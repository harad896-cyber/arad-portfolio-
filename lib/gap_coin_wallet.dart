import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'fun_zone_theme.dart';

class GapCoinWalletPage extends StatefulWidget {
  const GapCoinWalletPage({super.key});
  @override State<GapCoinWalletPage> createState() => _GapCoinWalletPageState();
}

class _GapCoinWalletPageState extends State<GapCoinWalletPage> {
  final client = Supabase.instance.client;
  bool loading = true, busy = false;
  String? error;
  int balance = 0;
  List<Map<String, dynamic>> transactions = [];
  Map<String, Map<String, dynamic>> profiles = {};

  @override void initState() { super.initState(); refresh(); }

  Future<void> refresh() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final user = client.auth.currentUser;
      if (user == null) throw StateError('auth');
      final rawWallet = await client.rpc('get_my_coin_wallet').timeout(const Duration(seconds: 15));
      final walletRows = rawWallet as List;
      if (walletRows.isEmpty) throw StateError('wallet_empty');
      final nextBalance = (walletRows.first['balance'] as num).toInt();
      final raw = await client.from('gap_coin_transactions')
        .select('id,transaction_type,from_user_id,to_user_id,amount,description,created_at')
        .or('from_user_id.eq.' + user.id + ',to_user_id.eq.' + user.id)
        .order('created_at', ascending: false).limit(50)
        .timeout(const Duration(seconds: 15));
      final rows = (raw as List).map((e) => Map<String,dynamic>.from(e as Map)).toList();
      final ids = rows.expand((e) => [e['from_user_id'],e['to_user_id']])
        .whereType<String>().where((id) => id != user.id).toSet().toList();
      final profileRows = ids.isEmpty ? <Map<String,dynamic>>[] :
        (await client.from('profiles').select('id,username,display_name,avatar_url').inFilter('id',ids) as List)
          .map((e) => Map<String,dynamic>.from(e as Map)).toList();
      if (!mounted) return;
      setState(() {
        balance = nextBalance; transactions = rows;
        profiles = {for (final p in profileRows) p['id'].toString():p};
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final v = e.toString().toLowerCase();
      setState(() {
        loading = false;
        error = v.contains('gap_coin') || v.contains('get_my_coin_wallet') || v.contains('schema cache')
          ? 'سرویس کیف پول هنوز روی سرور فعال نشده است.'
          : v.contains('auth') ? 'برای استفاده از کیف پول وارد حساب گپ‌رسان شو.'
          : 'بارگذاری کیف پول انجام نشد. اتصال را بررسی و دوباره تلاش کن.';
      });
    }
  }

  Future<void> transfer() async {
    final username = TextEditingController();
    final amount = TextEditingController();
    final form = await showDialog<List<String>>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('انتقال سکه'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: username, textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'نام کاربری گیرنده', hintText: '@username')),
        const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'تعداد سکه')),
        const SizedBox(height: 8),
        const Text('انتقال پس از تأیید سرور انجام می‌شود.', style: TextStyle(fontSize: 11,color: Colors.grey)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(ctx,[
          username.text.trim().replaceFirst(RegExp(r'^@'),''),
          amount.text.trim()
        ]), child: const Text('ادامه')),
      ],
    ));
    username.dispose(); amount.dispose();
    if (form == null || !mounted) return;
    final handle = form[0]; final count = int.tryParse(form[1]);
    if (handle.isEmpty || count == null || count < 1 || count > 100000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نام کاربری یا تعداد سکه معتبر نیست.')));
      return;
    }
    setState(() => busy = true);
    try {
      final recipient = await client.from('profiles').select('id,username,display_name')
        .eq('username',handle).maybeSingle();
      if (recipient == null) throw StateError('recipient_not_found');
      if (recipient['id'] == client.auth.currentUser?.id) throw StateError('invalid_recipient');
      final random = math.Random.secure();
      final requestKey = DateTime.now().microsecondsSinceEpoch.toString() +
        '-' + List.generate(20, (_) => random.nextInt(16).toRadixString(16)).join();
      await client.rpc('transfer_gap_coins',params:{
        'p_to_user_id':recipient['id'],'p_amount':count,'p_request_key':requestKey
      }).timeout(const Duration(seconds:15));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(count.toString() + ' سکه به ' +
          (recipient['display_name'] ?? '@' + handle).toString() + ' فرستاده شد.')));
      await refresh();
    } catch(e) {
      if (!mounted) return;
      final v=e.toString().toLowerCase();
      final msg=v.contains('insufficient_coins')?'موجودی سکه کافی نیست.':
        v.contains('transfer_limit_exceeded')?'به سقف مجاز انتقال روزانه رسیده‌ای.':
        v.contains('recipient_not_found')||v.contains('no rows')?'این نام کاربری پیدا نشد.':
        v.contains('invalid_recipient')?'نمی‌توانی به حساب خودت سکه بفرستی.':
        v.contains('transfer_gap_coins')||v.contains('schema cache')?'انتقال هنوز روی سرور فعال نشده است.':
        'انتقال انجام نشد. دوباره تلاش کن.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(msg)));
    } finally { if(mounted) setState(()=>busy=false); }
  }

  void purchaseInfo() => showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
    title:const Text('خرید سکه'),
    content:const Text('کیف پول و انتقال سکه آماده‌سازی شده است؛ اما دریافت پول تا اتصال پرداخت رسمی فعال نیست. برای نسخه اندروید منتشرشده در Google Play، خرید سکه باید از Google Play Billing انجام و رسید آن در سرور تأیید شود. در این نسخه هیچ پرداختی انجام نمی‌شود.'),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('متوجه شدم'))],
  ));

  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:Colors.transparent,
    appBar:AppBar(title:const Text('کیف پول سکه'),backgroundColor:Colors.transparent,
      actions:[IconButton(onPressed:loading?null:refresh,icon:const Icon(Icons.refresh_rounded))]),
    floatingActionButton:const FunZoneThemeButton(),
    body:FunZoneBackdrop(child:loading?const Center(child:CircularProgressIndicator()):
      error!=null?Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(
        mainAxisSize:MainAxisSize.min,children:[
          const Icon(Icons.account_balance_wallet_rounded,size:54,color:Colors.white70),
          const SizedBox(height:14),
          Text(error!,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,height:1.5)),
          const SizedBox(height:14),
          FilledButton.icon(onPressed:refresh,icon:const Icon(Icons.refresh),label:const Text('تلاش دوباره')),
        ]))):
      RefreshIndicator(onRefresh:refresh,child:ListView(
        physics:const AlwaysScrollableScrollPhysics(),
        padding:const EdgeInsets.fromLTRB(16,12,16,30),children:[
          _walletCard(),const SizedBox(height:14),
          Row(children:[
            Expanded(child:_action(Icons.add_card_rounded,'خرید سکه',purchaseInfo)),
            const SizedBox(width:10),
            Expanded(child:_action(Icons.send_rounded,'انتقال سکه',busy?null:transfer)),
          ]),
          const SizedBox(height:24),
          const Text('تاریخچه تراکنش‌ها',style:TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w900)),
          const SizedBox(height:10),
          if(transactions.isEmpty) Container(padding:const EdgeInsets.all(22),
            decoration:BoxDecoration(color:Colors.white.withValues(alpha:.08),borderRadius:BorderRadius.circular(18)),
            child:const Text('هنوز تراکنشی ثبت نشده است.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white70))),
          for(final tx in transactions) _transactionTile(tx),
          const SizedBox(height:18),
          const Text('سکه‌های گپ‌رسان اعتبار دیجیتالی داخل برنامه‌اند؛ قابل برداشت نقدی نیستند. موجودی فقط با ثبت معتبر سرور تغییر می‌کند.',
            textAlign:TextAlign.center,style:TextStyle(color:Colors.white60,fontSize:11,height:1.5)),
        ]))),
  );

  Widget _walletCard()=>Container(padding:const EdgeInsets.all(20),
    decoration:BoxDecoration(borderRadius:BorderRadius.circular(24),
      gradient:const LinearGradient(colors:[Color(0xFF4C3512),Color(0xFFD6A83D),Color(0xFFFFE7A0)],
        begin:Alignment.topRight,end:Alignment.bottomLeft),
      boxShadow:const [BoxShadow(color:Colors.black38,blurRadius:18,offset:Offset(0,8))]),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Row(children:[Icon(Icons.account_balance_wallet_rounded,color:Color(0xFFFFF2CB)),
        SizedBox(width:8),Text('موجودی کیف پول',style:TextStyle(color:Color(0xFFFFF2CB),fontWeight:FontWeight.w800))]),
      const SizedBox(height:14),
      Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
        Text(balance.toString(),style:const TextStyle(color:Colors.white,fontSize:38,fontWeight:FontWeight.w900)),
        const SizedBox(width:8),
        const Padding(padding:EdgeInsets.only(bottom:7),child:Text('🪙 سکه',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800))),
      ]),
      const SizedBox(height:4),
      const Text('اعتبار اختصاصی حساب گپ‌رسان',style:TextStyle(color:Color(0xFFFFF2CB),fontSize:12)),
    ]));

  Widget _action(IconData icon,String label,VoidCallback? action)=>SizedBox(height:54,
    child:FilledButton.tonalIcon(onPressed:action,icon:Icon(icon),label:Text(label,
      style:const TextStyle(fontWeight:FontWeight.w800)),
      style:FilledButton.styleFrom(backgroundColor:Colors.white.withValues(alpha:.14),foregroundColor:Colors.white)));

  Widget _transactionTile(Map<String,dynamic> tx) {
    final uid=client.auth.currentUser?.id;
    final outgoing=tx['from_user_id']==uid;
    final type=tx['transaction_type']?.toString()??'';
    final otherId=(outgoing?tx['to_user_id']:tx['from_user_id'])?.toString();
    final other=otherId==null?null:profiles[otherId];
    final otherName=other?['display_name']??other?['username']??'کاربر';
    final title=type=='purchase'?'خرید سکه':type=='transfer'?
      (outgoing?'ارسال به ':'دریافت از ')+otherName.toString():
      type=='refund'?'بازپرداخت':type=='game_spend'?'خرید در بازی':'تراکنش';
    final incoming=type=='purchase'||!outgoing;
    final date=DateTime.tryParse(tx['created_at']?.toString()??'')?.toLocal();
    final dateText=date==null?'':date.year.toString()+'/'+date.month.toString().padLeft(2,'0')+'/'+
      date.day.toString().padLeft(2,'0')+'  '+date.hour.toString().padLeft(2,'0')+':'+date.minute.toString().padLeft(2,'0');
    return Container(margin:const EdgeInsets.only(bottom:8),
      decoration:BoxDecoration(color:Colors.white.withValues(alpha:.09),borderRadius:BorderRadius.circular(16)),
      child:ListTile(
        leading:CircleAvatar(backgroundColor:incoming?const Color(0xFF1D8E71):const Color(0xFF9B5D43),
          child:Icon(incoming?Icons.south_west_rounded:Icons.north_east_rounded,color:Colors.white)),
        title:Text(title,maxLines:1,overflow:TextOverflow.ellipsis,
          style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800)),
        subtitle:Text(dateText,style:const TextStyle(color:Colors.white60,fontSize:11)),
        trailing:Text((incoming?'+':'-')+tx['amount'].toString()+' 🪙',
          style:TextStyle(color:incoming?const Color(0xFF8DE0BA):const Color(0xFFFFB7A9),fontWeight:FontWeight.w900)),
      ));
  }
}
