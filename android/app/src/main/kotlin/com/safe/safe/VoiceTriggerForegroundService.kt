package com.safe.safe

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class VoiceTriggerForegroundService : Service() {
    private var isListening: Boolean = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val keyword = intent.getStringExtra(EXTRA_KEYWORD).orEmpty()
                val duration = intent.getIntExtra(EXTRA_RECORDING_DURATION_SEC, 15)
                startVoiceTrigger(keyword, duration)
            }

            ACTION_STOP -> {
                stopVoiceTrigger()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startVoiceTrigger(keyword: String, durationSec: Int) {
        if (isListening) return

        createNotificationChannelIfNeeded()
        val notification = buildNotification(keyword, durationSec)
        startForeground(NOTIFICATION_ID, notification)

        // TODO: Brancher ici le moteur wake-word + capture audio 15s.
        isListening = true
    }

    private fun stopVoiceTrigger() {
        // TODO: Stopper moteur wake-word + capture audio.
        isListening = false
    }

    private fun buildNotification(keyword: String, durationSec: Int): Notification {
        val content = "Écoute active • mot-clé: $keyword • clip ${durationSec}s"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Protection Safe active")
            .setContentText(content)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSilent(true)
            .build()
    }

    private fun createNotificationChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Protection vocale",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "État de l'écoute du mot-clé d'urgence"
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val ACTION_START = "com.safe.safe.voice.ACTION_START"
        const val ACTION_STOP = "com.safe.safe.voice.ACTION_STOP"

        const val EXTRA_KEYWORD = "keyword"
        const val EXTRA_RECORDING_DURATION_SEC = "recordingDurationSec"

        private const val CHANNEL_ID = "safe_voice_trigger_channel"
        private const val NOTIFICATION_ID = 2401
    }
}
