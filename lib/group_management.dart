import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'group_moderation.dart';
import 'group_advanced_admin.dart';
import 'channel_management.dart';
import 'polish_widgets.dart';

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
  List<Map<String, dynamic>> auditEvents = [];
  Map<String, Map<String, dynamic>> profiles = {};
  int onlineCount = 0;
  bool loading = true, admin = false, owner = false, busy = false, canAddMembers = false, canEditGroup = false;

  String nameOf(String id) => (profiles[id]?['display_name'] ?? profiles[id]?['username'] ?? 'کاربر').toString();
  String avatarOf(String id) => (profiles[id]?['avatar_url'] ?? '').toString();
  void toast(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }

  String auditActionLabel(String action) {
    const labels = <String, String>{
      'member_added': 'عضو توسط مدیر اضافه شد',
      'joined_by_link': 'عضویت با لینک دعوت',
      'join_requested_by_link': 'درخواست عضویت با لینک',
      'joined_by_public_username': 'عضویت از طریق نام گروه',
      'join_requested_by_public_username': 'درخواست عضویت از نام گروه',
      'joined_after_approval': 'درخواست عضویت تأیید شد',
      'member_removed': 'عضو از گروه حذف شد',
      'member_banned': 'عضو محروم شد',
      'member_unbanned': 'محرومیت عضو برداشته شد',
      'admin_promoted': 'عضو مدیر شد',
      'admin_demoted': 'دسترسی مدیریت برداشته شد',
      'group_updated': 'تنظیمات گروه تغییر کرد',
      'settings_updated': 'تنظیمات گروه یا کانال تغییر کرد',
      'message_pinned': 'پیام سنجاق شد',
      'message_unpinned': 'سنجاق پیام برداشته شد',
      'join_request_rejected': 'درخواست عضویت رد شد',
    };
    return labels[action] ?? action.replaceAll('_', ' ');
  }

  Future<void> load() async {
    try {
      final g = Map<String, dynamic>.from(await db.from('conversations').select('id,type,title,avatar_url,description,created_by,username,is_public,join_approval,only_admins_can_post,only_admins_can_add,allow_reactions,auto_delete_seconds').eq('id', widget.conversationId).single());
      final ms = List<Map<String, dynamic>>.from(await db.from('conversation_members').select('user_id,role,joined_at').eq('conversation_id', widget.conversationId).order('joined_at'));
      List<Map<String, dynamic>> events = [];
      try { events = List<Map<String, dynamic>>.from(await db.from('group_audit_logs').select('id,actor_id,action,target_user_id,details,created_at').eq('conversation_id', widget.conversationId).order('created_at', ascending: false).limit(100)); } catch (_) {}
      final ids = ms.map((m) => m['user_id'].toString()).toSet();
      for (final event in events) { if (event['actor_id'] != null) ids.add(event['actor_id'].toString()); if (event['target_user_id'] != null) ids.add(event['target_user_id'].toString()); }
      final idList = ids.toList();
      final ps = idList.isEmpty ? <Map<String, dynamic>>[] : List<Map<String, dynamic>>.from(await db.from('profiles').select('id,display_name,username,avatar_url,is_verified,is_online,last_seen').inFilter('id', idList));
      final uid = db.auth.currentUser?.id;
      final isOwner = uid != null && g['created_by']?.toString() == uid;
      final isAdmin = isOwner || (uid != null && ms.any((m) => m['user_id']?.toString() == uid && ['admin', 'owner'].contains(m['role'])));
      Map<String,dynamic> permissions = {};
      if (isAdmin && !isOwner && uid != null) {
        try {
          final row = await db.from('group_admin_permissions').select('can_add_members,can_edit_group').eq('conversation_id', widget.conversationId).eq('user_id', uid).maybeSingle();
          if (row != null) permissions = Map<String,dynamic>.from(row);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        group = g; members = ms; auditEvents = events;
        final memberIds = ms.map((m) => m['user_id'].toString()).toSet();
        onlineCount = ps.where((p) => memberIds.contains(p['id'].toString()) && p['is_online'] == true).length;
        profiles = {for (final p in ps) p['id'].toString(): p};
        owner = isOwner;
        admin = isAdmin;
        canAddMembers = isOwner || (isAdmin && permissions['can_add_members'] != false) || g['only_admins_can_add'] != true;
        canEditGroup = isOwner || permissions['can_edit_group'] == true;
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
      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('انصراف')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(d).colorScheme.error, foregroundColor: Theme.of(d).colorScheme.onError), onPressed: () => Navigator.pop(d, true), child: const Text('خروج'))],
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
      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('انصراف')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(d).colorScheme.error, foregroundColor: Theme.of(d).colorScheme.onError), onPressed: () => Navigator.pop(d, c.text.trim() == 'حذف گروه'), child: const Text('حذف دائمی'))],
    )) ?? false;
    c.dispose();
    if (!ok) return;
    setState(() => busy = true);
    try { await db.rpc('delete_group', params: {'p_conversation_id': widget.conversationId}); if (mounted) Navigator.pop(context, true); }
    catch (e) { toast('حذف گروه ناموفق بود: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> changeGroupAvatar() async {
    if (!canEditGroup || busy) return;
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

  Future<void> addMembersFromContacts() async {
    if (!canAddMembers || busy) return;
    final uid = db.auth.currentUser?.id;
    if (uid == null) { toast('ابتدا وارد حساب شوید.'); return; }
    setState(() => busy = true);
    final search = TextEditingController();
    final selected = <String>{};
    var searchRequest = 0;
    try {
      final contactRows = await db.from('contacts').select('contact_id').eq('user_id', uid);
      final contactIds = (contactRows as List)
          .map((row) => row['contact_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty && id != uid)
          .toSet().toList();
      final currentIds = members.map((m) => m['user_id'].toString()).toSet();
      final eligibleIds = contactIds.where((id) => !currentIds.contains(id)).toList();
      final contacts = eligibleIds.isEmpty ? <Map<String, dynamic>>[] :
        List<Map<String, dynamic>>.from(await db.from('profiles')
          .select('id,display_name,username,avatar_url')
          .inFilter('id', eligibleIds));
      contacts.sort((a,b) => (a['display_name'] ?? a['username'] ?? '').toString().toLowerCase()
        .compareTo((b['display_name'] ?? b['username'] ?? '').toString().toLowerCase()));
      final picked = await showModalBottomSheet<List<String>>(
        context: context, isScrollControlled: true, showDragHandle: true,
        builder: (sheet) {
          var visible = List<Map<String,dynamic>>.from(contacts);
          return StatefulBuilder(builder: (sheet, setSheet) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.viewInsetsOf(sheet).bottom + 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('افزودن از مخاطبین', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('مخاطبین نمایش داده می‌شوند؛ با جستجو می‌توانید کاربران ثبت‌نام‌شده را هم پیدا کنید.', textAlign: TextAlign.center),
                const SizedBox(height: 10),
                TextField(controller: search, autofocus: true, onChanged: (q) async {
                  final requestId = ++searchRequest;
                  final term = q.trim();
                  if (term.isEmpty) {
                    setSheet(() => visible = List<Map<String, dynamic>>.from(contacts));
                    return;
                  }
                  try {
                    final raw = await db.rpc('search_profiles', params: {'search_text': term});
                    final currentIds = members.map((m) => m['user_id'].toString()).toSet();
                    final uid = db.auth.currentUser?.id;
                    final matches = List<Map<String, dynamic>>.from(raw as List)
                      .where((p) => p['id'] != null &&
                        p['id'].toString() != uid &&
                        !currentIds.contains(p['id'].toString()))
                      .toList();
                    if (sheet.mounted && requestId == searchRequest) setSheet(() => visible = matches);
                  } catch (_) {
                    final lower = term.toLowerCase();
                    if (sheet.mounted && requestId == searchRequest) setSheet(() => visible = contacts.where((p) =>
                      (p['display_name'] ?? '').toString().toLowerCase().contains(lower) ||
                      (p['username'] ?? '').toString().toLowerCase().contains(lower)).toList());
                  }
                }, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'جستجوی مخاطب یا نام کاربری')),
                if (contacts.isEmpty && search.text.trim().isEmpty) const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('مخاطب جدیدی برای افزودن نیست. با جستجو می‌توانید کاربران را پیدا کنید.', textAlign: TextAlign.center)),
                if (visible.isEmpty && search.text.trim().isNotEmpty) const Padding(
                  padding: EdgeInsets.all(16), child: Text('کاربری با این نام یا آیدی پیدا نشد.')),
                ConstrainedBox(constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView(shrinkWrap: true, children: visible.map((p) {
                    final id = p['id'].toString(); final checked = selected.contains(id);
                    final url = (p['avatar_url'] ?? '').toString();
                    return CheckboxListTile(value: checked,
                      onChanged: (_) => setSheet(() => checked ? selected.remove(id) : selected.add(id)),
                      secondary: CircleAvatar(backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
                        child: url.isEmpty ? const Icon(Icons.person) : null),
                      title: Text((p['display_name'] ?? p['username'] ?? 'کاربر').toString()),
                      subtitle: (p['username'] ?? '').toString().isEmpty ? null : Text('@${p['username']}'));
                  }).toList())),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  onPressed: selected.isEmpty ? null : () => Navigator.pop(sheet, selected.toList()),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(selected.isEmpty ? 'انتخاب مخاطب' : 'افزودن ${selected.length} نفر'))),
              ]),
            )));
        });
      if (picked == null || picked.isEmpty) return;
      await db.rpc('add_group_members', params: {'p_conversation_id': widget.conversationId, 'p_user_ids': picked});
      await load();
      final now = members.map((m) => m['user_id'].toString()).toSet();
      final count = picked.where(now.contains).length;
      toast(count > 0 ? '$count عضو به گروه اضافه شد.' : 'افزودن عضو از سرور تأیید نشد؛ مجوزها را بررسی کنید.');
    } catch (e) {
      toast('افزودن عضو ناموفق بود: $e');
    } finally {
      search.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openManagement() async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => GroupManagementPage(conversationId: widget.conversationId, title: widget.title)));
    if (changed == true) await load();
  }

  @override void initState() { super.initState(); load(); }

  @override Widget build(BuildContext context) {
    if (loading) return Scaffold(appBar: AppBar(title: const Text('پروفایل گروه')), body: const AppSkeletonList(count: 6));
    final g = group!; final title = (g['title'] ?? widget.title).toString(); final desc = (g['description'] ?? '').toString().trim(); final image = (g['avatar_url'] ?? '').toString();
    return Scaffold(appBar: AppBar(title: const Text('پروفایل گروه')), body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [
        GestureDetector(onTap: canEditGroup ? changeGroupAvatar : null, child: Stack(alignment: Alignment.bottomRight, children: [CircleAvatar(radius: 54, backgroundImage: image.isNotEmpty ? NetworkImage(image) : null, child: image.isEmpty ? const Icon(Icons.groups_rounded, size: 50) : null), if (canEditGroup) Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18))])),
        const SizedBox(height: 12), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        if ((g['username'] ?? '').toString().trim().isNotEmpty) Text('@${g['username']}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8), Text(desc.isEmpty ? 'بدون توضیحات' : desc, textAlign: TextAlign.center),
        const SizedBox(height: 10), Text('${members.length} عضو • ${onlineCount} فعال', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4), Text('فعال یعنی وضعیت آنلاین ثبت‌شده در حساب کاربر.', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]))),
      const SizedBox(height: 12),
      Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.people_alt_rounded), title: const Text('اعضای گروه'), subtitle: Text('${members.length} عضو • ${onlineCount} فعال'), trailing: const Icon(Icons.chevron_left), onTap: () => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => ListView(padding: const EdgeInsets.all(16), children: [Text('اعضای گروه • ${members.length} نفر • ${onlineCount} فعال', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 8), ...members.map((m) { final id = m['user_id'].toString(); final a = avatarOf(id); final o = g['created_by']?.toString() == id; return ListTile(leading: CircleAvatar(backgroundImage: a.isNotEmpty ? NetworkImage(a) : null, child: a.isEmpty ? const Icon(Icons.person) : null), title: Text(nameOf(id)), subtitle: Text(() {
            final joined = DateTime.tryParse('${m['joined_at'] ?? ''}')?.toLocal();
            final date = joined == null ? '' : '${joined.year}/${joined.month.toString().padLeft(2, '0')}/${joined.day.toString().padLeft(2, '0')} ${joined.hour.toString().padLeft(2, '0')}:${joined.minute.toString().padLeft(2, '0')}';
            final history = auditEvents.where((e) => e['target_user_id']?.toString() == id && ['member_added','joined_by_link','join_requested_by_link','joined_by_public_username','join_requested_by_public_username','joined_after_approval'].contains(e['action'])).toList();
            history.sort((a,b) => (DateTime.tryParse('${b['created_at'] ?? ''}') ?? DateTime(1970)).compareTo(DateTime.tryParse('${a['created_at'] ?? ''}') ?? DateTime(1970)));
            final event = history.isEmpty ? null : history.first;
            final source = event == null ? '' : event['action'] == 'joined_by_link' ? ' • از طریق لینک دعوت' : event['action'] == 'join_requested_by_link' ? ' • درخواست از طریق لینک' : event['action'] == 'joined_by_public_username' ? ' • از طریق نام کاربری عمومی' : event['action'] == 'join_requested_by_public_username' ? ' • درخواست از نام کاربری عمومی' : event['action'] == 'joined_after_approval' ? ' • عضویت پس از تأیید مدیر' : ' • افزوده‌شده توسط ${nameOf((event['actor_id'] ?? '').toString())}';
            return '${o ? '👑 مالک' : (m['role'] ?? 'عضو').toString()}${date.isEmpty ? '' : ' • عضویت: $date'}$source';
          }())); })]))),
        if (canAddMembers) ListTile(leading: const Icon(Icons.person_add_alt_1_rounded), title: const Text('افزودن اعضا از مخاطبین'), subtitle: const Text('انتخاب مخاطب و افزودن مستقیم به گروه'), trailing: const Icon(Icons.chevron_left), onTap: addMembersFromContacts),
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
      if (admin && auditEvents.isNotEmpty) ...[
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.history_rounded), const SizedBox(width: 8), const Expanded(child: Text('فعالیت‌های اخیر گروه', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), Text('${auditEvents.length}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))]),
          const SizedBox(height: 8),
          ...auditEvents.take(8).map((e) {
            final action = (e['action'] ?? '').toString();
            final actor = (e['actor_id'] ?? '').toString();
            final target = (e['target_user_id'] ?? '').toString();
            final at = DateTime.tryParse('${e['created_at'] ?? ''}')?.toLocal();
            final time = at == null ? '' : '${at.month.toString().padLeft(2, '0')}/${at.day.toString().padLeft(2, '0')} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
            final details = (e['details'] ?? '').toString().trim();
            return ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const CircleAvatar(radius: 17, child: Icon(Icons.bolt_rounded, size: 17)), title: Text(auditActionLabel(action), style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${actor.isEmpty ? 'سیستم' : nameOf(actor)}${target.isEmpty ? '' : ' · عضو: ${nameOf(target)}'}${details.isEmpty ? '' : '\\n$details'}'), trailing: Text(time, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)));
          }),
        ]))),
      ],
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
  bool loading = true, busy = false, admin = false, owner = false, canEditGroup = false, canRemoveMembers = false, canAddMembers = false, canDeleteMessages = false;
  String memberQuery = '';

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
      final isOwner = uid != null && g['created_by']?.toString() == uid;
      final isAdmin = isOwner || (uid != null && ms.any((m) => m['user_id']?.toString() == uid && ['admin', 'owner'].contains(m['role'])));
      Map<String,dynamic> permissions = {};
      if (isAdmin && !isOwner && uid != null) {
        try {
          final row = await db.from('group_admin_permissions').select('can_add_members,can_remove_members,can_edit_group,can_delete_messages').eq('conversation_id', widget.conversationId).eq('user_id', uid).maybeSingle();
          if (row != null) permissions = Map<String,dynamic>.from(row);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        group = g; members = ms; profiles = {for (final p in ps) p['id'].toString(): p};
        owner = isOwner; admin = isAdmin;
        canAddMembers = isOwner || (isAdmin && permissions['can_add_members'] != false);
        canRemoveMembers = isOwner || permissions['can_remove_members'] == true;
        canDeleteMessages = isOwner || permissions['can_delete_messages'] == true;
        canEditGroup = isOwner || permissions['can_edit_group'] == true;
        loading = false;
      });
    } catch (_) { if (mounted) { setState(() => loading = false); toast('مدیریت گروه بارگذاری نشد.'); } }
  }

  Future<void> addMembers() async {
    if (!canAddMembers || busy) return;
    final search = TextEditingController();
    final selected = <String>{};
    try {
      // Group invites must come from the user's saved contacts, not an unrestricted
      // directory of every profile in the database.
      final uid = db.auth.currentUser?.id;
      if (uid == null) throw Exception('برای افزودن مخاطب ابتدا وارد حساب شوید.');
      final contactRows = await db.from('contacts').select('contact_id').eq('user_id', uid);
      final contactIds = (contactRows as List)
          .map((row) => row['contact_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty && id != uid)
          .toSet()
          .toList();
      final existing = members.map((m) => m['user_id'].toString()).toSet();
      final eligibleIds = contactIds.where((id) => !existing.contains(id)).toList();
      final contactProfiles = eligibleIds.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(await db
              .from('profiles')
              .select('id,display_name,username,avatar_url,is_verified')
              .inFilter('id', eligibleIds));
      contactProfiles.sort((a, b) =>
          (a['display_name'] ?? a['username'] ?? '').toString().toLowerCase()
              .compareTo((b['display_name'] ?? b['username'] ?? '').toString().toLowerCase()));

      final added = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheet) {
          List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(contactProfiles);
          return StatefulBuilder(builder: (sheet, setSheet) {
            void filterContacts(String q) {
              final term = q.trim().toLowerCase();
              setSheet(() {
                results = contactProfiles.where((user) {
                  if (term.isEmpty) return true;
                  final name = (user['display_name'] ?? '').toString().toLowerCase();
                  final username = (user['username'] ?? '').toString().toLowerCase();
                  return name.contains(term) || username.contains(term);
                }).toList();
              });
            }

            return SafeArea(child: Padding(
              padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.viewInsetsOf(sheet).bottom + 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('افزودن از مخاطبین', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text('فقط مخاطب‌هایی نمایش داده می‌شوند که قبلاً ذخیره کرده‌اید و هنوز عضو این گروه نیستند.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Theme.of(sheet).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                TextField(
                  controller: search,
                  autofocus: true,
                  onChanged: filterContacts,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'جستجو در مخاطبین'),
                ),
                const SizedBox(height: 8),
                if (contactProfiles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('مخاطبِ واجد شرایطی ندارید. ابتدا کاربر را از بخش «مخاطبین» اضافه کنید.',
                        textAlign: TextAlign.center),
                  )
                else if (results.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('در مخاطبین شما نتیجه‌ای پیدا نشد.', textAlign: TextAlign.center),
                  ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView(shrinkWrap: true, children: results.map((user) {
                    final id = user['id'].toString();
                    final checked = selected.contains(id);
                    final avatar = (user['avatar_url'] ?? '').toString();
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (_) => setSheet(() => checked ? selected.remove(id) : selected.add(id)),
                      secondary: CircleAvatar(
                        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty ? const Icon(Icons.person) : null,
                      ),
                      title: Text((user['display_name'] ?? user['username'] ?? 'کاربر').toString()),
                      subtitle: (user['username'] ?? '').toString().isEmpty
                          ? null
                          : Text('@${user['username']}'),
                    );
                  }).toList()),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: selected.isEmpty ? null : () => Navigator.pop(sheet, selected.toList()),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(selected.isEmpty ? 'انتخاب مخاطب' : 'افزودن ${selected.length} نفر'),
                ),
              ]),
            ));
          });
        },
      );
      if (added == null || added.isEmpty) return;
      setState(() => busy = true);
      final before = members.map((m) => m['user_id'].toString()).toSet();
      try {
        await db.rpc('add_group_members', params: {
          'p_conversation_id': widget.conversationId,
          'p_user_ids': added,
        });
        await load();
        final after = members.map((m) => m['user_id'].toString()).toSet();
        final count = after.difference(before).length;
        if (count <= 0) {
          toast('عضوی اضافه نشد. دسترسی مدیر و تنظیمات سرور را بررسی کنید.');
          return;
        }
        toast('$count عضو به گروه اضافه شد.');
      } on PostgrestException catch (e) {
        final code = e.code ?? '';
        final message = e.message.toString();
        if (message.contains('not_group_admin') || code == '42501') {
          throw Exception('دسترسی مدیر برای افزودن عضو تأیید نشد.');
        }
        if (message.contains('not_group')) {
          throw Exception('این گفتگو گروه نیست.');
        }
        if (message.contains('not_authenticated')) {
          throw Exception('نشست حساب کاربری منقضی شده است؛ دوباره وارد شوید.');
        }
        throw Exception('سرور افزودن عضو را رد کرد: ${e.message}');
      }
    } catch (e) {
      toast('افزودن عضو ناموفق بود: $e');
    } finally {
      search.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> removeMember(String id) async {
    if (!canRemoveMembers || busy || id == group?['created_by']?.toString()) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('حذف عضو از گروه'),
        content: Text('آیا ${nameOf(id)} را از این گروه حذف کنید؟ این کار به‌تنهایی او را برای همیشه محروم نمی‌کند.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('انصراف')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(dialog).colorScheme.error, foregroundColor: Theme.of(dialog).colorScheme.onError),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('حذف عضو'),
          ),
        ],
      ),
    ) ?? false;
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      final removed = await db.rpc('remove_group_member', params: {'p_conversation_id': widget.conversationId, 'p_user_id': id});
      if (removed != true) {
        toast('این کاربر دیگر عضو گروه نیست یا حذف نشد.');
        await load();
        return;
      }
      await load();
      toast('عضو از گروه حذف شد.');
    } catch (e) {
      toast('حذف عضو ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> banMember(String id) async {
    if (!canRemoveMembers || busy || id == group?['created_by']?.toString()) return;
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
    if (!owner || busy || id == group?['created_by']?.toString()) return;
    final promoting = role == 'admin';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(promoting ? 'تعیین مدیر گروه' : 'لغو مدیریت'),
        content: Text(promoting
          ? '${nameOf(id)} را مدیر گروه می‌کنید؟ دسترسی‌های مدیر را بعداً از بخش «مدیریت پیشرفته» تنظیم کنید.'
          : 'مدیریت ${nameOf(id)} لغو و نقش او به عضو عادی تغییر داده شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(promoting ? 'مدیر کردن' : 'لغو مدیریت')),
        ],
      ),
    ) ?? false;
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      await db.rpc('set_group_member_role', params: {'p_conversation_id': widget.conversationId, 'p_user_id': id, 'p_role': role});
      await load();
      toast(promoting ? 'نقش مدیر برای کاربر ثبت شد.' : 'مدیریت کاربر لغو شد.');
    } catch (e) {
      toast('تغییر نقش ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changeGroupAvatar() async {
    if (!canEditGroup || group == null || busy) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(child: Wrap(children: [
        ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('انتخاب از گالری'), onTap: () => Navigator.pop(sheet, ImageSource.gallery)),
        ListTile(leading: const Icon(Icons.camera_alt_rounded), title: const Text('گرفتن عکس با دوربین'), onTap: () => Navigator.pop(sheet, ImageSource.camera)),
      ])),
    );
    if (source == null || !mounted) return;
    final file = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1200);
    if (file == null || !mounted) return;
    setState(() => busy = true);
    try {
      final bytes = await file.readAsBytes();
      final path = 'groups/${widget.conversationId}/avatar-${DateTime.now().millisecondsSinceEpoch}.jpg';
      await db.storage.from('avatars').uploadBinary(
        path, bytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      final url = db.storage.from('avatars').getPublicUrl(path);
      final g = group!;
      await db.rpc('update_group_settings', params: {
        'p_conversation_id': widget.conversationId,
        'p_title': g['title'],
        'p_description': g['description'],
        'p_avatar_url': url,
        'p_is_public': g['is_public'] ?? false,
        'p_username': g['username'],
        'p_join_approval': g['join_approval'] ?? false,
        'p_only_admins_can_post': g['only_admins_can_post'] ?? false,
        'p_only_admins_can_add': g['only_admins_can_add'] ?? false,
        'p_auto_delete_seconds': g['auto_delete_seconds'] ?? 0,
        'p_allow_reactions': g['allow_reactions'] ?? true,
      });
      await load();
      toast('عکس گروه تغییر کرد.');
    } catch (e) {
      toast('تغییر عکس گروه ناموفق بود. دسترسی ذخیره‌سازی یا مجوز ویرایش گروه را بررسی کنید: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editInfo() async {
    if (!canEditGroup || group == null) return;
    final t = TextEditingController(text: (group!['title'] ?? widget.title).toString());
    final u = TextEditingController(text: (group!['username'] ?? '').toString());
    final d = TextEditingController(text: (group!['description'] ?? '').toString());
    await showDialog<void>(context: context, builder: (dialog) => AlertDialog(title: const Text('ویرایش پروفایل گروه'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: t, decoration: const InputDecoration(labelText: 'نام گروه')), const SizedBox(height: 10), TextField(controller: u, autocorrect: false, decoration: const InputDecoration(labelText: 'نام کاربری عمومی', prefixText: '@', helperText: 'برای عمومی کردن گروه لازم است؛ فقط حروف انگلیسی، عدد و زیرخط.')), const SizedBox(height: 10), TextField(controller: d, maxLines: 3, decoration: const InputDecoration(labelText: 'توضیحات'))])), actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('لغو')), FilledButton(onPressed: () { Navigator.pop(dialog); updateSettings(title: t.text.trim(), description: d.text.trim(), username: u.text.trim().replaceFirst('@', '')); }, child: const Text('ذخیره'))]));
    t.dispose(); u.dispose(); d.dispose();
  }

  Future<void> changePublicVisibility(bool value) async {
    if (!value) { await updateSettings(publicGroup: false); return; }
    final current = (group?['username'] ?? '').toString().trim();
    if (current.isNotEmpty) { await updateSettings(publicGroup: true); return; }
    final controller = TextEditingController();
    final username = await showDialog<String>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('نام کاربری گروه عمومی'),
      content: TextField(controller: controller, autofocus: true, autocorrect: false, decoration: const InputDecoration(prefixText: '@', hintText: 'arad_group', helperText: 'نام کوتاه و یکتا انتخاب کنید.')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('لغو')), FilledButton(onPressed: () => Navigator.pop(dialog, controller.text.trim().replaceFirst('@', '')), child: const Text('عمومی کردن'))],
    ));
    controller.dispose();
    if (username == null || username.trim().isEmpty) return;
    if (!RegExp(r'^[a-zA-Z0-9_]{3,32}$').hasMatch(username)) { toast('نام کاربری باید ۳ تا ۳۲ نویسه و شامل حروف انگلیسی، عدد یا زیرخط باشد.'); return; }
    await updateSettings(publicGroup: true, username: username.toLowerCase());
  }

  String autoDeleteLabel(int seconds) {
    if (seconds <= 0) return 'خاموش';
    if (seconds < 604800) return 'پس از ${seconds ~/ 86400} روز';
    if (seconds < 2592000) return 'پس از ${seconds ~/ 604800} هفته';
    return 'پس از ${seconds ~/ 2592000} ماه';
  }

  Future<void> chooseAutoDelete() async {
    if (!canEditGroup || busy || group == null) return;
    final current = (group!['auto_delete_seconds'] as num?)?.toInt() ?? 0;
    const options = <int>[0, 86400, 604800, 2592000];
    final chosen = await showDialog<int>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('حذف خودکار پیام‌ها'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('زمان نگهداری پیام‌های گروه را انتخاب کنید. خاموش یعنی پیام‌ها طبق این تنظیم حذف خودکار نمی‌شوند.'),
              const SizedBox(height: 8),
              ...options.map((seconds) => RadioListTile<int>(
                value: seconds,
                groupValue: current,
                title: Text(autoDeleteLabel(seconds)),
                onChanged: (value) => Navigator.pop(dialog, value),
                contentPadding: EdgeInsets.zero,
              )),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('انصراف'))],
      ),
    );
    if (chosen != null && chosen != current) {
      await updateSettings(autoDeleteSeconds: chosen);
    }
  }

  Future<void> updateSettings({String? title, String? description, String? username, bool? publicGroup, bool? approval, bool? adminsPost, bool? adminsAdd, bool? reactions, int? autoDeleteSeconds}) async {
    if (!canEditGroup || group == null || busy) return;
    final g = group!;
    setState(() => busy = true);
    try {
      await db.rpc('update_group_settings', params: {
        'p_conversation_id': widget.conversationId,
        'p_title': title ?? g['title'],
        'p_description': description ?? g['description'],
        'p_avatar_url': g['avatar_url'],
        'p_is_public': publicGroup ?? g['is_public'] ?? false,
        'p_username': username ?? g['username'],
        'p_join_approval': approval ?? g['join_approval'] ?? false,
        'p_only_admins_can_post': adminsPost ?? g['only_admins_can_post'] ?? false,
        'p_only_admins_can_add': adminsAdd ?? g['only_admins_can_add'] ?? false,
        'p_auto_delete_seconds': autoDeleteSeconds ?? g['auto_delete_seconds'] ?? 0,
        'p_allow_reactions': reactions ?? g['allow_reactions'] ?? true,
      });
      await load();
      toast('تنظیمات گروه ذخیره شد.');
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
    if (loading) return Scaffold(appBar: AppBar(title: const Text('مدیریت گروه')), body: const AppSkeletonList(count: 6));
    if (!admin) return Scaffold(
      appBar: AppBar(title: const Text('مدیریت گروه')),
      body: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline_rounded, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          const Text('این بخش فقط برای مدیران گروه قابل دسترسی است.', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: load, icon: const Icon(Icons.refresh_rounded), label: const Text('بررسی دوباره')),
        ]),
      )),
    );
    return Scaffold(appBar: AppBar(title: const Text('مدیریت گروه'), actions: [if (canEditGroup) IconButton(tooltip: 'تغییر عکس گروه', onPressed: busy ? null : changeGroupAvatar, icon: const Icon(Icons.add_a_photo_rounded)), if (canEditGroup) IconButton(tooltip: 'ویرایش نام و توضیحات', onPressed: busy ? null : editInfo, icon: const Icon(Icons.edit_rounded))]), body: ListView(padding: const EdgeInsets.all(12), children: [
      Card(child: ListTile(leading: CircleAvatar(backgroundImage: (group!['avatar_url'] ?? '').toString().isNotEmpty ? NetworkImage(group!['avatar_url'].toString()) : null, child: (group!['avatar_url'] ?? '').toString().isEmpty ? const Icon(Icons.groups) : null), title: Text((group!['title'] ?? widget.title).toString(), style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(owner ? 'مالک گروه' : 'مدیر گروه'))),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('مدیریت اعضا', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${members.length} عضو • ${members.where((m) => (m['role'] ?? 'member').toString() == 'admin').length} مدیر',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])),
              CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(Icons.groups_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer)),
            ]),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => memberQuery = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'جستجوی نام یا نام کاربری عضو',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: memberQuery.isEmpty ? null : IconButton(
                  tooltip: 'پاک کردن جستجو',
                  onPressed: () => setState(() => memberQuery = ''),
                  icon: const Icon(Icons.close_rounded)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
              ),
            ),
            const SizedBox(height: 8),
            Text('«حذف از گروه» فقط اخراج است؛ «محروم کردن» از عضویت دوباره جلوگیری می‌کند.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      if (members.where((m) {
        if (memberQuery.isEmpty) return true;
        final id = m['user_id'].toString();
        final name = nameOf(id).toLowerCase();
        final username = (profiles[id]?['username'] ?? '').toString().toLowerCase();
        final role = (m['role'] ?? 'member').toString().toLowerCase();
        final roleLabel = role == 'owner' || group!['created_by']?.toString() == id
            ? 'مالک owner'
            : role == 'admin' ? 'مدیر admin' : 'عضو member';
        return name.contains(memberQuery) || username.contains(memberQuery) ||
          role.contains(memberQuery) || roleLabel.contains(memberQuery);
      }).isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          child: Column(children: [
            Icon(Icons.person_search_rounded, size: 38, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(memberQuery.isEmpty ? 'هنوز عضوی در گروه نیست.' : 'عضوی با این نام، آیدی یا نقش پیدا نشد.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      ...members.where((m) {
        if (memberQuery.isEmpty) return true;
        final id = m['user_id'].toString();
        final name = nameOf(id).toLowerCase();
        final username = (profiles[id]?['username'] ?? '').toString().toLowerCase();
        final role = (m['role'] ?? 'member').toString().toLowerCase();
        final roleLabel = role == 'owner' || group!['created_by']?.toString() == id
            ? 'مالک owner'
            : role == 'admin' ? 'مدیر admin' : 'عضو member';
        return name.contains(memberQuery) || username.contains(memberQuery) ||
          role.contains(memberQuery) || roleLabel.contains(memberQuery);
      }).map((m) {
        final id = m['user_id'].toString(); final isGroupOwner = group!['created_by']?.toString() == id; final role = (m['role'] ?? 'member').toString(); final a = avatarOf(id);
        return Card(margin: const EdgeInsets.symmetric(vertical: 4), child: ListTile(leading: CircleAvatar(backgroundImage: a.isNotEmpty ? NetworkImage(a) : null, child: a.isEmpty ? const Icon(Icons.person) : null), title: Text(nameOf(id)), subtitle: Text(isGroupOwner ? '👑 مالک' : role), trailing: isGroupOwner ? const Icon(Icons.lock_rounded) : ((canRemoveMembers || owner) ? PopupMenuButton<String>(onSelected: (v) { if (v == 'remove') removeMember(id); else if (v == 'ban') banMember(id); else if (v == 'admin') setRole(id, 'admin'); else if (v == 'member') setRole(id, 'member'); }, itemBuilder: (_) => <PopupMenuEntry<String>>[const PopupMenuItem(value: 'remove', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.person_remove_rounded), title: Text('حذف از گروه'))), const PopupMenuItem(value: 'ban', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.block_rounded), title: Text('محروم کردن'))), if (owner) const PopupMenuItem(value: 'admin', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.admin_panel_settings_rounded), title: Text('مدیر کردن'))), if (owner) const PopupMenuItem(value: 'member', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.person_rounded), title: Text('برداشتن مدیریت')))]) : null)));
      }),
      const SizedBox(height: 14),
      Card(child: Column(children: [
        const ListTile(title: Text('تنظیمات گروه', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
        SwitchListTile(title: const Text('گروه عمومی'), subtitle: Text((group!['username'] ?? '').toString().isEmpty ? 'برای فعال‌سازی، نام کاربری یکتا تعیین کنید.' : '@${group!['username']}'), value: group!['is_public'] == true, onChanged: canEditGroup ? changePublicVisibility : null),
        SwitchListTile(title: const Text('تأیید درخواست عضویت'), value: group!['join_approval'] == true, onChanged: canEditGroup ? (v) => updateSettings(approval: v) : null),
        SwitchListTile(title: const Text('فقط مدیران پیام بفرستند'), value: group!['only_admins_can_post'] == true, onChanged: canEditGroup ? (v) => updateSettings(adminsPost: v) : null),
        SwitchListTile(
          secondary: const Icon(Icons.group_add_rounded),
          title: const Text('فقط مدیران عضو اضافه کنند'),
          subtitle: const Text('در حالت خاموش، اعضا هم می‌توانند افراد را اضافه کنند.'),
          value: group!['only_admins_can_add'] == true,
          onChanged: canEditGroup ? (v) => updateSettings(adminsAdd: v) : null,
        ),
        ListTile(
          leading: const Icon(Icons.auto_delete_rounded),
          title: const Text('حذف خودکار پیام‌ها'),
          subtitle: Text(autoDeleteLabel((group!['auto_delete_seconds'] as num?)?.toInt() ?? 0)),
          trailing: const Icon(Icons.chevron_left_rounded),
          enabled: canEditGroup && !busy,
          onTap: canEditGroup && !busy ? chooseAutoDelete : null,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.emoji_emotions_outlined),
          title: const Text('واکنش به پیام‌ها'),
          subtitle: const Text('فعال یا غیرفعال کردن واکنش‌های ایموجی در گروه.'),
          value: group!['allow_reactions'] != false,
          onChanged: canEditGroup ? (v) => updateSettings(reactions: v) : null,
        ),
      ])),
      if (canRemoveMembers || canDeleteMessages || owner) Card(child: ListTile(leading: const Icon(Icons.shield_rounded), title: const Text('محرومیت و حذف پیام'), subtitle: const Text('فهرست محروم‌ها و حذف پیام برای همه'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupModerationPage(conversationId: widget.conversationId, title: widget.title))))),
      if (owner) Card(child: ListTile(leading: const Icon(Icons.dashboard_customize_rounded), title: const Text('مدیریت پیشرفته'), subtitle: const Text('درخواست‌های عضویت، محروم‌ها، محدودیت‌ها، سنجاق پیام و اختیارات مدیران'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupAdvancedAdminPage(conversationId: widget.conversationId, title: widget.title))))),
      if (owner) Card(child: ListTile(leading: const Icon(Icons.delete_forever_rounded), title: const Text('حذف کامل گروه', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: const Text('این گزینه هیچ ارتباطی با حذف/محروم کردن اعضا ندارد.'), onTap: deleteGroup)),
      if (busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
    ]));
  }
}
