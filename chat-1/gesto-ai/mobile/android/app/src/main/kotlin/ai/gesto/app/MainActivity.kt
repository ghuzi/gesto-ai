package ai.gesto.app

import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/**
 * Gesto AI host activity.
 *
 * The backend expects a base64 JPEG per frame, but Android cameras hand the
 * Flutter `camera` plugin YUV_420_888 (three planes) — `ImageFormatGroup.jpeg`
 * is effectively iOS-only, which is why streaming failed with
 * "This device does not expose a JPEG camera stream".
 *
 * This channel converts the planes to NV21 and lets Android's hardware YuvImage
 * encoder produce the JPEG. The work runs on a worker thread so the camera
 * preview stays at 60 fps, and the reply is posted back to the platform thread.
 */
class MainActivity : FlutterActivity() {

    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "encodeJpeg" -> {
                        val args = call.arguments as? Map<*, *>
                        if (args == null) {
                            result.error("bad_args", "encodeJpeg expects a map", null)
                            return@setMethodCallHandler
                        }
                        worker.execute {
                            try {
                                val jpeg = encodeJpeg(args)
                                mainHandler.post {
                                    if (jpeg == null) {
                                        result.error("encode_failed", "Could not encode the frame", null)
                                    } else {
                                        result.success(jpeg)
                                    }
                                }
                            } catch (error: Throwable) {
                                mainHandler.post {
                                    result.error(
                                        "encode_error",
                                        error.message ?: error.javaClass.simpleName,
                                        null
                                    )
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        worker.shutdownNow()
        super.onDestroy()
    }

    private fun encodeJpeg(args: Map<*, *>): ByteArray? {
        val width = (args["width"] as? Number)?.toInt() ?: return null
        val height = (args["height"] as? Number)?.toInt() ?: return null
        if (width <= 0 || height <= 0) return null

        val quality = ((args["quality"] as? Number)?.toInt() ?: DEFAULT_QUALITY)
            .coerceIn(10, 100)
        val format = args["format"] as? String ?: "yuv420"

        @Suppress("UNCHECKED_CAST")
        val planes = args["planes"] as? List<ByteArray> ?: return null
        if (planes.isEmpty()) return null

        val rowStrides = (args["rowStrides"] as? List<*>)?.map { (it as Number).toInt() }
        val pixelStrides = (args["pixelStrides"] as? List<*>)?.map { (it as Number).toInt() }

        val nv21: ByteArray = when {
            format == "nv21" && planes.size == 1 -> planes[0].copyOf()
            planes.size >= 3 && rowStrides != null && pixelStrides != null ->
                yuv420ToNv21(planes, rowStrides, pixelStrides, width, height)
            else -> return null
        }

        val output = ByteArrayOutputStream(nv21.size / 4)
        val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
        val ok = yuvImage.compressToJpeg(Rect(0, 0, width, height), quality, output)
        return if (ok) output.toByteArray() else null
    }

    /**
     * YUV_420_888 (Y, U, V planes with arbitrary strides) -> NV21
     * (full Y plane followed by interleaved V/U).
     */
    private fun yuv420ToNv21(
        planes: List<ByteArray>,
        rowStrides: List<Int>,
        pixelStrides: List<Int>,
        width: Int,
        height: Int,
    ): ByteArray {
        val yPlane = planes[0]
        val uPlane = planes[1]
        val vPlane = planes[2]

        val yRowStride = rowStrides[0]
        val uRowStride = rowStrides[1]
        val vRowStride = rowStrides[2]
        val yPixelStride = maxOf(1, pixelStrides[0])
        val uPixelStride = maxOf(1, pixelStrides[1])
        val vPixelStride = maxOf(1, pixelStrides[2])

        val out = ByteArray(width * height + width * height / 2)
        var position = 0

        // Luma: copy row by row, honouring the row stride and any padding.
        for (row in 0 until height) {
            var source = row * yRowStride
            for (col in 0 until width) {
                out[position++] = yPlane[source]
                source += yPixelStride
            }
        }

        // Chroma: half resolution, V before U (NV21 layout).
        val chromaHeight = height / 2
        val chromaWidth = width / 2
        for (row in 0 until chromaHeight) {
            var uSource = row * uRowStride
            var vSource = row * vRowStride
            for (col in 0 until chromaWidth) {
                out[position++] = vPlane[vSource]
                out[position++] = uPlane[uSource]
                uSource += uPixelStride
                vSource += vPixelStride
            }
        }

        return out
    }

    private companion object {
        const val CHANNEL = "ai.gesto.app/camera_codec"
        const val DEFAULT_QUALITY = 80
    }
}
