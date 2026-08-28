import 'package:flutter/foundation.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class ZegoService {
  static const int appId = 78485764;
  static const String appSign =
      'f7ae5ff7973d075e7fe126f99b60d5ffe06a46ac2459ea3b5722fd5adac7fdcf';

  static final ZegoService _instance = ZegoService._();
  factory ZegoService() => _instance;
  ZegoService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  String? _currentRoomId;
  String? get currentRoomId => _currentRoomId;
  bool get isInRoom => _currentRoomId != null;

  bool _isPublishing = false;
  bool get isPublishing => _isPublishing;

  // مستمعو الأحداث — يربطها RoomScreen
  void Function(String userId, String userName)? onUserJoined;
  void Function(String userId)? onUserLeft;
  void Function(Map<String, double> levels)? onAudioLevel;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await ZegoExpressEngine.createEngineWithProfile(
        ZegoEngineProfile(
          appId,
          ZegoScenario.StandardChatroom,  // multi-person voice, speaker by default
          appSign: appSign,
        ),
      );

      // مستمع دخول/خروج المستخدمين
      ZegoExpressEngine.onRoomUserUpdate = (roomId, updateType, userList) {
        for (final user in userList) {
          if (updateType == ZegoUpdateType.Add) {
            onUserJoined?.call(user.userID, user.userName);
          } else {
            onUserLeft?.call(user.userID);
          }
        }
      };

      // استقبال streams من المستخدمين الآخرين
      ZegoExpressEngine.onRoomStreamUpdate = (roomId, updateType, streamList, extendedData) {
        for (final stream in streamList) {
          if (updateType == ZegoUpdateType.Add) {
            ZegoExpressEngine.instance.startPlayingStream(stream.streamID);
            debugPrint('[Zego] ▶ startPlayingStream: ${stream.streamID}');
          } else {
            ZegoExpressEngine.instance.stopPlayingStream(stream.streamID);
            debugPrint('[Zego] ⏹ stopPlayingStream: ${stream.streamID}');
          }
        }
      };

      ZegoExpressEngine.onRoomStateChanged = (roomId, reason, errorCode, extendedData) {
        debugPrint('[Zego] room state: $reason | error: $errorCode');
      };

      _initialized = true;
      debugPrint('[ZegoService] ✅ تم التهيئة بنجاح (AppID: $appId)');
    } catch (e) {
      debugPrint('[ZegoService] ❌ خطأ في التهيئة: $e');
    }
  }

  Future<void> joinRoom({
    required String roomId,
    required String userId,
    required String userName,
  }) async {
    if (_currentRoomId == roomId) {
      debugPrint('[ZegoService] Already in room $roomId — skipping rejoin');
      return;
    }
    if (!_initialized) {
      await init();
      if (!_initialized) return;
    }
    try {
      final config = ZegoRoomConfig.defaultConfig();
      config.isUserStatusNotify = true;

      await ZegoExpressEngine.instance.loginRoom(
        roomId,
        ZegoUser(userId, userName),
        config: config,
      );

      // Route audio to loudspeaker (default is earpiece for voice calls).
      await ZegoExpressEngine.instance.setAudioRouteToSpeaker(true);

      // Clear any leftover speaker-mute from a previous room session.
      await ZegoExpressEngine.instance.muteAllPlayStreamAudio(false);

      // Do NOT startPublishingStream here — that would capture the microphone
      // even when the user is audience-only, which blocks incoming phone calls.
      // Publishing starts only when the user takes a seat (startPublishing).

      _currentRoomId = roomId;
      debugPrint('[ZegoService] ✅ دخل الغرفة: $roomId');
    } catch (e) {
      debugPrint('[ZegoService] ❌ خطأ في دخول الغرفة: $e');
    }
  }

  // Start capturing the microphone and publishing to the room stream.
  // Must be called when the user takes a seat, not at join time.
  // Safe to call when already publishing (e.g. switching seats) — it will
  // skip startPublishingStream but always unmute the mic and restore the
  // speaker route, which can be reset on some Android devices.
  Future<void> startPublishing(String roomId, String userId) async {
    if (!_initialized) return;
    try {
      if (!_isPublishing) {
        await ZegoExpressEngine.instance.startPublishingStream('${roomId}_$userId');
        _isPublishing = true;
        debugPrint('[ZegoService] 🎙 startPublishing: ${roomId}_$userId');
      }
      // Always unmute mic when called — handles seat-switch-while-muted case.
      await ZegoExpressEngine.instance.muteMicrophone(false);
      // Re-assert loudspeaker routing: Android can reset it after publish starts.
      await ZegoExpressEngine.instance.setAudioRouteToSpeaker(true);
    } catch (e) {
      debugPrint('[ZegoService] ❌ خطأ في startPublishing: $e');
    }
  }

  // Stop publishing and RELEASE the microphone hardware so phone calls work.
  Future<void> stopPublishing() async {
    if (!_initialized || !_isPublishing) return;
    try {
      await ZegoExpressEngine.instance.stopPublishingStream();
      _isPublishing = false;
      debugPrint('[ZegoService] 🎙 stopPublishing — mic released');
    } catch (e) {
      debugPrint('[ZegoService] ❌ خطأ في stopPublishing: $e');
    }
  }

  Future<void> leaveRoom() async {
    if (!_initialized) return;
    try {
      if (_isPublishing) {
        await ZegoExpressEngine.instance.stopPublishingStream();
        _isPublishing = false;
      }
      await ZegoExpressEngine.instance.logoutRoom();
      _currentRoomId = null;
      debugPrint('[ZegoService] تم مغادرة الغرفة');
    } catch (e) {
      debugPrint('[ZegoService] ❌ خطأ في المغادرة: $e');
    }
  }

  Future<void> setMicMuted(bool muted) async {
    if (!_initialized || !_isPublishing) return;
    try {
      await ZegoExpressEngine.instance.muteMicrophone(muted);
      debugPrint('[ZegoService] الميك: ${muted ? "مكتوم" : "مفتوح"}');
    } catch (e) {
      debugPrint('[ZegoService] ❌ خطأ في الكتم: $e');
    }
  }

  Future<void> muteAllAudio(bool muted) async {
    if (!_initialized) return;
    try {
      await ZegoExpressEngine.instance.muteAllPlayStreamAudio(muted);
      debugPrint('[ZegoService] سماعة الغرفة: ${muted ? "مكتومة" : "مفتوحة"}');
    } catch (e) {
      debugPrint('[ZegoService] ❌ خطأ في كتم الغرفة: $e');
    }
  }

  Future<void> setVoiceEffect(ZegoVoiceChangerPreset preset) async {
    if (!_initialized) return;
    try {
      await ZegoExpressEngine.instance.setVoiceChangerPreset(preset);
    } catch (e) {
      debugPrint('[ZegoService] ❌ خطأ في تأثير الصوت: $e');
    }
  }

  Future<void> setSpeakerVolume(int volume) async {
    if (!_initialized) return;
    await ZegoExpressEngine.instance.setPlayVolume('', volume);
  }

  Future<void> setSpeakerEnabled(bool enabled) async {
    if (!_initialized) return;
    await ZegoExpressEngine.instance.setAudioRouteToSpeaker(enabled);
  }

  Future<void> startSoundLevelMonitor() async {
    if (!_initialized) return;
    await ZegoExpressEngine.instance.startSoundLevelMonitor(
      config: ZegoSoundLevelConfig(300, false),
    );
    ZegoExpressEngine.onRemoteSoundLevelUpdate = (soundLevels) {
      onAudioLevel?.call(soundLevels);
    };
  }

  Future<void> stopSoundLevelMonitor() async {
    if (!_initialized) return;
    await ZegoExpressEngine.instance.stopSoundLevelMonitor();
  }

  Future<void> destroy() async {
    if (!_initialized) return;
    try {
      await ZegoExpressEngine.destroyEngine();
      _initialized = false;
      debugPrint('[ZegoService] تم التدمير');
    } catch (e) {
      debugPrint('[ZegoService] ❌ خطأ في التدمير: $e');
    }
  }
}
