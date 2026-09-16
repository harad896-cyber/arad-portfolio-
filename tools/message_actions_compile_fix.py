from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

if "import 'package:flutter/services.dart';" not in s:
    s = s.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';", 1)
s = s.replace("import 'group_management.dart';\n", "")

a = s.index('class ChatPage extends StatefulWidget {')
b = s.index('class ProfilePage extends StatefulWidget {', a)
chat = s[a:b]

chat = re.sub(r'\n\s*(?:final\s+)?Map<String\s*,\s*List<String>>\s+reactions\s*=\s*\{\};', '', chat)
if 'Map<String, List<String>> reactions = {};' not in chat:
    chat = chat.replace('  bool sending = false;', '  bool sending = false;\n  Map<String, List<String>> reactions = {};', 1)

chat = chat.replace(
    "showModalBottomSheet(context:context,showDragHandle:true,builder:(x)=>SafeArea(child:Wrap(spacing:10,runSpacing:10,padding:const EdgeInsets.all(20),children:",
    "showModalBottomSheet(context:context,showDragHandle:true,builder:(x)=>SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:Wrap(spacing:10,runSpacing:10,children:"
)
chat = chat.replace(
    ").toList()))); }\n  Future<void> actions",
    ").toList())))); }\n  Future<void> actions"
)

bs = chat.index('  @override Widget build') if '  @override Widget build' in chat else chat.index('  @override\n  Widget build')
new_build = r'''  @override
  Widget build(BuildContext context) {
    final uid = supabase.auth.currentUser!.id;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(radius: 19, child: Text(widget.title.isEmpty ? 'A' : widget.title.substring(0, 1))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const Text('آنلاین و امن', style: TextStyle(fontSize: 11)),
            ])),
          ],
        ),
        actions: [
          IconButton(onPressed: () => showMsg(context, 'جستجوی پیام‌ها به‌زودی فعال می‌شود.'), icon: const Icon(Icons.search_rounded)),
          PopupMenuButton<String>(
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'manage', child: Text('مدیریت گفتگو')),
              PopupMenuItem(value: 'mute', child: Text('بی‌صدا کردن')),
            ],
            onSelected: (value) => showMsg(context, value == 'mute' ? 'تنظیم بی‌صدا کردن آماده است.' : 'مدیریت گفتگو'),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
                  ? const Center(child: Text('هنوز پیامی نیست', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final m = messages[index];
                        final mine = m['sender_id'] == uid;
                        final deleted = m['deleted_at'] != null;
                        final body = '${m['body'] ?? ''}';
                        final messageReactions = reactions['${m['id']}'] ?? <String>[];
                        final created = DateTime.tryParse('${m['created_at'] ?? ''}');
                        final time = created == null ? '' : '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
                        return GestureDetector(
                          onLongPress: () => actions(m),
                          child: Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 350),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.fromLTRB(13, 9, 10, 7),
                              decoration: BoxDecoration(
                                color: mine ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
                                  bottomLeft: Radius.circular(mine ? 20 : 5), bottomRight: Radius.circular(mine ? 5 : 20),
                                ),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (m['reply_to'] != null && !deleted) const Text('↪ پاسخ به پیام', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                if (m['message_type'] == 'image' && !deleted) const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.image_rounded)),
                                if (m['message_type'] == 'file' && !deleted) const Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.insert_drive_file_rounded)),
                                Text(deleted ? 'این پیام حذف شده است' : body, style: TextStyle(fontSize: 15.5, height: 1.35, fontStyle: deleted ? FontStyle.italic : FontStyle.normal)),
                                if (m['edited_at'] != null && !deleted) const Padding(padding: EdgeInsets.only(top: 3), child: Text('ویرایش‌شده', style: TextStyle(fontSize: 9))),
                                if (messageReactions.isNotEmpty && !deleted) Padding(padding: const EdgeInsets.only(top: 4), child: Text(messageReactions.take(6).join(' '), style: const TextStyle(fontSize: 16))),
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(time, style: const TextStyle(fontSize: 10)),
                                  if (mine) ...[const SizedBox(width: 4), Icon(m['read_at'] != null ? Icons.done_all_rounded : Icons.done_rounded, size: 15)],
                                ]),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        if (replyToId != null) Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 5),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.reply, size: 18), const SizedBox(width: 7),
            Expanded(child: Text(replyToText ?? 'پاسخ', maxLines: 1, overflow: TextOverflow.ellipsis)),
            IconButton(onPressed: () => setState(() { replyToId = null; replyToText = null; }), icon: const Icon(Icons.close, size: 18)),
          ]),
        ),
        SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 8, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            IconButton(onPressed: messages.isEmpty ? null : () => pickReaction(messages.last), icon: const Icon(Icons.add_reaction_outlined)),
            IconButton(onPressed: sendImage, icon: const Icon(Icons.photo_outlined)),
            IconButton(onPressed: sendFile, icon: const Icon(Icons.attach_file_rounded)),
            Expanded(child: TextField(
              controller: text, minLines: 1, maxLines: 5,
              decoration: InputDecoration(hintText: 'پیام...', filled: true, fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11)),
            )),
            const SizedBox(width: 4),
            IconButton.filled(onPressed: sending ? null : sendText, icon: const Icon(Icons.send_rounded)),
          ]),
        )),
      ]),
    );
  }
'''
# IMPORTANT: close _ChatPageState before the next top-level class.
chat = chat[:bs] + new_build + '}\n'
s = s[:a] + chat + s[b:]
p.write_text(s, encoding='utf-8')
print('message actions compile fix applied')