from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

if "import 'notifications_page.dart';" not in s:
    s = s.replace("import 'invite.dart';", "import 'invite.dart';\nimport 'notifications_page.dart';", 1)

# Replace HomePage with an unread-aware version while preserving the existing creation methods.
hstart = s.index('class HomePage extends StatefulWidget {')
hend = s.index('class UserSearchDelegate extends SearchDelegate', hstart)
home = s[hstart:hend]

home = home.replace("  int selectedFilter = 0;", "  int selectedFilter = 0;\n  Map<String, int> unreadCounts = {};\n  Timer? unreadTimer;", 1)

load_marker = "  Future<void> createDirect() async {"
if 'Future<void> loadUnreadCounts() async {' not in home:
    method = r'''  Future<void> loadUnreadCounts() async {
    try {
      final raw = await supabase.rpc('get_unread_counts');
      final next = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(raw as List)) {
        next['${row['conversation_id']}'] = (row['unread_count'] as num?)?.toInt() ?? 0;
      }
      if (mounted) setState(() => unreadCounts = next);
    } catch (_) {}
  }

'''
    home = home.replace(load_marker, method + load_marker, 1)

home = home.replace("  @override\n  void initState() { super.initState(); load(); }", "  @override\n  void initState() {\n    super.initState();\n    load();\n    loadUnreadCounts();\n    unreadTimer = Timer.periodic(const Duration(seconds: 8), (_) => loadUnreadCounts());\n  }\n\n  @override\n  void dispose() {\n    unreadTimer?.cancel();\n    super.dispose();\n  }", 1)

# Add notification bell with total unread badge.
old_actions = """          IconButton(onPressed: createDirect, icon: const Icon(Icons.person_add)),"""
new_actions = """          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'اعلان‌ها',
                onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())); await loadUnreadCounts(); },
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              if (unreadCounts.values.fold<int>(0, (a, b) => a + b) > 0)
                Positioned(right: 4, top: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), constraints: const BoxConstraints(minWidth: 18), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)), child: Text('${unreadCounts.values.fold<int>(0, (a, b) => a + b)}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)))),
            ],
          ),
          IconButton(onPressed: createDirect, icon: const Icon(Icons.person_add)),"""
if old_actions in home:
    home = home.replace(old_actions, new_actions, 1)

old_tile = """                  return ListTile(leading: const CircleAvatar(child: Icon(Icons.chat)), title: Text(title), subtitle: Text('${c['last_message'] ?? ''}'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(id: '${c['id']}', title: title))));"""
new_tile = r'''                  final unread = unreadCounts['${c['id']}'] ?? 0;
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.chat)),
                    title: Row(children: [Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)), if (unread > 0) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), constraints: const BoxConstraints(minWidth: 22), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(14)), child: Text('$unread', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)))]),
                    subtitle: Text('${c['last_message'] ?? ''}'),
                    onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(id: '${c['id']}', title: title))); await loadUnreadCounts(); },
                  );'''
if old_tile in home:
    home = home.replace(old_tile, new_tile, 1)

s = s[:hstart] + home + s[hend:]

# Upgrade chat read tracking to per-user message_reads and keep messages.read_at for direct-chat compatibility.
cstart = s.index('class _ChatPageState extends State<ChatPage> {')
cend = s.index('class ProfilePage extends StatefulWidget {', cstart)
chat = s[cstart:cend]
old_mark = re.compile(r"  Future<void> markRead\(\) async \{.*?\n  \}", re.S)
new_mark = r'''  Future<void> markRead() async {
    try {
      await supabase.rpc('mark_conversation_read', params: {'p_conversation_id': widget.id});
    } catch (_) {}
  }'''
chat, n = old_mark.subn(new_mark, chat, count=1)

# Add a message-statistics button to the chat app bar. Handle both the original and enhanced app bars.
if 'ConversationStatsPage' not in chat:
    simple = """      appBar: AppBar(title: Text(widget.title)),"""
    simple_new = """      appBar: AppBar(
        title: Text(widget.title),
        actions: [IconButton(tooltip: 'آمار پیام‌ها', icon: const Icon(Icons.bar_chart_rounded), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationStatsPage(conversationId: widget.id, title: widget.title))))],
      ),"""
    if simple in chat:
        chat = chat.replace(simple, simple_new, 1)
    else:
        # voice_profile_media_fix gives the chat app bar a custom block; append one action before its closing action list.
        needle = "        actions: ["
        if needle in chat:
            chat = chat.replace(needle, needle + "\n          IconButton(tooltip: 'آمار پیام‌ها', icon: const Icon(Icons.bar_chart_rounded), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationStatsPage(conversationId: widget.id, title: widget.title)))),", 1)

# Mark incoming messages as read when the chat is loaded.
s = s[:cstart] + chat + s[cend:]
p.write_text(s, encoding='utf-8')
