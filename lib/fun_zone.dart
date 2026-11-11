import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Local-first entertainment hub for GapResan.
/// Multiplayer, shared scores and cloud persistence are intentionally not implied:
/// those require dedicated Supabase tables, policies and realtime flows.
class FunZonePage extends StatelessWidget {
  const FunZonePage({super.key});

  static const _items = <_FunItem>[
    _FunItem('بازی دونفره', 'دوز و رقابت دوستانه', Icons.grid_3x3_rounded, _FunKind.duel, Color(0xFF16A085)),
    _FunItem('مسابقه و معما', 'سؤال‌های کوتاه و امتیاز', Icons.quiz_rounded, _FunKind.quiz, Color(0xFF4776E6)),
    _FunItem('گردونه شانس', 'یک چرخش و یک جایزه مجازی', Icons.casino_rounded, _FunKind.wheel, Color(0xFFE6A23C)),
    _FunItem('استیکر و میم‌ساز', 'ساخت متن و استیکر ساده', Icons.emoji_emotions_rounded, _FunKind.stickers, Color(0xFFE76F9A)),
    _FunItem('شطرنج', 'صفحه تمرینی دونفره', Icons.grid_on_rounded, _FunKind.chess, Color(0xFF6574CD)),
    _FunItem('تخته‌نرد', 'بازی تمرینی با تاس', Icons.casino_outlined, _FunKind.backgammon, Color(0xFF9B6B43)),
    _FunItem('بازی مار', 'رکورد خودت را بشکن', Icons.videogame_asset_rounded, _FunKind.snake, Color(0xFF42A66C)),
    _FunItem('آزمون شخصیت و فال', 'فقط برای سرگرمی', Icons.auto_awesome_rounded, _FunKind.personality, Color(0xFF9B68C8)),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('سرگرمی‌های گپ‌رسان'), centerTitle: false),
      body: CustomScrollView(
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
              child: Text('بازی‌های فعلی روی همین دستگاه اجرا می‌شوند. رقابت آنلاین و ثبت رکورد حساب کاربری در مرحله بعد به سرور وصل می‌شود.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, height: 1.6)),
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, _FunKind kind) {
    final Widget page = switch (kind) {
      _FunKind.duel => const _TicTacToePage(),
      _FunKind.quiz => const _QuizPage(),
      _FunKind.wheel => const _WheelPage(),
      _FunKind.stickers => const _StickerMemePage(),
      _FunKind.chess => const _BoardPracticePage(chess: true),
      _FunKind.backgammon => const _BoardPracticePage(chess: false),
      _FunKind.snake => const _SnakePage(),
      _FunKind.personality => const _PersonalityPage(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

enum _FunKind { duel, quiz, wheel, stickers, chess, backgammon, snake, personality }

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
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: item.color.withValues(alpha: .14), borderRadius: BorderRadius.circular(15)),
            child: Icon(item.icon, color: item.color, size: 25)),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            const SizedBox(height: 4),
            Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ]),
      ),
    ),
  );
}

class _GameScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const _GameScaffold({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: SafeArea(child: child));
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

class _QuizPage extends StatefulWidget { const _QuizPage(); @override State<_QuizPage> createState() => _QuizPageState(); }
class _QuizPageState extends State<_QuizPage> {
  final questions = const [
    ('بزرگ‌ترین سیاره منظومه شمسی کدام است؟', ['زمین','مشتری','زهره','مریخ'], 1),
    ('آب در فشار معمول در چند درجه می‌جوشد؟', ['۵۰','۸۰','۱۰۰','۱۲۰'], 2),
    ('کدام حیوان پستاندار است؟', ['کوسه','دلفین','اختاپوس','قزل‌آلا'], 1),
    ('حاصل ۹ × ۷ چند است؟', ['۵۶','۶۳','۷۲','۶۷'], 1),
    ('کدام گاز بیشترین سهم هوای زمین را دارد؟', ['اکسیژن','کربن‌دی‌اکسید','نیتروژن','هیدروژن'], 2),
  ];
  int index = 0, score = 0; bool? answered;
  void choose(int i) { if (answered != null) return; setState(() { answered = i == questions[index].$3; if (answered!) score++; }); }
  void next() { setState(() { if (index < questions.length - 1) { index++; answered = null; } else { index = questions.length; } }); }
  @override Widget build(BuildContext context) => _GameScaffold(title: 'مسابقه و معما', child: Padding(padding: const EdgeInsets.all(18), child: index >= questions.length
    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.emoji_events_rounded, size: 64, color: Colors.amber), const Text('مسابقه تمام شد!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text('امتیاز تو: $score از ${questions.length}'), FilledButton(onPressed: () => setState(() { index=0; score=0; answered=null; }), child: const Text('شروع دوباره'))]))
    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('پرسش ${index+1} از ${questions.length}  ·  امتیاز: $score', style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 20), LinearProgressIndicator(value: (index+1)/questions.length),
      const SizedBox(height: 24), Text(questions[index].$1, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 18),
      ...List.generate(4, (i) => Padding(padding: const EdgeInsets.only(bottom: 10), child: OutlinedButton(
        onPressed: () => choose(i), child: Padding(padding: const EdgeInsets.all(9), child: Text(questions[index].$2[i]))))),
      if (answered != null) ...[Text(answered! ? 'آفرین! پاسخ درست بود.' : 'این پاسخ درست نبود.'), const SizedBox(height: 12), FilledButton(onPressed: next, child: Text(index == questions.length-1 ? 'دیدن نتیجه' : 'پرسش بعدی'))],
    ])));
}

class _WheelPage extends StatefulWidget { const _WheelPage(); @override State<_WheelPage> createState() => _WheelPageState(); }
class _WheelPageState extends State<_WheelPage> {
  final prizes = const ['۱۰ امتیاز مجازی','یک ستاره طلایی','یک شانس دوباره','۲۰ امتیاز مجازی','عنوان خوش‌شانس','یک لبخند بزرگ'];
  String? result; bool spinning = false;
  Future<void> spin() async { if (spinning) return; setState(() { spinning=true; result=null; }); await Future.delayed(const Duration(milliseconds: 1100)); if (!mounted) return; setState(() { result=prizes[math.Random().nextInt(prizes.length)]; spinning=false; }); }
  @override Widget build(BuildContext context) => _GameScaffold(title: 'گردونه شانس', child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    AnimatedRotation(turns: spinning ? 3.7 : 0, duration: const Duration(milliseconds: 1100), child: Container(width: 230, height: 230, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const SweepGradient(colors: [Colors.red, Colors.orange, Colors.amber, Colors.green, Colors.teal, Colors.blue, Colors.purple, Colors.red]), border: Border.all(color: Colors.white, width: 5), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18)]), child: const Center(child: Icon(Icons.star_rounded, color: Colors.white, size: 70)))),
    const SizedBox(height: 24), if (result != null) Text('جایزه تو: $result', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
    const SizedBox(height: 18), FilledButton.icon(onPressed: spinning ? null : spin, icon: const Icon(Icons.casino), label: Text(spinning ? 'در حال چرخش…' : 'چرخاندن گردونه')),
    const SizedBox(height: 12), const Text('امتیازها و جایزه‌ها فعلاً نمایشی و مجازی‌اند.', style: TextStyle(fontSize: 12)),
  ]))));
}

class _StickerMemePage extends StatefulWidget { const _StickerMemePage(); @override State<_StickerMemePage> createState() => _StickerMemePageState(); }
class _StickerMemePageState extends State<_StickerMemePage> {
  final controller = TextEditingController(text: 'امروز عالیه!'); String emoji = '😎';
  final emojis = const ['😎','😂','😍','🔥','💚','🥳','🤩','😴','🚀','🌟','🙌','❤️'];
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => _GameScaffold(title: 'استیکر و میم‌ساز', child: ListView(padding: const EdgeInsets.all(18), children: [
    Container(height: 240, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(24), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(emoji, style: const TextStyle(fontSize: 76)), Padding(padding: const EdgeInsets.all(14), child: Text(controller.text.isEmpty ? 'متن میم تو' : controller.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)))]))),
    const SizedBox(height: 16), TextField(controller: controller, onChanged: (_) => setState(() {}), maxLength: 50, decoration: const InputDecoration(labelText: 'متن استیکر', border: OutlineInputBorder())),
    const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 8, children: emojis.map((e) => ChoiceChip(label: Text(e, style: const TextStyle(fontSize: 24)), selected: emoji == e, onSelected: (_) => setState(() => emoji=e))).toList()),
    const SizedBox(height: 18), FilledButton.icon(onPressed: () async { await Clipboard.setData(ClipboardData(text: '$emoji  ${controller.text}')); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('متن استیکر کاپی شد.'))); }, icon: const Icon(Icons.copy), label: const Text('کاپی متن استیکر')),
    const Text('این نسخه متن و ایموجی را آماده می‌کند؛ خروجی تصویر و بسته استیکر در مرحله بعد اضافه می‌شود.', style: TextStyle(fontSize: 12)),
  ]));
}

class _BoardPracticePage extends StatefulWidget { final bool chess; const _BoardPracticePage({required this.chess}); @override State<_BoardPracticePage> createState() => _BoardPracticePageState(); }
class _BoardPracticePageState extends State<_BoardPracticePage> {
  late List<String> board; int? selected; bool whiteTurn = true; int dice = 0;
  @override void initState() { super.initState(); board = widget.chess ? _chessStart() : _backgammonStart(); }
  List<String> _chessStart() { final b=List<String>.filled(64,''); const row=['♜','♞','♝','♛','♚','♝','♞','♜']; for(var i=0;i<8;i++){b[i]=row[i];b[8+i]='♟';b[48+i]='♙';b[56+i]=['♖','♘','♗','♕','♔','♗','♘','♖'][i];} return b; }
  List<String> _backgammonStart() { final b=List<String>.filled(24,''); b[0]='⚪⚪';b[5]='⚫⚫⚫';b[7]='⚫⚫';b[11]='⚪⚪⚪';b[12]='⚫⚫⚫';b[16]='⚪⚪';b[18]='⚪⚪⚪';b[23]='⚫⚫';return b; }
  void tap(int i) { if (widget.chess) { setState(() { if (selected == null && board[i].isNotEmpty) { selected=i; } else if (selected != null && selected != i) { board[i]=board[selected!]; board[selected!]=''; selected=null; whiteTurn=!whiteTurn; } else { selected=null; } }); } else { if(dice==0) return; setState(() { if(selected==null && board[i].isNotEmpty) selected=i; else if(selected!=null && selected!=i) { board[i]=board[selected!];board[selected!]='';selected=null;dice=0;whiteTurn=!whiteTurn; } else selected=null; }); } }
  @override Widget build(BuildContext context) => _GameScaffold(title: widget.chess ? 'شطرنج · تمرینی' : 'تخته‌نرد · تمرینی', child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
    Text(widget.chess ? 'نوبت ${whiteTurn?'سفید':'سیاه'}' : 'نوبت ${whiteTurn?'مهره سفید':'مهره سیاه'}  ·  تاس: $dice', style: const TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 14),
    Expanded(child: AspectRatio(aspectRatio: 1, child: GridView.builder(physics: const NeverScrollableScrollPhysics(), itemCount: widget.chess?64:24, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: widget.chess?8:6), itemBuilder: (_,i) {
      final light = widget.chess ? ((i~/8+i%8)%2==0) : ((i~/6+i%6)%2==0);
      return InkWell(onTap: ()=>tap(i), child: Container(decoration: BoxDecoration(color:selected==i?Colors.amber:light?const Color(0xFFE8D5B5):const Color(0xFF916B4D), border: Border.all(color: Colors.black12)), child: Center(child: FittedBox(child: Text(board[i], style: TextStyle(fontSize: widget.chess?29:17))))));
    }))),
    if(!widget.chess) FilledButton(onPressed: ()=>setState(()=>dice=math.Random().nextInt(6)+1), child: const Text('انداختن تاس')),
    const SizedBox(height: 8), Text(widget.chess ? 'صفحه تمرینی برای جابه‌جایی مهره‌هاست؛ قوانین کامل شطرنج و داوری حرکت هنوز فعال نیست.' : 'نسخه نمایشی تخته و تاس است؛ قوانین کامل حرکت و زدن مهره هنوز فعال نیست.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
    TextButton(onPressed: ()=>setState(() {board=widget.chess?_chessStart():_backgammonStart();selected=null;whiteTurn=true;dice=0;}), child: const Text('شروع دوباره')),
  ])));
}

class _SnakePage extends StatefulWidget { const _SnakePage(); @override State<_SnakePage> createState() => _SnakePageState(); }
class _SnakePageState extends State<_SnakePage> {
  static const n=16; final random=math.Random(); List<int> snake=[119,118,117]; int food=85, direction=-1, score=0; Timer? timer; bool running=false, over=false;
  void start() { timer?.cancel(); setState(() {snake=[119,118,117];food=random.nextInt(n*n);direction=-1;score=0;over=false;running=true;}); timer=Timer.periodic(const Duration(milliseconds:180), (_) => step()); }
  void step() { if(!running)return; final head=snake.first; final next=head+direction; final valid=next>=0&&next<n*n&&!(direction==1&&head%n==n-1)&&!(direction==-1&&head%n==0)&&!(direction==n&&head~/n==n-1)&&!(direction==-n&&head~/n==0)&&!snake.contains(next); if(!valid){timer?.cancel();setState((){running=false;over=true;});return;} setState(() {snake.insert(0,next);if(next==food){score++;do{food=random.nextInt(n*n);}while(snake.contains(food));}else{snake.removeLast();}}); }
  void turn(int d){if((direction==-d)||d==direction)return;setState(()=>direction=d);}
  @override void dispose(){timer?.cancel();super.dispose();}
  @override Widget build(BuildContext context)=>_GameScaffold(title:'بازی مار',child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
    Text('امتیاز: $score',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
    const SizedBox(height:16),
    Expanded(child:Center(child:AspectRatio(aspectRatio:1,child:GestureDetector(onVerticalDragUpdate:(d){if(d.delta.dy>0)turn(n);else if(d.delta.dy<0)turn(-n);},onHorizontalDragUpdate:(d){if(d.delta.dx>0)turn(1);else if(d.delta.dx<0)turn(-1);},child:GridView.builder(physics:const NeverScrollableScrollPhysics(),itemCount:n*n,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:n),itemBuilder:(_,i)=>Container(margin:const EdgeInsets.all(1),decoration:BoxDecoration(color:snake.contains(i)?Colors.green:food==i?Colors.red:Theme.of(context).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(3)))))))),
    if(over) const Text('بازی تمام شد! دوباره تلاش کن.'),
    FilledButton(onPressed:start,child:Text(running?'شروع دوباره':'شروع بازی')),
    const Text('برای تغییر مسیر، روی صفحه به بالا، پایین، چپ یا راست بکش.',style:TextStyle(fontSize:11)),
  ])));
}

class _PersonalityPage extends StatefulWidget {
  const _PersonalityPage();
  @override
  State<_PersonalityPage> createState() => _PersonalityPageState();
}

class _PersonalityPageState extends State<_PersonalityPage> {
  final List<String> questions = const [
    'در یک روز آزاد کدام را انتخاب می‌کنی؟',
    'در جمع دوستان معمولاً…',
    'وقتی با چالش روبه‌رو می‌شوی…',
  ];
  final List<List<String>> options = const [
    ['ماجراجویی تازه', 'کتاب و آرامش', 'دیدار دوستان'],
    ['سر صحبت را باز می‌کنم', 'بیشتر گوش می‌دهم', 'همه را می‌خندانم'],
    ['سریع اقدام می‌کنم', 'اول خوب فکر می‌کنم', 'از دیگران کمک می‌گیرم'],
  ];
  final List<int> answers = [];
  int page = 0;

  String get result {
    final total = answers.fold<int>(0, (sum, value) => sum + value);
    if (total <= 2) return 'روحیه ماجراجو 🚀';
    if (total <= 4) return 'ذهن آرام و تحلیل‌گر 🧠';
    return 'همراه و اجتماعی 💚';
  }

  void restart() {
    setState(() {
      answers.clear();
      page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _GameScaffold(
      title: 'آزمون شخصیت و فال',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: page >= questions.length
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 60, color: Colors.amber),
                    const SizedBox(height: 12),
                    const Text('نتیجه سرگرمی تو', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(result, style: const TextStyle(fontSize: 19)),
                    const SizedBox(height: 10),
                    const Text(
                      'این آزمون علمی یا تشخیص شخصیت نیست؛ فقط برای تفریح است.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    FilledButton(onPressed: restart, child: const Text('دوباره انجام بده')),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('پرسش ${page + 1} از ${questions.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  LinearProgressIndicator(value: (page + 1) / questions.length),
                  const SizedBox(height: 22),
                  Text(questions[page], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  ...List.generate(
                    options[page].length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            answers.add(i);
                            page++;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(options[page][i]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
