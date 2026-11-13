// Run: node --test backend/lambda/iot_handler_read/test.js
const test = require('node:test');
const assert = require('node:assert');
const lambda = require('./read_branch.js');

const payload = {
  deviceId: 'TX-12',
  productType: 'TRANSMITTER',
  uptime_s: 292,
  readings: { distance_cm: 18000, selected_target_id: 0 },
  diagnostics: {
    battery_pct: 0,
    is_charging: false,
    gsm_rssi: 0,
    link_state: 'OK',
    status: 'ONLINE',
  },
};

function fakeDb({ ageS = 1, completed = false, raw = JSON.stringify(payload) } = {}) {
  return () => ({
    on() {},
    async connect() {},
    async end() {},
    async query(sql, params) {
      if (sql.includes('AS age_ms')) {
        // recentReadings(): oldest first
        return {
          rows: params[0] === 'TX-12'
            ? [
                { id: '101', distance_cm: 3000, age_ms: 1400 },
                { id: '102', distance_cm: 2900, age_ms: 900 },
                { id: '103', distance_cm: 2800, age_ms: 400 },
              ]
            : [],
        };
      }
      if (sql.includes('FROM device_telemetry')) {
        return params[0] === 'TX-12'
          ? { rows: [{ payload: raw, age_s: ageS, battery_level: 0, signal_rssi: 0, distance_cm: 18000 }] }
          : { rows: [] };
      }
      if (sql.includes('FROM shunting_sessions')) {
        return { rows: completed ? [{}] : [] };
      }
      if (sql.includes('FROM device_registry')) {
        if (sql.includes('LIMIT 1')) {
          // deviceMeta(): single-device lookup used by getDevice().
          return params[0] === 'TX-12'
            ? { rows: [{ sensor_type: 'lidar', max_range_m: 100 }] }
            : { rows: [] };
        }
        return {
          rows: [
            { device_id: 'TX-12', sensor_type: 'lidar', max_range_m: 100, age_s: 2 },
            { device_id: 'TX-99', sensor_type: 'camera', max_range_m: 45, age_s: 600 },
          ],
        };
      }
      throw new Error('unexpected sql ' + sql);
    },
  });
}

const get = (qs) => ({ requestContext: { http: { method: 'GET' } }, queryStringParameters: qs });

test('latest telemetry keeps the IoT payload shape', async () => {
  lambda._setClientFactory(fakeDb());
  const res = await lambda.handleRead(get({ deviceId: 'TX-12' }));
  assert.strictEqual(res.statusCode, 200);
  const body = JSON.parse(res.body);
  assert.strictEqual(body.deviceId, 'TX-12');
  assert.strictEqual(body.readings.distance_cm, 18000);
  assert.strictEqual(body.diagnostics.status, 'ONLINE');
  assert.strictEqual(body.diagnostics.link_state, 'OK');
  assert.strictEqual(body.obstacle, false);
  assert.strictEqual(body.completed, false);
  assert.strictEqual(body.sensorType, 'lidar');
  assert.strictEqual(body.maxRangeM, 100);
});

test('a device not yet registered with a range/type falls back to the defaults', async () => {
  lambda._setClientFactory(() => ({
    on() {},
    async connect() {},
    async end() {},
    async query(sql, params) {
      if (sql.includes('AS age_ms')) return { rows: [] };
      if (sql.includes('FROM device_telemetry')) {
        return { rows: [{ payload: JSON.stringify(payload), age_s: 1, battery_level: 0, signal_rssi: 0, distance_cm: 18000 }] };
      }
      if (sql.includes('FROM shunting_sessions')) return { rows: [] };
      if (sql.includes('FROM device_registry')) return { rows: [] }; // not registered yet
      throw new Error('unexpected sql ' + sql);
    },
  }));
  const body = JSON.parse((await lambda.handleRead(get({ deviceId: 'TX-12' }))).body);
  assert.strictEqual(body.sensorType, 'lidar');
  assert.strictEqual(body.maxRangeM, 45);
});

test('payload stored as jsonb object also works', async () => {
  lambda._setClientFactory(fakeDb({ raw: payload }));
  const body = JSON.parse((await lambda.handleRead(get({ deviceId: 'TX-12' }))).body);
  assert.strictEqual(body.readings.distance_cm, 18000);
});

test('stale telemetry is reported offline', async () => {
  lambda._setClientFactory(fakeDb({ ageS: 60, completed: true }));
  const body = JSON.parse((await lambda.handleRead(get({ deviceId: 'TX-12' }))).body);
  assert.strictEqual(body.diagnostics.status, 'OFFLINE');
  assert.strictEqual(body.diagnostics.link_state, 'LOST');
  assert.strictEqual(body.completed, false);
});

test('completed session flag', async () => {
  lambda._setClientFactory(fakeDb({ completed: true }));
  const body = JSON.parse((await lambda.handleRead(get({ deviceId: 'TX-12' }))).body);
  assert.strictEqual(body.completed, true);
});

test('unknown device -> 404, bad id -> 400, bad method -> 405', async () => {
  lambda._setClientFactory(fakeDb());
  assert.strictEqual((await lambda.handleRead(get({ deviceId: 'TX-77' }))).statusCode, 404);
  assert.strictEqual((await lambda.handleRead(get({ deviceId: "x';--" }))).statusCode, 400);
  const post = { requestContext: { http: { method: 'POST' } } };
  assert.strictEqual((await lambda.handleRead(post)).statusCode, 405);
});

test('list returns only live transmitters, each with its registered range/type', async () => {
  lambda._setClientFactory(fakeDb());
  const body = JSON.parse((await lambda.handleRead(get(undefined))).body);
  assert.deepStrictEqual(body.devices.map((d) => d.deviceId), ['TX-12']);
  assert.strictEqual(body.devices[0].sensorType, 'lidar');
  assert.strictEqual(body.devices[0].maxRangeM, 100);
});

test('api key is enforced when configured', async () => {
  process.env.API_KEY = 'secret';
  lambda._setClientFactory(fakeDb());
  assert.strictEqual((await lambda.handleRead(get({ deviceId: 'TX-12' }))).statusCode, 401);
  const ok = { ...get({ deviceId: 'TX-12' }), headers: { 'X-Api-Key': 'secret' } };
  assert.strictEqual((await lambda.handleRead(ok)).statusCode, 200);
  delete process.env.API_KEY;
});

test('isHttpRequest tells Function URL calls from IoT Rule events apart', () => {
  assert.strictEqual(lambda.isHttpRequest({ requestContext: { http: { method: 'GET' } } }), true);
  assert.strictEqual(lambda.isHttpRequest({ deviceId: 'TX-12', readings: {} }), false);
  assert.strictEqual(lambda.isHttpRequest(undefined), false);
});

test('CORS headers are sent and OPTIONS preflight is answered', async () => {
  lambda._setClientFactory(fakeDb());
  const res = await lambda.handleRead(get({ deviceId: 'TX-12' }));
  assert.strictEqual(res.headers['Access-Control-Allow-Origin'], '*');
  const pre = await lambda.handleRead({ requestContext: { http: { method: 'OPTIONS' } } });
  assert.strictEqual(pre.statusCode, 204);
  assert.strictEqual(pre.headers['Access-Control-Allow-Origin'], '*');
  const err = await lambda.handleRead(get({ deviceId: 'TX-77' }));
  assert.strictEqual(err.headers['Access-Control-Allow-Origin'], '*');
});

test('response carries ageMs and the recent readings (oldest first, with ids)', async () => {
  lambda._setClientFactory(fakeDb({ ageS: 1.234 }));
  const body = JSON.parse((await lambda.handleRead(get({ deviceId: 'TX-12' }))).body);
  assert.strictEqual(body.ageMs, 1234);
  assert.strictEqual(body.ageSeconds, 1);
  assert.deepStrictEqual(body.recent, [
    { id: 101, cm: 3000, ageMs: 1400 },
    { id: 102, cm: 2900, ageMs: 900 },
    { id: 103, cm: 2800, ageMs: 400 },
  ]);
});

test('stale device returns no recent readings', async () => {
  lambda._setClientFactory(fakeDb({ ageS: 60 }));
  const body = JSON.parse((await lambda.handleRead(get({ deviceId: 'TX-12' }))).body);
  assert.deepStrictEqual(body.recent, []);
  assert.strictEqual(body.ageMs, 60000);
});
