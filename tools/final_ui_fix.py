from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# Home filter chips: transparent/clean four filters.
s = s.replace(
    "return Padding(padding: const EdgeInsets.only(left: 6), child: ChoiceChip(\n              selected: selectedFilter == i,",
    "return Padding(padding: const EdgeInsets.only(left: 6), child: ChoiceChip(\n              backgroundColor: Colors.transparent,\n              selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),\n              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45)),\n              selected: selectedFilter == i,",
    1,
)

start = s.index('class _ChatPageState extends State<ChatPage> {')
end = s.index('class ProfilePage extends StatefulWidget {', start)
chat = s[start:end]

# State for the person/group shown in the chat header.
if 'Map<String, dynamic>? chatPeer;' not in chat:
    chat = chat.replace(
        '  Map<String, dynamic>? replyMessage;\n',
        '  Map<String, dynamic>? replyMessage;\n  Map<String, dynamic>? chatPeer;\n',
        1,
    )

# Telegram-style ordering: newest records first in data + reverse ListView => newest at bottom.
chat = chat.replace(
    ".order('created_at');",
    ".order('created_at', ascending: false);",
    1,
)

# Load the other participant's full profile for the chat header.
anchor = """      final rows = await supabase.from('messages').select().eq('conversation_id', widget.id).order('created_at', ascending: false);\n      final loaded = List<Map<String, dynamic>>.from(rows);\n"""
insert = """      final rows = await supabase.from('messages').select().eq('conversation_id', widget.id).order('created_at', ascending: false);\n      final loaded = List<Map<String, dynamic>>.from(rows);\n      chatPeer = null;\n      if ('${c?['type'] ?? ''}' == 'direct') {\n        try {\n          final me = supabase.auth.currentUser!.id;\n          final memberRows = await supabase.from('conversation_members').select('user_id').eq('conversation_id', widget.id);\n          final peerIds = List<Map<String, dynamic>>.from(memberRows)\n              .map((x) => '${x['user_id']}')\n              .where((id) => id != me)\n              .toList();\n          if (peerIds.isNotEmpty) {\n            final peerRows = await supabase.from('profiles')\n                .select('id,display_name,username,avatar_url,bio,is_verified')\n                .eq('id', peerIds.first)\n                .limit(1);\n            if (peerRows.isNotEmpty) chatPeer = Map<String, dynamic>.from(peerRows.first);\n          }\n        } catch (_) {}\n      }\n"""
if anchor in chat and "chatPeer = null;" not in chat:
    chat = chat.replace(anchor, insert, 1)

# Reverse the actual ListView without changing message alignment.
chat = chat.replace(
    ": ListView.builder(padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), itemCount:",
    ": ListView.builder(reverse: true, padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), itemCount:",
    1,
)

# Replace the simple title with a compact profile header containing avatar, name, ID and bio.
old_app = """      appBar: AppBar(\n        title: Row(children: [const CircleAvatar(radius: 17, child: Icon(Icons.person, size: 18)), const SizedBox(width: 9), Expanded(child: Text(widget.title, overflow: TextOverflow.ellipsis))]),\n"""
new_app = """      appBar: AppBar(\n        titleSpacing: 0,\n        title: InkWell(\n          borderRadius: BorderRadius.circular(14),\n          onTap: () {\n            final p = chatPeer;\n            if (p == null) return;\n            showModalBottomSheet<void>(\n              context: context,\n              showDragHandle: true,\n              builder: (sheet) => SafeArea(child: Padding(\n                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),\n                child: Column(mainAxisSize: MainAxisSize.min, children: [\n                  CircleAvatar(radius: 42, backgroundImage: '${p['avatar_url'] ?? ''}'.isNotEmpty ? NetworkImage('${p['avatar_url']}') : null, child: '${p['avatar_url'] ?? ''}'.isEmpty ? const Icon(Icons.person, size: 42) : null),\n                  const SizedBox(height: 12),\n                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [\n                    Flexible(child: Text('${p['display_name'] ?? p['username'] ?? 'کاربر'}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis)),\n                    if (p['is_verified'] == true) const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.verified_rounded, color: Colors.blue, size: 21)),\n                  ]),\n                  const SizedBox(height: 4),\n                  Text('@${p['username'] ?? ''}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),\n                  const SizedBox(height: 8),\n                  Text('${p['bio'] ?? 'شرحی ثبت نشده است.'}', textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),\n                  const SizedBox(height: 8),\n                  Text('ID: ${p['id'] ?? ''}', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),\n                ]),\n              )),\n            );\n          },\n          child: Row(children: [\n            CircleAvatar(radius: 18, backgroundImage: '${chatPeer?['avatar_url'] ?? ''}'.isNotEmpty ? NetworkImage('${chatPeer?['avatar_url']}') : null, child: '${chatPeer?['avatar_url'] ?? ''}'.isEmpty ? const Icon(Icons.person, size: 19) : null),\n            const SizedBox(width: 8),\n            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [\n              Row(children: [\n                Flexible(child: Text('${chatPeer?['display_name'] ?? widget.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),\n                if (chatPeer?['is_verified'] == true) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, color: Colors.blue, size: 16)),\n              ]),\n              Text(chatPeer != null ? '@${chatPeer?['username'] ?? ''}  •  ${'${chatPeer?['bio'] ?? ''}'.trim().isEmpty ? 'بدون شرح' : chatPeer?['bio']}' : '${conversation?['type'] == 'group' ? 'گروه' : conversation?['type'] == 'channel' ? 'کانال' : 'در حال اتصال'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),\n            ])),\n          ]),\n        ),\n"""
if old_app in chat:
    chat = chat.replace(old_app, new_app, 1)

s = s[:start] + chat + s[end:]
p.write_text(s, encoding='utf-8')
