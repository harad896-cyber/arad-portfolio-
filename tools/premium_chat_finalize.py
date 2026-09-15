from pathlib import Path
p=Path('lib/main.dart')
s=p.read_text(encoding='utf-8')
start=s.index('class _ChatPageState extends State<ChatPage> {')
end=s.index('class ProfilePage extends StatefulWidget {',start)
chat=s[start:end]
if 'Map<String, Map<String, dynamic>> senderStats' not in chat:
    chat=chat.replace('class _ChatPageState extends State<ChatPage> {\n','class _ChatPageState extends State<ChatPage> {\n  Map<String, Map<String, dynamic>> senderStats = {};\n',1)
if "get_chat_sender_stats" not in chat:
    old="""        profiles = {for (final p in List<Map<String, dynamic>>.from(people)) '${p['id']}': p};
      }
"""
    new="""        profiles = {for (final p in List<Map<String, dynamic>>.from(people)) '${p['id']}': p};
        try {
          final stats = await supabase.rpc('get_chat_sender_stats', params: {'p_conversation_id': widget.id, 'p_user_ids': senderIds});
          senderStats = {for (final x in List<Map<String, dynamic>>.from(stats)) '${x['user_id']}': x};
        } catch (_) {
          senderStats = {};
        }
      }
"""
    chat=chat.replace(old,new,1)
helper=r'''  String _rankLabel(Map<String, dynamic>? stats) => stats == null ? '🌱 تازه‌وارد' : '${stats['rank_icon'] ?? '🌱'} ${stats['rank_name'] ?? 'تازه‌وارد'}';

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
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Text(conversation?['type'] == 'channel' ? 'لینک دعوت کانال' : 'لینک دعوت گروه', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            SelectableText(link, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: link)); Navigator.pop(sheet); showMsg(context, 'لینک دعوت کپی شد.'); }, icon: const Icon(Icons.copy_rounded), label: const Text('کپی لینک دعوت'))),
          ]),
        ),
      ),
    );
  }

  Future<void> showAppearance() async {
    int nextWallpaper = wallpaperIndex;
    int nextBubble = bubbleIndex;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => StatefulBuilder(
        builder: (sheetContext, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              const Text('ظاهر و پس‌زمینه چت', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              const Align(alignment: Alignment.centerRight, child: Text('پس‌زمینه', style: TextStyle(fontWeight: FontWeight.w800))),
              const SizedBox(height: 8),
              Row(children: List<Widget>.generate(wallpapers.length, (i) => Expanded(child: InkWell(onTap: () => setSheet(() => nextWallpaper = i), child: Container(height: 38, margin: const EdgeInsets.all(3), decoration: BoxDecoration(color: wallpapers[i], borderRadius: BorderRadius.circular(10), border: Border.all(color: nextWallpaper == i ? Theme.of(sheetContext).colorScheme.primary : Colors.transparent, width: 2))))))),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerRight, child: Text('رنگ پیام‌های شما', style: TextStyle(fontWeight: FontWeight.w800))),
              const SizedBox(height: 8),
              Row(children: List<Widget>.generate(mineColors.length, (i) => Expanded(child: InkWell(onTap: () => setSheet(() => nextBubble = i), child: Container(height: 38, margin: const EdgeInsets.all(3), decoration: BoxDecoration(color: mineColors[i], borderRadius: BorderRadius.circular(10), border: Border.all(color: nextBubble == i ? Theme.of(sheetContext).colorScheme.primary : Colors.transparent, width: 2))))))),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () async { wallpaperIndex = nextWallpaper; bubbleIndex = nextBubble; final prefs = await SharedPreferences.getInstance(); final key = 'chat_style_${widget.id}'; await prefs.setInt('${key}_wallpaper', wallpaperIndex); await prefs.setInt('${key}_bubble', bubbleIndex); if (mounted) { setState(() {}); Navigator.pop(sheet); } }, child: const Text('ذخیره قالب چت'))),
            ]),
          ),
        ),
      ),
    );
  }

'''
if 'String _senderIdLabel' not in chat:
    chat=chat.replace('  @override\n  void initState()',helper+'  @override\n  void initState()',1)
if 'loadAppearance();' not in chat and 'Future<void> loadAppearance()' in chat:
    chat=chat.replace('  void initState() {\n    super.initState();\n    load();','  void initState() {\n    super.initState();\n    loadAppearance();\n    load();',1)
if "tooltip: 'ظاهر چت'" not in chat:
    controls="""          if ('${conversation?['type'] ?? ''}' == 'group' || '${conversation?['type'] ?? ''}' == 'channel') IconButton(tooltip: 'لینک دعوت', onPressed: showInvite, icon: const Icon(Icons.link_rounded)),
          if ('${conversation?['type'] ?? ''}' == 'group') IconButton(tooltip: 'مدیریت گروه', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupManagementPage(conversationId: widget.id, title: widget.title))), icon: const Icon(Icons.groups_2_rounded)),
          IconButton(tooltip: 'ظاهر چت', onPressed: showAppearance, icon: const Icon(Icons.palette_outlined)),
"""
    if '        actions: [' in chat:
        chat=chat.replace('        actions: [','        actions: [\n'+controls,1)
if 'backgroundColor: wallpapers[' not in chat:
    chat=chat.replace('    return Scaffold(\n','    return Scaffold(\n      backgroundColor: wallpapers[wallpaperIndex.clamp(0, wallpapers.length - 1)],\n',1)
s=s[:start]+chat+s[end:]
p.write_text(s,encoding='utf-8')
