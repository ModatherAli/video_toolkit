package com.modatherali.video_toolkit

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Log
import androidx.core.content.FileProvider
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.TransformationRequest
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.modatherali.video_toolkit/compressor"
    private val EVENT_CHANNEL = "com.modatherali.video_toolkit/compression_events"
    private val REQUEST_CODE_PICK_VIDEO = 1001

    private var pendingPickResult: MethodChannel.Result? = null
    private var eventSink: EventChannel.EventSink? = null

    private var activeTransformer: Transformer? = null
    private var currentOutputFile: File? = null
    private var progressRunnable: Runnable? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickVideo" -> handlePickVideo(result)
                "getVideoMetadata" -> handleGetVideoMetadata(call, result)
                "startCompression" -> handleStartCompression(call, result)
                "cancelCompression" -> handleCancelCompression(result)
                "saveToGallery" -> handleSaveToGallery(call, result)
                "getAvailableStorage" -> handleGetAvailableStorage(result)
                "openVideoFile" -> handleOpenVideoFile(call, result)
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    private fun handlePickVideo(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("ALREADY_PICKING", "A video selection is already active", null)
            return
        }
        pendingPickResult = result

        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "video/*"
            addCategory(Intent.CATEGORY_OPENABLE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                putExtra(Intent.EXTRA_LOCAL_ONLY, true)
            }
        }
        try {
            startActivityForResult(intent, REQUEST_CODE_PICK_VIDEO)
        } catch (e: Exception) {
            pendingPickResult = null
            result.error("PICKER_ERROR", "Could not launch video picker: ${e.message}", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_PICK_VIDEO) {
            val result = pendingPickResult ?: return
            pendingPickResult = null

            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                try {
                    val takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION
                    contentResolver.takePersistableUriPermission(uri, takeFlags)
                } catch (_: Exception) {}

                Thread {
                    try {
                        val meta = extractMetadata(uri.toString())
                        mainHandler.post { result.success(meta) }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("METADATA_ERROR", "Failed to inspect video: ${e.message}", null)
                        }
                    }
                }.start()
            } else {
                result.success(null)
            }
        }
    }

    private fun handleGetVideoMetadata(call: MethodCall, result: MethodChannel.Result) {
        val uriOrPath = call.argument<String>("uri") ?: call.argument<String>("path")
        if (uriOrPath.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "URI or path must not be null or blank", null)
            return
        }

        Thread {
            try {
                val meta = extractMetadata(uriOrPath)
                mainHandler.post { result.success(meta) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("METADATA_ERROR", "Failed to inspect video: ${e.message}", null)
                }
            }
        }.start()
    }

    private fun extractMetadata(uriOrPath: String): Map<String, Any?> {
        val retriever = MediaMetadataRetriever()
        var fileName = "video.mp4"
        var fileSize = 0L

        if (uriOrPath.startsWith("content://")) {
            val uri = Uri.parse(uriOrPath)
            retriever.setDataSource(this, uri)
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIdx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val sizeIdx = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (nameIdx != -1) fileName = cursor.getString(nameIdx) ?: "video.mp4"
                    if (sizeIdx != -1) fileSize = cursor.getLong(sizeIdx)
                }
            }
        } else {
            val file = File(uriOrPath)
            fileName = file.name
            fileSize = file.length()
            retriever.setDataSource(uriOrPath)
        }

        val durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
        var width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
        var height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
        val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
        val bitrate = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toLongOrNull() ?: 0L
        val mimeType = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE) ?: "video/mp4"

        // Account for rotation
        if (rotation == 90 || rotation == 270) {
            val temp = width
            width = height
            height = temp
        }

        // Generate thumbnail
        var thumbnailPath: String? = null
        try {
            val frame: Bitmap? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                retriever.getScaledFrameAtTime(1000000L, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, 512, 512)
                    ?: retriever.frameAtTime
            } else {
                retriever.frameAtTime
            }
            if (frame != null) {
                val thumbFile = File(cacheDir, "thumb_${System.currentTimeMillis()}.jpg")
                FileOutputStream(thumbFile).use { out ->
                    frame.compress(Bitmap.CompressFormat.JPEG, 85, out)
                }
                thumbnailPath = thumbFile.absolutePath
            }
        } catch (e: Exception) {
            Log.w("OptiVideo", "Thumbnail generation error: ${e.message}")
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {}
        }

        return mapOf(
            "uri" to uriOrPath,
            "fileName" to fileName,
            "fileSize" to fileSize,
            "durationMs" to durationMs,
            "width" to width,
            "height" to height,
            "rotation" to rotation,
            "bitrate" to bitrate,
            "mimeType" to mimeType,
            "thumbnailPath" to thumbnailPath
        )
    }

    private fun handleStartCompression(call: MethodCall, result: MethodChannel.Result) {
        if (activeTransformer != null) {
            result.error("ALREADY_RUNNING", "A compression task is already running", null)
            return
        }

        val sourceUri = call.argument<String>("sourceUri")
        val outputPath = call.argument<String>("outputPath")
        val targetWidth = call.argument<Int>("targetWidth") ?: 0
        val targetHeight = call.argument<Int>("targetHeight") ?: 0
        val videoBitrate = call.argument<Int>("videoBitrate") ?: 0
        val preserveAudio = call.argument<Boolean>("preserveAudio") ?: true
        val videoCodec = call.argument<String>("videoCodec") ?: "H264"

        if (sourceUri.isNullOrBlank() || outputPath.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "sourceUri and outputPath must be provided", null)
            return
        }

        val outFile = File(outputPath)
        outFile.parentFile?.mkdirs()
        if (outFile.exists()) {
            outFile.delete()
        }
        currentOutputFile = outFile

        try {
            val mediaItem = if (sourceUri.startsWith("content://")) {
                MediaItem.fromUri(Uri.parse(sourceUri))
            } else {
                MediaItem.fromUri(Uri.fromFile(File(sourceUri)))
            }

            val editedItemBuilder = EditedMediaItem.Builder(mediaItem)
            if (!preserveAudio) {
                editedItemBuilder.setRemoveAudio(true)
            }

            if (targetWidth > 0 && targetHeight > 0) {
                val safeWidth = (targetWidth / 2) * 2
                val safeHeight = (targetHeight / 2) * 2
                val presentation = Presentation.createForWidthAndHeight(
                    safeWidth,
                    safeHeight,
                    Presentation.LAYOUT_SCALE_TO_FIT
                )
                editedItemBuilder.setEffects(Effects(emptyList(), listOf(presentation)))
            }

            val editedMediaItem = editedItemBuilder.build()

            val encoderFactoryBuilder = DefaultEncoderFactory.Builder(this)
            if (videoBitrate > 0) {
                encoderFactoryBuilder.setRequestedVideoEncoderSettings(
                    VideoEncoderSettings.Builder()
                        .setBitrate(videoBitrate)
                        .build()
                )
            }

            val videoMime = if (videoCodec.equals("H265", ignoreCase = true)) {
                MimeTypes.VIDEO_H265
            } else {
                MimeTypes.VIDEO_H264
            }

            val transformer = Transformer.Builder(this)
                .setVideoMimeType(videoMime)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .setEncoderFactory(encoderFactoryBuilder.build())
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        stopProgressPolling()
                        activeTransformer = null
                        val finalSize = currentOutputFile?.length() ?: 0L
                        mainHandler.post {
                            eventSink?.success(
                                mapOf(
                                    "status" to "completed",
                                    "outputPath" to outputPath,
                                    "fileSize" to finalSize
                                )
                            )
                        }
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException
                    ) {
                        stopProgressPolling()
                        activeTransformer = null
                        currentOutputFile?.delete()
                        mainHandler.post {
                            eventSink?.success(
                                mapOf(
                                    "status" to "error",
                                    "message" to (exportException.message ?: "Compression failed")
                                )
                            )
                        }
                    }

                    override fun onFallbackApplied(
                        composition: Composition,
                        originalTransformationRequest: TransformationRequest,
                        fallbackTransformationRequest: TransformationRequest
                    ) {
                        Log.i("OptiVideo", "Fallback applied during compression: $fallbackTransformationRequest")
                    }
                })
                .build()

            activeTransformer = transformer
            transformer.start(editedMediaItem, outputPath)
            startProgressPolling(transformer)
            result.success(true)
        } catch (e: Exception) {
            activeTransformer = null
            currentOutputFile?.delete()
            result.error("START_FAILED", "Failed to start compression: ${e.message}", null)
        }
    }

    private fun handleCancelCompression(result: MethodChannel.Result) {
        stopProgressPolling()
        try {
            activeTransformer?.cancel()
        } catch (e: Exception) {
            Log.w("OptiVideo", "Cancel error: ${e.message}")
        }
        activeTransformer = null
        currentOutputFile?.delete()
        currentOutputFile = null
        eventSink?.success(mapOf("status" to "cancelled"))
        result.success(true)
    }

    private fun startProgressPolling(transformer: Transformer) {
        stopProgressPolling()
        val progressHolder = ProgressHolder()
        progressRunnable = object : Runnable {
            override fun run() {
                val t = activeTransformer
                if (t != null && t === transformer) {
                    val progressState = t.getProgress(progressHolder)
                    if (progressState == Transformer.PROGRESS_STATE_AVAILABLE) {
                        eventSink?.success(
                            mapOf(
                                "status" to "progress",
                                "progress" to progressHolder.progress
                            )
                        )
                    }
                    mainHandler.postDelayed(this, 250)
                }
            }
        }
        mainHandler.post(progressRunnable!!)
    }

    private fun stopProgressPolling() {
        progressRunnable?.let { mainHandler.removeCallbacks(it) }
        progressRunnable = null
    }

    private fun handleSaveToGallery(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        val displayName = call.argument<String>("displayName") ?: "compressed_video.mp4"

        if (filePath.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "filePath must not be null or blank", null)
            return
        }

        Thread {
            try {
                val sourceFile = File(filePath)
                if (!sourceFile.exists()) {
                    mainHandler.post { result.error("NOT_FOUND", "Source file does not exist", null) }
                    return@Thread
                }

                val values = ContentValues().apply {
                    put(MediaStore.Video.Media.DISPLAY_NAME, displayName)
                    put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES + "/OptiVideo")
                        put(MediaStore.Video.Media.IS_PENDING, 1)
                    }
                }

                val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                } else {
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                }

                val insertedUri = contentResolver.insert(collection, values)
                if (insertedUri == null) {
                    mainHandler.post { result.error("INSERT_FAILED", "Failed to insert media entry", null) }
                    return@Thread
                }

                contentResolver.openOutputStream(insertedUri)?.use { out ->
                    FileInputStream(sourceFile).use { input ->
                        input.copyTo(out)
                    }
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    values.clear()
                    values.put(MediaStore.Video.Media.IS_PENDING, 0)
                    contentResolver.update(insertedUri, values, null, null)
                }

                mainHandler.post { result.success(insertedUri.toString()) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("SAVE_FAILED", "Failed to save video to gallery: ${e.message}", null)
                }
            }
        }.start()
    }

    private fun handleGetAvailableStorage(result: MethodChannel.Result) {
        try {
            val stat = StatFs(cacheDir.path)
            val available = stat.availableBlocksLong * stat.blockSizeLong
            result.success(available)
        } catch (e: Exception) {
            result.error("STORAGE_ERROR", "Failed to query storage: ${e.message}", null)
        }
    }

    private fun handleOpenVideoFile(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        if (filePath.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "filePath must not be null", null)
            return
        }

        try {
            val file = File(filePath)
            if (!file.exists()) {
                result.error("NOT_FOUND", "File does not exist: $filePath", null)
                return
            }

            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "video/*")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_FAILED", "Failed to open video: ${e.message}", null)
        }
    }
}
