package com.bkktransit.bkk_transit_planner

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodChannel

class JourneyNotificationReceiver : BroadcastReceiver() {
    companion object {
        var methodChannel: MethodChannel? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        
        // Send action call back to Flutter
        methodChannel?.invokeMethod(action, null)
    }
}
