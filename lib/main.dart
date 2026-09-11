import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://bkbdcqequyvubjmrbpqo.supabase.co';
const supabasePublishableKey = 'sb_publishable_-wIHh9FKu-lmXSMHRWBbFw_t9u5KutA';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  runApp(const AradMessengerApp());
}

class AradMessengerApp extends StatelessWidget {
  const AradMessengerApp({super.key});
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
  Widget build(BuildContext context) => Supabase.instance.client.auth.currentSession == null
      ? const LoginPage()
      : const ProfileGate();
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool obscurePassword = true;

  Future<void> signIn() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || !email.contains('@')) return _message('ایمیل را درست وارد کنید.');
    if (password.length < 6) return _message('رمز عبور باید حداقل ۶ کاراکتر باشد.');
    setState(() => loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ProfileGate()));
    } on AuthException catch (e) { _message(e.message); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> signUp() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || !email.contains('@')) return _message('ایمیل را درست وارد کنید.');
    if (password.length < 6) return _message('رمز عبور باید حداقل ۶ کاراکتر باشد.');
    setState(() => loading = true);
    try {
      final response = await Supabase.instance.client.auth.signUp(email: email, password: password);
      if (mounted) {
        if (response.session != null) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ProfileGate()));
        } else {
          _message('حساب ساخته شد. ایمیل تأیید را بررسی کنید.');
        }
      }
    } on AuthException catch (e) { _message(e.message); }
    finally { if (mounted) setState(() => loading = false); }
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() { emailController.dispose(); passwordController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.forum_rounded, size: 72),
                    const SizedBox(height: 16),
                    Text('Arad Messenger', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('ورود یا ثبت‌نام با ایمیل', textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    TextField(controller: emailController, enabled: !loading, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'ایمیل', hintText: 'example@gmail.com', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: passwordController, enabled: !loading, obscureText: obscurePassword, decoration: InputDecoration(labelText: 'رمز عبور', prefixIcon: const Icon(Icons.lock_outline), border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: () => setState(() => obscurePassword = !obscurePassword), icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off)))),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: loading ? null : signIn, child: Text(loading ? 'در حال پردازش...' : 'ورود')),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: loading ? null : signUp, child: const Text('ساخت حساب جدید')),
                  ],
                ),
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
  bool hasProfile = false;

  @override
  void initState() { super.initState(); _checkProfile(); }

  Future<void> _checkProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final row = await Supabase.instance.client.from('profiles').select('username, display_name').eq('id', user.id).maybeSingle();
      if (mounted) setState(() { hasProfile = row != null && (row['username'] ?? '').toString().isNotEmpty && (row['display_name'] ?? '').toString().isNotEmpty; loading = false; });
    } catch (_) {
      if (mounted) setState(() { loading = false; hasProfile = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return hasProfile ? const HomePage() : const ProfileSetupPage();
  }
}

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});
  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final bioController = TextEditingController();
  bool loading = false;

  Future<void> saveProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    final name = nameController.text.trim();
    final username = usernameController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (user == null) return;
    if (name.length < 2) return _message('نام خود را وارد کنید.');
    if (username.length < 3) return _message('نام کاربری باید حداقل ۳ حرف باشد.');
    setState(() => loading = true);
    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'display_name': name,
        'username': username,
        'bio': bioController.text.trim(),
        'phone': user.phone,
      });
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } on PostgrestException catch (e) {
      _message(e.message.contains('duplicate') ? 'این نام کاربری قبلاً استفاده شده است.' : e.message);
    } catch (_) { _message('ذخیره پروفایل انجام نشد.'); }
    finally { if (mounted) setState(() => loading = false); }
  }

  void _message(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
  @override
  void dispose() { nameController.dispose(); usernameController.dispose(); bioController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ساخت پروفایل')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const CircleAvatar(radius: 48, child: Icon(Icons.person, size: 52)),
                const SizedBox(height: 24),
                TextField(controller: nameController, enabled: !loading, decoration: const InputDecoration(labelText: 'نام نمایشی', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: usernameController, enabled: !loading, decoration: const InputDecoration(labelText: 'نام کاربری', prefixText: '@', prefixIcon: Icon(Icons.alternate_email), border: OutlineInputBorder(), helperText: 'فقط حروف انگلیسی، عدد و _')),
                const SizedBox(height: 12),
                TextField(controller: bioController, enabled: !loading, maxLines: 3, decoration: const InputDecoration(labelText: 'بیوگرافی (اختیاری)', border: OutlineInputBorder())),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: loading ? null : saveProfile, child: Text(loading ? 'در حال ذخیره...' : 'ادامه'))),
              ],
            ),
          ),
        ),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Arad Messenger'), actions: [IconButton(tooltip: 'خروج', onPressed: () async { await Supabase.instance.client.auth.signOut(); if (context.mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage())); }, icon: const Icon(Icons.logout))]),
        body: const Center(child: Text('پروفایل شما آماده است.\nمرحله بعد: ساخت چت و پیام‌ها.', textAlign: TextAlign.center)),
        floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.chat_rounded)),
      );
}
