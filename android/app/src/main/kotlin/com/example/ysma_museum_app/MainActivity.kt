package com.example.ysma_museum_app

import android.speech.tts.TextToSpeech
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val channelName = "ysma_museum_app/voice_navigation"
    private var textToSpeech: TextToSpeech? = null
    private var textToSpeechReady = false
    private var pendingSpeech: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        warmUpTextToSpeech()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "warmUp" -> {
                    warmUpTextToSpeech()
                    result.success(null)
                }
                "speak" -> {
                    val text = call.argument<String>("text").orEmpty()
                    speak(text)
                    result.success(true)
                }
                "stop" -> {
                    textToSpeech?.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onInit(status: Int) {
        textToSpeechReady = status == TextToSpeech.SUCCESS

        if (textToSpeechReady) {
            textToSpeech?.language = Locale.US
            pendingSpeech?.let { speak(it) }
            pendingSpeech = null
        }
    }

    private fun warmUpTextToSpeech() {
        if (textToSpeech == null) {
            textToSpeech = TextToSpeech(this, this)
        }
    }

    private fun speak(text: String) {
        if (text.isBlank()) {
            return
        }

        val engine = textToSpeech
        if (engine == null) {
            pendingSpeech = text
            warmUpTextToSpeech()
            return
        }

        if (!textToSpeechReady) {
            pendingSpeech = text
            return
        }

        engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "museum_navigation")
    }

    override fun onDestroy() {
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        super.onDestroy()
    }
}
