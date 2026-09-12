// Auth OTP flow: email code + owner authorization.
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


String t(String key, String locale) {
  const data = {
    'fa': {'login':'ورود','signup':'ثبت‌نام','email':'ایمیل','password':'رمز عبور','google':'ورود با حساب Google','profile':'پروفایل شما','continue':'ادامه','settings':'تنظیمات','language':'زبان'},
    'en': {'login':'Login','signup':'Sign up','email':'Email','password':'Password','google':'Continue with Google','profile':'Your profile','continue':'Continue','settings':'Settings','language':'Language'},
    'ar': {'login':'تسجيل الدخول','signup':'إنشاء حساب','email':'البريد الإلكتروني','password':'كلمة المرور','google':'المتابعة باستخدام Google','profile':'ملفك الشخصي','continue':'متابعة','settings':'الإعدادات','language':'اللغة'},
    'tr': {'login':'Giriş','signup':'Kayıt ol','email':'E-posta','password':'Şifre','google':'Google ile devam et','profile':'Profiliniz','continue':'Devam','settings':'Ayarlar','language':'Dil'},
    'fr': {'login':'Connexion','signup':'Inscription','email':'E-mail','password':'Mot de passe','google':'Continuer avec Google','profile':'Votre profil','continue':'Continuer','settings':'Paramètres','language':'Langue'},
    'de': {'login':'Anmelden','signup':'Registrieren','email':'E-Mail','password':'Passwort','google':'Mit Google fortfahren','profile':'Ihr Profil','continue':'Weiter','settings':'Einstellungen','language':'Sprache'},
  };
  return data[locale]?[key] ?? data['en']![key] ?? key;
}

class LanguageController extends ChangeNotifier {
  Locale locale = const Locale('fa');
  Future<void> load() async { final p = await SharedPreferences.getInstance(); locale = Locale(p.getString('locale') ?? 'fa'); notifyListeners(); }
  Future<void> setLocale(String code) async { locale = Locale(code); final p = await SharedPreferences.getInstance(); await p.setString('locale', code); notifyListeners(); }
}

class AppStrings {
  static const supported = ['fa', 'en', 'ar', 'tr', 'fr', 'de'];
  static const names = {'fa':'فارسی','en':'English','ar':'العربية','tr':'Türkçe','fr':'Français','de':'Deutsch'};
}


const supabaseUrl = 'https://bkbdcqequyvubjmrbpqo.supabase.co';
const supabasePublishableKey = 'sb_publishable_-wIHh9FKu-lmXSMHRWBbFw_t9u5KutA';
// Set this to the Google OAuth Web client ID from Google Cloud Console.
const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');
final googleSignIn = GoogleSignIn.instance;

final supabase = Supabase.instance.client;

String? authRedirectUrl() {
  if (!kIsWeb) return null;
  final uri = Uri.base;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri.origin;
}

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
      locale: const Locale('fa'),
      supportedLocales: AppStrings.supported.map((x) => Locale(x)),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      title: 'Arad Messenger',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17181C),
          ),
          iconTheme: IconThemeData(color: Color(0xFF30323A)),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            side: BorderSide(color: Color(0xFFE6E8EF)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFFD9DCE6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFFD9DCE6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFF4F46E5), width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFFD32F2F)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFFD32F2F), width: 1.8),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: const BorderSide(color: Color(0xFFD2D5DF)),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 2,
          shape: StadiumBorder(),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          insetPadding: const EdgeInsets.all(16),
        ),
        dividerTheme: const DividerThemeData(
          space: 1,
          thickness: 1,
          color: Color(0xFFE7E8EE),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

void showMsg(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

String normalizeOtpDigits(String value) {
  return value
      .replaceAll('۰', '0')
      .replaceAll('۱', '1')
      .replaceAll('۲', '2')
      .replaceAll('۳', '3')
      .replaceAll('۴', '4')
      .replaceAll('۵', '5')
      .replaceAll('۶', '6')
      .replaceAll('۷', '7')
      .replaceAll('۸', '8')
      .replaceAll('۹', '9')
      .replaceAll('٠', '0')
      .replaceAll('١', '1')
      .replaceAll('٢', '2')
      .replaceAll('٣', '3')
      .replaceAll('٤', '4')
      .replaceAll('٥', '5')
      .replaceAll('٦', '6')
      .replaceAll('٧', '7')
      .replaceAll('٨', '8')
      .replaceAll('٩', '9');
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
        final meta = user?.appMetadata ?? const <String, dynamic>{};
        final role = meta['role']?.toString().toLowerCase();
        final privileged = role == 'owner' || role == 'admin' ||
            meta['owner'] == true ||
            meta['owner']?.toString().toLowerCase() == 'true';
        final verified = user?.emailConfirmedAt != null || privileged;
        if (!verified) {
          return EmailVerificationPage(
            email: user?.email ?? '',
            verificationType: OtpType.email,
            allowCreateUser: false,
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
    if (user == null) return false;
    final meta = user.appMetadata;
    final role = meta['role']?.toString().toLowerCase();
    final privileged = role == 'owner' || role == 'admin' ||
        meta['owner'] == true ||
        meta['owner']?.toString().toLowerCase() == 'true';
    if (user.emailConfirmedAt == null && !privileged) return false;
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
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  bool signup = true;
  bool ownerMode = false;
  bool busy = false;

  Future<void> signInWithGoogle() async {
    if (googleServerClientId.isEmpty && !kIsWeb) {
      showMsg(context, 'ورود با Google هنوز در نسخه اندروید تنظیم نشده است.');
      return;
    }
    setState(() => busy = true);
    try {
      if (kIsWeb) {
        await supabase.auth.signInWithOAuth(OAuthProvider.google);
        return;
      }

      if (googleServerClientId.isEmpty) {
        throw const AuthException(
          'ورود با Google هنوز تنظیم نشده است. Client ID گوگل باید در نسخه اندروید قرار بگیرد.',
        );
      }

      await googleSignIn.initialize(serverClientId: googleServerClientId);
      final account = await googleSignIn.authenticate();
      final authentication = account.authentication;
      final idToken = authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const AuthException('Google ID Token دریافت نشد.');
      }

      const scopes = <String>[
        'openid',
        'https://www.googleapis.com/auth/userinfo.email',
        'https://www.googleapis.com/auth/userinfo.profile',
      ];
      final authorization = await account.authorizationClient.authorizeScopes(scopes);
      final accessToken = authorization.accessToken;
      if (accessToken.isEmpty) {
        throw const AuthException('Google Access Token دریافت نشد.');
      }

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      if (mounted) showMsg(context, 'ورود با گوگل ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> ownerLogin() async {
    final mail = email.text.trim();

    if (mail.isEmpty) {
      showMsg(context, 'ایمیل مالک را وارد کنید.');
      return;
    }

    setState(() => busy = true);
    try {
      await supabase.auth.signInWithOtp(
        email: mail.toLowerCase(),
        shouldCreateUser: false,
      );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmailVerificationPage(
            email: mail.toLowerCase(),
            verificationType: OtpType.email,
            allowCreateUser: false,
            ownerOnly: true,
          ),
        ),
      );
    } on AuthException catch (e) {
      if (mounted) showMsg(context, 'ارسال کد مالک ناموفق بود: ${e.message}');
    } catch (e) {
      if (mounted) showMsg(context, 'ارسال کد مالک ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    final first = firstName.text.trim();
    final last = lastName.text.trim();
    final mail = email.text.trim();

    if (signup && (first.isEmpty || last.isEmpty)) {
      showMsg(context, 'نام و نام خانوادگی را وارد کنید.');
      return;
    }
    if (mail.isEmpty) {
      showMsg(context, 'ایمیل را وارد کنید.');
      return;
    }

    setState(() => busy = true);
    try {
      await supabase.auth.signInWithOtp(
        email: mail,
        shouldCreateUser: signup,
        data: signup
            ? {
                'first_name': first,
                'last_name': last,
                'full_name': '$first $last',
              }
            : null,
      );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmailVerificationPage(
            email: mail.toLowerCase(),
            verificationType: OtpType.email,
            allowCreateUser: signup,
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final m = e.message.toLowerCase();
      if (m.contains('user not found') || m.contains('not found')) {
        showMsg(context, 'این ایمیل ثبت نشده است. ابتدا ثبت‌نام کنید.');
      } else if (m.contains('rate limit') || m.contains('too many') || m.contains('60')) {
        showMsg(context, 'تعداد درخواست‌ها زیاد است. حداقل ۶۰ ثانیه صبر کنید.');
      } else {
        showMsg(context, 'ارسال کد ناموفق بود: ${e.message}');
      }
    } catch (e) {
      if (mounted) showMsg(context, 'ارسال کد ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                            color: theme.colorScheme.primary.withValues(alpha: 0.18),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.forum_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Arad Messenger',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ownerMode ? 'ورود امن مالک' : (signup ? 'ساخت حساب جدید' : 'خوش آمدید'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (signup && !ownerMode) ...[
                            TextField(
                              controller: firstName,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'نام',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: lastName,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'نام خانوادگی',
                                prefixIcon: const Icon(Icons.badge_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'ایمیل',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (signup) ...[
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 17,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    'پس از ارسال، یک کد ۶ رقمی به ایمیل شما می‌آید و بعد از رقم ششم خودکار بررسی می‌شود.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: busy ? null : (ownerMode ? ownerLogin : submit),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(
                                      ownerMode ? 'ورود امن مالک' : (signup ? 'ثبت‌نام و دریافت کد' : 'ورود'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          if (!ownerMode) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: busy ? null : signInWithGoogle,
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.g_mobiledata, size: 28),
                              label: const Text(
                                'ورود با حساب Google',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          ],
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                      ownerMode = !ownerMode;
                                      signup = false;
                                    }),
                            icon: Icon(
                              ownerMode
                                  ? Icons.lock_open_rounded
                                  : Icons.admin_panel_settings_outlined,
                              size: 19,
                            ),
                            label: Text(
                              ownerMode ? 'بازگشت به ورود عادی' : 'ورود مالک',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: busy || ownerMode ? null : () => setState(() => signup = !signup),
                    child: Text(
                      ownerMode ? 'ورود مالک فعال است' : (signup ? 'حساب دارم؛ ورود' : 'حساب ندارم؛ ثبت‌نام'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    super.dispose();
  }
}

class EmailVerificationPage extends StatefulWidget {
  final String email;
  final OtpType verificationType;
  final bool allowCreateUser;
  final bool ownerOnly;

  const EmailVerificationPage({
    super.key,
    required this.email,
    this.verificationType = OtpType.email,
    this.allowCreateUser = false,
    this.ownerOnly = false,
  });

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final code = TextEditingController();
  bool busy = false;
  bool resending = false;
  int resendCount = 0;
  int resendCooldown = 60;
  Timer? resendTimer;
  static const int maxResends = 3;

  Future<void> verify() async {
    final token = normalizeOtpDigits(code.text).replaceAll(RegExp(r'\s+'), '');
    if (token != code.text) {
      code.value = TextEditingValue(
        text: token,
        selection: TextSelection.collapsed(offset: token.length),
      );
    }
    if (token.length != 6 || !RegExp(r'^\d{6}$').hasMatch(token)) {
      showMsg(context, 'کد تأیید باید دقیقاً ۶ رقم باشد.');
      return;
    }
    if (busy) return;

    setState(() => busy = true);
    try {
      final response = await supabase.auth.verifyOTP(
        type: OtpType.email,
        email: widget.email.trim().toLowerCase(),
        token: token,
      );

      if (response.session == null || supabase.auth.currentSession == null) {
        throw const AuthException('تأیید کد انجام نشد. دوباره تلاش کنید.');
      }

      if (widget.ownerOnly) {
        final user = supabase.auth.currentUser;
        if (user == null) {
          throw const AuthException('حساب مالک پیدا نشد.');
        }
        final adminRow = await supabase
            .from('admin_users')
            .select('user_id')
            .eq('user_id', user.id)
            .maybeSingle();
        if (adminRow == null) {
          await supabase.auth.signOut();
          throw const AuthException('این ایمیل دسترسی مالک ندارد.');
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ProfileGate()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      showMsg(context, 'تأیید کد ناموفق بود: ${e.message}');
      code.clear();
    } catch (e) {
      if (!mounted) return;
      showMsg(context, 'تأیید کد ناموفق بود: $e');
      code.clear();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void startResendCooldown() {
    resendTimer?.cancel();
    setState(() => resendCooldown = 60);
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (resendCooldown <= 1) {
        timer.cancel();
        setState(() => resendCooldown = 0);
      } else {
        setState(() => resendCooldown--);
      }
    });
  }

  Future<void> resend() async {
    if (resendCount >= maxResends || resending || resendCooldown > 0) {
      showMsg(context, resendCooldown > 0
          ? 'برای ارسال مجدد $resendCooldown ثانیه صبر کنید.'
          : 'سقف ارسال مجدد کد تمام شده است.');
      return;
    }
    setState(() => resending = true);
    try {
      await supabase.auth.signInWithOtp(
        email: widget.email.trim().toLowerCase(),
        shouldCreateUser: widget.allowCreateUser,
      );
      if (!mounted) return;
      setState(() => resendCount++);
      startResendCooldown();
      code.clear();
      showMsg(context, 'کد ۶ رقمی جدید ارسال شد.');
    } on AuthException catch (e) {
      if (mounted) showMsg(context, 'ارسال کد ناموفق بود: ${e.message}');
    } catch (e) {
      if (mounted) showMsg(context, 'ارسال کد ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => resending = false);
    }
  }

  @override
  void initState() {
    super.initState();
    startResendCooldown();
  }

  @override
  void dispose() {
    resendTimer?.cancel();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('تأیید ایمیل')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'کد تأیید ارسال شد',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            'کد ۶ رقمی برای این ایمیل ارسال شده است:',
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
                            'بعد از وارد کردن رقم ششم، کد خودکار بررسی می‌شود و در صورت درست بودن وارد برنامه می‌شوید.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: code,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                    ),
                    onChanged: (value) {
                      if (value.length == 6 && !busy) {
                        verify();
                      }
                    },
                    onSubmitted: (_) {
                      if (!busy) verify();
                    },
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: 'کد ۶ رقمی',
                      hintText: '۱۲۳۴۵۶',
                      prefixIcon: const Icon(Icons.password_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : verify,
                      child: Text(busy ? 'در حال تأیید...' : 'تأیید و ورود'),
                    ),
                  ),
                  TextButton(
                    onPressed: (resending || resendCount >= maxResends || resendCooldown > 0) ? null : resend,
                    child: Text(
                      resending
                          ? 'در حال ارسال کد...'
                          : resendCount >= maxResends
                              ? 'سقف ارسال مجدد تمام شد'
                              : resendCooldown > 0
                                  ? 'ارسال مجدد تا $resendCooldown ثانیه دیگر'
                                  : 'ارسال مجدد کد (${maxResends - resendCount})',
                    ),
                  ),
                ],
              ),
            ),
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
      final user = supabase.auth.currentUser!;
      final row = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (row != null) {
        name.text = '${row['display_name'] ?? ''}';
        username.text = '${row['username'] ?? ''}';
        bio.text = '${row['bio'] ?? ''}';
      } else {
        final metadata = user.userMetadata ?? <String, dynamic>{};
        final fullName = (metadata['full_name'] ?? '').toString().trim();
        if (fullName.isNotEmpty) {
          name.text = fullName;
        }
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
              ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.forum_outlined,
                        size: 42,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'هنوز گفتگویی ندارید',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'با پیدا کردن یک کاربر، اولین گفتگوی خود را شروع کنید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: createDirect,
                      icon: const Icon(Icons.add_comment_outlined),
                      label: const Text('شروع گفتگوی جدید'),
                    ),
                  ],
                ),
              ),
            )
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
      final rows = await supabase.from('messages').select('id').eq('conversation_id', widget.id).neq('sender_id', supabase.auth.currentUser!.id);
      for (final row in rows) {
        await supabase.rpc('mark_message_read', params: {'p_message_id': row['id']});
      }
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
