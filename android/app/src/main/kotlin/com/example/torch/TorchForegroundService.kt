package com.example.torch

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel

class TorchForegroundService : Service() {

    private var cameraManager: CameraManager? = null
    private var cameraId: String? = null

    companion object {
        const val CHANNEL_ID = "torch_foreground_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_STOP = "ACTION_STOP_TORCH"

        // Référence au MethodChannel Flutter pour notifier l'UI
        var flutterChannel: MethodChannel? = null

        fun start(context: Context, isOn: Boolean) {
            val intent = Intent(context, TorchForegroundService::class.java).apply {
                putExtra("is_on", isOn)
            }
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, TorchForegroundService::class.java))
        }
    }

    override fun onCreate() {
        super.onCreate()
        cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        cameraId = cameraManager?.cameraIdList?.firstOrNull {
            cameraManager?.getCameraCharacteristics(it)
                ?.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        }
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            // Bouton "Fermer" dans la notification
            setTorch(false)
            // Notifier Flutter que la torche a été éteinte
            Handler(Looper.getMainLooper()).post {
                flutterChannel?.invokeMethod("onTorchStopped", null)
            }
            stopSelf()
            return START_NOT_STICKY
        }

        val isOn = intent?.getBooleanExtra("is_on", false) ?: false

        // Démarrer en premier plan avec notification
        startForeground(NOTIFICATION_ID, buildNotification(isOn))

        // Petit délai pour laisser Flutter libérer la caméra avant qu'on la reprenne
        Handler(Looper.getMainLooper()).postDelayed({
            setTorch(isOn)
        }, 300)

        return START_STICKY
    }

    private fun setTorch(enable: Boolean) {
        try {
            cameraId?.let { cameraManager?.setTorchMode(it, enable) }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun buildNotification(isOn: Boolean): Notification {
        val openIntent = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopIntent = PendingIntent.getService(
            this, 1,
            Intent(this, TorchForegroundService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(if (isOn) "🔦 Torche allumée" else "🔦 Torche en veille")
            .setContentText(
                if (isOn) "La torche reste active en arrière-plan."
                else "La torche est éteinte."
            )
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentIntent(openIntent)
            .addAction(android.R.drawable.ic_delete, "⏻ Fermer la torche", stopIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID, "Torche active", NotificationManager.IMPORTANCE_LOW
        ).apply { description = "Maintient la torche active en arrière-plan" }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    override fun onDestroy() {
        setTorch(false)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
