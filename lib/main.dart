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
      : const HomePage();
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneController = TextEditingController();
  final codeController = TextEditingController();
  String countryCode = '+98';
  bool codeSent = false;
  bool loading = false;

  String get phone {
    var value = phoneController.text.trim().replaceAll(RegExp(r'[^0-9+]'), '');
    if (value.startsWith('00')) value = '+${value.substring(2)}';
    if (value.startsWith('0')) value = '$countryCode${value.substring(1)}';
    if (!value.startsWith('+')) value = '$countryCode$value';
    return value;
  }

  Future<void> sendCode() async {
    if (phoneController.text.trim().length < 8) {
      _message('شماره تلفن را درست وارد کنید.');
      return;
    }
    setState(() => loading = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(phone: phone);
      if (mounted) {
        setState(() => codeSent = true);
        _message('کد تأیید برای $phone ارسال شد.');
      }
    } on AuthException catch (e) {
      _message(e.message);
    } catch (_) {
      _message('ارسال کد انجام نشد. تنظیمات سرویس SMS در Supabase را بررسی کنید.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> verifyCode() async {
    if (codeController.text.trim().length < 4) {
      _message('کد تأیید را وارد کنید.');
      return;
    }
    setState(() => loading = true);
    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.sms,
        phone: phone,
        token: codeController.text.trim(),
      );
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } on AuthException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    phoneController.dispose();
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  const Text('ورود با شماره تلفن', textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  DropdownButtonFormField<String>(
                    value: countryCode,
                    decoration: const InputDecoration(labelText: 'کشور', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: '+98', child: Text('🇮🇷 ایران  +98')),
                      DropdownMenuItem(value: '+93', child: Text('🇦🇫 افغانستان  +93')),
                    ],
                    onChanged: loading ? null : (v) => setState(() => countryCode = v ?? '+98'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    enabled: !codeSent,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'شماره تلفن', hintText: 'مثلاً 09123456789', border: OutlineInputBorder()),
                  ),
                  if (codeSent) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(labelText: 'کد تأیید پیامک‌شده', border: OutlineInputBorder()),
                    ),
                    FilledButton(onPressed: loading ? null : verifyCode, child: Text(loading ? 'در حال بررسی...' : 'تأیید و ورود')),
                    TextButton(onPressed: loading ? null : () => setState(() => codeSent = false), child: const Text('تغییر شماره')),
                  ] else ...[
                    FilledButton(onPressed: loading ? null : sendCode, child: Text(loading ? 'در حال ارسال...' : 'ارسال کد تأیید')),
                  ],
                  const SizedBox(height: 12),
                  const Text('با ورود، حساب کاربری شما در Arad Messenger ساخته یا وارد می‌شود.', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Arad Messenger'),
          actions: [
            IconButton(
              tooltip: 'خروج',
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: const Center(child: Text('صفحه اصلی پیام‌رسان آماده است.')),
        floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.chat_rounded)),
      );
}
