import 'dart:math' as math;
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'fun_zone_theme.dart';

enum _ChessMode { bot, local }

class ChessGamePage extends StatefulWidget {
  const ChessGamePage({super.key});
  @override State<ChessGamePage> createState() => _ChessGamePageState();
}

class _ChessGamePageState extends State<ChessGamePage> {
  static const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  static const glyph = {'K':'♔','Q':'♕','R':'♖','B':'♗','N':'♘','P':'♙','k':'♚','q':'♛','r':'♜','b':'♝','n':'♞','p':'♟'};
  static const values = {Role.pawn:100,Role.knight:320,Role.bishop:330,Role.rook:500,Role.queen:900,Role.king:20000};
  final rng = math.Random();
  final history = <Position>[Chess.fromSetup(Setup.parseFen(fen))];
  final notation = <String>[];
  _ChessMode? mode;
  int level = 2;
  Square? selected;
  Set<Square> targets = {};
  bool thinking = false;
  String? notice;
  String? drawClaim;
  Position get pos => history.last;
  String get key => pos.fen.split(' ').take(4).join(' ');
  int get repetitions => history.where((p) => p.fen.split(' ').take(4).join(' ') == key).length;
  bool get finished => drawClaim != null || pos.isGameOver || repetitions >= 5 || pos.halfmoves >= 150;
  bool get canClaim => !finished && (repetitions >= 3 || pos.halfmoves >= 100);
  String get status {
    if (drawClaim != null) return drawClaim!;
    if (pos.isCheckmate) return 'کیش‌ومات؛ ' + (pos.turn == Side.white ? 'سیاه' : 'سفید') + ' برنده شد.';
    if (pos.isStalemate) return 'مساوی؛ وضعیت پات.';
    if (pos.isInsufficientMaterial) return 'مساوی؛ مهرهٔ کافی برای مات نیست.';
    if (pos.halfmoves >= 150) return 'مساوی طبق قانون ۷۵ حرکت.';
    if (repetitions >= 5) return 'مساوی؛ تکرار پنج‌باره.';
    if (pos.isCheck) return 'کیش! نوبت ' + (pos.turn == Side.white ? 'سفید' : 'سیاه');
    return 'نوبت ' + (pos.turn == Side.white ? 'سفید' : 'سیاه');
  }
  Square square(int row, int col) => Square.fromCoords(File(col), Rank(7-row));
  void reset() {
    history..clear()..add(Chess.fromSetup(Setup.parseFen(fen)));
    notation.clear(); selected=null; targets={}; thinking=false; notice=null; drawClaim=null;
  }
  void start(_ChessMode m) => setState(() { mode=m; reset(); });
  List<Move> moves(Position p) {
    final out=<Move>[];
    for (final e in makeLegalMoves(p).entries) {
      for (final to in e.value) {
        final piece=p.board.pieceAt(e.key);
        final promotion=piece?.role==Role.pawn && (to.rank==Rank.first || to.rank==Rank.eighth);
        out.add(NormalMove(from:e.key,to:to,promotion:promotion?Role.queen:null));
      }
    }
    return out;
  }
  int evaluate(Position p) {
    var score=0;
    for (final (_,piece) in p.board.pieces) {
      final v=values[piece.role]??0;
      score += piece.color==Side.black ? v : -v;
    }
    if (p.isCheckmate) score += p.turn==Side.white ? 100000 : -100000;
    return score;
  }
  void tap(Square s) {
    if (finished || thinking || (mode==_ChessMode.bot && pos.turn==Side.black)) return;
    final piece=pos.board.pieceAt(s);
    if (selected==null || (piece!=null && piece.color==pos.turn)) {
      setState(() { selected=piece?.color==pos.turn?s:null; targets=selected==null?{}:(makeLegalMoves(pos)[s]??{}); notice=null; });
      return;
    }
    if (!targets.contains(s)) { setState(() { selected=null; targets={}; notice='این حرکت قانونی نیست.'; }); return; }
    final from=selected!;
    final mover=pos.board.pieceAt(from);
    if (mover?.role==Role.pawn && (s.rank==Rank.first || s.rank==Rank.eighth)) {
      promote(from,s);
    } else {
      play(NormalMove(from:from,to:s));
    }
  }
  Future<void> promote(Square from, Square to) async {
    final role=await showModalBottomSheet<Role>(context:context,builder:(ctx)=>SafeArea(child:Row(
      mainAxisAlignment:MainAxisAlignment.spaceEvenly,
      children:[for(final r in [Role.queen,Role.rook,Role.bishop,Role.knight])
        IconButton(iconSize:40,onPressed:()=>Navigator.pop(ctx,r),icon:Text(glyph[pos.turn==Side.white?r.uppercaseLetter:r.letter]!))])));
    if (role!=null && mounted) play(NormalMove(from:from,to:to,promotion:role));
  }
  void play(Move move) {
    try {
      final (next,san)=pos.makeSan(move);
      setState(() { history.add(next); notation.add(san); selected=null; targets={}; notice=null; });
      if (mode==_ChessMode.bot && !finished && next.turn==Side.black) bot();
    } on PlayException {
      setState(() { selected=null; targets={}; notice='حرکت غیرقانونی است.'; });
    }
  }
  Future<void> bot() async {
    setState(()=>thinking=true);
    await Future<void>.delayed(const Duration(milliseconds:220));
    if (!mounted || finished) return;
    final choices=moves(pos);
    if (choices.isEmpty) { setState(()=>thinking=false); return; }
    Move chosen=choices[rng.nextInt(choices.length)];
    if (level>=2) {
      final scored=choices.map((m)=>(m,evaluate(pos.play(m)))).toList()..sort((a,b)=>b.$2.compareTo(a.$2));
      final top=scored.take(math.min(level==2?4:2,scored.length)).toList();
      chosen=top.first.$1;
      if (level==2) chosen=top[rng.nextInt(top.length)].$1;
      if (level==3) {
        var best=-1000000;
        for (final candidate in choices) {
          final next=pos.play(candidate);
          final replies=moves(next);
          var worst=1000000;
          for (final reply in replies) worst=math.min(worst,evaluate(next.play(reply)));
          final score=replies.isEmpty && next.isCheckmate ? 100000 : worst;
          if (score>best) { best=score; chosen=candidate; }
        }
      }
    }
    if (!mounted) return;
    final (next,san)=pos.makeSan(chosen);
    setState(() { history.add(next); notation.add(san); thinking=false; });
  }
  void undo() {
    if (history.length<2 || thinking) return;
    setState(() {
      final count=mode==_ChessMode.bot && history.length>=3?2:1;
      for(var i=0;i<count && history.length>1;i++) { history.removeLast(); notation.removeLast(); }
      selected=null; targets={}; notice=null;
    });
  }
  @override Widget build(BuildContext context) {
    if (mode==null) return Scaffold(backgroundColor:Colors.transparent,appBar:AppBar(title:const Text('شطرنج گپ‌رسان'),backgroundColor:Colors.transparent),floatingActionButton:const FunZoneThemeButton(),body:FunZoneBackdrop(child:ListView(padding:const EdgeInsets.all(18),children:[
      const SizedBox(height:18),const Icon(Icons.grid_4x4_rounded,size:60),
      const SizedBox(height:12),const Text('حالت بازی شطرنج',textAlign:TextAlign.center,style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
      const SizedBox(height:20),
      Card(child:ListTile(leading:const Icon(Icons.smart_toy),title:const Text('آفلاین با ربات'),subtitle:const Text('بدون اینترنت؛ سه سطح دشواری'),onTap:()=>start(_ChessMode.bot))),
      Card(child:Padding(padding:const EdgeInsets.symmetric(horizontal:14),child:Row(children:[
        const Expanded(child:Text('سطح ربات',style:TextStyle(fontWeight:FontWeight.bold))),
        DropdownButton<int>(value:level,items:const [DropdownMenuItem(value:1,child:Text('آسان')),DropdownMenuItem(value:2,child:Text('متوسط')),DropdownMenuItem(value:3,child:Text('سخت'))],onChanged:(v)=>setState(()=>level=v??2)),
      ]))),
      Card(child:ListTile(leading:const Icon(Icons.people),title:const Text('آفلاین دونفره'),subtitle:const Text('دو نفر روی یک دستگاه؛ نوبت و قوانین کامل'),onTap:()=>start(_ChessMode.local))),
      const Card(child:ListTile(leading:Icon(Icons.public),title:Text('آنلاین با حریف تصادفی'),subtitle:Text('پس از اعتبارسنجی امن حرکت‌ها روی سرور فعال می‌شود.'),enabled:false)),
      const Card(child:ListTile(leading:Icon(Icons.cloud_sync),title:Text('آنلاین با ربات'),subtitle:Text('پس از اتصال موتور قانونی سرور فعال می‌شود.'),enabled:false)),
    ])));
    final scheme=Theme.of(context).colorScheme;
    return Scaffold(backgroundColor:Colors.transparent,floatingActionButton:const FunZoneThemeButton(),appBar:AppBar(title:const Text('شطرنج'),backgroundColor:Colors.transparent,actions:[
      IconButton(onPressed:()=>setState(()=>mode=null),icon:const Icon(Icons.tune)),
      IconButton(onPressed:()=>setState(reset),icon:const Icon(Icons.refresh)),
    ]),body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.all(10),child:Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
        Text(thinking?'ربات در حال فکر کردن است…':status,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17)),
        Text(mode==_ChessMode.bot?'آفلاین با ربات · سطح '+['','آسان','متوسط','سخت'][level]:'آفلاین دونفره · یک دستگاه',style:TextStyle(color:scheme.onSurfaceVariant,fontSize:12)),
        if (notice!=null) Text(notice!,style:TextStyle(color:scheme.primary,fontSize:12)),
      ])))),
      Expanded(child:Center(child:AspectRatio(aspectRatio:1,child:Padding(padding:const EdgeInsets.all(8),child:GridView.builder(
        physics:const NeverScrollableScrollPhysics(),itemCount:64,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:8),
        itemBuilder:(context,i) {
          final row=i~/8,col=i%8,s=square(row,col),piece=pos.board.pieceAt(s);
          final light=(row+col).isEven,chosen=selected==s,target=targets.contains(s);
          return GestureDetector(onTap:()=>tap(s),child:Container(
            color:chosen?const Color(0xFFE5C84B):target?const Color(0xFF8DBB78):light?const Color(0xFFF0D9B5):const Color(0xFFB58863),
            child:Stack(children:[
              if(piece!=null) Center(child:FittedBox(child:Text(glyph[piece.fenChar]??'',style:TextStyle(fontSize:36,color:piece.color==Side.white?const Color(0xFFFFFEF7):const Color(0xFF171717),shadows:const [Shadow(color:Colors.black54,blurRadius:2)])))),
              if(target && piece==null) Center(child:Container(width:11,height:11,decoration:const BoxDecoration(color:Color(0xAA245B36),shape:BoxShape.circle))),
              if(target && piece!=null) Center(child:Container(decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:const Color(0xAA245B36),width:4)))),
              if(col==0) Positioned(left:2,top:1,child:Text((8-row).toString(),style:TextStyle(fontSize:8,color:light?Colors.brown:Colors.white70))),
              if(row==7) Positioned(right:2,bottom:0,child:Text('abcdefgh'[col],style:TextStyle(fontSize:8,color:light?Colors.brown:Colors.white70))),
            ]),
          ));
        },
      ))))),
      Wrap(alignment:WrapAlignment.center,spacing:8,children:[
        OutlinedButton.icon(onPressed:history.length>1&&!thinking?undo:null,icon:const Icon(Icons.undo),label:const Text('برگشت')),
        OutlinedButton.icon(onPressed:canClaim?()=>setState(()=>drawClaim=repetitions>=3?'مساوی؛ طبق قانون تکرار سه‌باره.':'مساوی؛ طبق قانون ۵۰ حرکت.'):null,icon:const Icon(Icons.handshake),label:const Text('اعلام مساوی')),
        TextButton.icon(onPressed:()=>setState(()=>mode=null),icon:const Icon(Icons.swap_horiz),label:const Text('تغییر حالت')),
      ]),
      if(notation.isNotEmpty) SizedBox(height:48,child:ListView(scrollDirection:Axis.horizontal,children:[
        for(var i=0;i<notation.length;i++) Padding(padding:const EdgeInsets.symmetric(horizontal:3),child:Chip(label:Text((i.isEven?(i~/2+1).toString()+'. ':'')+notation[i]))),
      ])),
    ]))));
  }
}
