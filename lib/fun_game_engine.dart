import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _PlayMode { bot, local, onlineHuman, onlineBot }

class FunGamePage extends StatefulWidget {
  final String gameType, title;
  const FunGamePage({super.key, required this.gameType, required this.title});
  @override State<FunGamePage> createState() => _FunGamePageState();
}
class _FunGamePageState extends State<FunGamePage> {
  final client=Supabase.instance.client, random=math.Random();
  _PlayMode? mode;
  int difficulty=2,xWins=0,oWins=0;
  List<String> board=[];
  String turn='X';
  String? winner,message;
  bool draw=false,thinking=false,busy=false;
  Map<String,dynamic>? room;
  StreamSubscription<List<Map<String,dynamic>>>? roomSub;
  bool get connectFour=>widget.gameType=='connect_four';
  String get uid=>client.auth.currentUser?.id??'';
  bool get online=>mode==_PlayMode.onlineHuman||mode==_PlayMode.onlineBot;
  bool get botRoom=>room?['is_bot_game']==true;
  String get roomStatus=>(room?['status']??'').toString();
  String get turnUser=>room?['turn_user_id']?.toString()??'';
  String get winnerUser=>room?['winner_id']?.toString()??'';
  String get playerOne=>room?['player_one_id']?.toString()??'';
  String get myMark=>uid==playerOne?'X':'O';
  int get version=>(room?['version'] as num?)?.toInt()??0;
  bool get ended=>online?roomStatus=='finished':winner!=null||draw;

  @override void initState(){super.initState();resetBoard();}
  void resetBoard(){board=List.filled(connectFour?42:9,connectFour?'0':'.');turn='X';winner=null;draw=false;thinking=false;}
  @override void dispose(){roomSub?.cancel();super.dispose();}

  Future<void> choose(_PlayMode value) async {
    if(value!=_PlayMode.online){
      await leaveRoom();if(!mounted)return;
      setState((){mode=value;room=null;message=null;resetBoard();});return;
    }
    if(uid.isEmpty){setState(()=>message='برای بازی آنلاین وارد حساب گپ‌رسان شو.');return;}
    setState(()=>busy=true);
    try{
      final data=await client.rpc(value==_PlayMode.onlineBot?'start_fun_game_bot':'join_fun_game_queue',params:{'p_game_type':widget.gameType}).timeout(const Duration(seconds:12));
      final row=Map<String,dynamic>.from(data as Map);
      await roomSub?.cancel();if(!mounted)return;
      setState(() { mode = value; room = row; busy = false; });
      roomSub=client.from('fun_game_rooms').stream(primaryKey:['id']).eq('id',row['id'].toString()).listen(
        (rows){if(mounted&&rows.isNotEmpty)setState(()=>room=Map<String,dynamic>.from(rows.first));},
        onError:(_){if(mounted)setState(()=>message='اتصال بازی قطع شد؛ اینترنت را بررسی کن.');});
    }catch(_){if(mounted)setState(() { busy = false; message = 'حریف پیدا نشد یا اتصال برقرار نیست. دوباره تلاش کن.'; });}
  }
  Future<void> leaveRoom() async{
    final old=room;await roomSub?.cancel();roomSub=null;
    if(old!=null&&(old['status']=='waiting'||(old['is_bot_game']==true&&old['status']=='active'))){try{await client.rpc('cancel_fun_game_queue',params:{'p_room_id':old['id']});}catch(_){}}
  }
  bool won(List<String>b,String m){
    if(!connectFour){const lines=[[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];return lines.any((l)=>l.every((i)=>b[i]==m));}
    for(var r=0;r<6;r++){for(var c=0;c<7;c++){if(b[r*7+c]!=m)continue;
      for(final d in const [(0,1),(1,0),(1,1),(1,-1)]){var n=1;for(final s in [-1,1]){var y=r+d.$1*s,x=c+d.$2*s;while(y>=0&&y<6&&x>=0&&x<7&&b[y*7+x]==m){n++;y+=d.$1*s;x+=d.$2*s;}}if(n>=4)return true;}
    }}return false;
  }
  int? landing(List<String>b,int c){if(c<0||c>6)return null;for(var r=5;r>=0;r--){final i=r*7+c;if(b[i]=='0')return i;}return null;}
  List<String> drop(List<String>b,int c,String m){final n=List<String>.from(b);final i=landing(n,c);if(i!=null)n[i]=m;return n;}

  Future<void> play(int index) async{
    if(busy||thinking||ended)return;
    if(online){
      if(roomStatus!='active'||turnUser!=uid)return;
      setState(()=>busy=true);
      try{
        final data=await client.rpc('submit_fun_game_move',params:{'p_room_id':room!['id'],'p_expected_version':version,'p_move':connectFour?index%7:index}).timeout(const Duration(seconds:10));
        if(mounted)setState(() { room = Map<String,dynamic>.from(data as Map); busy = false; });
        if(mounted&&botRoom&&roomStatus=='active')await botTurnOnline();
      }catch(e){if(mounted)setState(()=>busy=false);final v=e.toString().toLowerCase();snack(v.contains('not_your_turn')?'هنوز نوبت تو نیست.':v.contains('stale_game_version')?'حرکت حریف رسید؛ صفحه به‌روز شد.':'حرکت ثبت نشد؛ دوباره تلاش کن.');}return;
    }
    if(connectFour){final c=index%7;if(landing(board,c)==null){snack('این ستون پُر است.');return;}setState(()=>board=drop(board,c,turn));}
    else{if(index<0||index>8||board[index]!='.')return;setState(()=>board[index]=turn);}
    final mark=turn;
    if(won(board,mark)){setState(()=>winner=mark);if(mark=='X')xWins++;else oWins++;return;}
    if(board.every((v)=>connectFour?v!='0':v!='.')){setState(()=>draw=true);return;}
    setState(()=>turn=turn=='X'?'O':'X');
    if(mode==_PlayMode.bot&&turn=='O')await botTurn();
  }
  Future<void> botTurn()async{
    setState(()=>thinking=true);await Future<void>.delayed(const Duration(milliseconds:300));if(!mounted||ended)return;
    final move=botMove();if(move==null){setState(()=>thinking=false);return;}
    setState((){
      board=connectFour?drop(board,move,'O'):(List<String>.from(board)..[move]='O');thinking=false;
      if(won(board,'O')){winner='O';oWins++;}else if(board.every((v)=>connectFour?v!='0':v!='.'))draw=true;else turn='X';
    });
  }
  Future<void> botTurnOnline()async{
    if(!mounted||!botRoom||roomStatus!='active')return;
    setState(()=>thinking=true);
    await Future<void>.delayed(const Duration(milliseconds:350));
    if(!mounted||!botRoom||roomStatus!='active')return;
    final raw=room!['board'].toString().split('');
    board=raw.map((v)=>v=='1'?'X':v=='2'?'O':v).toList();
    final move=botMove();
    if(move==null){if(mounted)setState(()=>thinking=false);return;}
    setState(()=>busy=true);
    try{
      final data=await client.rpc('submit_fun_game_move',params:{
        'p_room_id':room!['id'],'p_expected_version':version,'p_move':connectFour?move:move,
      }).timeout(const Duration(seconds:10));
      if(mounted)setState(() { room = Map<String,dynamic>.from(data as Map); busy = false; thinking = false; });
    }catch(_){
      if(mounted)setState(() { busy = false; thinking = false; });
      snack('حرکت ربات ثبت نشد؛ اتصال را بررسی کن.');
    }
  }
  int? botMove(){
    if(connectFour){
      final cols=List.generate(7,(i)=>i).where((c)=>landing(board,c)!=null).toList();if(cols.isEmpty)return null;
      if(difficulty==1)return cols[random.nextInt(cols.length)];
      for(final c in cols){if(won(drop(board,c,'O'),'O'))return c;}
      for(final c in cols){if(won(drop(board,c,'X'),'X'))return c;}
      if(difficulty==3&&cols.contains(3))return 3;cols.sort((a,b)=>(a-3).abs().compareTo((b-3).abs()));return cols.first;
    }
    if(difficulty==3){var best=-999;int? chosen;for(var i=0;i<9;i++){if(board[i]!='.')continue;final b=List<String>.from(board)..[i]='O';final s=minimax(b,false,0);if(s>best){best=s;chosen=i;}}return chosen;}
    if(difficulty>=2){final a=winningMove('O');if(a!=null)return a;final b=winningMove('X');if(b!=null)return b;if(board[4]=='.')return 4;final corners=[0,2,6,8].where((i)=>board[i]=='.').toList();if(corners.isNotEmpty)return corners[random.nextInt(corners.length)];}
    final free=List.generate(9,(i)=>i).where((i)=>board[i]=='.').toList();return free.isEmpty?null:free[random.nextInt(free.length)];
  }
  int? winningMove(String m){for(var i=0;i<9;i++){if(board[i]!='.')continue;final b=List<String>.from(board)..[i]=m;if(won(b,m))return i;}return null;}
  int minimax(List<String>b,bool bot,int depth){if(won(b,'O'))return 10-depth;if(won(b,'X'))return depth-10;if(b.every((v)=>v!='.'))return 0;var best=bot?-100:100;for(var i=0;i<9;i++){if(b[i]!='.')continue;final n=List<String>.from(b)..[i]=bot?'O':'X';final s=minimax(n,!bot,depth+1);best=bot?math.max(best,s):math.min(best,s);}return best;}
  Future<void> newRound()async{if(online){await leaveRoom();if(mounted)setState(() { room = null; mode = null; });return;}setState(resetBoard);}
  void snack(String t){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t)));}

  @override Widget build(BuildContext context){
    if(mode==null)return picker();if(online&&roomStatus=='waiting')return waiting();
    final b=online?room!['board'].toString().split(''):board;final done=ended;final scheme=Theme.of(context).colorScheme;
    final statusText=online?(done?(room?['winner_mark']=='O'?'ربات برنده شد.':winnerUser.isEmpty?'بازی مساوی شد.':winnerUser==uid?'آفرین! تو برنده شدی.':'حریف برنده شد.'):botRoom?(version.isEven?'نوبت توست':'نوبت ربات'):turnUser==uid?'نوبت توست':'نوبت حریف است…')
      :winner!=null?(mode==_PlayMode.bot?(winner=='X'?'آفرین! تو برنده شدی.':'ربات برنده شد.'):'بازیکن $winner برنده شد!'):draw?'بازی مساوی شد.':thinking?'ربات فکر می‌کند…':mode==_PlayMode.bot?(turn=='X'?'نوبت توست':'نوبت ربات'):'نوبت بازیکن $turn';
    return Scaffold(appBar:AppBar(title:Text(widget.title),actions:[IconButton(onPressed:newRound,icon:const Icon(Icons.tune_rounded),tooltip:'تغییر حالت')]),
      body:SafeArea(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
        Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
          Text(statusText,textAlign:TextAlign.center,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
          const SizedBox(height:5),
          Text(online?(botRoom?'آنلاین · حریف ربات':'آنلاین · '+(myMark=='X'?'تو X هستی':'تو O هستی')):mode==_PlayMode.bot?'آفلاین · ربات هوشمند · سطح $difficulty':'آفلاین · دونفره روی یک دستگاه',style:TextStyle(color:scheme.onSurfaceVariant,fontSize:12)),
          if(online&&room!=null)Text('کد بازی: '+room!['id'].toString().substring(0,8),style:TextStyle(color:scheme.onSurfaceVariant,fontSize:11)),
        ]))),
        if(!online)Text('X: $xWins برد  •  O: $oWins برد',style:const TextStyle(fontWeight:FontWeight.w800)),
        const SizedBox(height:10),
        Expanded(child:Center(child:connectFour?connectBoard(b,done,scheme):ticBoard(b,done,scheme))),
        if(online&&roomStatus=='active')Text(turnUser==uid?'حرکتت را انتخاب کن':'منتظر حرکت حریف باش'),
        if(done)FilledButton.icon(onPressed:newRound,icon:const Icon(Icons.refresh),label:const Text('بازی تازه'))
        else if(!online)OutlinedButton.icon(onPressed:newRound,icon:const Icon(Icons.refresh),label:const Text('شروع دوباره')),
        const SizedBox(height:8),Text(connectFour?'چهار مهره را افقی، عمودی یا مورب ردیف کن.':'سه مهره را در یک خط ردیف کن.',textAlign:TextAlign.center,style:TextStyle(fontSize:12,color:scheme.onSurfaceVariant)),
      ]))));
  }
  Widget picker()=>Scaffold(appBar:AppBar(title:Text(widget.title)),body:ListView(padding:const EdgeInsets.all(18),children:[
    const SizedBox(height:12),const Icon(Icons.sports_esports_rounded,size:54),const SizedBox(height:12),
    const Text('حالت بازی را انتخاب کن',textAlign:TextAlign.center,style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:22),
    Card(child:ListTile(leading:const Icon(Icons.smart_toy_rounded),title:const Text('آفلاین با ربات'),subtitle:const Text('بدون اینترنت؛ سه سطح دشواری'),onTap:busy?null:()=>choose(_PlayMode.bot))),
    Card(child:Padding(padding:const EdgeInsets.symmetric(horizontal:14),child:Row(children:[
      const Expanded(child:Text('سطح هوش ربات',style:TextStyle(fontWeight:FontWeight.w700))),
      DropdownButton<int>(value:difficulty,items:const [DropdownMenuItem(value:1,child:Text('آسان')),DropdownMenuItem(value:2,child:Text('متوسط')),DropdownMenuItem(value:3,child:Text('سخت'))],onChanged:(v)=>setState(()=>difficulty=v??2)),
    ]))),
    Card(child:ListTile(leading:const Icon(Icons.people_alt_rounded),title:const Text('آفلاین دونفره'),subtitle:const Text('دو نفر روی همین گوشی، نوبتی'),onTap:busy?null:()=>choose(_PlayMode.local))),
    const Divider(height:30),
    Card(child:ListTile(leading:const Icon(Icons.smart_toy_outlined),title:const Text('آنلاین با ربات'),subtitle:const Text('بازی ثبت‌شده روی سرور؛ بدون انتظار برای حریف'),onTap:busy?null:()=>choose(_PlayMode.onlineBot))),
    Card(child:ListTile(leading:const Icon(Icons.public_rounded),title:const Text('آنلاین با حریف تصادفی'),subtitle:const Text('از میان کاربران گپ‌رسان حریف پیدا کن'),onTap:busy?null:()=>choose(_PlayMode.onlineHuman))),
    if(busy)const Center(child:Padding(padding:EdgeInsets.all(16),child:CircularProgressIndicator())),
    if(message!=null)Padding(padding:const EdgeInsets.all(12),child:Text(message!,textAlign:TextAlign.center,style:TextStyle(color:Theme.of(context).colorScheme.error))),
  ]));
  Widget waiting()=>Scaffold(appBar:AppBar(title:Text(widget.title),leading:IconButton(onPressed:newRound,icon:const Icon(Icons.arrow_back))),body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const CircularProgressIndicator(),const SizedBox(height:18),const Text('در حال پیدا کردن حریف آنلاین…',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
    const SizedBox(height:8),const Text('با ورود بازیکن دیگر، بازی خودکار آغاز می‌شود.',textAlign:TextAlign.center),const SizedBox(height:20),
    OutlinedButton.icon(onPressed:()async{await leaveRoom();if(mounted)setState(() { room = null; mode = _PlayMode.bot; resetBoard(); });},icon:const Icon(Icons.smart_toy),label:const Text('منتظر نمان؛ با ربات بازی کن')),
    TextButton(onPressed:newRound,child:const Text('لغو جستجو')),
  ]))));
  Widget ticBoard(List<String>b,bool done,ColorScheme scheme)=>AspectRatio(aspectRatio:1,child:GridView.builder(physics:const NeverScrollableScrollPhysics(),itemCount:9,
    gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,crossAxisSpacing:8,mainAxisSpacing:8),
    itemBuilder:(_,i){final m=b.length>i&&b[i]!='.'?b[i]:'';final can=!busy&&!thinking&&!done&&(!online||(roomStatus=='active'&&turnUser==uid));return Material(color:scheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(18),child:InkWell(borderRadius:BorderRadius.circular(18),onTap:can?()=>play(i):null,child:Center(child:Text(m,style:TextStyle(fontSize:52,fontWeight:FontWeight.w900,color:m=='X'?Colors.teal:Colors.deepOrange)))));}));
  Widget connectBoard(List<String>b,bool done,ColorScheme scheme)=>AspectRatio(aspectRatio:7/6,child:Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:const Color(0xFF2459A6),borderRadius:BorderRadius.circular(18)),child:GridView.builder(physics:const NeverScrollableScrollPhysics(),itemCount:42,
    gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7,crossAxisSpacing:5,mainAxisSpacing:5),
    itemBuilder:(_,i){final v=b.length>i?b[i]:'0';final m=online?(v=='1'?'X':v=='2'?'O':''):v=='0'?'':v;final can=!busy&&!thinking&&!done&&(!online||(roomStatus=='active'&&turnUser==uid));return GestureDetector(onTap:can?()=>play(i):null,child:DecoratedBox(decoration:BoxDecoration(shape:BoxShape.circle,color:m=='X'?const Color(0xFFE64B4B):m=='O'?const Color(0xFFFFD447):const Color(0xFFEAF1FA))));})));
}
