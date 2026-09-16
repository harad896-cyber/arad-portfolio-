from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# The final ChatPage rebuild previously replaced the profile/voice UI added earlier.
# Restore an actual peer profile header using the already-loaded chatPeer state.
old = """title: Row(children: [
          CircleAvatar(radius: 19, child: Text(widget.title.isEmpty ? 'A' : widget.title.substring(0, 1))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const Text('آنلاین و امن', style: TextStyle(fontSize: 11)),
          ])),
        ]),"""
new = """title: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final p = chatPeer;
            if (p == null) return;
            showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => SafeArea(child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  avatar(p, size: 88),
                  const SizedBox(height: 12),
                  Text('${p['display_name'] ?? 'کاربر'}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  if ('${p['username'] ?? ''}'.isNotEmpty) Text('@${p['username']}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('${p['bio'] ?? ''}'.trim().isEmpty ? 'شرحی ثبت نشده است.' : '${p['bio']}', textAlign: TextAlign.center),
                ]),
              )),
            );
          },
          child: Row(children: [
            avatar(chatPeer ?? const <String,dynamic>{}, size: 38),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${chatPeer?['display_name'] ?? widget.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              Text(chatPeer == null ? 'گفتگو' : (('${chatPeer?['username'] ?? ''}').isEmpty ? 'پروفایل' : '@${chatPeer?['username']}'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ])),
          ]),
        ),"""
if old in s:
    s = s.replace(old, new, 1)

# Make voice recording visible and usable in the composer.
old_controls = """IconButton(onPressed: sendImage, icon: const Icon(Icons.photo_outlined)), IconButton(onPressed: sendFile, icon: const Icon(Icons.attach_file_rounded)),
          Expanded"""
new_controls = """IconButton(onPressed: sendImage, tooltip: 'تصویر', icon: const Icon(Icons.photo_outlined)), IconButton(onPressed: sendFile, tooltip: 'فایل', icon: const Icon(Icons.attach_file_rounded)),
          IconButton(onPressed: toggleVoiceRecording, tooltip: recordingVoice ? 'توقف و ارسال ویس' : 'ضبط ویس', icon: Icon(recordingVoice ? Icons.stop_circle_rounded : Icons.mic_rounded)),
          Expanded"""
if old_controls in s:
    s = s.replace(old_controls, new_controls, 1)

# Render audio messages with a real play control when the attachment URL is available.
audio_marker = """if (m['message_type'] == 'file' && !deleted) const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.insert_drive_file_rounded)),
                  Text(deleted ? 'این پیام حذف شده است' : body,"""
audio_new = """if (m['message_type'] == 'file' && !deleted) const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.insert_drive_file_rounded)),
                  if (m['message_type'] == 'audio' && !deleted) _voicePlayButton('${m['id']}'),
                  if (m['message_type'] != 'audio') Text(deleted ? 'این پیام حذف شده است' : body,"""
if audio_marker in s:
    s = s.replace(audio_marker, audio_new, 1)

# Close the conditional Text introduced above before the edited/reaction rows.
needle = """                  if (m['edited_at'] != null && !deleted) const Padding"""
if needle in s and "if (m['message_type'] != 'audio') Text(deleted ? 'این پیام حذف شده است' : body" in s:
    # The original Text ends with a single '),'. Convert it to the same conditional expression cleanly.
    s = s.replace("""                  Text(deleted ? 'این پیام حذف شده است' : body, style: TextStyle(fontSize: 15.5, height: 1.35, fontStyle: deleted ? FontStyle.italic : FontStyle.normal)),
""", """                  if (m['message_type'] != 'audio') Text(deleted ? 'این پیام حذف شده است' : body, style: TextStyle(fontSize: 15.5, height: 1.35, fontStyle: deleted ? FontStyle.italic : FontStyle.normal)),
""", 1)

# Keep the default accent explicitly Telegram-like blue.
s = s.replace('Color(0xFF229ED9), Color(0xFF4F46E5)', 'Color(0xFF229ED9), Color(0xFF4F46E5)', 1)

p.write_text(s, encoding='utf-8')
print('Final messenger UI fixes applied')
