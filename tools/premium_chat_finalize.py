from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')
start = s.index('class _ChatPageState extends State<ChatPage> {')
end = s.index('class ProfilePage extends StatefulWidget {', start)
chat = s[start:end]

fields = """  Map<String, Map<String, dynamic>> senderStats = {};
  Map<String, dynamic>? conversation;
  int wallpaperIndex = 0;
  int bubbleIndex = 0;
  static const wallpapers = <Color>[Color(0xFFF5F7FB), Color(0xFFEAF4FF), Color(0xFFF5EEFF), Color(0xFFFFF5E8), Color(0xFFEAF9F1), Color(0xFFFFEEF2)];
  static const mineColors = <Color>[Color(0xFFDCE7FF), Color(0xFFDDF7EA), Color(0xFFFFE6F0), Color(0xFFFFEFD2), Color(0xFFEAE0FF), Color(0xFFDFF7F8)];
"""
if 'Map<String, Map<String, dynamic>> senderStats' not in chat:
    chat = chat.replace('class _ChatPageState extends State<ChatPage> {\n', 'class _ChatPageState extends State<ChatPage> {\n' + fields, 1)

if "get_chat_sender_stats" not in chat:
    chat = chat.replace("    try {\n      final rows = await supabase.from('messages').select().eq('conversation_id', widget.id).order('created_at');", "    try {\n      final c = await supabase.from('conversations').select('id,type,title,invite_code,allow_reactions,allow_member_add,created_by').eq('id', widget.id).maybeSingle();\n      final rows = await supabase.from('messages').select().eq('conversation_id', widget.id).order('created_at');", 1)
    old = """        profiles = {for (final p in List<Map<String, dynamic>>.from(people)) '${p['id']}': p};
      }
"""
    new = """        profiles = {for (final p in List<Map<String, dynamic>>.from(people)) '${p['id']}': p};
        try {
          final stats = await supabase.rpc('get_chat_sender_stats', params: {'p_conversation_id': widget.id, 'p_user_ids': senderIds});
          senderStats = {for (final x in List<Map<String, dynamic>>.from(stats)) '${x['user_id']}': x};
        } catch (_) {
          senderStats = {};
        }
      }
"""
    chat = chat.replace(old, new, 1)
    chat = chat.replace("          messages = loaded;\n          reactions = loadedReactions;", "          conversation = c;\n          messages = loaded;\n          reactions = loadedReactions;", 1)

helpers = r'''  Future<void> loadAppearance() async {
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

  String _rankLabel(Map<String, dynamic>? stats) => stats == null ? '🌱 تازه‌وارد' : '${stats['rank_icon'] ?? '🌱'} ${stats['rank_name'] ?? 'تازه‌وارد'}';

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
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: link)); Navigator.pop(sheet); showMsg(context, 'لینک دعوت کپی شد.'); }, icon: const Icon(Icons.copy_rounded), label: const Text('کپی لینک دعوت'))),
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
          Wrap(spacing: 10, children: List.generate(wallpapers.length, (i) => GestureDetector(onTap: () => setSheet(() => wallpaperIndex = i), child: Container(width: 44, height: 44, decoration: BoxDecoration(color: wallpapers[i], shape: BoxShape.circle, border: Border.all(color: wallpaperIndex == i ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3))))),
          const SizedBox(height: 16),
          const Align(alignment: Alignment.centerRight, child: Text('رنگ پیام‌های شما', style: TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(height: 8),
          Wrap(spacing: 10, children: List.generate(mineColors.length, (i) => GestureDetector(onTap: () => setSheet(() => bubbleIndex = i), child: Container(width: 44, height: 44, decoration: BoxDecoration(color: mineColors[i], borderRadius: BorderRadius.circular(13), border: Border.all(color: bubbleIndex == i ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 3))))),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () async { await saveAppearance(); if (mounted) { setState(() {}); Navigator.pop(sheet); } }, child: const Text('ذخیره قالب چت'))),
        ]),
      ))),
    );
  }

'''
if 'Future<void> showAppearance()' not in chat:
    chat = chat.replace('  @override\n  void initState()', helpers + '  @override\n  void initState()', 1)

if 'loadAppearance();' not in chat:
    chat = chat.replace('  void initState() {\n    super.initState();\n    load();', '  void initState() {\n    super.initState();\n    loadAppearance();\n    load();', 1)

if "tooltip: 'ظاهر چت'" not in chat:
    controls = """          if ('${conversation?['type'] ?? ''}' == 'group' || '${conversation?['type'] ?? ''}' == 'channel') IconButton(tooltip: 'لینک دعوت', onPressed: showInvite, icon: const Icon(Icons.link_rounded)),
          if ('${conversation?['type'] ?? ''}' == 'group') IconButton(tooltip: 'مدیریت گروه', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupManagementPage(conversationId: widget.id, title: widget.title))), icon: const Icon(Icons.groups_2_rounded)),
          IconButton(tooltip: 'ظاهر چت', onPressed: showAppearance, icon: const Icon(Icons.palette_outlined)),
"""
    if '        actions: [' in chat:
        chat = chat.replace('        actions: [', '        actions: [\n' + controls, 1)

if 'backgroundColor: wallpapers[' not in chat:
    chat = chat.replace('    return Scaffold(\n', '    return Scaffold(\n      backgroundColor: wallpapers[wallpaperIndex.clamp(0, wallpapers.length - 1)],\n', 1)

s = s[:start] + chat + s[end:]
p.write_text(s, encoding='utf-8')
