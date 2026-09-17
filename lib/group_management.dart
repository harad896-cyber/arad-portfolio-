import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'group_moderation.dart';
import 'group_advanced_admin.dart';
import 'channel_management.dart';

class GroupProfilePage extends StatefulWidget {
  final String conversationId;
  final String title;
  const GroupProfilePage({super.key, required this.conversationId, required this.title});
  @override State<GroupProfilePage> createState() => _GroupProfilePageState();
}

class _GroupProfilePageState extends State<GroupProfilePage> {
  final db = Supabase.instance.client;
  Map<String, dynamic>? group;
  List<Map<String, dynamic>> members = [];
  Map<String, Map<String, dynamic>> profiles = {};
  bool loading = true, admin = false, owner = false, busy = false;

  String nameOf(String id) => (profiles[id]?['display_name'] ?? profiles[id]?['username'] ?? 'کاربر').toString();
  String avatarOf(String id) => (profiles[id]?['avatar_url'] ?? '').toString();
  void toast(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }

  Future<void> load() async {
    try {
      final g = Map<String, dynamic>.from(await db.from('conversations').select('id,type,title,avatar_url,description,created_by,username,is_public').eq('id', widget.conversationId).single());
      final ms = List<Map<String, dynamic>>.from(await db.from('conversation_members').select('user_id,role,joined_at').eq('conversation_id', widget.conversationId).order('joined_at'));
      final ids = ms.map((m) => m['user_id'].toString()).toList();
      final ps = ids.isEmpty ? <Map<String, dynamic>>[] : List<Map<String, dynamic>>.from(await db.from('profiles').select('id,display_name,username,avatar_url,is_verified').inFilter('id', ids));
      final uid = db.auth.currentUser?.id;
      if (!mounted) return;
      setState(() {
        group = g; members = ms; profiles = {for (final p in ps) p['id'].toString(): p};
        owner = uid != null && g['created_by']?.toString() == uid;
        admin = owner || (uid != null && ms.any((m) => m['user_id']?.toString() == uid && ['admin', 'owner'].contains(m['role'])));
        loading = false;
      });
    } catch (_) {
      if (mounted) { setState(() => loading = false); toast('پروفایل گروه بارگذاری نشد.'); }
    }
  }

  Future<void> leaveGroup() async {
    if (owner) { toast('مالک نمی‌تواند خارج شود؛ برای مالک فقط حذف کامل گروه فعال است.'); return; }
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: const Text('خروج از گروه'), content: const Text('فقط حساب شما از گروه خارج می‌شود.'),
      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('خروج'))],
    )) ?? false;
    if (!ok || busy) return;
    setState(() => busy = true);
    try { await db.rpc('leave_group', params: {'p_conversation_id': widget.conversationId}); if (mounted) Navigator.pop(context, true); }
    catch (e) { toast('خروج ناموفق بود: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> deleteGroup() async {
    if (!owner || busy) return;
    final c = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: const Text('حذف کامل گروه'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [const Text('این گزینه خود گروه و محتوای آن را برای همه حذف می‌کند.'), const SizedBox(height: 10), TextField(controller: c, decoration: const InputDecoration(labelText: 'برای تأیید: حذف گروه'))]),
      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(d, c.text.trim() == 'حذف گروه'), child: const Text('حذف دائمی'))],
    )) ?? false;
    c.dispose();
    if (!ok) return;
    setState(() => busy = true);
    try { await db.rpc('delete_group', params: {'p_conversation_id': widget.conversationId}); if (mounted) Navigator.pop(context, true); }
    catch (e) { toast('حذف گروه ناموفق بود: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> changeGroupAvatar() async {
    if (!admin || busy) return;
    final source = await showModalBottomSheet<ImageSource>(context: context, builder: (s) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('انتخاب از گالری'), onTap: () => Navigator.pop(s, ImageSource.gallery)),
      ListTile(leading: const Icon(Icons.camera_alt_rounded), title: const Text('دوربین'), onTap: () => Navigator.pop(s, ImageSource.camera)),
    ])));
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1200);
    if (file == null) return;
    setState(() => busy = true);
    try {
      final bytes = await file.readAsBytes();
      final path = 'groups/${widget.conversationId}/avatar-${DateTime.now().millisecondsSinceEpoch}.jpg';
      await db.storage.from('avatars').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
      final url = db.storage.from('avatars').getPublicUrl(path);
      await db.rpc('update_group_settings', params: {
        'p_conversation_id': widget.conversationId,
        'p_title': group?['title'],
        'p_description': group?['description'],
        'p_avatar_url': url,
        'p_is_public': group?['is_public'] ?? false,
        'p_username': group?['username'],
        'p_join_approval': group?['join_approval'] ?? false,
        'p_only_admins_can_post': group?['only_admins_can_post'] ?? false,
        'p_only_admins_can_add': group?['only_admins_can_add'] ?? false,
        'p_auto_delete_seconds': group?['auto_delete_seconds'] ?? 0,
        'p_allow_reactions': group?['allow_reactions'] ?? true,
      });
      await load();
    } catch (e) { toast('تغییر عکس گروه ناموفق بود: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> openManagement() async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => GroupManagementPage(conversationId: widget.conversationId, title: widget.title)));
    if (changed == true) await load();
  }

  @override void initState() { super.initState(); load(); }

  @override Widget build(BuildContext context) {
    if (loading) return Scaffold(appBar: AppBar(title: const Text('پروفایل گروه')), body: const Center(child: CircularProgressIndicator()));
    final g = group!; final title = (g['title'] ?? widget.title).toString(); final desc = (g['description'] ?? '').toString().trim(); final image = (g['avatar_url'] ?? '').toString();
    return Scaffold(appBar: AppBar(title: const Text('پروفایل گروه')), body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [
        GestureDetector(onTap: admin ? changeGroupAvatar : null, child: Stack(alignment: Alignment.bottomRight, children: [CircleAvatar(radius: 54, backgroundImage: image.isNotEmpty ? NetworkImage(image) : null, child: image.isEmpty ? const Icon(Icons.groups_rounded, size: 50) : null), if (admin) Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18))])),
        const SizedBox(height: 12), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        if ((g['username'] ?? '').toString().trim().isNotEmpty) Text('@${g['username']}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8), Text(desc.isEmpty ? 'بدون توضیحات' : desc, textAlign: TextAlign.center),
        const SizedBox(height: 10), Text('${members.length} عضو', style: const TextStyle(fontWeight: FontWeight.w800)),
      ]))),
      const SizedBox(height: 12),
      Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.people_alt_rounded), title: const Text('اعضای گروه'), subtitle: Text('${members.length} عضو'), trailing: const Icon(Icons.chevron_left), onTap: () => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => ListView(padding: const EdgeInsets.all(16), children: [const Text('اعضای گروه', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 8), ...members.map((m) { final id = m['user_id'].toString(); final a = avatarOf(id); final o = g['created_by']?.toString() == id; return ListTile(leading: CircleAvatar(backgroundImage: a.isNotEmpty ? NetworkImage(a) : null, child: a.isEmpty ? const Icon(Icons.person) : null), title: Text(nameOf(id)), subtitle: Text(o ? '👑 مالک' : (m['role'] ?? 'عضو').toString())); })]))),
        if (admin) ListTile(leading: const Icon(Icons.person_add_alt_1_rounded), title: const Text('افزودن اعضا'), subtitle: const Text('جستجو و افزودن چند کاربر به‌صورت هم‌زمان'), trailing: const Icon(Icons.chevron_left), onTap: openManagement),
        if (admin) const Divider(height: 1),
        if (admin) ListTile(leading: const Icon(Icons.link_rounded), title: const Text('لینک گروه'), subtitle: const Text('ساخت، کپی، اشتراک‌گذاری و باطل کردن لینک دعوت'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationInvitePage(conversationId: widget.conversationId, title: title, type: 'group')))),
        if (admin) ListTile(leading: const Icon(Icons.admin_panel_settings_rounded), title: const Text('مدیریت گروه'), subtitle: const Text('حذف عضو، محرومیت، نقش‌ها و تنظیمات'), trailing: const Icon(Icons.chevron_left), onTap: openManagement),
        if (owner) ListTile(
          leading: const Icon(Icons.dashboard_customize_rounded),
          title: const Text('مدیریت پیشرفته'),
          subtitle: const Text('درخواست عضویت، محدودیت‌ها، محروم‌ها و پیام‌های سنجاق‌شده'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupAdvancedAdminPage(
                conversationId: widget.conversationId,
                title: title,
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        ListTile(leading: Icon(owner ? Icons.delete_forever_rounded : Icons.logout_rounded), title: Text(owner ? 'حذف کامل گروه' : 'خروج از گروه', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(owner ? 'برای همه حذف می‌شود' : 'فقط شما خارج می‌شوید'), onTap: owner ? deleteGroup : leaveGroup),
      ])),
      if (busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
    ]));
  }
}

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
  bool loading = true, busy = false, admin = false, owner = false;

  String nameOf(String id) => (profiles[id]?['display_name'] ?? profiles[id]?['username'] ?? 'کاربر').toString();
  String avatarOf(String id) => (profiles[id]?['avatar_url'] ?? '').toString();
  void toast(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }

  Future<void> load() async {
    try {
      final g = Map<String, dynamic>.from(await db.from('conversations').select('id,type,title,avatar_url,description,created_by,username,is_public,join_approval,only_admins_can_post,only_admins_can_add,allow_reactions,auto_delete_seconds').eq('id', widget.conversationId).single());
      final ms = List<Map<String, dynamic>>.from(await db.from('conversation_members').select('user_id,role,joined_at').eq('conversation_id', widget.conversationId).order('joined_at'));
      final ids = ms.map((m) => m['user_id'].toString()).toList();
      final ps = ids.isEmpty ? <Map<String, dynamic>>[] : List<Map<String, dynamic>>.from(await db.from('profiles').select('id,display_name,username,avatar_url,is_verified').inFilter('id', ids));
      final uid = db.auth.currentUser?.id;
      if (!mounted) return;
      setState(() { group = g; members = ms; profiles = {for (final p in ps) p['id'].toString(): p}; owner = uid != null && g['created_by']?.toString() == uid; admin = owner || (uid != null && ms.any((m) => m['user_id']?.toString() == uid && ['admin', 'owner'].contains(m['role']))); loading = false; });
    } catch (_) { if (mounted) { setState(() => loading = false); toast('مدیریت گروه بارگذاری نشد.'); } }
  }

  Future<void> addMembers() async {
    if (!admin || busy) return;
    final search = TextEditingController();
    final selected = <String>{};
    try {
      final added = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheet) {
          List<Map<String, dynamic>> results = [];
          bool loadingUsers = false;
          return StatefulBuilder(builder: (sheet, setSheet) {
            Future<void> findUsers(String q) async {
              final term = q.trim();
              if (term.length < 2) { setSheet(() => results = []); return; }
              setSheet(() => loadingUsers = true);
              try {
                final rows = await db.from('profiles').select('id,display_name,username,avatar_url,is_verified').or('display_name.ilike.%$term%,username.ilike.%$term%').limit(30);
                final existing = members.map((m) => m['user_id'].toString()).toSet();
                setSheet(() => results = List<Map<String, dynamic>>.from(rows).where((r) => !existing.contains(r['id'].toString())).toList());
              } catch (_) { setSheet(() => results = []); }
              finally { if (sheet.mounted) setSheet(() => loadingUsers = false); }
            }
            return SafeArea(child: Padding(
              padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.viewInsetsOf(sheet).bottom + 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('افزودن اعضا', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextField(controller: search, autofocus: true, onChanged: findUsers, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'نام یا آیدی کاربر')),
                const SizedBox(height: 8),
                if (loadingUsers) const LinearProgressIndicator(minHeight: 2),
                ConstrainedBox(constraints: const BoxConstraints(maxHeight: 360), child: ListView(shrinkWrap: true, children: results.map((u) {
                  final id = u['id'].toString(); final checked = selected.contains(id); final avatar = (u['avatar_url'] ?? '').toString();
                  return CheckboxListTile(value: checked, onChanged: (_) => setSheet(() => checked ? selected.remove(id) : selected.add(id)),
                    secondary: CircleAvatar(backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null, child: avatar.isEmpty ? const Icon(Icons.person) : null),
                    title: Text((u['display_name'] ?? u['username'] ?? 'کاربر').toString()), subtitle: Text((u['username'] ?? '').toString().isEmpty ? '' : '@${u['username']}'));
                }).toList())),
                const SizedBox(height: 10),
                FilledButton.icon(onPressed: selected.isEmpty ? null : () => Navigator.pop(sheet, selected.toList()), icon: const Icon(Icons.person_add_alt_1_rounded), label: Text(selected.isEmpty ? 'انتخاب اعضا' : 'افزودن ${selected.length} نفر')),
              ]),
            ));
          });
        },
      );
      if (added == null || added.isEmpty) return;
      setState(() => busy = true);
      final count = await db.rpc('add_group_members', params: {'p_conversation_id': widget.conversationId, 'p_user_ids': added});
      toast('${count ?? added.length} عضو به گروه اضافه شد.');
      await load();
    } catch (e) { toast('افزودن عضو ناموفق بود: $e'); }
    finally { search.dispose(); if (mounted) setState(() => busy = false); }
  }

  Future<void> removeMember(String id) async {
    if (!admin || busy || id == group?['created_by']?.toString()) return;
    setState(() => busy = true);
    try { await db.rpc('remove_group_member', params: {'p_conversationId': widget.conversationId, 'p_user_id': id}); toast('عضو از گروه حذف شد.'); await load(); }
    catch (e) { toast('حذف عضو ناموفق بود: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> banMember(String id) async {
    if (!admin || busy || id == group?['created_by']?.toString()) return;
    final c = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: Text('محروم کردن ${nameOf(id)}'), content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(labelText: 'دلیل (اختیاری)')), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('لغو')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('محروم و حذف شود'))])) ?? false;
    final reason = c.text.trim(); c.dispose();
    if (!ok) return;
    setState(() => busy = true);
    try { await db.rpc('ban_group_member', params: {'p_conversation_id': widget.conversationId, 'p_user_id': id, 'p_reason': reason.isEmpty ? null : reason}); toast('عضو محروم و از گروه حذف شد.'); await load(); }
    catch (e) { toast('محروم کردن ناموفق بود: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> setRole(String id, String role) async {
    if (!admin || busy || id == group?['created_by']?.toString()) return;
    setState(() => busy = true);
    try { await db.rpc('set_group_member_role', params: {'p_conversation_id': widget.conversationId, 'p_user_id': id, 'p_role': role}); toast(role == 'admin' ? 'مدیر شد.' : 'نقش به عضو تغییر کرد.'); await load(); }
    catch (e) { toast('تغییر نقش ناموفق بود: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> editInfo() async {
    if (!admin || group == null) return;
    final t = TextEditingController(text: (group!['title'] ?? widget.title).toString());
    final d = TextEditingController(text: (group!['description'] ?? '').toString());
    await showDialog<void>(context: context, builder: (dialog) => AlertDialog(title: const Text('ویرایش پروفایل گروه'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: t, decoration: const InputDecoration(labelText: 'نام گروه')), const SizedBox(height: 10), TextField(controller: d, maxLines: 3, decoration: const InputDecoration(labelText: 'توضیحات'))]), actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('لغو')), FilledButton(onPressed: () { Navigator.pop(dialog); updateSettings(title: t.text.trim(), description: d.text.trim()); }, child: const Text('ذخیره'))]));
    t.dispose(); d.dispose();
  }

  Future<void> updateSettings({String? title, String? description, bool? publicGroup, bool? approval, bool? adminsPost, bool? adminsAdd, bool? reactions}) async {
    if (!admin || group == null || busy) return;
    final g = group!;
    setState(() => busy = true);
    try {
      await db.rpc('update_group_settings', params: {'p_conversation_id': widget.conversationId, 'p_title': title ?? g['title'], 'p_description': description ?? g['description'], 'p_avatar_url': g['avatar_url'], 'p_is_public': publicGroup ?? g['is_public'] ?? false, 'p_username': g['username'], 'p_join_approval': approval ?? g['join_approval'] ?? false, 'p_only_admins_can_post': adminsPost ?? g['only_admins_can_post'] ?? false, 'p_only_admins_can_add': adminsAdd ?? g['only_admins_can_add'] ?? false, 'p_auto_delete_seconds': g['auto_delete_seconds'] ?? 0, 'p_allow_reactions': reactions ?? g['allow_reactions'] ?? true});
      await load();
    } catch (e) { toast('تنظیمات ذخیره نشد: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> deleteGroup() async {
    if (!owner || busy) return;
    final c = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('حذف کامل گروه'), content: TextField(controller: c, decoration: const InputDecoration(labelText: 'بنویسید: حذف گروه')), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('لغو')), FilledButton(onPressed: () => Navigator.pop(d, c.text.trim() == 'حذف گروه'), child: const Text('حذف دائمی'))])) ?? false;
    c.dispose();
    if (!ok) return;
    setState(() => busy = true);
    try { await db.rpc('delete_group', params: {'p_conversation_id': widget.conversationId}); if (mounted) Navigator.pop(context, true); }
    catch (e) { toast('حذف گروه ناموفق بود: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override void initState() { super.initState(); load(); }

  @override Widget build(BuildContext context) {
    if (loading) return Scaffold(appBar: AppBar(title: const Text('مدیریت گروه')), body: const Center(child: CircularProgressIndicator()));
    return Scaffold(appBar: AppBar(title: const Text('مدیریت گروه'), actions: [if (admin) IconButton(onPressed: editInfo, icon: const Icon(Icons.edit_rounded))]), body: ListView(padding: const EdgeInsets.all(12), children: [
      Card(child: ListTile(leading: CircleAvatar(backgroundImage: (group!['avatar_url'] ?? '').toString().isNotEmpty ? NetworkImage(group!['avatar_url'].toString()) : null, child: (group!['avatar_url'] ?? '').toString().isEmpty ? const Icon(Icons.groups) : null), title: Text((group!['title'] ?? widget.title).toString(), style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(owner ? 'مالک گروه' : 'مدیر گروه'))),
      const SizedBox(height: 8),
      const Text('اعضا', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const Text('«حذف از گروه» فقط اخراج است؛ «محروم کردن» اخراج + جلوگیری از عضویت دوباره است.'),
      const SizedBox(height: 8),
      ...members.map((m) {
        final id = m['user_id'].toString(); final isGroupOwner = group!['created_by']?.toString() == id; final role = (m['role'] ?? 'member').toString(); final a = avatarOf(id);
        return Card(margin: const EdgeInsets.symmetric(vertical: 4), child: ListTile(leading: CircleAvatar(backgroundImage: a.isNotEmpty ? NetworkImage(a) : null, child: a.isEmpty ? const Icon(Icons.person) : null), title: Text(nameOf(id)), subtitle: Text(isGroupOwner ? '👑 مالک' : role), trailing: isGroupOwner ? const Icon(Icons.lock_rounded) : PopupMenuButton<String>(onSelected: (v) { if (v == 'remove') removeMember(id); else if (v == 'ban') banMember(id); else if (v == 'admin') setRole(id, 'admin'); else if (v == 'member') setRole(id, 'member'); }, itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.person_remove_rounded), title: Text('حذف از گروه'))), PopupMenuItem(value: 'ban', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.block_rounded), title: Text('محروم کردن'))), PopupMenuItem(value: 'admin', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.admin_panel_settings_rounded), title: Text('مدیر کردن'))), PopupMenuItem(value: 'member', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.person_rounded), title: Text('برداشتن مدیریت')))])));
      }),
      const SizedBox(height: 14),
      Card(child: Column(children: [
        const ListTile(title: Text('تنظیمات گروه', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
        SwitchListTile(title: const Text('گروه عمومی'), value: group!['is_public'] == true, onChanged: admin ? (v) => updateSettings(publicGroup: v) : null),
        SwitchListTile(title: const Text('تأیید درخواست عضویت'), value: group!['join_approval'] == true, onChanged: admin ? (v) => updateSettings(approval: v) : null),
        SwitchListTile(title: const Text('فقط مدیران پیام بفرستند'), value: group!['only_admins_can_post'] == true, onChanged: admin ? (v) => updateSettings(adminsPost: v) : null),
        SwitchListTile(title: const Text('فقط مدیران عضو اضافه کنند'), value: group!['only_admins_can_add'] == true, onChanged: admin ? (v) => updateSettings(adminsAdd: v) : null),
        SwitchListTile(title: const Text('واکنش به پیام‌ها'), value: group!['allow_reactions'] != false, onChanged: admin ? (v) => updateSettings(reactions: v) : null),
      ])),
      if (admin) Card(child: ListTile(leading: const Icon(Icons.shield_rounded), title: const Text('محرومیت و حذف پیام'), subtitle: const Text('فهرست محروم‌ها و حذف پیام برای همه'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupModerationPage(conversationId: widget.conversationId, title: widget.title))))),
      if (owner) Card(child: ListTile(leading: const Icon(Icons.dashboard_customize_rounded), title: const Text('مدیریت پیشرفته'), subtitle: const Text('درخواست‌های عضویت، محروم‌ها، محدودیت‌ها، سنجاق پیام و اختیارات مدیران'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupAdvancedAdminPage(conversationId: widget.conversationId, title: widget.title))))),
      if (owner) Card(child: ListTile(leading: const Icon(Icons.delete_forever_rounded), title: const Text('حذف کامل گروه', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: const Text('این گزینه هیچ ارتباطی با حذف/محروم کردن اعضا ندارد.'), onTap: deleteGroup)),
      if (busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
    ]));
  }
}
