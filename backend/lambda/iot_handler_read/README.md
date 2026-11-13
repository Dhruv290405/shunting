# Read branch for the existing IoT handler (no new Lambda)

Goal: the tablet reads live data from the **same** Function URL
(`https://wmrnfmn54255qt246fn6k5xmby0oebty.lambda-url.ap-south-1.on.aws/`)
that the IoT Rule already writes through. IoT ingestion is unchanged.

## 1. Add the file
In the Lambda console code editor, create a new file `read_branch.js` next to
`index.js` and paste the contents of `read_branch.js` from this folder.
(`pg` is already in your function.)

## 2. Change the handler (3 lines)
At the very top of `exports.handler` in `index.js`:

```js
const { isHttpRequest, handleRead } = require('./read_branch');   // top of file

exports.handler = async (event, context) => {
  if (isHttpRequest(event)) return handleRead(event);              // NEW
  console.log('Incoming AWS IoT Telemetry Event:', ...);           // existing code
  ...
```

IoT Rule events have no `requestContext.http`, so they keep going through your
existing code untouched. HTTP calls that are not GET get `405` and never reach
the database insert code.

## 3. Settings
- Function URL auth type: NONE (already the case).
- Optional: add env var `API_KEY=<secret>`; the app then needs
  `--dart-define=LAMBDA_API_KEY=<secret>`.
- Optional index (faster reads):
  `CREATE INDEX IF NOT EXISTS device_telemetry_dev_time ON device_telemetry (device_id, recorded_at DESC);`

## 4. Run the app
The tablet discovers live transmitter IDs from the device-list response and
then requests the selected ID. It does not hardcode a transmitter ID.
(`LAMBDA_URL` already defaults to the IoT handler URL.)

## Check
```
curl "https://wmrnfmn54255qt246fn6k5xmby0oebty.lambda-url.ap-south-1.on.aws/?deviceId=TX-12"
```
Tests (no DB needed): `node --test test.js`

## 5. Registering a device's range/type (run once, before deploying this file)

Each unit's real LiDAR/camera range is a hardware fact, not something it
reports over the wire and not something the tablet should guess from its id.
It lives in `device_registry` and this read branch sends it to the tablet as
`sensorType` / `maxRangeM`. Run this migration **before** pasting the updated
`read_branch.js` into the Lambda console, or every read will fail with
`column "sensor_type" does not exist`:

```sql
ALTER TABLE device_registry
  ADD COLUMN IF NOT EXISTS sensor_type text NOT NULL DEFAULT 'lidar',
  ADD COLUMN IF NOT EXISTS max_range_m integer NOT NULL DEFAULT 45;

-- sensor_type is one of: 'lidar', 'camera', 'lidar_camera'
```

Then set the real values per device as the hardware team confirms them, e.g.:

```sql
UPDATE device_registry SET sensor_type = 'lidar', max_range_m = 100
 WHERE device_id = 'TX-12';
```

Until a device's row is updated it reports the default (45 m, lidar), which
is exactly today's fallback behaviour - so the migration is safe to run
ahead of time with no effect until you set a device's real values.
