from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# Imports required for reliable recording/upload/playback.
if "import 'dart:io';" not in s:
    s = s.replace("import 'dart:async';", "import 'dart:async';\nimport 'dart:io';", 1)
if "import 'package:record/record.dart';" not in s:
    s = s.replace("import 'package:image_picker/image_picker.dart';", "import 'package:image_picker/image_picker.dart';\nimport 'package:record/record.dart';\nimport 'package:audioplayers/audioplayers.dart';", 1)

start = s.index('class _ChatPageState extends State<ChatPage> {')
end = s.index('class ProfilePage extends StatefulWidget {', start)
chat = s[start:end]

# State for the direct-chat peer and voice recording.
if 'Map<String, dynamic>? chatPeer;' not in chat:
    chat = chat.replace('  bool sending = false;', '  bool sending = false;\n  Map<String, dynamic>? chatPeer;\n  final AudioRecorder _voiceRecorder = AudioRecorder();\n  bool recordingVoice = false;\n  final AudioPlayer _voicePlayer = AudioPlayer();', 1)

# Load peer profile immediately, not only after opening the profile sheet.
if 'Future<void> loadChatPeer() async {' not in chat:
    method = r'''
  Future<void> loadChatPeer() async {
    try {
      final me = supabase.auth.currentUser?.id;
      if (me == null) return;
      final conv = await supabase.from('conversations').select('id,type,title').eq('id', widget.id).maybeSingle();
      if (conv == null || conv['type'] != 'direct') return;
      final members = await supabase.from('conversation_members').select('user_id').eq('conversation_id', widget.id);
      final ids = List<Map<String, dynamic>>.from(members)
          .map((m) => '${m['user_id']}')
          .where((id) => id != me)
          .toList();
      if (ids.isEmpty) return;
      final rows = await supabase.from('profiles')
          .select('id,display_name,username,avatar_url,bio,is_verified')
          .eq('id', ids.first)
          .limit(1);
      if (!mounted || rows.isEmpty) return;
      setState(() => chatPeer = Map<String, dynamic>.from(rows.first));
    } catch (_) {}
  }

'''
    marker = '  @override\n  Widget build(BuildContext context) {'
    chat = chat.replace(marker, method + marker, 1)

# Ensure peer profile is fetched during initialization.
chat = chat.replace('void initState() { super.initState(); load(); }', 'void initState() { super.initState(); load(); loadChatPeer(); }', 1)

# Replace the old image sender with a hardened version that uses explicit MIME type and records the attachment.
pattern = re.compile(r"  Future<void> sendImage\(\) async \{.*?\n  \}", re.S)
new_send_image = r'''  Future<void> sendImage() async {
    if (sending) return;
    setState(() => sending = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) throw Exception('فایل تصویر خالی است');
      final safeName = image.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final lower = safeName.toLowerCase();
      final contentType = lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
              ? 'image/webp'
              : lower.endsWith('.gif')
                  ? 'image/gif'
                  : 'image/jpeg';
      final path = '${widget.id}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await supabase.storage.from('chat-media').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: false),
      );
      final msg = await supabase.from('messages').insert({
        'conversation_id': widget.id,
        'sender_id': supabase.auth.currentUser!.id,
        'body': image.name,
        'message_type': 'image',
      }).select().single();
      await supabase.from('message_attachments').insert({
        'message_id': msg['id'],
        'storage_path': path,
        'file_name': image.name,
        'mime_type': contentType,
      });
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'تصویر ارسال نشد: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }'''
chat, count = pattern.subn(new_send_image, chat, count=1)

# Voice recording: hold/tap microphone to start, tap again to stop and send.
if 'Future<void> toggleVoiceRecording() async {' not in chat:
    voice = r'''

  Future<void> toggleVoiceRecording() async {
    if (sending) return;
    try {
      if (recordingVoice) {
        final path = await _voiceRecorder.stop();
        if (mounted) setState(() => recordingVoice = false);
        if (path == null || path.isEmpty) return;
        final file = File(path);
        if (!await file.exists()) throw Exception('فایل ویس ساخته نشد');
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) throw Exception('فایل ویس خالی است');
        setState(() => sending = true);
        final safe = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        final storagePath = '${widget.id}/$safe';
        await supabase.storage.from('chat-media').uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(contentType: 'audio/mp4', upsert: false),
        );
        final msg = await supabase.from('messages').insert({
          'conversation_id': widget.id,
          'sender_id': supabase.auth.currentUser!.id,
          'body': 'پیام صوتی',
          'message_type': 'audio',
        }).select().single();
        await supabase.from('message_attachments').insert({
          'message_id': msg['id'],
          'storage_path': storagePath,
          'file_name': safe,
          'mime_type': 'audio/mp4',
        });
        try { await file.delete(); } catch (_) {}
        await load();
      } else {
        final ok = await _voiceRecorder.hasPermission();
        if (!ok) {
          if (mounted) showMsg(context, 'دسترسی میکروفون فعال نیست.');
          return;
        }
        final path = '${Directory.systemTemp.path}/arad_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _voiceRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
          path: path,
        );
        if (mounted) setState(() => recordingVoice = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() { recordingVoice = false; sending = false; });
        showMsg(context, 'ارسال ویس ناموفق بود: $e');
      }
    } finally {
      if (mounted && !recordingVoice) setState(() => sending = false);
    }
  }
'''
    # Insert before sendImage (or before build if somehow absent).
    chat = chat.replace('  Future<void sendImage() async {', voice + '\n  Future<void sendImage() async {', 1)

# Dispose audio resources with the chat page.
if 'await _voiceRecorder.dispose();' not in chat:
    marker = '  @override\n  Widget build(BuildContext context) {'
    dispose = "  @override\n  void dispose() {\n    _voiceRecorder.dispose();\n    _voicePlayer.dispose();\n    text.dispose();\n    super.dispose();\n  }\n\n"
    chat = chat.replace(marker, dispose + marker, 1)

# Replace the simple chat app bar with a Telegram-like always-visible peer header.
old_app = "      appBar: AppBar(title: Text(widget.title)),"
new_app = r'''      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final p = chatPeer;
            if (p == null) return;
            showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (sheet) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    avatar(p, size: 86),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Flexible(child: Text('${p['display_name'] ?? 'کاربر'}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis)),
                      if (p['is_verified'] == true) const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.verified_rounded, color: Colors.blue, size: 22)),
                    ]),
                    const SizedBox(height: 3),
                    Text(p['username'] == null || '${p['username']}'.isEmpty ? 'بدون نام کاربری' : '@${p['username']}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Text('${p['bio'] ?? ''}'.trim().isEmpty ? 'شرحی ثبت نشده است.' : '${p['bio']}', textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Text('شناسه: ${p['id'] ?? ''}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ]),
                ),
              ),
            );
          },
          child: Row(children: [
            avatar(chatPeer ?? const <String, dynamic>{}, size: 38),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(children: [
                Flexible(child: Text('${chatPeer?['display_name'] ?? widget.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                if (chatPeer?['is_verified'] == true) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, color: Colors.blue, size: 16)),
              ]),
              Text(chatPeer == null ? 'گفتگو' : (chatPeer?['username'] == null || '${chatPeer?['username']}'.isEmpty ? 'پروفایل' : '@${chatPeer?['username']}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ])),
          ]),
        ),
'''
if old_app in chat:
    chat = chat.replace(old_app, new_app, 1)

# Add microphone button beside image/file controls.
old_controls = """                IconButton(onPressed: sendImage, icon: const Icon(Icons.image)),
                IconButton(onPressed: sendFile, icon: const Icon(Icons.attach_file)),"""
new_controls = """                IconButton(onPressed: sendImage, tooltip: 'ارسال تصویر', icon: const Icon(Icons.image_rounded)),
                IconButton(onPressed: sendFile, tooltip: 'ارسال فایل', icon: const Icon(Icons.attach_file_rounded)),
                IconButton(onPressed: toggleVoiceRecording, tooltip: recordingVoice ? 'توقف و ارسال ویس' : 'ضبط ویس', icon: Icon(recordingVoice ? Icons.stop_circle_rounded : Icons.mic_rounded)),"""
chat = chat.replace(old_controls, new_controls, 1)

# Render images from signed URLs and audio with a play button.
if "m['message_type'] == 'audio'" not in chat:
    marker = """                                if (m['message_type'] == 'image') const Icon(Icons.image),
                                Text('${m['body'] ?? ''}'),"""
    replacement = r'''                                if (m['message_type'] == 'image')
                                  attachmentUrls['${m['id']}'] != null
                                      ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(attachmentUrls['${m['id']}']!, width: 250, height: 250, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 42)))
                                      : const SizedBox(width: 250, height: 100, child: Center(child: CircularProgressIndicator())),
                                if (m['message_type'] == 'audio')
                                  _voicePlayButton('${m['id']}'),
                                if (m['message_type'] != 'image' && m['message_type'] != 'audio')
                                  Text('${m['body'] ?? ''}'),'''
    if marker in chat:
        chat = chat.replace(marker, replacement, 1)

# Add a small audio playback widget using the same signed attachment URL map.
if 'Widget _voicePlayButton(String messageId)' not in chat:
    marker = '  @override\n  Widget build(BuildContext context) {'
    player = r'''
  Widget _voicePlayButton(String messageId) {
    return IconButton(
      tooltip: 'پخش ویس',
      icon: const Icon(Icons.play_circle_fill_rounded, size: 42),
      onPressed: () async {
        final url = attachmentUrls[messageId];
        if (url == null) {
          showMsg(context, 'ویس هنوز آماده پخش نیست.');
          return;
        }
        try { await _voicePlayer.stop(); await _voicePlayer.play(UrlSource(url)); }
        catch (e) { if (mounted) showMsg(context, 'پخش ویس ناموفق بود: $e'); }
      },
    );
  }

'''
    chat = chat.replace(marker, player + marker, 1)

# Replace the attachment loader condition so both image and audio files get signed URLs.
chat = chat.replace("if (path.isNotEmpty && (mime.isEmpty || mime.startsWith('image'))) {", "if (path.isNotEmpty && (mime.isEmpty || mime.startsWith('image') || mime.startsWith('audio'))) {", 1)

s = s[:start] + chat + s[end:]
p.write_text(s, encoding='utf-8')
