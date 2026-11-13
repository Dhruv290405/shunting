/**
 * READ BRANCH for the existing "shunting iot handler" Lambda (same function,
 * same Function URL, no extra Lambda).
 *
 * The IoT handler only WRITES telemetry to Postgres. The tablet calls its
 * Function URL over HTTP, so this file adds the read side. The handler sends
 * HTTP requests here and keeps handling IoT Rule events exactly as before
 * (see README.md for the 3-line change).
 *
 *   GET <url>?deviceId=TX-12   latest telemetry for one transmitter, in the
 *                              same JSON shape the IoT message had
 *                              ({deviceId, readings, diagnostics, ...}) plus
 *                              `obstacle` / `completed` flags.
 *   GET <url>                  list of live transmitters
 *                              {"devices":[{deviceId,battery,online,ageSeconds}]}
 *
 * Environment variables (DB_* already exist on the IoT handler):
 *   API_KEY          optional; when set, requests must send header x-api-key
 *   STALE_SECONDS    optional (default 15); telemetry older than this is
 *                    reported as status "OFFLINE" / link_state "LOST"
 *   COMPLETED_WINDOW_SECONDS  optional (default 30); how long a finished
 *                    session keeps reporting completed=true
 *
 * Needs read access only: use a read-only DB user if you can.
 * Recommended index:  CREATE INDEX IF NOT EXISTS device_telemetry_dev_time
 *                       ON device_telemetry (device_id, recorded_at DESC);
 */

const { Client } = require('pg');

const STALE_SECONDS = Number(process.env.STALE_SECONDS || 15);
const COMPLETED_WINDOW_SECONDS = Number(process.env.COMPLETED_WINDOW_SECONDS || 30);
const DEVICE_ID_PATTERN = /^[A-Za-z0-9_-]{1,40}$/;

let client = null;
// Overridable for tests.
let clientFactory = () =>
  new Client({
    // Same defaults as the IoT handler so both behave identically.
    host: process.env.DB_HOST || 'safeshunt-db.c5oesqouwl70.ap-south-1.rds.amazonaws.com',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME || 'safeshunt_db',
    port: parseInt(process.env.DB_PORT || '5432', 10),
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 5000,
  });

async function db() {
  // Reuse the connection across warm invocations (the tablet polls every second).
  if (client) return client;
  const c = clientFactory();
  c.on('error', () => {
    client = null;
  });
  await c.connect();
  client = c;
  return client;
}

// CORS: lets the Flutter web build (Chrome) read the response. The APK does not
// need it. Do NOT also enable CORS in the Function URL settings, or the headers
// get duplicated and browsers reject the response.
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'content-type, x-api-key, accept',
  'Access-Control-Max-Age': '600',
};

function reply(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
      ...CORS_HEADERS,
    },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  };
}

function parsePayload(raw) {
  if (raw && typeof raw === 'object') return raw;
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch (_) {
    return {};
  }
}

function header(event, name) {
  const headers = event.headers || {};
  const key = Object.keys(headers).find((k) => k.toLowerCase() === name);
  return key ? headers[key] : undefined;
}

async function latestTelemetry(c, deviceId) {
  const res = await c.query(
    `SELECT payload, battery_level, signal_rssi, distance_cm,
            EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - recorded_at)) AS age_s
       FROM device_telemetry
      WHERE device_id = $1
      ORDER BY recorded_at DESC
      LIMIT 1`,
    [deviceId]
  );
  return res.rows[0] || null;
}

// Each unit's real sensing range and sensor type are a hardware fact set
// once when the device is registered (see README "Registering a device's
// range/type") - never guessed from the device id on the tablet.
const DEFAULT_SENSOR_TYPE = 'lidar';
const DEFAULT_MAX_RANGE_M = 45;

async function deviceMeta(c, deviceId) {
  const res = await c.query(
    `SELECT COALESCE(sensor_type, $2) AS sensor_type,
            COALESCE(max_range_m, $3) AS max_range_m
       FROM device_registry
      WHERE device_id = $1
      LIMIT 1`,
    [deviceId, DEFAULT_SENSOR_TYPE, DEFAULT_MAX_RANGE_M]
  );
  const row = res.rows[0];
  return {
    sensorType: row ? row.sensor_type : DEFAULT_SENSOR_TYPE,
    maxRangeM: row ? Number(row.max_range_m) : DEFAULT_MAX_RANGE_M,
  };
}

// The transmitter publishes about every 500 ms, but the tablet polls once a
// second, so it would miss every other reading. The shunting receiver checks
// every reading for the obstacle rule, so return the last few (oldest first)
// and let the tablet process each one once, by id.
const RECENT_WINDOW_SECONDS = Number(process.env.RECENT_WINDOW_SECONDS || 3);

async function recentReadings(c, deviceId) {
  try {
    const res = await c.query(
      `SELECT id, distance_cm,
              EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - recorded_at)) * 1000 AS age_ms
         FROM device_telemetry
        WHERE device_id = $1
          AND distance_cm IS NOT NULL
          AND recorded_at > CURRENT_TIMESTAMP - ($2::text || ' seconds')::interval
        ORDER BY recorded_at ASC, id ASC
        LIMIT 12`,
      [deviceId, String(RECENT_WINDOW_SECONDS)]
    );
    return res.rows.map((r) => ({
      id: Number(r.id),
      cm: Number(r.distance_cm),
      ageMs: Math.max(0, Math.round(Number(r.age_ms))),
    }));
  } catch (err) {
    console.error('recent readings lookup failed:', err.message);
    return [];
  }
}

async function recentlyCompleted(c, deviceId) {
  try {
    const res = await c.query(
      `SELECT 1
         FROM shunting_sessions
        WHERE (tx_device_id = $1 OR de_code = $1)
          AND (status = 'COMPLETED' OR session_status = 'COMPLETED')
          AND COALESCE(end_time, session_end, updated_at)
              > NOW() - ($2::text || ' seconds')::interval
        LIMIT 1`,
      [deviceId, String(COMPLETED_WINDOW_SECONDS)]
    );
    return res.rows.length > 0;
  } catch (err) {
    console.error('completed lookup failed:', err.message);
    return false;
  }
}

function flag(value) {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') return ['true', '1', 'yes'].includes(value.toLowerCase());
  return false;
}

async function getDevice(c, deviceId) {
  const row = await latestTelemetry(c, deviceId);
  if (!row) return reply(404, { error: 'No telemetry for device', deviceId });

  const payload = parsePayload(row.payload);
  const readings = { ...(payload.readings || {}) };
  const diagnostics = { ...(payload.diagnostics || {}) };

  // Fall back to the extracted columns if the raw payload lacks them.
  if (readings.distance_cm == null && row.distance_cm != null) {
    readings.distance_cm = Number(row.distance_cm);
  }
  if (diagnostics.battery_pct == null && row.battery_level != null) {
    diagnostics.battery_pct = Number(row.battery_level);
  }
  if (diagnostics.gsm_rssi == null && row.signal_rssi != null) {
    diagnostics.gsm_rssi = Number(row.signal_rssi);
  }

  const ageSeconds = Math.max(0, Number(row.age_s));
  const fresh = ageSeconds <= STALE_SECONDS;
  if (!fresh) {
    diagnostics.status = 'OFFLINE';
    diagnostics.link_state = 'LOST';
  }

  const obstacle = [payload, readings, diagnostics].some((s) => flag(s.obstacle));
  const completed = fresh ? await recentlyCompleted(c, deviceId) : false;
  const recent = fresh ? await recentReadings(c, deviceId) : [];
  const meta = await deviceMeta(c, deviceId);

  return reply(200, {
    deviceId,
    productType: payload.productType || 'TRANSMITTER',
    uptime_s: payload.uptime_s ?? null,
    // Hardware fact set at registration time (device_registry), not reported
    // by the device itself and not guessed from the device id.
    sensorType: meta.sensorType,
    maxRangeM: meta.maxRangeM,
    readings,
    diagnostics,
    obstacle,
    completed,
    ageSeconds: Math.round(ageSeconds),
    // Age of the newest reading in ms (the receiver's BEST threshold is 2 s,
    // so whole seconds are too coarse).
    ageMs: Math.round(ageSeconds * 1000),
    recent,
  });
}

async function listDevices(c) {
  const res = await c.query(
    `SELECT device_id,
            COALESCE(sensor_type, '${DEFAULT_SENSOR_TYPE}') AS sensor_type,
            COALESCE(max_range_m, ${DEFAULT_MAX_RANGE_M}) AS max_range_m,
            EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - last_reading_timestamp)) AS age_s
       FROM device_registry
      WHERE product_type = 'TRANSMITTER'
        AND last_reading_timestamp IS NOT NULL
      ORDER BY device_id
      LIMIT 200`
  );
  const devices = [];
  for (const row of res.rows) {
    const ageSeconds = Math.max(0, Number(row.age_s));
    if (ageSeconds > STALE_SECONDS) continue; // only live transmitters
    const latest = await latestTelemetry(c, row.device_id);
    const payload = latest ? parsePayload(latest.payload) : {};
    const battery = payload.diagnostics?.battery_pct ?? latest?.battery_level ?? 0;
    devices.push({
      deviceId: row.device_id,
      battery: Number(battery) || 0,
      online: true,
      sensorType: row.sensor_type,
      maxRangeM: Number(row.max_range_m),
      ageSeconds: Math.round(ageSeconds),
    });
  }
  return reply(200, { devices });
}

/** True for Function URL / HTTP requests; false for AWS IoT Rule events. */
exports.isHttpRequest = (event) => Boolean(event && event.requestContext && event.requestContext.http);

exports.handleRead = async (event) => {
  // Browser CORS preflight (no API key is sent on preflight requests).
  if (event.requestContext?.http?.method === 'OPTIONS') {
    return { statusCode: 204, headers: CORS_HEADERS, body: '' };
  }
  const apiKey = process.env.API_KEY;
  if (apiKey && header(event, 'x-api-key') !== apiKey) {
    return reply(401, { error: 'Unauthorized' });
  }
  const method = event.requestContext?.http?.method || 'GET';
  if (method !== 'GET') return reply(405, { error: 'Method not allowed' });

  const deviceId = event.queryStringParameters?.deviceId;
  if (deviceId !== undefined && !DEVICE_ID_PATTERN.test(deviceId)) {
    return reply(400, { error: 'Invalid deviceId' });
  }

  try {
    const c = await db();
    return deviceId ? await getDevice(c, deviceId) : await listDevices(c);
  } catch (err) {
    console.error('Read API error:', err);
    // Drop the connection so the next invocation reconnects.
    try {
      if (client) await client.end();
    } catch (_) {}
    client = null;
    return reply(500, { error: 'Database error' });
  }
};

exports._setClientFactory = (factory) => {
  clientFactory = factory;
  client = null;
};
