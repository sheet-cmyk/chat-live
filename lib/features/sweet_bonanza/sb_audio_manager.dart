import 'package:audioplayers/audioplayers.dart';

class SbAudioManager {
  static final SbAudioManager _instance = SbAudioManager._internal();
  factory SbAudioManager() => _instance;

  final AudioPlayer _musicPlayer;
  final AudioPlayer _sfxPlayer;

  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _isMusicPlaying = false;

  SbAudioManager._internal()
      : _musicPlayer = AudioPlayer(),
        _sfxPlayer = AudioPlayer() {
    // Keep _isMusicPlaying in sync with actual player state.
    _musicPlayer.onPlayerStateChanged.listen((state) {
      _isMusicPlaying = state == PlayerState.playing;
    });
  }

  bool get isMusicPlaying => _isMusicPlaying;

  void toggleSound(bool enabled) => _soundEnabled = enabled;

  void toggleMusic(bool enabled) {
    _musicEnabled = enabled;
    if (!enabled) stopMusic();
  }

  Future<void> playSfx(String assetPath) async {
    if (!_soundEnabled) return;
    try {
      final path = assetPath.startsWith('assets/')
          ? assetPath.substring('assets/'.length)
          : assetPath;
      await _sfxPlayer.play(AssetSource(path));
    } catch (_) {}
  }

  Future<void> playBackgroundMusic(String assetPath, {bool loop = true}) async {
    if (!_musicEnabled || _isMusicPlaying) return;
    try {
      final path = assetPath.startsWith('assets/')
          ? assetPath.substring('assets/'.length)
          : assetPath;
      await _musicPlayer.setReleaseMode(
          loop ? ReleaseMode.loop : ReleaseMode.release);
      await _musicPlayer.play(AssetSource(path));
      _isMusicPlaying = true;
    } catch (_) {}
  }

  Future<void> pauseBackgroundMusic() async {
    try {
      await _musicPlayer.pause();
    } catch (_) {}
    _isMusicPlaying = false;
  }

  Future<void> resumeBackgroundMusic() async {
    if (!_musicEnabled || _isMusicPlaying) return;
    try {
      await _musicPlayer.resume();
      _isMusicPlaying = true;
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    try {
      await _musicPlayer.stop();
    } catch (_) {}
    _isMusicPlaying = false;
  }

  Future<void> dispose() async {
    await _musicPlayer.dispose();
    await _sfxPlayer.dispose();
  }
}
