import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/models/message_model.dart';
import 'package:intl/intl.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showAvatar = true,
  });

  final MessageModel message;
  final bool isMe;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) return _DeletedBubble(isMe: isMe);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            showAvatar
                ? _Avatar(avatar: message.senderAvatar, name: message.senderName)
                : const SizedBox(width: 32),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && showAvatar)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, right: 4, left: 4),
                    child: Text(
                      message.senderName,
                      style: const TextStyle(
                        color: AppColors.primary, fontSize: 11,
                        fontWeight: FontWeight.w600, fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                _buildBubble(context),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    switch (message.contentType) {
      case MessageContentType.image:
        return _ImageBubble(url: message.content, isMe: isMe, time: message.createdAt);
      case MessageContentType.voice:
        return _VoiceBubble(url: message.content, isMe: isMe, time: message.createdAt);
      default:
        return _TextBubble(message: message, isMe: isMe);
    }
  }
}

// ── فقاعة النص ──────────────────────────────────────────────────
class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.message, required this.isMe});
  final MessageModel message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
      decoration: _bubbleDecoration(isMe),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message.content,
            style: TextStyle(
              color: isMe ? Colors.white : AppColors.textPrimary,
              fontFamily: 'Cairo', fontSize: 14,
            ),
          ),
          const SizedBox(height: 3),
          _TimeRow(time: message.createdAt, isMe: isMe, status: message.status),
        ],
      ),
    );
  }
}

// ── فقاعة الصورة ──────────────────────────────────────────────────
class _ImageBubble extends StatelessWidget {
  const _ImageBubble({required this.url, required this.isMe, required this.time});
  final String url;
  final bool isMe;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
      decoration: _bubbleDecoration(isMe),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () => _showFullscreen(context, url),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 180,
              placeholder: (_, __) => Container(
                height: 180,
                color: AppColors.surfaceLight,
                child: const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 180,
                color: AppColors.surfaceLight,
                child: const Icon(Icons.broken_image_rounded, color: AppColors.textHint, size: 40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: _TimeRow(time: time, isMe: isMe),
          ),
        ],
      ),
    );
  }

  void _showFullscreen(BuildContext context, String url) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        )),
        body: Center(
          child: InteractiveViewer(
            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
          ),
        ),
      ),
    ));
  }
}

// ── فقاعة الصوت ──────────────────────────────────────────────────
class _VoiceBubble extends StatefulWidget {
  const _VoiceBubble({required this.url, required this.isMe, required this.time});
  final String url;
  final bool isMe;
  final DateTime time;

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _state = PlayerState.stopped; _position = Duration.zero; });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      width: MediaQuery.of(context).size.width * 0.55,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _bubbleDecoration(widget.isMe),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _toggle,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isMe ? Colors.white.withAlpha(40) : AppColors.primary.withAlpha(30),
                  ),
                  child: Icon(
                    _state == PlayerState.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: widget.isMe ? Colors.white : AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 3,
                        backgroundColor: (widget.isMe ? Colors.white : AppColors.primary).withAlpha(40),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.isMe ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _duration > Duration.zero ? '${_fmt(_position)} / ${_fmt(_duration)}' : '🎤',
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.isMe ? Colors.white70 : AppColors.textHint,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _TimeRow(time: widget.time, isMe: widget.isMe),
        ],
      ),
    );
  }
}

// ── مشاركة ──────────────────────────────────────────────────────
BoxDecoration _bubbleDecoration(bool isMe) => BoxDecoration(
  color: isMe ? AppColors.primary : AppColors.card,
  borderRadius: BorderRadius.only(
    topLeft: const Radius.circular(18),
    topRight: const Radius.circular(18),
    bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
  ),
  boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4, offset: const Offset(0, 2))],
);

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.time, required this.isMe, this.status});
  final DateTime time;
  final bool isMe;
  final MessageStatus? status;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat('hh:mm a', 'ar').format(time),
          style: TextStyle(color: isMe ? Colors.white60 : AppColors.textHint, fontSize: 10),
        ),
        if (isMe && status != null) ...[
          const SizedBox(width: 4),
          Icon(
            status == MessageStatus.read ? Icons.done_all_rounded : Icons.done_rounded,
            size: 13,
            color: status == MessageStatus.read ? Colors.lightBlueAccent : Colors.white60,
          ),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.avatar, required this.name});
  final String? avatar;
  final String name;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.primary,
      backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar!) : null,
      child: avatar == null
          ? Text(name.isNotEmpty ? name[0] : '?',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
          : null,
    );
  }
}

class _DeletedBubble extends StatelessWidget {
  const _DeletedBubble({required this.isMe});
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: isMe ? 60 : 12, right: isMe ? 12 : 60, top: 2, bottom: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_rounded, size: 13, color: AppColors.textHint),
            SizedBox(width: 5),
            Text('تم حذف هذه الرسالة',
                style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}

class DateDivider extends StatelessWidget {
  const DateDivider({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = date.day == now.day && date.month == now.month && date.year == now.year
        ? 'اليوم'
        : date.day == now.subtract(const Duration(days: 1)).day
            ? 'أمس'
            : DateFormat('d MMMM', 'ar').format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
          child: Text(label, style: const TextStyle(color: AppColors.textHint, fontSize: 11, fontFamily: 'Cairo')),
        ),
      ),
    );
  }
}
