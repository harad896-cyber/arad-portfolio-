from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

marker = "  Widget _glassMessageBubble(Map<String, dynamic> m) {\n"
if marker not in s:
    raise SystemExit('chat bubble marker not found')

# Keep all existing message actions/attachments for normal chats, but give group
# messages a dedicated visual treatment matching the supplied reference.
if "_groupStyledMessageBubble(Map<String, dynamic> m)" not in s:
    s = s.replace(marker, marker + "    if (_chatType == 'group') return _groupStyledMessageBubble(m);\n", 1)

    method = r'''  Widget _groupStyledMessageBubble(Map<String, dynamic> m) {
    final mine = m['sender_id'] == supabase.auth.currentUser?.id;
    final senderId = m['sender_id']?.toString() ?? '';
    final profile = profiles[senderId];
    final sender = (profile?['display_name'] ?? profile?['username'] ?? 'عضو گروه').toString();
    final avatarUrl = (profile?['avatar_url'] ?? '').toString();
    final body = (m['body'] ?? '').toString();
    final type = (m['message_type'] ?? 'text').toString();
    final created = DateTime.tryParse((m['created_at'] ?? '').toString());
    final time = created == null ? '' : '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
    final bubble = mine ? const Color(0xFFB84F86) : const Color(0xFF263036);

    Widget content;
    if (type == 'image') {
      content = Container(width: 220, height: 150, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(14)), child: const Center(child: Icon(Icons.image_rounded, size: 42, color: Colors.white70)));
    } else if (type == 'audio') {
      content = Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 48, height: 48, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFB84F86), size: 30)),
        const SizedBox(width: 10),
        const Icon(Icons.graphic_eq_rounded, color: Colors.white70, size: 52),
        const SizedBox(width: 7),
        const Text('00:00', style: TextStyle(color: Colors.white70, fontSize: 12)),
      ]);
    } else if (type == 'file') {
      content = Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.insert_drive_file_rounded, color: Colors.white70, size: 32),
        const SizedBox(width: 9),
        Flexible(child: Text(body.isEmpty ? 'فایل' : body, style: const TextStyle(color: Colors.white, fontSize: 15))),
      ]);
    } else {
      content = Text(body, style: const TextStyle(fontSize: 16, height: 1.42, color: Colors.white));
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (!mine) ...[
          CircleAvatar(radius: 18, backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null, backgroundColor: const Color(0xFF17191C), child: avatarUrl.isEmpty ? const Icon(Icons.person_rounded, color: Colors.white60, size: 19) : null),
          const SizedBox(width: 7),
        ],
        Flexible(child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .84),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(13, 9, 11, 7),
          decoration: BoxDecoration(
            color: bubble,
            borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: Radius.circular(mine ? 20 : 5), bottomRight: Radius.circular(mine ? 5 : 20)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .32), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!mine) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(sender, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFE4A7C8), fontSize: 14.5))),
            content,
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(time, style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
                if (mine) ...[const SizedBox(width: 4), const Icon(Icons.done_all_rounded, size: 15, color: Color(0xFFBDE0FF))],
              ]),
            ],
          ]),
        )),
      ]),
    );
  }

'''
    anchor = "  @override\n  void initState() {\n    super.initState();\n    load();\n    _loadChatType();"
    if anchor not in s:
        raise SystemExit('chat init anchor not found')
    s = s.replace(anchor, method + anchor, 1)

# Dark group header/background. These replacements are intentionally narrow.
s = s.replace("backgroundColor: scheme.surface,\n        surfaceTintColor: Colors.transparent,", "backgroundColor: _chatType == 'group' ? const Color(0xFF17171A) : scheme.surface,\n        surfaceTintColor: Colors.transparent,", 1)
s = s.replace("color: scheme.onSurface.withValues(alpha: .07))),", "color: _chatType == 'group' ? Colors.white.withValues(alpha: .06) : scheme.onSurface.withValues(alpha: .07))),", 1)

old = """      body: Container(\n        decoration: BoxDecoration(\n          color: dark ? const Color(0xFF14171B) : const Color(0xFFEFF2F5),\n        ),"""
new = """      body: Container(\n        decoration: BoxDecoration(\n          color: _chatType == 'group' ? const Color(0xFF0B0D0F) : (dark ? const Color(0xFF14171B) : const Color(0xFFEFF2F5)),\n          gradient: _chatType == 'group' ? const RadialGradient(center: Alignment(0.82, -0.85), radius: 1.15, colors: [Color(0x222A1724), Color(0xFF0B0D0F)]) : null,\n        ),"""
if old in s:
    s = s.replace(old, new, 1)

p.write_text(s, encoding='utf-8')
print('group chat style applied')
