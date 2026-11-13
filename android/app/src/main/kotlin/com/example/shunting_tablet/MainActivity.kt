package com.example.shunting_tablet

import android.content.Intent
import android.os.Bundle
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(KioskManager.status(this))
                    "enterMaintenance" -> {
                        KioskManager.enterMaintenance(this)
                        result.success(KioskManager.status(this))
                    }
                    "lockNow" -> {
                        KioskManager.lock(this)
                        result.success(KioskManager.status(this))
                    }
                    "openSettings" -> result.success(KioskManager.openSettings(this, false))
                    "openWifiSettings" -> result.success(KioskManager.openSettings(this, true))
                    "decommission" -> {
                        KioskManager.decommission(this)
                        result.success(KioskManager.status(this))
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The tablet is a dashboard: never let the screen time out.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        KioskManager.maxVolume(this)
        KioskManager.ensureLocked(this)
        KioskManager.showReminder(this)
        channel?.invokeMethod("stateChanged", null)
    }

    /** The "LOCK NOW" action of the maintenance reminder notification. */
    private fun handleIntent(intent: Intent?) {
        if (intent?.action == KioskManager.ACTION_LOCK_NOW) {
            KioskManager.lock(this)
            channel?.invokeMethod("stateChanged", null)
        }
    }

    // The app's own volume control sets the beep loudness; the tablet's
    // hardware volume keys must not change anything.
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean =
        if (isVolumeKey(keyCode)) true else super.onKeyDown(keyCode, event)

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean =
        if (isVolumeKey(keyCode)) true else super.onKeyUp(keyCode, event)

    private fun isVolumeKey(keyCode: Int) =
        keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
            keyCode == KeyEvent.KEYCODE_VOLUME_DOWN ||
            keyCode == KeyEvent.KEYCODE_VOLUME_MUTE

    companion object {
        const val CHANNEL = "shunting/kiosk"
    }
}
