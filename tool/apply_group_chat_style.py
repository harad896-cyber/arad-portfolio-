from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

marker = "  Widget _glassMessageBubble(Map<String, dynamic> m) {\n"
if marker not in s:
    raise SystemExit('chat bubble marker not found')
if "_groupStyledMessageBubble" not in s:
    s = s.replace(marker, marker + "    if (_chatType == 'group') return _groupStyledMessageBubble(m);\n", 1)

if "Widget _groupStyledMessageBubble(Map<String, dynamic> m)" not in s:
    method = r'''  Widget _groupStyledMessageBubble(Map<String, dynamic> m) {
    final mine = m['sender_id'] == supabase.auth.currentUser!.id;
    final sender = _senderName(m);
    final avatarUrl = profiles['${m['sender_id']}']?['avatar_url']?.toString() ?? '';
    final body = (m['body'] ?? '').toString();
    final scheme = Theme.of(context).colorScheme;
    final myBubble = const Color(0xFFB84F86);
    final otherBubble = const Color(0xFF263036);
    final textColor = Colors.white;
    final urlMatch = RegExp(r'https?://\\S+').firstMatch(body);
    Widget content;
    if (m['message_type'] == 'image') {
      content = _imageAttachment(m);
    } else if (m['message_type'] == 'audio') {
      content = _voicePlayButton(m['id'].toString());
    } else if (m['message_type'] == 'file') {
      content = _fileAttachment(m);
    } else if (urlMatch != null && urlMatch.start == 0) {
      final url = urlMatch.group(0)!;
      content = Container(
        width: 235,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(15)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: double.infinity, height: 82, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(11)), child: const Center(child: Icon(Icons.language_rounded, size: 32, color: Colors.white70))),
          const SizedBox(height: 7),
          const Text('پیش‌نمایش لینک', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          Text(Uri.tryParse(url)?.host ?? 'لینک', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
        ]),
      );
    } else {
      content = Text(body, style: const TextStyle(fontSize: 16, height: 1.42, color: Colors.white));
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => showMessageActions(m),
        onDoubleTap: () => reactTo(m, '❤️'),
        onHorizontalDragEnd: (details) { if ((details.primaryVelocity ?? 0).abs() > 450) setReply(m); },
        child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (!mine) ...[
            CircleAvatar(radius: 18, backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null, backgroundColor: const Color(0xFF111518), child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 18, color: Colors.white70) : null),
            const SizedBox(width: 7),
          ],
          Flexible(child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .84),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(13, 9, 11, 7),
            decoration: BoxDecoration(
              color: mine ? myBubble : otherBubble,
              borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: Radius.circular(mine ? 20 : 5), bottomRight: Radius.circular(mine ? 5 : 20)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .30), blurRadius: 10, offset: const Offset(0, 3))],
              border: Border.all(color: Colors.white.withValues(alpha: .055)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!mine) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(sender, style: TextStyle(fontWeight: FontWeight.w900, color: scheme.secondaryContainer, fontSize: 14.5))),
              _replyPreview(m),
              content,
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_time(m['created_at']), style: TextStyle(fontSize: 10.5, color: textColor.withValues(alpha: .68))),
                if (mine) ...[const SizedBox(width: 4), Icon(m['read_at'] != null ? Icons.done_all_rounded : Icons.done_rounded, size: 15, color: const Color(0xFFBDE0FF))],
              ]),
              _reactionRow(m),
            ]),
          )),
        ]),
      ),
    );
  }

'''
    anchor = "  @override\n  void initState() {\n    super.initState();\n    load();\n    _loadChatType();"
    if anchor not in s:
        raise SystemExit('chat init anchor not found')
    s = s.replace(anchor, method + anchor, 1)

# Group chat header and background colors.
s = s.replace("backgroundColor: scheme.surface,\n        surfaceTintColor: Colors.transparent,", "backgroundColor: _chatType == 'group' ? const Color(0xFF17171A) : scheme.surface,\n        surfaceTintColor: Colors.transparent,", 1)
s = s.replace("bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: scheme.onSurface.withValues(alpha: .07))),", "bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: _chatType == 'group' ? Colors.white.withValues(alpha: .06) : scheme.onSurface.withValues(alpha: .07))),", 1)
s = s.replace("const CircleAvatar(radius: 17, child: Icon(Icons.groups_rounded, size: 18)),", "CircleAvatar(radius: 18, backgroundColor: _chatType == 'group' ? const Color(0xFF3B303A) : scheme.primaryContainer, child: Icon(_chatType == 'group' ? Icons.groups_rounded : Icons.person_rounded, size: 19, color: _chatType == 'group' ? const Color(0xFFE7A6C8) : scheme.primary)),", 1)

old = """      body: Container(\n        decoration: BoxDecoration(\n          color: dark ? const Color(0xFF14171B) : const Color(0xFFEFF2F5),\n        ),"""
new = """      body: Container(\n        decoration: BoxDecoration(\n          color: _chatType == 'group' ? const Color(0xFF0B0D0F) : (dark ? const Color(0xFF14171B) : const Color(0xFFEFF2F5)),\n          gradient: _chatType == 'group' ? const RadialGradient(center: Alignment(0.82, -0.85), radius: 1.15, colors: [Color(0x222A1724), Color(0xFF0B0D0F)]) : null,\n        ),"""
if old in s:
    s = s.replace(old, new, 1)
else:
    raise SystemExit('chat body marker not found')

p.write_text(s, encoding='utf-8')
print('group chat style applied')
