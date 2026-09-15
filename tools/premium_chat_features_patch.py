from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')
start = s.index('class ChatPage extends StatefulWidget {')
end = s.index('class ProfilePage extends StatefulWidget {', start)

new_chat = r'''class ChatPage extends StatefulWidget {
  final String id;
  final String title;

  const ChatPage({super.key, required this.id, required this.title});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final text = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  Map<String, Map<String, dynamic>> profiles = {};
  Map<String, Map<String, dynamic>> senderStats = {};
  Map<String, List<Map<String, dynamic>>> reactions = {};
  Map<String, dynamic>? conversation;
  RealtimeChannel? channel;
  bool loading = true;
  bool sending = false;
  Map<String, dynamic>? replyMessage;
  int wallpaperIndex = 0;
  int bubbleIndex = 0;

  static const wallpapers = <Color>[
    Color(0xFFF5F7FB), Color(0xFFEAF4FF), Color(0xFFF5EEFF),
    Color(0xFFFFF5E8), Color(0xFFEAF9F1), Color(0xFFFFEEF2),
  ];
  static const mineColors = <Color>[
    Color(0xFFDCE7FF), Color(0xFFDDF7EA), Color(0xFFFFE6F0),
    Color(0xFFFFEFD2), Color(0xFFEAE0FF), Color(0xFFDFF7F8),
  ];

  String _time(dynamic value) {
    final dt = DateTime.tryParse('$value')?.toLocal();
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _dateLabel(dynamic value) {
    final dt = DateTime.tryParse('$value')?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'امروز';
    if (diff == 1) return 'دیروز';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  String _senderName(Map<String, dynamic> m) {
    final p = profiles['${m['sender_id']}'];
    if (p == null) return m['sender_id'] == supabase.auth.currentUser?.id ? 'شما' : 'کاربر';
    return '${p['display_name'] ?? p['username'] ?? 'کاربر'}';
  }

  String _senderUsername(Map<String, dynamic> m) {
    final p = profiles['${m['sender_id']}'];
    final username = '${p?['username'] ?? ''}'.trim();
    if (username.isNotEmpty) return '@$username';
    final id = '${m['sender_id'] ?? ''}';
    return id.length > 8 ? 'ID: ${id.substring(0, 8)}…' : 'ID: $id';
  }

  String _rankLabel(Map<String, dynamic>? stats) {
    if (stats == null) return '🌱 تازه‌وارد';
    return '${stats['rank_icon'] ?? '🌱'} ${stats['rank_name'] ?? 'تازه‌وارد'}';
  }

  Future<void> loadAppearance() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_style_${widget.id}';
    if (mounted) {
      setState(() {
        wallpaperIndex = prefs.getInt('${key}_wallpaper') ?? 0;
        bubbleIndex = prefs.getInt('${key}_bubble') ?? 0;
      });
    }
  }

  Future<void> saveAppearance() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_style_${widget.id}';
    await prefs.setInt('${key}_wallpaper', wallpaperIndex);
    await prefs.setInt('${key}_bubble', bubbleIndex);
  }

  Future<void> load() async {
    try {
      final c = await supabase.from('conversations').select('id,type,title,invite_code,allow_reactions,allow_member_add,created_by').eq('id', widget.id).maybeSingle();
      final rows = await supabase.from('messages').select().eq('conversation_id', widget.id).order('created_at');
      final loaded = List<Map<String, dynamic>>.from(rows);
      final senderIds = loaded.map((m) => '${m['sender_id']}').toSet().toList();
      if (senderIds.isNotEmpty) {
        final people = await supabase.from('profiles').select('id,display_name,username,avatar_url').inFilter('id', senderIds);
        profiles = {for (final p in List<Map<String, dynamic>>.from(people)) '${p['id']}': p};
        try {
          final stats = await supabase.rpc('get_chat_sender_stats', params: {'p_conversation_id': widget.id, 'p_user_ids': senderIds});
          senderStats = {for (final x in List<Map<String, dynamic>>.from(stats)) '${x['user_id']}': x};
        } catch (_) {
          senderStats = {};
        }
      }
      final ids = loaded.map((m) => '${m['id']}').toList();
      final loadedReactions = <String, List<Map<String, dynamic>>>{};
      if (ids.isNotEmpty) {
        final rr = await supabase.from('message_reactions').select('message_id,user_id,reaction,created_at').inFilter('message_id', ids);
        for (final r in List<Map<String, dynamic>>.from(rr)) {
          loadedReactions.putIfAbsent('${r['message_id']}', () => []).add(r);
        }
      }
      if (mounted) {
        setState(() {
          conversation = c;
          messages = loaded;
          reactions = loadedReactions;
          loading = false;
        });
      }
      await markRead();
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        showMsg(context, 'خطا در پیام‌ها: $e');
      }
    }
  }

  Future<void> markRead() async {
    try {
      final rows = await supabase.from('messages').select('id').eq('conversation_id', widget.id).neq('sender_id', supabase.auth.currentUser!.id);
      for (final row in rows) {
        await supabase.rpc('mark_message_read', params: {'p_message_id': row['id']});
      }
    } catch (_) {}
  }

  Future<void> sendText() async {
    final value = text.text.trim();
    if (value.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await supabase.from('messages').insert({
        'conversation_id': widget.id,
        'sender_id': supabase.auth.currentUser!.id,
        'body': value,
        'message_type': 'text',
        'reply_to': replyMessage?['id'],
      });
      text.clear();
      if (mounted) setState(() => replyMessage = null);
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'ارسال نشد: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> sendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null) return;
      final f = result.files.single;
      final bytes = f.bytes;
      if (bytes == null) return;
      final path = '${widget.id}/${DateTime.now().millisecondsSinceEpoch}_${f.name}';
      await supabase.storage.from('chat-media').uploadBinary(path, bytes);
      final msg = await supabase.from('messages').insert({'conversation_id': widget.id, 'sender_id': supabase.auth.currentUser!.id, 'body': f.name, 'message_type': 'file', 'reply_to': replyMessage?['id']}).select().single();
      await supabase.from('message_attachments').insert({'message_id': msg['id'], 'storage_path': path, 'file_name': f.name, 'file_size': f.size});
      if (mounted) setState(() => replyMessage = null);
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'فایل ارسال نشد: $e');
    }
  }

  Future<void> sendImage() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final path = '${widget.id}/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      await supabase.storage.from('chat-media').uploadBinary(path, bytes);
      final msg = await supabase.from('messages').insert({'conversation_id': widget.id, 'sender_id': supabase.auth.currentUser!.id, 'body': image.name, 'message_type': 'image', 'reply_to': replyMessage?['id']}).select().single();
      await supabase.from('message_attachments').insert({'message_id': msg['id'], 'storage_path': path, 'file_name': image.name, 'mime_type': 'image'});
      if (mounted) setState(() => replyMessage = null);
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'تصویر ارسال نشد: $e');
    }
  }

  Future<void> reactTo(Map<String, dynamic> message, String emoji) async {
    try {
      await supabase.rpc('set_message_reaction', params: {'p_message_id': message['id'], 'p_reaction': emoji});
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'واکنش ذخیره نشد: $e');
    }
  }

  void setReply(Map<String, dynamic> message) => setState(() => replyMessage = message);

  Future<void> showMessageActions(Map<String, dynamic> message) async {
    const emojis = ['❤️', '👍', '😂', '😮', '😢', '🔥'];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(alignment: WrapAlignment.center, spacing: 8, children: emojis.map((e) => InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () { Navigator.pop(sheetContext); reactTo(message, e); },
              child: Padding(padding: const EdgeInsets.all(9), child: Text(e, style: const TextStyle(fontSize: 27))),
            )).toList()),
            const Divider(height: 18),
            ListTile(leading: const Icon(Icons.reply_rounded), title: const Text('پاسخ به این پیام'), onTap: () { Navigator.pop(sheetContext); setReply(message); }),
            ListTile(leading: const Icon(Icons.copy_rounded), title: const Text('کپی متن'), enabled: '${message['body'] ?? ''}'.isNotEmpty, onTap: () { Clipboard.setData(ClipboardData(text: '${message['body'] ?? ''}')); Navigator.pop(sheetContext); showMsg(context, 'متن کپی شد.'); }),
          ]),
        ),
      ),
    );
  }

  Widget _replyPreview(Map<String, dynamic> message) {
    final id = '${message['reply_to'] ?? ''}';
    if (id.isEmpty) return const SizedBox.shrink();
    Map<String, dynamic>? parent;
    for (final item in messages) { if ('${item['id']}' == id) { parent = item; break; } }
    if (parent == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
      child: Text('${_senderName(parent!)}: ${parent['body'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
    );
  }

  Widget _reactionRow(Map<String, dynamic> message) {
    final list = reactions['${message['id']}'] ?? const <Map<String, dynamic>>[];
    if (list.isEmpty) return const SizedBox.shrink();
    final counts = <String, int>{};
    for (final r in list) { final emoji = '${r['reaction']}'; counts[emoji] = (counts[emoji] ?? 0) + 1; }
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Wrap(spacing: 4, children: counts.entries.map((e) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => reactTo(message, e.key),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)), child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 12))),
      )).toList()),
    );
  }

  Widget _senderHeader(Map<String, dynamic> m, Map<String, dynamic>? p, Map<String, dynamic>? stats) {
    final url = '${p?['avatar_url'] ?? ''}';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      CircleAvatar(radius: 15, backgroundImage: url.isNotEmpty ? NetworkImage(url) : null, child: url.isEmpty ? const Icon(Icons.person, size: 17) : null),
      const SizedBox(width: 7),
      Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_senderName(m), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
        Text('${_senderUsername(m)}  •  ${_rankLabel(stats)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
      ])),
    ]);
  }

  Widget _messageBubble(Map<String, dynamic> m) {
    final mine = m['sender_id'] == supabase.auth.currentUser!.id;
    final p = profiles['${m['sender_id']}'];
    final stats = senderStats['${m['sender_id']}'];
    final url = '${p?['avatar_url'] ?? ''}';
    final bubbleColor = mine ? mineColors[bubbleIndex.clamp(0, mineColors.length - 1)] : Theme.of(context).colorScheme.surface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => showMessageActions(m),
        onHorizontalDragEnd: (details) { if ((details.primaryVelocity ?? 0).abs() > 450) setReply(m); },
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .88),
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (!mine) ...[CircleAvatar(radius: 19, backgroundImage: url.isNotEmpty ? NetworkImage(url) : null, child: url.isEmpty ? const Icon(Icons.person, size: 20) : null), const SizedBox(width: 6)],
            Flexible(child: Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: bubbleColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .45))),
              child: Padding(padding: const EdgeInsets.fromLTRB(12, 9, 10, 7), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (!mine) Padding(padding: const EdgeInsets.only(bottom: 6), child: _senderHeader(m, p, stats)),
                if (mine) Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(radius: 13, backgroundImage: url.isNotEmpty ? NetworkImage(url) : null, child: url.isEmpty ? const Icon(Icons.person, size: 14) : null), const SizedBox(width: 6),
                  Text('${_senderUsername(m)}  •  ${_rankLabel(stats)}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ])),
                _replyPreview(m),
                if (m['message_type'] == 'image') const Padding(padding: EdgeInsets.only(bottom: 5), child: Icon(Icons.image_rounded, size: 42)),
                if ('${m['body'] ?? ''}'.isNotEmpty) Text('${m['body'] ?? ''}', style: const TextStyle(fontSize: 15.5, height: 1.42)),
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${_dateLabel(m['created_at'])}  ${_time(m['created_at'])}', style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  if (mine) ...[const SizedBox(width: 4), Icon(m['read_at'] != null ? Icons.done_all_rounded : Icons.done_rounded, size: 15, color: m['read_at'] != null ? Colors.blue : null)],
                ]),
                _reactionRow(m),
              ])),
            )),
            if (mine) ...[const SizedBox(width: 6), CircleAvatar(radius: 19, backgroundImage: url.isNotEmpty ? NetworkImage(url) : null, child: url.isEmpty ? const Icon(Icons.person, size: 20) : null)],
          ]),
        ),
      ),
    );
  }

  String? _inviteLink() {
    final code = '${conversation?['invite_code'] ?? ''}'.trim();
    if (code.isEmpty) return null;
    return 'https://bkbdcqequyvubjmrbpqo.supabase.co/functions/v1/conversation-invite?code=${Uri.encodeComponent(code)}';
  }

  Future<void> showInvite() async {
    final link = _inviteLink();
    if (link == null) { showMsg(context, 'لینک دعوت هنوز آماده نیست.'); return; }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(18, 6, 18, 24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(conversation?['type'] == 'channel' ? 'لینک دعوت کانال' : 'لینک دعوت گروه', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        SelectableText(link, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: link)); Navigator.pop(sheet); showMsg(context, 'لینک دعوت کپی شد.'); }, icon: const Icon(Icons.copy), label: const Text('کپی لینک'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: link)); Navigator.pop(sheet); showMsg(context, 'لینک آماده ارسال است.'); }, icon: const Icon(Icons.share_outlined), label: const Text('اشتراک‌گذاری'))),
        ]),
      ])),
    );
  }

  Future<void> showAppearance() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(builder: (context, setSheet) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(18, 6, 18, 24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('ظاهر و پس‌زمینه چت', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        const Align(alignment: Alignment.centerRight, child: Text('پس‌زمینه', style: TextStyle(fontWeight: FontWeight.w800))),
        const SizedBox(height: 8),
        Wrap(spacing: 10, children: List.generate(wallpapers.length, (i) => GestureDetector(onTap: () => setSheet(() { wallpaperIndex = i; }), child: Container(width: 46, height: 46, decoration: BoxDecoration(color: wallpapers[i], shape: BoxShape.circle, border: Border.all(color: wallpaperIndex == i ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3))))),
        const SizedBox(height: 18),
        const Align(alignment: Alignment.centerRight, child: Text('رنگ پیام‌های شما', style: TextStyle(fontWeight: FontWeight.w800))),
        const SizedBox(height: 8),
        Wrap(spacing: 10, children: List.generate(mineColors.length, (i) => GestureDetector(onTap: () => setSheet(() { bubbleIndex = i; }), child: Container(width: 46, height: 46, decoration: BoxDecoration(color: mineColors[i], borderRadius: BorderRadius.circular(14), border: Border.all(color: bubbleIndex == i ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3))))),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () { saveAppearance(); setState(() {}); Navigator.pop(sheet); }, child: const Text('ذخیره قالب چت'))),
      ]))),
    );
  }

  @override
  void initState() {
    super.initState();
    loadAppearance();
    load();
    channel = supabase.channel('chat-${widget.id}')
      .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'messages', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: widget.id), callback: (_) => load())
      .subscribe();
  }

  @override
  void dispose() {
    if (channel != null) supabase.removeChannel(channel!);
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = '${conversation?['type'] ?? ''}';
    final isCommunity = type == 'group' || type == 'channel';
    return Scaffold(
      backgroundColor: wallpapers[wallpaperIndex.clamp(0, wallpapers.length - 1)],
      appBar: AppBar(
        title: Row(children: [const CircleAvatar(radius: 17, child: Icon(Icons.forum_rounded, size: 18)), const SizedBox(width: 9), Expanded(child: Text(widget.title, overflow: TextOverflow.ellipsis))]),
        actions: [
          if (isCommunity) IconButton(tooltip: 'لینک دعوت', onPressed: showInvite, icon: const Icon(Icons.link_rounded)),
          if (isCommunity && type == 'group') IconButton(tooltip: 'مدیریت گروه', icon: const Icon(Icons.groups_2_rounded), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupManagementPage(conversationId: widget.id, title: widget.title)))),
          IconButton(tooltip: 'ظاهر چت', onPressed: showAppearance, icon: const Icon(Icons.palette_outlined)),
        ],
      ),
      body: Column(children: [
        if (isCommunity) Container(width: double.infinity, margin: const EdgeInsets.fromLTRB(12, 8, 12, 0), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withValues(alpha: .78), borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(type == 'channel' ? Icons.campaign_rounded : Icons.groups_rounded, size: 19), const SizedBox(width: 8), Expanded(child: Text(type == 'channel' ? 'کانال • لینک دعوت اختصاصی فعال است' : 'گروه • لینک دعوت اختصاصی فعال است', style: const TextStyle(fontWeight: FontWeight.w700))), IconButton(onPressed: showInvite, icon: const Icon(Icons.copy_rounded), tooltip: 'کپی لینک')])) ,
        Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : messages.isEmpty ? const Center(child: Text('هنوز پیامی وجود ندارد.')) : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), itemCount: messages.length, itemBuilder: (context, i) => _messageBubble(messages[i]))),
        if (replyMessage != null) Container(width: double.infinity, margin: const EdgeInsets.fromLTRB(12, 0, 12, 4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(14)), child: Row(children: [const Icon(Icons.reply_rounded), const SizedBox(width: 8), Expanded(child: Text('${_senderName(replyMessage!)}: ${replyMessage!['body'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis)), IconButton(onPressed: () => setState(() => replyMessage = null), icon: const Icon(Icons.close))])),
        SafeArea(child: Row(children: [IconButton(onPressed: sendImage, icon: const Icon(Icons.image_outlined)), IconButton(onPressed: sendFile, icon: const Icon(Icons.attach_file_rounded)), Expanded(child: TextField(controller: text, textDirection: TextDirection.rtl, minLines: 1, maxLines: 5, decoration: const InputDecoration(hintText: 'پیام...', border: OutlineInputBorder()))), IconButton(onPressed: sending ? null : sendText, icon: const Icon(Icons.send_rounded))])),
      ]),
    );
  }
}
'''

s = s[:start] + new_chat + '\n' + s[end:]
if "import 'group_management.dart';" not in s:
    s = s.replace("import 'invite.dart';", "import 'invite.dart';\nimport 'group_management.dart';", 1)
p.write_text(s, encoding='utf-8')
