import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Participant-only chat embedded in a live casual-game room.
class FunGameRoomChatPanel extends StatefulWidget {
  final String roomId;
  const FunGameRoomChatPanel({super.key, required this.roomId});
  @override
  State<FunGameRoomChatPanel> createState() => _FunGameRoomChatPanelState();
}

class _FunGameRoomChatPanelState extends State<FunGameRoomChatPanel> {
  final _db = Supabase.instance.client;
  final _text = TextEditingController();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  Timer? _recordTimer;
  bool _sending = false, _recording = false;
  int _seconds = 0;
  String? _playingId;
  String? get _uid => _db.auth.currentUser?.id;

  @override
  void dispose() {
    _recordTimer?.cancel();
    if (_recording) unawaited(_recorder.stop());
    _recorder.dispose();
    _player.dispose();
    _text.dispose();
    super.dispose();
  }

  String _stamp(dynamic value) {
    final dt = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (dt == null) return '--:--:--';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}  ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  Future<void> _sendText() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _db.rpc('send_fun_game_room_message', params: {
        'p_room_id': widget.roomId, 'p_kind': 'text', 'p_body': body, 'p_media_path': null,
      }).timeout(const Duration(seconds: 10));
      _text.clear();
    } catch (e) {
      _notice('پیام فرستاده نشد: ${_friendly(e)}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startRecording() async {
    if (_recording || _sending) return;
    try {
      if (!await _recorder.hasPermission()) throw StateError('اجازهٔ میکروفن داده نشده است.');
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final path = kIsWeb ? 'game_voice_$stamp.webm' :
        '${(await getTemporaryDirectory()).path}/game_voice_$stamp.m4a';
      await _recorder.start(RecordConfig(
        encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
        bitRate: 64000, sampleRate: 24000, numChannels: 1,
      ), path: path);
      if (!mounted) return;
      setState(() { _recording = true; _seconds = 0; });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_recording) return;
        setState(() => _seconds++);
        if (_seconds >= 30) unawaited(_stopRecording());
      });
    } catch (e) { _notice(_friendly(e)); }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    if (!_recording) return;
    _recordTimer?.cancel(); _recordTimer = null;
    setState(() => _recording = false);
    try {
      final path = await _recorder.stop();
      if (cancel || path == null || path.isEmpty) return;
      final bytes = await XFile(path).readAsBytes();
      if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
        throw StateError('پیام صوتی خالی یا بزرگ‌تر از ۲ مگابایت است.');
      }
      final uid = _uid;
      if (uid == null) throw StateError('نشست کاربری پایان یافته است.');
      final ext = kIsWeb ? 'webm' : 'm4a';
      final key = '${widget.roomId}/$uid/${DateTime.now().microsecondsSinceEpoch}.$ext';
      setState(() => _sending = true);
      await _db.storage.from('fun-game-voice').uploadBinary(key, bytes,
        fileOptions: FileOptions(contentType: kIsWeb ? 'audio/webm' : 'audio/mp4', upsert: false));
      try {
        await _db.rpc('send_fun_game_room_message', params: {
          'p_room_id': widget.roomId, 'p_kind': 'voice', 'p_body': null, 'p_media_path': key,
        });
      } catch (_) {
        await _db.storage.from('fun-game-voice').remove([key]);
        rethrow;
      }
    } catch (e) { _notice('ارسال صدا ناموفق بود: ${_friendly(e)}'); }
    finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _play(Map<String, dynamic> row) async {
    final id = row['id'].toString(), key = row['media_path']?.toString() ?? '';
    if (key.isEmpty) return;
    try {
      final url = await _db.storage.from('fun-game-voice').createSignedUrl(key, 300);
      setState(() => _playingId = id);
      await _player.play(UrlSource(url));
    } catch (e) { _notice('پخش صدا ناموفق بود: ${_friendly(e)}'); }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('game_chat_rate_limited')) return 'کمی صبر کن و دوباره بفرست.';
    if (s.contains('not_a_game_participant')) return 'فقط بازیکنان این مسابقه می‌توانند پیام بدهند.';
    if (s.contains('opponent_not_connected')) return 'حریف هنوز وصل نشده است.';
    return s.replaceFirst('Exception: ', '');
  }

  void _notice(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55))),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Row(children: [
            Icon(Icons.forum_rounded, size: 18),
            SizedBox(width: 7),
            Text('گپ زندهٔ بازی', style: TextStyle(fontWeight: FontWeight.w900)),
            Spacer(),
            Text('زمان دقیق', style: TextStyle(fontSize: 10, color: Colors.green)),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 210,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _db.from('fun_game_room_messages').stream(primaryKey: ['id'])
                .eq('room_id', widget.roomId).order('created_at', ascending: true).limit(80),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('گپ فعلاً در دسترس نیست.'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final rows = snapshot.data!;
                if (rows.isEmpty) return const Center(child: Text('هنوز پیامی نیست؛ اولین پیام را بفرست.'));
                return ListView.builder(
                  reverse: false,
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index], mine = row['sender_id'] == uid;
                    final voice = row['message_type'] == 'voice';
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 270),
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: mine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(17), topRight: const Radius.circular(17),
                            bottomLeft: Radius.circular(mine ? 17 : 5), bottomRight: Radius.circular(mine ? 5 : 17)),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .28)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          if (voice)
                            TextButton.icon(
                              onPressed: () => _play(row),
                              icon: Icon(_playingId == row['id'] ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded),
                              label: const Text('پیام صوتی'),
                            )
                          else
                            Align(alignment: Alignment.centerLeft, child: Text(row['body']?.toString() ?? '')),
                          Text(_stamp(row['created_at']), style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 7),
          Row(children: [
            Expanded(child: TextField(
              controller: _text, minLines: 1, maxLines: 2,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendText(),
              decoration: InputDecoration(hintText: 'پیامت را بنویس…', isDense: true, filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .55),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5))),
            )),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: _sending ? null : _sendText,
              icon: _sending ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
            ),
            const SizedBox(width: 2),
            GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecording(),
              child: CircleAvatar(
                backgroundColor: _recording ? Colors.red : Theme.of(context).colorScheme.secondaryContainer,
                child: Icon(_recording ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: _recording ? Colors.white : Theme.of(context).colorScheme.onSecondaryContainer),
              ),
            ),
          ]),
          if (_recording) Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text('در حال ضبط… $_seconds ثانیه · برای ارسال رها کن',
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 11)),
          ),
        ]),
      ),
    );
  }
}
