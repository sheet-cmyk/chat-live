import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final _player = AudioPlayer();
  static Uint8List? _giftSound;

  static Future<void> playGiftSound() async {
    try {
      _giftSound ??= _buildCoinWav();
      await _player.play(BytesSource(_giftSound!));
    } catch (_) {}
  }

  // Generates a metallic coin-ping WAV (880 Hz + harmonics, 600 ms fade-out)
  static Uint8List _buildCoinWav() {
    const sampleRate = 22050;
    const durationMs = 600;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final samples = Int16List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate.toDouble();
      final fade = pow(1.0 - t / (durationMs / 1000.0), 2).toDouble();
      final s = sin(2 * pi * 880 * t) * 0.50 +
                sin(2 * pi * 1320 * t) * 0.30 +
                sin(2 * pi * 1760 * t) * 0.20;
      samples[i] = (s * fade * 0.7 * 32767).round().clamp(-32767, 32767);
    }

    final dataSize = numSamples * 2;
    final buf = ByteData(44 + dataSize);
    _str(buf, 0, 'RIFF');
    buf.setUint32(4, 36 + dataSize, Endian.little);
    _str(buf, 8, 'WAVE');
    _str(buf, 12, 'fmt ');
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little);          // PCM
    buf.setUint16(22, 1, Endian.little);          // mono
    buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, sampleRate * 2, Endian.little);
    buf.setUint16(32, 2, Endian.little);
    buf.setUint16(34, 16, Endian.little);
    _str(buf, 36, 'data');
    buf.setUint32(40, dataSize, Endian.little);
    for (int i = 0; i < numSamples; i++) {
      buf.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return buf.buffer.asUint8List();
  }

  static void _str(ByteData buf, int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      buf.setUint8(offset + i, s.codeUnitAt(i));
    }
  }
}
