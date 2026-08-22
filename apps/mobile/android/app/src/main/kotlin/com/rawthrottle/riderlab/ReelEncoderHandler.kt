package com.rawthrottle.riderlab

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.HandlerThread
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class ReelEncoderHandler : MethodChannel.MethodCallHandler {
  private val thread = HandlerThread("reel-encoder").apply { start() }
  private val handler = Handler(thread.looper)
  private var session: Session? = null

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    handler.post {
      try {
        when (call.method) {
          "start" -> {
            val path = call.argument<String>("path")
              ?: throw IllegalArgumentException("path")
            val width = call.argument<Int>("width") ?: 720
            val height = call.argument<Int>("height") ?: 1280
            val fps = call.argument<Int>("fps") ?: 12
            session?.release()
            session = Session(path, width, height, fps)
            reply(result, null)
          }
          "addFrame" -> {
            val bytes = call.argument<ByteArray>("bytes")
              ?: (call.arguments as? ByteArray)
              ?: throw IllegalArgumentException("bytes")
            session?.addFrame(bytes)
              ?: throw IllegalStateException("not started")
            reply(result, null)
          }
          "finish" -> {
            session?.finish()
            session = null
            reply(result, null)
          }
          else -> Handler(android.os.Looper.getMainLooper()).post {
            result.notImplemented()
          }
        }
      } catch (e: Exception) {
        Handler(android.os.Looper.getMainLooper()).post {
          result.error("reel", e.message, null)
        }
      }
    }
  }

  private fun reply(result: MethodChannel.Result, value: Any?) {
    Handler(android.os.Looper.getMainLooper()).post {
      result.success(value)
    }
  }

  fun dispose() {
    handler.post {
      session?.release()
      session = null
      thread.quitSafely()
    }
  }

  private class Session(
    path: String,
    private val width: Int,
    private val height: Int,
    private val fps: Int,
  ) {
    private val codec: MediaCodec =
      MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
    private val colorFormat: Int
    private val muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    private var track = -1
    private var muxerStarted = false
    private var frameIndex = 0L
    private val info = MediaCodec.BufferInfo()

    init {
      File(path).parentFile?.mkdirs()
      colorFormat = pickColor(codec)
      val format = MediaFormat.createVideoFormat(
        MediaFormat.MIMETYPE_VIDEO_AVC,
        width,
        height,
      )
      format.setInteger(MediaFormat.KEY_COLOR_FORMAT, colorFormat)
      format.setInteger(MediaFormat.KEY_BIT_RATE, 3_500_000)
      format.setInteger(MediaFormat.KEY_FRAME_RATE, fps)
      format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
      codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
      codec.start()
    }

    fun addFrame(rgba: ByteArray) {
      val yuv = rgbaToYuv(rgba, width, height, colorFormat)
      var inIx = codec.dequeueInputBuffer(20_000)
      var spins = 0
      while (inIx < 0 && spins < 20) {
        drain(false)
        inIx = codec.dequeueInputBuffer(20_000)
        spins++
      }
      if (inIx < 0) throw IllegalStateException("encoder busy")
      val buf = codec.getInputBuffer(inIx) ?: throw IllegalStateException("in buf")
      buf.clear()
      buf.put(yuv)
      val pts = frameIndex * 1_000_000L / fps
      codec.queueInputBuffer(inIx, 0, yuv.size, pts, 0)
      frameIndex++
      drain(false)
    }

    fun finish() {
      val inIx = codec.dequeueInputBuffer(50_000)
      if (inIx >= 0) {
        codec.queueInputBuffer(
          inIx,
          0,
          0,
          frameIndex * 1_000_000L / fps,
          MediaCodec.BUFFER_FLAG_END_OF_STREAM,
        )
      }
      drain(true)
      release()
    }

    fun release() {
      try {
        codec.stop()
      } catch (_: Exception) {
      }
      try {
        codec.release()
      } catch (_: Exception) {
      }
      try {
        if (muxerStarted) muxer.stop()
      } catch (_: Exception) {
      }
      try {
        muxer.release()
      } catch (_: Exception) {
      }
    }

    private fun drain(end: Boolean) {
      var loops = 0
      while (loops++ < 64) {
        val outIx = codec.dequeueOutputBuffer(info, if (end) 50_000 else 0)
        when {
          outIx == MediaCodec.INFO_TRY_AGAIN_LATER -> {
            if (!end) return
          }
          outIx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
            if (muxerStarted) continue
            track = muxer.addTrack(codec.outputFormat)
            muxer.start()
            muxerStarted = true
          }
          outIx >= 0 -> {
            val out = codec.getOutputBuffer(outIx)
            if (out != null && info.size > 0 && muxerStarted) {
              out.position(info.offset)
              out.limit(info.offset + info.size)
              muxer.writeSampleData(track, out, info)
            }
            codec.releaseOutputBuffer(outIx, false)
            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
              return
            }
          }
          else -> return
        }
        if (!end && outIx < 0) return
      }
    }

    companion object {
      private fun pickColor(codec: MediaCodec): Int {
        val caps = codec.codecInfo.getCapabilitiesForType(MediaFormat.MIMETYPE_VIDEO_AVC)
        val formats = caps.colorFormats
        if (formats.contains(MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar)) {
          return MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar
        }
        if (formats.contains(MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar)) {
          return MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar
        }
        return MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar
      }

      private fun rgbaToYuv(
        rgba: ByteArray,
        width: Int,
        height: Int,
        colorFormat: Int,
      ): ByteArray {
        val ySize = width * height
        val out = ByteArray(ySize + ySize / 2)
        val nv12 =
          colorFormat == MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar
        var uv = ySize
        var u = ySize
        var v = ySize + ySize / 4
        var i = 0
        for (y in 0 until height) {
          for (x in 0 until width) {
            val r = rgba[i].toInt() and 0xFF
            val g = rgba[i + 1].toInt() and 0xFF
            val b = rgba[i + 2].toInt() and 0xFF
            i += 4
            val yy = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
            out[y * width + x] = yy.coerceIn(0, 255).toByte()
            if (y % 2 == 0 && x % 2 == 0) {
              val uu = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
              val vv = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
              if (nv12) {
                out[uv++] = uu.coerceIn(0, 255).toByte()
                out[uv++] = vv.coerceIn(0, 255).toByte()
              } else {
                out[u++] = uu.coerceIn(0, 255).toByte()
                out[v++] = vv.coerceIn(0, 255).toByte()
              }
            }
          }
        }
        return out
      }
    }
  }
}
