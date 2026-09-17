import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupModerationPage extends StatefulWidget {
  final String conversationId;
  final String title;
  const GroupModerationPage({super.key, required this.conversationId, required this.title});
  @override State<GroupModerationPage> createState() => _GroupModerationPageState();
}

class _GroupModerationPageState extends State<GroupModerationPage> {
  final db = Supabase.instance.client;
  bool loading = true;
  bool busy = false;
  bool isAdmin = false;
  bool isOwner = false;
  Map<String,dynamic>? group;
  List<Map<String,dynamic>> messages = [];
  List<Map<String,dynamic>> members = [];
  List<Map<String,dynamic>> banned = [];
  Map<String,Map<String,dynamic>> profiles = {};

  Future<void> load() async {
    try {
      final g = Map<String,dynamic>.from(await db.from('conversations').select('id,type,title,created_by').eq('id', widget.conversationId).single());
      final ms = List<Map<String,dynamic>>.from(await db.from('conversation_members').select('user_id,role,joined_at').eq('conversation_id', widget.conversationId).order('joined_at'));
      final ids = ms.map((m) => '${m['user_id']}').toSet().toList();
      final rows = await db.from('messages').select('id,conversation_id,sender_id,body,message_type,created_at,deleted_at').eq('conversation_id', widget.conversationId).order('created_at', ascending: false).limit(100);
      final b = await db.from('group_banned_members').select('conversation_id,user_id,banned_by,reason,created_at').eq('conversation_id', widget.conversationId).order('created_at', ascending: false);
      final allIds = {...ids, ...List<Map<String,dynamic>>.from(b).map((x) => '${x['user_id']}')};
      final people = allIds.isEmpty ? <Map<String,dynamic>>[] : List<Map<String,dynamic>>.from(await db.from('profiles').select('id,display_name,username,avatar_url,is_verified').inFilter('id', allIds.toList()));
      final p = {for (final x in people) '${x['id']}': x};
      final uid = db.auth.currentUser?.id;
      if (!mounted) return;
      setState(() {
        group = g;
        members = ms;
        messages = List<Map<String,dynamic>>.from(rows);
        banned = List<Map<String,dynamic>>.from(b);
        profiles = p;
        isOwner = uid != null && '${g['created_by']}' == uid;
        isAdmin = uid != null && (isOwner || ms.any((m) => '${m['user_id']}' == uid && ['admin','owner'].contains(m['role'])));
        loading = false;
      });
    } catch (e) {
      if (mounted) { setState(() => loading = false); _toast('بارگذاری مدیریت گروه ناموفق بود: $e'); }
    }
  }

  String nameOf(String id) => '${profiles[id]?['display_name'] ?? profiles[id]?['username'] ?? 'کاربر'}';
  void _toast(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  Future<void> deleteMessage(Map<String,dynamic> message) async {
    if (!isAdmin || busy) return;
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: const Text('حذف پیام برای همه'),
      content: Text('این پیام برای همه اعضای گروه حذف می‌شود.\n\nفرستنده: ${nameOf('${message['sender_id']}')}'),
      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('لغو')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حذف برای همه'))],
    )) ?? false;
    if (!ok) return;
    setState(() => busy = true);
    try {
      await db.rpc('delete_group_message_for_everyone', params: {'p_conversation_id': widget.conversationId, 'p_message_id': message['id']});
      _toast('پیام برای همه اعضای گروه حذف شد.');
      await load();
    } catch (e) { _toast('حذف پیام ناموفق بود: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> banMember(String id) async {
    if (!isAdmin || busy) return;
    if (id == '${group?['created_by']}') { _toast('مالک گروه قابل محروم‌کردن نیست.'); return; }
    final reason = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: Text('محروم‌کردن ${nameOf(id)}'),
      content: TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'دلیل (اختیاری)')),
      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('لغو')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('محروم و حذف شود'))],
    )) ?? false;
    final r = reason.text.trim();
    reason.dispose();
    if (!ok) return;
    setState(() => busy = true);
    try {
      await db.rpc('ban_group_member', params: {'p_conversation_id': widget.conversationId, 'p_user_id': id, 'p_reason': r.isEmpty ? null : r});
      _toast('عضو از گروه حذف و محروم شد؛ دوباره با افزودن عادی وارد نمی‌شود.');
      await load();
    } catch (e) { _toast('محروم‌کردن ناموفق بود: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> unbanMember(String id) async {
    if (!isAdmin || busy) return;
    setState(() => busy = true);
    try { await db.rpc('unban_group_member', params: {'p_conversation_id': widget.conversationId, 'p_user_id': id}); _toast('محرومیت برداشته شد.'); await load(); }
    catch (e) { _toast('رفع محرومیت ناموفق بود: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override void initState() { super.initState(); load(); }

  @override Widget build(BuildContext context) {
    if (loading) return Scaffold(appBar: AppBar(title: const Text('مدیریت گروه')), body: const Center(child: CircularProgressIndicator()));
    if (!isAdmin) return Scaffold(appBar: AppBar(title: Text(widget.title)), body: const Center(child: Text('دسترسی مدیریت گروه ندارید.')));
    final activeMessages = messages.where((m) => m['deleted_at'] == null).toList();
    return Scaffold(
      appBar: AppBar(title: Text('مدیریت ${group?['title'] ?? widget.title}')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(14), children: [
          Card(child: ListTile(leading: Icon(Icons.admin_panel_settings_rounded, color: Theme.of(context).colorScheme.primary), title: Text(isOwner ? 'کنترل کامل مالک' : 'مدیریت گروه'), subtitle: const Text('حذف پیام برای همه، حذف و محروم‌کردن اعضا'))),
          const SizedBox(height: 10),
          Text('پیام‌های اخیر (${activeMessages.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          if (activeMessages.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('پیام فعالی برای مدیریت وجود ندارد.'))),
          ...activeMessages.map((m) => Card(child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.message_rounded)),
            title: Text(nameOf('${m['sender_id']}'), style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${m['body'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
            trailing: IconButton(tooltip: 'حذف برای همه', onPressed: busy ? null : () => deleteMessage(m), icon: const Icon(Icons.delete_sweep_rounded)),
          ))),
          const SizedBox(height: 14),
          Text('اعضای قابل محروم‌کردن (${members.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          ...members.map((m) {
            final id = '${m['user_id']}';
            final owner = id == '${group?['created_by']}';
            final p = profiles[id];
            return Card(child: ListTile(
              leading: CircleAvatar(backgroundImage: '${p?['avatar_url'] ?? ''}'.isNotEmpty ? NetworkImage('${p?['avatar_url']}') : null, child: '${p?['avatar_url'] ?? ''}'.isEmpty ? const Icon(Icons.person) : null),
              title: Text(nameOf(id)),
              subtitle: Text(owner ? '👑 مالک — قابل محروم‌کردن نیست' : '${m['role'] ?? 'member'}'),
              trailing: owner || id == db.auth.currentUser?.id ? null : IconButton(tooltip: 'محروم و حذف', onPressed: busy ? null : () => banMember(id), icon: const Icon(Icons.person_remove_rounded)),
            ));
          }),
          const SizedBox(height: 14),
          Text('محروم‌شده‌ها (${banned.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          if (banned.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('عضو محروم‌شده‌ای وجود ندارد.'))),
          ...banned.map((b) { final id='${b['user_id']}'; return Card(child: ListTile(leading: const Icon(Icons.block_rounded), title: Text(nameOf(id)), subtitle: Text('${b['reason'] ?? 'بدون دلیل'}\n${b['created_at'] ?? ''}'), isThreeLine: true, trailing: IconButton(tooltip:'رفع محرومیت', onPressed:busy?null:()=>unbanMember(id), icon:const Icon(Icons.lock_open_rounded))); }),
        ],),
      ),
    );
  }
}
