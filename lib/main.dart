// Auth OTP flow: email code + owner authorization.
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'invite.dart';


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

class AppThemeController extends ChangeNotifier {
  bool dark = false;
  int seed = 0xFF4F46E5;
  Future<void> load() async { final p = await SharedPreferences.getInstance(); dark = p.getBool('dark_mode') ?? false; seed = p.getInt('accent_seed') ?? 0xFF4F46E5; notifyListeners(); }
  Future<void> setDark(bool value) async { dark = value; final p = await SharedPreferences.getInstance(); await p.setBool('dark_mode', value); notifyListeners(); }
  Future<void> setSeed(int value) async { seed = value; final p = await SharedPreferences.getInstance(); await p.setInt('accent_seed', value); notifyListeners(); }
}
final appTheme = AppThemeController();

final aradLanguageController = LanguageController();

class AppStrings {
  static const supported = ['fa', 'en', 'ar', 'tr', 'fr', 'de'];
  static const names = {'fa':'فارسی','en':'English','ar':'العربية','tr':'Türkçe','fr':'Français','de':'Deutsch'};
}


const supabaseUrl = 'https://bkbdcqequyvubjmrbpqo.supabase.co';
const supabasePublishableKey = 'sb_publishable_-wIHh9FKu-lmXSMHRWBbFw_t9u5KutA';
// Set this to the Google OAuth Web client ID from Google Cloud Console.
const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');
const ownerEmail = String.fromEnvironment('OWNER_EMAIL', defaultValue: 'harad896@gmail.com');
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
  await appTheme.load();
  await aradLanguageController.load();
  runApp(const AradMessenger());
}

class AradMessenger extends StatelessWidget {
  const AradMessenger({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: Listenable.merge([appTheme, aradLanguageController]), builder: (context, _) => MaterialApp(
      locale: aradLanguageController.locale,
      supportedLocales: AppStrings.supported.map((x) => Locale(x)),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      title: 'Arad Messenger',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(appTheme.seed),
          brightness: Brightness.light,
          surface: const Color(0xFFF8FAFD),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFD),
        visualDensity: VisualDensity.standard,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xE6F8FAFD),
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
          color: Color(0xF2FFFFFF),
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            side: BorderSide(color: Color(0x1A4F46E5)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xF2FFFFFF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: Color(0x1F30323A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: Color(0x1F30323A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: Color(0xFF4F46E5), width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: Color(0xFFD32F2F)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: Color(0xFFD32F2F), width: 1.6),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            side: const BorderSide(color: Color(0x2630323A)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 1,
          shape: StadiumBorder(),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          insetPadding: const EdgeInsets.all(16),
        ),
        dividerTheme: const DividerThemeData(
          space: 1,
          thickness: 1,
          color: Color(0x16000000),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(appTheme.seed),
          brightness: Brightness.dark,
          surface: const Color(0xFF101214),
        ),
        scaffoldBackgroundColor: const Color(0xFF101214),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xE6101214),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Color(0xE617191B),
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            side: BorderSide(color: Color(0x1FFFFFFF)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xE617191B),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: Color(0x22FFFFFF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: Color(0x22FFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: Color(0xFF7C83FF), width: 1.6),
          ),
        ),
      ),
      themeMode: appTheme.dark ? ThemeMode.dark : ThemeMode.light,
      home: const AuthGate(),
    ));
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

const _accountEmailsKey = 'arad_account_emails';

Future<List<String>> _savedAccountEmails() async {
  final p = await SharedPreferences.getInstance();
  return p.getStringList(_accountEmailsKey) ?? <String>[];
}

Future<void> _rememberAccount(String email) async {
  final normalized = email.trim().toLowerCase();
  if (normalized.isEmpty) return;
  final p = await SharedPreferences.getInstance();
  final accounts = p.getStringList(_accountEmailsKey) ?? <String>[];
  accounts.removeWhere((e) => e.toLowerCase() == normalized);
  accounts.insert(0, normalized);
  await p.setStringList(_accountEmailsKey, accounts.take(3).toList());
}

Future<void> _removeSavedAccount(String email) async {
  final p = await SharedPreferences.getInstance();
  final accounts = p.getStringList(_accountEmailsKey) ?? <String>[];
  accounts.removeWhere((e) => e.toLowerCase() == email.toLowerCase());
  await p.setStringList(_accountEmailsKey, accounts);
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
  final country = TextEditingController();
  String selectedCountry = 'افغانستان';
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
    if (mail.toLowerCase() != ownerEmail.toLowerCase()) {
      showMsg(context, 'این ایمیل، ایمیل مالک نیست.');
      return;
    }

    setState(() => busy = true);
    try {
      await supabase.auth.signOut();
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
    if (signup && selectedCountry.trim().isEmpty) {
      showMsg(context, 'کشور خود را انتخاب کنید.');
      return;
    }

    setState(() => busy = true);
    try {
      await supabase.auth.signOut();
      await supabase.auth.signInWithOtp(
        email: mail.toLowerCase(),
        shouldCreateUser: signup,
        data: signup
            ? {
                'first_name': first,
                'last_name': last,
                'full_name': '$first $last',
                'country': selectedCountry,
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
                            DropdownButtonFormField<String>(
                              initialValue: selectedCountry,
                              decoration: const InputDecoration(
                                labelText: 'کشور',
                                prefixIcon: Icon(Icons.public),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                'افغانستان',
                                'ایران',
                                'پاکستان',
                                'هند',
                                'ترکیه',
                                'آلمان',
                                'فرانسه',
                                'انگلستان',
                                'آمریکا',
                                'کانادا',
                                'استرالیا',
                                'امارات متحده عربی',
                                'عراق',
                                'تاجیکستان',
                                'ازبکستان',
                                'صربستان',
                              ].map((c) => DropdownMenuItem<String>(
                                value: c,
                                child: Text(c),
                              )).toList(),
                              onChanged: busy ? null : (value) {
                                if (value != null) setState(() => selectedCountry = value);
                              },
                            ),
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
                                    'پس از ارسال، یک کد دقیقاً ۶ رقمی به ایمیل شما می‌آید. کد فقط با زدن «تأیید و ورود» بررسی می‌شود.',
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
    country.dispose();
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
  bool _verificationStarted = false;
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
    if (busy || _verificationStarted) return;

    _verificationStarted = true;
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

      await _rememberAccount(widget.email);

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
      _verificationStarted = false;
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

  Widget _voicePlayButton(String messageId) {
    return IconButton(
      icon: const Icon(Icons.play_circle_fill_rounded),
      tooltip: 'پخش پیام صوتی',
      onPressed: () async {
        try {
          final row = await supabase.from('message_attachments').select('storage_path').eq('message_id', messageId).maybeSingle();
          final path = row?['storage_path']?.toString() ?? '';
          if (path.isEmpty) return;
          final url = supabase.storage.from('chat-media').getPublicUrl(path);
          await _voicePlayer.stop();
          await _voicePlayer.play(UrlSource(url));
        } catch (e) {
          if (mounted) showMsg(context, 'پخش ویس ناموفق بود: $e');
        }
      },
    );
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
                            'کد فقط وقتی بررسی می‌شود که روی «تأیید و ورود» بزنید. کدهای قبلی یا منقضی‌شده قابل استفاده نیستند.',
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
                    textDirection: TextDirection.ltr,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]')),
                    ],
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                    ),
                    onChanged: (value) {
                      final normalized = normalizeOtpDigits(value);
                      if (normalized != value) {
                        code.value = TextEditingValue(
                          text: normalized,
                          selection: TextSelection.collapsed(offset: normalized.length),
                        );
                      }
                    },
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: 'کد ۶ رقمی',
                      hintText: '------',
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
  XFile? avatarImage;
  Uint8List? avatarBytes;
  String? existingAvatarUrl;
  bool loading = true;
  bool busy = false;

  Future<void> load() async {
    try {
      final user = supabase.auth.currentUser!;
      final row = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      if (row != null) {
        existingAvatarUrl = '${row['avatar_url'] ?? ''}';
        name.text = '${row['display_name'] ?? ''}';
        username.text = '${row['username'] ?? ''}';
        bio.text = '${row['bio'] ?? ''}';
      } else {
        final metadata = user.userMetadata ?? <String, dynamic>{};
        final fullName = (metadata['full_name'] ?? '').toString().trim();
        if (fullName.isNotEmpty) name.text = fullName;
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> pickAvatar(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source, imageQuality: 88, maxWidth: 900, maxHeight: 900);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (mounted) setState(() { avatarImage = image; avatarBytes = bytes; });
    } catch (e) {
      if (mounted) showMsg(context, 'انتخاب عکس ناموفق بود: $e');
    }
  }

  Future<void> chooseAvatar() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('دوربین'), onTap: () { Navigator.pop(context); pickAvatar(ImageSource.camera); }),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('گالری'), onTap: () { Navigator.pop(context); pickAvatar(ImageSource.gallery); }),
        ]),
      ),
    );
  }

  Future<void> save() async {
    final displayName = name.text.trim();
    final userName = username.text.trim().replaceFirst('@', '');
    if (displayName.isEmpty) { showMsg(context, 'نام نمایشی را وارد کنید.'); return; }
    setState(() => busy = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      final data = <String, dynamic>{
        'id': uid,
        'display_name': displayName,
        'username': userName,
        'bio': bio.text.trim(),
        'country': '${supabase.auth.currentUser?.userMetadata?['country'] ?? ''}',
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
      };
      if (avatarImage != null) {
        final bytes = avatarBytes ?? await avatarImage!.readAsBytes();
        final path = '$uid/avatar.jpg';
        await supabase.storage.from('avatars').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
        data['avatar_url'] = '${supabase.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
      }
      await supabase.from('profiles').upsert(data);
      if (mounted) { showMsg(context, 'پروفایل با موفقیت ذخیره شد.'); Navigator.pop(context); }
    } catch (e) {
      if (mounted) showMsg(context, 'ذخیره پروفایل ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { name.dispose(); username.dispose(); bio.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('پروفایل شما')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: GestureDetector(
            onTap: chooseAvatar,
            child: Stack(clipBehavior: Clip.none, children: [
              CircleAvatar(
                radius: 58,
                backgroundImage: avatarBytes != null ? MemoryImage(avatarBytes!) : (existingAvatarUrl != null && existingAvatarUrl!.isNotEmpty ? NetworkImage(existingAvatarUrl!) : null),
                child: avatarBytes == null && (existingAvatarUrl == null || existingAvatarUrl!.isEmpty) ? const Icon(Icons.person, size: 58) : null,
              ),
              const Positioned(bottom: -4, right: -4, child: CircleAvatar(radius: 20, child: Icon(Icons.camera_alt, size: 20))),
            ]),
          )),
          const SizedBox(height: 22),
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
  int selectedFilter = 0;
  int navIndex = 0;

  List<Map<String, dynamic>> get visibleChats {
    if (selectedFilter == 0) return chats;
    final type = selectedFilter == 1 ? 'direct' : selectedFilter == 2 ? 'group' : 'channel';
    return chats.where((c) => c['type'].toString() == type).toList();
  }

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
      if (mounted) { setState(() => loading = false); showMsg(context, 'خطا در بارگذاری گفتگوها: ' + e.toString()); }
    }
  }

  Future<void> createDirect() async {
    final result = await showSearch<Map<String, dynamic>?>(context: context, delegate: UserSearchDelegate());
    if (result == null) return;
    try {
      final uid = supabase.auth.currentUser!.id;
      if (result['id'].toString() == uid) { showMsg(context, 'نمی‌توانید با خودتان گفتگوی شخصی بسازید.'); return; }
      final existing = await supabase.from('conversation_members').select('conversation_id').eq('user_id', uid);
      for (final r in existing) {
        final members = await supabase.from('conversation_members').select('user_id').eq('conversation_id', r['conversation_id']);
        if ((members as List).length == 2 && members.any((m) => m['user_id'] == result['id'])) {
          if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(id: r['conversation_id'].toString(), title: (result['display_name'] ?? result['username'] ?? 'گفتگو').toString())));
          return;
        }
      }
      final c = await supabase.from('conversations').insert({'type': 'direct', 'created_by': uid}).select().single();
      await supabase.from('conversation_members').insert([
        {'conversation_id': c['id'], 'user_id': uid},
        {'conversation_id': c['id'], 'user_id': result['id']},
      ]);
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(id: c['id'].toString(), title: (result['display_name'] ?? result['username'] ?? 'گفتگو').toString())));
      load();
    } catch (e) { if (mounted) showMsg(context, 'ساخت گفتگو ناموفق بود: ' + e.toString()); }
  }

  Future<void> createGroup() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupCreatePage()));
    load();
  }

  @override
  void initState() { super.initState(); load(); }

  Widget chatsView() {
    final theme = Theme.of(context);
    return Column(
      children: [
        const _StoriesStrip(),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
          child: Row(children: [
            const Expanded(child: Text('گفتگوها', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900))),
            IconButton.filledTonal(onPressed: createDirect, icon: const Icon(Icons.edit_rounded)),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: List.generate(4, (i) {
            const labels = ['تمامی گفتگوها', 'مخاطبین', 'گروه‌ها', 'کانال‌ها'];
            const icons = [Icons.forum_rounded, Icons.person_rounded, Icons.groups_rounded, Icons.campaign_rounded];
            return Padding(
              padding: const EdgeInsets.only(left: 7),
              child: ChoiceChip(
                selected: selectedFilter == i,
                avatar: Icon(icons[i], size: 17),
                label: Text(labels[i]),
                onSelected: (_) => setState(() => selectedFilter = i),
              ),
            );
          })),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : visibleChats.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      CircleAvatar(radius: 42, backgroundColor: theme.colorScheme.primaryContainer, child: Icon(Icons.forum_rounded, size: 40, color: theme.colorScheme.primary)),
                      const SizedBox(height: 16),
                      const Text('هنوز گفتگویی ندارید', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      const Text('برای شروع یک گفتگو کاربر را جستجو کنید.'),
                      const SizedBox(height: 18),
                      FilledButton.icon(onPressed: createDirect, icon: const Icon(Icons.add_comment_rounded), label: const Text('گفتگوی جدید')),
                    ]))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 90),
                      itemCount: visibleChats.length,
                      itemBuilder: (context, i) {
                        final c = visibleChats[i];
                        final type = c['type'].toString();
                        final title = (c['title'] ?? (type == 'group' ? 'گروه' : type == 'channel' ? 'کانال' : 'گفتگو')).toString();
                        final icon = type == 'group' ? Icons.groups_rounded : type == 'channel' ? Icons.campaign_rounded : Icons.person_rounded;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: CircleAvatar(backgroundColor: theme.colorScheme.primaryContainer, child: Icon(icon, color: theme.colorScheme.primary)),
                            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text((c['last_message'] ?? 'شروع گفتگو').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: const Icon(Icons.chevron_left_rounded),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(id: c['id'].toString(), title: title))),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget contactsView() => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: const Text('مخاطبین'), actions: [
      IconButton(onPressed: () => showSearch(context: context, delegate: UserSearchDelegate()), icon: const Icon(Icons.search_rounded)),
    ]),
    body: Center(child: FilledButton.tonalIcon(
      onPressed: () => showSearch(context: context, delegate: UserSearchDelegate()),
      icon: const Icon(Icons.person_search_rounded),
      label: const Text('جستجوی کاربر'),
    )),
  );

  Widget settingsView() => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: const Text('تنظیمات')),
    body: ListView(padding: const EdgeInsets.all(14), children: [
      Card(child: Column(children: [
        ListTile(leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.palette_rounded, color: Theme.of(context).colorScheme.primary)), title: const Text('ظاهر و رنگ', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('رنگ اصلی و حالت تاریک'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'تنظیمات صفحات', icon: Icons.palette_rounded)))),
        const Divider(height: 1),
        ListTile(leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.chat_rounded, color: Theme.of(context).colorScheme.primary)), title: const Text('تنظیمات گفتگو'), subtitle: const Text('اعلان‌ها و نمایش پیام‌ها'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'تنظیمات چت', icon: Icons.chat_rounded)))),
        const Divider(height: 1),
        ListTile(leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.bookmark_rounded, color: Theme.of(context).colorScheme.primary)), title: const Text('پیام‌های ذخیره‌شده'), subtitle: const Text('پیام‌های مهم را یکجا نگه دارید'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedMessagesPage()))),
      ])),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: KeyedSubtree(
        key: ValueKey(navIndex),
        child: navIndex == 0 ? chatsView() : navIndex == 1 ? contactsView() : navIndex == 2 ? settingsView() : const ProfilePage(),
      ))),
      floatingActionButton: navIndex == 0 ? FloatingActionButton(onPressed: createDirect, child: const Icon(Icons.chat_rounded)) : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (i) => setState(() => navIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum_rounded), label: 'گفتگوها'),
          NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'مخاطبین'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'تنظیمات'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'پروفایل'),
        ],
      ),
    );
  }
}

class _StoriesStrip extends StatefulWidget {
  const _StoriesStrip();
  @override State<_StoriesStrip> createState() => _StoriesStripState();
}

class _StoriesStripState extends State<_StoriesStrip> {
  List<Map<String, dynamic>> stories = [];
  bool loading = true;

  Future<void> load() async {
    try {
      final rows = await supabase.from('stories').select('id,user_id,text,background,created_at,expires_at').gt('expires_at', DateTime.now().toUtc().toIso8601String()).order('created_at', ascending: false).limit(30);
      final raw = List<Map<String, dynamic>>.from(rows);
      final ids = raw.map((x) => x['user_id']).toSet().toList();
      final people = ids.isEmpty ? <Map<String, dynamic>>[] : List<Map<String, dynamic>>.from(await supabase.from('profiles').select('id,display_name,username,avatar_url').inFilter('id', ids));
      final map = {for (final p in people) p['id'].toString(): p};
      if (mounted) setState(() { stories = raw.map((s) => {...s, '_profile': map[s['user_id'].toString()] ?? {}}).toList(); loading = false; });
    } catch (_) {
      if (mounted) setState(() { stories = []; loading = false; });
    }
  }

  @override void initState() { super.initState(); load(); }

  @override
  Widget build(BuildContext context) {
    final uid = supabase.auth.currentUser?.id;
    final mine = stories.where((s) => s['user_id'].toString() == uid).toList();
    final others = stories.where((s) => s['user_id'].toString() != uid).toList();
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 2),
        children: [
          _storyItem(context, mine.isEmpty ? null : mine.first, true),
          ...others.map((s) => _storyItem(context, s, false)),
        ],
      ),
    );
  }

  Widget _storyItem(BuildContext context, Map<String, dynamic>? story, bool mine) {
    final theme = Theme.of(context);
    final p = story == null ? <String, dynamic>{} : Map<String, dynamic>.from(story['_profile'] ?? {});
    return GestureDetector(
      onTap: () async {
        if (mine) {
          final changed = await Navigator.push(context, MaterialPageRoute(builder: (_) => StoryComposerPage(existing: story)));
          if (changed == true) load();
        } else if (story != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewerPage(story: story)));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const StoryComposerPage()));
        }
      },
      child: SizedBox(width: 78, child: Column(children: [
        Container(
          width: 64, height: 64, padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary])),
          child: story == null ? CircleAvatar(backgroundColor: theme.colorScheme.surface, child: Icon(Icons.add_rounded, color: theme.colorScheme.primary)) : avatar(p, size: 58),
        ),
        const SizedBox(height: 5),
        Text(mine ? (story == null ? 'استوری شما' : 'استوری من') : (p['display_name'] ?? p['username'] ?? 'کاربر').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
      ])),
    );
  }
}

class StoryComposerPage extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const StoryComposerPage({super.key, this.existing});
  @override State<StoryComposerPage> createState() => _StoryComposerPageState();
}

class _StoryComposerPageState extends State<StoryComposerPage> {
  late TextEditingController text;
  int background = 0xFF2563EB;
  bool busy = false;
  static const colors = [0xFF2563EB, 0xFF7C3AED, 0xFFDB2777, 0xFFEA580C, 0xFF059669, 0xFF0F172A];

  @override void initState() {
    super.initState();
    text = TextEditingController(text: (widget.existing?['text'] ?? '').toString());
    background = int.tryParse((widget.existing?['background'] ?? '').toString()) ?? background;
  }

  Future<void> save() async {
    final value = text.text.trim();
    if (value.isEmpty) { showMsg(context, 'یک جمله برای استوری بنویسید.'); return; }
    if (value.length > 180) { showMsg(context, 'استوری حداکثر ۱۸۰ کاراکتر باشد.'); return; }
    setState(() => busy = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      final data = {'user_id': uid, 'text': value, 'background': background.toString(), 'expires_at': DateTime.now().toUtc().add(const Duration(hours: 24)).toIso8601String()};
      if (widget.existing != null) {
        await supabase.from('stories').update(data).eq('id', widget.existing!['id']).eq('user_id', uid);
      } else {
        await supabase.from('stories').insert(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMsg(context, 'ذخیره استوری انجام نشد. ابتدا migration استوری را در Supabase اجرا کنید.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استوری یک‌جمله‌ای')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 290,
          decoration: BoxDecoration(color: Color(background), borderRadius: BorderRadius.circular(28)),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(28),
          child: Text(text.text.isEmpty ? 'جمله استوری شما' : text.text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.3)),
        ),
        const SizedBox(height: 18),
        TextField(controller: text, maxLength: 180, maxLines: 2, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'یک جمله بنویسید', prefixIcon: Icon(Icons.edit_rounded))),
        const SizedBox(height: 8),
        const Text('رنگ استوری', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, children: colors.map((c) => GestureDetector(onTap: () => setState(() => background = c), child: Container(width: 42, height: 42, decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: background == c ? Border.all(color: Colors.white, width: 4) : null)))).toList()),
        const SizedBox(height: 22),
        FilledButton.icon(onPressed: busy ? null : save, icon: const Icon(Icons.check_rounded), label: Text(busy ? 'در حال ذخیره...' : 'انتشار استوری')),
      ]),
    );
  }

  @override void dispose() { text.dispose(); super.dispose(); }
}

class StoryViewerPage extends StatelessWidget {
  final Map<String, dynamic> story;
  const StoryViewerPage({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    final p = Map<String, dynamic>.from(story['_profile'] ?? {});
    final bg = int.tryParse(story['background'].toString()) ?? 0xFF2563EB;
    return Scaffold(
      backgroundColor: Color(bg),
      body: SafeArea(child: Stack(children: [
        Center(child: Padding(padding: const EdgeInsets.all(30), child: Text(story['text'].toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900, height: 1.35)))),
        Positioned(top: 10, left: 16, right: 16, child: Row(children: [
          avatar(p, size: 42),
          const SizedBox(width: 10),
          Expanded(child: Text((p['display_name'] ?? p['username'] ?? 'کاربر').toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white)),
        ])),
      ])),
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
      final uniqueIds = <String>{uid, ...selected.map((p) => '${p['id']}')};
      final members = uniqueIds.map((memberId) => {'conversation_id': c['id'], 'user_id': memberId}).toList();
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
  Map<String, Map<String, dynamic>> profiles = {};
  Map<String, List<Map<String, dynamic>>> reactions = {};
  RealtimeChannel? channel;
  bool loading = true;
  bool sending = false;
  Map<String, dynamic>? replyMessage;
  final AudioRecorder _voiceRecorder = AudioRecorder();
  final AudioPlayer _voicePlayer = AudioPlayer();
  bool recordingVoice = false;

  String _time(dynamic value) {
    final dt = DateTime.tryParse('$value')?.toLocal();
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _dateLabel(dynamic value) {
    final dt = DateTime.tryParse('$value')?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'امروز';
    if (diff == 1) return 'دیروز';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  String _senderName(Map<String, dynamic> m) {
    final p = profiles['${m['sender_id']}'];
    if (p == null) return m['sender_id'] == supabase.auth.currentUser?.id ? 'شما' : 'کاربر';
    return '${p['display_name'] ?? p['username'] ?? 'کاربر'}';
  }

  Future<void> load() async {
    try {
      final rows = await supabase.from('messages').select().eq('conversation_id', widget.id).order('created_at');
      final loaded = List<Map<String, dynamic>>.from(rows);
      final senderIds = loaded.map((m) => '${m['sender_id']}').toSet().toList();
      if (senderIds.isNotEmpty) {
        final people = await supabase.from('profiles').select('id,display_name,username,avatar_url').inFilter('id', senderIds);
        profiles = {for (final p in List<Map<String, dynamic>>.from(people)) '${p['id']}': p};
      }
      final ids = loaded.map((m) => '${m['id']}').toList();
      final loadedReactions = <String, List<Map<String, dynamic>>>{};
      if (ids.isNotEmpty) {
        final rr = await supabase.from('message_reactions').select('message_id,user_id,reaction,created_at').inFilter('message_id', ids);
        for (final r in List<Map<String, dynamic>>.from(rr)) {
          loadedReactions.putIfAbsent('${r['message_id']}', () => []).add(r);
        }
      }
      if (mounted) {
        setState(() {
          messages = loaded;
          reactions = loadedReactions;
          loading = false;
        });
      }
      await markRead();
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        showMsg(context, 'خطا در پیام‌ها: $e');
      }
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
      await supabase.from('messages').insert({
        'conversation_id': widget.id,
        'sender_id': supabase.auth.currentUser!.id,
        'body': value,
        'message_type': 'text',
        'reply_to': replyMessage?['id'],
      });
      text.clear();
      if (mounted) setState(() => replyMessage = null);
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
      final msg = await supabase.from('messages').insert({
        'conversation_id': widget.id,
        'sender_id': supabase.auth.currentUser!.id,
        'body': f.name,
        'message_type': 'file',
        'reply_to': replyMessage?['id'],
      }).select().single();
      await supabase.from('message_attachments').insert({'message_id': msg['id'], 'storage_path': path, 'file_name': f.name, 'file_size': f.size});
      if (mounted) setState(() => replyMessage = null);
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'فایل ارسال نشد: $e');
    }
  }

  Future<void> toggleVoiceRecording() async {
    if (sending) return;
    try {
      if (recordingVoice) {
        final path = await _voiceRecorder.stop();
        if (mounted) setState(() => recordingVoice = false);
        if (path == null || path.isEmpty) return;
        final file = File(path);
        if (!await file.exists()) throw Exception('فایل ویس ساخته نشد');
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) throw Exception('فایل ویس خالی است');
        setState(() => sending = true);
        final storagePath = widget.id + '/voice_' + DateTime.now().millisecondsSinceEpoch.toString() + '.m4a';
        await supabase.storage.from('chat-media').uploadBinary(storagePath, bytes, fileOptions: const FileOptions(contentType: 'audio/mp4', upsert: false));
        final msg = await supabase.from('messages').insert({
          'conversation_id': widget.id,
          'sender_id': supabase.auth.currentUser!.id,
          'body': 'پیام صوتی',
          'message_type': 'audio',
          'reply_to': replyMessage?['id'],
        }).select().single();
        await supabase.from('message_attachments').insert({
          'message_id': msg['id'],
          'storage_path': storagePath,
          'file_name': storagePath.split('/').last,
          'mime_type': 'audio/mp4',
        });
        if (mounted) setState(() => replyMessage = null);
        try { await file.delete(); } catch (_) {}
        await load();
      } else {
        if (!await _voiceRecorder.hasPermission()) {
          if (mounted) showMsg(context, 'دسترسی میکروفون فعال نیست.');
          return;
        }
        final path = Directory.systemTemp.path + '/arad_voice_' + DateTime.now().millisecondsSinceEpoch.toString() + '.m4a';
        await _voiceRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100), path: path);
        if (mounted) setState(() => recordingVoice = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() { recordingVoice = false; sending = false; });
        showMsg(context, 'ضبط یا ارسال ویس ناموفق بود: $e');
      }
    } finally {
      if (mounted && !recordingVoice) setState(() => sending = false);
    }
  }

  Future<void> sendImage() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final path = '${widget.id}/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      await supabase.storage.from('chat-media').uploadBinary(path, bytes);
      final msg = await supabase.from('messages').insert({
        'conversation_id': widget.id,
        'sender_id': supabase.auth.currentUser!.id,
        'body': image.name,
        'message_type': 'image',
        'reply_to': replyMessage?['id'],
      }).select().single();
      await supabase.from('message_attachments').insert({'message_id': msg['id'], 'storage_path': path, 'file_name': image.name, 'mime_type': 'image'});
      if (mounted) setState(() => replyMessage = null);
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'تصویر ارسال نشد: $e');
    }
  }

  Future<void> reactTo(Map<String, dynamic> message, String emoji) async {
    final uid = supabase.auth.currentUser!.id;
    try {
      final current = (reactions['${message['id']}'] ?? const <Map<String, dynamic>>[]).where((r) => r['user_id'] == uid).toList();
      if (current.isNotEmpty && current.first['reaction'] == emoji) {
        await supabase.from('message_reactions').delete().match({'message_id': message['id'], 'user_id': uid});
      } else {
        await supabase.from('message_reactions').upsert({'message_id': message['id'], 'user_id': uid, 'reaction': emoji});
      }
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'واکنش ذخیره نشد: $e');
    }
  }

  void setReply(Map<String, dynamic> message) {
    setState(() => replyMessage = message);
  }

  Future<void> editMessage(Map<String, dynamic> message) async {
    if (message['sender_id'] != supabase.auth.currentUser?.id || message['message_type'] != 'text') return;
    final controller = TextEditingController(text: message['body']?.toString() ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ویرایش پیام'),
        content: TextField(controller: controller, autofocus: true, maxLines: 5),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('ذخیره')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || value == (message['body']?.toString() ?? '')) return;
    try {
      await supabase.from('messages').update({
        'body': value,
        'edited_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', message['id']).eq('sender_id', supabase.auth.currentUser!.id);
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'ویرایش پیام ناموفق بود: $e');
    }
  }

  Future<void> deleteForMe(Map<String, dynamic> message) async {
    try {
      await supabase.from('message_user_deletions').upsert({
        'message_id': message['id'],
        'user_id': supabase.auth.currentUser!.id,
      });
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'حذف برای من ناموفق بود: $e');
    }
  }

  Future<void> deleteForEveryone(Map<String, dynamic> message) async {
    if (message['sender_id'] != supabase.auth.currentUser?.id) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف برای همه'),
        content: const Text('این پیام برای همه اعضای گفتگو حذف می‌شود.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase.from('messages').update({
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'body': null,
      }).eq('id', message['id']).eq('sender_id', supabase.auth.currentUser!.id);
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'حذف برای همه ناموفق بود: $e');
    }
  }

  Future<void> shareMessage(Map<String, dynamic> message) async {
    final body = '\${message['body'] ?? ''}'.trim();
    if (body.isEmpty) return;
    try {
      await Share.share(body);
    } catch (e) {
      if (mounted) showMsg(context, 'اشتراک‌گذاری ناموفق بود: $e');
    }
  }

  Future<void> copyMessageLink(Map<String, dynamic> message) async {
    final link = 'arad://chat/\${widget.id}/message/\${message['id']}';
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) showMsg(context, 'لینک پیام کپی شد.');
  }

  Future<void> forwardMessage(Map<String, dynamic> message) async {
    final body = message['body']?.toString().trim() ?? '';
    if (body.isEmpty || message['deleted_at'] != null) {
      if (mounted) showMsg(context, 'این پیام قابل فوروارد نیست.');
      return;
    }
    try {
      final uid = supabase.auth.currentUser!.id;
      final memberRows = await supabase.from('conversation_members').select('conversation_id').eq('user_id', uid);
      final ids = (memberRows as List).map((e) => e['conversation_id']).where((id) => id != null).toList();
      if (ids.isEmpty) {
        if (mounted) showMsg(context, 'گفتگویی برای فوروارد وجود ندارد.');
        return;
      }
      final rows = await supabase.from('conversations').select('id,title,type,created_at').inFilter('id', ids).order('created_at', ascending: false);
      final rawTargets = List<Map<String, dynamic>>.from(rows).where((c) => '${c['id']}' != '${widget.id}').toList();
      final targets = <Map<String, dynamic>>[];
      for (final c in rawTargets) {
        var displayTitle = '${c['title'] ?? ''}'.trim();
        if (displayTitle.isEmpty && '${c['type']}' == 'direct') {
          final other = await supabase.from('conversation_members').select('user_id').eq('conversation_id', c['id']).neq('user_id', uid).maybeSingle();
          if (other != null) {
            final p = await supabase.from('profiles').select('display_name,username').eq('id', other['user_id']).maybeSingle();
            displayTitle = '${p?['display_name'] ?? p?['username'] ?? 'کاربر'}';
          }
        }
        if (displayTitle.isEmpty) {
          final type = '${c['type']}';
          displayTitle = type == 'group' ? 'گروه' : type == 'channel' ? 'کانال' : 'گفتگو';
        }
        targets.add({...c, '_display_title': displayTitle});
      }
      if (targets.isEmpty) {
        if (mounted) showMsg(context, 'گفتگوی دیگری برای فوروارد پیدا نشد.');
        return;
      }

      final target = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: Theme.of(context).colorScheme.surface,
        showDragHandle: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .62,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('ارسال فوروارد به...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: targets.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (_, index) {
                      final c = targets[index];
                      final type = '${c['type']}';
                      final title = '${c['_display_title'] ?? c['title'] ?? (type == 'group' ? 'گروه' : type == 'channel' ? 'کانال' : 'گفتگو')}';
                      final icon = type == 'group' ? Icons.group_rounded : type == 'channel' ? Icons.campaign_rounded : Icons.person_rounded;
                      return ListTile(
                        leading: CircleAvatar(child: Icon(icon)),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(type == 'group' ? 'گروه' : type == 'channel' ? 'کانال' : 'گفتگوی شخصی'),
                        trailing: const Icon(Icons.chevron_left_rounded),
                        onTap: () => Navigator.pop(sheetContext, c),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (target == null) return;

      final inserted = await supabase.from('messages').insert({
        'conversation_id': target['id'],
        'sender_id': uid,
        'body': body,
        'message_type': message['message_type'] ?? 'text',
        'reply_to': null,
      }).select().single();

      final type = '${message['message_type'] ?? 'text'}';
      if (type != 'text') {
        final attachment = await supabase.from('message_attachments')
            .select('storage_path,file_name,file_size,mime_type')
            .eq('message_id', message['id'])
            .maybeSingle();
        if (attachment != null) {
          await supabase.from('message_attachments').insert({
            'message_id': inserted['id'],
            'storage_path': attachment['storage_path'],
            'file_name': attachment['file_name'],
            'file_size': attachment['file_size'],
            'mime_type': attachment['mime_type'],
          });
        }
      }

      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatPage(id: '${target['id']}', title: '${target['_display_title'] ?? target['title'] ?? 'گفتگو'}'),
        ));
        showMsg(context, 'پیام با موفقیت فوروارد شد.');
      }
    } catch (e) {
      if (mounted) showMsg(context, 'فوروارد پیام ناموفق بود: $e');
    }
  }

  Future<void> showMessageActions(Map<String, dynamic> message) async {
    const emojis = ['❤️', '😁', '💘', '👍', '👎', '🔥', '🥰'];
    final scheme = Theme.of(context).colorScheme;
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'عملیات پیام',
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF20384A),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _messageActionsContent(context, message),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .18),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: .96, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _messageActionsContent(BuildContext context, Map<String, dynamic> message) {
    const emojis = ['❤️', '😁', '💘', '👍', '👎', '🔥', '🥰'];
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('عملیات پیام', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
            IconButton(tooltip: 'بستن', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white70)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .14), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withValues(alpha: .07))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              ...emojis.map((e) => InkWell(borderRadius: BorderRadius.circular(24), onTap: () { Navigator.pop(context); reactTo(message, e); }, child: Padding(padding: const EdgeInsets.all(5), child: Text(e, style: const TextStyle(fontSize: 25))))),
              InkWell(borderRadius: BorderRadius.circular(24), onTap: () { Navigator.pop(context); _showMoreReactions(message); }, child: const Padding(padding: EdgeInsets.all(7), child: Icon(Icons.add_reaction_outlined, color: Colors.white, size: 25))),
            ]),
          ),
          const SizedBox(height: 7),
          _actionTile(context, Icons.reply_rounded, 'پاسخ دادن', () => setReply(message)),
          _actionTile(context, Icons.share_rounded, 'اشتراک‌گذاری پیام', () => shareMessage(message)),
          _actionTile(context, Icons.link_rounded, 'لینک پیام', () => copyMessageLink(message)),
          _actionTile(context, Icons.copy_rounded, 'کپی', () { final text = '${message['body'] ?? ''}'; if (text.trim().isNotEmpty) { Clipboard.setData(ClipboardData(text: text)); showMsg(context, 'متن کپی شد.'); } else { showMsg(context, 'این پیام متن قابل کپی ندارد.'); } }),
          if (message['sender_id'] == supabase.auth.currentUser?.id && message['message_type'] == 'text') _actionTile(context, Icons.edit_outlined, 'ویرایش پیام', () => editMessage(message)),
          _actionTile(context, Icons.forward_rounded, 'فوروارد', () => forwardMessage(message)),
          const Divider(height: 12, color: Colors.white12),
          _actionTile(context, Icons.push_pin_outlined, 'سنجاق کردن', () => showMsg(context, 'قابلیت سنجاق پیام در حال آماده‌سازی است.')),
          _actionTile(context, Icons.info_outline_rounded, 'اطلاعات پیام', () => _showMessageInfo(message)),
          _actionTile(context, Icons.report_gmailerrorred_outlined, 'گزارش پیام', () => showMsg(context, 'گزارش پیام در نسخه فعلی فقط به‌صورت محلی ثبت می‌شود.')),
          _actionTile(context, Icons.delete_outline_rounded, 'حذف برای من', () => deleteForMe(message)),
          if (message['sender_id'] == supabase.auth.currentUser?.id) _actionTile(context, Icons.delete_forever_outlined, 'حذف برای همه', () => deleteForEveryone(message)),
          Text('با انیمیشن باز و بسته می‌شود', style: TextStyle(color: scheme.onSurface.withValues(alpha: .45), fontSize: 10)),
        ],
      ),
    );
  }

  Future<void> _showMoreReactions(Map<String, dynamic> message) async {
    const more = ['😂','😍','😎','😢','😡','👏','🎉','❤️‍🔥','💯','🙏','🤝','👀','🚀','⭐','⚡','😮'];
    final selected = await showModalBottomSheet<String>(context: context, backgroundColor: Theme.of(context).colorScheme.surface, showDragHandle: true, builder: (_) => SafeArea(child: GridView.count(shrinkWrap: true, crossAxisCount: 5, padding: const EdgeInsets.all(18), mainAxisSpacing: 8, crossAxisSpacing: 8, children: more.map((e) => InkWell(borderRadius: BorderRadius.circular(16), onTap: () => Navigator.pop(context, e), child: Center(child: Text(e, style: const TextStyle(fontSize: 30)))).toList())));
    if (selected != null) await reactTo(message, selected);
  }

  Future<void> _showMessageInfo(Map<String, dynamic> message) async {
    final created = message['created_at']?.toString() ?? 'نامشخص';
    final edited = message['edited_at'] != null;
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('اطلاعات پیام'), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('فرستنده: ' + _senderName(message)), const SizedBox(height: 8), Text('نوع: ' + (message['message_type']?.toString() ?? 'text')), const SizedBox(height: 8), Text('زمان ارسال: ' + created), if (edited) ...[const SizedBox(height: 8), const Text('وضعیت: ویرایش شده')]]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('بستن'))]));
  }
  Widget _actionTile(
    BuildContext sheetContext,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return ListTile(
      dense: true,
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon, color: enabled ? Colors.white : Colors.white38, size: 27),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? Colors.white : Colors.white38,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: enabled
          ? () {
              Navigator.pop(sheetContext);
              onTap();
            }
          : null,
    );
  }

  Widget _replyPreview(Map<String, dynamic> message) {
    final id = '${message['reply_to'] ?? ''}';
    if (id.isEmpty) return const SizedBox.shrink();
    Map<String, dynamic>? parent;
    for (final item in messages) {
      if ('${item['id']}' == id) {
        parent = item;
        break;
      }
    }
    if (parent == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
      child: Text('${_senderName(parent!)}: ${parent['body'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
    );
  }

  Widget _reactionRow(Map<String, dynamic> message) {
    final list = reactions['${message['id']}'] ?? const <Map<String, dynamic>>[];
    if (list.isEmpty) return const SizedBox.shrink();
    final counts = <String, int>{};
    for (final r in list) {
      final emoji = '${r['reaction']}';
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Wrap(
        spacing: 4,
        children: counts.entries.map((e) => InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => reactTo(message, e.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
            child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 12)),
          ),
        )).toList(),
      ),
    );
  }

  Widget _messageBubble(Map<String, dynamic> m) {
    final mine = m['sender_id'] == supabase.auth.currentUser!.id;
    final sender = _senderName(m);
    final avatarUrl = profiles['${m['sender_id']}']?['avatar_url']?.toString() ?? '';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => showMessageActions(m),
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0).abs() > 450) setReply(m);
        },
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .84),
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine) ...[
                CircleAvatar(radius: 17, backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null, child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 18) : null),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Card(
                  margin: EdgeInsets.zero,
                  color: mine ? Theme.of(context).colorScheme.primaryContainer : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 10, 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!mine) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(sender, style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary))),
                        _replyPreview(m),
                        if (m['message_type'] == 'image') const Padding(padding: EdgeInsets.only(bottom: 5), child: Icon(Icons.image_rounded, size: 42)),
                        if (m['message_type'] == 'audio') _voicePlayButton(m['id'].toString()),
                        if (m['message_type'] != 'audio' && '${m['body'] ?? ''}'.isNotEmpty) Text('${m['body'] ?? ''}', style: const TextStyle(fontSize: 15.5, height: 1.35)),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${_dateLabel(m['created_at'])}  ${_time(m['created_at'])}', style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            if (mine) ...[
                              const SizedBox(width: 4),
                              Icon(m['read_at'] != null ? Icons.done_all_rounded : Icons.done_rounded, size: 15, color: m['read_at'] != null ? Colors.blue : null),
                            ],
                          ],
                        ),
                        _reactionRow(m),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    _voiceRecorder.dispose();
    _voicePlayer.dispose();
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [const CircleAvatar(radius: 17, child: Icon(Icons.person, size: 18)), const SizedBox(width: 9), Expanded(child: Text(widget.title, overflow: TextOverflow.ellipsis))]),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(child: Text('هنوز پیامی وجود ندارد.'))
                    : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), itemCount: messages.length, itemBuilder: (context, i) => _messageBubble(messages[i])),
          ),
          if (replyMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, border: const Border(top: BorderSide(color: Color(0xFFE0E2E8)))),
              child: Row(children: [const Icon(Icons.reply_rounded, size: 20), const SizedBox(width: 8), Expanded(child: Text('${_senderName(replyMessage!)}: ${replyMessage!['body'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))), IconButton(onPressed: () => setState(() => replyMessage = null), icon: const Icon(Icons.close))]),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(onPressed: sendImage, tooltip: 'تصویر', icon: const Icon(Icons.image_outlined)),
                  IconButton(onPressed: sendFile, tooltip: 'فایل', icon: const Icon(Icons.attach_file)),
                  IconButton(onPressed: toggleVoiceRecording, tooltip: recordingVoice ? 'توقف و ارسال ویس' : 'ضبط ویس', icon: Icon(recordingVoice ? Icons.stop_circle_rounded : Icons.mic_rounded)),
                  Expanded(child: TextField(controller: text, minLines: 1, maxLines: 5, textInputAction: TextInputAction.newline, decoration: const InputDecoration(hintText: 'پیام...', border: OutlineInputBorder(), isDense: true))),
                  IconButton(onPressed: sending ? null : sendText, icon: const Icon(Icons.send_rounded)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class AccountSwitcherPage extends StatefulWidget {
  final bool autoAdd;

  const AccountSwitcherPage({super.key, this.autoAdd = false});

  @override
  State<AccountSwitcherPage> createState() => _AccountSwitcherPageState();
}

class _AccountSwitcherPageState extends State<AccountSwitcherPage> {
  List<String> accounts = <String>[];
  bool loading = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.autoAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addAccount();
      });
    }
  }

  Future<void> _load() async {
    final list = await _savedAccountEmails();
    final current = supabase.auth.currentUser?.email?.toLowerCase();
    if (current != null && current.isNotEmpty) {
      await _rememberAccount(current);
    }
    if (!mounted) return;
    setState(() {
      accounts = list.contains(current) ? list : ([if (current != null) current, ...list]);
      accounts = accounts.take(3).toList();
      loading = false;
    });
  }

  Future<void> _switchTo(String email) async {
    final current = supabase.auth.currentUser?.email?.toLowerCase();
    if (current == email.toLowerCase()) {
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => busy = true);
    try {
      await supabase.auth.signOut();
      await supabase.auth.signInWithOtp(email: email.toLowerCase(), shouldCreateUser: false);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => EmailVerificationPage(
          email: email.toLowerCase(),
          verificationType: OtpType.email,
          allowCreateUser: false,
        )),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (mounted) showMsg(context, 'تغییر حساب ناموفق بود: ${e.message}');
    } catch (e) {
      if (mounted) showMsg(context, 'تغییر حساب ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _addAccount() async {
    if (accounts.length >= 3) {
      showMsg(context, 'حداکثر ۳ حساب می‌توانید روی این دستگاه داشته باشید.');
      return;
    }
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('افزودن حساب'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ایمیل حساب جدید',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('ادامه')),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.trim().isEmpty) return;
    final normalized = email.trim().toLowerCase();
    if (accounts.any((e) => e.toLowerCase() == normalized)) {
      showMsg(context, 'این حساب قبلاً اضافه شده است.');
      return;
    }
    setState(() => busy = true);
    try {
      await supabase.auth.signOut();
      await supabase.auth.signInWithOtp(email: normalized, shouldCreateUser: true);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => EmailVerificationPage(
          email: normalized,
          verificationType: OtpType.email,
          allowCreateUser: true,
        )),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (mounted) showMsg(context, 'ارسال کد حساب جدید ناموفق بود: ${e.message}');
    } catch (e) {
      if (mounted) showMsg(context, 'افزودن حساب ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _remove(String email) async {
    final current = supabase.auth.currentUser?.email?.toLowerCase();
    if (current == email.toLowerCase()) {
      showMsg(context, 'حساب فعال را نمی‌توان از لیست حذف کرد.');
      return;
    }
    await _removeSavedAccount(email);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final current = supabase.auth.currentUser?.email?.toLowerCase();
    return Scaffold(
      appBar: AppBar(title: const Text('تغییر حساب')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(children: [
                      CircleAvatar(radius: 27, child: const Icon(Icons.manage_accounts_rounded)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('حساب‌های من', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('${accounts.length} از ۳ حساب فعال روی این دستگاه'),
                      ])),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                ...accounts.map((email) {
                  final active = email.toLowerCase() == current;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(active ? Icons.check_rounded : Icons.person_outline_rounded)),
                      title: Text(email, textDirection: TextDirection.ltr),
                      subtitle: Text(active ? 'حساب فعلی' : 'برای ورود، کد ۶ رقمی ایمیل می‌شود.'),
                      trailing: active
                          ? const Icon(Icons.radio_button_checked_rounded)
                          : PopupMenuButton<String>(
                              onSelected: (v) { if (v == 'switch') _switchTo(email); if (v == 'remove') _remove(email); },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'switch', child: Text('تغییر به این حساب')),
                                PopupMenuItem(value: 'remove', child: Text('حذف از این دستگاه')),
                              ],
                            ),
                      onTap: active ? null : () => _switchTo(email),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: busy ? null : _addAccount,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(accounts.length >= 3 ? 'سقف ۳ حساب تکمیل است' : 'افزودن حساب جدید'),
                ),
                const SizedBox(height: 8),
                Text(
                  'برای امنیت، هنگام تغییر یا افزودن حساب، کد ۶ رقمی همان ایمیل درخواست می‌شود.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .6), fontSize: 12),
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

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('خروج از حساب'),
        content: const Text('آیا می‌خواهید از این حساب خارج شوید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('خروج')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await supabase.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (err) {
      if (mounted) showMsg(context, 'خروج ناموفق بود: ' + err.message);
    } catch (err) {
      if (mounted) showMsg(context, 'خروج ناموفق بود: ' + err.toString());
    }
  }
  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('پروفایل'),
        actions: [
          IconButton(
            tooltip: 'تغییر یا افزودن حساب',
            icon: const Icon(Icons.manage_accounts_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountSwitcherPage()),
            ),
          ),
          IconButton(
            tooltip: 'ویرایش پروفایل',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSetupPage()));
              await load();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: Stack(children: [avatar(p, size: 104), Positioned(bottom: 0, right: 0, child: IconButton.filled(onPressed: avatarUpload, icon: const Icon(Icons.camera_alt)))])),
          const SizedBox(height: 18),
          Center(child: Text('${p['display_name'] ?? 'بدون نام'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900))),
          if ('${p['username'] ?? ''}'.trim().isNotEmpty) Center(child: Text('@${p['username']}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700))),
          const SizedBox(height: 10),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('${p['bio']?.toString().trim().isNotEmpty == true ? p['bio'] : 'هنوز بیویی برای پروفایل ثبت نشده است.'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.5)))),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSetupPage()));
              await load();
            },
            icon: const Icon(Icons.edit_rounded),
            label: const Text('ویرایش نام، نمایه و بیو'),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('حساب‌ها', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(
                    'تا ۳ حساب را روی این دستگاه نگه دارید و هر زمان خواستید با کد ۶ رقمی بین آن‌ها جابه‌جا شوید.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AccountSwitcherPage()),
                          ),
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('تغییر حساب'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AccountSwitcherPage(autoAdd: true)),
                          ),
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('افزودن حساب'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 8),
          const Text('تنظیمات پروفایل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ListTile(leading: const Icon(Icons.person_outline), title: const Text('حساب کاربری'), subtitle: const Text('نام، نام کاربری و اطلاعات حساب'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSetupPage()))),
          ListTile(leading: const Icon(Icons.lock_outline), title: const Text('حریم خصوصی و امنیت'), subtitle: const Text('تنظیمات امنیت و حریم خصوصی'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'حریم خصوصی و امنیت', icon: Icons.lock_outline)))),
          ListTile(leading: const Icon(Icons.storage_outlined), title: const Text('داده‌ها و ذخیره‌سازی'), subtitle: const Text('مدیریت داده‌ها و فضای ذخیره‌سازی'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'داده‌ها و ذخیره‌سازی', icon: Icons.storage_outlined)))),
          ListTile(leading: const Icon(Icons.chat_bubble_outline), title: const Text('تنظیمات چت'), subtitle: const Text('ظاهر و رفتار گفتگوها'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'تنظیمات چت', icon: Icons.chat_bubble_outline)))),
          ListTile(leading: const Icon(Icons.bookmark_outline), title: const Text('پیام‌های ذخیره‌شده'), subtitle: const Text('دسترسی سریع به پیام‌های مهم'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'پیام‌های ذخیره‌شده', icon: Icons.bookmark_outline)))),
          ListTile(leading: const Icon(Icons.dashboard_customize_outlined), title: const Text('تنظیمات صفحات'), subtitle: const Text('مدیریت تنظیمات بخش‌های برنامه'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'تنظیمات صفحات', icon: Icons.dashboard_customize_outlined)))),
          ListTile(leading: const Icon(Icons.language), title: const Text('زبان'), subtitle: const Text('انتخاب زبان برنامه'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'زبان', icon: Icons.language)))),
          ListTile(leading: const Icon(Icons.account_balance_wallet_outlined), title: const Text('کیف پول'), subtitle: const Text('مدیریت کیف پول آراد'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'کیف پول', icon: Icons.account_balance_wallet_outlined)))),
          ListTile(leading: const Icon(Icons.person_add_alt_1), title: const Text('دعوت از دوستان'), subtitle: const Text('دعوت یک دوست برای پیوستن به آراد'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvitePage()))),
          ListTile(leading: const Icon(Icons.system_update_outlined), title: const Text('به‌روزرسانی'), subtitle: const Text('بررسی نسخه جدید برنامه'), onTap: () => showMsg(context, 'نسخه فعلی برنامه بررسی شد.')),
          ListTile(leading: const Icon(Icons.support_agent_outlined), title: const Text('پشتیبانی'), subtitle: const Text('راهنمایی و ارتباط با پشتیبانی'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'پشتیبانی', icon: Icons.support_agent_outlined)))),
          const SizedBox(height: 12),

          FilledButton.tonal(
            onPressed: _logout,
            child: const Text('خروج'),
          ),
        ],
      ),
    );
}
}


class ProfileOptionPage extends StatefulWidget {
  final String title; final IconData icon;
  const ProfileOptionPage({super.key, required this.title, required this.icon});
  @override State<ProfileOptionPage> createState() => _ProfileOptionPageState();
}
class _ProfileOptionPageState extends State<ProfileOptionPage> {
  bool notifications = true, readReceipts = true, mediaAuto = true;
  @override Widget build(BuildContext context) {
    final title = widget.title;
    return Scaffold(appBar: AppBar(title: Text(title)), body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [CircleAvatar(radius: 26, child: Icon(widget.icon)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 4), const Text('تنظیمات Arad Messenger')]))]))),
      if (title == 'حریم خصوصی و امنیت') ...[
        SwitchListTile(value: readReceipts, onChanged: (v) => setState(() => readReceipts = v), title: const Text('وضعیت خوانده‌شدن'), subtitle: const Text('نمایش تیک خوانده‌شدن پیام‌ها')),
        ListTile(leading: const Icon(Icons.logout_rounded), title: const Text('خروج از حساب'), onTap: () => supabase.auth.signOut()),
      ] else if (title == 'داده‌ها و ذخیره‌سازی') ...[
        SwitchListTile(value: mediaAuto, onChanged: (v) => setState(() => mediaAuto = v), title: const Text('دانلود خودکار رسانه')),
        ListTile(leading: const Icon(Icons.delete_sweep_outlined), title: const Text('پاک‌سازی حافظه موقت'), onTap: () => showMsg(context, 'حافظه موقت پاک شد.')),
      ] else if (title == 'تنظیمات چت') ...[
        ListTile(leading: const Icon(Icons.palette_outlined), title: const Text('رنگ برنامه'), subtitle: const Text('انتخاب رنگ اصلی'), onTap: () => _pickColor(context)),
        SwitchListTile(value: notifications, onChanged: (v) => setState(() => notifications = v), title: const Text('پیش‌نمایش پیام')),
      ] else if (title == 'تنظیمات صفحات') ...[
        SwitchListTile(value: appTheme.dark, onChanged: (v) => appTheme.setDark(v), title: const Text('حالت تاریک'), subtitle: const Text('تغییر ظاهر روشن و تاریک')),
        SwitchListTile(value: notifications, onChanged: (v) => setState(() => notifications = v), title: const Text('اعلان‌ها')),
      ] else if (title == 'پشتیبانی') ...[
        ListTile(leading: const Icon(Icons.help_outline_rounded), title: const Text('راهنمای استفاده'), onTap: () => showDialog(context: context, builder: (_) => const AlertDialog(title: Text('راهنمای Arad Messenger'), content: Text('برای شروع گفتگو، کاربر را جستجو کنید یا گروه بسازید. در چت می‌توانید تصویر و فایل ارسال کنید.')))),
        ListTile(leading: const Icon(Icons.bug_report_outlined), title: const Text('گزارش مشکل'), onTap: () => showMsg(context, 'گزارش مشکل را از طریق پشتیبانی ارسال کنید.')),
      ] else if (title == 'زبان') ...[
        ...AppStrings.supported.map((code) => ListTile(leading: const Icon(Icons.language), title: Text(AppStrings.names[code] ?? code), trailing: aradLanguageController.locale.languageCode == code ? const Icon(Icons.check_circle_rounded) : null, onTap: () async { await aradLanguageController.setLocale(code); if (context.mounted) Navigator.pop(context); })),
      ] else if (title == 'کیف پول') ...[
        ListTile(leading: const Icon(Icons.account_balance_wallet_outlined), title: const Text('وضعیت کیف پول'), subtitle: const Text('کیف پول هنوز فعال نشده است.')),
      ] else ...[
        ListTile(leading: const Icon(Icons.check_circle_outline), title: const Text('وضعیت حساب'), subtitle: const Text('حساب شما فعال است.')),
      ],
    ]));
  }
  Future<void> _pickColor(BuildContext context) async {
    const colors = [0xFF4F46E5,0xFF2563EB,0xFF0891B2,0xFF059669,0xFFEA580C,0xFFDB2777];
    final value = await showModalBottomSheet<int>(context: context, builder: (_) => SafeArea(child: Wrap(children: colors.map((c) => ListTile(leading: CircleAvatar(backgroundColor: Color(c)), title: Text('#'+c.toRadixString(16).substring(2).toUpperCase()), onTap: () => Navigator.pop(context,c))).toList())));
    if(value != null) await appTheme.setSeed(value);
  }
}