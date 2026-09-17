// Auth OTP flow: email code + owner authorization.
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'group_management.dart';
import 'channel_management.dart';
import 'invite.dart';
import 'profile_page.dart';
import 'call_session.dart';
import 'voice_message_player.dart';

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
  int seed = 0xFF7C5CFF;
  String get _scope { final uid = Supabase.instance.client.auth.currentUser?.id; return uid == null ? 'guest' : uid; }
  Future<void> load() async => loadForUser();
  Future<void> loadForUser() async { final p = await SharedPreferences.getInstance(); final key = _scope; dark = p.getBool('dark_mode_$key') ?? false; seed = p.getInt('accent_seed_$key') ?? 0xFF7C5CFF; notifyListeners(); }
  Future<void> setDark(bool value) async { dark = value; final p = await SharedPreferences.getInstance(); await p.setBool('dark_mode_$_scope', value); notifyListeners(); }
  Future<void> setSeed(int value) async { seed = value; final p = await SharedPreferences.getInstance(); await p.setInt('accent_seed_$_scope', value); notifyListeners(); }
}
final appTheme = AppThemeController();
final aradLanguageController = LanguageController();
class AppStrings { static const supported = ['fa', 'en', 'ar', 'tr', 'fr', 'de']; static const names = {'fa':'فارسی','en':'English','ar':'العربية','tr':'Türkçe','fr':'Français','de':'Deutsch'}; }
const supabaseUrl = 'https://bkbdcqequyvubjmrbpqo.supabase.co';
const supabasePublishableKey = 'sb_publishable_-wIHh9FKu-lmXSMHRWBbFw_t9u5KutA';
const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');
const ownerEmail = String.fromEnvironment('OWNER_EMAIL', defaultValue: 'harad896@gmail.com');
final googleSignIn = GoogleSignIn.instance;
final supabase = Supabase.instance.client;
String? authRedirectUrl() { if (!kIsWeb) return null; final uri = Uri.base; if (uri.scheme != 'http' && uri.scheme != 'https') return null; return uri.origin; }
Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey); await appTheme.load(); await aradLanguageController.load(); runApp(const AradMessenger()); }

class AradMessenger extends StatelessWidget {
  const AradMessenger({super.key});
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: Listenable.merge([appTheme, aradLanguageController]), builder: (context, _) => MaterialApp(
    locale: aradLanguageController.locale,
    supportedLocales: AppStrings.supported.map((x) => Locale(x)),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    debugShowCheckedModeBanner: false,
    title: 'Arad Messenger',
    theme: ThemeData(useMaterial3: true, fontFamily: 'Vazirmatn', colorScheme: ColorScheme.fromSeed(seedColor: Color(appTheme.seed), brightness: Brightness.light, surface: const Color(0xFFF5F5F7)), scaffoldBackgroundColor: const Color(0xFFF5F5F7)),
    darkTheme: ThemeData(useMaterial3: true, fontFamily: 'Vazirmatn', colorScheme: ColorScheme.fromSeed(seedColor: Color(appTheme.seed), brightness: Brightness.dark, surface: const Color(0xFF111114)), scaffoldBackgroundColor: const Color(0xFF09090B)),
    themeMode: appTheme.dark ? ThemeMode.dark : ThemeMode.light,
    home: const AuthGate(),
  ));
}

void showMsg(BuildContext context, String text) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
String normalizeOtpDigits(String value) => value.replaceAll('۰','0').replaceAll('۱','1').replaceAll('۲','2').replaceAll('۳','3').replaceAll('۴','4').replaceAll('۵','5').replaceAll('۶','6').replaceAll('۷','7').replaceAll('۸','8').replaceAll('۹','9').replaceAll('٠','0').replaceAll('١','1').replaceAll('٢','2').replaceAll('٣','3').replaceAll('٤','4').replaceAll('٥','5').replaceAll('٦','6').replaceAll('٧','7').replaceAll('٨','8').replaceAll('٩','9');

// ... existing application code ...
