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
import '../widgets/sound_effects_panel.dart';
import '../../../admin/presentation/providers/admin_provider.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key, required this.room});
  final RoomModel room;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
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

  @override
  void initState() {
    super.initState();
    _roomId = widget.room.roomId;
    _coverImageUrl = widget.room.coverImage;
    _joinedAt = DateTime.now();
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

      // المضيف يجلس في المقعد 0 تلقائياً
      if (isHost) {
        await ref.read(seatsWriterProvider(_roomId)).takeSeat(
          0,
          userId: me.uid,
          userName: me.displayName ?? 'مستخدم',
          userAvatar: me.photoURL,
        );
        ref.read(myCurrentSeatProvider.notifier).state = 0;
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

      // Zego starts with mic muted — sync provider state to match reality.
      if (isHost) {
        // Host auto-unmutes on seat 0.
        await zego.setMicMuted(false);
        ref.read(isMicMutedProvider.notifier).state = false;
      } else {
        // Non-host: mic stays muted until they take a seat.
        ref.read(isMicMutedProvider.notifier).state = true;
      }

      await zego.startSoundLevelMonitor();

    // استمع لقرار الطرد من الغرفة
    RoomStateRepository().watchRoomKick(_roomId, me.uid).listen((kicked) {
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
      final seats = ref.read(seatsProvider(_roomId));
      final seat = seats.firstWhere(
        (s) => s.userId == userId,
        orElse: () => const SeatModel(index: -1),
      );
      if (seat.index >= 0) {
        // Only clear if still owned by that user (prevents race with re-join).
        await ref.read(seatsWriterProvider(_roomId)).leaveSeatIfOwner(seat.index, userId);
        if (seat.index == ref.read(myCurrentSeatProvider)) {
          ref.read(myCurrentSeatProvider.notifier).state = -1;
        }
      }
    };

    zego.onAudioLevel = (levels) {
      if (!mounted) return;
      ref.read(speakingUsersProvider.notifier).state = {
        for (final e in levels.entries)
          if (e.value > 10) e.key,
      };
    };
  }

  // تصغير الغرفة لفقاعة عائمة بدلاً من الخروج الكلي
  void _minimizeRoom() {
    final me = _currentUser;
    if (me == null) {
      Navigator.of(context).pop();
      return;
    }
    _leftCleanly = true; // منع cleanup عند dispose
    ref.read(minimizedRoomProvider.notifier).state = MinimizedRoomState(
      room: widget.room,
      mySeat: ref.read(myCurrentSeatProvider),
      userId: me.uid,
      userName: me.displayName ?? 'مستخدم',
    );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    // Read seat index BEFORE super.dispose() invalidates ref.
    final savedSeat = ref.read(myCurrentSeatProvider);
    _cleanup(savedSeat: savedSeat);
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

  void _onSeatTap(SeatModel seat) {
    final me = _currentUser;
    if (me == null) return;
    final isHost = ref.read(isHostProvider);

    // تصوير مقعدي → اعرض ملفي الشخصي
    if (!seat.isEmpty && seat.userId == me.uid) {
      _showMyProfile(seat);
      return;
    }

    if (seat.index == 0) return;

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

    // اترك المقعد القديم أولاً
    final mySeat = ref.read(myCurrentSeatProvider);
    if (mySeat >= 0) {
      ref.read(seatsWriterProvider(_roomId)).leaveSeatIfOwner(mySeat, me.uid);
    }

    ref.read(seatsWriterProvider(_roomId)).takeSeat(
      seat.index,
      userId: me.uid,
      userName: me.displayName ?? 'مستخدم',
      userAvatar: me.photoURL,
    );
    ref.read(myCurrentSeatProvider.notifier).state = seat.index;
    ZegoService().setMicMuted(false);
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
    // كتم الميكروفون عند النزول من المقعد وتحديث الزر فوراً
    ZegoService().setMicMuted(true);
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

  void _sendMessage(String text) {
    final me = _currentUser;
    if (me == null || text.isEmpty) return;
    ref.read(chatWriterProvider(_roomId)).sendUserMessage(
      senderId: me.uid,
      senderName: me.displayName ?? 'مستخدم',
      senderAvatar: me.photoURL,
      content: text,
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

    // ── مزامنة حالة المقعد من Firestore إلى Zego ──────────────────
    // Handles: host muting a user, and detecting when kicked from seat.
    ref.listen<List<SeatModel>>(seatsProvider(_roomId), (_, seats) {
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
      if (!next.hasValue) return;
      final msgs = next.value!;

      // تمرير تلقائي للأسفل
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _minimizeRoom();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            _RoomBackground(coverImage: _coverImageUrl),

            Column(
              children: [
                _RoomHeader(room: widget.room, onMinimize: _minimizeRoom),

                // المضيف
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: SeatWidget(
                    seat: seats[0],
                    isHost: true,
                    isMe: seats[0].userId == _currentUser?.uid,
                    onTap: () => _onSeatTap(seats[0]),
                    emojiTrigger: _seatEmoji[0],
                  ),
                ),

                // شبكة المقاعد
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 4,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: 8,
                    itemBuilder: (_, i) {
                      final seat = seats[i + 1];
                      return SeatWidget(
                        seat: seat,
                        isHost: false,
                        isMe: seat.userId == _currentUser?.uid,
                        onTap: () => _onSeatTap(seat),
                        emojiTrigger: _seatEmoji[seat.index],
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

                RoomBottomBar(
                  onSendMessage: _sendMessage,
                  onGift: () => _showGiftPanel(context),
                  onSettings: () => _showSettings(context),
                  onSoundEffects: _showSoundEffects,
                  isHost: isHost,
                  roomId: _roomId,
                  currentUserId: _currentUser?.uid ?? '',
                ),
              ],
            ),

            // أنيميشن الهدايا
            const GiftAnimationOverlay(),
          ],
        ),
      ),
    ));
  }

  void _showGiftPanel(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const GiftPanel(),
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
class _RoomHeader extends StatelessWidget {
  const _RoomHeader({required this.room, required this.onMinimize});
  final RoomModel room;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: onMinimize,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(80),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 16),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w700, fontFamily: 'Cairo',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      const Icon(Icons.people_rounded, size: 11, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text(
                        '${room.onlineCount} متصل',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'Cairo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _HeaderBtn(icon: Icons.share_rounded, onTap: () {}),
            const SizedBox(width: 6),
            _HeaderBtn(icon: Icons.remove_rounded, onTap: onMinimize),
          ],
        ),
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(80),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
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
class _RoomSettingsSheet extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(20),
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
            onTap: () {
              Navigator.pop(context);
              onChangeCover?.call();
            },
          ),
          _MenuTile(
            icon: Icons.edit_rounded, label: 'تعديل الغرفة', color: AppColors.primary,
            onTap: () {
              Navigator.pop(context);
              onEditRoom?.call();
            },
          ),
          _MenuTile(
            icon: Icons.announcement_rounded, label: 'تعديل الإعلان', color: AppColors.primary,
            onTap: () {
              Navigator.pop(context);
              onEditAnnouncement?.call();
            },
          ),
          _MenuTile(
            icon: Icons.mic_off_rounded, label: 'كتم الكل', color: AppColors.warning,
            onTap: () async {
              final seats = ref.read(seatsProvider(roomId));
              final writer = ref.read(seatsWriterProvider(roomId));
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
    );
  }
}

