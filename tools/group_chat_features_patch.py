from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# Import group management exactly once.
if "import 'group_management.dart';" not in s:
    marker = "import 'invite.dart';"
    if marker not in s:
        raise SystemExit('invite import not found')
    s = s.replace(marker, marker + "\nimport 'group_management.dart';", 1)

# Incoming messages use a distinct neutral surface instead of the sender's own color.
s = s.replace(
    "color: mine ? Theme.of(context).colorScheme.primaryContainer : Colors.white,",
    "color: mine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,",
    1,
)

# Use the server-side reaction permission check.
old = """      if (current.isNotEmpty && current.first['reaction'] == emoji) {\n        await supabase.from('message_reactions').delete().match({'message_id': message['id'], 'user_id': uid});\n      } else {\n        await supabase.from('message_reactions').upsert({'message_id': message['id'], 'user_id': uid, 'reaction': emoji});\n      }"""
new = """      await supabase.rpc('set_message_reaction', params: {'p_message_id': message['id'], 'p_reaction': emoji});"""
if old in s:
    s = s.replace(old, new, 1)

# Add group management to the chat header. The page itself verifies that this is a group.
old_appbar = """appBar: AppBar(\n        title: Row(children: [const CircleAvatar(radius: 17, child: Icon(Icons.person, size: 18)), const SizedBox(width: 9), Expanded(child: Text(widget.title, overflow: TextOverflow.ellipsis))]),\n      ),"""
new_appbar = """appBar: AppBar(\n        title: Row(children: [const CircleAvatar(radius: 17, child: Icon(Icons.person, size: 18)), const SizedBox(width: 9), Expanded(child: Text(widget.title, overflow: TextOverflow.ellipsis))]),\n        actions: [\n          IconButton(\n            tooltip: 'مدیریت گروه',\n            icon: const Icon(Icons.groups_2_rounded),\n            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupManagementPage(conversationId: widget.id, title: widget.title))),\n          ),\n        ],\n      ),"""
if old_appbar in s:
    s = s.replace(old_appbar, new_appbar, 1)

p.write_text(s, encoding='utf-8')
