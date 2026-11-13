package com.example.shunting_tablet

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import android.util.Log

/**
 * Kiosk control.
 *
 * Kiosk lock (lock task mode) only works once the tablet has been provisioned
 * with this app as device owner:
 *
 *   adb shell dpm set-device-owner com.example.shunting_tablet/.KioskAdminReceiver
 *
 * On a tablet that is not provisioned every lock call here is a safe no-op, so
 * the same APK can be installed and tried out without any risk of locking the
 * tablet.
 *
 * Locking and unlocking is always manual: "maintenance mode" stays on, across
 * restarts too, until someone presses LOCK NOW.
 */
object KioskManager {
    private const val TAG = "Kiosk"
    private const val PREFS = "kiosk"
    private const val KEY_MAINTENANCE = "maintenance"
    private const val CHANNEL_ID = "kiosk_maintenance"
    private const val NOTIFICATION_ID = 4101
    private const val HOME_ALIAS = "com.example.shunting_tablet.KioskHomeActivity"
    const val ACTION_LOCK_NOW = "com.example.shunting_tablet.LOCK_NOW"

    private fun dpm(ctx: Context) =
        ctx.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

    private fun admin(ctx: Context) = ComponentName(ctx, KioskAdminReceiver::class.java)

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isDeviceOwner(ctx: Context): Boolean = dpm(ctx).isDeviceOwnerApp(ctx.packageName)

    fun isMaintenance(ctx: Context): Boolean = prefs(ctx).getBoolean(KEY_MAINTENANCE, false)

    private fun setMaintenance(ctx: Context, value: Boolean) {
        prefs(ctx).edit().putBoolean(KEY_MAINTENANCE, value).commit()
    }

    fun isLocked(ctx: Context): Boolean {
        val am = ctx.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
    }

    /** Device-owner policies that make the lock possible (idempotent). */
    private fun applyPolicies(ctx: Context) {
        val dpm = dpm(ctx)
        val admin = admin(ctx)
        try {
            dpm.setLockTaskPackages(admin, arrayOf(ctx.packageName))
            if (Build.VERSION.SDK_INT >= 28) {
                // No Home, Recents, notifications, system info, lock screen or
                // power menu while locked.
                dpm.setLockTaskFeatures(admin, DevicePolicyManager.LOCK_TASK_FEATURE_NONE)
            }
            dpm.setKeyguardDisabled(admin, true)
        } catch (e: Exception) {
            Log.e(TAG, "applyPolicies failed", e)
        }
    }

    /**
     * Whether this app is the device's one and only Home app. Must only be
     * on while actually locked: it is an OS-level policy, not tied to lock
     * task mode, so it has to be cleared on unlock or Home still reopens
     * this app during maintenance (and after a restart while unlocked).
     */
    private fun setHomeApp(ctx: Context, enabled: Boolean) {
        val dpm = dpm(ctx)
        val admin = admin(ctx)
        val homeAlias = ComponentName(ctx, HOME_ALIAS)
        try {
            if (enabled) {
                ctx.packageManager.setComponentEnabledSetting(
                    homeAlias,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                val home = IntentFilter(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    addCategory(Intent.CATEGORY_DEFAULT)
                }
                dpm.addPersistentPreferredActivity(
                    admin, home, homeAlias
                )
            } else {
                dpm.clearPackagePersistentPreferredActivities(admin, ctx.packageName)
                ctx.packageManager.setComponentEnabledSetting(
                    homeAlias,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "setHomeApp failed", e)
        }
    }

    /** Called whenever the activity comes to the front. */
    fun ensureLocked(activity: Activity) {
        if (!isDeviceOwner(activity)) return
        applyPolicies(activity)
        if (isMaintenance(activity)) return
        try {
            setHomeApp(activity, true)
            dpm(activity).setStatusBarDisabled(admin(activity), true)
            if (!isLocked(activity)) activity.startLockTask()
        } catch (e: Exception) {
            Log.e(TAG, "ensureLocked failed", e)
        }
    }

    /** PIN accepted: leave kiosk until someone presses LOCK NOW. */
    fun enterMaintenance(activity: Activity) {
        setMaintenance(activity, true)
        if (isDeviceOwner(activity)) {
            try {
                activity.stopLockTask()
            } catch (e: Exception) {
                Log.w(TAG, "stopLockTask: $e")
            }
            try {
                setHomeApp(activity, false)
                dpm(activity).setStatusBarDisabled(admin(activity), false)
                if (Build.VERSION.SDK_INT >= 33) {
                    dpm(activity).setPermissionGrantState(
                        admin(activity), activity.packageName,
                        Manifest.permission.POST_NOTIFICATIONS,
                        DevicePolicyManager.PERMISSION_GRANT_STATE_GRANTED
                    )
                }
            } catch (e: Exception) {
                Log.w(TAG, "enterMaintenance policies: $e")
            }
        } else if (Build.VERSION.SDK_INT >= 33 &&
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7)
        }
        showReminder(activity)
    }

    /**
     * (Re)posts the "tablet not locked" reminder. Called when maintenance
     * starts and every time the app comes to the front while unlocked, so it
     * also appears right after the user grants the notification permission.
     */
    fun showReminder(ctx: Context) {
        if (isMaintenance(ctx)) showNotification(ctx)
    }

    /** LOCK NOW: back to kiosk. */
    fun lock(activity: Activity) {
        setMaintenance(activity, false)
        cancelNotification(activity)
        ensureLocked(activity)
    }

    /** Remove kiosk completely (no factory reset needed afterwards). */
    @Suppress("DEPRECATION")
    fun decommission(activity: Activity) {
        setMaintenance(activity, false)
        cancelNotification(activity)
        if (!isDeviceOwner(activity)) return
        val dpm = dpm(activity)
        val admin = admin(activity)
        try {
            activity.stopLockTask()
        } catch (e: Exception) {
            Log.w(TAG, "stopLockTask: $e")
        }
        try {
            dpm.clearPackagePersistentPreferredActivities(admin, activity.packageName)
            activity.packageManager.setComponentEnabledSetting(
                ComponentName(activity, HOME_ALIAS),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            dpm.setStatusBarDisabled(admin, false)
            dpm.setKeyguardDisabled(admin, false)
            dpm.setLockTaskPackages(admin, arrayOf())
            dpm.clearDeviceOwnerApp(activity.packageName)
        } catch (e: Exception) {
            Log.e(TAG, "decommission failed", e)
        }
    }

    /** The app's own volume % scales the beeps, so the system volume stays at max. */
    fun maxVolume(ctx: Context) {
        try {
            val audio = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audio.setStreamVolume(
                AudioManager.STREAM_MUSIC,
                audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC),
                0
            )
        } catch (e: Exception) {
            Log.w(TAG, "maxVolume: $e")
        }
    }

    fun openSettings(ctx: Context, wifi: Boolean): Boolean {
        return try {
            val intent = Intent(if (wifi) Settings.ACTION_WIFI_SETTINGS else Settings.ACTION_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.w(TAG, "openSettings: $e")
            false
        }
    }

    fun status(ctx: Context): Map<String, Boolean> = mapOf(
        "deviceOwner" to isDeviceOwner(ctx),
        "maintenance" to isMaintenance(ctx),
        "locked" to isLocked(ctx),
    )

    // ---- "tablet not locked" reminder -----------------------------------

    private fun showNotification(ctx: Context) {
        try {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID, "Maintenance mode", NotificationManager.IMPORTANCE_LOW
                    )
                )
            }
            val intent = Intent(ctx, MainActivity::class.java)
                .setAction(ACTION_LOCK_NOW)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            val pending = PendingIntent.getActivity(
                ctx, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val builder = if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(ctx, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(ctx)
            }
            builder
                .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
                .setContentTitle("MAINTENANCE MODE - TABLET NOT LOCKED")
                .setContentText("Tap to lock the tablet again")
                .setOngoing(true)
                .setContentIntent(pending)
                .addAction(
                    Notification.Action.Builder(
                        Icon.createWithResource(ctx, android.R.drawable.ic_lock_lock),
                        "LOCK NOW",
                        pending
                    ).build()
                )
            nm.notify(NOTIFICATION_ID, builder.build())
        } catch (e: Exception) {
            Log.w(TAG, "showNotification: $e")
        }
    }

    private fun cancelNotification(ctx: Context) {
        try {
            (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .cancel(NOTIFICATION_ID)
        } catch (e: Exception) {
            Log.w(TAG, "cancelNotification: $e")
        }
    }
}
