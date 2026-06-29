package com.bkktransit.bkk_transit_planner

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.istornz.live_activities.LiveActivityManagerHolder

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        LiveActivityManagerHolder.instance = CustomLiveActivityManager(this)
        
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bkktransit/journey_actions")
        JourneyNotificationReceiver.methodChannel = channel
        
        channel.setMethodCallHandler { call, result ->
            if (call.method == "STOP_FOREGROUND_SERVICE") {
                val serviceIntent = Intent(this, JourneyForegroundService::class.java)
                stopService(serviceIntent)
                JourneyForegroundService.activeNotification = null
                JourneyForegroundService.activeNotificationId = 0
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
