import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'polish_widgets.dart';
import 'secret_chat.dart';

class AdvancedFeaturesPage extends StatefulWidget {
  const AdvancedFeaturesPage({super.key});
  @override
  State<AdvancedFeaturesPage> createState() => _AdvancedFeaturesPageState();
}

class _AdvancedFeaturesPageState extends State<AdvancedFeaturesPage> {
  final supabase = Supabase.instance.client;
  final wallpapers = <String>['پیش‌فرض', 'آرام', 'تیره', 'شفاف'];
  bool notifications = true;
  bool readReceipts = true;
  bool autoBackup = false;
  String wallpaper = 'پیش‌فرض';
  String search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      notifications = p.getBool('notifications') ?? true;
      readReceipts = p.getBool('read_receipts') ?? true;
      autoBackup = p.getBool('auto_backup') ?? false;
      wallpaper = p.getString('chat_wallpaper') ?? 'پیش‌فرض';
    });
  }

  Future<void> _save(String key, Object value) async {
    final p = await SharedPreferences.getInstance();
    if (value is bool) await p.setBool(key, value);
    if (value is String) await p.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final items = <_FeatureItem>[
      _FeatureItem(Icons.lock_outline_rounded, 'قفل برنامه', 'قفل با PIN و احراز هویت بیومتریک', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppLockSettingsPage()))),
      _FeatureItem(Icons.notifications_none, 'اعلان‌ها', 'تنظیم اعلان‌های محلی برنامه', () async { setState(() => notifications = !notifications); await _save('notifications', notifications); }),
      _FeatureItem(Icons.wallpaper_outlined, 'والپیپر گفتگو', 'تنظیم ظاهر گفتگو روی دستگاه', () => _showWallpaper()),
      _FeatureItem(Icons.backup_outlined, 'پشتیبان‌گیری و بازیابی', 'وضعیت فعلی پشتیبان‌گیری دستگاه', () async { setState(() => autoBackup = !autoBackup); await _save('auto_backup', autoBackup); }),
      _FeatureItem(Icons.check_circle_outline, 'رسید خواندن', 'تنظیم ترجیح محلی برای رسید خواندن', () async { setState(() => readReceipts = !readReceipts); await _save('read_receipts', readReceipts); }),
      _FeatureItem(Icons.folder_copy_outlined, 'پوشه‌های واقعی گفتگو', 'ساخت، ویرایش و دسته‌بندی گفتگوها با همگام‌سازی حساب', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatFolderManagerPage()))),
      _FeatureItem(Icons.lock_rounded, 'Secret Chat', 'گفتگوی محرمانه با رمزنگاری سرتاسری برای چت‌های دونفره', () => _openSecretChat()),
      _FeatureItem(Icons.timer_outlined, 'حذف خودکار پیام‌ها', 'تعیین زمان حذف واقعی پیام‌های جدید در هر گفتگو', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessageAutoDeletePage()))),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('قابلیت‌های برنامه')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(borderRadius: BorderRadius.circular(kPolishRadius), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Messenger Plus', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), SizedBox(height: 6), Text('همه قابلیت‌ها بجز کیف پول در یک بخش قابل دسترس هستند.')])) ,
          const SizedBox(height: 14),
          ...items.where((e) => search.isEmpty || e.title.contains(search)).map((e) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: Icon(e.icon), title: Text(e.title), subtitle: Text(e.subtitle), trailing: const Icon(Icons.chevron_left), onTap: e.action))),
        ],
      ),
    );
  }

  Future<void> _openSecretChat() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final members = List<Map<String,dynamic>>.from(await supabase.from('conversation_members').select('conversation_id').eq('user_id', uid));
    final directIds = <String>[];
    for (final row in members) {
      final id = row['conversation_id'].toString();
      final cm = List<Map<String,dynamic>>.from(await supabase.from('conversation_members').select('user_id').eq('conversation_id', id));
      if (cm.length == 2) directIds.add(id);
    }
    if (!mounted) return;
    if (directIds.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هنوز گفتگوی دونفره‌ای ندارید.'))); return; }
    String? selected = directIds.first;
    final title = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: const Text('انتخاب گفتگوی محرمانه'), content: DropdownButtonFormField<String>(value: selected, items: directIds.map((id) => DropdownMenuItem(value: id, child: Text(id))).toList(), onChanged: (v) => selected = v), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لغو')), FilledButton(onPressed: () => Navigator.pop(ctx, selected), child: const Text('باز کردن'))]));
    if (title == null || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => SecretChatPage(conversationId: title, title: 'Secret Chat')));
  }

  void _showWallpaper() => showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [for (final w in wallpapers) RadioListTile<String>(value: w, groupValue: wallpaper, title: Text(w), onChanged: (v) async { if (v == null) return; setState(() => wallpaper = v); await _save('chat_wallpaper', v); if (mounted) Navigator.pop(context); })])));

}



class MessageAutoDeletePage extends StatefulWidget {
  const MessageAutoDeletePage({super.key});
  @override State<MessageAutoDeletePage> createState() => _MessageAutoDeletePageState();
}
class _MessageAutoDeletePageState extends State<MessageAutoDeletePage> {
  final supabase = Supabase.instance.client;
  bool loading = true, saving = false;
  List<Map<String,dynamic>> chats = [];
  Map<String,int> ttl = {};
  String? selected;
  static const options = <int, String>{0:'خاموش',86400:'۱ روز',604800:'۷ روز',2592000:'۳۰ روز'};
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    try {
      final uid=supabase.auth.currentUser?.id; if(uid==null)return;
      final ms=List<Map<String,dynamic>>.from(await supabase.from('conversation_members').select('conversation_id').eq('user_id',uid));
      final ids=ms.map((e)=>e['conversation_id']).toList();
      if(ids.isEmpty){if(mounted)setState(()=>loading=false);return;}
      chats=List<Map<String,dynamic>>.from(await supabase.from('conversations').select('id,type,title').inFilter('id',ids));
      final rows=List<Map<String,dynamic>>.from(await supabase.from('message_ttl').select('conversation_id,ttl_seconds').inFilter('conversation_id',ids));
      ttl={for(final r in rows) r['conversation_id'].toString():(r['ttl_seconds'] as num).toInt()};
      selected=chats.first['id'].toString();
    }catch(e){if(mounted)showMsg(context,'بارگذاری حذف خودکار ناموفق بود: $e');}
    if(mounted)setState(()=>loading=false);
  }
  Future<void> _save(int seconds) async {
    final id=selected; final uid=supabase.auth.currentUser?.id; if(id==null||uid==null)return;
    setState(()=>saving=true);
    try {
      if(seconds==0){await supabase.from('message_ttl').delete().eq('conversation_id',id);} else {await supabase.from('message_ttl').upsert({'conversation_id':id,'ttl_seconds':seconds,'enabled_by':uid,'updated_at':DateTime.now().toUtc().toIso8601String()});}
      ttl[id]=seconds; if(mounted){setState((){});showMsg(context,'تنظیم حذف خودکار ذخیره شد.');}
    }catch(e){if(mounted)showMsg(context,'ذخیره تنظیم ناموفق بود: $e');}finally{if(mounted)setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context){
    final current=ttl[selected]??0;
    return Scaffold(appBar:AppBar(title:const Text('حذف خودکار پیام‌ها')),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
      const Card(child:Padding(padding:EdgeInsets.all(16),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.timer_outlined),SizedBox(width:12),Expanded(child:Text('پس از انتخاب زمان، پیام‌های جدید این گفتگو در Backend زمان انقضا می‌گیرند و حذف آن‌ها توسط سرویس زمان‌بندی‌شده انجام می‌شود.'))]))),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(value:selected,decoration:const InputDecoration(labelText:'گفتگو'),items:chats.map((c)=>DropdownMenuItem(value:c['id'].toString(),child:Text((c['title']??(c['type']=='group'?'گروه':c['type']=='channel'?'کانال':'گفتگو')).toString()))).toList(),onChanged:(v)=>setState(()=>selected=v)),
      const SizedBox(height:18),
      ...options.entries.map((e)=>Card(child:RadioListTile<int>(value:e.key,groupValue:current,title:Text(e.value,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:e.key==0?const Text('پیام‌ها حذف خودکار نمی‌شوند.'):const Text('برای پیام‌های جدید'),onChanged:saving?null:(v){if(v!=null)_save(v);}))),
    ]);
  }
}

class ChatFolderManagerPage extends StatefulWidget {
  const ChatFolderManagerPage({super.key});
  @override State<ChatFolderManagerPage> createState() => _ChatFolderManagerPageState();
}

class _ChatFolderManagerPageState extends State<ChatFolderManagerPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  List<Map<String, dynamic>> folders = [];
  List<Map<String, dynamic>> conversations = [];
  Map<String, Set<String>> assignments = {};
  String? selectedFolderId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;
      final folderRows = List<Map<String, dynamic>>.from(
        await supabase.from('chat_folders').select('id,name,icon_name,sort_order').eq('user_id', uid).order('sort_order').order('created_at'),
      );
      final memberRows = List<Map<String, dynamic>>.from(
        await supabase.from('conversation_members').select('conversation_id').eq('user_id', uid),
      );
      final ids = memberRows.map((e) => e['conversation_id']).toList();
      final convRows = ids.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await supabase.from('conversations').select('id,type,title,avatar_url,description,username').inFilter('id', ids),
            );

      final peerIds = <String>{};
      final membersByConversation = <String, List<String>>{};
      if (ids.isNotEmpty) {
        final allMembers = List<Map<String, dynamic>>.from(
          await supabase.from('conversation_members').select('conversation_id,user_id').inFilter('conversation_id', ids),
        );
        for (final row in allMembers) {
          final cid = row['conversation_id'].toString();
          final uidValue = row['user_id'].toString();
          (membersByConversation[cid] ??= <String>[]).add(uidValue);
          if (uidValue != uid && convRows.any((c) => c['id'].toString() == cid && c['type'] == 'direct')) {
            peerIds.add(uidValue);
          }
        }
      }

      final profiles = peerIds.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await supabase.from('profiles').select('id,display_name,username,avatar_url').inFilter('id', peerIds.toList()),
            );
      final profileMap = {for (final p in profiles) p['id'].toString(): p};

      final enriched = convRows.map((c) {
        final copy = Map<String, dynamic>.from(c);
        if (copy['type'] == 'direct') {
          final peerId = (membersByConversation[copy['id'].toString()] ?? const <String>[])
              .firstWhere((id) => id != uid, orElse: () => '');
          copy['_title'] = profileMap[peerId]?['display_name'] ?? profileMap[peerId]?['username'] ?? 'گفتگوی خصوصی';
          copy['_avatar'] = profileMap[peerId]?['avatar_url'] ?? '';
        } else {
          copy['_title'] = copy['title'] ?? (copy['type'] == 'group' ? 'گروه' : 'کانال');
          copy['_avatar'] = copy['avatar_url'] ?? '';
        }
        return copy;
      }).toList()
        ..sort((a, b) => a['_title'].toString().compareTo(b['_title'].toString()));

      final itemRows = folderRows.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await supabase.from('chat_folder_items').select('folder_id,conversation_id').inFilter('folder_id', folderRows.map((f) => f['id']).toList()),
            );
      final map = <String, Set<String>>{};
      for (final f in folderRows) {
        map[f['id'].toString()] = <String>{};
      }
      for (final row in itemRows) {
        (map[row['folder_id'].toString()] ??= <String>{}).add(row['conversation_id'].toString());
      }

      if (!mounted) return;
      setState(() {
        folders = folderRows;
        conversations = enriched;
        assignments = map;
        selectedFolderId = selectedFolderId != null && map.containsKey(selectedFolderId) ? selectedFolderId : (folderRows.isEmpty ? null : folderRows.first['id'].toString());
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('پوشه‌ها بارگذاری نشد: ' + e.toString())));
      }
    }
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پوشه جدید'),
        content: TextField(controller: controller, autofocus: true, maxLength: 40, decoration: const InputDecoration(labelText: 'نام پوشه')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('ساخت')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      final uid = supabase.auth.currentUser!.id;
      await supabase.from('chat_folders').insert({'user_id': uid, 'name': name.trim(), 'sort_order': folders.length});
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ساخت پوشه ناموفق بود: ' + e.toString())));
    }
  }

  Future<void> _renameFolder(Map<String, dynamic> folder) async {
    final controller = TextEditingController(text: folder['name']?.toString() ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ویرایش نام پوشه'),
        content: TextField(controller: controller, autofocus: true, maxLength: 40, decoration: const InputDecoration(labelText: 'نام پوشه')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('ذخیره')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      await supabase.from('chat_folders').update({'name': name}).eq('id', folder['id']);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ویرایش پوشه ناموفق بود: ' + e.toString())));
    }
  }

  Future<void> _deleteFolder(Map<String, dynamic> folder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف پوشه؟'),
        content: Text('پوشه «' + (folder['name']?.toString() ?? '') + '» و فقط تنظیم دسته‌بندی آن حذف می‌شود. گفتگوها حذف نمی‌شوند.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    try {
      await supabase.from('chat_folders').delete().eq('id', folder['id']);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حذف پوشه ناموفق بود: ' + e.toString())));
    }
  }

  Future<void> _toggleConversation(String conversationId, bool selected) async {
    final folderId = selectedFolderId;
    if (folderId == null) return;
    try {
      if (selected) {
        await supabase.from('chat_folder_items').upsert({'folder_id': folderId, 'conversation_id': conversationId});
      } else {
        await supabase.from('chat_folder_items').delete().eq('folder_id', folderId).eq('conversation_id', conversationId);
      }
      setState(() {
        final set = assignments[folderId] ??= <String>{};
        if (selected) {
          set.add(conversationId);
        } else {
          set.remove(conversationId);
        }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تغییر دسته‌بندی ناموفق بود: ' + e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedFolderId;
    final assigned = selected == null ? <String>{} : (assignments[selected] ?? <String>{});
    return Scaffold(
      appBar: AppBar(
        title: const Text('پوشه‌های گفتگو'),
        actions: [
          IconButton(onPressed: _createFolder, tooltip: 'پوشه جدید', icon: const Icon(Icons.create_new_folder_outlined)),
          if (selected != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                final folder = folders.firstWhere((f) => f['id'].toString() == selected);
                if (v == 'rename') _renameFolder(folder);
                if (v == 'delete') _deleteFolder(folder);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('تغییر نام')),
                PopupMenuItem(value: 'delete', child: Text('حذف پوشه')),
              ],
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (folders.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Row(
                      children: folders.map((folder) {
                        final id = folder['id'].toString();
                        return Padding(
                          padding: const EdgeInsets.only(left: 7),
                          child: ChoiceChip(
                            selected: id == selected,
                            avatar: const Icon(Icons.folder_rounded, size: 17),
                            label: Text(folder['name'].toString()),
                            onSelected: (_) => setState(() => selectedFolderId = id),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('هنوز پوشه‌ای نساخته‌اید. از دکمه + یک پوشه بسازید.', textAlign: TextAlign.center),
                  ),
                if (selected != null)
                  Expanded(
                    child: conversations.isEmpty
                        ? const Center(child: Text('گفتگویی برای دسته‌بندی وجود ندارد.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                            itemCount: conversations.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (_, i) {
                              final c = conversations[i];
                              final id = c['id'].toString();
                              final checked = assigned.contains(id);
                              final title = c['_title']?.toString() ?? 'گفتگو';
                              final type = c['type']?.toString() ?? 'direct';
                              final avatarUrl = c['_avatar']?.toString() ?? '';
                              final icon = type == 'group' ? Icons.groups_rounded : type == 'channel' ? Icons.campaign_rounded : Icons.person_rounded;
                              return Card(
                                child: CheckboxListTile(
                                  value: checked,
                                  onChanged: (v) => _toggleConversation(id, v == true),
                                  secondary: CircleAvatar(
                                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                    child: avatarUrl.isEmpty ? Icon(icon) : null,
                                  ),
                                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(type == 'group' ? 'گروه' : type == 'channel' ? 'کانال' : 'گفتگوی خصوصی'),
                                ),
                              );
                            },
                          ),
                  )
                else
                  const Expanded(child: Center(child: Icon(Icons.folder_copy_outlined, size: 72))),
              ],
            ),
    );
  }
}

class _FeatureItem {
  final IconData icon; final String title; final String subtitle; final VoidCallback action;
  _FeatureItem(this.icon, this.title, this.subtitle, this.action);
}

class _FeatureSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget>? buildActions(BuildContext context) => [if (query.isNotEmpty) IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear))];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(onPressed: () => close(context, ''), icon: const Icon(Icons.arrow_back));
  @override
  Widget buildResults(BuildContext context) => Center(child: Text(query.isEmpty ? 'جستجو کنید' : 'جستجو برای «$query»'));
  @override
  Widget buildSuggestions(BuildContext context) => const Center(child: Text('کاربر، گفتگو یا پیام را جستجو کنید'));
}


class AppLockSettingsPage extends StatefulWidget {
  const AppLockSettingsPage({super.key});
  @override State<AppLockSettingsPage> createState() => _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends State<AppLockSettingsPage> {
  final _secure = const FlutterSecureStorage();
  final _auth = LocalAuthentication();
  bool enabled = false, biometric = false, saving = false;
  bool biometricAvailable = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final can = await _auth.canCheckBiometrics;
    if (!mounted) return;
    setState(() {
      enabled = p.getBool('app_lock_enabled') ?? false;
      biometric = p.getBool('app_lock_biometric') ?? false;
      biometricAvailable = can;
    });
  }

  Future<void> _setPin() async {
    final c1=TextEditingController(), c2=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('تعیین PIN'), content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:c1,keyboardType:TextInputType.number,maxLength:6,obscureText:true,decoration:const InputDecoration(labelText:'PIN چهار تا شش رقمی')),
        TextField(controller:c2,keyboardType:TextInputType.number,maxLength:6,obscureText:true,decoration:const InputDecoration(labelText:'تکرار PIN')),
      ]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(ctx,c1.text.length>=4&&c1.text.length<=6&&RegExp(r'^\d+$').hasMatch(c1.text)&&c1.text==c2.text),child:const Text('ذخیره'))]));
    c1.dispose(); c2.dispose();
    if(ok!=true)return;
    final p=await SharedPreferences.getInstance();
    await _secure.write(key:'app_lock_pin',value:c1.text);
    await p.setBool('app_lock_enabled',true);
    if(mounted)setState(()=>enabled=true);
  }

  Future<void> _toggleBiometric(bool v) async {
    if(v) {
      try {
        final ok=await _auth.authenticate(localizedReason:'برای فعال‌سازی قفل برنامه احراز هویت کنید',options:const AuthenticationOptions(biometricOnly:true,useErrorDialogs:true,stickyAuth:true));
        if(!ok)return;
      } catch(_) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('احراز هویت بیومتریک در این دستگاه در دسترس نیست.'))); return; }
    }
    final p=await SharedPreferences.getInstance(); await p.setBool('app_lock_biometric',v);
    if(mounted)setState(()=>biometric=v);
  }

  Future<void> _disable() async {
    final pin=await _secure.read(key:'app_lock_pin');
    if(pin!=null) {
      final c=TextEditingController();
      final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('غیرفعال‌سازی قفل'),content:TextField(controller:c,keyboardType:TextInputType.number,obscureText:true,decoration:const InputDecoration(labelText:'PIN')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(ctx,c.text==pin),child:const Text('تأیید'))]));
      c.dispose(); if(ok!=true)return;
    }
    final p=await SharedPreferences.getInstance(); await p.setBool('app_lock_enabled',false); await p.setBool('app_lock_biometric',false); await _secure.delete(key:'app_lock_pin');
    if(mounted)setState(()=>{enabled=false;biometric=false;});
  }

  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('قفل برنامه')),body:ListView(padding:const EdgeInsets.all(16),children:[
    Card(child:ListTile(leading:const Icon(Icons.password_rounded),title:const Text('قفل با PIN'),subtitle:Text(enabled?'فعال':'غیرفعال'),trailing:FilledButton.tonal(onPressed:_setPin,child:Text(enabled?'تغییر PIN':'تعیین PIN')))),
    Card(child:SwitchListTile(title:const Text('باز کردن با اثر انگشت / Face ID'),subtitle:Text(biometricAvailable?'در صورت پشتیبانی دستگاه':'این دستگاه بیومتریک قابل استفاده را گزارش نکرده است'),value:biometric&&enabled,onChanged:enabled&&biometricAvailable?_toggleBiometric:null)),
    if(enabled) Card(child:ListTile(leading:const Icon(Icons.lock_open_rounded),title:const Text('غیرفعال کردن قفل'),onTap:_disable)),
    const SizedBox(height:12),const Text('PIN در حافظه امن دستگاه نگهداری می‌شود و در Supabase ذخیره نمی‌شود.')
  ]));
}
