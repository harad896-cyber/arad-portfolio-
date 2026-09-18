import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'polish_widgets.dart';

class GroupModerationPage extends StatefulWidget {
  final String conversationId;
  final String title;
  const GroupModerationPage({super.key, required this.conversationId, required this.title});
  @override State<GroupModerationPage> createState() => _GroupModerationPageState();
}

class _GroupModerationPageState extends State<GroupModerationPage> {
  final db = Supabase.instance.client;
  bool loading = true, busy = false, isAdmin = false, isOwner = false;
  Map<String, dynamic>? group;
  List<Map<String, dynamic>> messages = [], members = [], banned = [];
  Map<String, Map<String, dynamic>> profiles = {};

  String nameOf(String id) {
    final p = profiles[id];
    return (p?['display_name'] ?? p?['username'] ?? 'کاربر').toString();
  }

  void toast(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> load() async {
    try {
      final g = Map<String, dynamic>.from(await db.from('conversations').select('id,type,title,created_by').eq('id', widget.conversationId).single());
      final ms = List<Map<String, dynamic>>.from(await db.from('conversation_members').select('user_id,role,joined_at').eq('conversation_id', widget.conversationId).order('joined_at'));
      final rawMessages = await db.from('messages').select('id,conversation_id,sender_id,body,message_type,created_at,deleted_at').eq('conversation_id', widget.conversationId).order('created_at', ascending: false).limit(100);
      final bans = List<Map<String, dynamic>>.from(await db.from('group_banned_members').select('conversation_id,user_id,banned_by,reason,created_at').eq('conversation_id', widget.conversationId).order('created_at', ascending: false));
      final ids = <String>{...ms.map((m) => m['user_id'].toString()), ...bans.map((b) => b['user_id'].toString())};
      final people = ids.isEmpty ? <Map<String, dynamic>>[] : List<Map<String, dynamic>>.from(await db.from('profiles').select('id,display_name,username,avatar_url,is_verified').inFilter('id', ids.toList()));
      final uid = db.auth.currentUser?.id;
      if (!mounted) return;
      setState(() {
        group = g; members = ms; messages = List<Map<String, dynamic>>.from(rawMessages); banned = bans;
        profiles = {for (final p in people) p['id'].toString(): p};
        isOwner = uid != null && g['created_by'].toString() == uid;
        isAdmin = uid != null && (isOwner || ms.any((m) => m['user_id'].toString() == uid && ['admin', 'owner'].contains(m['role'])));
        loading = false;
      });
    } catch (e) {
      if (mounted) { setState(() => loading = false); toast('بارگذاری مدیریت گروه ناموفق بود: $e'); }
    }
  }

  Future<void> deleteMessage(String id) async {
    if (!isAdmin || busy) return;
    setState(() => busy = true);
    try { await db.rpc('delete_group_message_for_everyone', params: {'p_conversation_id': widget.conversationId, 'p_message_id': id}); toast('پیام برای همه حذف شد.'); await load(); }
    catch (e) { toast('حذف پیام ناموفق بود: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> banMember(String id) async {
    if (!isAdmin || busy || id == group?['created_by'].toString()) return;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: Text('محروم‌کردن ${nameOf(id)}'), content: TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'دلیل (اختیاری)')), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('لغو')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('محروم و حذف شود'))])) ?? false;
    final text = reason.text.trim(); reason.dispose();
    if (!ok) return;
    setState(() => busy = true);
    try { await db.rpc('ban_group_member', params: {'p_conversation_id': widget.conversationId, 'p_user_id': id, 'p_reason': text.isEmpty ? null : text}); toast('عضو حذف و محروم شد.'); await load(); }
    catch (e) { toast('محروم‌کردن ناموفق بود: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> unbanMember(String id) async {
    if (!isAdmin || busy) return;
    setState(() => busy = true);
    try { await db.rpc('unban_group_member', params: {'p_conversation_id': widget.conversationId, 'p_user_id': id}); toast('محرومیت برداشته شد.'); await load(); }
    catch (e) { toast('رفع محرومیت ناموفق بود: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override void initState() { super.initState(); load(); }

  @override Widget build(BuildContext context) {
    if (loading) return Scaffold(appBar: AppBar(title: const Text('مدیریت گروه')), body: const AppSkeletonList(count: 6));
    if (!isAdmin) return Scaffold(appBar: AppBar(title: Text(widget.title)), body: const Center(child: Text('دسترسی مدیریت گروه ندارید.')));
    final active = messages.where((m) => m['deleted_at'] == null).toList();
    return Scaffold(
      appBar: AppBar(title: Text('مدیریت ${(group?['title'] ?? widget.title).toString()}')),
      body: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(14), children: [
        Card(child: ListTile(leading: Icon(Icons.admin_panel_settings_rounded, color: Theme.of(context).colorScheme.primary), title: Text(isOwner ? 'کنترل کامل مالک' : 'مدیریت گروه'), subtitle: const Text('حذف پیام برای همه و مدیریت اعضا'))),
        const SizedBox(height: 12), Text('پیام‌های اخیر (${active.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ...active.map((m) => Card(child: ListTile(title: Text(nameOf(m['sender_id'].toString()), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text((m['body'] ?? '').toString(), maxLines: 3, overflow: TextOverflow.ellipsis), trailing: IconButton(onPressed: busy ? null : () => deleteMessage(m['id'].toString()), icon: const Icon(Icons.delete_sweep_rounded))))),
        const SizedBox(height: 14), Text('اعضا (${members.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ...members.map((m) { final id = m['user_id'].toString(); final owner = id == group?['created_by'].toString(); return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(nameOf(id)), subtitle: Text(owner ? '👑 مالک' : (m['role'] ?? 'member').toString()), trailing: owner || id == db.auth.currentUser?.id ? null : IconButton(onPressed: busy ? null : () => banMember(id), icon: const Icon(Icons.person_remove_rounded)))); }),
        const SizedBox(height: 14), Text('محروم‌شده‌ها (${banned.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ...banned.map((b) { final id = b['user_id'].toString(); return Card(child: ListTile(title: Text(nameOf(id)), subtitle: Text((b['reason'] ?? 'بدون دلیل').toString()), trailing: IconButton(onPressed: busy ? null : () => unbanMember(id), icon: const Icon(Icons.lock_open_rounded)))); }),
      ])),
    );
  }
}
