package com.motoline.motoline

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val handler = Handler(Looper.getMainLooper())
  private var tone: ToneGenerator? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      CHANNEL,
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "ready" -> {
          playReady()
          result.success(null)
        }
        "fail" -> {
          playFail()
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }

  override fun onDestroy() {
    releaseTone()
    super.onDestroy()
  }

  private fun vibrator(): Vibrator {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
      vm.defaultVibrator
    } else {
      @Suppress("DEPRECATION")
      getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    }
  }

  private fun vibrate(timings: LongArray, amplitudes: IntArray) {
    val v = vibrator()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      v.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
    } else {
      @Suppress("DEPRECATION")
      v.vibrate(timings, -1)
    }
  }

  private fun playReady() {
    // Three max-amplitude pulses, last one longer — felt through a jacket pocket.
    vibrate(
      longArrayOf(0, 180, 90, 180, 90, 420),
      intArrayOf(0, 255, 0, 255, 0, 255),
    )
    playTones(
      first = ToneGenerator.TONE_PROP_ACK,
      firstMs = 160,
      second = ToneGenerator.TONE_CDMA_CONFIRM,
      secondMs = 380,
      gapMs = 80,
    )
  }

  private fun playFail() {
    vibrate(
      longArrayOf(0, 520),
      intArrayOf(0, 255),
    )
    playTones(
      first = ToneGenerator.TONE_SUP_ERROR,
      firstMs = 420,
      second = null,
      secondMs = 0,
      gapMs = 0,
    )
  }

  private fun toneStream(): Int {
    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    if (am.getStreamVolume(AudioManager.STREAM_MUSIC) > 0) {
      return AudioManager.STREAM_MUSIC
    }
    if (am.getStreamVolume(AudioManager.STREAM_NOTIFICATION) > 0) {
      return AudioManager.STREAM_NOTIFICATION
    }
    // Media and notification muted — still beep so the rider hears lock.
    return AudioManager.STREAM_ALARM
  }

  private fun playTones(
    first: Int,
    firstMs: Int,
    second: Int?,
    secondMs: Int,
    gapMs: Int,
  ) {
    try {
      releaseTone()
      tone = ToneGenerator(toneStream(), 100)
      tone?.startTone(first, firstMs)
      if (second != null) {
        handler.postDelayed({
          try {
            tone?.startTone(second, secondMs)
            handler.postDelayed({ releaseTone() }, (secondMs + 40).toLong())
          } catch (_: Exception) {
            releaseTone()
          }
        }, (firstMs + gapMs).toLong())
      } else {
        handler.postDelayed({ releaseTone() }, (firstMs + 40).toLong())
      }
    } catch (_: Exception) {
      releaseTone()
    }
  }

  private fun releaseTone() {
    try {
      tone?.release()
    } catch (_: Exception) {
    }
    tone = null
  }

  companion object {
    private const val CHANNEL = "com.motoline.motoline/lock_cue"
  }
}
