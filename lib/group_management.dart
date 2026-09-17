import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  List<Map<String, dynamic>> restrictions = [];
  List<Map<String, dynamic>> audit = [];
  bool loading = true, busy = false, isAdmin = false, isOwner = false;

  Future<void> load() async {
    try {
      final c = await db.from('conversations').select('id,type,title,avatar_url,description,created_by,allow_reactions,allow_member_add,is_public,username,auto_delete_seconds,join_approval,only_admins_can_post,only_admins_can_add').eq('id', widget.conversationId).single();
      final rows = await db.from('conversation_members').select('conversation_id,user_id,role,joined_at').eq('conversation_id', widget.conversationId).order('joined_at');
      final list = List<Map<String, dynamic>>.from(rows);
      final ids = list.map((e) => '${e['user_id']}').toList();
      final people = ids.isEmpty ? <dynamic>[] : await db.from('profiles').select('id,display_name,username,avatar_url,is_verified,is_owner').inFilter('id', ids);
      final map = {for (final p in List<Map<String, dynamic>>.from(people)) '${p['id']}': p};
      List<Map<String, dynamic>> r = [], a = [];
      try { r = List<Map<String, dynamic>>.from(await db.from('group_member_restrictions').select().eq('conversation_id', widget.conversationId)); } catch (_) {}
      try { a = List<Map<String, dynamic>>.from(await db.from('group_audit_logs').select().eq('conversation_id', widget.conversationId).order('created_at', ascending: false).limit(50)); } catch (_) {}
      final uid = db.auth.currentUser?.id;
      if (!mounted) return;
      setState(() { group = Map<String, dynamic>.from(c); members = list; profiles = map; restrictions = r; audit = a; isOwner = uid != null && c['created_by'] == uid; isAdmin = isOwner || list.any((m) => m['user_id'] == uid && m['role'] == 'admin'); loading = false; });
    } catch (e) { if (mounted) { setState(() => loading = false); _toast('خطا در بارگذاری گروه: $e'); } }
  }
  String nameOf(String id) => '${profiles[id]?['display_name'] ?? profiles[id]?['username'] ?? 'کاربر'}';
  bool restricted(String id, String key) => restrictions.any((r) => '${r['user_id']}' == id && r[key] == false);
  void _toast(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }

  Future<void> addMember() async {
    if (!isAdmin) return;
    final c = TextEditingController();
    await showDialog(context: context, builder: (d) => AlertDialog(title: const Text('افزودن عضو'), content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'نام کاربری یا نام نمایشی')), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('لغو')), FilledButton(onPressed: () async {
      final q = c.text.trim(); if (q.isEmpty) return;
      try { final results = await db.from('profiles').select('id,display_name,username').or('username.ilike.%$q%,display_name.ilike.%$q%').limit(10); if (!d.mounted) return; Navigator.pop(d); if (results.isEmpty) { _toast('کاربری پیدا نشد.'); return; } if (results.length == 1) await _addUser('${results.first['id']}'); else await _chooseUser(List<Map<String, dynamic>>.from(results)); }
      catch (e) { if (d.mounted) Navigator.pop(d); _toast('جستجو ناموفق بود: $e'); }
    }, child: const Text('جستجو'))]));
    c.dispose();
  }
  Future<void> _chooseUser(List<Map<String, dynamic>> results) async => showModalBottomSheet(context: context, showDragHandle: true, builder: (s) => SafeArea(child: ListView(shrinkWrap: true, children: results.map((p) => ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text('${p['display_name'] ?? p['username'] ?? 'کاربر'}'), subtitle: Text('@${p['username'] ?? ''}'), onTap: () { Navigator.pop(s); _addUser('${p['id']}'); })).toList())));
  Future<void> _addUser(String id) async { try { await db.rpc('add_group_member', params: {'p_conversation_id': widget.conversationId, 'p_user_id': id}); await load(); _toast('عضو اضافه شد.'); } catch (e) { _toast('افزودن عضو ناموفق بود: $e'); } }
  Future<void> removeMember(String id) async { try { await db.rpc('remove_group_member', params: {'p_conversation_id': widget.conversationId, 'p_user_id': id}); await load(); } catch (e) { _toast('حذف عضو ناموفق بود: $e'); } }
  Future<void> changeRole(String id, String role) async { try { await db.rpc('set_group_member_role', params: {'p_conversation_id': widget.conversationId, 'p_user_id': id, 'p_role': role}); await load(); } catch (e) { _toast('تغییر نقش ناموفق بود: $e'); } }
  Future<void> updateSettings(Map<String, dynamic> values) async { if (!isAdmin) return; setState(() => busy = true); try { await db.rpc('update_group_settings', params: {'p_conversation_id': widget.conversationId, ...values}); await load(); } catch (e) { _toast('تنظیمات ذخیره نشد: $e'); } finally { if (mounted) setState(() => busy = false); } }

  Future<void> editGroup() async {
    final title = TextEditingController(text: '${group?['title'] ?? widget.title}');
    final desc = TextEditingController(text: '${group?['description'] ?? ''}');
    final username = TextEditingController(text: '${group?['username'] ?? ''}');
    await showDialog(context: context, builder: (d) => AlertDialog(title: const Text('ویرایش پروفایل گروه'), content: SingleChildScrollView(child: Column(children: [TextField(controller: title, decoration: const InputDecoration(labelText: 'نام گروه')), const SizedBox(height: 10), TextField(controller: username, decoration: const InputDecoration(labelText: 'نام کاربری عمومی (اختیاری)', prefixText: '@')), const SizedBox(height: 10), TextField(controller: desc, maxLines: 4, decoration: const InputDecoration(labelText: 'توضیحات گروه'))])), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('لغو')), FilledButton(onPressed: () async { Navigator.pop(d); await updateSettings({'p_title': title.text.trim(), 'p_description': desc.text.trim(), 'p_username': username.text.trim().isEmpty ? null : username.text.trim()}); }, child: const Text('ذخیره'))]));
    title.dispose(); desc.dispose(); username.dispose();
  }

  Future<void> restrictMember(String id) async {
    if (!isAdmin) return;
    final current = restrictions.where((r) => '${r['user_id']}' == id).firstOrNull;
    bool messages = current?['can_send_messages'] ?? true, media = current?['can_send_media'] ?? true, links = current?['can_send_links'] ?? true;
    await showDialog(context: context, builder: (d) => StatefulBuilder(builder: (d, set) => AlertDialog(title: Text('محدودیت ${nameOf(id)}'), content: Column(mainAxisSize: MainAxisSize.min, children: [SwitchListTile(title: const Text('ارسال پیام'), value: messages, onChanged: (v) => set(() => messages = v)), SwitchListTile(title: const Text('ارسال رسانه'), value: media, onChanged: (v) => set(() => media = v)), SwitchListTile(title: const Text('ارسال لینک'), value: links, onChanged: (v) => set(() => links = v))]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('لغو')), FilledButton(onPressed: () async { Navigator.pop(d); try { await db.rpc('restrict_group_member', params: {'p_conversation_id': widget.conversationId, 'p_user_id': id, 'p_can_send_messages': messages, 'p_can_send_media': media, 'p_can_send_links': links, 'p_expires_at': null}); await load(); } catch (e) { _toast('محدودیت ذخیره نشد: $e'); } }, child: const Text('اعمال'))])));
  }

  Future<void> createInvite() async {
    if (!isAdmin) return;
    try { final result = await db.rpc('create_group_invite', params: {'p_conversation_id': widget.conversationId, 'p_max_uses': 0, 'p_expires_at': null, 'p_requires_approval': group?['join_approval'] == true}); final code = result is Map ? '${result['code'] ?? ''}' : '$result'; if (!mounted) return; await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('لینک دعوت گروه'), content: SelectableText(code.isEmpty ? 'دعوت ایجاد شد.' : 'کد دعوت: $code'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن'))])); } catch (e) { _toast('ساخت دعوت ناموفق بود: $e'); }
  }

  @override void initState() { super.initState(); load(); }
  @override Widget build(BuildContext context) {
    final g = group;
    if (loading) return Scaffold(appBar: AppBar(title: Text(widget.title)), body: const Center(child: CircularProgressIndicator()));
    if (g == null || g['type'] != 'group') return Scaffold(appBar: AppBar(title: Text(widget.title)), body: const Center(child: Text('این گفتگو گروه نیست.')));
    return Scaffold(appBar: AppBar(title: Text('${g['title'] ?? widget.title}'), actions: [if (isAdmin) IconButton(onPressed: busy ? null : editGroup, icon: const Icon(Icons.edit_rounded))]), body: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(14), children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const CircleAvatar(radius: 30, child: Icon(Icons.groups_rounded, size: 30)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${g['title'] ?? widget.title}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text('${members.length} عضو • ${isOwner ? 'مالک' : isAdmin ? 'مدیر' : 'عضو'}'), if ('${g['username'] ?? ''}'.isNotEmpty) Text('@${g['username']}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700))]))]), if ('${g['description'] ?? ''}'.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('${g['description']}')), const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: [if (isAdmin) ActionChip(avatar: const Icon(Icons.person_add), label: const Text('افزودن عضو'), onPressed: addMember), if (isAdmin) ActionChip(avatar: const Icon(Icons.link), label: const Text('لینک دعوت'), onPressed: createInvite)])]))),
      if (isAdmin) ...[
        const SizedBox(height: 8), Card(child: Column(children: [SwitchListTile(title: const Text('گروه عمومی'), subtitle: const Text('با نام کاربری قابل پیدا شدن باشد'), value: g['is_public'] == true, onChanged: busy ? null : (v) => updateSettings({'p_is_public': v})), SwitchListTile(title: const Text('تأیید عضویت'), subtitle: const Text('درخواست ورود نیاز به تأیید داشته باشد'), value: g['join_approval'] == true, onChanged: busy ? null : (v) => updateSettings({'p_join_approval': v})), SwitchListTile(title: const Text('فقط مدیران پیام بفرستند'), value: g['only_admins_can_post'] == true, onChanged: busy ? null : (v) => updateSettings({'p_only_admins_can_post': v})), SwitchListTile(title: const Text('فقط مدیران عضو اضافه کنند'), value: g['only_admins_can_add'] == true, onChanged: busy ? null : (v) => updateSettings({'p_only_admins_can_add': v})), SwitchListTile(title: const Text('واکنش به پیام‌ها'), value: g['allow_reactions'] == true, onChanged: busy ? null : (v) => updateSettings({'p_allow_reactions': v})), ListTile(title: const Text('حذف خودکار پیام‌ها'), subtitle: Text(g['auto_delete_seconds'] == null || g['auto_delete_seconds'] == 0 ? 'خاموش' : '${g['auto_delete_seconds']} ثانیه'), trailing: DropdownButton<int>(value: [0,86400,604800,2592000].contains(g['auto_delete_seconds']) ? (g['auto_delete_seconds'] ?? 0) : 0, items: const [DropdownMenuItem(value: 0, child: Text('خاموش')), DropdownMenuItem(value: 86400, child: Text('۱ روز')), DropdownMenuItem(value: 604800, child: Text('۷ روز')), DropdownMenuItem(value: 2592000, child: Text('۳۰ روز'))], onChanged: busy ? null : (v) { if (v != null) updateSettings({'p_auto_delete_seconds': v}); }))])),
        const SizedBox(height: 8), Card(child: ListTile(leading: const Icon(Icons.history), title: const Text('گزارش مدیریت'), subtitle: Text('${audit.length} رویداد اخیر'), onTap: _showAudit)),
      ],
      const SizedBox(height: 10), Text('اعضای گروه (${members.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 6),
      ...members.map((m) { final id = '${m['user_id']}'; final owner = id == '${g['created_by']}'; final role = '${m['role'] ?? 'member'}'; final p = profiles[id]; return Card(child: ListTile(leading: CircleAvatar(backgroundImage: '${p?['avatar_url'] ?? ''}'.isNotEmpty ? NetworkImage('${p?['avatar_url']}') : null, child: '${p?['avatar_url'] ?? ''}'.isEmpty ? Text(nameOf(id).isEmpty ? '?' : nameOf(id)[0].toUpperCase()) : null), title: Row(children: [Flexible(child: Text(nameOf(id))), if (p?['is_owner'] == true) const Padding(padding: EdgeInsets.only(right: 5), child: Icon(Icons.verified, size: 17)), if (p?['is_verified'] == true) const Padding(padding: EdgeInsets.only(right: 5), child: Icon(Icons.verified_user, size: 16))]), subtitle: Text(owner ? '👑 مالک گروه' : role == 'admin' ? '🛡️ مدیر' : restricted(id, 'can_send_messages') ? '🚫 محدود شده' : 'عضو'), trailing: isAdmin && !owner && id != db.auth.currentUser?.id ? PopupMenuButton<String>(onSelected: (v) => v == 'remove' ? removeMember(id) : v == 'restrict' ? restrictMember(id) : changeRole(id, v), itemBuilder: (_) => [PopupMenuItem(value: role == 'admin' ? 'member' : 'admin', child: Text(role == 'admin' ? 'برداشتن مدیریت' : 'ارتقا به مدیر')), const PopupMenuItem(value: 'restrict', child: Text('محدودیت‌های عضو')), const PopupMenuItem(value: 'remove', child: Text('حذف از گروه'))]) : null)); }),
    ])));
  }

  void _showAudit() => showModalBottomSheet(context: context, showDragHandle: true, builder: (_) => SafeArea(child: audit.isEmpty ? const Padding(padding: EdgeInsets.all(30), child: Text('هنوز رویدادی ثبت نشده.')) : ListView.builder(padding: const EdgeInsets.all(12), itemCount: audit.length, itemBuilder: (_, i) { final x = audit[i]; return ListTile(leading: const Icon(Icons.event_note), title: Text('${x['action'] ?? 'رویداد'}'), subtitle: Text('${x['created_at'] ?? ''}')); })));
}
