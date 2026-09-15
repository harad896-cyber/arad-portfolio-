from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

old_group = """      final uniqueIds = <String>{uid, ...selected.map((p) => '${p['id']}')};
      final members = uniqueIds.map((memberId) => {'conversation_id': c['id'], 'user_id': memberId}).toList();
      await supabase.from('conversation_members').insert(members);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatPage(id: '${c['id']}', title: title.text.trim())));
      }"""
new_group = """      final uniqueIds = <String>{...selected.map((p) => '${p['id']}')}..remove(uid);
      if (uniqueIds.isNotEmpty) {
        final members = uniqueIds.map((memberId) => {'conversation_id': c['id'], 'user_id': memberId}).toList();
        await supabase.from('conversation_members').insert(members);
      }
      if (mounted) {
        final inviteCode = '${c['invite_code'] ?? ''}'.trim();
        final titleValue = title.text.trim();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatPage(id: '${c['id']}', title: titleValue)));
        if (inviteCode.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final link = 'https://bkbdcqequyvubjmrbpqo.supabase.co/functions/v1/conversation-invite?code=${Uri.encodeComponent(inviteCode)}';
            showDialog<void>(
              context: context,
              builder: (dialog) => AlertDialog(
                title: const Text('گروه ساخته شد ✅'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('لینک دعوت گروه آماده است.'),
                  const SizedBox(height: 12),
                  SelectableText(link, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                ]),
                actions: [
                  TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: link)); Navigator.pop(dialog); }, child: const Text('کپی لینک')),
                  FilledButton(onPressed: () => Navigator.pop(dialog), child: const Text('باشه')),
                ],
              ),
            );
          });
        }
      }"""
if old_group in s:
    s = s.replace(old_group, new_group, 1)

old_tile = """                  return ListTile(leading: const CircleAvatar(child: Icon(Icons.chat)), title: Text(title), subtitle: Text('${c['last_message'] ?? ''}'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(id: '${c['id']}', title: title))));"""
new_tile = """                  final isGroup = c['type'] == 'group';
                  final isChannel = c['type'] == 'channel';
                  return ListTile(
                    leading: CircleAvatar(child: Icon(isGroup ? Icons.groups_rounded : isChannel ? Icons.campaign_rounded : Icons.chat_rounded)),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(isGroup ? 'گروه' : isChannel ? 'کانال' : '${c['last_message'] ?? ''}'),
                    trailing: (isGroup || isChannel) ? const Icon(Icons.chevron_left_rounded) : null,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(id: '${c['id']}', title: title))).then((_) => load()),
                  );"""
if old_tile in s:
    s = s.replace(old_tile, new_tile, 1)

p.write_text(s, encoding='utf-8')
