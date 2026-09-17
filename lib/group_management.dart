import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'group_moderation.dart';

class GroupManagementPage extends StatefulWidget {
  final String conversationId;
  final String title;
  const GroupManagementPage({super.key, required this.conversationId, required this.title});
  @override State<GroupManagementPage> createState() => _GroupManagementPageState();
}

class _GroupManagementPageState extends State<GroupManagementPage> {
  final db = Supabase.instance.client;
  Map<String, dynamic>? group;
  List<Map<String, dynamic>> members = [];
  Map<String, Map<String, dynamic>> profiles = {};
  bool loading = true, busy = false, isAdmin = false;

  String nameOf(String id) => (profiles[id]?['display_name'] ?? profiles[id]?['username'] ?? 'کاربر').toString();
  void toast(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  Future<void> load() async {
    try {
      final g = Map<String, dynamic>.from(await db.from('conversations').select('id,type,title,avatar_url,description,created_by,allow_reactions,is_public,username,auto_delete_seconds,join_approval,only_admins_can_post,only_admins_can_add').eq('id', widget.conversationId).single());
      final rows = List<Map<String, dynamic>>.from(await db.from('conversation_members').select('conversation_id,user_id,role,joined_at').eq('conversation_id', widget.conversationId).order('joined_at'));
      final ids = rows.map((e) => e['user_id'].toString()).toList();
      final people = ids.isEmpty ? <Map<String, dynamic>>[] : List<Map<String, dynamic>>.from(await db.from('profiles').select('id,display_name,username,avatar_url,is_verified').inFilter('id', ids));
      if (!mounted) return;
      final uid = db.auth.currentUser?.id;
      setState(() { group = g; members = rows; profiles = {for (final p in people) p['id'].toString(): p}; isAdmin = uid != null && (uid == g['created_by'].toString() || rows.any((m) => m['user_id'].toString() == uid && ['admin','owner'].contains(m['role']))); loading = false; });
    } catch (e) { if (mounted) { setState(() => loading = false); toast('خطا در بارگذاری گروه: $e'); } }
  }

  Future<void> updateSettings({String? title, String? description, bool? publicGroup, bool? approval, bool? adminsPost, bool? adminsAdd, bool? reactions}) async {
    if (!isAdmin || group == null || busy) return;
    setState(() => busy = true); final g = group!;
    try {
      await db.rpc('update_group_settings', params: {
        'p_conversation_id': widget.conversationId, 'p_title': title ?? g['title'], 'p_description': description ?? g['description'], 'p_avatar_url': g['avatar_url'],
        'p_is_public': publicGroup ?? g['is_public'] ?? false, 'p_username': g['username'], 'p_join_approval': approval ?? g['join_approval'] ?? false,
        'p_only_admins_can_post': adminsPost ?? g['only_admins_can_post'] ?? false, 'p_only_admins_can_add': adminsAdd ?? g['only_admins_can_add'] ?? false,
        'p_auto_delete_seconds': g['auto_delete_seconds'] ?? 0, 'p_allow_reactions': reactions ?? g['allow_reactions'] ?? true,
      });
      await load();
    } catch (e) { toast('تنظیمات ذخیره نشد: $e'); } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> editGroup() async {
    if (!isAdmin || group == null) return;
    final title = TextEditingController(text: (group!['title'] ?? widget.title).toString());
    final desc = TextEditingController(text: (group!['description'] ?? '').toString());
    await showDialog<void>(context: context, builder: (d) => AlertDialog(title: const Text('ویرایش پروفایل گروه'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: title, decoration: const InputDecoration(labelText: 'نام گروه')), TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'توضیحات'))]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('لغو')), FilledButton(onPressed: () { Navigator.pop(d); updateSettings(title: title.text.trim(), description: desc.text.trim()); }, child: const Text('ذخیره'))]));
    title.dispose(); desc.dispose();
  }

  Future<void> removeMember(String id) async {
    if (!isAdmin || busy) return;
    try { await db.rpc('remove_group_member', params: {'p_conversationId': widget.conversationId, 'p_user_id': id}); await load(); toast('عضو حذف شد.'); } catch (e) { toast('حذف عضو ناموفق بود: $e'); }
  }

  Future<void> changeRole(String id, String role) async {
    if (!isAdmin || busy) return;
    try { await db.rpc('set_group_member_role', params: {'p_conversation_id': widget.conversationId, 'p_user_id': id, 'p_role': role}); await load(); } catch (e) { toast('تغییر نقش ناموفق بود: $e'); }
  }

  @override void initState() { super.initState(); load(); }

  @override Widget build(BuildContext context) {
    if (loading) return Scaffold(appBar: AppBar(title: Text(widget.title)), body: const Center(child: CircularProgressIndicator()));
    if (group == null || group!['type'] != 'group') return Scaffold(appBar: AppBar(title: Text(widget.title)), body: const Center(child: Text('این گفتگو گروه نیست.')));
    final groupTitle = (group!['title'] ?? widget.title).toString();
    return Scaffold(
      appBar: AppBar(title: Text(groupTitle), actions: [if (isAdmin) IconButton(onPressed: busy ? null : editGroup, icon: const Icon(Icons.edit_rounded))]),
      body: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(14), children: [
        Card(child: ListTile(title: Text(groupTitle, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${members.length} عضو'))),
        if (isAdmin) ...[
          Card(child: Column(children: [
            SwitchListTile(title: const Text('گروه عمومی'), value: group!['is_public'] == true, onChanged: busy ? null : (v) => updateSettings(publicGroup: v)),
            SwitchListTile(title: const Text('تأیید عضویت'), value: group!['join_approval'] == true, onChanged: busy ? null : (v) => updateSettings(approval: v)),
            SwitchListTile(title: const Text('فقط مدیران پیام بفرستند'), value: group!['only_admins_can_post'] == true, onChanged: busy ? null : (v) => updateSettings(adminsPost: v)),
            SwitchListTile(title: const Text('فقط مدیران عضو اضافه کنند'), value: group!['only_admins_can_add'] == true, onChanged: busy ? null : (v) => updateSettings(adminsAdd: v)),
            SwitchListTile(title: const Text('واکنش به پیام‌ها'), value: group!['allow_reactions'] != false, onChanged: busy ? null : (v) => updateSettings(reactions: v)),
          ])),
          Card(child: ListTile(leading: const Icon(Icons.admin_panel_settings_rounded), title: const Text('مدیریت پیام و محرومیت'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupModerationPage(conversationId: widget.conversationId, title: groupTitle))).then((_) => load()))),
        ],
        const SizedBox(height: 8), Text('اعضا (${members.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ...members.map((m) {
          final id = m['user_id'].toString(); final owner = id == group!['created_by'].toString(); final role = (m['role'] ?? 'member').toString();
          Widget? action;
          if (isAdmin && !owner && id != db.auth.currentUser?.id) {
            action = PopupMenuButton<String>(onSelected: (v) { if (v == 'remove') { removeMember(id); } else { changeRole(id, v); } }, itemBuilder: (_) => [
              PopupMenuItem<String>(value: role == 'admin' ? 'member' : 'admin', child: Text(role == 'admin' ? 'برداشتن مدیریت' : 'ارتقا به مدیر')),
              const PopupMenuItem<String>(value: 'remove', child: Text('حذف از گروه')),
            ]);
          }
          return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(nameOf(id)), subtitle: Text(owner ? '👑 مالک گروه' : role == 'admin' ? '🛡️ مدیر' : 'عضو'), trailing: action));
        }),
      ])),
    );
  }
}
