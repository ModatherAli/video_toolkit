# OptiVideo — Offline Video Compressor for Android

**OptiVideo** is a modern, lightweight, privacy-focused Android video compression utility built with Flutter and **AndroidX Media3 Transformer**. It enables users to compress and optimize video files directly on their devices using hardware acceleration—completely offline, without accounts, subscriptions, or external servers.

---

## 🌟 Key Highlights

- **100% Offline Processing**: The application does not declare `android.permission.INTERNET`. Zero network access ensures videos never leave the device.
- **Hardware-Accelerated Native Transcoding**: Powered by Google's modern **AndroidX Media3 Transformer** pipeline using on-device `MediaCodec` encoders (H.264 / AAC) rather than bloated, battery-draining C++ FFmpeg wrappers.
- **Lightweight APK Footprint**: Eliminates massive 40–80 MB FFmpeg binaries, keeping the app lightweight and fast.
- **Genuine Progress Updates**: Tracks live hardware encoder progress via `Transformer.getProgress()`.
- **Scoped Storage Compliant**: Directly exports to the device's public `Movies/OptiVideo` collection using Android `MediaStore` without requiring risky broad file permissions on Android 10+.
- **Universal MP4 Compatibility**: Outputs standard H.264 video with AAC audio playable on all Android, iOS, Windows, and web players.
- **Uptodown & Third-Party Store Ready**: Optimized for distribution across Uptodown, F-Droid, and third-party Android application repositories.

---

## 📱 Main User Journey

1. **Home Screen**: View free storage capacity, privacy guarantee, and recent compressions.
2. **Video Selection**: Pick a video from gallery or file manager (handles both `content://` URIs and file paths).
3. **Metadata & Preview**: View duration, resolution, size, bitrate, orientation, and thumbnail.
4. **Preset or Custom Settings**:
   - **High Quality**: Retains source resolution (up to 1080p), moderate compression (~85% target bitrate).
   - **Balanced (Recommended)**: Targets 720p HD with optimal bitrate (~2.2 Mbps), ideal for WhatsApp/Telegram.
   - **Small Size**: Downscales to 480p SD with aggressive compression (~900 kbps) for minimal file size.
   - **Custom**: Choose target resolution (Original, 1080p, 720p, 480p, 360p with no-upscaling protection), video bitrate slider, and audio toggle.
5. **Real-Time Transcoding**: Monitor hardware progress bar, percentage, elapsed time, with the ability to safely cancel anytime.
6. **Results & Actions**:
   - Compare original vs. compressed size, total MB saved, percentage reduction, and encoding duration.
   - Built-in video player preview.
   - One-tap "Save to Gallery" (`Movies/OptiVideo`).
   - System share sheet integration (`SharePlus`).
   - "Open with..." system player or compress another video.
7. **Local History**: Persistent compression history stored locally in app documents (`optivideo_history.json`). Tracks total lifetime storage saved, with options to play, share, or delete entries (with optional physical file deletion).

---

## 🏗️ Architecture & Technology Stack

```
lib/
├── main.dart                               # Entry point, initializes local history & services
├── app.dart                                # MaterialApp, Theme configuration (Light/Dark M3)
├── models/
│   ├── video_info.dart                     # Video metadata model (duration, dimensions, bitrate, thumb)
│   ├── compression_config.dart             # Preset definitions and encoder configuration builder
│   ├── compression_progress.dart           # Event-driven progress status model
│   └── history_item.dart                   # Persistent history item model with savings calculators
├── services/
│   ├── video_compressor_service.dart       # Platform channel bridge (MethodChannel + EventChannel)
│   └── history_repository.dart             # Pure Dart JSON file storage with reactive ValueNotifier
├── theme/
│   ├── app_colors.dart                     # Tailored Material 3 palette (Indigo primary, Emerald savings)
│   └── app_theme.dart                      # High-contrast light and dark themes
├── utils/
│   ├── formatters.dart                     # Byte sizes, durations, bitrates, and dates
│   └── video_calculator.dart               # Aspect ratio scaling (even dimension guard) & bitrates
└── screens/
    ├── home/                               # Home dashboard with storage status & recent compressions
    ├── setup/                              # Video summary, preset picker, and custom settings
    ├── processing/                         # Active hardware compression progress screen
    ├── result/                             # Results screen with preview player & savings breakdown
    └── history/                            # Full history screen with search & storage metrics
```

### Android Native Layer (`android/app/src/main/kotlin/.../MainActivity.kt`)
- **`com.modatherali.video_toolkit/compressor`**:
  - `pickVideo`: System media picker with automatic fallback.
  - `getVideoMetadata`: Extracts metadata using `MediaMetadataRetriever` (rotation-aware, generates thumbnail).
  - `startCompression`: Configures `EditedMediaItem`, `Presentation` effect for scaling, `VideoEncoderSettings` for target bitrate, and starts `Transformer`.
  - `cancelCompression`: Safely cancels transcoding and cleans up partial files.
  - `saveToGallery`: Inserts video into Android `MediaStore.Video.Media` (scoped storage).
  - `getAvailableStorage`: Real-time free block query via `StatFs`.
  - `openVideoFile`: Launches `ACTION_VIEW` intent with `FileProvider`.
- **`com.modatherali.video_toolkit/compression_events`**:
  - Streams hardware progress (0–100%) polled directly from `Transformer.getProgress()`.

---

## ⚖️ Technical Rationale: AndroidX Media3 Transformer vs FFmpeg

| Criteria | AndroidX Media3 Transformer (OptiVideo) | FFmpeg Wrappers |
|---|---|---|
| **App Size Impact** | ~2–3 MB | 40–80 MB (contains 4 ABIs of native `.so` files) |
| **Hardware Encoding** | Native `MediaCodec` hardware pipelines | Often falls back to CPU `libx264`, draining battery |
| **Battery & Heat** | Low power consumption via dedicated silicon | High CPU usage and device heating |
| **Licensing** | Apache 2.0 (Google Media3) | LGPL/GPL (legal complexity for store distribution) |
| **Memory Footprint** | Direct surface streaming via OpenGL ES | High RAM usage buffering video frames |
| **Offline Safety** | 100% on-device | 100% on-device |

---

## 🚀 Building & Running

### Prerequisites
- Flutter SDK 3.22+ (tested with Flutter 3.44.4 / Dart 3.12.2)
- Android SDK (API level 24+)
- JDK 17

### Commands

1. **Get dependencies**:
   ```bash
   flutter pub get
   ```

2. **Run tests**:
   ```bash
   flutter test
   ```

3. **Run on connected device**:
   ```bash
   flutter run -d <device_id>
   ```

4. **Build Release APK**:
   ```bash
   flutter build apk --release
   ```
   The output APK will be located at:
   `build/app/outputs/flutter-apk/app-release.apk`

---

## 🔒 Privacy & Permissions

- **`INTERNET` permission**: **NOT requested**. OptiVideo cannot communicate over the internet.
- **Storage permissions**:
  - Android 10+ (API 29–36): Uses **Scoped Storage** and **Android MediaStore API**. No storage permissions required to read selected videos or save compressed outputs to the gallery.
  - Android 9 and lower: Declares `READ_EXTERNAL_STORAGE` (maxSdkVersion 32) and `WRITE_EXTERNAL_STORAGE` (maxSdkVersion 28) for backwards compatibility.

---

## 📄 Tested Features & Validations

1. **Hardware Transcoding**: Verified compilation and execution with `androidx.media3:media3-transformer:1.4.1`.
2. **Dimension Scaling**: Tested landscape and portrait aspect-ratio scaling with strict 2-pixel even alignment to prevent encoder crashes.
3. **No-Upscaling Protection**: Automatically prevents upscaling source videos beyond native resolution.
4. **Real-Device Deployment**: Verified on real physical Android device running Android 16 (API 36).
5. **Impeller Vulkan Backend**: Verified launch and rendering under Flutter's Impeller Vulkan engine.
6. **Local Persistence**: Pure Dart JSON repository in app documents (`optivideo_history.json`), verified resilient to app restarts and free from native JNI/Pigeon version mismatch bugs.
