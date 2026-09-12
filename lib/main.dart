import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://bkbdcqequyvubjmrbpqo.supabase.co';
const supabasePublishableKey = 'sb_publishable_-wIHh9FKu-lmXSMHRWBbFw_t9u5KutA';
// Set this to the Google OAuth Web client ID from Google Cloud Console.
const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');
final googleSignIn = GoogleSignIn.instance;

final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const AradMessenger());
}

class AradMessenger extends StatelessWidget {
  const AradMessenger({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Arad Messenger',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const AuthGate(),
    );
  }
}

void showMsg(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Widget avatar(Map<String, dynamic> profile, {double size = 44}) {
  final url = profile['avatar_url']?.toString() ?? '';
  return CircleAvatar(
    radius: size / 2,
    backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
    child: url.isEmpty ? const Icon(Icons.person) : null,
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session == null) return const LoginPage();

        final user = supabase.auth.currentUser;
        final verified = user?.emailConfirmedAt != null;
        if (!verified) {
          return EmailVerificationPage(
            email: user?.email ?? '',
          );
        }

        return const ProfileGate();
      },
    );
  }
}

class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key});

  Future<bool> hasProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null || user.emailConfirmedAt == null) return false;
    final uid = user.id;
    final row = await supabase.from('profiles').select('id').eq('id', uid).maybeSingle();
    return row != null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: hasProfile(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data! ? const HomePage() : const ProfileSetupPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool signup = false;
  bool busy = false;

  Future<void> signInWithGoogle() async {
    setState(() => busy = true);
    try {
      if (kIsWeb) {
        await supabase.auth.signInWithOAuth(OAuthProvider.google);
        return;
      }

      if (googleServerClientId.isEmpty) {
        throw const AuthException(
          'GOOGLE_SERVER_CLIENT_ID برای نسخه اندروید تنظیم نشده است.',
        );
      }

      await googleSignIn.initialize(serverClientId: googleServerClientId);
      final account = await googleSignIn.authenticate();
      final authentication = account.authentication;
      final idToken = authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const AuthException('Google ID Token دریافت نشد.');
      }

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } catch (e) {
      if (mounted) showMsg(context, 'ورود با گوگل ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      showMsg(context, 'ایمیل و رمز عبور را وارد کنید.');
      return;
    }
    setState(() => busy = true);
    try {
      if (signup) {
        final response = await supabase.auth.signUp(
          email: email.text.trim(),
          password: password.text,
        );
        if (!mounted) return;
        final verified = response.user?.emailConfirmedAt != null;
        if (!verified) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EmailVerificationPage(
                email: email.text.trim(),
              ),
            ),
          );
        } else {
          showMsg(context, 'ثبت‌نام با موفقیت انجام شد.');
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } catch (e) {
      if (mounted) showMsg(context, 'خطا: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.forum_rounded, size: 80),
              const SizedBox(height: 12),
              const Text('Arad Messenger', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 28),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'ایمیل', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'رمز عبور', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(busy ? 'در حال انجام...' : (signup ? 'ثبت‌نام' : 'ورود')),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('ورود با حساب Google'),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: busy ? null : () => setState(() => signup = !signup),
                child: Text(signup ? 'حساب دارم؛ ورود' : 'حساب ندارم؛ ثبت‌نام'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }
}

class EmailVerificationPage extends StatefulWidget {
  final String email;

  const EmailVerificationPage({super.key, required this.email});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final code = TextEditingController();
  bool busy = false;
  bool resending = false;

  Future<void> verify() async {
    final token = code.text.trim().replaceAll(' ', '');
    if (token.length < 6) {
      showMsg(context, 'کد تأیید را کامل وارد کنید.');
      return;
    }

    setState(() => busy = true);
    try {
      final response = await supabase.auth.verifyOTP(
        type: OtpType.signup,
        email: widget.email,
        token: token,
      );
      if (response.session == null) {
        throw const AuthException('تأیید انجام نشد. دوباره تلاش کنید.');
      }
      if (mounted) {
        showMsg(context, 'ایمیل با موفقیت تأیید شد.');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ProfileGate()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) showMsg(context, 'کد تأیید نامعتبر یا منقضی شده است: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resend() async {
    setState(() => resending = true);
    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      if (mounted) showMsg(context, 'کد جدید به ایمیل شما ارسال شد.');
    } catch (e) {
      if (mounted) showMsg(context, 'ارسال مجدد ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => resending = false);
    }
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تأیید ایمیل')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.mark_email_read_outlined, size: 72),
              const SizedBox(height: 16),
              const Text(
                'کد تأیید ارسال شد',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  children: [
                    const Text(
                      'کد تأیید برای این ایمیل ارسال شده است:',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ایمیل خود را بررسی کنید و کد ۶ رقمی را در کادر زیر وارد کنید.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: code,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'کد ۶ رقمی',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : verify,
                  child: Text(busy ? 'در حال تأیید...' : 'تأیید ایمیل'),
                ),
              ),
              TextButton(
                onPressed: resending ? null : resend,
                child: Text(resending ? 'در حال ارسال...' : 'ارسال دوباره کد'),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
  bool loading = true;
  bool busy = false;

  Future<void> load() async {
    try {
      final uid = supabase.auth.currentUser!.id;
      final row = await supabase.from('profiles').select().eq('id', uid).maybeSingle();
      if (row != null) {
        name.text = '${row['display_name'] ?? ''}';
        username.text = '${row['username'] ?? ''}';
        bio.text = '${row['bio'] ?? ''}';
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty || username.text.trim().isEmpty) {
      showMsg(context, 'نام و نام کاربری را وارد کنید.');
      return;
    }
    setState(() => busy = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      await supabase.from('profiles').upsert({
        'id': uid,
        'display_name': name.text.trim(),
        'username': username.text.trim().replaceFirst('@', ''),
        'bio': bio.text.trim(),
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
      }
    } catch (e) {
      if (mounted) showMsg(context, 'ذخیره نشد: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('پروفایل شما')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'نام نمایشی', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: username, decoration: const InputDecoration(labelText: 'نام کاربری', prefixText: '@', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: bio, maxLines: 3, decoration: const InputDecoration(labelText: 'معرفی کوتاه', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'در حال ذخیره...' : 'ادامه')),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> chats = [];
  bool loading = true;

  Future<void> load() async {
    try {
      final uid = supabase.auth.currentUser!.id;
      final members = await supabase.from('conversation_members').select('conversation_id').eq('user_id', uid);
      final ids = (members as List).map((e) => e['conversation_id']).toList();
      if (ids.isEmpty) {
        if (mounted) setState(() { chats = []; loading = false; });
        return;
      }
      final rows = await supabase.from('conversations').select().inFilter('id', ids).order('created_at', ascending: false);
      if (mounted) setState(() { chats = List<Map<String, dynamic>>.from(rows); loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        showMsg(context, 'خطا در بارگذاری گفتگوها: $e');
      }
    }
  }

  Future<void> createDirect() async {
    final result = await showSearch<Map<String, dynamic>?>(context: context, delegate: UserSearchDelegate());
    if (result == null) return;
    try {
      final uid = supabase.auth.currentUser!.id;
      final existing = await supabase.from('conversation_members').select('conversation_id').eq('user_id', uid);
      for (final r in existing) {
        final members = await supabase.from('conversation_members').select('user_id').eq('conversation_id', r['conversation_id']);
        if ((members as List).length == 2 && members.any((m) => m['user_id'] == result['id'])) {
          if (mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(id: '${r['conversation_id']}', title: '${result['display_name'] ?? result['username'] ?? 'گفتگو'}')));
          }
          return;
        }
      }
      final c = await supabase.from('conversations').insert({'type': 'direct', 'created_by': uid}).select().single();
      await supabase.from('conversation_members').insert([
        {'conversation_id': c['id'], 'user_id': uid},
        {'conversation_id': c['id'], 'user_id': result['id']},
      ]);
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(id: '${c['id']}', title: '${result['display_name'] ?? result['username'] ?? 'گفتگو'}')));
      }
      load();
    } catch (e) {
      if (mounted) showMsg(context, 'ساخت گفتگو ناموفق بود: $e');
    }
  }

  Future<void> createGroup() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupCreatePage()));
    load();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arad Messenger'),
        actions: [
          IconButton(onPressed: createDirect, icon: const Icon(Icons.person_add)),
          IconButton(onPressed: createGroup, icon: const Icon(Icons.group_add)),
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())), icon: const Icon(Icons.person)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : chats.isEmpty
              ? const Center(child: Text('هنوز گفتگویی ندارید'))
              : ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, i) {
                    final c = chats[i];
                    final title = '${c['title'] ?? (c['type'] == 'group' ? 'گروه' : 'گفتگو')}';
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.chat)),
                      title: Text(title),
                      subtitle: Text('${c['last_message'] ?? ''}'),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(id: '${c['id']}', title: title))),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(onPressed: createDirect, child: const Icon(Icons.chat)),
    );
  }
}

class UserSearchDelegate extends SearchDelegate<Map<String, dynamic>?> {
  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear))];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(onPressed: () => close(context, null), icon: const Icon(Icons.arrow_back));

  @override
  Widget buildResults(BuildContext context) => resultsWidget();

  @override
  Widget buildSuggestions(BuildContext context) => resultsWidget();

  Widget resultsWidget() {
    final q = query.trim();
    if (q.isEmpty) return const Center(child: Text('نام یا نام کاربری را جستجو کنید'));
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase.rpc('search_profiles', params: {'search_text': q}).then((v) => List<Map<String, dynamic>>.from(v)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('جستجو ناموفق بود: ${snapshot.error}'));
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) return const Center(child: Text('کاربری پیدا نشد'));
        return ListView(
          children: rows.map((p) {
            return ListTile(
              leading: avatar(p),
              title: Text('${p['display_name'] ?? ''}'),
              subtitle: Text('@${p['username'] ?? ''}'),
              onTap: () => close(context, p),
            );
          }).toList(),
        );
      },
    );
  }
}

class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({super.key});

  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  final title = TextEditingController();
  final search = TextEditingController();
  List<Map<String, dynamic>> found = [];
  List<Map<String, dynamic>> selected = [];
  bool busy = false;

  Future<void> findUsers(String q) async {
    if (q.trim().isEmpty) {
      setState(() => found = []);
      return;
    }
    try {
      final rows = await supabase.rpc('search_profiles', params: {'search_text': q.trim()});
      if (mounted) setState(() => found = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      if (mounted) showMsg(context, 'جستجو ناموفق بود: $e');
    }
  }

  Future<void> createGroup() async {
    if (title.text.trim().isEmpty || selected.isEmpty) {
      showMsg(context, 'نام گروه و حداقل یک عضو را وارد کنید.');
      return;
    }
    setState(() => busy = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      final c = await supabase.from('conversations').insert({'type': 'group', 'title': title.text.trim(), 'created_by': uid}).select().single();
      final members = <Map<String, dynamic>>[
        {'conversation_id': c['id'], 'user_id': uid},
        ...selected.map((p) => {'conversation_id': c['id'], 'user_id': p['id']}),
      ];
      await supabase.from('conversation_members').insert(members);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatPage(id: '${c['id']}', title: title.text.trim())));
      }
    } catch (e) {
      if (mounted) showMsg(context, 'ساخت گروه ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    title.dispose();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ساخت گروه')),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(12), child: TextField(controller: title, decoration: const InputDecoration(labelText: 'نام گروه', border: OutlineInputBorder()))),
          Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: TextField(controller: search, onChanged: findUsers, decoration: const InputDecoration(hintText: 'افزودن اعضا...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()))),
          if (selected.isNotEmpty)
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                children: selected.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text('${p['display_name'] ?? ''}'),
                      onDeleted: () => setState(() => selected.remove(p)),
                    ),
                  );
                }).toList(),
              ),
            ),
          Expanded(
            child: ListView(
              children: found.map((p) {
                final isSelected = selected.any((x) => x['id'] == p['id']);
                return ListTile(
                  leading: avatar(p),
                  title: Text('${p['display_name'] ?? ''}'),
                  subtitle: Text('@${p['username'] ?? ''}'),
                  trailing: Icon(isSelected ? Icons.check_circle : Icons.add),
                  onTap: () => setState(() {
                    if (isSelected) {
                      selected.removeWhere((x) => x['id'] == p['id']);
                    } else {
                      selected.add(p);
                    }
                  }),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : createGroup, child: Text(busy ? 'در حال ساخت...' : 'ساخت گروه'))),
          ),
        ],
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String id;
  final String title;

  const ChatPage({super.key, required this.id, required this.title});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final text = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  RealtimeChannel? channel;
  bool loading = true;
  bool sending = false;

  Future<void> load() async {
    try {
      final rows = await supabase.from('messages').select().eq('conversation_id', widget.id).order('created_at');
      if (mounted) setState(() { messages = List<Map<String, dynamic>>.from(rows); loading = false; });
      await markRead();
    } catch (e) {
      if (mounted) { setState(() => loading = false); showMsg(context, 'خطا در پیام‌ها: $e'); }
    }
  }

  Future<void> markRead() async {
    try {
      final rows = await supabase.from('messages').select('id').eq('conversation_id', widget.id).neq('sender_id', supabase.auth.currentUser!.id);\n      for (final row in rows) {\n        await supabase.rpc('mark_message_read', params: {'p_message_id': row['id']});\n      }
    } catch (_) {}
  }

  Future<void> sendText() async {
    final value = text.text.trim();
    if (value.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await supabase.from('messages').insert({'conversation_id': widget.id, 'sender_id': supabase.auth.currentUser!.id, 'body': value, 'message_type': 'text'});
      text.clear();
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'ارسال نشد: $e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> sendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null) return;
      final f = result.files.single;
      final bytes = f.bytes;
      if (bytes == null) return;
      final path = '${widget.id}/${DateTime.now().millisecondsSinceEpoch}_${f.name}';
      await supabase.storage.from('chat-media').uploadBinary(path, bytes);
      final msg = await supabase.from('messages').insert({'conversation_id': widget.id, 'sender_id': supabase.auth.currentUser!.id, 'body': f.name, 'message_type': 'file'}).select().single();
      await supabase.from('message_attachments').insert({'message_id': msg['id'], 'storage_path': path, 'file_name': f.name, 'file_size': f.size});
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'فایل ارسال نشد: $e');
    }
  }

  Future<void> sendImage() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final path = '${widget.id}/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      await supabase.storage.from('chat-media').uploadBinary(path, bytes);
      final msg = await supabase.from('messages').insert({'conversation_id': widget.id, 'sender_id': supabase.auth.currentUser!.id, 'body': image.name, 'message_type': 'image'}).select().single();
      await supabase.from('message_attachments').insert({'message_id': msg['id'], 'storage_path': path, 'file_name': image.name, 'mime_type': 'image'});
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'تصویر ارسال نشد: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    load();
    channel = supabase.channel('chat-${widget.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: widget.id),
        callback: (_) => load(),
      )
      .subscribe();
  }

  @override
  void dispose() {
    if (channel != null) supabase.removeChannel(channel!);
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      final mine = m['sender_id'] == supabase.auth.currentUser!.id;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (m['message_type'] == 'image') const Icon(Icons.image),
                                Text('${m['body'] ?? ''}'),
                                if (mine) Icon(m['read_at'] != null ? Icons.done_all : Icons.done, size: 16),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(onPressed: sendImage, icon: const Icon(Icons.image)),
                IconButton(onPressed: sendFile, icon: const Icon(Icons.attach_file)),
                Expanded(child: TextField(controller: text, decoration: const InputDecoration(hintText: 'پیام...', border: OutlineInputBorder()))),
                IconButton(onPressed: sending ? null : sendText, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
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

  Future<void> load() async {
    final row = await supabase.from('profiles').select().eq('id', supabase.auth.currentUser!.id).maybeSingle();
    if (mounted) setState(() => profile = row);
  }

  Future<void> avatarUpload() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final path = '${supabase.auth.currentUser!.id}/avatar.jpg';
      await supabase.storage.from('avatars').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
      final url = supabase.storage.from('avatars').getPublicUrl(path);
      await supabase.from('profiles').update({'avatar_url': '$url?x=${DateTime.now().millisecondsSinceEpoch}'}).eq('id', supabase.auth.currentUser!.id);
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'تصویر پروفایل ذخیره نشد: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('پروفایل')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: Stack(children: [avatar(p, size: 96), Positioned(bottom: 0, right: 0, child: IconButton.filled(onPressed: avatarUpload, icon: const Icon(Icons.camera_alt)))])),
          const SizedBox(height: 20),
          Text('${p['display_name'] ?? ''}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text('@${p['username'] ?? ''}'),
          const SizedBox(height: 8),
          Text('${p['bio'] ?? ''}'),
          const SizedBox(height: 30),
          FilledButton.tonal(onPressed: () => supabase.auth.signOut(), child: const Text('خروج')),
        ],
      ),
    );
  }
}
