import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'chess_engine/chess.dart' as chess;
import 'fun_zone_theme.dart';

enum _ChessMode { bot, local }

class ChessGamePage extends StatefulWidget {
  const ChessGamePage({super.key});
  @override State<ChessGamePage> createState() => _ChessGamePageState();
}

class _ChessGamePageState extends State<ChessGamePage> {
  static const _glyph = {
    'K':'♔','Q':'♕','R':'♖','B':'♗','N':'♘','P':'♙',
    'k':'♚','q':'♛','r':'♜','b':'♝','n':'♞','p':'♟',
  };
  static const _values = {
    chess.PieceType.PAWN:100,
    chess.PieceType.KNIGHT:320,
    chess.PieceType.BISHOP:330,
    chess.PieceType.ROOK:500,
    chess.PieceType.QUEEN:900,
    chess.PieceType.KING:20000,
  };

  final _rng = math.Random();
  chess.Chess game = chess.Chess();
  final _positions = <String>[];
  final _notation = <String>[];
  _ChessMode? mode;
  int level = 2;
  String? selected;
  Set<String> targets = {};
  bool thinking = false;
  String? notice;
  String? drawClaim;

  @override
  void initState() {
    super.initState();
    _positions.add(game.fen);
  }

  String get _positionKey => game.fen.split(' ').take(4).join(' ');
  int get repetitions => _positions.where((fen) => fen.split(' ').take(4).join(' ') == _positionKey).length;
  bool get finished => drawClaim != null || game.in_checkmate || game.in_stalemate ||
      game.insufficient_material || repetitions >= 5 || game.half_moves >= 150;
  bool get canClaim => !finished && (repetitions >= 3 || game.half_moves >= 100);

  String get status {
    if (drawClaim != null) return drawClaim!;
    if (game.in_checkmate) return 'کیش‌ومات؛ ' + (game.turn == chess.Color.WHITE ? 'سیاه' : 'سفید') + ' برنده شد.';
    if (game.in_stalemate) return 'مساوی؛ وضعیت پات.';
    if (game.insufficient_material) return 'مساوی؛ مهرهٔ کافی برای مات نیست.';
    if (game.half_moves >= 150) return 'مساوی طبق قانون ۷۵ حرکت.';
    if (repetitions >= 5) return 'مساوی؛ تکرار پنج‌باره.';
    if (game.in_check) return 'کیش! نوبت ' + (game.turn == chess.Color.WHITE ? 'سفید' : 'سیاه');
    return 'نوبت ' + (game.turn == chess.Color.WHITE ? 'سفید' : 'سیاه');
  }

  String _square(int row, int col) => 'abcdefgh'[col] + (8-row).toString();
  chess.Piece? _pieceAt(int row, int col) => game.get(_square(row,col));

  void reset() {
    game = chess.Chess();
    _positions..clear()..add(game.fen);
    _notation.clear();
    selected = null;
    targets = {};
    thinking = false;
    notice = null;
    drawClaim = null;
  }

  void start(_ChessMode nextMode) => setState(() { mode=nextMode; reset(); });

  List<chess.Move> _legalMoves([String? from]) =>
      game.generate_moves(from == null ? null : {'square':from});

  int _evaluate(chess.Chess position) {
    var score=0;
    for (var row=0;row<8;row++) {
      for (var col=0;col<8;col++) {
        final piece=position.get('abcdefgh'[col]+(8-row).toString());
        if (piece==null) continue;
        final value=_values[piece.type]??0;
        score += piece.color==chess.Color.BLACK ? value : -value;
      }
    }
    if (position.in_checkmate) score += position.turn==chess.Color.WHITE ? 100000 : -100000;
    return score;
  }

  void tap(String square) {
    if (finished || thinking || (mode==_ChessMode.bot && game.turn==chess.Color.BLACK)) return;
    final piece=game.get(square);
    if (selected==null || (piece!=null && piece.color==game.turn)) {
      setState(() {
        selected=piece?.color==game.turn?square:null;
        targets=selected==null?{}:_legalMoves(selected).map((m)=>m.toAlgebraic).toSet();
        notice=null;
      });
      return;
    }
    if (!targets.contains(square)) {
      setState(() { selected=null; targets={}; notice='این حرکت قانونی نیست.'; });
      return;
    }
    final from=selected!;
    final moves=_legalMoves(from).where((m)=>m.toAlgebraic==square).toList();
    if (moves.isEmpty) {
      setState(() { selected=null; targets={}; notice='حرکت در این وضعیت مجاز نیست.'; });
      return;
    }
    if (moves.any((m)=>m.promotion!=null)) {
      promote(from,square);
    } else {
      play(moves.first);
    }
  }

  Future<void> promote(String from,String to) async {
    final role=await showModalBottomSheet<chess.PieceType>(
      context:context,
      showDragHandle:true,
      builder:(ctx)=>SafeArea(child:Padding(
        padding:const EdgeInsets.all(18),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          const Text('مهرهٔ ارتقا را انتخاب کنید',style:TextStyle(fontWeight:FontWeight.w900,fontSize:17)),
          const SizedBox(height:12),
          Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
            for(final item in [chess.PieceType.QUEEN,chess.PieceType.ROOK,chess.PieceType.BISHOP,chess.PieceType.KNIGHT])
              IconButton.filledTonal(
                iconSize:38,
                onPressed:()=>Navigator.pop(ctx,item),
                icon:Text(_glyph[game.turn==chess.Color.WHITE?item.toUpperCase():item.toLowerCase()]!),
              ),
          ]),
        ]),
      )),
    );
    if (role!=null && mounted) {
      final move = _legalMoves(from).firstWhere(
        (candidate) => candidate.toAlgebraic == to && candidate.promotion == role,
      );
      final san = game.move_to_san(move);
      final moved = game.move(move);
      if (moved) {
        setState(() {
          _notation.add(san);
          _positions.add(game.fen);
          selected=null; targets={}; notice=null;
        });
        if (mode==_ChessMode.bot && !finished && game.turn==chess.Color.BLACK) bot();
      } else {
        setState(() { selected=null; targets={}; notice='ارتقای مهره انجام نشد؛ دوباره تلاش کنید.'; });
      }
    }
  }

  void play(chess.Move move) {
    final san=game.move_to_san(move);
    if (!game.move(move)) {
      setState(() { selected=null; targets={}; notice='حرکت غیرقانونی است؛ صفحه دوباره بررسی شد.'; });
      return;
    }
    setState(() {
      _notation.add(san);
      _positions.add(game.fen);
      selected=null; targets={}; notice=null;
    });
    if (mode==_ChessMode.bot && !finished && game.turn==chess.Color.BLACK) bot();
  }

  Future<void> bot() async {
    setState(()=>thinking=true);
    await Future<void>.delayed(const Duration(milliseconds:180));
    if (!mounted || finished) return;
    final choices=_legalMoves();
    if (choices.isEmpty) { setState(()=>thinking=false); return; }
    var chosen=choices[_rng.nextInt(choices.length)];
    if (level>=2) {
      final scored=< (chess.Move,int) >[];
      for (final move in choices) {
        final next=game.copy()..move(move);
        scored.add((move,_evaluate(next)));
      }
      scored.sort((a,b)=>b.$2.compareTo(a.$2));
      final top=scored.take(math.min(level==2?4:2,scored.length)).toList();
      chosen=top.first.$1;
      if (level==2) {
        chosen=top[_rng.nextInt(top.length)].$1;
      } else {
        var best=-1000000;
        for (final candidate in choices) {
          final next=game.copy()..move(candidate);
          final replies=next.generate_moves();
          var worst=1000000;
          for (final reply in replies) {
            final response=next.copy()..move(reply);
            worst=math.min(worst,_evaluate(response));
          }
          final score = replies.isEmpty ? (next.in_checkmate ? 100000 : 0) : worst;
          if (score>best) { best=score; chosen=candidate; }
        }
      }
    }
    if (!mounted) return;
    final san=game.move_to_san(chosen);
    if (game.move(chosen)) {
      setState(() { _notation.add(san); _positions.add(game.fen); thinking=false; });
    } else {
      setState(() { thinking=false; notice='ربات نتوانست حرکت را ثبت کند؛ بازی را دوباره آغاز کنید.'; });
    }
  }

  void undo() {
    if (game.history.isEmpty || thinking) return;
    setState(() {
      final count=mode==_ChessMode.bot && game.history.length>=2?2:1;
      for (var i=0;i<count && game.history.isNotEmpty;i++) {
        game.undo();
        if (_positions.length>1) _positions.removeLast();
        if (_notation.isNotEmpty) _notation.removeLast();
      }
      selected=null; targets={}; notice=null; drawClaim=null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (mode==null) {
      return Scaffold(
        backgroundColor:Colors.transparent,
        appBar:AppBar(title:const Text('شطرنج گپ‌رسان'),backgroundColor:Colors.transparent),
        floatingActionButton:const FunZoneThemeButton(),
        body:FunZoneBackdrop(child:ListView(padding:const EdgeInsets.all(18),children:[
          const SizedBox(height:18),
          const Icon(Icons.grid_4x4_rounded,size:60),
          const SizedBox(height:12),
          const Text('حالت بازی شطرنج',textAlign:TextAlign.center,style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),
          const SizedBox(height:20),
          Card(child:ListTile(leading:const Icon(Icons.smart_toy),title:const Text('آفلاین با ربات'),subtitle:const Text('بدون اینترنت؛ سه سطح دشواری'),onTap:()=>start(_ChessMode.bot))),
          Card(child:Padding(padding:const EdgeInsets.symmetric(horizontal:14),child:Row(children:[
            const Expanded(child:Text('سطح ربات',style:TextStyle(fontWeight:FontWeight.bold))),
            DropdownButton<int>(value:level,items:const [
              DropdownMenuItem(value:1,child:Text('آسان')),
              DropdownMenuItem(value:2,child:Text('متوسط')),
              DropdownMenuItem(value:3,child:Text('سخت')),
            ],onChanged:(v)=>setState(()=>level=v??2)),
          ]))),
          Card(child:ListTile(leading:const Icon(Icons.people),title:const Text('آفلاین دونفره'),subtitle:const Text('دو نفر روی یک دستگاه؛ قوانین کامل'),onTap:()=>start(_ChessMode.local))),
          const Card(child:ListTile(leading:Icon(Icons.public),title:Text('آنلاین با حریف تصادفی'),subtitle:Text('تا زمان اعتبارسنجی امن حرکت‌ها روی سرور غیرفعال است.'),enabled:false)),
        ])),
      );
    }
    final scheme=Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor:Colors.transparent,
      floatingActionButton:const FunZoneThemeButton(),
      appBar:AppBar(title:const Text('شطرنج'),backgroundColor:Colors.transparent,actions:[
        IconButton(tooltip:'تغییر حالت',onPressed:()=>setState(()=>mode=null),icon:const Icon(Icons.tune_rounded)),
        IconButton(tooltip:'شروع دوباره',onPressed:()=>setState(reset),icon:const Icon(Icons.refresh_rounded)),
      ]),
      body:FunZoneBackdrop(child:SafeArea(child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(12,8,12,10),child:Card(elevation:2,child:Padding(padding:const EdgeInsets.all(13),child:Column(children:[
          Text(thinking?'ربات در حال فکر کردن است…':status,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:17)),
          const SizedBox(height:4),
          Text(mode==_ChessMode.bot?'آفلاین با ربات · سطح '+['','آسان','متوسط','سخت'][level]:'آفلاین دونفره · یک دستگاه',style:TextStyle(color:scheme.onSurfaceVariant,fontSize:12)),
          if (notice!=null) ...[
            const SizedBox(height:6),
            Text(notice!,textAlign:TextAlign.center,style:TextStyle(color:scheme.primary,fontSize:12)),
          ],
        ])))),
        Expanded(child:Center(child:AspectRatio(aspectRatio:1,child:Padding(padding:const EdgeInsets.all(8),child:DecoratedBox(
          decoration:BoxDecoration(borderRadius:BorderRadius.circular(16),boxShadow:[
            BoxShadow(color:Colors.black.withValues(alpha:0.18),blurRadius:18,offset:const Offset(0,7)),
          ]),
          child:ClipRRect(borderRadius:BorderRadius.circular(16),child:GridView.builder(
            physics:const NeverScrollableScrollPhysics(),
            itemCount:64,
            gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:8),
            itemBuilder:(context,index) {
              final row=index~/8,col=index%8,square=_square(row,col),piece=_pieceAt(row,col);
              final light=(row+col).isEven,chosen=selected==square,target=targets.contains(square);
              final symbol=piece==null?null:_glyph[piece.color==chess.Color.WHITE?piece.type.toUpperCase():piece.type.toLowerCase()];
              return GestureDetector(
                behavior:HitTestBehavior.opaque,
                onTap:()=>tap(square),
                child:AnimatedContainer(
                  duration:const Duration(milliseconds:120),
                  color:chosen?const Color(0xFFE7C85B):light?const Color(0xFFF0DCC0):const Color(0xFF926B4C),
                  child:Stack(alignment:Alignment.center,children:[
                    if (target && piece==null) Container(width:13,height:13,decoration:const BoxDecoration(color:Color(0xAA245B36),shape:BoxShape.circle)),
                    if (target && piece!=null) Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(border:Border.all(color:const Color(0xCC245B36),width:3)))),
                    if (symbol!=null) FittedBox(child:Padding(padding:const EdgeInsets.all(2),child:Text(symbol,style:TextStyle(fontSize:38,color:piece.color==chess.Color.WHITE?const Color(0xFFFFFEF7):const Color(0xFF171717),shadows:const [Shadow(color:Colors.black54,blurRadius:2)])))),
                    if (col==0) Positioned(left:3,top:1,child:Text((8-row).toString(),style:TextStyle(fontSize:8,fontWeight:FontWeight.w800,color:light?const Color(0xFF73563F):Colors.white70))),
                    if (row==7) Positioned(right:3,bottom:0,child:Text('abcdefgh'[col],style:TextStyle(fontSize:8,fontWeight:FontWeight.w800,color:light?const Color(0xFF73563F):Colors.white70))),
                  ]),
                ),
              );
            },
          )),
        ))))),
        Padding(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),child:Wrap(alignment:WrapAlignment.center,spacing:8,children:[
          OutlinedButton.icon(onPressed:game.history.isNotEmpty&&!thinking?undo:null,icon:const Icon(Icons.undo_rounded),label:const Text('برگشت')),
          OutlinedButton.icon(onPressed:canClaim?()=>setState(()=>drawClaim=repetitions>=3?'مساوی؛ طبق قانون تکرار سه‌باره.':'مساوی؛ طبق قانون ۵۰ حرکت.'):null,icon:const Icon(Icons.handshake_rounded),label:const Text('اعلام مساوی')),
          TextButton.icon(onPressed:()=>setState(()=>mode=null),icon:const Icon(Icons.swap_horiz_rounded),label:const Text('تغییر حالت')),
        ])),
        if (_notation.isNotEmpty) SizedBox(height:48,child:ListView(scrollDirection:Axis.horizontal,children:[
          for (var i=0;i<_notation.length;i++) Padding(padding:const EdgeInsets.symmetric(horizontal:3),child:Chip(label:Text((i.isEven?(i~/2+1).toString()+'. ':'')+_notation[i]))),
        ])),
      ])))),
    );
  }
}
