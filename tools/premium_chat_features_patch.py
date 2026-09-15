from pathlib import Path
p=Path('lib/main.dart')
s=p.read_text()
if "import 'group_management.dart';" not in s:
    s=s.replace("import 'invite.dart';", "import 'invite.dart';\nimport 'group_management.dart';",1)
start=s.index('class _ChatPageState extends State<ChatPage> {')
end=s.index('class ProfilePage extends StatefulWidget {', start)
chat=s[start:end]
needle="  Map<String, dynamic>? replyMessage;\n"
insert="""  Map<String, dynamic>? replyMessage;
  Map<String, dynamic>? conversation;
  int wallpaperIndex = 0;
  int bubbleIndex = 0;
  static const wallpapers = <Color>[Color(0xFFF5F7FB), Color(0xFFEAF4FF), Color(0xFFF5EEFF), Color(0xFFFFF5E8), Color(0xFFEAF9F1), Color(0xFFFFEEF2)];
  static const mineColors = <Color>[Color(0xFFDCE7FF), Color(0xFFDDF7EA), Color(0xFFFFE6F0), Color(0xFFFFEFD2), Color(0xFFEAE0FF), Color(0xFFDFF7F8)];
"""
if needle in chat and 'static const wallpapers' not in chat:
    chat=chat.replace(needle,insert,1)
old="""  Future<void> load() async {
    try {
      final rows = await supabase.from('messages').select().eq('conversation_id', widget.id).order('created_at');
"""
new="""  Future<void> load() async {
    try {
      final c = await supabase.from('conversations').select('id,type,title,invite_code,allow_reactions,allow_member_add,created_by').eq('id', widget.id).maybeSingle();
      final rows = await supabase.from('messages').select().eq('conversation_id', widget.id).order('created_at');
"""
chat=chat.replace(old,new,1)
chat=chat.replace("          messages = loaded;\n          reactions = loadedReactions;", "          conversation = c;\n          messages = loaded;\n          reactions = loadedReactions;",1)
marker="  @override\n  void initState() {"
methods=r'''  Future<void> loadAppearance() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_style_${widget.id}';
    if (!mounted) return;
    setState(() {
      wallpaperIndex = prefs.getInt('${key}_wallpaper') ?? 0;
      bubbleIndex = prefs.getInt('${key}_bubble') ?? 0;
    });
  }

  Future<void> saveAppearance() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_style_${widget.id}';
    await prefs.setInt('${key}_wallpaper', wallpaperIndex);
    await prefs.setInt('${key}_bubble', bubbleIndex);
  }

  String _rankLabel(Map<String, dynamic>? stats) => stats == null
      ? '🌱 تازه‌وارد'
      : '${stats['rank_icon'] ?? '🌱'} ${stats['rank_name'] ?? 'تازه‌وارد'}';

  String _senderIdLabel(Map<String, dynamic> m) {
    final p = profiles['${m['sender_id']}'];
    final username = '${p?['username'] ?? ''}'.trim();
    if (username.isNotEmpty) return '@$username';
    final id = '${m['sender_id'] ?? ''}';
    return id.length > 8 ? 'ID: ${id.substring(0, 8)}…' : 'ID: $id';
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
      builder: (sheet) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(conversation?['type'] == 'channel' ? 'لینک دعوت کانال' : 'لینک دعوت گروه', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          SelectableText(link, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: () { Clipboard.setData(ClipboardData(text: link)); Navigator.pop(sheet); showMsg(context, 'لینک دعوت کپی شد.'); },
            icon: const Icon(Icons.copy_rounded), label: const Text('کپی لینک دعوت'),
          )),
        ]),
      )),
    );
  }

  Future<void> showAppearance() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(builder: (context, setSheet) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('ظاهر و پس‌زمینه چت', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          const Align(alignment: Alignment.centerRight, child: Text('پس‌زمینه', style: TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(height: 8),
          Wrap(spacing: 10, children: List.generate(wallpapers.length, (i) => GestureDetector(
            onTap: () => setSheet(() => wallpaperIndex = i),
            child: Container(width: 44, height: 44, decoration: BoxDecoration(color: wallpapers[i], shape: BoxShape.circle, border: Border.all(color: wallpaperIndex == i ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3))),
          ))),
          const SizedBox(height: 16),
          const Align(alignment: Alignment.centerRight, child: Text('رنگ پیام‌های شما', style: TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(height: 8),
          Wrap(spacing: 10, children: List.generate(mineColors.length, (i) => GestureDetector(
            onTap: () => setSheet(() => bubbleIndex = i),
            child: Container(width: 44, height: 44, decoration: BoxDecoration(color: mineColors[i], borderRadius: BorderRadius.circular(13), border: Border.all(color: bubbleIndex == i ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3))),
          ))),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () async { await saveAppearance(); if (mounted) { setState(() {}); Navigator.pop(sheet); } }, child: const Text('ذخیره قالب چت'))),
        ]),
      ))),
    );
  }

'''
if marker in chat and 'Future<void> showAppearance()' not in chat:
    chat=chat.replace(marker,methods+marker,1)
mb_start=chat.index('  Widget _messageBubble(Map<String, dynamic> m) {')
mb_end=chat.index('  @override\n  void initState()',mb_start)
new_bubble=r'''  Widget _messageBubble(Map<String, dynamic> m) {
    final mine = m['sender_id'] == supabase.auth.currentUser!.id;
    final p = profiles['${m['sender_id']}'];
    final stats = senderStats['${m['sender_id']}'];
    final url = '${p?['avatar_url'] ?? ''}';
    final name = '${p?['display_name'] ?? p?['username'] ?? (mine ? 'شما' : 'کاربر')}';
    final userId = _senderIdLabel(m);
    final rank = _rankLabel(stats);
    final bubbleColor = mine ? mineColors[bubbleIndex.clamp(0, mineColors.length - 1)] : Theme.of(context).colorScheme.surface;
    final avatarWidget = CircleAvatar(radius: 19, backgroundImage: url.isNotEmpty ? NetworkImage(url) : null, child: url.isEmpty ? const Icon(Icons.person, size: 20) : null);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => showMessageActions(m),
        onHorizontalDragEnd: (details) { if ((details.primaryVelocity ?? 0).abs() > 450) setReply(m); },
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .88),
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (!mine) ...[avatarWidget, const SizedBox(width: 7)],
            Flexible(child: Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: bubbleColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .45))),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 10, 7),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(radius: 14, backgroundImage: url.isNotEmpty ? NetworkImage(url) : null, child: url.isEmpty ? const Icon(Icons.person, size: 15) : null),
                    const SizedBox(width: 6),
                    Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
                      Text('$userId  •  $rank', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ])),
                  ]),
                  const SizedBox(height: 5),
                  _replyPreview(m),
                  if (m['message_type'] == 'image') const Padding(padding: EdgeInsets.only(bottom: 5), child: Icon(Icons.image_rounded, size: 42)),
                  if ('${m['body'] ?? ''}'.isNotEmpty) Text('${m['body'] ?? ''}', style: const TextStyle(fontSize: 15.5, height: 1.42)),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${_dateLabel(m['created_at'])}  ${_time(m['created_at'])}', style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    if (mine) ...[const SizedBox(width: 4), Icon(m['read_at'] != null ? Icons.done_all_rounded : Icons.done_rounded, size: 15, color: m['read_at'] != null ? Colors.blue : null)],
                  ]),
                  _reactionRow(m),
                ]),
              ),
            )),
            if (mine) ...[const SizedBox(width: 7), avatarWidget],
          ]),
        ),
      ),
    );
  }

'''
chat=chat[:mb_start]+new_bubble+chat[mb_end:]
old_app="""      appBar: AppBar(
        title: Row(children: [const CircleAvatar(radius: 17, child: Icon(Icons.person, size: 18)), const SizedBox(width: 9), Expanded(child: Text(widget.title, overflow: TextOverflow.ellipsis))]),
      ),"""
new_app="""      appBar: AppBar(
        title: Row(children: [const CircleAvatar(radius: 17, child: Icon(Icons.person, size: 18)), const SizedBox(width: 9), Expanded(child: Text(widget.title, overflow: TextOverflow.ellipsis))]),
        actions: [
          if ('${conversation?['type'] ?? ''}' == 'group' || '${conversation?['type'] ?? ''}' == 'channel') IconButton(tooltip: 'لینک دعوت', onPressed: showInvite, icon: const Icon(Icons.link_rounded)),
          if ('${conversation?['type'] ?? ''}' == 'group') IconButton(tooltip: 'مدیریت گروه', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupManagementPage(conversationId: widget.id, title: widget.title))), icon: const Icon(Icons.groups_2_rounded)),
          IconButton(tooltip: 'ظاهر چت', onPressed: showAppearance, icon: const Icon(Icons.palette_outlined)),
        ],
      ),"""
if old_app in chat:
    chat=chat.replace(old_app,new_app,1)
chat=chat.replace("    return Scaffold(\n      appBar:", "    return Scaffold(\n      backgroundColor: wallpapers[wallpaperIndex.clamp(0, wallpapers.length - 1)],\n      appBar:",1)
chat=chat.replace("  void initState() {\n    super.initState();\n    load();", "  void initState() {\n    super.initState();\n    loadAppearance();\n    load();",1)
s=s[:start]+chat+s[end:]
p.write_text(s)
