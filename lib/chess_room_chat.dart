import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-match communication surface for a verified two-player chess room.
/// The room must already exist and be active; database RLS/RPCs enforce membership.
class ChessRoomChatPanel extends StatefulWidget {
  final String roomId;
  final String opponentUserId;
  final String opponentName;

  const ChessRoomChatPanel({
    super.key,
    required this.roomId,
    required this.opponentUserId,
    required this.opponentName,
  });

  @override
  State<ChessRoomChatPanel> createState() => _ChessRoomChatPanelState();
}

class _ChessRoomChatPanelState extends State<ChessRoomChatPanel> {
  static const _quickMessages = <String>[
    'سلام! 👋',
    'بازی خوبی داشته باشی!',
    'حرکت جالبی بود!',
    'آفرین!',
    'موفق باشی!',
    'من آماده‌ام.',
    'عجله نکن 🙂',
    'ممنون از بازی!',
  ];

  final _client = Supabase.instance.client;
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _channel;
  Timer? _recordTimer;
  bool _loading = true;
  bool _sending = false;
  bool _recording = false;
  bool _chatEnabled = true;
  bool _quickEnabled = true;
  bool _voiceEnabled = true;
  bool _blocked = false;
  int _recordSeconds = 0;
  String? _error;
  String? _playingMessageId;

  String? get _uid => _client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _connect();
  }

  Future<void> _loadPreferences() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final row = await _client
          .from('chess_room_preferences')
          .select('chat_enabled,quick_messages_enabled,voice_enabled')
          .eq('room_id', widget.roomId)
          .eq('user_id', uid)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _chatEnabled = row?['chat_enabled'] as bool? ?? true;
        _quickEnabled = row?['quick_messages_enabled'] as bool? ?? true;
        _voiceEnabled = row?['voice_enabled'] as bool? ?? true;
      });
    } catch (_) {
      // Defaults keep the chat usable if preferences have not been created yet.
    }
  }

  Future<void> _connect() async {
    try {
      final uid = _uid;
      if (uid == null) throw StateError('برای گفت‌وگو باید وارد حساب شوی.');
      _channel = _client
          .channel('chess-room-chat-${widget.roomId}-$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'chess_room_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: widget.roomId,
            ),
            callback: (payload) {
              _addMessage(Map<String, dynamic>.from(payload.newRecord));
            },
          )
          .subscribe();
      await _loadMessages();
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    }
  }

  Future<void> _loadMessages() async {
    try {
      final rows = await _client
          .from('chess_room_messages')
          .select('id,room_id,sender_id,message_type,body,media_path,created_at')
          .eq('room_id', widget.roomId)
          .order('created_at', ascending: true)
          .limit(100);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(List<Map<String, dynamic>>.from(rows));
        _loading = false;
      });
      _jumpToLatest();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  void _addMessage(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    if (id == null || _messages.any((m) => m['id']?.toString() == id)) return;
    if (!mounted) return;
    setState(() {
      _messages.add(row);
      _messages.sort((a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'));
    });
    _jumpToLatest();
  }

  void _jumpToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String kind, {String? body, String? mediaPath}) async {
    if (_sending || _uid == null || _blocked || !_chatEnabled) return;
    setState(() => _sending = true);
    try {
      await _client.rpc('send_chess_room_message', params: {
        'p_room_id': widget.roomId,
        'p_kind': kind,
        'p_body': body,
        'p_media_path': mediaPath,
      });
      if (kind == 'text') _text.clear();
      // Realtime is primary; reload also covers a missed websocket event.
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startRecording() async {
    if (_recording || _sending || !_voiceEnabled || !_chatEnabled || _blocked) return;
    try {
      if (!await _recorder.hasPermission()) {
        throw StateError('اجازهٔ استفاده از میکروفون داده نشده است.');
      }
      final path = kIsWeb
          ? 'chess_voice_${DateTime.now().millisecondsSinceEpoch}.webm'
          : '${(await getTemporaryDirectory()).path}/chess_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        RecordConfig(
          encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 24000,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordSeconds = 0;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_recording) return;
        setState(() => _recordSeconds++);
        if (_recordSeconds >= 30) _stopRecording();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e))),
        );
      }
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    if (!_recording) return;
    _recordTimer?.cancel();
    _recordTimer = null;
    setState(() => _recording = false);
    String? path;
    try {
      path = await _recorder.stop();
      if (cancel || path == null || path.isEmpty) return;
      final bytes = await XFile(path).readAsBytes();
      if (bytes.isEmpty) throw StateError('پیام صوتی خالی است.');
      if (bytes.length > 2 * 1024 * 1024) {
        throw StateError('حجم پیام صوتی بیشتر از ۲ مگابایت است.');
      }
      final uid = _uid;
      if (uid == null) throw StateError('نشست کاربری پایان یافته است.');
      final ext = kIsWeb ? 'webm' : 'm4a';
      final mime = kIsWeb ? 'audio/webm' : 'audio/mp4';
      final storagePath =
          '${widget.roomId}/$uid/${DateTime.now().microsecondsSinceEpoch}.$ext';
      setState(() => _sending = true);
      await _client.storage.from('chess-voice').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: mime, upsert: false),
          );
      try {
        await _send('voice', mediaPath: storagePath);
      } catch (_) {
        await _client.storage.from('chess-voice').remove([storagePath]);
        rethrow;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ارسال پیام صوتی ناموفق بود: ${_friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _playVoice(Map<String, dynamic> message) async {
    final id = message['id'].toString();
    final path = message['media_path']?.toString() ?? '';
    if (path.isEmpty) return;
    try {
      final url = await _client.storage.from('chess-voice').createSignedUrl(path, 300);
      setState(() => _playingMessageId = id);
      await _player.play(UrlSource(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('پخش پیام صوتی ناموفق بود: ${_friendlyError(e)}')),
        );
      }
    }
  }

  Future<void> _savePreferences({
    bool? chat,
    bool? quick,
    bool? voice,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final nextChat = chat ?? _chatEnabled;
    final nextQuick = quick ?? _quickEnabled;
    final nextVoice = voice ?? _voiceEnabled;
    setState(() {
      _chatEnabled = nextChat;
      _quickEnabled = nextQuick;
      _voiceEnabled = nextVoice;
    });
    try {
      await _client.from('chess_room_preferences').upsert({
        'room_id': widget.roomId,
        'user_id': uid,
        'chat_enabled': nextChat,
        'quick_messages_enabled': nextQuick,
        'voice_enabled': nextVoice,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'room_id,user_id');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chatEnabled = !nextChat;
        _quickEnabled = !nextQuick;
        _voiceEnabled = !nextVoice;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ذخیرهٔ تنظیمات ناموفق بود: ${_friendlyError(e)}')),
      );
    }
  }

  Future<void> _blockOpponent() async {
    final uid = _uid;
    if (uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسدودکردن حریف؟'),
        content: const Text('پس از مسدودسازی، ارسال پیام بین شما و این کاربر متوقف می‌شود.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('مسدود کن')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _client.from('user_blocks').insert({
        'blocker_id': uid,
        'blocked_id': widget.opponentUserId,
      });
      if (mounted) setState(() => _blocked = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('مسدودسازی ناموفق بود: ${_friendlyError(e)}')),
        );
      }
    }
  }

  Future<void> _reportOpponent() async {
    String reason = 'abuse';
    final details = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('گزارش حریف'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: reason,
                items: const [
                  DropdownMenuItem(value: 'abuse', child: Text('توهین و آزار')),
                  DropdownMenuItem(value: 'spam', child: Text('هرزنامه')),
                  DropdownMenuItem(value: 'inappropriate_voice', child: Text('پیام صوتی نامناسب')),
                  DropdownMenuItem(value: 'cheating', child: Text('تقلب')),
                  DropdownMenuItem(value: 'other', child: Text('مورد دیگر')),
                ],
                onChanged: (value) => setDialogState(() => reason = value ?? 'abuse'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: details,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ارسال گزارش')),
          ],
        ),
      ),
    );
    if (submitted != true) {
      details.dispose();
      return;
    }
    try {
      await _client.from('chess_room_reports').insert({
        'room_id': widget.roomId,
        'reporter_id': _uid,
        'reported_user_id': widget.opponentUserId,
        'reason': reason,
        'details': details.text.trim().isEmpty ? null : details.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('گزارش ثبت شد.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ثبت گزارش ناموفق بود: ${_friendlyError(e)}')),
        );
      }
    } finally {
      details.dispose();
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('chess_room_not_active')) return 'این مسابقه دیگر فعال نیست.';
    if (raw.contains('not_a_chess_participant')) return 'دسترسی به گفت‌وگوی این مسابقه مجاز نیست.';
    if (raw.contains('opponent_chat_disabled')) return 'حریف گفت‌وگو را خاموش کرده است.';
    if (raw.contains('chess_chat_blocked')) return 'ارتباط بین دو حساب مسدود شده است.';
    if (raw.contains('chess_chat_rate_limited')) return 'کمی صبر کن و دوباره پیام بفرست.';
    if (raw.contains('quick_message_not_allowed')) return 'این پیام آماده برای حریف فعال نیست.';
    return raw.replaceFirst('Exception: ', '');
  }

  String _timeLabel(dynamic value) {
    final parsed = DateTime.tryParse('$value')?.toLocal();
    if (parsed == null) return '';
    return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('گفت‌وگو با ${widget.opponentName}', style: const TextStyle(fontSize: 16)),
            const Text('فقط دو بازیکن این مسابقه', style: TextStyle(fontSize: 11)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SwitchListTile(
                          title: const Text('گفت‌وگو فعال باشد'),
                          value: _chatEnabled,
                          onChanged: (value) => _savePreferences(chat: value),
                        ),
                        SwitchListTile(
                          title: const Text('جملات آماده فعال باشد'),
                          value: _quickEnabled,
                          onChanged: (value) => _savePreferences(quick: value),
                        ),
                        SwitchListTile(
                          title: const Text('پیام صوتی فعال باشد'),
                          value: _voiceEnabled,
                          onChanged: (value) => _savePreferences(voice: value),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (value == 'report') {
                _reportOpponent();
              } else if (value == 'block') {
                _blockOpponent();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'settings', child: Text('تنظیمات ارتباط')),
              PopupMenuItem(value: 'report', child: Text('گزارش حریف')),
              PopupMenuItem(value: 'block', child: Text('مسدودکردن حریف')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(onPressed: () { setState(() => _error = null); _connect(); }, child: const Text('تلاش دوباره')),
              ],
            ),
          if (!_chatEnabled || _blocked)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_blocked ? 'این حریف مسدود شده است.' : 'گفت‌وگو برای حساب تو خاموش است.'),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('هنوز پیامی ردوبدل نشده است.'))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final mine = message['sender_id'] == uid;
                          final voice = message['message_type'] == 'voice';
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 310),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: mine
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (voice)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => _playVoice(message),
                                          icon: Icon(_playingMessageId == message['id']
                                              ? Icons.graphic_eq_rounded
                                              : Icons.play_arrow_rounded),
                                        ),
                                        const Text('پیام صوتی'),
                                      ],
                                    )
                                  else
                                    Text('${message['body'] ?? ''}'),
                                  Align(
                                    alignment: Alignment.bottomLeft,
                                    child: Text(
                                      _timeLabel(message['created_at']),
                                      style: Theme.of(context).textTheme.labelSmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_quickEnabled && _chatEnabled && !_blocked)
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                scrollDirection: Axis.horizontal,
                itemCount: _quickMessages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) => ActionChip(
                  label: Text(_quickMessages[index]),
                  onPressed: _sending ? null : () => _send('quick', body: _quickMessages[index]),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Row(
                children: [
                  if (_voiceEnabled)
                    IconButton.filledTonal(
                      onPressed: _sending
                          ? null
                          : (_recording ? () => _stopRecording() : _startRecording),
                      icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded),
                      tooltip: _recording ? 'پایان و ارسال پیام صوتی' : 'ضبط پیام صوتی',
                    ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      enabled: _chatEnabled && !_blocked && !_sending && !_recording,
                      maxLength: 500,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'پیام بنویس…',
                        counterText: '',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send('text', body: _text.text.trim()),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _chatEnabled && !_blocked && !_sending && _text.text.trim().isNotEmpty
                        ? () => _send('text', body: _text.text.trim())
                        : null,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
          if (_recording)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('در حال ضبط… $_recordSeconds از ۳۰ ثانیه'),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    if (_recording) _recorder.stop();
    _recorder.dispose();
    _player.dispose();
    _text.dispose();
    _scroll.dispose();
    final channel = _channel;
    if (channel != null) _client.removeChannel(channel);
    super.dispose();
  }
}
