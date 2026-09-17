from pathlib import Path
import re

MAIN = Path('lib/main.dart')
PUB = Path('pubspec.yaml')

main = MAIN.read_text(encoding='utf-8')
if "import 'package:qr_flutter/qr_flutter.dart';" not in main:
    main = main.replace("import 'package:supabase_flutter/supabase_flutter.dart';", "import 'package:supabase_flutter/supabase_flutter.dart';\nimport 'package:qr_flutter/qr_flutter.dart';")

start = main.find('class GroupManagementPage extends StatefulWidget {')
end = main.find('class ConversationToolsPage extends StatefulWidget {', start)
if start < 0 or end < 0:
    raise SystemExit('GroupManagementPage block not found')

new_block = r'''class GroupManagementPage extends StatefulWidget {
  final String conversationId;
  final String title;
  const GroupManagementPage({super.key, required this.conversationId, required this.title});
  @override State<GroupManagementPage> createState() => _GroupManagementPageState();
}

class _GroupManagementPageState extends State<GroupManagementPage> with SingleTickerProviderStateMixin {
  final sb = Supabase.instance.client;
  late TabController tabs;
  Map<String, dynamic> group = {};
  List<Map<String, dynamic>> members = [];
  List<Map<String, dynamic>> admins = [];
  List<Map<String, dynamic>> logs = [];
  List<Map<String, dynamic>> media = [];
  Map<String, Map<String, dynamic>> people = {};
  bool loading = true;
  bool saving = false;
  bool isOwner = false;
  bool isAdmin = false;
  final memberSearch = TextEditingController();

  @override void initState() { super.initState(); tabs = TabController(length: 3, vsync: this); load(); }
  @override void dispose() { tabs.dispose(); memberSearch.dispose(); super.dispose(); }

  Future<void> load() async {
    try {
      final c = Map<String, dynamic>.from(await sb.from('conversations').select().eq('id', widget.conversationId).single());
      final ms = List<Map<String, dynamic>>.from(await sb.from('conversation_members').select('conversation_id,user_id,role,joined_at').eq('conversation_id', widget.conversationId).order('joined_at'));
      final as_ = List<Map<String, dynamic>>.from(await sb.from('conversation_admins').select('user_id,role,created_at').eq('conversation_id', widget.conversationId));
      final ids = {...ms.map((x) => '${x['user_id']}'), ...as_.map((x) => '${x['user_id']}')}.toList();
      final ps = ids.isEmpty ? <Map<String, dynamic>>[] : List<Map<String, dynamic>>.from(await sb.from('profiles').select('id,display_name,username,avatar_url,bio').inFilter('id', ids));
      final uid = sb.auth.currentUser?.id;
      List<Map<String, dynamic>> ls = [];
      List<Map<String, dynamic>> med = [];
      try { ls = List<Map<String, dynamic>>.from(await sb.from('group_audit_logs').select().eq('conversation_id', widget.conversationId).order('created_at', ascending: false).limit(100)); } catch (_) {}
      try {
        final msgs = List<Map<String, dynamic>>.from(await sb.from('messages').select('id,body,message_type,created_at').eq('conversation_id', widget.conversationId).order('created_at', ascending: false).limit(200));
        med = msgs.where((m) => ['image','video','file','link'].contains('${m['message_type']}')).toList();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        group = c; members = ms; admins = as_; people = {for (final p in ps) '${p['id']}': p}; logs = ls; media = med;
        isOwner = uid != null && '${c['created_by']}' == uid;
        isAdmin = isOwner || as_.any((a) => '${a['user_id']}' == uid && '${a['role']}' == 'admin');
        loading = false;
      });
    } catch (e) { if (mounted) { setState(() => loading = false); showMsg(context, 'خطا در پروفایل گروه: $e'); } }
  }

  String nameOf(String id) => '${people[id]?['display_name'] ?? people[id]?['username'] ?? 'کاربر'}';
  bool adminOf(String id) => isOwner && '${group['created_by']}' == id || admins.any((a) => '${a['user_id']}' == id && '${a['role']}' == 'admin');
  bool can(String permission) => isOwner || admins.any((a) => '${a['user_id']}' == sb.auth.currentUser?.id && '${a['role']}' == 'admin');

  Future<void> editSettings() async {
    if (!isAdmin) return;
    final name = TextEditingController(text: '${group['title'] ?? widget.title}');
    final desc = TextEditingController(text: '${group['description'] ?? ''}');
    final username = TextEditingController(text: '${group['username'] ?? ''}');
    bool publicGroup = group['is_public'] == true;
    bool approval = group['join_approval'] == true;
    bool adminsPost = group['only_admins_can_post'] == true;
    bool adminsAdd = group['only_admins_can_add'] == true;
    int autoDelete = int.tryParse('${group['auto_delete_seconds'] ?? 0}') ?? 0;
    await showDialog<void>(context: context, builder: (d) => StatefulBuilder(builder: (_, set) => AlertDialog(
      title: const Text('تنظیمات گروه'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'نام گروه')),
        const SizedBox(height: 10), TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'توضیحات')),
        const SizedBox(height: 10), SwitchListTile(title: const Text('گروه عمومی'), subtitle: const Text('با نام کاربری قابل پیدا شدن باشد'), value: publicGroup, onChanged: (v) => set(() => publicGroup = v)),
        if (publicGroup) TextField(controller: username, decoration: const InputDecoration(labelText: 'نام کاربری گروه', prefixText: '@')),
        SwitchListTile(title: const Text('تأیید عضویت'), value: approval, onChanged: (v) => set(() => approval = v)),
        SwitchListTile(title: const Text('فقط ادمین‌ها پیام بفرستند'), value: adminsPost, onChanged: (v) => set(() => adminsPost = v)),
        SwitchListTile(title: const Text('فقط ادمین‌ها عضو اضافه کنند'), value: adminsAdd, onChanged: (v) => set(() => adminsAdd = v)),
        DropdownButtonFormField<int>(initialValue: autoDelete, decoration: const InputDecoration(labelText: 'پاک‌شدن خودکار پیام‌ها'), items: const [DropdownMenuItem(value: 0, child: Text('خاموش')), DropdownMenuItem(value: 86400, child: Text('۲۴ ساعت')), DropdownMenuItem(value: 604800, child: Text('۷ روز')), DropdownMenuItem(value: 2592000, child: Text('۳۰ روز'))], onChanged: (v) => set(() => autoDelete = v ?? 0)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('لغو')), FilledButton(onPressed: saving ? null : () async {
        setState(() => saving = true);
        try { await sb.rpc('update_group_settings', params: {'p_conversation_id': widget.conversationId,'p_title': name.text.trim(),'p_description': desc.text.trim(),'p_avatar_url': group['avatar_url'],'p_is_public': publicGroup,'p_username': username.text.trim(),'p_join_approval': approval,'p_only_admins_can_post': adminsPost,'p_only_admins_can_add': adminsAdd,'p_auto_delete_seconds': autoDelete}); if (d.mounted) Navigator.pop(d); await load(); }
        catch (e) { if (mounted) showMsg(context, 'ذخیره نشد: $e'); }
        finally { if (mounted) setState(() => saving = false); }
      }, child: const Text('ذخیره'))],
    )));
    name.dispose(); desc.dispose(); username.dispose();
  }

  Future<void> addMembers() async {
    if (!isAdmin) return;
    final q = TextEditingController(); final chosen = <Map<String,dynamic>>[];
    await showDialog<void>(context: context, builder: (d) => StatefulBuilder(builder: (_, set) => AlertDialog(
      title: const Text('افزودن چند عضو'),
      content: SizedBox(width: 420, height: 360, child: Column(children: [TextField(controller: q, onChanged: (v) async { if (v.trim().isEmpty) return; try { final r = await sb.rpc('search_profiles', params: {'search_text': v.trim()}); if (d.mounted) set(() { chosen.removeWhere((x) => false); }); } catch (_) {} }, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'نام یا نام کاربری')),
        const SizedBox(height: 12), const Text('برای افزودن، از جستجوی مخاطبین استفاده کنید.'), const SizedBox(height: 8), Expanded(child: ListView(children: chosen.map((p) => ListTile(title: Text('${p['display_name'] ?? p['username']}'), trailing: const Icon(Icons.check))).toList()))])),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('لغو')), FilledButton(onPressed: () async { Navigator.pop(d); await showSearch(context: context, delegate: UserSearchDelegate()); }, child: const Text('جستجو و افزودن'))],
    )));
  }

  Future<void> memberAction(Map<String,dynamic> m) async {
    if (!isAdmin) return; final id = '${m['user_id']}'; if (id == '${group['created_by']}') return;
    await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (s) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.admin_panel_settings_rounded), title: Text(adminOf(id) ? 'عزل از مدیریت' : 'ارتقا به ادمین'), onTap: () async { Navigator.pop(s); try { await sb.rpc('set_group_member_role', params: {'p_conversation_id': widget.conversationId,'p_user_id': id,'p_role': adminOf(id) ? 'member' : 'admin'}); await load(); } catch (e) { if (mounted) showMsg(context, 'تغییر نقش ناموفق بود: $e'); } }),
      ListTile(leading: const Icon(Icons.timer_off_rounded), title: const Text('محدودیت موقت ارسال'), onTap: () async { Navigator.pop(s); await restrict(id); }),
      ListTile(leading: const Icon(Icons.person_remove_rounded), title: const Text('فقط حذف از گروه'), onTap: () async { Navigator.pop(s); await remove(id, false); }),
      ListTile(leading: const Icon(Icons.block_rounded), title: const Text('حذف و مسدودکردن'), onTap: () async { Navigator.pop(s); await remove(id, true); }),
    ])));
  }

  Future<void> restrict(String id) async {
    final choices = <String,int>{'۳۰ دقیقه':1800,'۱ ساعت':3600,'۲۴ ساعت':86400};
    final seconds = await showDialog<int>(context: context, builder: (d) => SimpleDialog(title: const Text('مدت محدودیت'), children: choices.entries.map((e) => SimpleDialogOption(onPressed: () => Navigator.pop(d,e.value), child: Text(e.key))).toList()));
    if (seconds == null) return;
    try { await sb.rpc('restrict_group_member', params: {'p_conversation_id': widget.conversationId,'p_user_id': id,'p_can_send_messages': false,'p_can_send_media': false,'p_can_send_links': false,'p_expires_at': DateTime.now().toUtc().add(Duration(seconds: seconds)).toIso8601String()}); await load(); } catch (e) { if (mounted) showMsg(context, 'محدودیت اعمال نشد: $e'); }
  }

  Future<void> remove(String id, bool block) async {
    try { await sb.rpc('remove_group_member', params: {'p_conversation_id': widget.conversationId,'p_user_id': id}); if (block) await sb.from('group_member_restrictions').upsert({'conversation_id':widget.conversationId,'user_id':id,'can_send_messages':false,'can_send_media':false,'can_send_links':false}); await load(); } catch (e) { if (mounted) showMsg(context, 'عملیات ناموفق بود: $e'); }
  }

  Future<void> invite() async {
    int max = 0; bool approval = group['join_approval'] == true; DateTime? expiry;
    final code = await showDialog<String>(context: context, builder: (d) => StatefulBuilder(builder: (_, set) => AlertDialog(title: const Text('لینک دعوت جدید'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حداکثر استفاده (۰ = نامحدود)'), onChanged: (v) => max = int.tryParse(v) ?? 0), SwitchListTile(title: const Text('تأیید عضویت'), value: approval, onChanged: (v) => set(() => approval = v)), const Text('برای انقضا از گزینه‌های سریع استفاده کنید.'), Wrap(spacing: 6, children: [TextButton(onPressed: () => set(() => expiry = DateTime.now().toUtc().add(const Duration(hours: 24))), child: const Text('۲۴ ساعت')), TextButton(onPressed: () => set(() => expiry = DateTime.now().toUtc().add(const Duration(days: 7))), child: const Text('۷ روز'))])]), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('لغو')), FilledButton(onPressed: () async { try { final r = await sb.rpc('create_group_invite', params: {'p_conversation_id':widget.conversationId,'p_max_uses':max,'p_expires_at':expiry?.toIso8601String(),'p_requires_approval':approval}); if (d.mounted) Navigator.pop(d, '${r}'); } catch (e) { if (mounted) showMsg(context,'ساخت لینک ناموفق بود: $e'); } }, child: const Text('ساخت'))]));
    if (code == null || !mounted) return;
    await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (s) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.link_rounded,size:40), const SizedBox(height:10), SelectableText('https://arad.app/invite/$code'), const SizedBox(height:10), Row(children: [Expanded(child: FilledButton.icon(onPressed: () async { await Clipboard.setData(ClipboardData(text:'https://arad.app/invite/$code')); if (mounted) showMsg(context,'لینک کپی شد.'); }, icon: const Icon(Icons.copy), label: const Text('کپی'))), const SizedBox(width:8), Expanded(child: OutlinedButton.icon(onPressed: () => Share.share('https://arad.app/invite/$code'), icon: const Icon(Icons.share), label: const Text('اشتراک')))]), const SizedBox(height:18), QrImageView(data:'https://arad.app/invite/$code',size:190), const SizedBox(height:8), const Text('QR اختصاصی گروه'))])));
  }

  Widget memberTab() {
    final q = memberSearch.text.trim().toLowerCase();
    final list = members.where((m) => q.isEmpty || nameOf('${m['user_id']}').toLowerCase().contains(q) || '${people['${m['user_id']}']?['username'] ?? ''}'.toLowerCase().contains(q)).toList();
    return ListView(padding: const EdgeInsets.all(14), children: [TextField(controller: memberSearch, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'جستجوی اعضا')), const SizedBox(height:12), ...list.map((m) { final id='${m['user_id']}'; return ListTile(leading: avatar(people[id] ?? {}), title: Row(children:[Flexible(child: Text(nameOf(id))), if(id=='${group['created_by']}') _badge('سازنده'), if(adminOf(id) && id!='${group['created_by']}') _badge('ادمین')]), subtitle: Text('@${people[id]?['username'] ?? ''}'), onLongPress: isAdmin ? () => memberAction(m) : null); })]);
  }
  Widget _badge(String text) => Container(margin: const EdgeInsetsDirectional.only(start:6), padding: const EdgeInsets.symmetric(horizontal:6,vertical:2), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer,borderRadius: BorderRadius.circular(7)), child: Text(text,style: TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:Theme.of(context).colorScheme.primary)));
  Widget infoTab() => ListView(padding: const EdgeInsets.all(14), children: [
    Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children:[CircleAvatar(radius:48,backgroundImage: '${group['avatar_url'] ?? ''}'.isNotEmpty ? NetworkImage('${group['avatar_url']}') : null, child: '${group['avatar_url'] ?? ''}'.isEmpty ? const Icon(Icons.groups_rounded,size:42) : null), const SizedBox(height:12), Text('${group['title'] ?? widget.title}',style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900)), Text('${members.length} عضو',style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant)), if('${group['description'] ?? ''}'.trim().isNotEmpty) Padding(padding:const EdgeInsets.only(top:8),child:Text('${group['description']}',textAlign:TextAlign.center))]))),
    const SizedBox(height:10),
    Card(child: Column(children:[ListTile(leading:const Icon(Icons.search_rounded),title:const Text('جستجو در گفتگو')), ListTile(leading:const Icon(Icons.notifications_off_outlined),title:const Text('بی‌صدا کردن گروه')), ListTile(leading:const Icon(Icons.link_rounded),title:const Text('لینک دعوت و QR'),onTap:invite), if(isAdmin) ListTile(leading:const Icon(Icons.settings_rounded),title:const Text('تنظیمات گروه'),onTap:editSettings), if(isAdmin) ListTile(leading:const Icon(Icons.admin_panel_settings_rounded),title:const Text('مدیریت ادمین‌ها'),onTap:() => tabs.animateTo(0))])),
    const SizedBox(height:10),
    Card(child: Column(children:[ListTile(leading:const Icon(Icons.photo_library_outlined),title:const Text('رسانه‌ها'),subtitle:Text('${media.where((m)=>m['message_type']=='image'||m['message_type']=='video').length} مورد')), ListTile(leading:const Icon(Icons.insert_drive_file_outlined),title:const Text('فایل‌ها'),subtitle:Text('${media.where((m)=>m['message_type']=='file').length} مورد')), ListTile(leading:const Icon(Icons.link_outlined),title:const Text('لینک‌ها'),subtitle:Text('${media.where((m)=>m['message_type']=='link').length} مورد'))])),
    const SizedBox(height:18),
    if(isOwner) Card(child: ListTile(textColor:Colors.red,iconColor:Colors.red,leading:const Icon(Icons.delete_forever_outlined),title:const Text('حذف کامل گروه'),onTap:() => showMsg(context,'حذف کامل گروه را فقط پس از تأیید نهایی انجام دهید.'))),
    Card(child: ListTile(textColor:Colors.red,iconColor:Colors.red,leading:const Icon(Icons.logout_rounded),title:const Text('خروج از گروه'),onTap:() async { final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('خروج از گروه؟'),content:const Text('مطمئنی می‌خواهی از گروه خارج بشی؟'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('خروج'))])); if(ok==true) { try { await sb.from('conversation_members').delete().eq('conversation_id',widget.conversationId).eq('user_id',sb.auth.currentUser!.id); if(mounted) Navigator.pop(context); } catch(e) { if(mounted) showMsg(context,'خروج ناموفق بود: $e'); } } }))
  ]);
  Widget adminsTab() => ListView(padding: const EdgeInsets.all(14), children: [if(isAdmin) FilledButton.icon(onPressed:addMembers,icon:const Icon(Icons.person_add_alt_1),label:const Text('افزودن عضو')), const SizedBox(height:8), Text('ادمین‌ها',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)), ...admins.map((a){ final id='${a['user_id']}'; return Card(child:ListTile(leading:avatar(people[id]??{}),title:Text(nameOf(id)),subtitle:const Text('ادمین'),trailing:isOwner?PopupMenuButton<String>(onSelected:(v)async{if(v=='remove') { await sb.rpc('set_group_member_role',params:{'p_conversation_id':widget.conversationId,'p_user_id':id,'p_role':'member'}); await load(); }},itemBuilder:(_)=>const [PopupMenuItem(value:'remove',child:Text('عزل ادمین'))]):null)); })]);
  Widget logsTab() => ListView(padding:const EdgeInsets.all(14),children:[Text('لاگ فعالیت‌های مهم',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),...logs.map((l)=>ListTile(leading:const Icon(Icons.history_rounded),title:Text('${l['action']}'),subtitle:Text('${l['created_at']}')))]);

  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(appBar:AppBar(title:Text('${group['title'] ?? widget.title}'),actions:[if(isAdmin) IconButton(onPressed:editSettings,icon:const Icon(Icons.settings_rounded)),IconButton(onPressed:invite,icon:const Icon(Icons.link_rounded))],bottom:TabBar(controller:tabs,tabs:const [Tab(text:'اعضا'),Tab(text:'پروفایل'),Tab(text:'لاگ')])) ,body:TabBarView(controller:tabs,children:[memberTab(),infoTab(),logsTab()]));
  }
}

'''
main = main[:start] + new_block + main[end:]
MAIN.write_text(main, encoding='utf-8')

pub = PUB.read_text(encoding='utf-8')
if 'qr_flutter:' not in pub:
    pub = pub.replace('  share_plus: ^10.1.4\n', '  share_plus: ^10.1.4\n  qr_flutter: ^4.1.0\n')
    PUB.write_text(pub, encoding='utf-8')
print('complete group system patched')
