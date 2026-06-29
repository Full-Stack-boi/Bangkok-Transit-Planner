package com.bkktransit.bkk_transit_planner

import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews
import com.istornz.live_activities.LiveActivityManager

class CustomLiveActivityManager(context: Context) : LiveActivityManager(context) {
    private val context: Context = context.applicationContext
    
    private val remoteViews = RemoteViews(context.packageName, R.layout.live_activity)
    
    private val pendingIntent = PendingIntent.getActivity(
        context, 200, Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    override suspend fun buildNotification(
        notification: Notification.Builder,
        event: String,
        data: Map<String, Any>
    ): Notification {
        val lineName = data["lineName"] as? String ?: ""
        val lineColorHex = data["lineColorHex"] as? String ?: "#7DC242"
        val currentStation = data["currentStation"] as? String ?: ""
        val nextStation = data["nextStation"] as? String ?: ""
        val destinationStation = data["destinationStation"] as? String ?: ""
        
        val stationsDone = (data["stationsDone"] as? Double)?.toInt() 
            ?: (data["stationsDone"] as? Int) 
            ?: 0
        val stationsTotal = (data["stationsTotal"] as? Double)?.toInt()
            ?: (data["stationsTotal"] as? Int)
            ?: 1
            
        val walkMeters = (data["walkMeters"] as? Double)?.toInt()
            ?: (data["walkMeters"] as? Int)
            ?: 0
        val etaMinutes = (data["etaMinutes"] as? Double)?.toInt()
            ?: (data["etaMinutes"] as? Int)
            ?: 0
        val speedKmh = (data["speedKmh"] as? Double) ?: 0.0
        val isWalking = data["isWalking"] as? Boolean ?: false
        val isSimulation = data["isSimulation"] as? Boolean ?: false

        remoteViews.setTextViewText(R.id.tv_line_name, lineName)
        
        if (isWalking) {
            remoteViews.setTextViewText(R.id.tv_direction, "เดินเท้า")
            remoteViews.setTextViewText(R.id.tv_walk_meters, "🚶 เดินเท้าอีก ${walkMeters} ม.")
        } else {
            remoteViews.setTextViewText(R.id.tv_direction, "มุ่งหน้า ${destinationStation}")
            remoteViews.setTextViewText(R.id.tv_walk_meters, "🚇 นั่งรถไฟฟ้า")
        }

        remoteViews.setProgressBar(R.id.pb_progress, stationsTotal, stationsDone, false)
        
        try {
            val color = Color.parseColor(lineColorHex)
            remoteViews.setColorStateList(R.id.pb_progress, "setProgressTintList", android.content.res.ColorStateList.valueOf(color))
        } catch (e: Exception) {
            // Ignore color parsing failures
        }

        remoteViews.setTextViewText(R.id.tv_current_station, currentStation)
        remoteViews.setTextViewText(R.id.tv_next_station, nextStation)
        
        remoteViews.setTextViewText(R.id.tv_eta, "⏱ อีก ${etaMinutes} นาที")
        remoteViews.setTextViewText(R.id.tv_speed, String.format("💨 %.1f กม./ชม", speedKmh))

        val nextIntent = Intent(context, JourneyNotificationReceiver::class.java).apply {
            action = "ACTION_NEXT_STATION"
        }
        val nextPendingIntent = PendingIntent.getBroadcast(
            context,
            301,
            nextIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        remoteViews.setOnClickPendingIntent(R.id.btn_next, nextPendingIntent)
        val nextVisibility = if (isSimulation) android.view.View.VISIBLE else android.view.View.GONE
        remoteViews.setViewVisibility(R.id.btn_next, nextVisibility)

        val stopIntent = Intent(context, JourneyNotificationReceiver::class.java).apply {
            action = "ACTION_STOP_JOURNEY"
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            context,
            302,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        remoteViews.setOnClickPendingIntent(R.id.btn_stop, stopPendingIntent)

        val builder = notification
            .setOngoing(true)
            .setSmallIcon(R.drawable.ic_train)
            .setContentTitle(lineName)
            .setContentText("มุ่งหน้า ${destinationStation}")
            .setContentIntent(pendingIntent)
            .setCategory(Notification.CATEGORY_NAVIGATION)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setStyle(Notification.DecoratedCustomViewStyle())
            .setCustomContentView(remoteViews)
            .setCustomBigContentView(remoteViews)
            
        try {
            val color = Color.parseColor(lineColorHex)
            builder.setColor(color)
            builder.setColorized(true)
        } catch (e: Exception) {
            // Ignore color parsing failures
        }

        val builtNotification = builder.build()

        val notificationId = java.math.BigInteger(
            java.security.MessageDigest.getInstance("SHA-256").digest("journey_tracking".toByteArray())
        ).abs().toInt()
        
        JourneyForegroundService.activeNotification = builtNotification
        JourneyForegroundService.activeNotificationId = notificationId

        if (event == "create") {
            val serviceIntent = Intent(context, JourneyForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }

        return builtNotification
    }
}
