package com.bkktransit.bkk_transit_planner

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.os.Build
import android.content.pm.ServiceInfo

class JourneyForegroundService : Service() {
    companion object {
        var activeNotification: Notification? = null
        var activeNotificationId: Int = 0
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = activeNotification
        if (notification != null && activeNotificationId != 0) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(activeNotificationId, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            } else {
                startForeground(activeNotificationId, notification)
            }
        }
        return START_STICKY
    }
}
