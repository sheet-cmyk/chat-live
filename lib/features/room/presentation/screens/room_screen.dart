import 'dart:async';
import 'dart:math' show pi, cos, sin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../home/data/repositories/room_history_repository.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/models/seat_model.dart';
import '../../../home/data/models/room_model.dart';
import '../../../home/presentation/screens/create_room_sheet.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../providers/room_provider.dart';
import '../widgets/seat_widget.dart';
import '../widgets/room_chat_messages.dart';
import '../widgets/room_bottom_bar.dart';
import '../../../../core/services/zego_service.dart';
import '../../../../core/providers/active_room_provider.dart';
import '../../../gift/presentation/widgets/gift_panel.dart';
import '../../../gift/presentation/widgets/gift_animation_overlay.dart';
import '../../../gift/data/models/gift_model.dart';
import '../../../gift/presentation/providers/gift_provider.dart';
import '../../../../core/services/sound_service.dart';
import '../../data/models/room_message_model.dart';
import '../../data/repositories/room_state_repository.dart';
import '../widgets/user_profile_sheet.dart';
import '../widgets/room_announcement_banner.dart';
import '../widgets/night_sky_background.dart';
import '../widgets/sound_effects_panel.dart';
import '../widgets/pk_bar.dart';
import '../../../admin/presentation/providers/admin_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../app/theme/chat_colors.dart';
import '../../../games/dice_game/providers/dice_game_providers.dart';
import '../../../games/dice_game/dice_game_panel.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key, required this.room});
  final RoomModel room;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen>
    with WidgetsBindingObserver {
  final _scrollCtrl = ScrollController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  late final String _roomId;
  bool _leftCleanly = false;
  String _announcement = '';
  late final DateTime _joinedAt;
  String? _lastGiftMsgId;
  String? _coverImageUrl;
  String? _lastEmojiMsgId;
  final Map<int, EmojiTrigger> _seatEmoji = {};
  int _cachedSeat = -1;              // updated in build — avoids ref.read in dispose
  StreamSubscription<bool>? _kickSub; // cancelled in dispose

  @override
  void initState() {
    super.initState();
    _roomId = widget.room.roomId;
    _coverImageUrl = widget.room.coverImage;
    _joinedAt = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initRoom());
  }

  Future<void> _initRoom() async {
    final me = _currentUser;
    if (me == null) return;

    final isHost = widget.room.hostUid == me.uid;
    ref.read(isHostProvider.notifier).state = isHost;
    ref.read(currentRoomProvider.notifier).state = widget.room;

    final zego = ZegoService();
    final isRestored = zego.currentRoomId == _roomId;

    if (!isRestored) {
      ref.read(myCurrentSeatProvider.notifier).state = -1;

      // احفظ في سجل الغرف المزارة
      RoomHistoryRepository().addRoom(widget.room);

      // سجّل في Firestore كعضو
      await RoomStateRepository().joinRoom(
        roomId: _roomId,
        userId: me.uid,
        userName: me.displayName ?? 'مستخدم',
        userAvatar: me.photoURL,
      );

      // حمّل الإعلان من Firestore
      final doc = await FirebaseFirestore.instance.collection('rooms').doc(_roomId).get();
      if (mounted) {
        final ann = doc.data()?['announcement'] as String? ?? '';
        if (ann.isNotEmpty) setState(() => _announcement = ann);
      }

      // أرسل رسالة انضمام
      await ref.read(chatWriterProvider(_roomId)).sendSystem(
        '${me.displayName ?? 'مستخدم'} انضم للغرفة 🎉',
      );

      // طلب إذن الميكروفون
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (mounted) _showSnack('يرجى السماح باستخدام الميكروفون للانضمام للغرفة');
      }

      // تهيئة ZEGOCLOUD وانضمام للغرفة
      await zego.init();
      await zego.joinRoom(
        roomId: _roomId,
        userId: me.uid,
        userName: me.displayName ?? 'مستخدم',
      );

      // mic stays muted until user takes a seat
      ref.read(isMicMutedProvider.notifier).state = true;

      await zego.startSoundLevelMonitor();

    // استمع لقرار الطرد من الغرفة
    _kickSub = RoomStateRepository().watchRoomKick(_roomId, me.uid).listen((kicked) {
      if (kicked && mounted) {
        _leftCleanly = false;
        _cleanup();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('🚫 تم طردك من الغرفة', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.red,
          ));
        }
      }
    });
    }

    // سجّل الـ callbacks في كل مرة (بما فيها الاستعادة من التصغير)
    zego.onUserJoined = (userId, userName) async {
      if (!mounted) return;
    };
    zego.onUserLeft = (userId) async {
      if (!mounted) return;
      try {
        final seats = ref.read(seatsProvider(_roomId));
        final seat = seats.firstWhere(
          (s) => s.userId == userId,
          orElse: () => const SeatModel(index: -1),
        );
        if (seat.index >= 0) {
          await ref.read(seatsWriterProvider(_roomId)).leaveSeatIfOwner(seat.index, userId);
          if (seat.index == ref.read(myCurrentSeatProvider)) {
            ref.read(myCurrentSeatProvider.notifier).state = -1;
          }
        }
      } catch (_) {}
    };

    zego.onAudioLevel = (levels) {
      if (!mounted) return;
      try {
        ref.read(speakingUsersProvider.notifier).state = {
          for (final e in levels.entries)
            if (e.value > 10) e.key,
        };
      } catch (_) {}
    };
  }

  // تصغير الغرفة لفقاعة عائمة — ينزل من المايك تلقائياً
  void _minimizeRoom() {
    final me = _currentUser;
    if (me == null) {
      Navigator.of(context).pop();
      return;
    }
    // ينزل من المقعد عند التصغير أو الانتقال لغرفة ثانية
    _leaveSeatOnly();
    _leftCleanly = true; // منع cleanup عند dispose
    ref.read(minimizedRoomProvider.notifier).state = MinimizedRoomState(
      room: widget.room,
      mySeat: -1, // مقعد فارغ لأننا نزلنا
      userId: me.uid,
      userName: me.displayName ?? 'مستخدم',
    );
    Navigator.of(context).pop();
  }

  // خروج كلي من الغرفة — ينزل من المايك ويغادر ZEGO
  Future<void> _leaveRoom() async {
    // امسح حالة التصغير إن وجدت
    ref.read(minimizedRoomProvider.notifier).state = null;
    // أجبر cleanup يعمل حتى لو _leftCleanly كان true سابقاً
    _leftCleanly = false;
    final savedSeat = ref.read(myCurrentSeatProvider);
    await _cleanup(savedSeat: savedSeat);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // المستخدم أغلق التطبيق أو ذهب للخلفية → ينزل من المايك تلقائياً
    if (state == AppLifecycleState.paused) {
      _leaveSeatOnly();
    }
  }

  // ينزل من المايك فقط دون مغادرة الغرفة
  void _leaveSeatOnly() {
    final mySeat = ref.read(myCurrentSeatProvider);
    if (mySeat < 0) return;
    final me = _currentUser;
    if (me == null) return;
    RoomStateRepository().leaveSeatIfOwner(_roomId, mySeat, me.uid);
    ref.read(myCurrentSeatProvider.notifier).state = -1;
    ZegoService().stopPublishing();   // release mic so phone calls work
    ref.read(isMicMutedProvider.notifier).state = true;
  }

  @override
  void dispose() {
    _kickSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scrollCtrl.dispose();
    _cleanup(savedSeat: _cachedSeat); // use cached value — never touch ref in dispose
    super.dispose();
  }

  Future<void> _cleanup({int savedSeat = -1}) async {
    if (_leftCleanly) return;
    _leftCleanly = true;

    final me = _currentUser;
    final zego = ZegoService();
    zego.onUserJoined = null;
    zego.onUserLeft = null;
    zego.onAudioLevel = null;
    await zego.stopSoundLevelMonitor();
    await zego.leaveRoom();

    if (me == null) return;

    // Clear our seat only if we still own it (guards against re-entry race).
    if (savedSeat >= 0) {
      await RoomStateRepository().leaveSeatIfOwner(_roomId, savedSeat, me.uid);
    }

    // رسالة مغادرة
    await RoomStateRepository().sendMessage(
      _roomId,
      RoomMessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: '${me.displayName ?? 'مستخدم'} غادر الغرفة',
        type: MessageType.system,
        createdAt: DateTime.now(),
      ),
    );

    // حذف من members + تنقيص العداد
    await RoomStateRepository().leaveRoom(roomId: _roomId, userId: me.uid);
  }

  Future<void> _onSeatTap(SeatModel seat) async {
    final me = _currentUser;
    if (me == null) return;
    final isHost = ref.read(isHostProvider);

    // تصوير مقعدي → اعرض ملفي الشخصي
    if (!seat.isEmpty && seat.userId == me.uid) {
      _showMyProfile(seat);
      return;
    }

    if (!seat.isEmpty) {
      if (isHost) {
        _showHostSeatMenu(seat);
      } else {
        _showUserProfile(seat);
      }
      return;
    }

    if (seat.isLocked) {
      _showSnack('هذا المقعد مقفل');
      return;
    }

    final mySeat = ref.read(myCurrentSeatProvider);
    final seatProfile = ref.read(userProfileStreamProvider).valueOrNull;

    // ── تحديث فوري للـ UI (optimistic) ──────────────────────────────
    final patchNotifier = ref.read(optimisticSeatsProvider(_roomId).notifier);
    final newSeatModel = SeatModel(
      index: seat.index,
      userId: me.uid,
      userName: me.displayName ?? 'مستخدم',
      userAvatar: me.photoURL,
      nameColor: seatProfile?['nameColor'] as String?,
    );
    patchNotifier.state = {
      ...patchNotifier.state,
      if (mySeat >= 0) mySeat: null, // أفرغ القديم فوراً
      seat.index: newSeatModel,      // احجز الجديد فوراً
    };

    // ── اكتب Firestore في الخلفية (بدون await) ───────────────────────
    if (mySeat >= 0) {
      ref.read(seatsWriterProvider(_roomId)).leaveSeatIfOwner(mySeat, me.uid);
    }
    ref.read(seatsWriterProvider(_roomId)).takeSeat(
      seat.index,
      userId: me.uid,
      userName: me.displayName ?? 'مستخدم',
      userAvatar: me.photoURL,
      nameColor: seatProfile?['nameColor'] as String?,
    );

    ref.read(myCurrentSeatProvider.notifier).state = seat.index;
    // Start capturing mic only now (releases it when user leaves the seat)
    await ZegoService().startPublishing(_roomId, me.uid);
    ref.read(isMicMutedProvider.notifier).state = false;
  }

  void _showMyProfile(SeatModel seat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MyProfileSheet(
        userId: seat.userId ?? '',
        userName: seat.userName ?? 'أنا',
        userAvatar: seat.userAvatar,
        onLeaveSeat: () => _doLeaveSeat(seat.index),
        onSendEmoji: (emoji) {
          final me = _currentUser;
          if (me == null) return;
          ref.read(chatWriterProvider(_roomId)).sendEmojiReaction(
            senderId: me.uid,
            senderName: seat.userName ?? me.displayName ?? 'أنا',
            emoji: emoji,
          );
        },
      ),
    );
  }

  void _doLeaveSeat(int index) {
    final me = _currentUser;
    if (me != null) {
      ref.read(seatsWriterProvider(_roomId)).leaveSeatIfOwner(index, me.uid);
    } else {
      ref.read(seatsWriterProvider(_roomId)).leaveSeat(index);
    }
    ref.read(myCurrentSeatProvider.notifier).state = -1;
    // Release the microphone so incoming phone calls can use it
    ZegoService().stopPublishing();
    ref.read(isMicMutedProvider.notifier).state = true;
  }

  void _showUserProfile(SeatModel seat) {
    final isAdmin = ref.read(isAdminProvider).valueOrNull == true;
    final isHost = ref.read(isHostProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => UserProfileSheet(
        roomId: _roomId,
        targetUserId: seat.userId ?? '',
        targetUserName: seat.userName ?? 'مستخدم',
        targetUserAvatar: seat.userAvatar,
        seatIndex: seat.index,
        isSeatMuted: seat.isMuted,
        isAdmin: isAdmin,
        isHost: isHost,
      ),
    );
  }

  void _showUserProfileFromChat(String userId, String userName, String? avatar) {
    if (userId == (_currentUser?.uid ?? '')) return; // لا تُظهر قائمة لنفسك
    final isAdmin = ref.read(isAdminProvider).valueOrNull == true;
    final isHost = ref.read(isHostProvider);
    // ابحث عن مقعده إن وجد
    final seats = ref.read(seatsProvider(_roomId));
    final seat = seats.firstWhere((s) => s.userId == userId, orElse: () => const SeatModel(index: -1));
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => UserProfileSheet(
        roomId: _roomId,
        targetUserId: userId,
        targetUserName: userName,
        targetUserAvatar: avatar,
        seatIndex: seat.index >= 0 ? seat.index : null,
        isSeatMuted: seat.index >= 0 ? seat.isMuted : false,
        isAdmin: isAdmin,
        isHost: isHost,
      ),
    );
  }

  void _showHostSeatMenu(SeatModel seat) {
    // استخدم UserProfileSheet الموحّد للمضيف أيضاً
    _showUserProfile(seat);
  }

  void _sendMessage(String text, String? textColor) {
    final me = _currentUser;
    if (me == null || text.isEmpty) return;
    final profile = ref.read(userProfileStreamProvider).valueOrNull;
    ref.read(chatWriterProvider(_roomId)).sendUserMessage(
      senderId: me.uid,
      senderName: me.displayName ?? 'مستخدم',
      senderAvatar: me.photoURL,
      content: text,
      nameColor: profile?['nameColor'] as String?,
      textColor: textColor ?? profile?['textColor'] as String?,
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.surface),
    );
  }

  void _showEditRoom() {
    showEditRoomSheet(context, widget.room);
  }

  void _showSoundEffects() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SoundEffectsPanel(
        onSend: (emoji, label) async {
          final me = _currentUser;
          if (me == null) return;
          await ref.read(chatWriterProvider(_roomId)).sendSystem('$emoji ${me.displayName ?? 'مستخدم'} أرسل $label');
        },
      ),
    );
  }

  void _showEditAnnouncement() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => EditAnnouncementSheet(
        current: _announcement,
        onSave: (text) {
          setState(() => _announcement = text);
          // احفظه في Firestore
          FirebaseFirestore.instance.collection('rooms').doc(_roomId).update({'announcement': text}).catchError((_) {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seats = ref.watch(seatsProvider(_roomId));
    final messagesAsync = ref.watch(roomChatStreamProvider(_roomId));
    final messages = messagesAsync.valueOrNull ?? [];
    final isHost = ref.watch(isHostProvider);
    final isAdmin = ref.watch(isAdminProvider).valueOrNull == true;
    final challengeActive = ref.watch(challengeEndTimeProvider(_roomId)).valueOrNull != null;
    final pk = ref.watch(pkStateProvider(_roomId)).valueOrNull;
    final pkActive = pk != null && pk.active;
    final maxSeats = ref.watch(roomMaxSeatsProvider(_roomId)).valueOrNull ?? seats.length;

    // ── امسح الـ patches بعد تأكيد Firestore ─────────────────────────
    ref.listen(roomSeatsStreamProvider(_roomId), (_, __) {
      final patches = ref.read(optimisticSeatsProvider(_roomId));
      if (patches.isNotEmpty) {
        ref.read(optimisticSeatsProvider(_roomId).notifier).state = {};
      }
    });

    // ── كاش مقعد المستخدم لاستخدامه في dispose بدون ref ──────────
    _cachedSeat = ref.watch(myCurrentSeatProvider);

    // ── مزامنة حالة المقعد من Firestore إلى Zego ──────────────────
    // Handles: host muting a user, and detecting when kicked from seat.
    ref.listen<List<SeatModel>>(seatsProvider(_roomId), (_, seats) {
      if (!mounted) return;
      final mySeat = ref.read(myCurrentSeatProvider);
      if (mySeat < 0 || mySeat >= seats.length) return;
      final mySeatData = seats[mySeat];
      final uid = _currentUser?.uid;
      if (uid == null) return;

      if (mySeatData.isEmpty || mySeatData.userId != uid) {
        // Kicked by host — reset local state and mute mic.
        ref.read(myCurrentSeatProvider.notifier).state = -1;
        if (!ref.read(isMicMutedProvider)) {
          ref.read(isMicMutedProvider.notifier).state = true;
          ZegoService().setMicMuted(true);
        }
        return;
      }

      // Sync host's mute toggle from Firestore to actual Zego mic.
      final firestoreMuted = mySeatData.isMuted;
      if (firestoreMuted != ref.read(isMicMutedProvider)) {
        ref.read(isMicMutedProvider.notifier).state = firestoreMuted;
        ZegoService().setMicMuted(firestoreMuted);
      }
    });

    // مرر للأسفل عند وصول رسائل جديدة + كشف هدايا جديدة للأنيميشن
    ref.listen(roomChatStreamProvider(_roomId), (_, next) {
      if (!mounted) return;
      if (!next.hasValue) return;
      final msgs = next.value!;

      // تمرير تلقائي للأسفل — في reverse list، أحدث رسالة عند position 0
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients && _scrollCtrl.position.pixels != 0) {
          _scrollCtrl.animateTo(
            0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });

      // كشف رسائل الهدايا الجديدة وإطلاق الأنيميشن + الصوت لجميع الأعضاء
      final giftMsgs = msgs.where((m) => m.type == MessageType.gift).toList();
      if (giftMsgs.isEmpty) return;
      final latest = giftMsgs.last;
      if (latest.id == _lastGiftMsgId) return; // لم تتغير
      final isNew = latest.createdAt.isAfter(_joinedAt);
      _lastGiftMsgId = latest.id;
      if (!isNew) return; // هدية قديمة قبل انضمامنا

      ref.read(activeGiftAnimProvider.notifier).state = GiftSentRecord(
        id: latest.id,
        roomId: _roomId,
        senderId: latest.senderId ?? '',
        senderName: latest.senderName ?? '',
        senderAvatar: latest.senderAvatar,
        giftId: '',
        giftName: '',
        giftEmoji: latest.giftEmoji ?? '🎁',
        coinPrice: 0,
        diamondValue: 0,
        sentAt: latest.createdAt,
      );
      SoundService.playGiftSound();
    });

    // كشف ردود الفعل بالإيموجي وإظهارها فوق مقعد المرسل
    ref.listen(roomChatStreamProvider(_roomId), (_, next) {
      if (!mounted) return;
      if (!next.hasValue) return;
      final emojiMsgs = next.value!.where((m) => m.type == MessageType.emoji).toList();
      if (emojiMsgs.isEmpty) return;
      final latest = emojiMsgs.last;
      if (latest.id == _lastEmojiMsgId) return;
      if (!latest.createdAt.isAfter(_joinedAt)) return;
      _lastEmojiMsgId = latest.id;
      final currentSeats = ref.read(seatsProvider(_roomId));
      final seatIdx = currentSeats.indexWhere((s) => s.userId == latest.senderId);
      if (seatIdx < 0) return;
      setState(() => _seatEmoji[seatIdx] = EmojiTrigger(latest.content));
    });

    // مزامنة عدد الزوار الحقيقي مع حقل onlineCount لبطاقات الغرف
    ref.listen(memberCountProvider(_roomId), (_, next) {
      if (!mounted || !next.hasValue) return;
      try {
        FirebaseFirestore.instance
            .collection('rooms')
            .doc(_roomId)
            .update({'onlineCount': next.value!});
      } catch (_) {}
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _minimizeRoom();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            _RoomBackground(coverImage: _coverImageUrl),
            const Positioned.fill(child: NightSkyBackground()),

            Column(
              children: [
                _RoomHeader(
                  room: widget.room,
                  onMinimize: _minimizeRoom,
                  onLeave: () => _leaveRoom(),
                  onVisitorTap: _showUserProfileFromChat,
                  isHost: isHost,
                  isAdmin: isAdmin,
                  onSettings: () => _showSettings(context),
                ),

                // شريط هدايا التحدي (يظهر فقط عند وجود تحدي نشط)
                _ChallengeGiftBar(roomId: _roomId),

                // شريط PK Battle
                PKBar(roomId: _roomId, isHost: isHost),

                // شبكة المقاعد
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: challengeActive
                      ? _buildTeamBattleLayout(seats)
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _seatColumns(seats.length),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 4,
                            childAspectRatio: 0.62,
                          ),
                          itemCount: seats.length,
                          itemBuilder: (_, i) {
                            final seat = seats[i];
                            final pkTeam = pkActive
                                ? (seat.index < maxSeats ~/ 2 ? 1 : 2)
                                : 0;
                            return SeatWidget(
                              seat: seat,
                              isHost: false,
                              isMe: seat.userId == _currentUser?.uid,
                              onTap: () => _onSeatTap(seat),
                              emojiTrigger: _seatEmoji[seat.index],
                              challengeActive: challengeActive,
                              pkTeam: pkTeam,
                            );
                          },
                        ),
                ),

                // بانر الإعلان
                if (_announcement.isNotEmpty)
                  RoomAnnouncementBanner(text: _announcement),

                // منطقة الدردشة
                Expanded(
                  child: RoomChatMessages(
                    messages: messages,
                    scrollController: _scrollCtrl,
                    onUserTap: _showUserProfileFromChat,
                  ),
                ),
              ],
            ),

            // شريط الإدخال — Positioned فوق الكيبورد دائماً
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: RoomBottomBar(
                onSendMessage: (text, color) => _sendMessage(text, color),
                onGift: () => _showGiftPanel(context),
                onSettings: () => _showSettings(context),
                onSoundEffects: _showSoundEffects,
                isHost: isHost,
                isAdmin: isAdmin,
                roomId: _roomId,
                currentUserId: _currentUser?.uid ?? '',
              ),
            ),

            // أنيميشن الهدايا
            const GiftAnimationOverlay(),

            // ── لوحة لعبة النرد (overlay سفلي) ──────────────────────
            _DiceGameOverlay(roomId: _roomId),
          ],
        ),
      ),
    ));
  }

  int _seatColumns(int count) {
    if (count <= 3) return 3;
    if (count <= 5) return 5;
    if (count <= 10) return 5;
    return 5;
  }

  Widget _buildTeamBattleLayout(List<SeatModel> seats) {
    if (seats.isEmpty) return const SizedBox.shrink();

    const deepBlue = Color(0xFF0A1EA8);
    const deepRed  = Color(0xFFA80A0A);

    final hostSeat = seats[0];
    final rest     = seats.length > 1 ? seats.sublist(1) : const <SeatModel>[];
    final half     = (rest.length / 2).ceil();
    final teamA    = rest.sublist(0, half);
    final teamB    = half < rest.length ? rest.sublist(half) : const <SeatModel>[];
    final rowCount = ((teamA.length > teamB.length ? teamA.length : teamB.length) / 2).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // مقعد المضيف في المنتصف
        SeatWidget(
          seat: hostSeat,
          isHost: true,
          isMe: hostSeat.userId == _currentUser?.uid,
          onTap: () => _onSeatTap(hostSeat),
          emojiTrigger: _seatEmoji[hostSeat.index],
          challengeActive: true,
          pkTeam: 0,
        ),
        const SizedBox(height: 8),
        if (rest.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: deepBlue, borderRadius: BorderRadius.circular(20)),
                    child: const Text('💙 أزرق', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: deepRed, borderRadius: BorderRadius.circular(20)),
                    child: const Text('❤️ أحمر', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(rowCount, (rowIdx) {
            final aStart = rowIdx * 2;
            final bStart = rowIdx * 2;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (int c = 0; c < 2; c++)
                          if (aStart + c < teamA.length)
                            SeatWidget(
                              seat: teamA[aStart + c],
                              isHost: false,
                              isMe: teamA[aStart + c].userId == _currentUser?.uid,
                              onTap: () => _onSeatTap(teamA[aStart + c]),
                              emojiTrigger: _seatEmoji[teamA[aStart + c].index],
                              challengeActive: true,
                              pkTeam: 1,
                            )
                          else
                            const SizedBox(width: 62),
                      ],
                    ),
                  ),
                  Container(width: 1, color: Colors.white24),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (int c = 0; c < 2; c++)
                          if (bStart + c < teamB.length)
                            SeatWidget(
                              seat: teamB[bStart + c],
                              isHost: false,
                              isMe: teamB[bStart + c].userId == _currentUser?.uid,
                              onTap: () => _onSeatTap(teamB[bStart + c]),
                              emojiTrigger: _seatEmoji[teamB[bStart + c].index],
                              challengeActive: true,
                              pkTeam: 2,
                            )
                          else
                            const SizedBox(width: 62),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  void _showGiftPanel(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GiftPanel(roomId: _roomId),
    );
  }

  Future<void> _pickCoverFromRoom() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;
    try {
      final Uint8List bytes = await picked.readAsBytes();
      final storageRef = FirebaseStorage.instance.ref('room_covers/$_roomId/cover.jpg');
      await storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await storageRef.getDownloadURL();
      await ref.read(roomRepositoryProvider).updateRoom(_roomId, coverImage: url);
      if (mounted) setState(() => _coverImageUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تحديث صورة الغرفة'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showSettings(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RoomSettingsSheet(
        roomId: _roomId,
        onEditAnnouncement: _showEditAnnouncement,
        onEditRoom: _showEditRoom,
        onChangeCover: _pickCoverFromRoom,
      ),
    );
  }
}

// ── لوحة النرد كـ overlay ───────────────────────────────────────────
class _DiceGameOverlay extends ConsumerWidget {
  const _DiceGameOverlay({required this.roomId});
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible   = ref.watch(diceGameVisibleProvider);
    final activeRoomId = ref.watch(diceGameRoomIdProvider);
    if (!isVisible || activeRoomId != roomId) return const SizedBox.shrink();

    final mq          = MediaQuery.of(context);
    final screenHeight = mq.size.height;
    // ارفع اللوحة فوق navigation bar الهاتف
    final navBarHeight = mq.viewPadding.bottom;

    return Positioned(
      left: 0, right: 0,
      bottom: navBarHeight,           // فوق أزرار الهاتف مباشرةً
      height: screenHeight * 0.56,
      child: DiceGamePanel(
        roomId: roomId,
        onClose: () {
          ref.read(diceGameVisibleProvider.notifier).state = false;
        },
      ),
    );
  }
}

// ── خلفية الغرفة ──────────────────────────────────────────────────
class _RoomBackground extends StatelessWidget {
  const _RoomBackground({this.coverImage});
  final String? coverImage;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base: cover image or dark gradient
        if (coverImage != null)
          CachedNetworkImage(
            imageUrl: coverImage!,
            fit: BoxFit.cover,
            placeholder: (_, __) => _darkBase(),
            errorWidget: (_, __, ___) => _darkBase(),
          )
        else
          _darkBase(),

        // Dark overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withAlpha(coverImage != null ? 170 : 110),
                Colors.black.withAlpha(coverImage != null ? 100 : 50),
                Colors.black.withAlpha(coverImage != null ? 180 : 130),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // Decorative pattern overlay
        const Positioned.fill(child: _RoomBgPatternWidget()),
      ],
    );
  }

  Widget _darkBase() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0D0018), Color(0xFF1A0033), Color(0xFF0F0820), Color(0xFF2D0060)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  );
}

class _RoomBgPatternWidget extends StatelessWidget {
  const _RoomBgPatternWidget();
  @override
  Widget build(BuildContext context) => IgnorePointer(child: CustomPaint(painter: _RoomBgPainter()));
}

class _RoomBgPainter extends CustomPainter {
  static const _cols = [
    Color(0xFF4285F4),
    Color(0xFFEA4335),
    Color(0xFFFBBC05),
    Color(0xFF34A853),
    Color(0xFFEC4899),
    Color(0xFF7C3AED),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void dot(double x, double y, double r, int ci, {double a = 0.25}) {
      canvas.drawCircle(Offset(x, y), r,
          Paint()..color = _cols[ci % 6].withAlpha((a * 255).round()));
    }

    void ring(double x, double y, double r, int ci, {double a = 0.15, double sw = 1.5}) {
      canvas.drawCircle(Offset(x, y), r,
          Paint()
            ..color = _cols[ci % 6].withAlpha((a * 255).round())
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw);
    }

    // Corner accent dots
    dot(w * 0.04, h * 0.06, 22, 0, a: 0.18);
    dot(w * 0.94, h * 0.05, 16, 1, a: 0.18);
    dot(w * 0.05, h * 0.88, 14, 2, a: 0.18);
    dot(w * 0.95, h * 0.88, 18, 3, a: 0.18);

    // Rings
    ring(w * 0.12, h * 0.18, 48, 0, a: 0.10, sw: 1.5);
    ring(w * 0.88, h * 0.14, 36, 1, a: 0.10, sw: 1.5);
    ring(w * 0.10, h * 0.72, 32, 4, a: 0.10, sw: 1.5);
    ring(w * 0.90, h * 0.75, 40, 3, a: 0.10, sw: 1.5);
    ring(w * 0.50, h * 0.04, 24, 5, a: 0.08, sw: 1.0);
    ring(w * 0.50, h * 0.96, 24, 0, a: 0.08, sw: 1.0);

    // Scattered small dots
    const pts = [
      [0.22, 0.10], [0.78, 0.16], [0.38, 0.92], [0.62, 0.88],
      [0.06, 0.42], [0.94, 0.40], [0.30, 0.52], [0.70, 0.48],
      [0.16, 0.30], [0.84, 0.62], [0.46, 0.18], [0.54, 0.80],
      [0.60, 0.28], [0.40, 0.68],
    ];
    for (int i = 0; i < pts.length; i++) {
      dot(w * pts[i][0], h * pts[i][1], 3.5 + (i % 3), i, a: 0.22);
    }

    // Faint grid
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(7)
      ..strokeWidth = 0.5;
    for (double x = 0; x < w; x += w / 6) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y < h; y += h / 10) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // 8-pointed star rings at top & bottom center
    void starRing(double cx, double cy, double dist) {
      for (int i = 0; i < 8; i++) {
        final angle = -pi / 2 + i * pi / 4;
        ring(cx + dist * cos(angle), cy + dist * sin(angle), 5, i, a: 0.15, sw: 1.0);
      }
    }
    starRing(w * 0.5, h * 0.10, 22);
    starRing(w * 0.5, h * 0.90, 22);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── رأس الغرفة ─────────────────────────────────────────────────────
class _RoomHeader extends ConsumerWidget {
  const _RoomHeader({
    required this.room,
    required this.onMinimize,
    required this.onLeave,
    required this.onVisitorTap,
    this.isHost = false,
    this.isAdmin = false,
    this.onSettings,
  });
  final RoomModel room;
  final VoidCallback onMinimize;
  final VoidCallback onLeave;
  final void Function(String userId, String userName, String? avatar) onVisitorTap;
  final bool isHost;
  final bool isAdmin;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalGifts = ref.watch(roomTotalGiftsProvider(room.roomId)).valueOrNull ?? 0;
    final lvlIdx = giftSendLevelIndex(totalGifts);
    final lvl = kRoomLevels[lvlIdx];
    final memberCount = ref.watch(memberCountProvider(room.roomId)).valueOrNull ?? room.onlineCount;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          room.name,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.w700, fontFamily: 'Cairo',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: lvl.$4.withAlpha(40),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: lvl.$4.withAlpha(120), width: 1),
                        ),
                        child: Text(
                          '${lvl.$3} Lv.${lvlIdx + 1}',
                          style: TextStyle(color: lvl.$4, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => _VisitorsSheet(
                        roomId: room.roomId,
                        onVisitorTap: onVisitorTap,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withAlpha(80), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_red_eye_rounded, size: 11, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            '$memberCount',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ترس الإعدادات — يظهر للمضيف والمشرف
            if ((isHost || isAdmin) && onSettings != null) ...[
              GestureDetector(
                onTap: onSettings,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(90),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.settings_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // قائمة الثلاث نقاط — تصغير/خروج
            _RoomMenuBtn(onMinimize: onMinimize, onLeave: onLeave),
          ],
        ),
      ),
    );
  }
}

// ── زر الثلاث نقاط — قائمة تصغير/خروج ────────────────────────────
class _RoomMenuBtn extends StatelessWidget {
  const _RoomMenuBtn({required this.onMinimize, required this.onLeave});
  final VoidCallback onMinimize;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'minimize') onMinimize();
        if (v == 'leave')    onLeave();
      },
      color: const Color(0xFF1E1030),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      offset: const Offset(0, 44),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'minimize',
          child: Row(children: [
            Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white70, size: 20),
            SizedBox(width: 10),
            Text('تغيير الغرفة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 14)),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'leave',
          child: Row(children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            SizedBox(width: 10),
            Text('خروج', style: TextStyle(color: Colors.redAccent, fontFamily: 'Cairo', fontSize: 14)),
          ]),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(80),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}



// ── قائمة الزوار ─────────────────────────────────────────────────────
class _VisitorsSheet extends ConsumerWidget {
  const _VisitorsSheet({required this.roomId, required this.onVisitorTap});
  final String roomId;
  final void Function(String userId, String userName, String? avatar) onVisitorTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(roomMembersProvider(roomId));

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1030),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // مقبض السحب
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // العنوان
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.remove_red_eye_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  members.when(
                    data: (list) => Text(
                      'الزوار (${list.length})',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
                    ),
                    loading: () => const Text('الزوار', style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Cairo')),
                    error: (_, __) => const Text('الزوار', style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Cairo')),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // القائمة
            Expanded(
              child: members.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => Center(child: Text('خطأ: $e', style: const TextStyle(color: Colors.white54, fontFamily: 'Cairo'))),
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(
                      child: Text('لا يوجد زوار حالياً', style: TextStyle(color: Colors.white38, fontFamily: 'Cairo', fontSize: 14)),
                    );
                  }
                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final m = list[i];
                      final uid    = m['userId']    as String? ?? '';
                      final name   = m['userName']  as String? ?? 'مستخدم';
                      final avatar = m['userAvatar'] as String?;
                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          onVisitorTap(uid, name, avatar);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              // صورة المستخدم
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.primary.withAlpha(60),
                                backgroundImage: avatar != null && avatar.isNotEmpty
                                    ? CachedNetworkImageProvider(avatar)
                                    : null,
                                child: avatar == null || avatar.isEmpty
                                    ? Text(name.isNotEmpty ? name[0] : '?',
                                        style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Cairo'))
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              // الاسم
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Cairo', fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.chevron_left_rounded, color: Colors.white30, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SafeArea(top: false, child: SizedBox(height: 8)),
          ],
        ),
      ),
    );
  }
}

// ── عنصر قائمة مشترك ────────────────────────────────────────────────
class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontFamily: 'Cairo')),
      onTap: onTap,
    );
  }
}

// ── إعدادات الغرفة ──────────────────────────────────────────────────
class _RoomSettingsSheet extends ConsumerStatefulWidget {
  const _RoomSettingsSheet({
    required this.roomId,
    this.onEditAnnouncement,
    this.onEditRoom,
    this.onChangeCover,
  });
  final String roomId;
  final VoidCallback? onEditAnnouncement;
  final VoidCallback? onEditRoom;
  final VoidCallback? onChangeCover;

  @override
  ConsumerState<_RoomSettingsSheet> createState() => _RoomSettingsSheetState();
}

class _RoomSettingsSheetState extends ConsumerState<_RoomSettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final challengeEnd = ref.watch(challengeEndTimeProvider(widget.roomId)).valueOrNull;
    final hasChallenge = challengeEnd != null && challengeEnd.isAfter(DateTime.now());
    final currentMax = ref.watch(roomMaxSeatsProvider(widget.roomId)).valueOrNull ?? 9;
    final pk = ref.watch(pkStateProvider(widget.roomId)).valueOrNull;
    final pkActive = pk != null && pk.active;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + MediaQuery.of(context).padding.bottom),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          const Text('إعدادات الغرفة',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
          const SizedBox(height: 16),
          _MenuTile(
            icon: Icons.image_rounded, label: 'تغيير صورة الغرفة', color: AppColors.blue,
            onTap: () { Navigator.pop(context); widget.onChangeCover?.call(); },
          ),
          _MenuTile(
            icon: Icons.drive_file_rename_outline_rounded, label: 'تغيير اسم الغرفة', color: AppColors.primary,
            onTap: () => _showNameDialog(context),
          ),
          _MenuTile(
            icon: Icons.edit_rounded, label: 'تعديل الغرفة', color: AppColors.primary,
            onTap: () { Navigator.pop(context); widget.onEditRoom?.call(); },
          ),
          _MenuTile(
            icon: Icons.announcement_rounded, label: 'تعديل الإعلان', color: AppColors.primary,
            onTap: () { Navigator.pop(context); widget.onEditAnnouncement?.call(); },
          ),
          // ── عدد المقاعد ──────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.mic_rounded, color: Color(0xFF9B59B6)),
            title: const Text('عدد المقاعد', style: TextStyle(color: Color(0xFF9B59B6), fontFamily: 'Cairo')),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF9B59B6).withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF9B59B6).withAlpha(100)),
              ),
              child: Text('$currentMax مقعد',
                  style: const TextStyle(color: Color(0xFF9B59B6), fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            onTap: () => _showSeatCountDialog(context, currentMax),
          ),
          _MenuTile(
            icon: hasChallenge ? Icons.timer_off_rounded : Icons.timer_rounded,
            label: hasChallenge ? 'إلغاء التحدي 🏁' : 'تفعيل تحدي ⏱',
            color: hasChallenge ? AppColors.error : const Color(0xFFFF2D78),
            onTap: hasChallenge
                ? () async {
                    Navigator.pop(context);
                    await RoomStateRepository().deactivateChallenge(widget.roomId);
                  }
                : () => _showChallengeDialog(context),
          ),
          _MenuTile(
            icon: Icons.sports_kabaddi_rounded,
            label: pkActive ? 'إيقاف تحدي PK ⚔️' : 'تحدي PK ⚔️',
            color: pkActive ? AppColors.error : const Color(0xFFFF6B35),
            onTap: pkActive
                ? () async {
                    Navigator.pop(context);
                    await RoomStateRepository().stopPK(widget.roomId);
                  }
                : () => _showPKDialog(context),
          ),
          _MenuTile(
            icon: Icons.mic_off_rounded, label: 'كتم الكل', color: AppColors.warning,
            onTap: () async {
              final seats = ref.read(seatsProvider(widget.roomId));
              final writer = ref.read(seatsWriterProvider(widget.roomId));
              for (final s in seats) {
                if (!s.isEmpty && !s.isMuted) await writer.toggleMute(s.index, false);
              }
              if (context.mounted) Navigator.pop(context);
            },
          ),
          _MenuTile(
            icon: Icons.stop_circle_rounded, label: 'إنهاء الغرفة', color: AppColors.error,
            onTap: () { Navigator.pop(context); Navigator.pop(context); },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  }

  void _showSeatCountDialog(BuildContext context, int current) {
    int selected = current;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('عدد المقاعد',
              style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 16)),
          content: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [3, 5, 10, 20, 25].map((n) {
              final isSel = selected == n;
              return GestureDetector(
                onTap: () => setDlg(() => selected = n),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 64,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF9B59B6).withAlpha(40) : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel ? const Color(0xFF9B59B6) : AppColors.divider,
                      width: isSel ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$n',
                    style: TextStyle(
                      color: isSel ? const Color(0xFF9B59B6) : AppColors.textSecondary,
                      fontFamily: 'Cairo',
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.normal,
                      fontSize: 15,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo')),
            ),
            TextButton(
              onPressed: () async {
                await RoomStateRepository().updateMaxSeats(widget.roomId, selected);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('حفظ',
                  style: TextStyle(color: Color(0xFF9B59B6), fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showNameDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('تغيير اسم الغرفة',
            style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 15)),
        content: TextField(
          controller: ctrl,
          textDirection: TextDirection.rtl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
          decoration: const InputDecoration(
            hintText: 'اسم الغرفة الجديد',
            hintStyle: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo'),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await RoomStateRepository().updateRoomName(widget.roomId, name);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ',
                style: TextStyle(color: AppColors.primary, fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showChallengeDialog(BuildContext sheetCtx) {
    showDialog(
      context: sheetCtx,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('⏱ تفعيل التحدي',
            style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اختر مدة التحدي:',
                style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 13)),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _DurBtn(label: 'ساعة', hours: 1, roomId: widget.roomId,
                    dialogCtx: ctx, sheetCtx: sheetCtx),
                _DurBtn(label: 'ساعتين', hours: 2, roomId: widget.roomId,
                    dialogCtx: ctx, sheetCtx: sheetCtx),
                _DurBtn(label: '3 ساعات', hours: 3, roomId: widget.roomId,
                    dialogCtx: ctx, sheetCtx: sheetCtx),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  void _showPKDialog(BuildContext sheetCtx) {
    showDialog(
      context: sheetCtx,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('⚔️ تحدي PK',
            style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'المقاعد الأولى = 🔥 فريق أ\nالمقاعد الأخيرة = 💙 فريق ب\n\nاختر مدة التحدي:',
              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _PKDurBtn(label: '3 دقائق', minutes: 3, roomId: widget.roomId, dialogCtx: ctx, sheetCtx: sheetCtx),
                _PKDurBtn(label: '5 دقائق', minutes: 5, roomId: widget.roomId, dialogCtx: ctx, sheetCtx: sheetCtx),
                _PKDurBtn(label: '10 دقائق', minutes: 10, roomId: widget.roomId, dialogCtx: ctx, sheetCtx: sheetCtx),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}

// ── زر مدة التحدي ──────────────────────────────────────────────────
class _DurBtn extends StatelessWidget {
  const _DurBtn({
    required this.label,
    required this.hours,
    required this.roomId,
    required this.dialogCtx,
    required this.sheetCtx,
  });
  final String label;
  final int hours;
  final String roomId;
  final BuildContext dialogCtx;
  final BuildContext sheetCtx;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final end = DateTime.now().add(Duration(hours: hours));
        Navigator.pop(dialogCtx);
        Navigator.pop(sheetCtx);
        await RoomStateRepository().activateChallenge(roomId, end);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF2D78), Color(0xFFFF6B6B)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF2D78).withAlpha(90),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white, fontFamily: 'Cairo',
            fontWeight: FontWeight.w700, fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ── زر مدة PK ──────────────────────────────────────────────────────
class _PKDurBtn extends StatelessWidget {
  const _PKDurBtn({
    required this.label,
    required this.minutes,
    required this.roomId,
    required this.dialogCtx,
    required this.sheetCtx,
  });
  final String label;
  final int minutes;
  final String roomId;
  final BuildContext dialogCtx;
  final BuildContext sheetCtx;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final messenger = ScaffoldMessenger.maybeOf(sheetCtx);
        Navigator.pop(dialogCtx);
        Navigator.pop(sheetCtx);
        try {
          await RoomStateRepository().startPK(roomId, minutes);
        } catch (e) {
          debugPrint('[PK] startPK error: $e');
          messenger?.showSnackBar(SnackBar(
            content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF4500)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withAlpha(90),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white, fontFamily: 'Cairo',
            fontWeight: FontWeight.w700, fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _ChallengeGiftBar — شريط هدايا التحدي المتحرك
// ═══════════════════════════════════════════════════════════════════════════

// _ChallengeGiftBar: يراقب Providers فقط — بدون Timer
class _ChallengeGiftBar extends ConsumerWidget {
  const _ChallengeGiftBar({required this.roomId});
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endTime = ref.watch(challengeEndTimeProvider(roomId)).valueOrNull;
    if (endTime == null) return const SizedBox.shrink();
    final total = ref.watch(challengeGiftTotalProvider(roomId)).valueOrNull ?? 0;
    final isHost = ref.watch(isHostProvider);
    return _ChallengeGiftBarContent(
      roomId: roomId,
      endTime: endTime,
      total: total,
      isHost: isHost,
    );
  }
}

// _ChallengeGiftBarContent: يحسب العداد بـ Timer — بدون ref.watch
class _ChallengeGiftBarContent extends StatefulWidget {
  const _ChallengeGiftBarContent({
    required this.roomId,
    required this.endTime,
    required this.total,
    required this.isHost,
  });
  final String roomId;
  final DateTime endTime;
  final int total;
  final bool isHost;

  @override
  State<_ChallengeGiftBarContent> createState() => _ChallengeGiftBarContentState();
}

class _ChallengeGiftBarContentState extends State<_ChallengeGiftBarContent> {
  Timer? _tick;
  bool _deactivated = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static Color _barColor(int total) {
    if (total >= 5000000) return const Color(0xFFFF2D55);
    if (total >= 1000000) return const Color(0xFF9B59B6);
    if (total >= 500000)  return const Color(0xFF3498DB);
    return const Color(0xFF2ECC71);
  }

  static double _progress(int total) {
    if (total <= 0) return 0;
    if (total >= 5000000) return 1.0;
    if (total >= 1000000) return 0.75 + 0.25 * (total - 1000000) / 4000000;
    if (total >= 500000)  return 0.50 + 0.25 * (total - 500000) / 500000;
    if (total >= 50000)   return 0.25 + 0.25 * (total - 50000) / 450000;
    return 0.25 * total / 50000;
  }

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.endTime.difference(DateTime.now());
    if (remaining.isNegative) {
      if (widget.isHost && !_deactivated) {
        _deactivated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          RoomStateRepository().deactivateChallenge(widget.roomId);
        });
      }
      return const SizedBox.shrink();
    }

    final total = widget.total;
    final progress = _progress(total);
    final color = _barColor(total);

    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    final timeLabel = h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(110),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withAlpha(25)),
        boxShadow: [
          BoxShadow(color: color.withAlpha(70), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          // ── يسار: إجمالي الهدايا ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💎', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Text(
                  _fmt(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                    height: 1,
                  ),
                ),
              ],
            ),
          ),

          // ── وسط: شريط التقدم المتحرك ────────────────────────────
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 16,
                child: LayoutBuilder(
                  builder: (ctx, box) {
                    final fillWidth = box.maxWidth * progress;
                    return Stack(
                      children: [
                        // خلفية شفافة
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        // الجزء المملوء
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOut,
                          width: fillWidth.clamp(0, box.maxWidth),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(color: color.withAlpha(200), blurRadius: 8),
                            ],
                          ),
                        ),
                        // شيمر (بريق متحرك)
                        if (progress > 0.02)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withAlpha(35),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.3, 0.5, 0.7],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // ── يمين: العداد التنازلي ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⏱', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 3),
                Text(
                  timeLabel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
