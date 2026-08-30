package com.safe.safe

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream
import java.util.*

class VoiceTriggerForegroundService : Service() {
    private var isListening: Boolean = false
    private var keyword: String = ""
    private var recordingDurationSec: Int = 15
    
    private var speechRecognizer: SpeechRecognizer? = null
    private var audioRecorder: AudioRecord? = null
    private var isRecording: Boolean = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                keyword = intent.getStringExtra(EXTRA_KEYWORD).orEmpty().lowercase()
                recordingDurationSec = intent
                    .getIntExtra(EXTRA_RECORDING_DURATION_SEC, 15)
                    .coerceIn(MIN_RECORDING_DURATION_SEC, MAX_RECORDING_DURATION_SEC)
                startVoiceTrigger()
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

    override fun onDestroy() {
        stopVoiceTrigger()
        super.onDestroy()
    }

    private fun startVoiceTrigger() {
        if (isListening) return
        if (keyword.isEmpty()) {
            Log.w(TAG, "Mot-clé vide, impossible de démarrer")
            return
        }

        createNotificationChannelIfNeeded()
        val notification = buildNotification()
        startForeground(NOTIFICATION_ID, notification)

        startSpeechRecognition()
        isListening = true
        Log.i(TAG, "Écoute démarrée pour '$keyword'")
    }

    private fun stopVoiceTrigger() {
        stopSpeechRecognition()
        stopEmergencyRecording()
        isListening = false
        Log.i(TAG, "Écoute arrêtée")
    }

    // ── Speech Recognition ───────────────────────────────────────────────────

    private fun startSpeechRecognition() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            Log.e(TAG, "Reconnaissance vocale non disponible sur cet appareil")
            return
        }

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                Log.d(TAG, "Prêt pour écoute")
            }

            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}

            override fun onError(error: Int) {
                Log.d(TAG, "Erreur reconnaissance: $error")
                // Redémarrer après erreur
                if (isListening) {
                    android.os.Handler(mainLooper).postDelayed({
                        startListeningIntent()
                    }, 500)
                }
            }

            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                processRecognitionResults(matches)
                
                // Continuer l'écoute
                if (isListening) {
                    android.os.Handler(mainLooper).postDelayed({
                        startListeningIntent()
                    }, 300)
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                processRecognitionResults(matches)
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        startListeningIntent()
    }

    private fun startListeningIntent() {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "fr-FR")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        }
        
        try {
            speechRecognizer?.startListening(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Erreur démarrage écoute: ${e.message}")
        }
    }

    private fun stopSpeechRecognition() {
        try {
            speechRecognizer?.stopListening()
            speechRecognizer?.cancel()
            speechRecognizer?.destroy()
            speechRecognizer = null
        } catch (e: Exception) {
            Log.e(TAG, "Erreur arrêt reconnaissance: ${e.message}")
        }
    }

    private fun processRecognitionResults(matches: List<String>?) {
        if (matches.isNullOrEmpty()) return
        
        for (text in matches) {
            val lowerText = text.lowercase()
            Log.d(TAG, "Reconnu: $lowerText")
            
            if (containsKeyword(lowerText)) {
                Log.i(TAG, "🚨 MOT-CLÉ DÉTECTÉ: '$keyword'")
                onKeywordDetected()
                return
            }
        }
    }

    private fun containsKeyword(text: String): Boolean {
        // Vérification exacte
        if (text.contains(keyword)) return true
        
        // Vérification mot par mot
        val keywordWords = keyword.split(" ").filter { it.length >= 3 }
        if (keywordWords.isEmpty()) return false
        
        var matchCount = 0
        for (word in keywordWords) {
            if (text.contains(word)) matchCount++
        }
        
        // 70% des mots trouvés
        return matchCount >= (keywordWords.size * 0.7).toInt().coerceAtLeast(1)
    }

    private fun onKeywordDetected() {
        // Vibration de confirmation
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? android.os.Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(android.os.VibrationEffect.createOneShot(200, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(200)
        }
        
        // Démarrer l'enregistrement d'urgence
        startEmergencyRecording()
    }

    // ── Emergency Recording ──────────────────────────────────────────────────

    private fun startEmergencyRecording() {
        if (isRecording) return
        isRecording = true
        
        Log.i(TAG, "🔴 Enregistrement d'urgence démarré (${recordingDurationSec}s)")
        
        Thread {
            try {
                val sampleRate = 44100
                val bufferSize = AudioRecord.getMinBufferSize(
                    sampleRate,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT
                )
                
                audioRecorder = AudioRecord(
                    MediaRecorder.AudioSource.MIC,
                    sampleRate,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufferSize
                )
                
                val outputFile = File(
                    getExternalFilesDir(null),
                    "emergency_${System.currentTimeMillis()}.pcm"
                )
                
                val outputStream = FileOutputStream(outputFile)
                val buffer = ByteArray(bufferSize)
                
                audioRecorder?.startRecording()
                
                val endTime = System.currentTimeMillis() + (recordingDurationSec * 1000L)
                
                while (System.currentTimeMillis() < endTime && isRecording) {
                    val read = audioRecorder?.read(buffer, 0, bufferSize) ?: 0
                    if (read > 0) {
                        outputStream.write(buffer, 0, read)
                    }
                }
                
                outputStream.close()
                audioRecorder?.stop()
                audioRecorder?.release()
                audioRecorder = null
                
                Log.i(TAG, "⬛ Enregistrement terminé: ${outputFile.absolutePath}")
                
                // TODO: Convertir PCM en M4A et notifier Flutter
                
            } catch (e: Exception) {
                Log.e(TAG, "Erreur enregistrement: ${e.message}")
            } finally {
                isRecording = false
            }
        }.start()
    }

    private fun stopEmergencyRecording() {
        isRecording = false
        try {
            audioRecorder?.stop()
            audioRecorder?.release()
            audioRecorder = null
        } catch (e: Exception) {
            Log.e(TAG, "Erreur arrêt enregistrement: ${e.message}")
        }
    }

    // ── Notification ─────────────────────────────────────────────────────────

    private fun buildNotification(): Notification {
        val content = "Écoute active • mot-clé: $keyword • clip ${recordingDurationSec}s"

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
        private const val TAG = "VoiceTriggerService"
        
        const val ACTION_START = "com.safe.safe.voice.ACTION_START"
        const val ACTION_STOP = "com.safe.safe.voice.ACTION_STOP"

        const val EXTRA_KEYWORD = "keyword"
        const val EXTRA_RECORDING_DURATION_SEC = "recordingDurationSec"

        private const val CHANNEL_ID = "safe_voice_trigger_channel"
        private const val NOTIFICATION_ID = 2401
        private const val MIN_RECORDING_DURATION_SEC = 5
        private const val MAX_RECORDING_DURATION_SEC = 600
    }
}
