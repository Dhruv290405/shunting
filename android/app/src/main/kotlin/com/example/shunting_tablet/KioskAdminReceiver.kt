package com.example.shunting_tablet

import android.app.admin.DeviceAdminReceiver

/**
 * Admin component for kiosk mode. It has no behaviour of its own: its only job
 * is to be the component set as device owner (see KioskManager).
 */
class KioskAdminReceiver : DeviceAdminReceiver()
