import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'fun_zone_theme.dart';
import 'fun_game_room_chat.dart';
import 'fun_game_voice_call.dart';

enum _PlayMode { bot, local, onlineHuman, onlineBot }

class FunGamePage extends StatefulWidget {
  final String gameType, title;
  const FunGamePage({super.key, required this.gameType, required this.title});
  @override State<FunGamePage> createState() => _FunGamePageState();
}
class _FunGamePageState extends State<FunGamePage> with WidgetsBindingObserver {
  // Keep local/offline games independent from Supabase initialization.
  // Resolve the client only when an online action actually needs it.
  SupabaseClient get client => Supabase.instance.client;
  final random=math.Random();
  _PlayMode? mode;
  int difficulty=2,xWins=0,oWins=0;
  List<String> board=[];
  String turn='X';
  String? winner,message;
  bool draw=false,thinking=false,busy=false;
  Map<String,dynamic>? room;
  StreamSubscription<List<Map<String,dynamic>>>? roomSub;
  Timer? _reconnectTimer;
  bool _reconnecting=false, _pollingRoom=false;
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
  bool get ended=>online?(roomStatus=='finished'||roomStatus=='cancelled'):winner!=null||draw;

  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);resetBoard();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed&&online&&roomStatus=='active'){unawaited(_pollRoomState());_scheduleRoomReconnect();}}
  void resetBoard(){board=List.filled(connectFour?42:9,connectFour?'0':'.');turn='X';winner=null;draw=false;thinking=false;}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);_reconnectTimer?.cancel();_roomPollTimer?.cancel();roomSub?.cancel();super.dispose();}

  Future<void> choose(_PlayMode value) async {
    if(value!=_PlayMode.onlineHuman&&value!=_PlayMode.onlineBot){
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
      _watchRoom(row['id'].toString());
    }catch(_){if(mounted)setState(() { busy = false; message = 'حریف پیدا نشد یا اتصال برقرار نیست. دوباره تلاش کن.'; });}
  }
  void _watchRoom(String roomId){
    _reconnectTimer?.cancel();
    roomSub?.cancel();
    roomSub=client.from('fun_game_rooms').stream(primaryKey:['id']).eq('id',roomId).listen(
      (rows){
        if(!mounted||rows.isEmpty)return;
        _reconnectTimer?.cancel();
        if(_reconnecting)setState(()=>_reconnecting=false);
        setState(()=>room=Map<String,dynamic>.from(rows.first));
        if(rows.first['is_bot_game']==true&&rows.first['status']=='active'&&((rows.first['version'] as num?)?.toInt()??0).isOdd&&!thinking&&!busy){unawaited(botTurnOnline());}
      },
      onError:(_){
        if(mounted){setState(()=>message='ارتباط قطع شد؛ تا ۵ ثانیه دیگر خودکار وصل می‌شویم.');_scheduleRoomReconnect();}
      },
    );
  }
  void _startRoomPolling(){
    _roomPollTimer?.cancel();
    _roomPollTimer=Timer.periodic(const Duration(seconds:5),(_){
      if(online&&roomStatus=='active')unawaited(_pollRoomState());
    });
  }
  Future<void> _pollRoomState()async{
    final id=room?['id']?.toString();
    if(!mounted||id==null||_reconnecting)return;
    _reconnecting=true;
    try{
      final row=await client.from('fun_game_rooms').select().eq('id',id).maybeSingle().timeout(const Duration(seconds:5));
      if(!mounted)return;
      if(row!=null){
        final latest=Map<String,dynamic>.from(row);
        if((latest['version'] as num?)?.toInt()!=version||latest['status']!=roomStatus){
          setState(()=>room=latest);
        }
      }
      _reconnecting=false;
    }catch(_){
      _reconnecting=false;
      if(mounted&&roomStatus=='active'){
        setState(()=>message='اتصال ناپایدار است؛ بازی تا برگشت اینترنت حفظ می‌شود.');
        _scheduleRoomReconnect();
      }
    }
  }
  void _scheduleRoomReconnect(){
    if(!mounted||!online||room==null||roomStatus!='active')return;
    _reconnectTimer?.cancel();
    _reconnectTimer=Timer(const Duration(seconds:5),()=>unawaited(_restoreRoom()));
  }
  Future<void> _restoreRoom()async{
    final id=room?['id']?.toString();
    if(!mounted||id==null||_reconnecting)return;
    _reconnecting=true;
    try{
      final row=await client.from('fun_game_rooms').select().eq('id',id).maybeSingle().timeout(const Duration(seconds:8));
      if(!mounted)return;
      if(row==null){setState(()=>message='اتاق بازی دیگر پیدا نشد.');_reconnecting=false;return;}
      setState(()=>room=Map<String,dynamic>.from(row));
      _reconnecting=false;
      if(roomStatus=='active')_watchRoom(id);
    }catch(_){
      _reconnecting=false;
      if(mounted){setState(()=>message='اتصال هنوز برقرار نیست؛ ۵ ثانیه دیگر دوباره تلاش می‌کنیم.');_scheduleRoomReconnect();}
    }
  }
  void _openRoomChat(){
    final id=room?['id']?.toString();
    if(id==null)return;
    showModalBottomSheet<void>(
      context:context,isScrollControlled:true,showDragHandle:true,
      builder:(context)=>SafeArea(child:Padding(
        padding:EdgeInsets.fromLTRB(12,4,12,MediaQuery.of(context).viewInsets.bottom+12),
        child:FunGameRoomChatPanel(roomId:id),
      )),
    );
  }

  Future<void> leaveRoom() async{
    final old=room;await roomSub?.cancel();roomSub=null;
    if(old!=null&&(old['status']=='waiting'||old['status']=='active')){try{await client.rpc('cancel_fun_game_queue',params:{'p_room_id':old['id']});}catch(_){}}
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
      if(roomStatus!='active'||turnUser!=uid||(botRoom&&version.isOdd))return;
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
    if(!mounted||!botRoom||roomStatus!='active'||version.isEven||thinking||busy)return;
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
      if(difficulty==3){
        var bestScore=-1000000;int? bestColumn;
        // Search five plies and examine central columns first. This improves
        // tactical detection while alpha-beta pruning keeps the mobile workload bounded.
        cols.sort((a,b)=>(a-3).abs().compareTo((b-3).abs()));
        for(final c in cols){
          final score=connectFourMinimax(drop(board,c,'O'),5,false,-1000000,1000000);
          if(score>bestScore){bestScore=score;bestColumn=c;}
        }
        return bestColumn;
      }
      if(cols.contains(3))return 3;
      cols.sort((a,b)=>(a-3).abs().compareTo((b-3).abs()));return cols.first;
    }
    if(difficulty==3){var best=-999;int? chosen;for(var i=0;i<9;i++){if(board[i]!='.')continue;final b=List<String>.from(board)..[i]='O';final s=minimax(b,false,0);if(s>best){best=s;chosen=i;}}return chosen;}
    if(difficulty>=2){final a=winningMove('O');if(a!=null)return a;final b=winningMove('X');if(b!=null)return b;if(board[4]=='.')return 4;final corners=[0,2,6,8].where((i)=>board[i]=='.').toList();if(corners.isNotEmpty)return corners[random.nextInt(corners.length)];}
    final free=List.generate(9,(i)=>i).where((i)=>board[i]=='.').toList();return free.isEmpty?null:free[random.nextInt(free.length)];
  }
  int evaluateConnectFour(List<String> b){
    var score=0;
    for(var r=0;r<6;r++){if(b[r*7+3]=='O')score+=4;if(b[r*7+3]=='X')score-=4;}
    const dirs=[(0,1),(1,0),(1,1),(1,-1)];
    for(var r=0;r<6;r++){for(var col=0;col<7;col++){for(final d in dirs){
      final endR=r+3*d.$1,endC=col+3*d.$2;
      if(endR<0||endR>=6||endC<0||endC>=7)continue;
      var o=0,x=0;
      for(var k=0;k<4;k++){final v=b[(r+k*d.$1)*7+col+k*d.$2];if(v=='O')o++;if(v=='X')x++;}
      if(x==0){score+=o==1?2:o==2?12:o==3?90:0;}
      if(o==0){score-=x==1?3:x==2?16:x==3?110:0;}
    }}}return score;
  }
  int connectFourMinimax(List<String>b,int depth,bool maximizing,int alpha,int beta){
    if(won(b,'O'))return 100000+depth;
    if(won(b,'X'))return -100000-depth;
    final cols=List.generate(7,(i)=>i).where((c)=>landing(b,c)!=null).toList()
      ..sort((a,b)=>(a-3).abs().compareTo((b-3).abs()));
    if(depth==0||cols.isEmpty)return evaluateConnectFour(b);
    if(maximizing){
      var best=-1000000;
      for(final c in cols){best=math.max(best,connectFourMinimax(drop(b,c,'O'),depth-1,false,alpha,beta));alpha=math.max(alpha,best);if(beta<=alpha)break;}
      return best;
    }
    var best=1000000;
    for(final c in cols){best=math.min(best,connectFourMinimax(drop(b,c,'X'),depth-1,true,alpha,beta));beta=math.min(beta,best);if(beta<=alpha)break;}
    return best;
  }
  int? winningMove(String m){for(var i=0;i<9;i++){if(board[i]!='.')continue;final b=List<String>.from(board)..[i]=m;if(won(b,m))return i;}return null;}
  int minimax(List<String>b,bool bot,int depth){if(won(b,'O'))return 10-depth;if(won(b,'X'))return depth-10;if(b.every((v)=>v!='.'))return 0;var best=bot?-100:100;for(var i=0;i<9;i++){if(b[i]!='.')continue;final n=List<String>.from(b)..[i]=bot?'O':'X';final s=minimax(n,!bot,depth+1);best=bot?math.max(best,s):math.min(best,s);}return best;}
  Future<void> newRound()async{if(online){await leaveRoom();if(mounted)setState(() { room = null; mode = null; });return;}setState(resetBoard);}
  void snack(String t){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t)));}

  @override Widget build(BuildContext context){
    if(mode==null)return picker();if(online&&roomStatus=='waiting')return waiting();
    final b=online?room!['board'].toString().split(''):board;final done=ended;final scheme=Theme.of(context).colorScheme;
    final statusText=online?(roomStatus=='cancelled'?'بازی لغو شد؛ حریف از اتاق خارج شد.':done?(botRoom?(room?['winner_mark']=='O'?'ربات برنده شد.':room?['winner_mark']=='X'?'آفرین! تو برنده شدی.':'بازی مساوی شد.'):(winnerUser.isEmpty?'بازی مساوی شد.':winnerUser==uid?'آفرین! تو برنده شدی.':'حریف برنده شد.')):botRoom?(version.isEven?'نوبت توست':'نوبت ربات'):turnUser==uid?'نوبت توست':'نوبت حریف است…')
      :winner!=null?(mode==_PlayMode.bot?(winner=='X'?'آفرین! تو برنده شدی.':'ربات برنده شد.'):'بازیکن $winner برنده شد!'):draw?'بازی مساوی شد.':thinking?'ربات فکر می‌کند…':mode==_PlayMode.bot?(turn=='X'?'نوبت توست':'نوبت ربات'):'نوبت بازیکن $turn';
    return Scaffold(backgroundColor:Colors.transparent,appBar:AppBar(title:Text(widget.title),backgroundColor:Colors.transparent,actions:[IconButton(onPressed:newRound,icon:const Icon(Icons.tune_rounded),tooltip:'تغییر حالت')]),floatingActionButton:const FunZoneThemeButton(),
      body:FunZoneBackdrop(child:SafeArea(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
        Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
          Text(statusText,textAlign:TextAlign.center,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
          const SizedBox(height:5),
          Text(online?(botRoom?'آنلاین · حریف ربات':'آنلاین · '+(myMark=='X'?'تو X هستی':'تو O هستی')):mode==_PlayMode.bot?'آفلاین · ربات هوشمند · سطح $difficulty':'آفلاین · دونفره روی یک دستگاه',style:TextStyle(color:scheme.onSurfaceVariant,fontSize:12)),
          if(online&&room!=null)Text('کد بازی: '+room!['id'].toString().substring(0,8),style:TextStyle(color:scheme.onSurfaceVariant,fontSize:11)),
        ]))),
        if(!online)Text('X: $xWins برد  •  O: $oWins برد',style:const TextStyle(fontWeight:FontWeight.w800)),
        const SizedBox(height:10),
        Expanded(child:Center(child:connectFour?connectBoard(b,done,scheme):ticBoard(b,done,scheme))),
        if(online&&roomStatus=='active')Text(botRoom?(version.isEven?'حرکتت را انتخاب کن':'ربات در حال بازی است'):turnUser==uid?'حرکتت را انتخاب کن':'منتظر حرکت حریف باش'),
        if(online&&!botRoom&&roomStatus=='active')OutlinedButton.icon(onPressed:_openRoomChat,icon:const Icon(Icons.forum_rounded),label:const Text('چت بازی و پیام صوتی')),
        if(online&&!botRoom&&roomStatus=='active'&&room!=null)FunGameVoiceCallButton(roomId:room!['id'].toString(),isCaller:uid==playerOne),
        if(_reconnecting)const Text('در حال اتصال دوباره به مسابقه…',style:TextStyle(fontSize:11,color:Colors.orange)),
        if(botRoom&&roomStatus=='active'&&version.isOdd&&!thinking&&!busy)TextButton.icon(onPressed:botTurnOnline,icon:const Icon(Icons.refresh_rounded),label:const Text('تلاش دوباره برای حرکت ربات')),
        if(done)FilledButton.icon(onPressed:newRound,icon:const Icon(Icons.refresh),label:const Text('بازی تازه'))
        else if(!online)OutlinedButton.icon(onPressed:newRound,icon:const Icon(Icons.refresh),label:const Text('شروع دوباره')),
        const SizedBox(height:8),Text(connectFour?'چهار مهره را افقی، عمودی یا مورب ردیف کن.':'سه مهره را در یک خط ردیف کن.',textAlign:TextAlign.center,style:TextStyle(fontSize:12,color:scheme.onSurfaceVariant)),
      ])))));
  }
  Widget picker()=>Scaffold(backgroundColor:Colors.transparent,appBar:AppBar(title:Text(widget.title),backgroundColor:Colors.transparent),floatingActionButton:const FunZoneThemeButton(),body:FunZoneBackdrop(child:ListView(padding:const EdgeInsets.all(18),children:[
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
  ])));
  Widget waiting()=>Scaffold(backgroundColor:Colors.transparent,appBar:AppBar(title:Text(widget.title),backgroundColor:Colors.transparent,leading:IconButton(onPressed:newRound,icon:const Icon(Icons.arrow_back))),floatingActionButton:const FunZoneThemeButton(),body:FunZoneBackdrop(child:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const CircularProgressIndicator(),const SizedBox(height:18),const Text('در حال پیدا کردن حریف آنلاین…',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
    const SizedBox(height:8),const Text('با ورود بازیکن دیگر، بازی خودکار آغاز می‌شود.',textAlign:TextAlign.center),const SizedBox(height:20),
    OutlinedButton.icon(onPressed:()async{await leaveRoom();if(mounted)setState(() { room = null; mode = _PlayMode.bot; resetBoard(); });},icon:const Icon(Icons.smart_toy),label:const Text('منتظر نمان؛ با ربات بازی کن')),
    TextButton(onPressed:newRound,child:const Text('لغو جستجو')),
  ])))));
  Widget ticBoard(List<String>b,bool done,ColorScheme scheme)=>AspectRatio(aspectRatio:1,child:GridView.builder(physics:const NeverScrollableScrollPhysics(),itemCount:9,
    gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,crossAxisSpacing:8,mainAxisSpacing:8),
    itemBuilder:(_,i){final m=b.length>i&&b[i]!='.'?b[i]:'';final can=!busy&&!thinking&&!done&&(!online||(roomStatus=='active'&&turnUser==uid&&(!botRoom||version.isEven)));return Material(color:scheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(18),child:InkWell(borderRadius:BorderRadius.circular(18),onTap:can?()=>play(i):null,child:Center(child:Text(m,style:TextStyle(fontSize:52,fontWeight:FontWeight.w900,color:m=='X'?Colors.teal:Colors.deepOrange)))));}));
  Widget connectBoard(List<String>b,bool done,ColorScheme scheme)=>AspectRatio(aspectRatio:7/6,child:Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:const Color(0xFF2459A6),borderRadius:BorderRadius.circular(18)),child:GridView.builder(physics:const NeverScrollableScrollPhysics(),itemCount:42,
    gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7,crossAxisSpacing:5,mainAxisSpacing:5),
    itemBuilder:(_,i){final v=b.length>i?b[i]:'0';final m=online?(v=='1'?'X':v=='2'?'O':''):v=='0'?'':v;final can=!busy&&!thinking&&!done&&(!online||(roomStatus=='active'&&turnUser==uid&&(!botRoom||version.isEven)));return GestureDetector(onTap:can?()=>play(i):null,child:DecoratedBox(decoration:BoxDecoration(shape:BoxShape.circle,color:m=='X'?const Color(0xFFE64B4B):m=='O'?const Color(0xFFFFD447):const Color(0xFFEAF1FA))));})));
}
