import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupManagementPage extends StatefulWidget {
  final String conversationId;
  final String title;
  const GroupManagementPage({super.key, required this.conversationId, required this.title});

  @override
  State<GroupManagementPage> createState() => _GroupManagementPageState();
}

class _GroupManagementPageState extends State<GroupManagementPage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? group;
  List<Map<String, dynamic>> members = [];
  Map<String, Map<String, dynamic>> profiles = {};
  bool loading = true;
  bool busy = false;
  bool isAdmin = false;
  bool isOwner = false;

  Future<void> load() async {
    try {
      final c = await supabase.from('conversations').select('id,type,title,created_by,allow_reactions,allow_member_add').eq('id', widget.conversationId).single();
      final rows = await supabase.from('conversation_members').select('conversation_id,user_id,role,joined_at').eq('conversation_id', widget.conversationId).order('joined_at');
      final list = List<Map<String, dynamic>>.from(rows);
      final ids = list.map((e) => '${e['user_id']}').toList();
      final people = ids.isEmpty ? <dynamic>[] : await supabase.from('profiles').select('id,display_name,username,avatar_url').inFilter('id', ids);
      final map = {for (final p in List<Map<String, dynamic>>.from(people)) '${p['id']}': p};
      final uid = supabase.auth.currentUser?.id;
      if (!mounted) return;
      setState(() {
        group = Map<String, dynamic>.from(c);
        members = list;
        profiles = map;
        isOwner = uid != null && c['created_by'] == uid;
        isAdmin = isOwner || list.any((m) => m['user_id'] == uid && m['role'] == 'admin');
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا در گروه: $e')));
      }
    }
  }

  String nameOf(String id) {
    final p = profiles[id];
    return '${p?['display_name'] ?? p?['username'] ?? 'کاربر'}';
  }

  Future<void> addMember() async {
    if (!isAdmin || group?['allow_member_add'] != true) return;
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('افزودن عضو'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'نام کاربری یا نام نمایشی')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('لغو')),
          FilledButton(onPressed: () async {
            final q = controller.text.trim();
            if (q.isEmpty) return;
            try {
              final results = await supabase.from('profiles').select('id,display_name,username').or('username.ilike.%$q%,display_name.ilike.%$q%').limit(8);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (results.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کاربری پیدا نشد.')));
                return;
              }
              if (results.length == 1) {
                await _addUser('${results.first['id']}');
              } else {
                await _chooseUser(List<Map<String, dynamic>>.from(results));
              }
            } catch (e) {
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('جستجو ناموفق بود: $e')));
            }
          }, child: const Text('جستجو')),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _chooseUser(List<Map<String, dynamic>> results) async {
    await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (sheet) => SafeArea(child: ListView(shrinkWrap: true, children: results.map((p) => ListTile(title: Text('${p['display_name'] ?? p['username'] ?? 'کاربر'}'), subtitle: Text('@${p['username'] ?? ''}'), onTap: () { Navigator.pop(sheet); _addUser('${p['id']}'); })).toList())));
  }

  Future<void> _addUser(String id) async {
    try {
      await supabase.rpc('add_group_member', params: {'p_conversation_id': widget.conversationId, 'p_user_id': id});
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عضو به گروه اضافه شد.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('افزودن عضو ناموفق بود: $e')));
    }
  }

  Future<void> removeMember(String id) async {
    try {
      await supabase.rpc('remove_group_member', params: {'p_conversation_id': widget.conversationId, 'p_user_id': id});
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حذف عضو ناموفق بود: $e')));
    }
  }

  Future<void> changeRole(String id, String role) async {
    try {
      await supabase.rpc('set_group_member_role', params: {'p_conversation_id': widget.conversationId, 'p_user_id': id, 'p_role': role});
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تغییر نقش ناموفق بود: $e')));
    }
  }

  Future<void> setPermissions(bool reactionsAllowed, bool memberAddAllowed) async {
    if (!isAdmin) return;
    setState(() => busy = true);
    try {
      await supabase.rpc('set_group_permissions', params: {'p_conversation_id': widget.conversationId, 'p_allow_reactions': reactionsAllowed, 'p_allow_member_add': memberAddAllowed});
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تنظیمات ذخیره نشد: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void initState() { super.initState(); load(); }

  @override
  Widget build(BuildContext context) {
    final g = group;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} • مدیریت گروه')),
      body: loading ? const Center(child: CircularProgressIndicator()) : g == null || g['type'] != 'group' ? const Center(child: Text('این گفتگو گروه نیست.')) : RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.groups_rounded)), title: Text(g['title'] ?? widget.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(isOwner ? 'مالک گروه' : isAdmin ? 'مدیر گروه' : 'عضو'))),
            if (isAdmin) ...[
              const SizedBox(height: 8),
              Card(child: Column(children: [
                SwitchListTile(title: const Text('واکنش به پیام‌ها'), subtitle: const Text('اعضا بتوانند روی پیام‌ها واکنش بگذارند'), value: g['allow_reactions'] == true, onChanged: busy ? null : (v) => setPermissions(v, g['allow_member_add'] == true)),
                SwitchListTile(title: const Text('افزودن عضو توسط مدیر'), subtitle: const Text('مدیران بتوانند اعضای جدید اضافه کنند'), value: g['allow_member_add'] == true, onChanged: busy ? null : (v) => setPermissions(g['allow_reactions'] == true, v)),
              ])),
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: g['allow_member_add'] == true ? addMember : null, icon: const Icon(Icons.person_add_alt_1), label: const Text('افزودن عضو')),
            ],
            const SizedBox(height: 10),
            Text('اعضای گروه (${members.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            ...members.map((m) {
              final id = '${m['user_id']}';
              final owner = id == '${g['created_by']}';
              final role = '${m['role'] ?? 'member'}';
              return Card(child: ListTile(
                leading: CircleAvatar(child: Text(nameOf(id).isEmpty ? '?' : nameOf(id)[0].toUpperCase())),
                title: Text(nameOf(id)),
                subtitle: Text(owner ? '👑 مالک گروه' : role == 'admin' ? '🛡️ مدیر' : 'عضو'),
                trailing: isAdmin && !owner && id != supabase.auth.currentUser?.id ? PopupMenuButton<String>(onSelected: (v) => v == 'remove' ? removeMember(id) : changeRole(id, v), itemBuilder: (_) => [PopupMenuItem(value: role == 'admin' ? 'member' : 'admin', child: Text(role == 'admin' ? 'برداشتن مدیریت' : 'ارتقا به مدیر')), const PopupMenuItem(value: 'remove', child: Text('حذف از گروه'))]) : null,
              ));
            }),
          ],
        ),
      ),
    );
  }
}
