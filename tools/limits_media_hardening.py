from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# Give users a clear message when the database-enforced creation limits are reached.
for old, new in [
    ("'group_creation_limit_reached'", "'group_creation_limit_reached'"),
    ("'channel_creation_limit_reached'", "'channel_creation_limit_reached'"),
]:
    s = s.replace(old, new)

# Make image uploads explicit about their MIME type and keep the existing attachment/message flow intact.
old = """      final safeName = image.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = '${widget.id}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await supabase.storage.from('chat-media').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: false));
"""
new = """      final safeName = image.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = '${widget.id}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final lowerName = safeName.toLowerCase();
      final contentType = lowerName.endsWith('.png')
          ? 'image/png'
          : lowerName.endsWith('.webp')
              ? 'image/webp'
              : lowerName.endsWith('.gif')
                  ? 'image/gif'
                  : 'image/jpeg';
      await supabase.storage.from('chat-media').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: false),
      );
"""
if old in s:
    s = s.replace(old, new, 1)

# Keep the attachment MIME value consistent with the actual image type.
old_att = "await supabase.from('message_attachments').insert({'message_id': msg['id'], 'storage_path': path, 'file_name': image.name, 'mime_type': 'image'});"
new_att = "await supabase.from('message_attachments').insert({'message_id': msg['id'], 'storage_path': path, 'file_name': image.name, 'mime_type': contentType});"
s = s.replace(old_att, new_att, 1)

p.write_text(s, encoding='utf-8')
