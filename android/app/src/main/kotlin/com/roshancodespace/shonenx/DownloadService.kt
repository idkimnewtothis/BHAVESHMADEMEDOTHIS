package io.github.idkimnewtothis.shonenxplus
import android.app.Service
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class DownloadService : Service() {
    override fun onCreate() {
        super.onCreate()
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel("offline-transfers", "Offline downloads", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification = Notification.Builder(this, "offline-transfers")
            .setContentTitle("ShonenX+ downloads")
            .setContentText("Saving chapters and episodes for offline access")
            .setSmallIcon(android.R.drawable.stat_sys_download).setContentIntent(open).setOngoing(true).build()
        if (Build.VERSION.SDK_INT >= 29) startForeground(4101, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        else startForeground(4101, notification)
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.hasExtra("progress") == true) {
            val notification = Notification.Builder(this, "offline-transfers")
                .setContentTitle(intent.getStringExtra("title") ?: "ShonenX+ downloads")
                .setContentText("Saving for offline access")
                .setSmallIcon(android.R.drawable.stat_sys_download)
                .setProgress(100, intent.getIntExtra("progress", 0), false).setOngoing(true).build()
            getSystemService(NotificationManager::class.java).notify(4101, notification)
        }
        return START_NOT_STICKY
    }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onTimeout(startId: Int, fgsType: Int) { stopSelf() }
}
