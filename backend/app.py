"""Gateway between the receiver's AWS IoT MQTT topics and the tablet.

The gateway deliberately has no simulator or seed devices.  Devices appear
only after a receiver publishes its status/telemetry.
"""
import json
import os
import threading
from datetime import datetime, timezone

from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_socketio import SocketIO, emit

try:
    import paho.mqtt.client as mqtt
except ImportError as exc:  # API-only development remains available
    mqtt = None
    mqtt_import_error = str(exc)
else:
    mqtt_import_error = None

app = Flask(__name__)
app.config["SECRET_KEY"] = os.environ.get("SHUNTING_SECRET", "change-me")
CORS(app, origins="*")
socketio = SocketIO(app, cors_allowed_origins="*", async_mode="threading")
lock = threading.RLock()
devices = {}
telemetry = {}
connected_device = None
last_error = None
mqtt_client = None

def _now():
    return datetime.now(timezone.utc).isoformat()

def _device(device_id):
    with lock:
        d = devices.setdefault(device_id, {"number": len(devices) + 1,
            "name": device_id, "online": False, "in_use": False, "battery": 0})
        return d

def _publish_event(event, data):
    socketio.emit(event, data)

def handle_mqtt(topic, payload):
    global last_error
    try:
        body = json.loads(payload)
        parts = topic.split("/")
        if len(parts) < 3 or parts[0] != "devices":
            return
        device_id = parts[1]
        d = _device(device_id)
        if parts[2] == "telemetry":
            readings = body.get("readings")
            diagnostics = body.get("diagnostics")
            if not isinstance(readings, dict) or not isinstance(diagnostics, dict):
                raise ValueError("Telemetry payload must contain readings and diagnostics objects")
            distance_cm = readings.get("distance_cm")
            battery_pct = diagnostics.get("battery_pct")
            if not isinstance(distance_cm, (int, float)) or isinstance(distance_cm, bool):
                raise ValueError("Telemetry payload has an invalid distance_cm")
            if not isinstance(battery_pct, (int, float)) or isinstance(battery_pct, bool):
                raise ValueError("Telemetry payload has an invalid battery_pct")
            value = {
                "device": device_id,
                "distance": float(distance_cm) / 100.0,
                "battery": int(battery_pct),
                "network": diagnostics.get("link_state") not in (None, "", "DISCONNECTED", "ERROR"),
                "charger": bool(diagnostics.get("is_charging", False)),
                "obstacle": bool(body.get("obstacle", False)),
                "completed": bool(body.get("completed", False)),
                "timestamp": _now(),
            }
            d.update(online=True, battery=value["battery"])
            telemetry[device_id] = value
            _publish_event("telemetry_update", value)
        elif parts[2] in ("status", "register"):
            device = body.get("device")
            if not isinstance(device, dict):
                device = {}
            reported_id = device.get("deviceId") or body.get("deviceId")
            if reported_id and reported_id != device_id:
                raise ValueError("MQTT topic and payload device IDs do not match")
            online = body.get("status", "ONLINE") == "ONLINE"
            d["online"] = online
            battery_pct = body.get("battery_pct", device.get("battery_pct"))
            if battery_pct is not None:
                if not isinstance(battery_pct, (int, float)) or isinstance(battery_pct, bool):
                    raise ValueError("Status payload has an invalid battery_pct")
                d["battery"] = int(battery_pct)
            socketio.emit("device_status", {"device": device_id, "online": online})
    except (ValueError, TypeError, json.JSONDecodeError) as exc:
        last_error = str(exc)

def _mqtt_loop():
    global last_error, mqtt_client
    endpoint = os.environ.get(
        "AWS_IOT_ENDPOINT",
        "a18ey7y7yi6gdo-ats.iot.ap-south-1.amazonaws.com",
    )
    if not mqtt or not endpoint:
        return
    try:
        client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2,
                             client_id=os.environ.get("AWS_IOT_CLIENT_ID", "shunting-gateway"))
        mqtt_client = client
        cert, key, ca = os.environ.get("AWS_IOT_CERT"), os.environ.get("AWS_IOT_KEY"), os.environ.get("AWS_IOT_CA")
        if not cert or not key:
            raise RuntimeError(
                "AWS_IOT_CERT and AWS_IOT_KEY must point to the receiver certificate and private key"
            )
        client.tls_set(ca_certs=ca, certfile=cert, keyfile=key)
        client.on_message = lambda _c, _u, msg: handle_mqtt(msg.topic, msg.payload.decode("utf-8"))
        client.connect(endpoint, int(os.environ.get("AWS_IOT_PORT", "8883")), 60)
        client.subscribe("devices/+/telemetry")
        client.subscribe("devices/+/status")
        client.subscribe("devices/+/register")
        client.loop_forever()
    except Exception as exc:
        last_error = str(exc)

threading.Thread(target=_mqtt_loop, daemon=True).start()

@app.get("/api/devices")
def get_devices():
    with lock:
        return jsonify({"success": True, "devices": list(devices.values()), "connected": connected_device})

@app.post("/api/connect/<device_name>")
def connect(device_name):
    global connected_device
    d = devices.get(device_name)
    if not d or not d["online"]:
        return jsonify({"success": False, "error": "Device is not online"}), 409
    if connected_device and connected_device != device_name:
        devices[connected_device]["in_use"] = False
    connected_device, d["in_use"] = device_name, True
    return jsonify({"success": True, "device": d, **telemetry.get(device_name, {})})

@app.post("/api/disconnect")
def disconnect():
    global connected_device
    if connected_device in devices:
        devices[connected_device]["in_use"] = False
    old, connected_device = connected_device, None
    socketio.emit("device_disconnected", {"device": old})
    return jsonify({"success": True})

@app.get("/api/telemetry")
def get_telemetry():
    value = telemetry.get(connected_device, {"device": connected_device, "network": False})
    return jsonify({"success": True, **value})

@app.post("/api/change_device/<device_name>")
def change_device(device_name):
    response = connect(device_name)
    if isinstance(response, tuple):
        return response
    socketio.emit("device_changed", {"device": device_name})
    return response

@app.get("/api/status")
def status():
    return jsonify({"success": True, "connected": connected_device,
        "devices_online": sum(1 for d in devices.values() if d["online"]),
        "devices_total": len(devices),
        "mqtt": bool(mqtt_client and mqtt_client.is_connected()),
        "last_error": last_error or mqtt_import_error})

@app.post("/api/command")
def command():
    data = request.get_json() or {}
    if not connected_device:
        return jsonify({"success": False, "error": "No receiver connected"}), 409
    if mqtt_client and mqtt_client.is_connected():
        topic = "devices/%s/commands" % connected_device
        mqtt_client.publish(topic, json.dumps({"command": data.get("command")}), qos=1)
    socketio.emit("command_requested", {"device": connected_device, "command": data.get("command")})
    return jsonify({"success": True})

@app.post("/api/obstacle")
def obstacle():
    return command_with_name("obstacle")

@app.post("/api/clear_obstacle")
def clear_obstacle():
    return command_with_name("clear_obstacle")

@app.post("/api/charger")
def charger():
    plugged = bool((request.get_json() or {}).get("plugged", False))
    return command_with_name("charger_on" if plugged else "charger_off")

def command_with_name(name):
    if not connected_device:
        return jsonify({"success": False, "error": "No receiver connected"}), 409
    if mqtt_client and mqtt_client.is_connected():
        mqtt_client.publish("devices/%s/commands" % connected_device,
                            json.dumps({"command": name}), qos=1)
    socketio.emit("command_requested", {"device": connected_device, "command": name})
    return jsonify({"success": True, "accepted": bool(mqtt_client and mqtt_client.is_connected())})

@socketio.on("connect")
def on_connect():
    emit("connected", {"status": "backend_connected"})

@socketio.on("subscribe_telemetry")
def subscribe():
    if connected_device and connected_device in telemetry:
        emit("telemetry_update", telemetry[connected_device])

if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "5000")), debug=False)
