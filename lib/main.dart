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
import 'invite.dart';
import 'profile_page.dart';


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
  int seed = 0xFF5B6FB5;

  String get _scope {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return uid == null ? 'guest' : uid;
  }

  Future<void> load() async => loadForUser();
  Future<void> loadForUser() async {
    final p = await SharedPreferences.getInstance();
    final key = _scope;
    dark = p.getBool('dark_mode_$key') ?? false;
    seed = p.getInt('accent_seed_$key') ?? 0xFF5B6FB5;
    notifyListeners();
  }
  Future<void> setDark(bool value) async {
    dark = value;
    final p = await SharedPreferences.getInstance();
    await p.setBool('dark_mode_$_scope', value);
    notifyListeners();
  }
  Future<void> setSeed(int value) async {
    seed = value;
    final p = await SharedPreferences.getInstance();
    await p.setInt('accent_seed_$_scope', value);
    notifyListeners();
  }
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
          surface: const Color(0xFFF4F6FA),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        visualDensity: VisualDensity.standard,
        splashFactory: InkSparkle.splashFactory,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xDFF4F6FA),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF151821),
          ),
          iconTheme: IconThemeData(color: Color(0xFF30323A)),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Color(0xB8FFFFFF),
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            side: BorderSide(color: Color(0x1A4F46E5)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xB8FFFFFF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: Color(0x26303746)),
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
          primary: const Color(0xFF6E83C4),
          secondary: const Color(0xFF8B5FBF),
          tertiary: const Color(0xFFB45CC8),
          surface: const Color(0xFF111014),
        ),
        scaffoldBackgroundColor: const Color(0xFF111014),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xE6111014),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Color(0xB81C1A20),
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            side: BorderSide(color: Color(0x1FFFFFFF)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xB81C1A20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: Color(0x24FFFFFF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: Color(0x22FFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide(color: Color(0xFF7C8FD6), width: 1.6),
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

class ChatFoldersPage extends StatefulWidget {
  const ChatFoldersPage({super.key});
  @override State<ChatFoldersPage> createState()=>_ChatFoldersPageState();
}
class _ChatFoldersPageState extends State<ChatFoldersPage> {
  final folders=<String>['همه گفتگوها','کار','خانواده','ناخوانده‌ها'];
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('پوشه‌های گفتگو')),
    body: ListView.builder(padding: const EdgeInsets.all(14), itemCount: folders.length, itemBuilder: (_,i) => Card(child: ListTile(leading: Icon(i==0 ? Icons.chat_bubble_outline_rounded : Icons.folder_rounded), title: Text(folders[i])))),
    floatingActionButton: FloatingActionButton(
      onPressed: () => showDialog(context: context, builder: (_) {
        final c=TextEditingController();
        return AlertDialog(title: const Text('پوشه جدید'), content: TextField(controller:c, decoration: const InputDecoration(labelText:'نام پوشه')), actions: [
          TextButton(onPressed:()=>Navigator.pop(context), child:const Text('لغو')),
          FilledButton(onPressed:(){if(c.text.trim().isNotEmpty)setState(()=>folders.add(c.text.trim()));Navigator.pop(context);}, child:const Text('افزودن')),
        ]);
      }),
      child: const Icon(Icons.add_rounded),
    ),
  );
}
class DataAndPermissionsPage extends StatefulWidget {
  const DataAndPermissionsPage({super.key});
  @override State<DataAndPermissionsPage> createState()=>_DataAndPermissionsPageState();
}
class _DataAndPermissionsPageState extends State<DataAndPermissionsPage> {
  bool lowData=false,wifiOnly=false,highContrast=false; double fontScale=1;
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('داده و دسترسی‌پذیری')),body:ListView(padding:const EdgeInsets.all(14),children:[
    Card(child:SwitchListTile(title:const Text('حالت کم‌مصرف'),value:lowData,onChanged:(v)=>setState(()=>lowData=v))),
    Card(child:SwitchListTile(title:const Text('دانلود خودکار فقط با وای‌فای'),value:wifiOnly,onChanged:(v)=>setState(()=>wifiOnly=v))),
    Card(child:SwitchListTile(title:const Text('کنتراست بالا'),value:highContrast,onChanged:(v)=>setState(()=>highContrast=v))),
    Card(child:ListTile(title:const Text('اندازه فونت'),subtitle:Text('${(fontScale*100).round()}%'),trailing:SizedBox(width:170,child:Slider(value:fontScale,min:.8,max:1.4,onChanged:(v)=>setState(()=>fontScale=v))))),
    const ListTile(title:Text('اعلان‌ها و لرزش'),subtitle:Text('پیام، تماس و گروه')),
    const ListTile(title:Text('دستگاه‌های متصل'),subtitle:Text('مدیریت ورود هم‌زمان')),
  ]));
}
class PermissionInfoPage extends StatelessWidget {
  final String title,reason; final IconData icon;
  const PermissionInfoPage({super.key,required this.title,required this.reason,required this.icon});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(title)),body:Padding(padding:const EdgeInsets.all(20),child:Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:52,color:Theme.of(context).colorScheme.primary),const SizedBox(height:16),Text(reason,textAlign:TextAlign.center),const SizedBox(height:20),FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('ادامه'))])))));
}
class PremiumEmptyState extends StatelessWidget {
  final IconData icon; final String title, subtitle;
  const PremiumEmptyState({super.key,required this.icon,required this.title,required this.subtitle});
  @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(32),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Container(width:86,height:86,decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(28)),child:Icon(icon,size:40)),
    const SizedBox(height:20),Text(title,textAlign:TextAlign.center,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
    const SizedBox(height:8),Text(subtitle,textAlign:TextAlign.center)
  ])));
}
class PremiumPageRoute<T> extends PageRouteBuilder<T> {
  PremiumPageRoute({required Widget page}):super(
    pageBuilder:(context,a,b)=>page,
    transitionsBuilder:(context,a,b,child)=>FadeTransition(opacity:a,child:SlideTransition(
      position:Tween(begin:const Offset(.035,0),end:Offset.zero).animate(CurvedAnimation(parent:a,curve:Curves.easeOutCubic)),child:child)),
    transitionDuration:const Duration(milliseconds:260),
  );
}
class ProfessionalSettingsPage extends StatefulWidget {
  const ProfessionalSettingsPage({super.key});
  @override State<ProfessionalSettingsPage> createState()=>_ProfessionalSettingsPageState();
}
class _ProfessionalSettingsPageState extends State<ProfessionalSettingsPage>{
  final search=TextEditingController();
  String theme='خودکار',language='فارسی',privacy='مخاطبینم',layout='راحت',backup='هفتگی';
  double font=1;
  bool dnd=false,highContrast=false,reducedMotion=false,wifiOnly=true;
  @override void dispose(){search.dispose();super.dispose();}
  List<Map<String,String>> get items=>[
    {'cat':'حساب کاربری','title':'حساب کاربری','desc':'نام، نام کاربری، ایمیل، بیو و عکس پروفایل','value':'ویرایش اطلاعات'},
    {'cat':'حریم خصوصی و امنیت','title':'حریم خصوصی','desc':'کنترل اینکه چه کسانی اطلاعات شما را ببینند','value':privacy},
    {'cat':'حریم خصوصی و امنیت','title':'امنیت','desc':'قفل برنامه، تأیید دومرحله‌ای و دستگاه‌های متصل','value':'مدیریت امنیت'},
    {'cat':'اعلان‌ها','title':'اعلان‌ها','desc':'صدای پیام، لرزش و پیش‌نمایش برای هر نوع اعلان','value':'شخصی‌سازی'},
    {'cat':'ظاهر و شخصی‌سازی','title':'ظاهر','desc':'تم و رنگ برنامه را انتخاب کنید','value':theme},
    {'cat':'ظاهر و شخصی‌سازی','title':'زبان','desc':'زبان رابط کاربری برنامه','value':language},
    {'cat':'داده و ذخیره‌سازی','title':'داده و ذخیره‌سازی','desc':'مصرف رسانه و دانلود خودکار را کنترل کنید','value':wifiOnly?'فقط Wi-Fi':'آزاد'},
    {'cat':'پشتیبان‌گیری','title':'پشتیبان‌گیری','desc':'زمان‌بندی و مقصد ذخیره نسخه پشتیبان','value':backup},
    {'cat':'درباره','title':'درباره برنامه','desc':'نسخه، حریم خصوصی و پشتیبانی','value':'نسخه 1.0.0'},
  ];
  @override Widget build(BuildContext context){
    final q=search.text.trim();
    final filtered=items.where((x)=>q.isEmpty||x.values.any((v)=>v.contains(q))).toList();
    final groups=<String,List<Map<String,String>>>{};
     for(final x in filtered){ final cat=x['cat'] ?? ''; (groups[cat] ??= <Map<String,String>>[]).add(x); }
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات'),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(66), child: Padding(
          padding: const EdgeInsets.fromLTRB(14,4,14,10),
          child: TextField(controller:search,onChanged:(_)=>setState((){}),decoration:InputDecoration(
            hintText:'جستجو در تنظیمات',prefixIcon:const Icon(Icons.search_rounded),filled:true,
            border:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide.none),
          )),
        )),
      ),
      body:
    body:ListView(padding:const EdgeInsets.fromLTRB(14,10,14,30),children:[
      ...groups.entries.expand((g)=>[Padding(padding:const EdgeInsets.fromLTRB(4,18,4,8),child:Text(g.key,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w800))),...g.value.map((x)=>Card(child:ListTile(
        contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:5),
        leading:Icon(_iconForSetting(x['title']!)),title:Text(x['title']!,style:const TextStyle(fontWeight:FontWeight.w700)),
        subtitle:Text(x['desc']!),trailing:ConstrainedBox(constraints:const BoxConstraints(maxWidth:100),child:Text(x['value']!,textAlign:TextAlign.end,style:TextStyle(color:Theme.of(context).colorScheme.primary,fontWeight:FontWeight.w700))),
        onTap:()=>_open(x['title']!),
      )))])
    ]);
  }
  IconData _iconForSetting(String s)=>switch(s){'حساب کاربری'=>Icons.person_outline_rounded,'حریم خصوصی'=>Icons.visibility_outlined,'امنیت'=>Icons.shield_outlined,'اعلان‌ها'=>Icons.notifications_none_rounded,'ظاهر'=>Icons.palette_outlined,'زبان'=>Icons.language_rounded,'داده و ذخیره‌سازی'=>Icons.data_usage_rounded,'پشتیبان‌گیری'=>Icons.cloud_outlined,'درباره برنامه'=>Icons.info_outline_rounded,_=>Icons.settings_outlined};
  void _open(String title){
    if(title=='ظاهر'){showModalBottomSheet(context:context,builder:(_)=>_ChoiceSheet(title:'ظاهر',options:['روشن','تاریک','خودکار'],value:theme,onChanged:(v){setState(()=>theme=v);Navigator.pop(context);},));}
    else if(title=='زبان'){showModalBottomSheet(context:context,builder:(_)=>_ChoiceSheet(title:'زبان',options:['فارسی','English','العربية'],value:language,onChanged:(v){setState(()=>language=v);Navigator.pop(context);}));}
    else if(title=='پشتیبان‌گیری'){showModalBottomSheet(context:context,builder:(_)=>_ChoiceSheet(title:'پشتیبان‌گیری',options:['روزانه','هفتگی','ماهانه'],value:backup,onChanged:(v){setState(()=>backup=v);Navigator.pop(context);}));}
    else if(title=='داده و ذخیره‌سازی'){setState(()=>wifiOnly=!wifiOnly);}
    else if(title=='امنیت'){Navigator.push(context,MaterialPageRoute(builder:(_)=>const SecurityCenterPage()));}
    else if(title=='درباره برنامه'){Navigator.push(context,MaterialPageRoute(builder:(_)=>const AboutAppPage()));}
  }
}
class _ChoiceSheet extends StatelessWidget{
  final String title,value; final List<String> options; final ValueChanged<String> onChanged;
  const _ChoiceSheet({required this.title,required this.options,required this.value,required this.onChanged});
  @override Widget build(BuildContext context)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[Padding(padding:const EdgeInsets.all(18),child:Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800))),...options.map((o)=>RadioListTile(value:o,groupValue:value,onChanged:(v)=>onChanged(v!),title:Text(o)))]));
}
class AppAppearancePage extends StatefulWidget {
  const AppAppearancePage({super.key});
  @override State<AppAppearancePage> createState()=>_AppAppearancePageState();
}
class _AppAppearancePageState extends State<AppAppearancePage>{
  String mode='خودکار';
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('ظاهر برنامه')),body:ListView(padding:const EdgeInsets.all(14),children:[
    Card(child:RadioListTile(value:'روشن',groupValue:mode,onChanged:(v)=>setState(()=>mode=v!),title:const Text('روشن'))),
    Card(child:RadioListTile(value:'تاریک',groupValue:mode,onChanged:(v)=>setState(()=>mode=v!),title:const Text('تاریک'))),
    Card(child:RadioListTile(value:'خودکار',groupValue:mode,onChanged:(v)=>setState(()=>mode=v!),title:const Text('خودکار'))),
  ]));
}
class CallHistoryPage extends StatelessWidget {
  const CallHistoryPage({super.key});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('تاریخچه تماس‌ها')),body:ListView(children:[
    ListTile(leading:Icon(Icons.call_received_rounded,color:Theme.of(context).colorScheme.primary),title:const Text('تماس صوتی'),subtitle:const Text('دریافتی • امروز'),trailing:IconButton(onPressed:(){},icon:const Icon(Icons.call_rounded))),
    ListTile(leading:Icon(Icons.videocam_rounded,color:Theme.of(context).colorScheme.secondary),title:const Text('تماس تصویری'),subtitle:const Text('ارسالی • دیروز'),trailing:IconButton(onPressed:(){},icon:const Icon(Icons.videocam_rounded))),
    ListTile(leading:Icon(Icons.call_missed_rounded,color:Theme.of(context).colorScheme.error),title:const Text('تماس بی‌پاسخ'),subtitle:const Text('امروز'),trailing:IconButton(onPressed:(){},icon:const Icon(Icons.call_rounded))),
  ]));
}
class NotificationsCenterPage extends StatefulWidget {
  const NotificationsCenterPage({super.key});
  @override State<NotificationsCenterPage> createState()=>_NotificationsCenterPageState();
}
class _NotificationsCenterPageState extends State<NotificationsCenterPage>{
  final read=<bool>[false,false,true];
  final items=<String>['پیام جدید دریافت شد','درخواست عضویت در گروه','به‌روزرسانی برنامه'];
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('مرکز اعلان‌ها')),body:ListView.builder(itemCount:items.length,itemBuilder:(_,i)=>ListTile(onTap:()=>setState(()=>read[i]=true),leading:Icon(read[i]?Icons.notifications_none_rounded:Icons.notifications_active_rounded,color:read[i]?null:Theme.of(context).colorScheme.primary),title:Text(items[i],style:TextStyle(fontWeight:read[i]?FontWeight.w400:FontWeight.w800)),subtitle:Text(read[i]?'خوانده شده':'خوانده نشده'))));
}
class SharedMediaFilesPage extends StatelessWidget {
  const SharedMediaFilesPage({super.key});
  @override Widget build(BuildContext context)=>DefaultTabController(length:4,child:Scaffold(appBar:AppBar(title:const Text('رسانه‌ها و فایل‌های مشترک'),bottom:const TabBar(tabs:[Tab(text:'عکس/ویدیو'),Tab(text:'فایل'),Tab(text:'لینک'),Tab(text:'صدا')])),body:const TabBarView(children:[Center(child:Text('رسانه‌ای وجود ندارد')),Center(child:Text('فایلی وجود ندارد')),Center(child:Text('لینکی وجود ندارد')),Center(child:Text('صدایی وجود ندارد'))])));
}
class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});
  @override State<GlobalSearchPage> createState()=>_GlobalSearchPageState();
}
class _GlobalSearchPageState extends State<GlobalSearchPage>{
  final c=TextEditingController();
  @override void dispose(){c.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:TextField(controller:c,autofocus:true,decoration:const InputDecoration(hintText:'جستجو در همه گفتگوها و مخاطبین',border:InputBorder.none),onChanged:(_)=>setState((){}))),body:c.text.trim().isEmpty?const Center(child:Text('نام مخاطب، گفتگو یا پیام را جستجو کنید')):ListView(children:const[ _SearchSection(title:'مخاطبین'),_SearchSection(title:'گفتگوها'),_SearchSection(title:'پیام‌ها')]));
}
class _SearchSection extends StatelessWidget {
  final String title; const _SearchSection({required this.title});
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Padding(padding:const EdgeInsets.fromLTRB(16,18,16,8),child:Text(title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17))),const ListTile(leading:Icon(Icons.search_rounded),title:Text('نتیجه جستجو'))]);
}
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override State<BackupPage> createState()=>_BackupPageState();
}
class _BackupPageState extends State<BackupPage>{bool auto=true;@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('پشتیبان‌گیری و بازیابی')),body:ListView(padding:const EdgeInsets.all(14),children:[Card(child:SwitchListTile(title:const Text('پشتیبان‌گیری خودکار'),value:auto,onChanged:(v)=>setState(()=>auto=v))),const Card(child:ListTile(title:Text('آخرین پشتیبان'),subtitle:Text('هنوز پشتیبانی ثبت نشده'),trailing:Text('—'))),const Card(child:ListTile(title:Text('حجم پشتیبان'),subtitle:Text('محاسبه پس از اولین پشتیبان'),trailing:Text('—'))),FilledButton(onPressed:(){},child:const Text('پشتیبان‌گیری اکنون'))]));}
class StickersGifsPage extends StatelessWidget {
  const StickersGifsPage({super.key});
  @override Widget build(BuildContext context)=>DefaultTabController(length:3,child:Scaffold(appBar:AppBar(title:const Text('استیکر و ایموجی'),bottom:const TabBar(tabs:[Tab(text:'استیکرها'),Tab(text:'GIF'),Tab(text:'ایموجی')])),body:TabBarView(children:[ListView(children:const[ListTile(leading:Icon(Icons.stars_rounded),title:Text('پک‌های استیکر من')),ListTile(leading:Icon(Icons.add_rounded),title:Text('افزودن پک'))]),Center(child:TextField(decoration:InputDecoration(hintText:'جستجوی GIF',prefixIcon:Icon(Icons.search_rounded)))),GridView.count(crossAxisCount:6,children:List.generate(24,(i)=>Center(child:Text(['😀','❤️','👍','😂','🔥','🎉'][i%6],style:const TextStyle(fontSize:25)))))])));
}
class SecurityCenterPage extends StatelessWidget {
  const SecurityCenterPage({super.key});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('امنیت پیشرفته')),body:ListView(padding:const EdgeInsets.all(14),children:[
    Card(child:SwitchListTile(title:const Text('تأیید دومرحله‌ای'),value:false,onChanged:(_){},secondary:const Icon(Icons.verified_user_rounded))),
    const Card(child:ListTile(title:Text('دستگاه‌های متصل'),subtitle:Text('مدیریت نشست‌های فعال'),trailing:Icon(Icons.chevron_left_rounded))),
    const Card(child:ListTile(title:Text('مخاطبین مسدودشده'),trailing:Icon(Icons.chevron_left_rounded))),
    const Card(child:ListTile(title:Text('پیام‌های خودتخریب‌شونده'),subtitle:Text('تنظیم زمان حذف خودکار'),trailing:Icon(Icons.timer_rounded))),
  ]));
}
class GroupAdvancedPage extends StatefulWidget {
  const GroupAdvancedPage({super.key});
  @override State<GroupAdvancedPage> createState()=>_GroupAdvancedPageState();
}
class _GroupAdvancedPageState extends State<GroupAdvancedPage>{final q=TextEditingController();@override void dispose(){q.dispose();super.dispose();}@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('پیام‌رسانی گروهی')),body:ListView(padding:const EdgeInsets.all(14),children:[Card(child:ListTile(leading:const Icon(Icons.poll_rounded),title:const Text('نظرسنجی'),onTap:()=>showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('نظرسنجی جدید'),content:TextField(controller:q,decoration:const InputDecoration(labelText:'سؤال')),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('ساخت'))])))),const Card(child:ListTile(leading:Icon(Icons.push_pin_rounded),title:Text('پیام‌های پین‌شده'))),const Card(child:ListTile(leading:Icon(Icons.alternate_email_rounded),title:Text('ذکر اعضا با @')))]));}
class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('درباره برنامه')),body:ListView(padding:const EdgeInsets.all(14),children:[const Card(child:ListTile(title:Text('Arad Messenger'),subtitle:Text('نسخه 1.0.0'))),const Card(child:ListTile(title:Text('حریم خصوصی'),trailing:Icon(Icons.chevron_left_rounded))),const Card(child:ListTile(title:Text('تماس با پشتیبانی'),trailing:Icon(Icons.chevron_left_rounded))),Card(child:ListTile(title:const Text('امتیاز به برنامه'),trailing:Icon(Icons.star_rounded,color:Colors.amber),onTap:(){}))]));}
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


const _secureAccounts = FlutterSecureStorage();
Future<void> rememberCurrentSession() async {
  final user=supabase.auth.currentUser, session=supabase.auth.currentSession;
  if(user==null||session==null||session.refreshToken==null)return;
  final mail=(user.email??'').trim().toLowerCase(); if(mail.isEmpty)return;
  await _secureAccounts.write(key:'account_refresh_${mail}',value:session.refreshToken);
  await _rememberAccount(mail);
}
Future<List<String>> rememberedAccountEmails()=>_savedAccountEmails();

class LoginPage extends StatefulWidget {
  final bool addAccount;
  const LoginPage({super.key,this.addAccount=false});
  @override State<LoginPage> createState()=>_LoginPageState();
}
class _LoginPageState extends State<LoginPage>{
  final email=TextEditingController(),password=TextEditingController(),first=TextEditingController(),last=TextEditingController();
  bool signup=false,busy=false,obscure=true; String? emailError,passwordError;
  bool validEmail(String v)=>RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim());
  String? passwordMessage(String v){if(v.isEmpty)return 'رمز عبور را وارد کنید';if(v.length<8)return 'حداقل ۸ کاراکتر';if(!RegExp(r'[A-Z]').hasMatch(v))return 'حداقل یک حرف بزرگ';if(!RegExp(r'[0-9]').hasMatch(v))return 'حداقل یک عدد';return null;}
  Future<void> submit() async {
    final mail=email.text.trim().toLowerCase();
    if(!validEmail(mail)){setState(()=>emailError='ایمیل معتبر نیست');return;}
    if(signup){
      if(first.text.trim().isEmpty||last.text.trim().isEmpty){showMsg(context,'نام و نام خانوادگی را وارد کنید.');return;}
      setState(()=>busy=true);
      try{
        await supabase.auth.signOut();
        await supabase.auth.signInWithOtp(email:mail,shouldCreateUser:true,data:{'first_name':first.text.trim(),'last_name':last.text.trim(),'full_name':'${first.text.trim()} ${last.text.trim()}'});
        if(mounted)Navigator.push(context,MaterialPageRoute(builder:(_)=>EmailVerificationPage(email:mail,verificationType:OtpType.email,allowCreateUser:true)));
      }on AuthException catch(e){if(mounted)showMsg(context,'ثبت‌نام ناموفق بود: ${e.message}');}
      finally{if(mounted)setState(()=>busy=false);}
    }else{
      final pe=passwordMessage(password.text);if(pe!=null){setState(()=>passwordError=pe);return;}
      setState(()=>busy=true);
      try{
        await supabase.auth.signInWithPassword(email:mail,password:password.text);
        await rememberCurrentSession();await appTheme.loadForUser();
        if(mounted)Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const ProfileGate()),(_)=>false);
      }on AuthException catch(e){if(mounted)showMsg(context,'ورود ناموفق بود: ${e.message}');}
      finally{if(mounted)setState(()=>busy=false);}
    }
  }
  Future<void> forgotPassword()async{final mail=email.text.trim().toLowerCase();if(!validEmail(mail)){showMsg(context,'ابتدا ایمیل معتبر را وارد کنید.');return;}try{await supabase.auth.resetPasswordForEmail(mail);if(mounted)showMsg(context,'لینک بازیابی رمز به ایمیل ارسال شد.');}catch(e){if(mounted)showMsg(context,'ارسال لینک ناموفق بود: $e');}}
  @override Widget build(BuildContext context){final t=Theme.of(context);return Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(22),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:520),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Container(height:82,decoration:BoxDecoration(gradient:LinearGradient(colors:[t.colorScheme.primary,t.colorScheme.secondary]),borderRadius:BorderRadius.circular(24)),child:const Icon(Icons.forum_rounded,size:46,color:Colors.white)),
    const SizedBox(height:18),const Text('Arad Messenger',textAlign:TextAlign.center,style:TextStyle(fontSize:29,fontWeight:FontWeight.w800)),const SizedBox(height:20),
    Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[
      if(signup)...[TextField(controller:first,decoration:const InputDecoration(labelText:'نام',prefixIcon:Icon(Icons.person_outline))),const SizedBox(height:12),TextField(controller:last,decoration:const InputDecoration(labelText:'نام خانوادگی',prefixIcon:Icon(Icons.badge_outlined))),const SizedBox(height:12)],
      TextField(controller:email,keyboardType:TextInputType.emailAddress,onChanged:(v)=>setState(()=>emailError=validEmail(v)?null:'ایمیل معتبر نیست'),decoration:InputDecoration(labelText:'ایمیل',errorText:emailError,prefixIcon:const Icon(Icons.email_outlined))),
      if(!signup)...[TextField(controller:password,obscureText:obscure,onChanged:(v)=>setState(()=>passwordError=passwordMessage(v)),decoration:InputDecoration(labelText:'رمز عبور',errorText:passwordError,prefixIcon:const Icon(Icons.lock_outline_rounded),suffixIcon:IconButton(onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility:Icons.visibility_off)))),],
      if(!signup)Align(alignment:Alignment.centerRight,child:TextButton(onPressed:busy?null:forgotPassword,child:const Text('رمز را فراموش کرده‌ام'))),
      const SizedBox(height:8),SizedBox(height:52,width:double.infinity,child:FilledButton(onPressed:busy?null:submit,child:busy?const CircularProgressIndicator():Text(signup?'ثبت‌نام و دریافت کد':'ورود'))),
      const SizedBox(height:8),TextButton(onPressed:busy?null:()=>setState(()=>signup=!signup),child:Text(signup?'حساب دارم؛ ورود':'حساب ندارم؛ ثبت‌نام'))
    ])))
  ]))))));}
  @override void dispose(){email.dispose();password.dispose();first.dispose();last.dispose();super.dispose();}
}

class PasswordSetupPage extends StatefulWidget{const PasswordSetupPage({super.key});@override State<PasswordSetupPage> createState()=>_PasswordSetupPageState();}
class _PasswordSetupPageState extends State<PasswordSetupPage>{
 final p=TextEditingController(),c=TextEditingController();bool busy=false;
 String? err(String v)=>v.length<8||!RegExp(r'[A-Z]').hasMatch(v)||!RegExp(r'[0-9]').hasMatch(v)?'حداقل ۸ کاراکتر، یک حرف بزرگ و یک عدد لازم است':null;
 Future<void> save()async{if(p.text!=c.text){showMsg(context,'رمزها یکسان نیستند.');return;}final e=err(p.text);if(e!=null){showMsg(context,e);return;}setState(()=>busy=true);try{await supabase.auth.updateUser(UserAttributes(password:p.text));await rememberCurrentSession();if(mounted)Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const ProfileGate()),(_)=>false);}catch(e){if(mounted)showMsg(context,'ذخیره رمز ناموفق بود: $e');}finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('ساخت رمز عبور')),body:ListView(padding:const EdgeInsets.all(20),children:[const Text('ساخت رمز عبور',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:18),TextField(controller:p,obscureText:true,onChanged:(_)=>setState((){}),decoration:InputDecoration(labelText:'رمز عبور',errorText:err(p.text))),const SizedBox(height:12),TextField(controller:c,obscureText:true,decoration:const InputDecoration(labelText:'تکرار رمز عبور')),const SizedBox(height:20),FilledButton(onPressed:busy?null:save,child:Text(busy?'در حال ذخیره...':'ادامه'))]));
 @override void dispose(){p.dispose();c.dispose();super.dispose();}
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

      if (widget.allowCreateUser) { if (!mounted) return; Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PasswordSetupPage())); return; }
      await rememberCurrentSession();
      // Theme is private to the signed-in account, not shared between accounts.
      await appTheme.loadForUser();

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


class _ChatSkeleton extends StatelessWidget {
  const _ChatSkeleton();
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    Widget bar(double w, double h) => Container(
      width: w, height: h,
      decoration: BoxDecoration(
        color: s.onSurface.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
      ),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 7),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(radius: 25, backgroundColor: s.onSurface.withValues(alpha: .07)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            bar(140, 14), const SizedBox(height: 9), bar(210, 11),
          ])),
        ]),
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
  final TextEditingController chatSearch = TextEditingController();
  String chatQuery = '';

  List<Map<String, dynamic>> get visibleChats {
    final type = selectedFilter >= 1 && selectedFilter <= 3
        ? ['direct', 'group', 'channel'][selectedFilter - 1]
        : null;
    final unreadOnly = selectedFilter == 4;
    return chats.where((c) {
      final matchesType = type == null || c['type'].toString() == type;
      final unreadCount = int.tryParse('${c['unread_count'] ?? c['unread'] ?? 0}') ?? 0;
      final isUnread = unreadCount > 0 || c['unread'] == true;
      final q = chatQuery.trim().toLowerCase();
      final title = (c['title'] ?? '').toString().toLowerCase();
      final last = (c['last_message'] ?? '').toString().toLowerCase();
      return matchesType && (!unreadOnly || isUnread) &&
          (q.isEmpty || title.contains(q) || last.contains(q));
    }).toList();
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

  @override
  void dispose() { chatSearch.dispose(); super.dispose(); }

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
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: TextField(
            controller: chatSearch,
            onChanged: (v) => setState(() => chatQuery = v),
            textDirection: TextDirection.rtl,
            decoration: const InputDecoration(
              hintText: 'جستجوی گفتگو...',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: List.generate(4, (i) {
            const labels = ['تمامی گفتگوها', 'مخاطبین', 'گروه‌ها', 'کانال‌ها', 'خوانده‌نشده'];
            const icons = [Icons.forum_rounded, Icons.person_rounded, Icons.groups_rounded, Icons.campaign_rounded, Icons.mark_email_unread_rounded];
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
              ? ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 90),
                  itemCount: 7,
                  itemBuilder: (_, __) => const _ChatSkeleton(),
                )
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
                        final unreadCount = int.tryParse('${c['unread_count'] ?? c['unread'] ?? 0}') ?? 0;
                        final unread = unreadCount > 0 || c['unread'] == true;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Card(
                              color: theme.colorScheme.surface.withValues(alpha: .66),
                              margin: const EdgeInsets.only(bottom: 7),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                leading: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(backgroundColor: theme.colorScheme.primaryContainer, child: Icon(icon, color: theme.colorScheme.primary)),
                                    if (c['is_online'] == true) Positioned(
                                      right: -1, bottom: -1,
                                      child: Container(width: 12, height: 12, decoration: BoxDecoration(
                                        color: const Color(0xFF22C55E),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: theme.colorScheme.surface, width: 2),
                                      )),
                                    ),
                                  ],
                                ),
                                title: Row(children: [
                                  Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                                  if (unread) Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                                    child: Text(unreadCount > 0 ? '$unreadCount' : 'جدید', style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 10, fontWeight: FontWeight.w800)),
                                  ),
                                ]),
                                subtitle: Text((c['last_message'] ?? 'شروع گفتگو').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: const Icon(Icons.chevron_left_rounded),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(id: c['id'].toString(), title: title))),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget contactsView() {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Row(children: [
          const Expanded(child: Text('مخاطبین', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900))),
          IconButton.filledTonal(onPressed: () => showSearch(context: context, delegate: ContactSearchDelegate()), icon: const Icon(Icons.person_add_alt_1_rounded)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          Expanded(child: _glassAction(Icons.person_add_rounded, 'افزودن مخاطب', () => showSearch(context: context, delegate: ContactSearchDelegate()))),
          const SizedBox(width: 8),
          Expanded(child: _glassAction(Icons.groups_rounded, 'ایجاد گروه', createGroup)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: _glassAction(Icons.campaign_rounded, 'ایجاد کانال', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChannelCreatePage())).then((_) => load())),
      ),
      Expanded(child: FutureBuilder<List<Map<String,dynamic>>>(
        future: _loadContacts(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final rows = snap.data ?? [];
          if (rows.isEmpty) return const Center(child: Text('هنوز مخاطبی اضافه نکرده‌اید.'));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
            itemCount: rows.length,
            separatorBuilder: (_,__) => const SizedBox(height: 6),
            itemBuilder: (_,i) {
              final p = rows[i];
              final title = (p['display_name'] ?? p['username'] ?? 'کاربر').toString();
              return Card(child: ListTile(
                leading: avatar(p),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text((p['username'] == null || p['username'].toString().isEmpty) ? '' : '@' + p['username'].toString()),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(id: p['_conversation_id'].toString(), title: title))),
              ));
            },
          );
        },
      )),
    ]);
  }

  Future<List<Map<String,dynamic>>> _loadContacts() async {
    final uid = supabase.auth.currentUser!.id;
    final rows = await supabase.from('contacts').select('contact_id').eq('user_id', uid);
    final ids = (rows as List).map((x) => x['contact_id']).toList();
    if (ids.isEmpty) return [];
    final profiles = List<Map<String,dynamic>>.from(await supabase.from('profiles').select('id,display_name,username,avatar_url').inFilter('id', ids));
    final members = await supabase.from('conversation_members').select('conversation_id').eq('user_id', uid);
    for (final p in profiles) {
      for (final m in (members as List)) {
        final mm = await supabase.from('conversation_members').select('user_id').eq('conversation_id', m['conversation_id']);
        if ((mm as List).length == 2 && mm.any((x) => x['user_id'].toString() == p['id'].toString())) {
          p['_conversation_id'] = m['conversation_id'];
          break;
        }
      }
    }
    return profiles.where((p) => p['_conversation_id'] != null).toList();
  }

  Widget _glassAction(IconData icon, String label, VoidCallback onTap) {
    final s = Theme.of(context).colorScheme;
    return ClipRRect(borderRadius: BorderRadius.circular(20), child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Material(color: s.surface.withValues(alpha: .70), child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(20),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: s.primary), const SizedBox(width: 7),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
          ]),
        ),
      )),
    ));
  }

  Widget settingsView() => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: const Text('تنظیمات')),
    body: ListView(padding: const EdgeInsets.all(14), children: [
      Card(child: Column(children: [
        ListTile(leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.manage_accounts_rounded, color: Theme.of(context).colorScheme.primary)), title: const Text('حساب کاربری', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('پروفایل، حساب‌ها و امنیت'), onTap: () => setState(() => navIndex = 3)),
        const Divider(height: 1),
        ListTile(leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.lock_outline_rounded, color: Theme.of(context).colorScheme.primary)), title: const Text('حریم خصوصی'), subtitle: const Text('کنترل نمایش و دسترسی‌ها'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'حریم خصوصی', icon: Icons.lock_outline_rounded)))),
        const Divider(height: 1),
        ListTile(leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.notifications_none_rounded, color: Theme.of(context).colorScheme.primary)), title: const Text('اعلان‌ها'), subtitle: const Text('اعلان پیام‌ها و گفتگوها'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'اعلان‌ها', icon: Icons.notifications_none_rounded)))),
        const Divider(height: 1),
        ListTile(leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.storage_rounded, color: Theme.of(context).colorScheme.primary)), title: const Text('ذخیره‌سازی'), subtitle: const Text('مدیریت فایل‌ها و رسانه‌ها'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'ذخیره‌سازی', icon: Icons.storage_rounded)))),
        const Divider(height: 1),
        ListTile(leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.palette_rounded, color: Theme.of(context).colorScheme.primary)), title: const Text('ظاهر برنامه'), subtitle: const Text('رنگ اصلی و حالت تاریک'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'ظاهر برنامه', icon: Icons.palette_rounded)))),
        const Divider(height: 1),
        ListTile(leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.language_rounded, color: Theme.of(context).colorScheme.primary)), title: const Text('زبان'), subtitle: Text(aradLanguageController.locale.languageCode), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'زبان', icon: Icons.language_rounded)))),
        const Divider(height: 1),
        ListTile(leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.call_rounded, color: Theme.of(context).colorScheme.primary)), title: const Text('تماس‌ها'), subtitle: const Text('تماس صوتی و تصویری'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CallsPage()))),
        const Divider(height: 1),
        ListTile(title: const Text('تاریخچه تماس‌ها'), leading: const Icon(Icons.history_rounded), onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const CallHistoryPage()))),
        ListTile(title: const Text('مرکز اعلان‌ها'), leading: const Icon(Icons.notifications_rounded), onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const NotificationsPage()))),
        ListTile(title: const Text('پشتیبان‌گیری'), leading: const Icon(Icons.backup_rounded), onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const BackupPage()))),
        ListTile(title: const Text('استیکر و ایموجی'), leading: const Icon(Icons.emoji_emotions_rounded), onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const StickersPage()))),
        ListTile(title: const Text('امنیت پیشرفته'), leading: const Icon(Icons.security_rounded), onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const SecurityPage()))),
        ListTile(title: const Text('درباره برنامه'), leading: const Icon(Icons.info_outline_rounded), onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AboutPage()))),
        ListTile(title: const Text('مدیریت گفتگو'),leading: const Icon(Icons.tune_rounded),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ConversationToolsPage(conversationId:'global')))),
        ListTile(title: const Text('افزودن مخاطب و دعوت'),leading: const Icon(Icons.person_add_alt_rounded),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ContactsToolsPage()))),
        ListTile(title: const Text('کیف پول'),leading: const Icon(Icons.account_balance_wallet_rounded),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const WalletPage()))),
        ListTile(title: const Text('مصرف داده'),leading: const Icon(Icons.data_usage_rounded),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const DataSettingsPage()))),
        ListTile(title: const Text('دسترسی‌پذیری'),leading: const Icon(Icons.accessibility_new_rounded),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AccessibilityPage()))),
        ListTile(title: const Text('دسترسی‌های برنامه'),leading: const Icon(Icons.verified_user_rounded),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PermissionScreensPage()))),
        ListTile(title: const Text('پیام‌رسانی پیشرفته'),leading: const Icon(Icons.auto_awesome_rounded),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AdvancedMessagingPage()))),
        const Divider(height: 1),
        ListTile(leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.chat_rounded, color: Theme.of(context).colorScheme.primary)), title: const Text('تنظیمات گفتگو'), subtitle: const Text('نمایش پیام‌ها و رفتار چت'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'تنظیمات چت', icon: Icons.chat_rounded)))),
        const Divider(height: 1),
        ListTile(leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.bookmark_rounded, color: Theme.of(context).colorScheme.primary)), title: const Text('پیام‌های ذخیره‌شده'), subtitle: const Text('پیام‌های مهم را یکجا نگه دارید'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SavedMessagesPage()))),
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
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedIndex: navIndex,
            onDestinationSelected: (i) => setState(() => navIndex = i),
            destinations: const [
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum_rounded), label: 'گفتگوها'),
          NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'مخاطبین'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'تنظیمات'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'پروفایل'),
            ],
          ),
        ),
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
      await supabase.from('conversation_admins').insert({'conversation_id':c['id'],'user_id':uid,'role':'owner'});
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

class ContactSearchDelegate extends SearchDelegate<Map<String,dynamic>?> {
  @override List<Widget>? buildActions(BuildContext context) => [IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear))];
  @override Widget buildLeading(BuildContext context) => IconButton(onPressed: () => close(context, null), icon: const Icon(Icons.arrow_back));
  @override Widget buildResults(BuildContext context) => _build(context);
  @override Widget buildSuggestions(BuildContext context) => _build(context);
  Widget _build(BuildContext context) => FutureBuilder(
    future: query.trim().isEmpty ? Future.value([]) : supabase.rpc('search_profiles', params: {'search_text': query.trim()}),
    builder: (context, snap) {
      if (query.trim().isEmpty) return const Center(child: Text('نام یا آیدی کاربر را جستجو کنید.'));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final users = List<Map<String,dynamic>>.from(snap.data as List);
      return ListView(children: users.map((p) => ListTile(
        leading: avatar(p),
        title: Text((p['display_name'] ?? p['username'] ?? 'کاربر').toString()),
        subtitle: Text('@' + (p['username'] ?? '').toString()),
        trailing: const Icon(Icons.person_add_alt_1_rounded),
        onTap: () async {
          final uid = supabase.auth.currentUser!.id;
          if (p['id'].toString() == uid) { showMsg(context, 'نمی‌توانید خودتان را اضافه کنید.'); return; }
          await supabase.from('contacts').upsert({'user_id': uid, 'contact_id': p['id']}, onConflict: 'user_id,contact_id');
          if (context.mounted) { showMsg(context, 'مخاطب اضافه شد.'); close(context, p); }
        },
      )).toList());
    },
  );
}

class ChannelCreatePage extends StatefulWidget {
  const ChannelCreatePage({super.key});
  @override State<ChannelCreatePage> createState() => _ChannelCreatePageState();
}
class _ChannelCreatePageState extends State<ChannelCreatePage> {
  final title = TextEditingController(); final about = TextEditingController(); bool busy = false;
  Future<void> create() async {
    if (title.text.trim().isEmpty) { showMsg(context, 'نام کانال را وارد کنید.'); return; }
    setState(() => busy = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      final c = await supabase.from('conversations').insert({'type':'channel','title':title.text.trim(),'created_by':uid}).select().single();
      await supabase.from('conversation_members').insert({'conversation_id':c['id'],'user_id':uid});
      await supabase.from('conversation_admins').insert({'conversation_id':c['id'],'user_id':uid,'role':'owner'});
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatPage(id:c['id'].toString(),title:title.text.trim())));
    } catch(e) { if(mounted) showMsg(context, 'ساخت کانال ناموفق بود: ' + e.toString()); }
    finally { if(mounted) setState(() => busy=false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true, appBar: AppBar(title: const Text('ایجاد کانال'), backgroundColor: Colors.transparent),
    body: Center(child: Padding(padding: const EdgeInsets.all(18), child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX:20,sigmaY:20), child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withValues(alpha:.76), borderRadius: BorderRadius.circular(28)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.campaign_rounded, size: 58), const SizedBox(height: 12),
          TextField(controller:title, decoration:const InputDecoration(labelText:'نام کانال',prefixIcon:Icon(Icons.campaign_outlined))),
          const SizedBox(height:10),
          TextField(controller:about,maxLines:3,decoration:const InputDecoration(labelText:'توضیحات کانال')),
          const SizedBox(height:16),
          SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:busy?null:create,icon:const Icon(Icons.add_circle_outline),label:Text(busy?'در حال ساخت...':'ساخت کانال'))),
        ]),
      )),
    ))),
  );
  @override void dispose(){title.dispose();about.dispose();super.dispose();}
}


class GroupManagementPage extends StatefulWidget {
  final String conversationId;
  final String title;
  const GroupManagementPage({super.key,required this.conversationId,required this.title});
  @override State<GroupManagementPage> createState()=>_GroupManagementPageState();
}
class _GroupManagementPageState extends State<GroupManagementPage>{
  List<Map<String,dynamic>> members=[],admins=[]; bool loading=true;
  Future<void> load()async{
    try{
      final ms=List<Map<String,dynamic>>.from(await supabase.from('conversation_members').select('user_id').eq('conversation_id',widget.conversationId));
      final ids=ms.map((x)=>x['user_id']).toList();
      members=ids.isEmpty?[]:List<Map<String,dynamic>>.from(await supabase.from('profiles').select('id,display_name,username,avatar_url').inFilter('id',ids));
      admins=List<Map<String,dynamic>>.from(await supabase.from('conversation_admins').select('user_id,role').eq('conversation_id',widget.conversationId));
      if(mounted)setState(()=>loading=false);
    }catch(e){if(mounted){setState(()=>loading=false);showMsg(context,'خطا: '+e.toString());}}
  }
  bool isAdmin(String id)=>admins.any((a)=>a['user_id'].toString()==id);
  Future<void> addMember()async{
    final r=await showSearch<Map<String,dynamic>?>(context:context,delegate:UserSearchDelegate()); if(r==null)return;
    try{await supabase.from('conversation_members').upsert({'conversation_id':widget.conversationId,'user_id':r['id']},onConflict:'conversation_id,user_id');await load();if(mounted)showMsg(context,'عضو اضافه شد.');}
    catch(e){if(mounted)showMsg(context,'افزودن عضو ناموفق بود: '+e.toString());}
  }
  Future<void> toggleAdmin(Map<String,dynamic> p)async{
    final id=p['id'].toString(); if(id==supabase.auth.currentUser!.id){showMsg(context,'مالک را نمی‌توان تغییر داد.');return;}
    try{
      if(isAdmin(id)) await supabase.from('conversation_admins').delete().eq('conversation_id',widget.conversationId).eq('user_id',id);
      else await supabase.from('conversation_admins').insert({'conversation_id':widget.conversationId,'user_id':id,'role':'admin'});
      await load();
    }catch(e){if(mounted)showMsg(context,'تغییر مدیر ناموفق بود: '+e.toString());}
  }
  Future<void> removeMember(Map<String,dynamic> p)async{
    final id=p['id'].toString(); if(id==supabase.auth.currentUser!.id){showMsg(context,'مالک را نمی‌توان حذف کرد.');return;}
    try{await supabase.from('conversation_admins').delete().eq('conversation_id',widget.conversationId).eq('user_id',id);await supabase.from('conversation_members').delete().eq('conversation_id',widget.conversationId).eq('user_id',id);await load();}
    catch(e){if(mounted)showMsg(context,'حذف عضو ناموفق بود: '+e.toString());}
  }
  @override void initState(){super.initState();load();}
  @override Widget build(BuildContext context)=>Scaffold(
    extendBodyBehindAppBar:true,
    appBar:AppBar(title:Text('مدیریت '+widget.title),backgroundColor:Colors.transparent,actions:[IconButton(onPressed:addMember,icon:const Icon(Icons.person_add_alt_1_rounded))]),
    body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.fromLTRB(12,100,12,24),children:[
      ClipRRect(borderRadius:BorderRadius.circular(24),child:BackdropFilter(filter:ImageFilter.blur(sigmaX:18,sigmaY:18),child:Container(
        decoration:BoxDecoration(color:Theme.of(context).colorScheme.surface.withValues(alpha:.72),borderRadius:BorderRadius.circular(24)),
        child:Column(children:[
          ListTile(leading:const Icon(Icons.admin_panel_settings_rounded),title:const Text('مدیریت اعضا',style:TextStyle(fontWeight:FontWeight.w900)),subtitle:Text(members.length.toString()+' عضو • '+admins.length.toString()+' مدیر')),
          const Divider(height:1),
          ...members.map((p)=>ListTile(
            leading:avatar(p),
            title:Text((p['display_name']??p['username']??'کاربر').toString(),style:const TextStyle(fontWeight:FontWeight.w700)),
            subtitle:Text(isAdmin(p['id'].toString())?'مدیر':'عضو'),
            trailing:PopupMenuButton<String>(
              onSelected:(v)=>v=='admin'?toggleAdmin(p):removeMember(p),
              itemBuilder:(_)=>[
                PopupMenuItem(value:'admin',child:Text(isAdmin(p['id'].toString())?'حذف مدیر':'انتخاب به‌عنوان مدیر')),
                const PopupMenuItem(value:'remove',child:Text('حذف عضو')),
              ],
            ),
          )),
        ]),
      )),
      ),
    ]),
  );
}



class ConversationToolsPage extends StatefulWidget {
  final String conversationId;
  const ConversationToolsPage({super.key,required this.conversationId});
  @override State<ConversationToolsPage> createState()=>_ConversationToolsPageState();
}
class _ConversationToolsPageState extends State<ConversationToolsPage>{
  bool pinned=false,archived=false,muted=false;
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('مدیریت گفتگو')),body:ListView(padding:const EdgeInsets.all(14),children:[
    Card(child:SwitchListTile(value:pinned,onChanged:(v)=>setState(()=>pinned=v),title:const Text('پین کردن گفتگو'),secondary:const Icon(Icons.push_pin_rounded))),
    Card(child:SwitchListTile(value:archived,onChanged:(v)=>setState(()=>archived=v),title:const Text('آرشیو گفتگو'),secondary:const Icon(Icons.archive_rounded))),
    Card(child:SwitchListTile(value:muted,onChanged:(v)=>setState(()=>muted=v),title:const Text('بی‌صدا کردن'),secondary:const Icon(Icons.notifications_off_rounded))),
    Card(child:ListTile(title:const Text('پوشه گفتگو'),subtitle:const Text('کار / خانواده / ناخوانده‌ها'),leading:const Icon(Icons.folder_rounded),onTap:()=>showMsg(context,'پوشه انتخاب شد'))),
    Card(child:ListTile(title:const Text('پس‌زمینه گفتگو'),leading:const Icon(Icons.wallpaper_rounded),onTap:()=>showMsg(context,'انتخاب پس‌زمینه'))),
    Card(child:ListTile(title:const Text('حذف گفتگو'),leading:const Icon(Icons.delete_outline_rounded),onTap:()=>showMsg(context,'حذف گفتگو'))),
  ]));
}

class ContactsToolsPage extends StatelessWidget {
  const ContactsToolsPage({super.key});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('مخاطبین')),body:ListView(padding:const EdgeInsets.all(14),children:[
    Card(child:ListTile(leading:const Icon(Icons.qr_code_scanner_rounded),title:const Text('اسکن QR Code'),onTap:()=>showMsg(context,'اسکن QR'))),
    Card(child:ListTile(leading:const Icon(Icons.qr_code_rounded),title:const Text('QR کد پروفایل من'),onTap:()=>showMsg(context,'QR پروفایل'))),
    Card(child:ListTile(leading:const Icon(Icons.share_rounded),title:const Text('دعوت دوستان'),subtitle:const Text('لینک اختصاصی دعوت'),onTap:()=>showMsg(context,'لینک دعوت آماده است'))),
  ]));
}

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('کیف پول')),body:ListView(padding:const EdgeInsets.all(14),children:[
    const Card(child:ListTile(title:Text('موجودی'),subtitle:Text('۰'),leading:Icon(Icons.account_balance_wallet_rounded))),
    const Card(child:ListTile(title:Text('تاریخچه تراکنش‌ها'),leading:Icon(Icons.receipt_long_rounded))),
    Card(child:ListTile(title:const Text('انتقال وجه'),subtitle:const Text('انتقال به مخاطبین'),leading:const Icon(Icons.send_to_mobile_rounded),onTap:()=>showMsg(context,'انتقال وجه'))),
  ]));
}

class DataSettingsPage extends StatefulWidget {const DataSettingsPage({super.key});@override State<DataSettingsPage> createState()=>_DataSettingsPageState();}
class _DataSettingsPageState extends State<DataSettingsPage>{bool low=false,wifi=true;@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('مصرف داده')),body:ListView(padding:const EdgeInsets.all(14),children:[
 Card(child:SwitchListTile(value:low,onChanged:(v)=>setState(()=>low=v),title:const Text('حالت کم‌مصرف'))),
 Card(child:SwitchListTile(value:wifi,onChanged:(v)=>setState(()=>wifi=v),title:const Text('دانلود خودکار فقط با وای‌فای'))),
]));}

class AccessibilityPage extends StatefulWidget {const AccessibilityPage({super.key});@override State<AccessibilityPage> createState()=>_AccessibilityPageState();}
class _AccessibilityPageState extends State<AccessibilityPage>{double size=1;bool contrast=false;@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('دسترسی‌پذیری')),body:ListView(padding:const EdgeInsets.all(14),children:[
 Card(child:ListTile(title:const Text('اندازه متن'),subtitle:Slider(value:size,min:.8,max:1.5,divisions:7,onChanged:(v)=>setState(()=>size=v)))),
 Card(child:SwitchListTile(value:contrast,onChanged:(v)=>setState(()=>contrast=v),title:const Text('کنتراست بالا'))),
]));}

class PermissionScreensPage extends StatelessWidget {const PermissionScreensPage({super.key});@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('دسترسی‌های برنامه')),body:ListView(padding:const EdgeInsets.all(14),children:[
 const Card(child:ListTile(leading:Icon(Icons.contacts_rounded),title:Text('مخاطبین'),subtitle:Text('برای پیدا کردن دوستان لازم است.'))),
 const Card(child:ListTile(leading:Icon(Icons.notifications_rounded),title:Text('اعلان‌ها'),subtitle:Text('برای پیام‌ها و تماس‌های جدید لازم است.'))),
 const Card(child:ListTile(leading:Icon(Icons.camera_alt_rounded),title:Text('دوربین و میکروفون'),subtitle:Text('برای تماس، عکس و پیام صوتی لازم است.'))),
]));}

class AdvancedMessagingPage extends StatelessWidget {const AdvancedMessagingPage({super.key});@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('پیام‌رسانی پیشرفته')),body:ListView(padding:const EdgeInsets.all(14),children:[
 const Card(child:ListTile(leading:Icon(Icons.graphic_eq_rounded),title:Text('Waveform پیام صوتی'))),
 const Card(child:ListTile(leading:Icon(Icons.video_camera_front_rounded),title:Text('ویدیو-پیام دایره‌ای'))),
 const Card(child:ListTile(leading:Icon(Icons.translate_rounded),title:Text('ترجمه با یک ضربه'))),
 const Card(child:ListTile(leading:Icon(Icons.location_on_rounded),title:Text('موقعیت مکانی زنده'))),
]));}
