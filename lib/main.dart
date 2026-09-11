import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://bkbdcqequyvubjmrbpqo.supabase.co';
const supabasePublishableKey = 'sb_publishable_-wIHh9FKu-lmXSMHRWBbFw_t9u5KutA';
late final SupabaseClient supabase;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  supabase = Supabase.instance.client;
  runApp(const AradApp());
}

class AradApp extends StatelessWidget {
  const AradApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Arad Messenger',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        home: const AuthGate(),
      );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => supabase.auth.currentSession == null ? const LoginPage() : const ProfileGate();
}

void showMsg(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool hidden = true;

  Future<void> submit(bool create) async {
    final e = email.text.trim();
    final p = password.text;
    if (!e.contains('@') || p.length < 6) {
      showMsg(context, 'ایمیل معتبر و رمز حداقل ۶ کاراکتری وارد کنید.');
      return;
    }
    setState(() => busy = true);
    try {
      if (create) {
        final result = await supabase.auth.signUp(email: e, password: p);
        if (result.session == null) {
          if (!mounted) return;
          showMsg(context, 'حساب ساخته شد. ایمیل تأیید را بررسی کنید.');
          return;
        }
      } else {
        await supabase.auth.signInWithPassword(email: e, password: p);
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const ProfileGate()), (_) => false);
    } on AuthException catch (error) {
      if (!mounted) return;
      showMsg(context, error.message);
    } catch (error) {
      if (!mounted) return;
      showMsg(context, 'خطا: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(children: [
                  const Icon(Icons.forum_rounded, size: 72),
                  const SizedBox(height: 16),
                  const Text('Arad Messenger', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('پیام‌رسان امن و سریع'),
                  const SizedBox(height: 28),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'ایمیل', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: hidden, decoration: InputDecoration(labelText: 'رمز عبور', prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: () => setState(() => hidden = !hidden), icon: Icon(hidden ? Icons.visibility : Icons.visibility_off)))),
                  const SizedBox(height: 18),
                  SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : () => submit(false), child: Text(busy ? '...' : 'ورود'))),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: OutlinedButton(onPressed: busy ? null : () => submit(true), child: const Text('ساخت حساب'))),
                ]),
              ),
            ),
          ),
        ),
      );
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});
  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  bool loading = true;
  bool ready = false;
  @override
  void initState() { super.initState(); check(); }
  Future<void> check() async {
    final user = supabase.auth.currentUser;
    if (user == null) { if (mounted) setState(() => loading = false); return; }
    try {
      final row = await supabase.from('profiles').select('username,display_name').eq('id', user.id).maybeSingle();
      ready = row != null && '${row['username'] ?? ''}'.isNotEmpty && '${row['display_name'] ?? ''}'.isNotEmpty;
    } catch (_) { ready = false; }
    if (mounted) setState(() => loading = false);
  }
  @override
  Widget build(BuildContext context) => loading ? const Scaffold(body: Center(child: CircularProgressIndicator())) : ready ? const HomePage() : const ProfileSetupPage();
}

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});
  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final name = TextEditingController();
  final username = TextEditingController();
  final bio = TextEditingController();
  bool busy = false;
  Future<void> save() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final n = name.text.trim();
    final u = username.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (n.length < 2 || u.length < 3) { showMsg(context, 'نام و نام کاربری را کامل کنید.'); return; }
    setState(() => busy = true);
    try {
      await supabase.from('profiles').upsert({'id': user.id, 'display_name': n, 'username': u, 'bio': bio.text.trim()});
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } on PostgrestException catch (error) { if (mounted) showMsg(context, error.message); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  void dispose() { name.dispose(); username.dispose(); bio.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ساخت پروفایل')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const CircleAvatar(radius: 46, child: Icon(Icons.person, size: 48)),
          const SizedBox(height: 24),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'نام نمایشی', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: username, decoration: const InputDecoration(labelText: 'نام کاربری', prefixText: '@', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: bio, maxLines: 3, decoration: const InputDecoration(labelText: 'بیوگرافی', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'در حال ذخیره...' : 'ادامه')),
        ]),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final searchController = TextEditingController();
  List<Map<String, dynamic>> chats = [];
  List<Map<String, dynamic>> users = [];
  bool loading = true;
  @override
  void initState() { super.initState(); loadChats(); setOnline(true); }

  Future<void> setOnline(bool value) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try { await supabase.from('profiles').update({'is_online': value, 'last_seen': DateTime.now().toIso8601String()}).eq('id', user.id); } catch (_) {}
  }

  Future<void> loadChats() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final memberships = await supabase.from('conversation_members').select('conversation_id').eq('user_id', user.id).order('joined_at', ascending: false);
      final result = <Map<String, dynamic>>[];
      for (final membership in memberships) {
        final conversation = await supabase.from('conversations').select().eq('id', membership['conversation_id']).maybeSingle();
        if (conversation == null) continue;
        final members = await supabase.from('conversation_members').select('user_id').eq('conversation_id', conversation['id']);
        Map<String, dynamic>? profile;
        for (final member in members) {
          if (member['user_id'] != user.id) { profile = await supabase.from('profiles').select('id,display_name,username,avatar_url,is_online,last_seen').eq('id', member['user_id']).maybeSingle(); break; }
        }
        final last = await supabase.from('messages').select('body,message_type,created_at').eq('conversation_id', conversation['id']).order('created_at', ascending: false).limit(1).maybeSingle();
        result.add({'conversation': conversation, 'profile': profile, 'last': last});
      }
      if (mounted) setState(() => chats = result);
    } catch (error) { if (mounted) showMsg(context, 'خطا در بارگذاری گفتگوها: $error'); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> searchUsers(String value) async {
    if (value.trim().length < 2) { if (mounted) setState(() => users = []); return; }
    try {
      final result = await supabase.rpc('search_profiles', params: {'search_text': value.trim()});
      if (mounted) setState(() => users = List<Map<String, dynamic>>.from(result));
    } catch (_) {}
  }

  Future<void> openDirect(Map<String, dynamic> profile) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final conversation = await supabase.from('conversations').insert({'type': 'direct', 'title': profile['display_name'], 'created_by': user.id}).select().single();
      await supabase.from('conversation_members').insert([
        {'conversation_id': conversation['id'], 'user_id': user.id, 'role': 'member'},
        {'conversation_id': conversation['id'], 'user_id': profile['id'], 'role': 'member'},
      ]);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(id: conversation['id'], title: profile['display_name'] ?? 'گفتگو'))).then((_) => loadChats());
    } catch (error) { if (mounted) showMsg(context, 'ساخت گفتگو ناموفق بود: $error'); }
  }

  Future<void> logout() async {
    await setOnline(false);
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  @override
  void dispose() { searchController.dispose(); setOnline(false); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Arad Messenger'), actions: [
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupCreatePage())).then((_) => loadChats()), icon: const Icon(Icons.group_add_outlined)),
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())), icon: const Icon(Icons.person_outline)),
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ]),
        body: Column(children: [
          Padding(padding: const EdgeInsets.all(12), child: TextField(controller: searchController, onChanged: searchUsers, decoration: const InputDecoration(hintText: 'جستجوی کاربر...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()))),
          if (users.isNotEmpty)
            Expanded(child: ListView(children: users.map((profile) => ListTile(leading: avatar(profile), title: Text('${profile['display_name'] ?? ''}'), subtitle: Text('@${profile['username'] ?? ''}'), onTap: () { searchController.clear(); setState(() => users = []); openDirect(profile); })).toList()))
          else
            Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: loadChats, child: ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final item = chats[index];
                final conversation = Map<String, dynamic>.from(item['conversation']);
                final profile = item['profile'] == null ? null : Map<String, dynamic>.from(item['profile']);
                final last = item['last'] == null ? null : Map<String, dynamic>.from(item['last']);
                final group = conversation['type'] == 'group';
                final title = group ? '${conversation['title'] ?? 'گروه'}' : '${profile?['display_name'] ?? 'گفتگو'}';
                final subtitle = last == null ? 'شروع گفتگو' : last['message_type'] == 'text' ? '${last['body'] ?? ''}' : 'فایل';
                return ListTile(leading: group ? const CircleAvatar(child: Icon(Icons.groups)) : avatar(profile), title: Text(title), subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(id: conversation['id'], title: title))).then((_) => loadChats()));
              },
            ))),
        ]),
        floatingActionButton: FloatingActionButton(onPressed: () => FocusScope.of(context).requestFocus(), child: const Icon(Icons.chat_rounded)),
      );
}

Widget avatar(Map<String, dynamic>? profile) {
  final url = profile?['avatar_url'];
  return CircleAvatar(backgroundImage: url is String && url.isNotEmpty ? NetworkImage(url) : null, child: url is String && url.isNotEmpty ? null : const Icon(Icons.person));
}

class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({super.key});
  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  final title = TextEditingController();
  final search = TextEditingController();
  final selected = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> found = [];
  bool busy = false;
  Future<void> findUsers(String value) async {
    if (value.trim().length < 2) { if (mounted) setState(() => found = []); return; }
    try { final result = await supabase.rpc('search_profiles', params: {'search_text': value.trim()}); if (mounted) setState(() => found = List<Map<String, dynamic>>.from(result)); } catch (_) {}
  }
  Future<void> createGroup() async {
    final user = supabase.auth.currentUser;
    if (user == null || title.text.trim().length < 2 || selected.isEmpty) { showMsg(context, 'نام گروه و حداقل یک عضو را انتخاب کنید.'); return; }
    setState(() => busy = true);
    try {
      final conversation = await supabase.from('conversations').insert({'type': 'group', 'title': title.text.trim(), 'created_by': user.id}).select().single();
      final members = <Map<String, dynamic>>[
        {'conversation_id': conversation['id'], 'user_id': user.id, 'role': 'admin'},
        ...selected.map((p) => {'conversation_id': conversation['id'], 'user_id': p['id'], 'role': 'member'}),
      ];
      await supabase.from('conversation_members').insert(members);
      if (mounted) Navigator.pop(context);
    } catch (error) { if (mounted) showMsg(context, 'ساخت گروه ناموفق بود: $error'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  void dispose() { title.dispose(); search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ساخت گروه')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: TextField(controller: title, decoration: const InputDecoration(labelText: 'نام گروه', border: OutlineInputBorder()))),
      Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: TextField(controller: search, onChanged: findUsers, decoration: const InputDecoration(hintText: 'افزودن اعضا...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()))),
      if (selected.isNotEmpty)
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            children: selected.map((p) => Padding(padding: const EdgeInsets.only(right: 8), child: Chip(label: Text('${p['display_name'] ?? ''}'), onDeleted: () => setState(() => selected.remove(p)))).toList(),
          ),
        ),
      Expanded(
        child: ListView(
          children: found.map((p) => ListTile(
            leading: avatar(p),
            title: Text('${p['display_name'] ?? ''}'),
            subtitle: Text('@${p['username'] ?? ''}'),
            trailing: Icon(selected.any((x) => x['id'] == p['id']) ? Icons.check_circle : Icons.add),
            onTap: () => setState(() {
              if (selected.any((x) => x['id'] == p['id'])) {
                selected.removeWhere((x) => x['id'] == p['id']);
              } else {
                selected.add(p);
              }
            }),
          )).toList(),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : createGroup, child: Text(busy ? 'در حال ساخت...' : 'ساخت گروه'))),
      ),
    ]),
  );
}

class ChatPage extends StatefulWidget {
  final String id;
  final String title;
  const ChatPage({super.key, required this.id, required this.title});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final controller = TextEditingController();
  final scroll = ScrollController();
  final picker = ImagePicker();
  List<Map<String, dynamic>> messages = [];
  RealtimeChannel? channel;
  bool loading = true;
  bool sending = false;
  String? replyTo;

  @override
  void initState() {
    super.initState();
    loadMessages();
    channel = supabase.channel('chat-${widget.id}').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: widget.id),
      callback: (_) => loadMessages(),
    ).subscribe();
  }

  Future<void> loadMessages() async {
    try {
      final rows = await supabase.from('messages').select().eq('conversation_id', widget.id).order('created_at');
      if (mounted) setState(() { messages = List<Map<String, dynamic>>.from(rows); loading = false; });
    } catch (error) {
      if (mounted) { setState(() => loading = false); showMsg(context, 'خطا در پیام‌ها: $error'); }
    }
  }

  Future<void> sendText() async {
    final body = controller.text.trim();
    final user = supabase.auth.currentUser;
    if (body.isEmpty || user == null || sending) return;
    setState(() => sending = true);
    try {
      final data = <String, dynamic>{'conversation_id': widget.id, 'sender_id': user.id, 'body': body, 'message_type': 'text'};
      if (replyTo != null) data['reply_to'] = replyTo;
      await supabase.from('messages').insert(data);
      controller.clear();
      if (mounted) setState(() => replyTo = null);
      await loadMessages();
    } catch (error) { if (mounted) showMsg(context, 'ارسال ناموفق بود: $error'); }
    finally { if (mounted) setState(() => sending = false); }
  }

  Future<void> uploadImage() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (image == null) return;
    try {
      final bytes = await image.readAsBytes();
      final path = '${user.id}/${widget.id}/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      await supabase.storage.from('chat-media').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: false));
      final message = await supabase.from('messages').insert({'conversation_id': widget.id, 'sender_id': user.id, 'body': image.name, 'message_type': 'image'}).select().single();
      await supabase.from('message_attachments').insert({'message_id': message['id'], 'storage_path': path, 'file_name': image.name, 'mime_type': 'image/*', 'file_size': bytes.length});
      await loadMessages();
    } catch (error) { if (mounted) showMsg(context, 'آپلود تصویر ناموفق بود: $error'); }
  }

  Future<void> uploadFile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    try {
      final bytes = file.bytes!;
      final path = '${user.id}/${widget.id}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      await supabase.storage.from('chat-media').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: false));
      final message = await supabase.from('messages').insert({'conversation_id': widget.id, 'sender_id': user.id, 'body': file.name, 'message_type': 'file'}).select().single();
      await supabase.from('message_attachments').insert({'message_id': message['id'], 'storage_path': path, 'file_name': file.name, 'mime_type': file.extension, 'file_size': bytes.length});
      await loadMessages();
    } catch (error) { if (mounted) showMsg(context, 'آپلود فایل ناموفق بود: $error'); }
  }

  Future<void> markRead() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await supabase.from('messages').update({'read_at': DateTime.now().toIso8601String()}).eq('conversation_id', widget.id).neq('sender_id', user.id).isFilter('read_at', null);
    } catch (_) {}
  }

  @override
  void dispose() { channel?.unsubscribe(); controller.dispose(); scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    markRead();
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(children: [
        Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
          controller: scroll,
          padding: const EdgeInsets.all(12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final mine = message['sender_id'] == supabase.auth.currentUser?.id;
            final type = '${message['message_type'] ?? 'text'}';
            return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: GestureDetector(
              onLongPress: () => setState(() => replyTo = '${message['id']}'),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxWidth: 310),
                decoration: BoxDecoration(color: mine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (type != 'text') Icon(type == 'image' ? Icons.image : Icons.attach_file), Text('${message['body'] ?? ''}')]),
              ),
            ));
          },
        )),
        if (replyTo != null) Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), color: Theme.of(context).colorScheme.surfaceContainerHighest, child: Row(children: [const Icon(Icons.reply, size: 18), const SizedBox(width: 8), const Expanded(child: Text('در حال پاسخ به پیام')), IconButton(onPressed: () => setState(() => replyTo = null), icon: const Icon(Icons.close))])),
        SafeArea(child: Row(children: [
          IconButton(onPressed: uploadImage, icon: const Icon(Icons.image_outlined)),
          IconButton(onPressed: uploadFile, icon: const Icon(Icons.attach_file)),
          Expanded(child: TextField(controller: controller, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'پیام...', border: InputBorder.none))),
          IconButton(onPressed: sending ? null : sendText, icon: const Icon(Icons.send_rounded)),
        ])),
      ]),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? profile;
  bool loading = true;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final row = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (mounted) setState(() { profile = row == null ? null : Map<String, dynamic>.from(row); loading = false; });
    } catch (error) {
      if (mounted) { setState(() => loading = false); showMsg(context, 'خطا در پروفایل: $error'); }
    }
  }
  Future<void> changeAvatar() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (image == null) return;
    try {
      final bytes = await image.readAsBytes();
      final path = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      await supabase.storage.from('avatars').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
      final url = supabase.storage.from('avatars').getPublicUrl(path);
      await supabase.from('profiles').update({'avatar_url': url}).eq('id', user.id);
      await load();
    } catch (error) { if (mounted) showMsg(context, 'تغییر تصویر ناموفق بود: $error'); }
  }
  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(appBar: AppBar(title: const Text('پروفایل')), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      GestureDetector(onTap: changeAvatar, child: avatar(profile)),
      const SizedBox(height: 16),
      Text('${profile?['display_name'] ?? ''}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      Text('@${profile?['username'] ?? ''}'),
      if ('${profile?['bio'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('${profile?['bio']}')),
      const Text('برای تغییر عکس، روی تصویر بزنید.'),
    ])));
  }
}
