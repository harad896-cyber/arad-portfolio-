import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'fun_game_engine.dart';
import 'chess_game.dart';
import 'fun_zone_theme.dart';
import 'fun_game_leaderboard.dart';
import 'gap_coin_wallet.dart';
import 'ludo_game.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// GapResan entertainment hub. Board games use secured Supabase rooms for
/// online matches; quizzes and other activities remain local-first.
class FunZonePage extends StatelessWidget {
  const FunZonePage({super.key});

  static const _items = <_FunItem>[
    _FunItem('لودو', '۲ تا ۴ نفره و بازی با ربات', Icons.casino_rounded, _FunKind.ludo, Color(0xFFF0B83B)),
    _FunItem('مسابقه و معما', 'سؤال‌های کوتاه و امتیاز', Icons.quiz_rounded, _FunKind.quiz, Color(0xFF4776E6)),
    _FunItem('گردونه شانس', 'امتیاز روزانه و جایزه', Icons.casino_rounded, _FunKind.wheel, Color(0xFFE6A23C)),
    _FunItem('جدول امتیازها', 'رتبه و آمار بازیکنان', Icons.leaderboard_rounded, _FunKind.leaderboard, Color(0xFFD0A33D)),
    _FunItem('کیف پول سکه', 'موجودی، انتقال و تاریخچه', Icons.account_balance_wallet_rounded, _FunKind.wallet, Color(0xFFD6A83D)),
    _FunItem('شطرنج', 'قوانین کامل، ربات و دونفره آفلاین', Icons.grid_4x4_rounded, _FunKind.chess, Color(0xFF795548)),
    _FunItem('بازی حافظه', 'جفت شکل‌های پنهان را پیدا کن', Icons.grid_view_rounded, _FunKind.memory, Color(0xFF9B6B43)),
    _FunItem('آزمون شخصیت و فال', 'فقط برای سرگرمی', Icons.auto_awesome_rounded, _FunKind.personality, Color(0xFF9B68C8)),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('سرگرمی‌های گپ‌رسان'), centerTitle: false, backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent),
      floatingActionButton: const FunZoneThemeButton(),
      body: FunZoneBackdrop(child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF087F68), Color(0xFF20B58E), Color(0xFF66CDAA)],
                    begin: Alignment.topRight, end: Alignment.bottomLeft,
                  ),
                ),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.sports_esports_rounded, color: Colors.white, size: 30),
                  SizedBox(height: 12),
                  Text('وقت خوش در گپ‌رسان!', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                  SizedBox(height: 5),
                  Text('بازی کن، فکر کن و لحظه‌های سرگرم‌کننده بساز.', style: TextStyle(color: Colors.white, height: 1.5)),
                ]),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = _items[index];
                return _FunCard(item: item, onTap: () => _open(context, item.kind));
              }, childCount: _items.length),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.18,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
              child: Text('بازی‌های موجود را انتخاب کن و از رقابت و سرگرمی لذت ببر.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, height: 1.6)),
            ),
          ),
        ],
      )),
    );
  }

  void _open(BuildContext context, _FunKind kind) {
    final Widget page = switch (kind) {
      _FunKind.ludo => const LudoGamePage(),
      _FunKind.quiz => const _QuizPage(),
      _FunKind.wheel => const _WheelPage(),
      _FunKind.leaderboard => const FunGameLeaderboardPage(),
      _FunKind.wallet => const GapCoinWalletPage(),
      _FunKind.chess => const ChessGamePage(),
      _FunKind.memory => const _MemoryGamePage(),
      _FunKind.personality => const _PersonalityPage(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

enum _FunKind { ludo, quiz, wheel, leaderboard, wallet, chess, memory, personality }

class _FunItem {
  final String title, subtitle;
  final IconData icon;
  final _FunKind kind;
  final Color color;
  const _FunItem(this.title, this.subtitle, this.icon, this.kind, this.color);
}

class _FunCard extends StatelessWidget {
  final _FunItem item;
  final VoidCallback onTap;
  const _FunCard({required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [item.color.withValues(alpha: .28), scheme.surfaceContainerLow, scheme.surfaceContainerLow]),
        border: Border.all(color: item.color.withValues(alpha: .42), width: 1.1),
        boxShadow: [BoxShadow(color: item.color.withValues(alpha: .10), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(23),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(23),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [item.color.withValues(alpha: .95), item.color.withValues(alpha: .55)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: item.color.withValues(alpha: .28), blurRadius: 10, offset: const Offset(0, 4))],
                    border: Border.all(color: Colors.white.withValues(alpha: .45)),
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 26)),
                const Spacer(),
                Icon(Icons.arrow_outward_rounded, size: 17, color: item.color.withValues(alpha: .9)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 5),
                Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, height: 1.35, color: scheme.onSurfaceVariant)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GameScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const _GameScaffold({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: Text(title), backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent),
    floatingActionButton: const FunZoneThemeButton(),
    body: SafeArea(child: FunZoneBackdrop(child: child)),
  );
}

class _TicTacToePage extends StatefulWidget {
  const _TicTacToePage();
  @override
  State<_TicTacToePage> createState() => _TicTacToePageState();
}
class _TicTacToePageState extends State<_TicTacToePage> {
  List<String> cells = List.filled(9, '');
  String turn = 'X';
  String? result;
  int scoreX = 0, scoreO = 0;
  static const wins = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
  void play(int i) {
    if (cells[i].isNotEmpty || result != null) return;
    setState(() {
      cells[i] = turn;
      if (wins.any((w) => w.every((x) => cells[x] == turn))) {
        result = 'بازیکن $turn برنده شد!';
        if (turn == 'X') { scoreX++; } else { scoreO++; }
      } else if (cells.every((x) => x.isNotEmpty)) { result = 'بازی مساوی شد.'; }
      else { turn = turn == 'X' ? 'O' : 'X'; }
    });
  }
  void reset() => setState(() { cells = List.filled(9, ''); turn = 'X'; result = null; });
  @override
  Widget build(BuildContext context) => _GameScaffold(title: 'بازی دونفره · دوز', child: Padding(
    padding: const EdgeInsets.all(20), child: Column(children: [
      Text('X: $scoreX     •     O: $scoreO', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      const SizedBox(height: 10),
      Text(result ?? 'نوبت بازیکن $turn', style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 20),
      AspectRatio(aspectRatio: 1, child: GridView.builder(physics: const NeverScrollableScrollPhysics(), itemCount: 9,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemBuilder: (_, i) => InkWell(onTap: () => play(i), borderRadius: BorderRadius.circular(16),
          child: Container(decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text(cells[i], style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900,
              color: cells[i] == 'X' ? Colors.teal : Colors.deepOrange))))))),
      const SizedBox(height: 18), FilledButton.icon(onPressed: reset, icon: const Icon(Icons.refresh), label: const Text('بازی دوباره')),
      const SizedBox(height: 8), const Text('دو نفر روی یک دستگاه نوبتی بازی می‌کنند.', style: TextStyle(fontSize: 12)),
    ]),
  ));
}

typedef _QuizQuestion = (String, List<String>, int, String, String, int);

class _QuizPage extends StatefulWidget {
  const _QuizPage();
  @override State<_QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<_QuizPage> {
  static const questionBank = <_QuizQuestion>[
    ('بزرگ‌ترین سیارهٔ منظومهٔ شمسی کدام است؟',['زمین','مشتری','زهره','مریخ'],1,'علوم','مشتری از همهٔ سیاره‌های منظومهٔ شمسی بزرگ‌تر است.',1),
    ('آب خالص در فشار معمول نزدیک چند درجه می‌جوشد؟',['۵۰','۸۰','۱۰۰','۱۲۰'],2,'علوم','نقطهٔ جوش آب در فشار یک اتمسفر تقریباً ۱۰۰ درجهٔ سانتی‌گراد است.',1),
    ('کدام گاز بیشترین سهم هوای خشک زمین را دارد؟',['اکسیژن','نیتروژن','کربن‌دی‌اکسید','هیدروژن'],1,'علوم','نیتروژن نزدیک ۷۸ درصد هوای خشک زمین را تشکیل می‌دهد.',2),
    ('فرمول کیمیاوی آب چیست؟',['CO₂','O₂','H₂O','NaCl'],2,'علوم','هر مولکول آب دو اتم هیدروژن و یک اتم اکسیژن دارد.',1),
    ('کدام سیاره به حلقه‌های بزرگش مشهور است؟',['مریخ','زحل','عطارد','زهره'],1,'علوم','حلقه‌های زحل از ذرات یخ و سنگ ساخته شده‌اند.',1),
    ('نور خورشید تقریباً چند دقیقه تا زمین می‌رسد؟',['۲ دقیقه','۸ دقیقه','۳۰ دقیقه','۶۰ دقیقه'],1,'علوم','نور خورشید تقریباً ۸ دقیقه و ۲۰ ثانیه در راه است.',2),
    ('واحد اندازه‌گیری نیرو چیست؟',['ژول','وات','نیوتن','پاسکال'],2,'علوم','نیرو در دستگاه بین‌المللی با نیوتن اندازه‌گیری می‌شود.',2),
    ('کدام ذره بار الکتریکی منفی دارد؟',['پروتون','نوترون','الکترون','فوتون'],2,'علوم','الکترون بار منفی دارد؛ پروتون مثبت و نوترون خنثی است.',2),
    ('کدام عضو بدن خون را پمپ می‌کند؟',['ریه','قلب','کلیه','معده'],1,'علوم','قلب با انقباض منظم خون را در بدن به گردش درمی‌آورد.',1),
    ('در دمای اتاق کدام فلز مایع است؟',['آهن','مس','جیوه','آلومینیوم'],2,'علوم','جیوه در دمای اتاق مایع است.',2),
    ('کدام ویتامین با نور آفتاب در پوست ساخته می‌شود؟',['ویتامین A','ویتامین C','ویتامین D','ویتامین K'],2,'علوم','پوست با کمک نور فرابنفش B می‌تواند ویتامین D بسازد.',2),
    ('سرعت صوت در هوا در دمای معمول تقریباً چقدر است؟',['۳۴ متر بر ثانیه','۳۴۳ متر بر ثانیه','۳۰۰۰ متر بر ثانیه','۳۰ هزار متر بر ثانیه'],1,'علوم','سرعت صوت در هوای ۲۰ درجه تقریباً ۳۴۳ متر بر ثانیه است.',3),
    ('کدام جانور پستاندار است؟',['کوسه','دلفین','اختاپوس','قزل‌آلا'],1,'طبیعت','دلفین پستاندار است و برای نفس‌کشیدن به سطح آب می‌آید.',1),
    ('گیاهان در فتوسنتز بیشتر کدام گاز را جذب می‌کنند؟',['اکسیژن','نیتروژن','کربن‌دی‌اکسید','هلیم'],2,'طبیعت','گیاهان از کربن‌دی‌اکسید و آب برای ساخت مواد غذایی استفاده می‌کنند.',1),
    ('کدام جانور سریع‌ترین دوندهٔ خشکی است؟',['شیر','یوزپلنگ','اسب','گرگ'],1,'طبیعت','یوزپلنگ در مسافت کوتاه به سرعت بسیار بالا می‌رسد.',1),
    ('بزرگ‌ترین جانور شناخته‌شدهٔ زمین چیست؟',['فیل افریقایی','کوسه سفید','نهنگ آبی','زرافه'],2,'طبیعت','نهنگ آبی از نظر اندازه بزرگ‌ترین جانور شناخته‌شده است.',1),
    ('کدام بخش گیاه معمولاً آب و مواد معدنی را جذب می‌کند؟',['گل','ریشه','میوه','برگ'],1,'طبیعت','ریشه آب و مواد معدنی را از خاک جذب می‌کند.',1),
    ('کدام جانور دگردیسی کامل دارد؟',['پروانه','گربه','مار','کبوتر'],0,'طبیعت','پروانه از تخم به لارو، شفیره و سپس حشرهٔ بالغ تبدیل می‌شود.',2),
    ('کدام اقیانوس بزرگ‌ترین است؟',['هند','اطلس','آرام','منجمد شمالی'],2,'جغرافیا','اقیانوس آرام بزرگ‌ترین و عمیق‌ترین اقیانوس زمین است.',1),
    ('بلندترین رشته‌کوه جهان کدام است؟',['آلپ','هیمالیا','آند','قراقروم'],1,'جغرافیا','هیمالیا بلندترین رشته‌کوه روی خشکی است و اورست در آن قرار دارد.',1),
    ('پایتخت جاپان کدام شهر است؟',['سئول','توکیو','پکن','بانکوک'],1,'جغرافیا','توکیو پایتخت جاپان است.',1),
    ('کدام قاره از نظر مساحت بزرگ‌ترین است؟',['افریقا','اروپا','آسیا','استرالیا'],2,'جغرافیا','آسیا بزرگ‌ترین قاره از نظر مساحت و جمعیت است.',1),
    ('رود نیل به کدام دریا می‌ریزد؟',['دریای سرخ','دریای مدیترانه','دریای سیاه','خلیج فارس'],1,'جغرافیا','رود نیل پس از گذر از شمال افریقا به دریای مدیترانه می‌ریزد.',2),
    ('کدام کشور به شکل چکمه در نقشه مشهور است؟',['یونان','ایتالیا','پرتگال','ناروی'],1,'جغرافیا','شکل شبه‌جزیرهٔ ایتالیا شبیه چکمه است.',1),
    ('صحرای بزرگ افریقا در کدام قاره قرار دارد؟',['آسیا','افریقا','امریکای جنوبی','استرالیا'],1,'جغرافیا','صحرای بزرگ در شمال قارهٔ افریقا گسترده شده است.',1),
    ('کدام شهر در دو قارهٔ آسیا و اروپا قرار دارد؟',['پاریس','استانبول','قاهره','دهلی'],1,'جغرافیا','استانبول در دو سوی تنگهٔ بسفر و در دو قاره قرار گرفته است.',3),
    ('یک ساعت چند دقیقه است؟',['۳۰','۴۵','۶۰','۹۰'],2,'ریاضی','هر ساعت ۶۰ دقیقه دارد.',1),
    ('حاصل ۹ ضربدر ۷ چند است؟',['۵۶','۶۳','۷۲','۶۷'],1,'ریاضی','۹ ضربدر ۷ برابر با ۶۳ است.',1),
    ('حاصل ۱۲ ضربدر ۸ چند است؟',['۸۶','۹۶','۱۰۸','۱۱۲'],1,'ریاضی','۱۲ ضربدر ۸ برابر با ۹۶ است.',1),
    ('عدد اول بعد از ۷ کدام است؟',['۸','۹','۱۰','۱۱'],3,'ریاضی','۱۱ فقط بر ۱ و خودش بخش‌پذیر است.',2),
    ('مجموع زاویه‌های داخلی مثلث چند درجه است؟',['۹۰','۱۸۰','۲۷۰','۳۶۰'],1,'ریاضی','مجموع زاویه‌های داخلی هر مثلث در هندسهٔ اقلیدسی ۱۸۰ درجه است.',2),
    ('جذر ۱۴۴ چند است؟',['۱۰','۱۱','۱۲','۱۴'],2,'ریاضی','۱۲ ضربدر ۱۲ برابر ۱۴۴ است.',2),
    ('اگر نصف ۵۰ را بگیریم و ۵ اضافه کنیم، چند می‌شود؟',['۲۰','۲۵','۳۰','۳۵'],2,'ریاضی','نصف ۵۰ برابر ۲۵ است و با افزودن ۵، جواب ۳۰ می‌شود.',1),
    ('عدد پی تقریباً برابر با کدام مقدار است؟',['۲٫۱۴','۳٫۱۴','۴٫۱۳','۱٫۳۴'],1,'ریاضی','پی نسبت محیط دایره به قطر آن است و تقریباً ۳٫۱۴۱۵۹ می‌شود.',2),
    ('کدام دانشمند قانون جاذبهٔ عمومی را صورت‌بندی کرد؟',['نیوتن','ادیسون','داروین','گالیله'],0,'تاریخ','اسحاق نیوتن قانون گرانش عمومی را در اثر مشهور خود توضیح داد.',2),
    ('اهرام مشهور جیزه در کدام کشور هستند؟',['یونان','مصر','مکزیک','هند'],1,'تاریخ','اهرام جیزه در مصر و نزدیک شهر قاهره قرار دارند.',1),
    ('خط میخی از کدام تمدن‌های باستانی شناخته شده است؟',['بین‌النهرین','روم','مایا','وایکینگ'],0,'تاریخ','خط میخی در بین‌النهرین و نزد تمدن‌هایی چون سومریان گسترش یافت.',3),
    ('نخستین سفر انسان به ماه در کدام سال انجام شد؟',['۱۹۵۹','۱۹۶۹','۱۹۷۹','۱۹۸۹'],1,'تاریخ','ماموریت آپولو ۱۱ در سال ۱۹۶۹ انسان را به ماه رساند.',2),
    ('جادهٔ ابریشم بیشتر برای چه شناخته می‌شود؟',['راه‌های بازرگانی','مسابقه‌های ورزشی','راه‌آهن مدرن','کانال‌های آبی'],0,'تاریخ','جادهٔ ابریشم شبکه‌ای از راه‌های بازرگانی میان شرق و غرب بود.',2),
    ('کدام تمدن با شهر باستانی بابل پیوند دارد؟',['بین‌النهرین','اسکاندیناوی','مایا','ژاپن باستان'],0,'تاریخ','بابل یکی از شهرهای مهم تمدن بین‌النهرین بود.',2),
    ('مغز اصلی محاسبات کمپیوتر معمولاً چه نام دارد؟',['CPU','GPS','USB','HDMI'],0,'فناوری','CPU دستورها را اجرا و عملیات اصلی محاسباتی را انجام می‌دهد.',1),
    ('کدام مورد برای ذخیرهٔ فایل‌ها در اینترنت به کار می‌رود؟',['فضای ابری','بلندگو','میکروفون','چاپگر'],0,'فناوری','فضای ابری فایل‌ها را روی سرورهای اینترنتی نگهداری می‌کند.',1),
    ('رمز عبور قوی بهتر است چگونه باشد؟',['فقط نام خود','تکرار ۱۲۳۴','ترکیب طولانی و یکتا','تاریخ تولد'],2,'فناوری','رمز طولانی و یکتا که در سرویس‌های دیگر تکرار نشود امن‌تر است.',1),
    ('کدام فناوری برای ارتباط بی‌سیم نزدیک استفاده می‌شود؟',['Bluetooth','HDMI','Ethernet','VGA'],0,'فناوری','بلوتوث برای ارتباط بی‌سیم در فاصلهٔ کوتاه طراحی شده است.',1),
    ('فیشینگ معمولاً چه هدفی دارد؟',['سرقت اطلاعات','افزایش سرعت اینترنت','پاک‌کردن گردوغبار','شارژ باتری'],0,'فناوری','فیشینگ کاربر را فریب می‌دهد تا رمز یا اطلاعات حساسش را افشا کند.',2),
    ('کدام فرمت معمولاً برای عکس فشرده استفاده می‌شود؟',['JPEG','MP3','WAV','TXT'],0,'فناوری','JPEG یک فرمت رایج برای فشرده‌سازی تصویر است.',2),
    ('کدام زبان برای ساختار صفحهٔ وب استفاده می‌شود؟',['HTML','SQL','Bash','Dart'],0,'فناوری','HTML ساختار و محتوای صفحهٔ وب را مشخص می‌کند.',2),
    ('زبان رسمی سازمان ملل چند زبان است؟',['۴','۵','۶','۸'],2,'دانش عمومی','سازمان ملل شش زبان رسمی دارد.',2),
    ('یک سال عادی چند روز دارد؟',['۳۶۰','۳۶۵','۳۶۶','۳۵۴'],1,'دانش عمومی','سال عادی ۳۶۵ روز دارد و سال کبیسه ۳۶۶ روز.',1),
    ('کدام ساز موسیقی کلیدهای سیاه و سفید دارد؟',['تار','پیانو','دف','نی'],1,'دانش عمومی','پیانو با صفحه‌کلید سیاه و سفید نواخته می‌شود.',1),
    ('در شطرنج کدام مهره می‌تواند به شکل L حرکت کند؟',['رخ','فیل','اسب','وزیر'],2,'دانش عمومی','اسب در شطرنج به شکل دو خانه و سپس یک خانه عمود بر آن حرکت می‌کند.',2),
    ('کدام ورزش با راکت و توپ زرد انجام می‌شود؟',['تنیس','بوکس','شنا','کشتی'],0,'دانش عمومی','در تنیس از راکت و توپ مخصوص استفاده می‌شود.',1),
  ];

  static const categories = ['همه','علوم','طبیعت','ریاضی','جغرافیا','تاریخ','فناوری','دانش عمومی'];
  String category = 'همه';
  int difficulty = 0;
  late List<_QuizQuestion> questions;
  int index = 0, score = 0;
  int? selectedOption;
  bool? answered;

  @override void initState(){super.initState();_newRound();}
  void _newRound(){
    final pool=questionBank.where((q)=>(category=='همه'||q.$4==category)&&(difficulty==0||q.$6==difficulty)).toList()..shuffle(math.Random());
    questions=pool.take(math.min(12,pool.length)).toList();
    index=0;score=0;selectedOption=null;answered=null;
  }
  void choose(int i){
    if(answered!=null)return;
    setState(() { selectedOption = i; answered = i == questions[index].$3; });
    if(i==questions[index].$3)score++;
  }
  void next(){setState(() { index++; selectedOption = null; answered = null; });}

  @override Widget build(BuildContext context){
    final scheme=Theme.of(context).colorScheme;
    return _GameScaffold(title:'مسابقهٔ هوشمند',child:Padding(padding:const EdgeInsets.all(16),child:questions.isEmpty
      ?const Center(child:Text('برای این دسته پرسشی پیدا نشد.'))
      :index>=questions.length
        ?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
          const Icon(Icons.emoji_events_rounded,size:66,color:Colors.amber),
          const Text('مسابقه تمام شد!',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900)),
          Text('امتیاز تو: $score از ${questions.length}',style:const TextStyle(fontSize:18)),
          const SizedBox(height:12),
          FilledButton(onPressed:()=>setState(_newRound),child:const Text('مسابقهٔ تازه')),
          TextButton(onPressed: () { setState(() { category = 'همه'; difficulty = 0; _newRound(); }); }, child: const Text('تغییر دسته و سطح')),
        ]))
        :Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: categories.map((c) { return Padding(padding: const EdgeInsets.only(left: 6), child: ChoiceChip(label: Text(c), selected: category == c, onSelected: (_) { setState(() { category = c; _newRound(); }); })); }).toList())),
          const SizedBox(height:8),
          Wrap(spacing:6,children:[
            ChoiceChip(label:const Text('همهٔ سطح‌ها'),selected:difficulty==0,onSelected: (_) { setState(() { difficulty = 0; _newRound(); }); }),
            ChoiceChip(label:const Text('آسان'),selected:difficulty==1,onSelected: (_) { setState(() { difficulty = 1; _newRound(); }); }),
            ChoiceChip(label:const Text('متوسط'),selected:difficulty==2,onSelected: (_) { setState(() { difficulty = 2; _newRound(); }); }),
            ChoiceChip(label:const Text('سخت'),selected:difficulty==3,onSelected: (_) { setState(() { difficulty = 3; _newRound(); }); }),
          ]),
          const SizedBox(height:12),
          Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
            Text('پرسش ${index+1} از ${questions.length}',style:const TextStyle(fontWeight:FontWeight.w800)),
            Text('امتیاز: $score',style:TextStyle(color:scheme.primary,fontWeight:FontWeight.w900)),
          ]),
          const SizedBox(height:8),LinearProgressIndicator(value:(index+1)/questions.length),
          const SizedBox(height:22),
          Text(questions[index].$4,style:TextStyle(color:scheme.primary,fontWeight:FontWeight.w800)),
          const SizedBox(height:8),
          Text(questions[index].$1,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
          const SizedBox(height:14),
          ...List.generate(questions[index].$2.length,(i){
            final correct=i==questions[index].$3,selected=i==selectedOption;
            final color=answered==null?scheme.outline:correct?Colors.green:selected?Colors.red:scheme.outline;
            return Padding(padding:const EdgeInsets.only(bottom:8),child:OutlinedButton(
              onPressed:answered==null?()=>choose(i):null,
              style:OutlinedButton.styleFrom(backgroundColor:answered==null?null:correct?Colors.green.withValues(alpha:.10):selected?Colors.red.withValues(alpha:.10):null,side:BorderSide(color:color)),
              child:Row(children:[Expanded(child:Text(questions[index].$2[i])),if(answered!=null&&correct)const Icon(Icons.check_circle,color:Colors.green),if(answered!=null&&selected&&!correct)const Icon(Icons.cancel,color:Colors.red)]),
            ));
          }),
          if(answered!=null)...[
            const SizedBox(height:6),
            Text(answered!?'آفرین! پاسخ درست بود.':'پاسخ درست: '+questions[index].$2[questions[index].$3],style:TextStyle(fontWeight:FontWeight.w900,color:answered!?Colors.green:Colors.red)),
            const SizedBox(height:6),
            Text(questions[index].$5,style:TextStyle(color:scheme.onSurfaceVariant,height:1.4)),
            const Spacer(),
            FilledButton(onPressed:next,child:Text(index==questions.length-1?'دیدن نتیجه':'پرسش بعدی')),
          ],
        ]),
    ));
  }
}

class _WheelPage extends StatefulWidget { const _WheelPage(); @override State<_WheelPage> createState() => _WheelPageState(); }
class _WheelPageState extends State<_WheelPage> {
 static const prizes=['۵ امتیاز','۱۰ امتیاز','۱۵ امتیاز','۲۵ امتیاز','۵۰ امتیاز'];
 static const keys=['small','bright','gold','grand','jackpot'];
 static const colors=[Color(0xFF1D8E71),Color(0xFF2879B8),Color(0xFF8D5BC6),Color(0xFFE49A32),Color(0xFFD8B34B)];
 String? result,error;bool spinning=false,alreadySpun=false;double turns=0;int? awarded,totalPoints;
 Future<void> spin() async {
  if(spinning||alreadySpun)return;
  final user=Supabase.instance.client.auth.currentUser;
  if(user==null){setState(()=>error='برای دریافت امتیاز، نخست وارد حساب گپ‌رسان شو.');return;}
  setState(() { spinning=true; error=null; result=null; });
  try {
   final raw=await Supabase.instance.client.rpc('spin_fun_wheel').timeout(const Duration(seconds:12));
   final row=(raw as List).first as Map;
   final reward=(row['reward_key']??'').toString();
   final index=keys.indexOf(reward);
   if(index<0)throw StateError('پاداش نامعتبر دریافت شد.');
   final fraction=(1-(index+.5)/prizes.length)%1;
   var next=turns.floor()+5+fraction;
   if(next<=turns)next+=1;
   if(!mounted)return;
   setState(()=>turns=next);
   await Future<void>.delayed(const Duration(milliseconds:3400));
   if(!mounted)return;
   setState((){
    awarded=(row['points_awarded'] as num).toInt();
    totalPoints=(row['total_points'] as num).toInt();
    result='+'+awarded.toString()+' امتیاز';
    alreadySpun=true;spinning=false;
   });
  } catch(e) {
   if(!mounted)return;
   final message=e.toString().toLowerCase();
   setState((){
    spinning=false;
    if(message.contains('wheel_already_spun_today')){
      alreadySpun=true;error='امروز یک‌بار از گردونه استفاده کرده‌ای.';
    } else if(message.contains('authentication_required')){
      error='برای دریافت امتیاز وارد حساب گپ‌رسان شو.';
    } else {
      error='گردونه فعلاً وصل نشد. اتصال را بررسی کن و دوباره تلاش کن.';
    }
   });
  }
 }
 @override Widget build(BuildContext context)=>_GameScaffold(title:'گردونه شانس',child:ListView(
  padding:const EdgeInsets.fromLTRB(18,18,18,30),
  children:[
   const Text('هر روز یک چرخش؛ امتیاز مستقیم به حساب تو اضافه می‌شود.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white70,fontSize:13)),
   const SizedBox(height:18),
   Center(child:Stack(alignment:Alignment.topCenter,children:[
    Padding(padding:const EdgeInsets.only(top:20),child:AnimatedRotation(
     turns:turns,duration:const Duration(milliseconds:3400),curve:Curves.easeOutCubic,
     child:SizedBox(width: math.min(310.0,MediaQuery.sizeOf(context).width-54).toDouble(),height:math.min(310.0,MediaQuery.sizeOf(context).width-54).toDouble(),
      child:CustomPaint(painter:_PrizeWheelPainter(prizes:prizes,colors:colors))))),
    Container(width:48,height:52,decoration:const BoxDecoration(shape:BoxShape.circle,gradient:LinearGradient(colors:[Color(0xFFFFF1B8),Color(0xFFB78327)]),boxShadow:[BoxShadow(color:Colors.black45,blurRadius:12,offset:Offset(0,4))]),
      child:const Icon(Icons.keyboard_arrow_down_rounded,size:42,color:Color(0xFF4A2B08))),
   ])),
   const SizedBox(height:22),
   if(result!=null)Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),gradient:const LinearGradient(colors:[Color(0xFFB98A2E),Color(0xFFF6D77B),Color(0xFF9B6A20)]),boxShadow:const [BoxShadow(color:Colors.black26,blurRadius:16,offset:Offset(0,6))]),child:Column(children:[
    Text('تبریک! $result',style:const TextStyle(color:Color(0xFF38240B),fontSize:23,fontWeight:FontWeight.w900)),
    if(totalPoints!=null)Text('مجموع امتیاز حساب: $totalPoints',style:const TextStyle(color:Color(0xFF38240B),fontWeight:FontWeight.w800)),
   ])),
   if(error!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(error!,textAlign:TextAlign.center,style:const TextStyle(color:Color(0xFFFFD0C9),fontWeight:FontWeight.w700))),
   const SizedBox(height:18),
   Center(child:FilledButton.icon(
    onPressed:spinning||alreadySpun?null:spin,
    icon:spinning?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.casino_rounded),
    label:Text(spinning?'گردونه در حال چرخش…':alreadySpun?'چرخش امروز انجام شد':'چرخاندن گردونه'),
    style:FilledButton.styleFrom(backgroundColor:const Color(0xFFF1C96A),foregroundColor:const Color(0xFF38240B),padding:const EdgeInsets.symmetric(horizontal:24,vertical:15)),
   )),
   const SizedBox(height:12),
   const Text('نتیجه روی سرور تعیین می‌شود و امتیاز پس از ثبت، به حساب کاربری افزوده می‌شود.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white60,fontSize:11,height:1.5)),
  ],
 ));
}
class _PrizeWheelPainter extends CustomPainter {
 final List<String> prizes;final List<Color> colors;
 const _PrizeWheelPainter({required this.prizes,required this.colors});
 @override void paint(Canvas canvas,Size size){
  final center=Offset(size.width/2,size.height/2),radius=math.min(size.width,size.height)/2,sweep=2*math.pi/prizes.length;
  final outer=Paint()..shader=const LinearGradient(colors:[Color(0xFFFFF2C1),Color(0xFF9B6A20),Color(0xFFFFE7A0)]).createShader(Offset.zero&size);
  canvas.drawCircle(center,radius,outer);
  final innerRadius=radius-7;
  for(var i=0;i<prizes.length;i++){
   final start=-math.pi/2+i*sweep;
   final rect=Rect.fromCircle(center:center,radius:innerRadius);
   final fill=Paint()..shader=RadialGradient(colors:[Color.lerp(colors[i],Colors.white,.22)!,colors[i],Color.lerp(colors[i],Colors.black,.24)!]).createShader(rect);
   canvas.drawArc(rect,start,sweep,true,fill);
   canvas.drawArc(rect,start,sweep,true,Paint()..color=const Color(0x99FFF0C5)..style=PaintingStyle.stroke..strokeWidth=1.5);
   final angle=start+sweep/2,p=center+Offset(math.cos(angle),math.sin(angle))*radius*.64;
   final label=TextPainter(text:TextSpan(text:prizes[i],style:const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w900,shadows:[Shadow(color:Colors.black87,blurRadius:5,offset:Offset(1,2))])),textDirection:TextDirection.rtl,textAlign:TextAlign.center)..layout(maxWidth:radius*.65);
   canvas.save();canvas.translate(p.dx,p.dy);canvas.rotate(angle+math.pi/2);label.paint(canvas,Offset(-label.width/2,-label.height/2));canvas.restore();
   final pin=center+Offset(math.cos(start),math.sin(start))*(radius-13);
   canvas.drawCircle(pin,3.2,Paint()..color=const Color(0xFFFFF0B9));
  }
  canvas.drawCircle(center,radius*.19,Paint()..shader=const RadialGradient(colors:[Color(0xFFFFF6D4),Color(0xFFD8A93E),Color(0xFF6F4616)]).createShader(Rect.fromCircle(center:center,radius:radius*.19)));
  canvas.drawCircle(center,radius*.105,Paint()..shader=const RadialGradient(colors:[Color(0xFF285D4E),Color(0xFF092A24)]).createShader(Rect.fromCircle(center:center,radius:radius*.105)));
  canvas.drawCircle(center,radius*.19,Paint()..color=Colors.white.withValues(alpha:.35)..style=PaintingStyle.stroke..strokeWidth=1.5);
 }
 @override bool shouldRepaint(covariant _PrizeWheelPainter old)=>old.prizes!=prizes||old.colors!=colors;
}

class _StickerMemePage extends StatefulWidget { const _StickerMemePage(); @override State<_StickerMemePage> createState() => _StickerMemePageState(); }
class _StickerMemePageState extends State<_StickerMemePage> {
  final controller = TextEditingController(text: 'امروز عالیه!');
  final previewKey = GlobalKey();
  bool exporting = false;
  String emoji = '😎';
  Future<void> shareMeme() async {
    if (exporting) return;
    setState(() => exporting = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = previewKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('پیش‌نمایش برای ساخت تصویر آماده نیست.');
      }
      final image = await renderObject.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('ساخت تصویر ناموفق بود.');
      final bytes = data.buffer.asUint8List();
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png', name: 'gapresan-meme.png')],
        text: 'ساخته‌شده با گپ‌رسان',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ساخت یا شریک‌سازی تصویر انجام نشد: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }
  final emojis = const ['😎','😂','😍','🔥','💚','🥳','🤩','😴','🚀','🌟','🙌','❤️'];
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => _GameScaffold(title: 'استیکر و میم‌ساز', child: ListView(padding: const EdgeInsets.all(18), children: [
    RepaintBoundary(key: previewKey, child: Container(height: 240, width: double.infinity, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(24), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(emoji, style: const TextStyle(fontSize: 76)), Padding(padding: const EdgeInsets.all(14), child: Text(controller.text.isEmpty ? 'متن میم تو' : controller.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)))])))),
    const SizedBox(height: 16), TextField(controller: controller, onChanged: (_) => setState(() {}), maxLength: 50, decoration: const InputDecoration(labelText: 'متن استیکر', border: OutlineInputBorder())),
    const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 8, children: emojis.map((e) => ChoiceChip(label: Text(e, style: const TextStyle(fontSize: 24)), selected: emoji == e, onSelected: (_) => setState(() => emoji=e))).toList()),
    const SizedBox(height: 18),
    FilledButton.icon(onPressed: exporting ? null : shareMeme, icon: exporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.image_rounded), label: Text(exporting ? 'در حال ساخت تصویر…' : 'ساخت و شریک‌سازی تصویر PNG')),
    const SizedBox(height: 8),
    OutlinedButton.icon(onPressed: () async { await Clipboard.setData(ClipboardData(text: '$emoji  ${controller.text}')); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('متن استیکر کاپی شد.'))); }, icon: const Icon(Icons.copy), label: const Text('کاپی متن')),
  ]));
}

class _ConnectFourPage extends StatefulWidget {
 const _ConnectFourPage(); @override State<_ConnectFourPage> createState()=>_ConnectFourPageState();
}
class _ConnectFourPageState extends State<_ConnectFourPage> {
  static const rows = 6, cols = 7;
  List<int> board = List.filled(rows * cols, 0);
  int turn = 1, redWins = 0, yellowWins = 0;
  int? winner;
  bool draw = false;

  bool inside(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  bool wins(int r, int c, int player) {
    const directions = [(0, 1), (1, 0), (1, 1), (1, -1)];
    for (final (dr, dc) in directions) {
      var count = 1;
      for (final sign in [-1, 1]) {
        var nr = r + dr * sign;
        var nc = c + dc * sign;
        while (inside(nr, nc) && board[nr * cols + nc] == player) {
          count++;
          nr += dr * sign;
          nc += dc * sign;
        }
      }
      if (count >= 4) return true;
    }
    return false;
  }

  void drop(int col) {
    if (winner != null || draw) return;
    var row = -1;
    for (var r = rows - 1; r >= 0; r--) {
      if (board[r * cols + col] == 0) {
        row = r;
        break;
      }
    }
    if (row < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('این ستون پُر است.')),
      );
      return;
    }
    setState(() {
      board[row * cols + col] = turn;
      if (wins(row, col, turn)) {
        winner = turn;
        if (turn == 1) {
          redWins++;
        } else {
          yellowWins++;
        }
      } else if (board.every((value) => value != 0)) {
        draw = true;
      } else {
        turn = turn == 1 ? 2 : 1;
      }
    });
  }

  void reset() {
    setState(() {
      board = List.filled(rows * cols, 0);
      turn = 1;
      winner = null;
      draw = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = winner != null
        ? (winner == 1 ? 'مهره سرخ برنده شد!' : 'مهره زرد برنده شد!')
        : draw
            ? 'بازی مساوی شد.'
            : 'نوبت بازیکن ' + (turn == 1 ? 'سرخ' : 'زرد');
    return _GameScaffold(
      title: 'چهار در یک خط',
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              'سرخ: ' + redWins.toString() + ' برد  ·  زرد: ' +
                  yellowWins.toString() + ' برد',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(status),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: cols / rows,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2459A6),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rows * cols,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 5,
                        mainAxisSpacing: 5,
                      ),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => drop(i % cols),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: board[i] == 1
                                ? const Color(0xFFE64B4B)
                                : board[i] == 2
                                    ? const Color(0xFFFFD447)
                                    : const Color(0xFFEAF1FA),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Text(
              'هر نفر یک مهره در ستون انتخابی می‌اندازد. چهار مهرهٔ هم‌رنگ را افقی، عمودی یا مورب ردیف کن.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: reset,
              icon: const Icon(Icons.refresh),
              label: const Text('دور تازه'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryGamePage extends StatefulWidget{
 const _MemoryGamePage();@override State<_MemoryGamePage> createState()=>_MemoryGamePageState();
}
class _MemoryGamePageState extends State<_MemoryGamePage>{
 static const symbols=['🍎','🚀','🐼','⚽','🌙','🎧','🍀','🦋'];
 late List<String> cards;final Set<int> revealed={};final Set<int> matched={};int moves=0;bool resolving=false,finished=false;
 @override void initState(){super.initState();newGame();}
 void newGame(){cards=[...symbols,...symbols]..shuffle(math.Random());revealed.clear();matched.clear();moves=0;resolving=false;finished=false;}
 Future<void> flip(int i)async{
  if(resolving||finished||matched.contains(i)||revealed.contains(i))return;
  setState(()=>revealed.add(i));if(revealed.length<2)return;moves++;
  final pair=revealed.toList(growable:false);
  if(cards[pair[0]]==cards[pair[1]]){setState(() { matched.addAll(pair);revealed.clear();finished=matched.length==cards.length; });return;}
  setState(() { resolving=true; });await Future.delayed(const Duration(milliseconds:850));if(!mounted)return;setState(() { revealed.clear();resolving=false; });
 }
 @override Widget build(BuildContext context)=>_GameScaffold(title:'بازی حافظه',child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
  Text('حرکت‌ها: '+moves.toString()+'  ·  جفت‌ها: '+(matched.length~/2).toString()+' از '+symbols.length.toString(),style:const TextStyle(fontWeight:FontWeight.w900)),
  const SizedBox(height:12),
  Expanded(child:Center(child:AspectRatio(aspectRatio:1,child:GridView.builder(physics:const NeverScrollableScrollPhysics(),itemCount:cards.length,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:4,crossAxisSpacing:8,mainAxisSpacing:8),itemBuilder:(_,i){
   final visible=revealed.contains(i)||matched.contains(i);
   return Material(color:matched.contains(i)?Colors.green.withValues(alpha:.18):visible?Theme.of(context).colorScheme.surfaceContainerHighest:const Color(0xFF087F68),borderRadius:BorderRadius.circular(15),child:InkWell(borderRadius:BorderRadius.circular(15),onTap:()=>flip(i),child:Center(child:Text(visible?cards[i]:'؟',style:TextStyle(fontSize:visible?30:28,color:visible?null:Colors.white,fontWeight:FontWeight.w900)))));
  })))),
  if(finished)const Text('آفرین! همه جفت‌ها را پیدا کردی.',style:TextStyle(color:Colors.green,fontWeight:FontWeight.w900)),
  const Text('دو کارت را باز کن؛ اگر شکل‌ها یکسان باشند، جفت می‌شوند. همه جفت‌ها را با حرکت کمتر پیدا کن.',textAlign:TextAlign.center,style:TextStyle(fontSize:12)),
  const SizedBox(height:10),FilledButton.icon(onPressed:()=>setState(newGame),icon:const Icon(Icons.refresh),label:const Text('بازی تازه')),
 ])));
}

class _SnakePage extends StatefulWidget { const _SnakePage(); @override State<_SnakePage> createState() => _SnakePageState(); }
class _SnakePageState extends State<_SnakePage> {
  static const n=16; final random=math.Random(); List<int> snake=[117,118,119]; int food=85, direction=-1, score=0; Timer? timer; bool running=false, over=false;
  void start() { timer?.cancel(); setState(() {snake=[117,118,119];do{food=random.nextInt(n*n);}while(snake.contains(food));direction=-1;score=0;over=false;running=true;}); timer=Timer.periodic(const Duration(milliseconds:180), (_) => step()); }
  void step() {
    if (!running || snake.isEmpty) return;
    final head = snake.first;
    final next = head + direction;
    final willEat = next == food;
    final bodyToCheck = willEat ? snake : snake.take(snake.length - 1);
    final insideBoard = next >= 0 && next < n * n;
    final crossedEdge = (direction == 1 && head % n == n - 1) ||
        (direction == -1 && head % n == 0) ||
        (direction == n && head ~/ n == n - 1) ||
        (direction == -n && head ~/ n == 0);
    final hitSelf = bodyToCheck.contains(next);
    if (!insideBoard || crossedEdge || hitSelf) {
      timer?.cancel();
      setState(() { running = false; over = true; });
      return;
    }
    setState(() {
      snake.insert(0, next);
      if (willEat) {
        score++;
        if (snake.length == n * n) {
          timer?.cancel();
          running = false;
          over = true;
        } else {
          do { food = random.nextInt(n * n); } while (snake.contains(food));
        }
      } else {
        snake.removeLast();
      }
    });
  }
  void turn(int d){if((direction==-d)||d==direction)return;setState(()=>direction=d);}
  @override void dispose(){timer?.cancel();super.dispose();}
  @override Widget build(BuildContext context)=>_GameScaffold(title:'بازی مار',child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
    Text('امتیاز: $score',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
    const SizedBox(height:16),
    Expanded(child:Center(child:AspectRatio(aspectRatio:1,child:GestureDetector(onVerticalDragUpdate:(d){if(d.delta.dy>0)turn(n);else if(d.delta.dy<0)turn(-n);},onHorizontalDragUpdate:(d){if(d.delta.dx>0)turn(1);else if(d.delta.dx<0)turn(-1);},child:GridView.builder(physics:const NeverScrollableScrollPhysics(),itemCount:n*n,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:n),itemBuilder:(_,i)=>Container(margin:const EdgeInsets.all(1),decoration:BoxDecoration(color:snake.contains(i)?Colors.green:food==i?Colors.red:Theme.of(context).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(3)))))))),
    Row(mainAxisAlignment:MainAxisAlignment.center,children:[
      IconButton.filledTonal(onPressed:()=>turn(-1),icon:const Icon(Icons.arrow_left_rounded),tooltip:'چپ'),
      Column(mainAxisSize:MainAxisSize.min,children:[
        IconButton.filledTonal(onPressed:()=>turn(-n),icon:const Icon(Icons.arrow_upward_rounded),tooltip:'بالا'),
        IconButton.filledTonal(onPressed:()=>turn(n),icon:const Icon(Icons.arrow_downward_rounded),tooltip:'پایین'),
      ]),
      IconButton.filledTonal(onPressed:()=>turn(1),icon:const Icon(Icons.arrow_right_rounded),tooltip:'راست'),
    ]),
    if(over) const Text('بازی تمام شد! دوباره تلاش کن.'),
    FilledButton(onPressed:start,child:Text(running?'شروع دوباره':'شروع بازی')),
    const Text('برای تغییر مسیر، روی صفحه به بالا، پایین، چپ یا راست بکش.',style:TextStyle(fontSize:11)),
  ])));
}

typedef _ReadingPrompt = (String, List<String>, List<int>);
typedef _SymbolCard = (String, String);

class _PersonalityPage extends StatefulWidget {
  const _PersonalityPage();
  @override State<_PersonalityPage> createState() => _PersonalityPageState();
}

class _PersonalityPageState extends State<_PersonalityPage> {
  static const prompts = <_ReadingPrompt>[
    ('وقتی یک فرصت تازه پیش می‌آید، معمولاً چه می‌کنی؟',['بی‌درنگ امتحانش می‌کنم','اول همه چیز را می‌سنجم','با کسی مشورت می‌کنم'],[2,0,1]),
    ('در یک روز آزاد کدام برنامه را بیشتر دوست داری؟',['طبیعت‌گردی و کشف جاهای تازه','کتاب، موسیقی یا آرامش','دیدار دوستان و خانواده'],[2,0,1]),
    ('وقتی مشکلی پیش می‌آید، اولین واکنشت چیست؟',['یک راه تازه پیدا می‌کنم','آرام می‌شوم و مرحله‌به‌مرحله فکر می‌کنم','از یک دوست کمک می‌گیرم'],[2,1,0]),
    ('کدام هدیه بیشتر خوشحالت می‌کند؟',['یک تجربهٔ غیرمنتظره','چیزی با معنا و ماندگار','یک یادگاری از دوست'],[2,1,0]),
    ('در یک گروه معمولاً چه نقشی داری؟',['شروع‌کننده و پیش‌برنده','برنامه‌ریز و تحلیل‌گر','هماهنگ‌کننده و دلگرم‌کننده'],[2,1,0]),
    ('اگر یک مهارت تازه یاد بگیری، کدام را انتخاب می‌کنی؟',['ماجراجویی یا ورزش تازه','هنر، دانش یا زبان','گفت‌وگو و شناخت آدم‌ها'],[2,1,0]),
    ('کدام منظره بیشتر به دلت می‌نشیند؟',['قله‌های بلند و راه ناشناخته','کتابخانه و باران آرام','جمع دوستان کنار آتش'],[2,0,1]),
    ('وقتی کسی از تو نظر می‌خواهد، چه می‌کنی؟',['صادقانه و مستقیم می‌گویم','اول خوب گوش می‌دهم','با مهربانی راه‌حل پیشنهاد می‌کنم'],[2,1,0]),
    ('کدام جمله به تو نزدیک‌تر است؟',['از تجربه کردن نمی‌ترسم','در آرامش، جواب‌ها پیدا می‌شوند','با هم بودن راه را آسان می‌کند'],[2,0,1]),
    ('اگر یک سفر کوتاه داشته باشی، کجا می‌روی؟',['جایی که تا حالا ندیده‌ام','جای آرام و خلوت','شهری پر از آدم و فرهنگ'],[2,0,1]),
    ('در تصمیم‌های مهم بیشتر به چه تکیه می‌کنی؟',['جرأت و شهود','داده و فکر','احساس و رابطه‌ها'],[2,1,0]),
    ('چه چیزی بیشتر به تو انگیزه می‌دهد؟',['رسیدن به یک هدف تازه','فهمیدن یک موضوع عمیق','اثر خوب گذاشتن بر دیگران'],[2,1,0]),
    ('وقتی خسته می‌شوی، چه چیزی کمکت می‌کند؟',['حرکت و تغییر فضا','تنهایی و استراحت','صحبت با یک آدم نزدیک'],[2,0,1]),
    ('کدام رنگ را امروز انتخاب می‌کنی؟',['سبز روشن','آبی آرام','طلایی گرم'],[2,0,1]),
    ('اگر یک در بسته ببینی، چه برداشتی داری؟',['شاید راه تازه‌ای پشت آن باشد','باید دلیل بسته بودنش را بفهمم','شاید کسی کلیدش را داشته باشد'],[2,1,0]),
    ('در دوستی چه چیزی برایت مهم‌تر است؟',['صداقت و هیجان مشترک','اعتماد و درک متقابل','مهربانی و همراهی'],[2,1,0]),
  ];

  static const cards = <_SymbolCard>[
    ('چراغ','نماد روشن‌شدن یک ایده است؛ امروز یک کار کوچک را که عقب انداخته‌ای آغاز کن.'),
    ('پل','یادآور ارتباط است؛ شاید یک گفت‌وگوی صادقانه سوءتفاهمی را کمتر کند.'),
    ('درخت','نماد رشد آرام است؛ برای چیزی که می‌سازی به خودت زمان بده.'),
    ('ستاره','نشانهٔ امید و جهت است؛ هدفت را روشن و قدم بعدی را کوچک انتخاب کن.'),
    ('کلید','نماد امکان تازه است؛ راه‌حل ممکن است در پرسیدن یک سؤال بهتر باشد.'),
    ('رودخانه','یادآور انعطاف است؛ لازم نیست همه چیز دقیقاً طبق برنامه پیش برود.'),
    ('کوه','نماد پشتکار است؛ یک مانع بزرگ را به چند قدم کوچک تقسیم کن.'),
    ('پرنده','نشانهٔ آزادی انتخاب است؛ برای یک تصمیم، فضای بیشتری به خودت بده.'),
    ('کتاب','نماد یادگیری است؛ امروز از یک تجربه یا آدم تازه چیزی یاد بگیر.'),
    ('باران','یادآور تازه‌شدن است؛ کمی استراحت هم بخشی از پیشرفت است.'),
    ('قطب‌نما','نماد جهت‌یابی است؛ ارزش مهم خودت را پیش از انتخاب به یاد بیاور.'),
    ('بذر','نشانهٔ آغاز کوچک است؛ یک عادت خوب را با پنج دقیقه شروع کن.'),
  ];

  late List<_ReadingPrompt> session;
  final answers = <int>[];
  int page = 0;
  late _SymbolCard chosenCard;

  @override void initState(){super.initState();_restart();}
  void _restart(){
    session=List<_ReadingPrompt>.from(prompts)..shuffle(math.Random());
    session=session.take(6).toList();
    answers.clear();page=0;
    chosenCard=cards[math.Random().nextInt(cards.length)];
  }
  int get total {
    var sum=0;
    for(var i=0;i<answers.length;i++){sum+=session[i].$3[answers[i]];}
    return sum;
  }
  String get profile {
    if(total<=4)return 'آرام و ژرف‌نگر';
    if(total<=8)return 'همراه و پیونددهنده';
    return 'جستجوگر و ماجراجو';
  }
  String get reading {
    if(total<=4)return 'تو معمولاً پیش از حرکت، خوب نگاه می‌کنی. این دقت می‌تواند نقطهٔ قوتت باشد؛ فقط گاهی به خودت اجازه بده بدون کامل‌بودن همهٔ جواب‌ها هم شروع کنی.';
    if(total<=8)return 'تو میان فکر و احساس تعادل می‌جویی و حضور آدم‌ها برایت معنا دارد. مرزهای خودت را هم به اندازهٔ توجه به دیگران جدی بگیر.';
    return 'انرژی تجربه و کشف در انتخاب‌هایت پررنگ است. این جسارت ارزشمند است؛ اگر یک هدف را تا پایان دنبال کنی، نتیجه‌اش را بهتر می‌بینی.';
  }

  @override Widget build(BuildContext context){
    final done=page>=session.length;
    return _GameScaffold(title:'فال و گفت‌وگوی هوشمند',child:Padding(padding:const EdgeInsets.all(20),child:done
      ?Center(child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Icon(Icons.auto_awesome_rounded,size:62,color:Colors.amber),
        const Text('خوانش سرگرمی تو',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
        const SizedBox(height:8),
        Text(profile,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
        const SizedBox(height:10),
        Text(reading,textAlign:TextAlign.center,style:const TextStyle(height:1.6)),
        const SizedBox(height:18),
        Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
          const Text('نماد امروز تو',style:TextStyle(fontWeight:FontWeight.w900)),
          const SizedBox(height:6),
          Text(chosenCard.$1,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:Colors.amber)),
          const SizedBox(height:6),
          Text(chosenCard.$2,textAlign:TextAlign.center,style:const TextStyle(height:1.5)),
        ]))),
        const SizedBox(height:10),
        const Text('این نتیجه از پاسخ‌های همین نشست ساخته شده و فقط برای سرگرمی و خوداندیشی است؛ پیشگویی یا ارزیابی علمی شخصیت نیست.',textAlign:TextAlign.center,style:TextStyle(fontSize:11)),
        const SizedBox(height:14),
        FilledButton.icon(onPressed:()=>setState(_restart),icon:const Icon(Icons.refresh),label:const Text('گفت‌وگوی تازه')),
      ])))
      :Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text('پرسش ${page+1} از ${session.length}',style:const TextStyle(fontWeight:FontWeight.w900)),
        const SizedBox(height:8),LinearProgressIndicator(value:(page+1)/session.length),
        const SizedBox(height:26),
        Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const CircleAvatar(child:Icon(Icons.auto_awesome_rounded)),
          const SizedBox(width:10),
          Expanded(child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(18)),child:Text(session[page].$1,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800)))),
        ]),
        const SizedBox(height:18),
        ...List.generate(session[page].$2.length,(i)=>Padding(padding:const EdgeInsets.only(bottom:10),child:OutlinedButton(
          onPressed: () { setState(() { answers.add(i); page++; }); },
          child:Padding(padding:const EdgeInsets.all(10),child:Align(alignment:Alignment.centerRight,child:Text(session[page].$2[i]))),
        ))),
        const Spacer(),
        const Text('پاسخ درست یا غلطی وجود ندارد؛ همان چیزی را انتخاب کن که به حالت نزدیک‌تر است.',textAlign:TextAlign.center,style:TextStyle(fontSize:12)),
      ]),
    ));
  }
}
