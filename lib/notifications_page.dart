import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool loading = true;
  List<Map<String, dynamic>> rows = [];

  Future<void> load() async {
    rows = [];
    try {
      final db = Supabase.instance.client;
      final raw = await db.rpc('get_unread_counts');
      final items = List<Map<String, dynamic>>.from(raw as List);
      final ids = items.map((e) => '${e['conversation_id']}').toList();
      final result = <Map<String, dynamic>>[];
      if (ids.isNotEmpty) {
        final conversations = await db.from('conversations').select('id,type,title').inFilter('id', ids);
        final byId = {for (final c in conversations) '${c['id']}': Map<String, dynamic>.from(c)};
        for (final item in items) {
          final c = byId['${item['conversation_id']}'];
          if (c != null) result.add({...c, 'unread_count': item['unread_count']});
        }
      }
      if (mounted) setState(() { rows = result; loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('اعلان‌ها بارگذاری نشد: $e')));
      }
    }
  }

  @override
  void initState() { super.initState(); load(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اعلان‌ها')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? ListView(children: const [SizedBox(height: 180), Icon(Icons.notifications_none_rounded, size: 64), SizedBox(height: 14), Center(child: Text('اعلان خوانده‌نشده‌ای ندارید'))])
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      final type = '${r['type']}';
                      final title = '${r['title'] ?? (type == 'group' ? 'گروه' : type == 'channel' ? 'کانال' : 'گفتگو')}';
                      return Card(child: ListTile(
                        leading: CircleAvatar(child: Icon(type == 'group' ? Icons.group : type == 'channel' ? Icons.campaign : Icons.person)),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${r['unread_count']} پیام خوانده‌نشده'),
                        trailing: Text('${r['unread_count']}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900)),
                      ));
                    },
                  ),
                ),
    );
  }
}

class ConversationStatsPage extends StatefulWidget {
  final String conversationId;
  final String title;
  const ConversationStatsPage({super.key, required this.conversationId, required this.title});
  @override
  State<ConversationStatsPage> createState() => _ConversationStatsPageState();
}

class _ConversationStatsPageState extends State<ConversationStatsPage> {
  bool loading = true;
  List<Map<String, dynamic>> stats = [];

  Future<void> load() async {
    rows = [];
    try {
      final db = Supabase.instance.client;
      final raw = await db.rpc('get_conversation_sender_stats', params: {'p_conversation_id': widget.conversationId});
      final base = List<Map<String, dynamic>>.from(raw as List);
      final ids = base.map((e) => '${e['sender_id']}').toList();
      final result = <Map<String, dynamic>>[];
      if (ids.isNotEmpty) {
        final people = await db.from('profiles').select('id,display_name,username,avatar_url').inFilter('id', ids);
        final byId = {for (final p in people) '${p['id']}': Map<String, dynamic>.from(p)};
        result.addAll(base.map((e) => {...e, 'profile': byId['${e['sender_id']}']}));
      }
      if (mounted) setState(() { stats = result; loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('آمار پیام‌ها بارگذاری نشد: $e')));
      }
    }
  }

  @override
  void initState() { super.initState(); load(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('آمار پیام‌ها — ${widget.title}')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : stats.isEmpty
              ? const Center(child: Text('هنوز پیامی ارسال نشده است.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: stats.length,
                  itemBuilder: (_, i) {
                    final s = stats[i];
                    final p = s['profile'] is Map ? Map<String, dynamic>.from(s['profile']) : <String, dynamic>{};
                    final avatar = '${p['avatar_url'] ?? ''}';
                    return ListTile(
                      leading: CircleAvatar(backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null, child: avatar.isEmpty ? const Icon(Icons.person) : null),
                      title: Text('${p['display_name'] ?? p['username'] ?? 'کاربر'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('@${p['username'] ?? ''}'),
                      trailing: Text('${s['message_count']} پیام'),
                    );
                  },
                ),
    );
  }
}
