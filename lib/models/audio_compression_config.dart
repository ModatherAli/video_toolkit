enum AudioOutputFormat {
  m4a,
  mp3,
  ogg,
  wav,
  flac;

  String get extension => name;
  String get label {
    switch (this) {
      case AudioOutputFormat.m4a:
        return 'M4A (AAC - Highest Compatibility)';
      case AudioOutputFormat.mp3:
        return 'MP3 (Universal Audio)';
      case AudioOutputFormat.ogg:
        return 'OGG (Opus - Ultra Compact)';
      case AudioOutputFormat.wav:
        return 'WAV (Uncompressed)';
      case AudioOutputFormat.flac:
        return 'FLAC (Lossless)';
    }
  }
}

enum AudioPreset {
  voicePodcast,
  lectureSpeech,
  musicHighQuality,
  custom;

  String get title {
    switch (this) {
      case AudioPreset.voicePodcast:
        return 'Voice & Podcast Mode';
      case AudioPreset.lectureSpeech:
        return 'Lecture & Speech Mode';
      case AudioPreset.musicHighQuality:
        return 'Music High Quality';
      case AudioPreset.custom:
        return 'Custom Settings';
    }
  }

  String get subtitle {
    switch (this) {
      case AudioPreset.voicePodcast:
        return 'Mono 64 kbps + loudness leveling. Cuts size by ~70% while keeping speech crisp.';
      case AudioPreset.lectureSpeech:
        return 'Mono 48 kbps + silence trimming. Ideal for hour-long classes & voice notes.';
      case AudioPreset.musicHighQuality:
        return 'Stereo 192 kbps. Preserves rich instruments and full frequency range.';
      case AudioPreset.custom:
        return 'Manually set audio bitrate, channels, and DSP speech filters.';
    }
  }
}

class AudioCompressionConfig {
  final AudioPreset preset;
  final AudioOutputFormat format;
  final int bitrateKbps; // e.g. 64, 96, 128, 192, 320
  final bool isMono;
  final bool trimSilence;
  final bool normalizeLoudness;

  const AudioCompressionConfig({
    required this.preset,
    required this.format,
    required this.bitrateKbps,
    required this.isMono,
    required this.trimSilence,
    required this.normalizeLoudness,
  });

  factory AudioCompressionConfig.fromPreset(AudioPreset preset) {
    switch (preset) {
      case AudioPreset.voicePodcast:
        return const AudioCompressionConfig(
          preset: AudioPreset.voicePodcast,
          format: AudioOutputFormat.m4a,
          bitrateKbps: 64,
          isMono: true,
          trimSilence: true,
          normalizeLoudness: true,
        );
      case AudioPreset.lectureSpeech:
        return const AudioCompressionConfig(
          preset: AudioPreset.lectureSpeech,
          format: AudioOutputFormat.m4a,
          bitrateKbps: 48,
          isMono: true,
          trimSilence: true,
          normalizeLoudness: true,
        );
      case AudioPreset.musicHighQuality:
        return const AudioCompressionConfig(
          preset: AudioPreset.musicHighQuality,
          format: AudioOutputFormat.m4a,
          bitrateKbps: 192,
          isMono: false,
          trimSilence: false,
          normalizeLoudness: false,
        );
      case AudioPreset.custom:
        return const AudioCompressionConfig(
          preset: AudioPreset.custom,
          format: AudioOutputFormat.m4a,
          bitrateKbps: 128,
          isMono: false,
          trimSilence: false,
          normalizeLoudness: false,
        );
    }
  }

  AudioCompressionConfig copyWith({
    AudioPreset? preset,
    AudioOutputFormat? format,
    int? bitrateKbps,
    bool? isMono,
    bool? trimSilence,
    bool? normalizeLoudness,
  }) {
    return AudioCompressionConfig(
      preset: preset ?? this.preset,
      format: format ?? this.format,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
      isMono: isMono ?? this.isMono,
      trimSilence: trimSilence ?? this.trimSilence,
      normalizeLoudness: normalizeLoudness ?? this.normalizeLoudness,
    );
  }

  Map<String, dynamic> toMap({required String sourcePath, required String outputPath}) {
    return {
      'sourcePath': sourcePath,
      'outputPath': outputPath,
      'format': format.name,
      'bitrateKbps': bitrateKbps,
      'isMono': isMono,
      'trimSilence': trimSilence,
      'normalizeLoudness': normalizeLoudness,
    };
  }
}
