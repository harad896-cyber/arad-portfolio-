from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

if "import 'group_management.dart';" not in s:
    marker = "import 'invite.dart';"
    if marker not in s:
        raise SystemExit('invite import not found')
    s = s.replace(marker, marker + "\nimport 'group_management.dart';", 1)

s = s.replace(
    "color: mine ? Theme.of(context).colorScheme.primaryContainer : Colors.white,",
    "color: mine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,",
    1,
)

s = s.replace("    final uid = supabase.auth.currentUser!.id;\n    try {\n      final current = (reactions['${message['id']}'] ?? const <Map<String, dynamic>>[]).where((r) => r['user_id'] == uid).toList();\n", "    try {\n", 1)

old = """      if (current.isNotEmpty && current.first['reaction'] == emoji) {\n        await supabase.from('message_reactions').delete().match({'message_id': message['id'], 'user_id': uid});\n      } else {\n        await supabase.from('message_reactions').upsert({'message_id': message['id'], 'user_id': uid, 'reaction': emoji});\n      }"""
new = """      await supabase.rpc('set_message_reaction', params: {'p_message_id': message['id'], 'p_reaction': emoji});"""
if old in s:
    s = s.replace(old, new, 1)

# Make the reaction picker clearer and closer to a modern Telegram-style quick reaction bar.
old_reaction_picker = """    const emojis = ['❤️', '👍', '😂', '😮', '😢', '🔥'];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: emojis.map((e) => InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    reactTo(message, e);
                  },
                  child: Padding(padding: const EdgeInsets.all(9), child: Text(e, style: const TextStyle(fontSize: 27))),
                )).toList(),
              ),"""
new_reaction_picker = """    const emojis = ['👍', '❤️', '😂', '😮', '😢', '😡', '👎', '🥰', '🤩', '🔥', '🎉', '💯', '🤔', '🤗', '👏', '🙏', '😍', '😎', '🤣', '💔'];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(alignment: Alignment.centerRight, child: Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Text('واکنش به پیام', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)))),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 2,
                  runSpacing: 2,
                  children: emojis.map((e) => InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      reactTo(message, e);
                    },
                    child: SizedBox(width: 45, height: 45, child: Center(child: Text(e, style: const TextStyle(fontSize: 28)))),
                  )).toList(),
                ),
              ),"""
if old_reaction_picker in s:
    s = s.replace(old_reaction_picker, new_reaction_picker, 1)

# Make reaction pills on messages more visible.
old_reaction_row = """            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
            child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 12)),"""
new_reaction_row = """            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.28)),
            ),
            child: Text('${e.key}  ${e.value}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),"""
if old_reaction_row in s:
    s = s.replace(old_reaction_row, new_reaction_row, 1)

old_appbar = """appBar: AppBar(\n        title: Row(children: [const CircleAvatar(radius: 17, child: Icon(Icons.person, size: 18)), const SizedBox(width: 9), Expanded(child: Text(widget.title, overflow: TextOverflow.ellipsis))]),\n      ),"""
new_appbar = """appBar: AppBar(\n        title: Row(children: [const CircleAvatar(radius: 17, child: Icon(Icons.person, size: 18)), const SizedBox(width: 9), Expanded(child: Text(widget.title, overflow: TextOverflow.ellipsis))]),\n        actions: [\n          IconButton(\n            tooltip: 'مدیریت گروه',\n            icon: const Icon(Icons.groups_2_rounded),\n            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupManagementPage(conversationId: widget.id, title: widget.title))),\n          ),\n        ],\n      ),"""
if old_appbar in s:
    s = s.replace(old_appbar, new_appbar, 1)

p.write_text(s, encoding='utf-8')
