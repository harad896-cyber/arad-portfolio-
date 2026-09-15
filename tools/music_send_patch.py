from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

start = s.index('class _ChatPageState extends State<ChatPage> {')
end = s.index('class ProfilePage extends StatefulWidget {', start)
chat = s[start:end]

# Send music/audio files from the device through the existing chat-media bucket.
if 'Future<void> sendMusic() async {' not in chat:
    method = r'''
  Future<void> sendMusic() async {
    if (sending) return;
    setState(() => sending = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'opus', 'flac'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      final bytes = picked.bytes;
      if (bytes == null || bytes.isEmpty) throw Exception('فایل موسیقی خالی است');
      final safeName = picked.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final lower = safeName.toLowerCase();
      final contentType = lower.endsWith('.mp3')
          ? 'audio/mpeg'
          : lower.endsWith('.wav')
              ? 'audio/wav'
              : lower.endsWith('.ogg') || lower.endsWith('.opus')
                  ? 'audio/ogg'
                  : lower.endsWith('.flac')
                      ? 'audio/flac'
                      : lower.endsWith('.aac')
                          ? 'audio/aac'
                          : 'audio/mp4';
      final storagePath = '${widget.id}/music_${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await supabase.storage.from('chat-media').uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: false),
      );
      final msg = await supabase.from('messages').insert({
        'conversation_id': widget.id,
        'sender_id': supabase.auth.currentUser!.id,
        'body': picked.name,
        'message_type': 'audio',
      }).select().single();
      await supabase.from('message_attachments').insert({
        'message_id': msg['id'],
        'storage_path': storagePath,
        'file_name': picked.name,
        'mime_type': contentType,
      });
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'ارسال موسیقی ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

'''
    chat = chat.replace('  Future<void sendImage() async {', method + '  Future<void sendImage() async {', 1)

# Add a dedicated music picker button.
old = """                IconButton(onPressed: sendImage, tooltip: 'ارسال تصویر', icon: const Icon(Icons.image_rounded)),
                IconButton(onPressed: sendFile, tooltip: 'ارسال فایل', icon: const Icon(Icons.attach_file_rounded)),"""
new = """                IconButton(onPressed: sendImage, tooltip: 'ارسال تصویر', icon: const Icon(Icons.image_rounded)),
                IconButton(onPressed: sendMusic, tooltip: 'ارسال موسیقی', icon: const Icon(Icons.music_note_rounded)),
                IconButton(onPressed: sendFile, tooltip: 'ارسال فایل', icon: const Icon(Icons.attach_file_rounded)),"""
chat = chat.replace(old, new, 1)

# Display the music filename and reuse the audio player for playback.
chat = chat.replace(
    "if (m['message_type'] == 'audio')\n                                  _voicePlayButton('${m['id']}'),",
    "if (m['message_type'] == 'audio')\n                                  Row(mainAxisSize: MainAxisSize.min, children: [\n                                    IconButton(tooltip: 'پخش صدا', icon: const Icon(Icons.play_circle_fill_rounded, size: 42), onPressed: () async {\n                                      final url = attachmentUrls['${m['id']}'];\n                                      if (url == null) { showMsg(context, 'فایل هنوز آماده پخش نیست.'); return; }\n                                      try { await _voicePlayer.stop(); await _voicePlayer.play(UrlSource(url)); } catch (e) { if (mounted) showMsg(context, 'پخش فایل ناموفق بود: $e'); }\n                                    }),\n                                    Flexible(child: Text('${m['body'] ?? 'فایل صوتی'}', maxLines: 1, overflow: TextOverflow.ellipsis)),\n                                  ]),",
    1,
)

s = s[:start] + chat + s[end:]
p.write_text(s, encoding='utf-8')
