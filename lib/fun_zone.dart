import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    _FunItem('چهار در یک خط', 'چهار مهره را ردیف کن', Icons.view_week_rounded, _FunKind.connectFour, Color(0xFF6574CD)),
    _FunItem('بازی حافظه', 'جفت شکل‌های پنهان را پیدا کن', Icons.grid_view_rounded, _FunKind.memory, Color(0xFF9B6B43)),
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
      _FunKind.connectFour => const _ConnectFourPage(),
      _FunKind.memory => const _MemoryGamePage(),
      _FunKind.snake => const _SnakePage(),
      _FunKind.personality => const _PersonalityPage(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

enum _FunKind { duel, quiz, wheel, stickers, connectFour, memory, snake, personality }

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
  int index = 0, score = 0;
  bool? answered;
  int? selectedOption;

  void choose(int i) {
    if (answered != null) return;
    setState(() {
      selectedOption = i;
      answered = i == questions[index].$3;
      if (answered!) score++;
    });
  }

  void next() {
    setState(() {
      if (index < questions.length - 1) {
        index++;
        answered = null;
        selectedOption = null;
      } else {
        index = questions.length;
      }
    });
  }

  @override
  Widget build(BuildContext context) => _GameScaffold(
    title: 'مسابقه و معما',
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: index >= questions.length
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.emoji_events_rounded, size: 64, color: Colors.amber),
              const Text('مسابقه تمام شد!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text('امتیاز تو: $score از ${questions.length}'),
              FilledButton(onPressed: () => setState(() { index = 0; score = 0; answered = null; selectedOption = null; }), child: const Text('شروع دوباره')),
            ]))
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('پرسش ${index + 1} از ${questions.length}  ·  امتیاز: $score', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              LinearProgressIndicator(value: (index + 1) / questions.length),
              const SizedBox(height: 24),
              Text(questions[index].$1, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              ...List.generate(4, (i) {
                final isCorrectAnswer = i == questions[index].$3;
                final isSelected = i == selectedOption;
                final tint = answered == null
                    ? null
                    : isCorrectAnswer
                        ? Colors.green.withValues(alpha: .12)
                        : isSelected
                            ? Colors.red.withValues(alpha: .12)
                            : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton(
                    onPressed: answered == null ? () => choose(i) : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: tint,
                      side: BorderSide(
                        color: answered == null
                            ? Theme.of(context).colorScheme.outline
                            : isCorrectAnswer
                                ? Colors.green
                                : isSelected
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: Row(children: [
                        Expanded(child: Text(questions[index].$2[i])),
                        if (answered != null && isCorrectAnswer) const Icon(Icons.check_circle, color: Colors.green),
                        if (answered != null && isSelected && !isCorrectAnswer) const Icon(Icons.cancel, color: Colors.red),
                      ]),
                    ),
                  ),
                );
              }),
              if (answered != null) ...[
                Text(answered! ? 'آفرین! پاسخ درست بود.' : 'پاسخ درست: ${questions[index].$2[questions[index].$3]}'),
                const SizedBox(height: 12),
                FilledButton(onPressed: next, child: Text(index == questions.length - 1 ? 'دیدن نتیجه' : 'پرسش بعدی')),
              ],
            ]),
    ),
  );
}

class _WheelPage extends StatefulWidget { const _WheelPage(); @override State<_WheelPage> createState() => _WheelPageState(); }
class _WheelPageState extends State<_WheelPage> {
  final prizes = const ['۱۰ امتیاز مجازی','یک ستاره طلایی','یک شانس دوباره','۲۰ امتیاز مجازی','عنوان خوش‌شانس','یک لبخند بزرگ'];
  String? result;
  bool spinning = false;
  int turns = 0;

  Future<void> spin() async {
    if (spinning) return;
    final prize = prizes[math.Random().nextInt(prizes.length)];
    setState(() {
      spinning = true;
      result = null;
      turns += 5 + math.Random().nextInt(4);
    });
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    setState(() {
      result = prize;
      spinning = false;
    });
  }

  @override
  Widget build(BuildContext context) => _GameScaffold(
    title: 'گردونه شانس',
    child: Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(alignment: Alignment.topCenter, children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: AnimatedRotation(
              turns: turns.toDouble(),
              duration: const Duration(milliseconds: 2500),
              curve: Curves.easeOutCubic,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(colors: [Colors.red, Colors.orange, Colors.amber, Colors.green, Colors.teal, Colors.blue, Colors.purple, Colors.red]),
                  border: Border.all(color: Colors.white, width: 5),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18)],
                ),
                child: const Center(child: Icon(Icons.star_rounded, color: Colors.white, size: 70)),
              ),
            ),
          ),
          const Icon(Icons.arrow_drop_down_rounded, size: 42, color: Colors.deepOrange),
        ]),
        const SizedBox(height: 24),
        if (result != null) Text('جایزه تو: $result', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: spinning ? null : spin, icon: const Icon(Icons.casino), label: Text(spinning ? 'در حال چرخش…' : 'چرخاندن گردونه')),
        const SizedBox(height: 12),
        const Text('امتیازها و جایزه‌ها فعلاً نمایشی و مجازی‌اند.', style: TextStyle(fontSize: 12)),
      ]),
    )),
  );
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
class _ConnectFourPageState extends State<_ConnectFourPage>{
 static const rows=6,cols=7; List<int> board=List.filled(rows*cols,0);
 int turn=1,redWins=0,yellowWins=0; int? winner; bool draw=false;
 bool inside(int r,int c)=>r>=0&&r<rows&&c>=0&&c<cols;
 bool wins(int r,int c,int p){
  const dirs=[(0,1),(1,0),(1,1),(1,-1)];
  for(final (dr,dc) in dirs){var count=1;for(final sign in [-1,1]){var nr=r+dr*sign,nc=c+dc*sign;while(inside(nr,nc)&&board[nr*cols+nc]==p){count++;nr+=dr*sign;nc+=dc*sign;}}if(count>=4)return true;}return false;
 }
 void drop(int col){
  if(winner!=null||draw)return;var row=-1;for(var r=rows-1;r>=0;r--){if(board[r*cols+col]==0){row=r;break;}}
  if(row<0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('این ستون پُر است.')));return;}
  setState(() { board[row*cols+col]=turn; });
  if(wins(row,col,turn)){setState(() { winner=turn; if(turn==1){redWins++;}else{yellowWins++;} });}
  else if(board.every((v)=>v!=0)){setState(() { draw=true; });}
  else{setState(() { turn=turn==1?2:1; });}
 }
 void reset()=>setState(() { board=List.filled(rows*cols,0);turn=1;winner=null;draw=false; });
 @override Widget build(BuildContext context)=>_GameScaffold(title:'چهار در یک خط',child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
  Text('سرخ: '+redWins.toString()+' برد  ·  زرد: '+yellowWins.toString()+' برد',style:const TextStyle(fontWeight:FontWeight.w900)),
  const SizedBox(height:8),
  Text(winner!=null?(winner==1?'مهره سرخ برنده شد!':'مهره زرد برنده شد!'):draw?'بازی مساوی شد.':'نوبت بازیکن '+(turn==1?'سرخ':'زرد')),
  const SizedBox(height:12),
  Expanded(child:Center(child:AspectRatio(aspectRatio:cols/rows,child:Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:const Color(0xFF2459A6),borderRadius:BorderRadius.circular(18)),child:GridView.builder(physics:const NeverScrollableScrollPhysics(),itemCount:rows*cols,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:cols,crossAxisSpacing:5,mainAxisSpacing:5),itemBuilder:(_,i)=>GestureDetector(onTap:()=>drop(i%cols),child:DecoratedBox(decoration:BoxDecoration(shape:BoxShape.circle,color:board[i]==1?const Color(0xFFE64B4B):board[i]==2?const Color(0xFFFFD447):const Color(0xFFEAF1FA)))))))),
  const Text('هر نفر یک مهره در ستون انتخابی می‌اندازد. چهار مهرهٔ هم‌رنگ را افقی، عمودی یا مورب ردیف کن.',textAlign:TextAlign.center,style:TextStyle(fontSize:12)),
  const SizedBox(height:10),FilledButton.icon(onPressed:reset,icon:const Icon(Icons.refresh),label:const Text('دور تازه')),
 ])));
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
