package com.modatherali.video_toolkit

import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
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
    private val REQUEST_CODE_TRASH_ORIGINALS = 1002

    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingTrashResult: MethodChannel.Result? = null
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
                "createQuickSample" -> handleCreateQuickSample(call, result)
                "cancelCompression" -> handleCancelCompression(result)
                "saveToGallery" -> handleSaveToGallery(call, result)
                "getAvailableStorage" -> handleGetAvailableStorage(result)
                "openVideoFile" -> handleOpenVideoFile(call, result)
                "startForegroundNotification" -> handleStartForegroundNotification(call, result)
                "updateForegroundNotification" -> handleUpdateForegroundNotification(call, result)
                "stopForegroundNotification" -> handleStopForegroundNotification(result)
                "requestTrashFiles" -> handleRequestTrashFiles(call, result)
                "queryLargestMediaFiles" -> handleQueryLargestMediaFiles(call, result)
                "verifyOutputFile" -> handleVerifyOutputFile(call, result)
                "getDeviceSafetyStatus" -> handleGetDeviceSafetyStatus(result)
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
        if (requestCode == REQUEST_CODE_TRASH_ORIGINALS) {
            val result = pendingTrashResult ?: return
            pendingTrashResult = null
            result.success(resultCode == Activity.RESULT_OK)
            return
        }
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

    private fun handleStartForegroundNotification(call: MethodCall, result: MethodChannel.Result) {
        val title = call.argument<String>("title") ?: "Compressing Videos"
        val message = call.argument<String>("message") ?: "Processing in background"
        val progress = call.argument<Int>("progress") ?: 0
        try {
            CompressionForegroundService.startService(this, title, message, progress)
            result.success(true)
        } catch (e: Exception) {
            result.error("FOREGROUND_ERROR", "Failed to start foreground service: ${e.message}", null)
        }
    }

    private fun handleUpdateForegroundNotification(call: MethodCall, result: MethodChannel.Result) {
        val title = call.argument<String>("title") ?: "Compressing Videos"
        val message = call.argument<String>("message") ?: "Processing"
        val progress = call.argument<Int>("progress") ?: 0
        try {
            CompressionForegroundService.updateService(this, title, message, progress)
            result.success(true)
        } catch (e: Exception) {
            result.error("FOREGROUND_ERROR", "Failed to update notification: ${e.message}", null)
        }
    }

    private fun handleStopForegroundNotification(result: MethodChannel.Result) {
        try {
            CompressionForegroundService.stopService(this)
            result.success(true)
        } catch (e: Exception) {
            result.error("FOREGROUND_ERROR", "Failed to stop service: ${e.message}", null)
        }
    }

    private fun handleCreateQuickSample(call: MethodCall, result: MethodChannel.Result) {
        val sourceUri = call.argument<String>("sourceUri")
        val outputPath = call.argument<String>("outputPath")
        val targetWidth = call.argument<Int>("targetWidth") ?: 0
        val targetHeight = call.argument<Int>("targetHeight") ?: 0
        val videoBitrate = call.argument<Int>("videoBitrate") ?: 0
        val videoCodec = call.argument<String>("videoCodec") ?: "H264"
        val sampleDurationSec = call.argument<Int>("sampleDurationSec") ?: 5

        if (sourceUri.isNullOrBlank() || outputPath.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "sourceUri and outputPath must be provided", null)
            return
        }

        val outFile = File(outputPath)
        outFile.parentFile?.mkdirs()
        if (outFile.exists()) {
            outFile.delete()
        }

        try {
            val baseItem = if (sourceUri.startsWith("content://")) {
                MediaItem.fromUri(Uri.parse(sourceUri))
            } else {
                MediaItem.fromUri(Uri.fromFile(File(sourceUri)))
            }

            val clippingConfig = MediaItem.ClippingConfiguration.Builder()
                .setStartPositionMs(0L)
                .setEndPositionMs(sampleDurationSec * 1000L)
                .build()

            val clippedMediaItem = baseItem.buildUpon()
                .setClippingConfiguration(clippingConfig)
                .build()

            val editedItemBuilder = EditedMediaItem.Builder(clippedMediaItem)
            if (targetWidth > 0 && targetHeight > 0) {
                val presentation = Presentation.createForWidthAndHeight(
                    (targetWidth / 2) * 2,
                    (targetHeight / 2) * 2,
                    Presentation.LAYOUT_SCALE_TO_FIT
                )
                editedItemBuilder.setEffects(Effects(emptyList(), listOf(presentation)))
            }

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

            val sampleTransformer = Transformer.Builder(this)
                .setVideoMimeType(videoMime)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .setEncoderFactory(encoderFactoryBuilder.build())
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        mainHandler.post { result.success(outputPath) }
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException
                    ) {
                        outFile.delete()
                        mainHandler.post {
                            result.error("SAMPLE_ERROR", exportException.message ?: "Sample generation failed", null)
                        }
                    }
                })
                .build()

            sampleTransformer.start(editedItemBuilder.build(), outputPath)
        } catch (e: Exception) {
            outFile.delete()
            result.error("SAMPLE_START_FAILED", "Failed to start quick sample: ${e.message}", null)
        }
    }

    private fun handleRequestTrashFiles(call: MethodCall, result: MethodChannel.Result) {
        val filePathsOrUris = call.argument<List<String>>("files") ?: emptyList()
        if (filePathsOrUris.isEmpty()) {
            result.success(true)
            return
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val uris = filePathsOrUris.mapNotNull { str ->
                    if (str.startsWith("content://")) {
                        Uri.parse(str)
                    } else {
                        val projection = arrayOf(MediaStore.MediaColumns._ID)
                        val cursor = contentResolver.query(
                            MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                            projection,
                            "${MediaStore.MediaColumns.DATA} = ?",
                            arrayOf(str),
                            null
                        )
                        cursor?.use {
                            if (it.moveToFirst()) {
                                val id = it.getLong(it.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                                ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id)
                            } else null
                        }
                    }
                }

                if (uris.isNotEmpty()) {
                    pendingTrashResult = result
                    val pendingIntent = MediaStore.createTrashRequest(contentResolver, uris, true)
                    startIntentSenderForResult(
                        pendingIntent.intentSender,
                        REQUEST_CODE_TRASH_ORIGINALS,
                        null,
                        0,
                        0,
                        0
                    )
                    return
                }
            }

            var allDeleted = true
            for (p in filePathsOrUris) {
                val file = File(p)
                if (file.exists()) {
                    val deleted = file.delete()
                    if (!deleted) allDeleted = false
                }
            }
            result.success(allDeleted)
        } catch (e: Exception) {
            result.error("TRASH_ERROR", "Failed to move files to trash: ${e.message}", null)
        }
    }

    private fun handleQueryLargestMediaFiles(call: MethodCall, result: MethodChannel.Result) {
        val limit = call.argument<Int>("limit") ?: 25
        Thread {
            try {
                val mediaList = mutableListOf<Map<String, Any?>>()
                val projection = arrayOf(
                    MediaStore.Video.Media._ID,
                    MediaStore.Video.Media.DISPLAY_NAME,
                    MediaStore.Video.Media.SIZE,
                    MediaStore.Video.Media.DURATION,
                    MediaStore.Video.Media.DATE_MODIFIED,
                    MediaStore.Video.Media.DATA
                )
                val sortOrder = "${MediaStore.Video.Media.SIZE} DESC LIMIT $limit"

                contentResolver.query(
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    projection,
                    "${MediaStore.Video.Media.SIZE} > 0",
                    null,
                    sortOrder
                )?.use { cursor ->
                    val idCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
                    val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
                    val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
                    val durCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
                    val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_MODIFIED)
                    val dataCol = cursor.getColumnIndex(MediaStore.Video.Media.DATA)

                    while (cursor.moveToNext()) {
                        val id = cursor.getLong(idCol)
                        val name = cursor.getString(nameCol) ?: "Video_$id"
                        val size = cursor.getLong(sizeCol)
                        val dur = cursor.getLong(durCol)
                        val date = cursor.getLong(dateCol)
                        val path = if (dataCol >= 0) cursor.getString(dataCol) else null
                        val uri = ContentUris.withAppendedId(
                            MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                            id
                        ).toString()

                        mediaList.add(
                            mapOf(
                                "id" to id.toString(),
                                "uri" to uri,
                                "name" to name,
                                "size" to size,
                                "durationMs" to dur,
                                "dateModified" to date,
                                "path" to path
                            )
                        )
                    }
                }
                mainHandler.post { result.success(mediaList) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("QUERY_ERROR", "Failed to query media: ${e.message}", null)
                }
            }
        }.start()
    }

    private fun handleVerifyOutputFile(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        if (filePath.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "filePath must not be null", null)
            return
        }

        Thread {
            try {
                val file = File(filePath)
                if (!file.exists() || file.length() == 0L) {
                    mainHandler.post {
                        result.success(
                            mapOf(
                                "isValid" to false,
                                "hasAudio" to false,
                                "fileSize" to 0L,
                                "error" to "Output file is missing or empty"
                            )
                        )
                    }
                    return@Thread
                }

                val retriever = MediaMetadataRetriever()
                var hasAudio = false
                var durationMs = 0L
                try {
                    retriever.setDataSource(file.absolutePath)
                    hasAudio = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) != null
                    durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
                } finally {
                    try { retriever.release() } catch (_: Exception) {}
                }

                mainHandler.post {
                    result.success(
                        mapOf(
                            "isValid" to true,
                            "hasAudio" to hasAudio,
                            "fileSize" to file.length(),
                            "durationMs" to durationMs
                        )
                    )
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("VERIFY_ERROR", "Failed to verify output: ${e.message}", null)
                }
            }
        }.start()
    }

    private fun handleGetDeviceSafetyStatus(result: MethodChannel.Result) {
        try {
            val batteryFilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            val batteryStatus: Intent? = registerReceiver(null, batteryFilter)
            val level: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            val batteryPct: Int = if (level >= 0 && scale > 0) ((level / scale.toFloat()) * 100).toInt() else 100

            val status: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val isCharging: Boolean = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                    status == BatteryManager.BATTERY_STATUS_FULL

            var isThermalThrottling = false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                val thermal = powerManager?.currentThermalStatus ?: PowerManager.THERMAL_STATUS_NONE
                isThermalThrottling = thermal >= PowerManager.THERMAL_STATUS_MODERATE
            }

            result.success(
                mapOf(
                    "batteryLevel" to batteryPct,
                    "isCharging" to isCharging,
                    "isThermalThrottling" to isThermalThrottling
                )
            )
        } catch (e: Exception) {
            result.error("SAFETY_ERROR", "Failed to get device safety status: ${e.message}", null)
        }
    }
}
