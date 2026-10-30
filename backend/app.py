"""
Indian Railways Shunting Tablet - Backend Server
Flask + SocketIO REST API with WebSocket for real-time telemetry.
"""

import os
import json
import threading
import time
import random
from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_socketio import SocketIO, emit

app = Flask(__name__)
app.config['SECRET_KEY'] = 'shunting_tablet_secret_2024'
CORS(app, origins="*")
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# ---------------------------------------------------------------------------
# Device model (45 dead-end devices D-01 .. D-45)
# ---------------------------------------------------------------------------
NUM_DEVICES = 45
devices = {}
for i in range(1, NUM_DEVICES + 1):
    devices[f'D-{i:02d}'] = {
        'number': i,
        'name': f'D-{i:02d}',
        'online': (i % 7) != 5,
        'in_use': False,
        'battery': 40 + ((i * 13) % 60),
    }

connected_device = None
telemetry_distance = 120.0
battery_pct = 82
network_ready = True
obstacle_warning = False
charger_plugged = False
volume_pct = 50
shunting_completed = False

# ---------------------------------------------------------------------------
# Background telemetry simulator
# ---------------------------------------------------------------------------
def telemetry_loop():
    global telemetry_distance, shunting_completed, obstacle_warning
    while True:
        time.sleep(0.25)
        if connected_device and telemetry_distance > 0 and not shunting_completed:
            telemetry_distance = max(0, telemetry_distance - 0.4)
            socketio.emit('telemetry_update', {
                'device': connected_device,
                'distance': round(telemetry_distance, 1),
                'battery': battery_pct,
                'network': network_ready,
                'obstacle': obstacle_warning,
                'charger': charger_plugged,
            })
            if telemetry_distance == 0:
                shunting_completed = True
                socketio.emit('shunting_completed', {'device': connected_device})

threading.Thread(target=telemetry_loop, daemon=True).start()


# ---------------------------------------------------------------------------
# REST API routes
# ---------------------------------------------------------------------------
@app.route('/api/devices', methods=['GET'])
def get_devices():
    return jsonify({
        'success': True,
        'devices': list(devices.values()),
        'connected': connected_device,
    })


@app.route('/api/connect/<device_name>', methods=['POST'])
def connect_device(device_name):
    global connected_device, telemetry_distance, shunting_completed, obstacle_warning
    dev = devices.get(device_name)
    if not dev:
        return jsonify({'success': False, 'error': 'Device not found'}), 404
    if not dev['online']:
        return jsonify({'success': False, 'error': 'Device offline'}), 400
    if dev['in_use']:
        return jsonify({'success': False, 'error': 'Device already in use'}), 400

    connected_device = device_name
    dev['in_use'] = True
    telemetry_distance = 120.0
    shunting_completed = False
    obstacle_warning = False

    socketio.emit('device_connected', {
        'device': device_name,
        'distance': telemetry_distance,
    })
    return jsonify({'success': True, 'device': dev, 'distance': telemetry_distance})


@app.route('/api/disconnect', methods=['POST'])
def disconnect_device():
    global connected_device, telemetry_distance, shunting_completed
    dev_name = connected_device
    if dev_name and dev_name in devices:
        devices[dev_name]['in_use'] = False
    connected_device = None
    telemetry_distance = 0.0
    shunting_completed = False
    socketio.emit('device_disconnected', {'device': dev_name})
    return jsonify({'success': True})


@app.route('/api/telemetry', methods=['GET'])
def get_telemetry():
    return jsonify({
        'success': True,
        'device': connected_device,
        'distance': round(telemetry_distance, 1),
        'battery': battery_pct,
        'network': network_ready,
        'obstacle': obstacle_warning,
        'charger': charger_plugged,
        'completed': shunting_completed,
    })


@app.route('/api/obstacle', methods=['POST'])
def trigger_obstacle():
    global obstacle_warning
    obstacle_warning = True
    socketio.emit('obstacle_warning', {'device': connected_device, 'warning': True})
    return jsonify({'success': True, 'warning': True})


@app.route('/api/clear_obstacle', methods=['POST'])
def clear_obstacle():
    global obstacle_warning
    obstacle_warning = False
    socketio.emit('obstacle_cleared', {'device': connected_device})
    return jsonify({'success': True, 'warning': False})


@app.route('/api/charger', methods=['POST'])
def set_charger():
    global charger_plugged, battery_pct
    data = request.get_json() or {}
    charger_plugged = bool(data.get('plugged', True))
    if charger_plugged:
        battery_pct = min(100, battery_pct + 5)
    socketio.emit('charger_update', {'plugged': charger_plugged, 'battery': battery_pct})
    return jsonify({'success': True, 'plugged': charger_plugged, 'battery': battery_pct})


@app.route('/api/change_device/<device_name>', methods=['POST'])
def change_device(device_name):
    global connected_device
    old = connected_device
    if old and old in devices:
        devices[old]['in_use'] = False
    dev = devices.get(device_name)
    if not dev or not dev['online'] or dev['in_use']:
        return jsonify({'success': False, 'error': 'Cannot switch to this device'}), 400
    connected_device = device_name
    dev['in_use'] = True
    socketio.emit('device_changed', {'from': old, 'to': device_name})
    return jsonify({'success': True, 'device': dev})

@app.route('/api/volume', methods=['GET','POST'])
def volume():
    global volume_pct
    if request.method=='POST':
        data=request.get_json() or {}
        if 'volume' in data:
            v=int(data['volume'])
            v=max(0,min(10,v))
            volume_pct=v*10
        socketio.emit('volume_update',{'volume':volume_pct})
    return jsonify({'success':True,'volume':volume_pct})


@app.route('/api/status', methods=['GET'])
def get_status():
    return jsonify({
        'success': True,
        'connected': connected_device,
        'devices_online': sum(1 for d in devices.values() if d['online']),
        'devices_total': len(devices),
        'network': network_ready,
        'battery': battery_pct,
    })


# ---------------------------------------------------------------------------
# SocketIO events
# ---------------------------------------------------------------------------
@socketio.on('connect')
def on_connect():
    emit('connected', {'status': 'backend_connected'})


@socketio.on('subscribe_telemetry')
def on_subscribe():
    emit('telemetry_update', {
        'device': connected_device,
        'distance': round(telemetry_distance, 1),
        'battery': battery_pct,
        'network': network_ready,
        'obstacle': obstacle_warning,
        'charger': charger_plugged,
        'completed': shunting_completed,
    })


if __name__ == '__main__':
    print("=" * 60)
    print(" Indian Railways Shunting Tablet - Backend")
    print(" HTTP API : http://0.0.0.0:5000")
    print(" WebSocket: ws://0.0.0.0:5000")
    print("=" * 60)
    socketio.run(app, host='0.0.0.0', port=5000, debug=False)