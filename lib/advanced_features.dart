import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'polish_widgets.dart';
import 'chat_background_page.dart';
import 'secret_chat.dart';

class AdvancedFeaturesPage extends StatelessWidget {
  const AdvancedFeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String title, String subtitle, Widget page})>[
      (
        icon: Icons.wallpaper_outlined,
        title: 'پس‌زمینهٔ گفتگو',
        subtitle: 'انتخاب رنگ، عکس و افکت‌های واقعی گفتگو',
        page: const ChatBackgroundPage(),
      ),
      (
        icon: Icons.folder_copy_outlined,
        title: 'پوشه‌های گفتگو',
        subtitle: 'ساخت و دسته‌بندی گفتگوها برای حساب شما',
        page: const ChatFolderManagerPage(),
      ),
      (
        icon: Icons.lock_rounded,
        title: 'گفتگوی محرمانه',
        subtitle: 'باز کردن گفتگوی دونفره در حالت محرمانه',
        page: const _SecretChatEntryPage(),
      ),
      (
        icon: Icons.timer_outlined,
        title: 'حذف خودکار پیام‌ها',
        subtitle: 'تنظیم زمان انقضای پیام‌های جدید',
        page: const MessageAutoDeletePage(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('قابلیت‌های فعال')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'قابلیت‌هایی که از این بخش باز می‌شوند به صفحه و عملکرد واقعی متصل هستند.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: CircleAvatar(child: Icon(item.icon)),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(item.subtitle),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => item.page),
              ),
            ),
          )),
          const SizedBox(height: 8),
          Text(
            'قفل برنامه و گزینه‌های دیگری که هنوز کامل فعال نیستند عمداً نمایش داده نشده‌اند.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SecretChatEntryPage extends StatelessWidget {
  const _SecretChatEntryPage();

  @override
  Widget build(BuildContext context) => const _SecretChatLauncher();
}

class _SecretChatLauncher extends StatefulWidget {
  const _SecretChatLauncher();

  @override
  State<_SecretChatLauncher> createState() => _SecretChatLauncherState();
}

class _SecretChatLauncherState extends State<_SecretChatLauncher> {
  final supabase = Supabase.instance.client;
  bool loading = false;

  Future<void> _openSecretChat() async {
    if (loading) return;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برای باز کردن گفتگوی محرمانه ابتدا وارد حساب شوید.')),
      );
      return;
    }
    setState(() => loading = true);
    try {
      final memberships = List<Map<String, dynamic>>.from(
        await supabase.from('conversation_members').select('conversation_id').eq('user_id', uid),
      );
      final directIds = <String>[];
      for (final row in memberships) {
        final id = row['conversation_id'].toString();
        final members = List<Map<String, dynamic>>.from(
          await supabase.from('conversation_members').select('user_id').eq('conversation_id', id),
        );
        if (members.length == 2) directIds.add(id);
      }
      if (!mounted) return;
      if (directIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هنوز گفتگوی دونفره‌ای ندارید.')),
        );
        return;
      }
      String? selected = directIds.first;
      final id = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('انتخاب گفتگوی محرمانه'),
          content: DropdownButtonFormField<String>(
            value: selected,
            items: directIds.map((id) => DropdownMenuItem(value: id, child: Text('گفتگو • ${id.substring(0, id.length > 8 ? 8 : id.length)}'))).toList(),
            onChanged: (value) => selected = value,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('لغو')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, selected), child: const Text('باز کردن')),
          ],
        ),
      );
      if (id == null || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SecretChatPage(conversationId: id, title: 'گفتگوی محرمانه')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('باز کردن گفتگوی محرمانه ناموفق بود: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('گفتگوی محرمانه')),
    body: Center(
      child: FilledButton.icon(
        onPressed: loading ? null : _openSecretChat,
        icon: loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.lock_rounded),
        label: const Text('انتخاب گفتگوی دونفره'),
      ),
    ),
  );
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
    }catch(e){if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('بارگذاری حذف خودکار ناموفق بود: $e')));}
    if(mounted)setState(()=>loading=false);
  }
  Future<void> _save(int seconds) async {
    final id=selected; final uid=supabase.auth.currentUser?.id; if(id==null||uid==null)return;
    setState(()=>saving=true);
    try {
      if(seconds==0){await supabase.from('message_ttl').delete().eq('conversation_id',id);} else {await supabase.from('message_ttl').upsert({'conversation_id':id,'ttl_seconds':seconds,'enabled_by':uid,'updated_at':DateTime.now().toUtc().toIso8601String()});}
      ttl[id]=seconds; if(mounted){setState((){}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تنظیم حذف خودکار ذخیره شد.')));}
    }catch(e){if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ذخیره تنظیم ناموفق بود: $e')));}finally{if(mounted)setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context){
    final current=ttl[selected]??0;
    return Scaffold(appBar:AppBar(title:const Text('حذف خودکار پیام‌ها')),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
      const Card(child:Padding(padding:EdgeInsets.all(16),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(Icons.timer_outlined),SizedBox(width:12),Expanded(child:Text('پس از انتخاب زمان، پیام‌های جدید این گفتگو در Backend زمان انقضا می‌گیرند و حذف آن‌ها توسط سرویس زمان‌بندی‌شده انجام می‌شود.'))]))),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(value:selected,decoration:const InputDecoration(labelText:'گفتگو'),items:chats.map((c)=>DropdownMenuItem(value:c['id'].toString(),child:Text((c['title']??(c['type']=='group'?'گروه':c['type']=='channel'?'کانال':'گفتگو')).toString()))).toList(),onChanged:(v)=>setState(()=>selected=v)),
      const SizedBox(height:18),
      ...options.entries.map((e)=>Card(child:RadioListTile<int>(value:e.key,groupValue:current,title:Text(e.value,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:e.key==0?const Text('پیام‌ها حذف خودکار نمی‌شوند.'):const Text('برای پیام‌های جدید'),onChanged:saving?null:(v){if(v!=null)_save(v);}))),
    ]));
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


String _normalizeSettingsPinDigits(String value) => value.runes.map((rune) {
  if (rune >= 0x06F0 && rune <= 0x06F9) return String.fromCharCode(0x30 + rune - 0x06F0);
  if (rune >= 0x0660 && rune <= 0x0669) return String.fromCharCode(0x30 + rune - 0x0660);
  return String.fromCharCode(rune);
}).join();

class AppLockSettingsPage extends StatefulWidget {
  const AppLockSettingsPage({super.key});
  @override State<AppLockSettingsPage> createState() => _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends State<AppLockSettingsPage> {
  @override
  void initState() {
    super.initState();
    _disablePinLock();
  }

  Future<void> _disablePinLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', false);
    await prefs.setBool('app_lock_biometric', false);
    await const FlutterSecureStorage().delete(key: 'app_lock_pin');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('قفل برنامه')),
    body: ListView(padding: const EdgeInsets.all(16), children: const [
      Card(child: ListTile(
        leading: Icon(Icons.lock_open_rounded),
        title: Text('قفل PIN غیرفعال است'),
        subtitle: Text('قفل عددی و قفل اثر انگشت برای ورود به پیام‌رسان خاموش است.'),
      )),
      SizedBox(height: 12),
      Text('برای ورود به پیام‌رسان، PIN برنامه درخواست نمی‌شود.'),
    ]),
  );
}
