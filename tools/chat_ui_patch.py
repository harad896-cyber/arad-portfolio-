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
  Map<String, List<Map<String, dynamic>>> reactions = {};
  RealtimeChannel? channel;
  bool loading = true;
  bool sending = false;
  Map<String, dynamic>? replyMessage;

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

  Future<void> load() async {
    try {
      final rows = await supabase.from('messages').select().eq('conversation_id', widget.id).order('created_at');
      final loaded = List<Map<String, dynamic>>.from(rows);
      final senderIds = loaded.map((m) => '${m['sender_id']}').toSet().toList();
      if (senderIds.isNotEmpty) {
        final people = await supabase.from('profiles').select('id,display_name,username,avatar_url').inFilter('id', senderIds);
        profiles = {for (final p in List<Map<String, dynamic>>.from(people)) '${p['id']}': p};
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
      final msg = await supabase.from('messages').insert({
        'conversation_id': widget.id,
        'sender_id': supabase.auth.currentUser!.id,
        'body': f.name,
        'message_type': 'file',
        'reply_to': replyMessage?['id'],
      }).select().single();
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
      final msg = await supabase.from('messages').insert({
        'conversation_id': widget.id,
        'sender_id': supabase.auth.currentUser!.id,
        'body': image.name,
        'message_type': 'image',
        'reply_to': replyMessage?['id'],
      }).select().single();
      await supabase.from('message_attachments').insert({'message_id': msg['id'], 'storage_path': path, 'file_name': image.name, 'mime_type': 'image'});
      if (mounted) setState(() => replyMessage = null);
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'تصویر ارسال نشد: $e');
    }
  }

  Future<void> reactTo(Map<String, dynamic> message, String emoji) async {
    final uid = supabase.auth.currentUser!.id;
    try {
      final current = (reactions['${message['id']}'] ?? const <Map<String, dynamic>>[]).where((r) => r['user_id'] == uid).toList();
      if (current.isNotEmpty && current.first['reaction'] == emoji) {
        await supabase.from('message_reactions').delete().match({'message_id': message['id'], 'user_id': uid});
      } else {
        await supabase.from('message_reactions').upsert({'message_id': message['id'], 'user_id': uid, 'reaction': emoji});
      }
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'واکنش ذخیره نشد: $e');
    }
  }

  void setReply(Map<String, dynamic> message) {
    setState(() => replyMessage = message);
  }

  Future<void> showMessageActions(Map<String, dynamic> message) async {
    const emojis = ['❤️', '👍', '😂', '😮', '😢', '🔥'];
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
              ),
              const Divider(height: 18),
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('پاسخ به این پیام'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setReply(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('کپی متن'),
                enabled: '${message['body'] ?? ''}'.isNotEmpty,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: '${message['body'] ?? ''}'));
                  Navigator.pop(sheetContext);
                  showMsg(context, 'متن کپی شد.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _replyPreview(Map<String, dynamic> message) {
    final id = '${message['reply_to'] ?? ''}';
    if (id.isEmpty) return const SizedBox.shrink();
    Map<String, dynamic>? parent;
    for (final item in messages) {
      if ('${item['id']}' == id) {
        parent = item;
        break;
      }
    }
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
    for (final r in list) {
      final emoji = '${r['reaction']}';
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Wrap(
        spacing: 4,
        children: counts.entries.map((e) => InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => reactTo(message, e.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
            child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 12)),
          ),
        )).toList(),
      ),
    );
  }

  Widget _messageBubble(Map<String, dynamic> m) {
    final mine = m['sender_id'] == supabase.auth.currentUser!.id;
    final sender = _senderName(m);
    final avatarUrl = profiles['${m['sender_id']}']?['avatar_url']?.toString() ?? '';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => showMessageActions(m),
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0).abs() > 450) setReply(m);
        },
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .84),
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine) ...[
                CircleAvatar(radius: 17, backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null, child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 18) : null),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Card(
                  margin: EdgeInsets.zero,
                  color: mine ? Theme.of(context).colorScheme.primaryContainer : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 10, 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!mine) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(sender, style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary))),
                        _replyPreview(m),
                        if (m['message_type'] == 'image') const Padding(padding: EdgeInsets.only(bottom: 5), child: Icon(Icons.image_rounded, size: 42)),
                        if ('${m['body'] ?? ''}'.isNotEmpty) Text('${m['body'] ?? ''}', style: const TextStyle(fontSize: 15.5, height: 1.35)),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${_dateLabel(m['created_at'])}  ${_time(m['created_at'])}', style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            if (mine) ...[
                              const SizedBox(width: 4),
                              Icon(m['read_at'] != null ? Icons.done_all_rounded : Icons.done_rounded, size: 15, color: m['read_at'] != null ? Colors.blue : null),
                            ],
                          ],
                        ),
                        _reactionRow(m),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    load();
    channel = supabase.channel('chat-${widget.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: widget.id),
        callback: (_) => load(),
      )
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
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [const CircleAvatar(radius: 17, child: Icon(Icons.person, size: 18)), const SizedBox(width: 9), Expanded(child: Text(widget.title, overflow: TextOverflow.ellipsis))]),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(child: Text('هنوز پیامی وجود ندارد.'))
                    : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), itemCount: messages.length, itemBuilder: (context, i) => _messageBubble(messages[i])),
          ),
          if (replyMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, border: const Border(top: BorderSide(color: Color(0xFFE0E2E8)))),
              child: Row(children: [const Icon(Icons.reply_rounded, size: 20), const SizedBox(width: 8), Expanded(child: Text('${_senderName(replyMessage!)}: ${replyMessage!['body'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))), IconButton(onPressed: () => setState(() => replyMessage = null), icon: const Icon(Icons.close))]),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(onPressed: sendImage, icon: const Icon(Icons.image_outlined)),
                  IconButton(onPressed: sendFile, icon: const Icon(Icons.attach_file)),
                  Expanded(child: TextField(controller: text, minLines: 1, maxLines: 5, textInputAction: TextInputAction.newline, decoration: const InputDecoration(hintText: 'پیام...', border: OutlineInputBorder(), isDense: true))),
                  IconButton(onPressed: sending ? null : sendText, icon: const Icon(Icons.send_rounded)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

'''

s = s[:start] + new_chat + s[end:]
p.write_text(s, encoding='utf-8')
