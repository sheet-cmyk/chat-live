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

      // بدء البث الصوتي — الميك مكتوم افتراضياً حتى يأخذ المستخدم مقعداً
      await ZegoExpressEngine.instance.startPublishingStream('${roomId}_$userId');
      await ZegoExpressEngine.instance.muteMicrophone(true);

      // Route audio to loudspeaker (default is earpiece for voice calls).
      await ZegoExpressEngine.instance.setAudioRouteToSpeaker(true);

      _currentRoomId = roomId;
      debugPrint('[ZegoService] ✅ دخل الغرفة: $roomId');
    } catch (e) {
      debugPrint('[ZegoService] ❌ خطأ في دخول الغرفة: $e');
    }
  }

  Future<void> leaveRoom() async {
    if (!_initialized) return;
    try {
      await ZegoExpressEngine.instance.stopPublishingStream();
      await ZegoExpressEngine.instance.logoutRoom();
      _currentRoomId = null;
      debugPrint('[ZegoService] تم مغادرة الغرفة');
    } catch (e) {
      debugPrint('[ZegoService] ❌ خطأ في المغادرة: $e');
    }
  }

  Future<void> setMicMuted(bool muted) async {
    if (!_initialized) return;
    try {
      await ZegoExpressEngine.instance.muteMicrophone(muted);
      debugPrint('[ZegoService] الميك: ${muted ? "مكتوم" : "مفتوح"}');
    } catch (e) {
      debugPrint('[ZegoService] ❌ خطأ في الكتم: $e');
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
