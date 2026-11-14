import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Social lobby entry point embedded in GapResan chat.
class LudoLobbyPage extends StatefulWidget {
  const LudoLobbyPage({super.key, this.conversationId, this.initialInviteToken, this.initialRoomCode});
  final String? conversationId;
  final String? initialInviteToken;
  final String? initialRoomCode;
  @override
  State<LudoLobbyPage> createState() => _LudoLobbyPageState();
}

class _LudoLobbyPageState extends State<LudoLobbyPage> {
  final _db = Supabase.instance.client;
  final _code = TextEditingController();
  Map<String, dynamic>? _room;
  bool _busy = false;
  String? _error;
  int _maxPlayers = 4;
  bool _private = true;
  bool _fillBots = false;
  String _mode = 'standard';
  String? get _uid => _db.auth.currentUser?.id;

  @override
  void initState() { super.initState(); _code.text = widget.initialRoomCode ?? ''; }\n\n  void dispose() { _code.dispose(); super.dispose(); }

  Future<void> _createRoom() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final row = await _db.rpc('create_ludo_room', params: {
        'p_max_players': _maxPlayers,
        'p_is_private': _private,
        'p_game_mode': _mode,
        'p_fill_with_bots': _fillBots,
      }).timeout(const Duration(seconds: 12));
      final created = Map<String, dynamic>.from(row as Map);
      if (widget.conversationId != null) {
        try {
          final members = await _db.from('conversation_members').select('user_id')
            .eq('conversation_id', widget.conversationId!).neq('user_id', _uid ?? '');
          final targets = List<Map<String,dynamic>>.from(members)
            .map((m) => m['user_id'].toString()).toList();
          if (targets.isNotEmpty) {
            await _db.rpc('invite_ludo_players', params: {
              'p_room_id': created['id'], 'p_user_ids': targets,
            });
          }
          final card = '[[GAPRESAN_LUDO_INVITE]]${created['invite_token']}|${created['room_code']}';
          await _db.from('messages').insert({
            'conversation_id': widget.conversationId,
            'sender_id': _uid,
            'body': card,
            'message_type': 'text',
          });
        } catch (inviteError) {
          debugPrint('Ludo chat invite card could not be posted: $inviteError');
        }
      }
      if (!mounted) return;
      setState(() => _room = created);
    } catch (e) { if (mounted) setState(() => _error = _friendly(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _joinWithToken() async {
    final token = widget.initialInviteToken;
    if (token == null || token.isEmpty) return;
    await _run(() async {
      final row = await _db.rpc('join_ludo_room', params: {
        'p_room_code': null, 'p_invite_token': token,
      }).timeout(const Duration(seconds: 12));
      if (mounted) setState(() => _room = Map<String, dynamic>.from(row as Map));
    });
  }

  Future<void> _joinByCode() async {
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'کد اتاق باید ۶ رقم باشد.');
      return;
    }
    await _run(() async {
      final row = await _db.rpc('join_ludo_room', params: {
        'p_room_code': code, 'p_invite_token': null,
      }).timeout(const Duration(seconds: 12));
      if (mounted) setState(() => _room = Map<String, dynamic>.from(row as Map));
    });
  }

  Future<void> _acceptInvite(Map<String, dynamic> invite) async {
    await _run(() async {
      final row = await _db.rpc('join_ludo_room', params: {
        'p_room_code': null, 'p_invite_token': invite['invite_token'],
      }).timeout(const Duration(seconds: 12));
      if (mounted) setState(() => _room = Map<String, dynamic>.from(row as Map));
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try { await action(); }
    catch (e) { if (mounted) setState(() => _error = _friendly(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  String _friendly(Object error) {
    final value = error.toString();
    if (value.contains('ludo_room_expired_or_missing')) return 'اتاق پیدا نشد یا مهلت دعوت تمام شده است.';
    if (value.contains('ludo_invite_required')) return 'این اتاق خصوصی است؛ باید دعوت معتبر داشته باشی.';
    if (value.contains('ludo_room_full')) return 'ظرفیت اتاق تکمیل شده است.';
    if (value.contains('authentication_required')) return 'برای بازی باید وارد حساب شوی.';
    if (value.contains('duplicate key')) return 'این اتاق پر شده؛ یک اتاق دیگر را امتحان کن.';
    return value.replaceFirst('Exception: ', '');
  }

  Future<void> _inviteContacts() async {
    final room = _room;
    if (room == null || _busy) return;
    final profiles = await _db.from('profiles')
      .select('id,display_name,username,avatar_url')
      .neq('id', _uid ?? '')
      .order('display_name').limit(200);
    if (!mounted) return;
    final rows = List<Map<String, dynamic>>.from(profiles);
    final selected = <String>{};
    final ids = await showModalBottomSheet<List<String>>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, refresh) => SafeArea(
        child: SizedBox(height: MediaQuery.of(context).size.height * .75,
          child: Column(children: [
            const Padding(padding: EdgeInsets.all(12), child: Text('دعوت از مخاطبان', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
            Expanded(child: ListView.builder(itemCount: rows.length, itemBuilder: (_, i) {
              final p = rows[i]; final id = p['id'].toString();
              final name = (p['display_name'] ?? p['username'] ?? 'کاربر').toString();
              return CheckboxListTile(
                value: selected.contains(id),
                onChanged: (v) => refresh(() { if (v == true) { selected.add(id); } else { selected.remove(id); } }),
                title: Text(name), subtitle: Text('@${p['username'] ?? ''}'),
                secondary: CircleAvatar(child: Text(name.isEmpty ? '?' : name.characters.first)),
              );
            })),
            Padding(padding: const EdgeInsets.all(14), child: SizedBox(width: double.infinity,
              child: FilledButton.icon(
                onPressed: selected.isEmpty ? null : () => Navigator.pop(sheetContext, selected.toList()),
                icon: const Icon(Icons.send_rounded), label: Text('ارسال دعوت به ${selected.length} نفر'),
              ))),
          ]),
        ),
      )),
    );
    if (ids == null || ids.isEmpty || !mounted) return;
    await _run(() async {
      await _db.rpc('invite_ludo_players', params: {
        'p_room_id': room['id'], 'p_user_ids': ids,
      }).timeout(const Duration(seconds: 12));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('دعوت برای ${ids.length} نفر ثبت شد.')),
      );
    });
  }

  Future<void> _copyInvite() async {
    final room = _room;
    if (room == null) return;
    final code = room['room_code'].toString();
    await Clipboard.setData(ClipboardData(text: 'دعوت منچ گپ‌رسان | کد اتاق: $code'));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کد دعوت کپی شد.')));
  }

  Future<void> _setReady(bool ready) async {
    final room = _room;
    if (room == null) return;
    await _run(() async {
      await _db.rpc('set_ludo_ready', params: {'p_room_id': room['id'], 'p_ready': ready});
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    return Scaffold(
      appBar: AppBar(title: const Text('منچ دوستانه'), centerTitle: true),
      body: room == null ? _buildCreate() : _buildLobby(room),
    );
  }

  Widget _buildCreate() {
    return ListView(padding: const EdgeInsets.all(18), children: [
      Container(height: 150, decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Color(0xff063e48), Color(0xff49206c), Color(0xffd89a20)]),
      ), child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.casino_rounded, color: Colors.white, size: 54),
        SizedBox(height: 8), Text('منچ گپ‌رسان', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
        Text('دوستانت را دعوت کن و دور هم بازی کنید', style: TextStyle(color: Colors.white70)),
      ]))),
      const SizedBox(height: 20),
      const Text('ساخت اتاق جدید', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      const SizedBox(height: 8),
      SegmentedButton<int>(
        segments: const [ButtonSegment(value: 2,label:Text('۲ نفر')),ButtonSegment(value: 3,label:Text('۳ نفر')),ButtonSegment(value: 4,label:Text('۴ نفر'))],
        selected: {_maxPlayers}, onSelectionChanged: (v) => setState(() => _maxPlayers = v.first),
      ),
      const SizedBox(height: 12),
      SegmentedButton<String>(
        segments: const [ButtonSegment(value:'standard',label:Text('کلاسیک')),ButtonSegment(value:'one_piece',label:Text('تک‌مهره · ۵ دقیقه'))],
        selected: {_mode}, onSelectionChanged: (v) => setState(() => _mode = v.first),
      ),
      SwitchListTile(value:_private,onChanged:(v)=>setState(()=>_private=v),title:const Text('اتاق خصوصی'),subtitle:const Text('فقط افراد دعوت‌شده می‌توانند وارد شوند.')),
      SwitchListTile(value:_fillBots,onChanged:(v)=>setState(()=>_fillBots=v),title:const Text('پر کردن جای خالی با ربات'),subtitle:const Text('پس از شروع بازی؛ فعلاً فقط تنظیم لابی است.')),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed:_busy?null:_createRoom,icon:_busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.add_circle_outline),label:const Text('ساخت اتاق و دعوت دوستان')),
      const Divider(height:32),
      if (widget.initialInviteToken != null) ...[
        FilledButton.icon(onPressed:_busy?null:_joinWithToken,icon:const Icon(Icons.login_rounded),label:const Text('پیوستن به اتاق دعوت‌شده')),
        const SizedBox(height:12),
      ],
      const Text('پیوستن با کد اتاق',style:TextStyle(fontWeight:FontWeight.w900)),
      const SizedBox(height:8),
      Row(children:[
        Expanded(child:TextField(controller:_code,keyboardType:TextInputType.number,maxLength:6,decoration:const InputDecoration(labelText:'کد ۶ رقمی',counterText:'',border:OutlineInputBorder()))),
        const SizedBox(width:8),FilledButton(onPressed:_busy?null:_joinByCode,child:const Text('پیوستن')),
      ]),
      const SizedBox(height:14),
      const Text('دعوت‌های دریافتی',style:TextStyle(fontWeight:FontWeight.w900)),
      const SizedBox(height:8),
      FutureBuilder<List<dynamic>>(
        future:_db.rpc('get_my_ludo_invites'),
        builder:(context,snapshot){
          if(snapshot.hasError)return const Text('دعوت‌ها فعلاً بارگذاری نشدند.');
          if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
          final invites=List<Map<String,dynamic>>.from(snapshot.data!);
          if(invites.isEmpty)return const Text('دعوت تازه‌ای نداری.');
          return Column(children:invites.map((i)=>Card(child:ListTile(
            leading:const CircleAvatar(child:Icon(Icons.casino_rounded)),
            title:Text('${i['host_name']} دعوتت کرده'),
            subtitle:Text('کد اتاق ${i['room_code']}'),
            trailing:TextButton(onPressed:_busy?null:()=>_acceptInvite(i),child:const Text('بپیوند')),
          ))).toList());
        },
      ),
      if(_error!=null) Padding(padding:const EdgeInsets.only(top:12),child:Text(_error!,style:const TextStyle(color:Colors.red))),
    ]);
  }

  Widget _buildLobby(Map<String,dynamic> room) {
    final id=room['id'].toString();
    final playersStream=_db.from('ludo_room_players').stream(primaryKey:['room_id','user_id']).eq('room_id',id);
    return StreamBuilder<List<Map<String,dynamic>>>(
      stream:playersStream,
      builder:(context,snapshot){
        final players=(snapshot.data??const <Map<String,dynamic>>[]).toList()..sort((a,b)=>(a['seat'] as num).compareTo(b['seat'] as num));
        return ListView(padding:const EdgeInsets.all(18),children:[
          Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(
            borderRadius:BorderRadius.circular(22),color:Theme.of(context).colorScheme.surfaceContainerHighest,
            border:Border.all(color:Theme.of(context).colorScheme.primary.withValues(alpha:.35))),
            child:Column(children:[
              const Text('کد دعوت اتاق',style:TextStyle(fontWeight:FontWeight.w700)),
              const SizedBox(height:6),
              Text('${room['room_code']}',style:const TextStyle(fontSize:34,fontWeight:FontWeight.w900,letterSpacing:8)),
              Text('مهلت دعوت: ۱۰ دقیقه از زمان ساخت اتاق'),
              const SizedBox(height:10),
              Wrap(spacing:8,children:[
                OutlinedButton.icon(onPressed:_copyInvite,icon:const Icon(Icons.copy_rounded),label:const Text('کپی کد')),
                FilledButton.icon(onPressed:_busy?null:_inviteContacts,icon:const Icon(Icons.person_add_alt_1_rounded),label:const Text('دعوت مخاطبان')),
              ]),
            ]),
          ),
          const SizedBox(height:18),
          Text('بازیکنان ${players.length} از ${room['max_players']}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
          const SizedBox(height:8),
          for(var seat=0;seat<(room['max_players'] as num).toInt();seat++)
            _seatCard(_playerAtSeat(players,seat),seat),
          const SizedBox(height:14),
          OutlinedButton.icon(onPressed:_busy?null:()=>_setReady(true),icon:const Icon(Icons.check_circle_outline),label:const Text('من آماده‌ام')),
          const SizedBox(height:8),
          const Text('وقتی بازیکنان به اتاق بپیوندند، وضعیت آن‌ها در این فهرست زنده به‌روزرسانی می‌شود.',textAlign:TextAlign.center),
          if(snapshot.hasError)const Text('اتصال زنده قطع شده؛ صفحه را دوباره باز کن.',style:TextStyle(color:Colors.orange)),
          if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.red)),
        ]);
      },
    );
  }

  Map<String,dynamic>? _playerAtSeat(List<Map<String,dynamic>> players,int seat) {\n    for(final player in players){if((player['seat'] as num).toInt()==seat)return player;}\n    return null;\n  }\n\n  Widget _seatCard(Map<String,dynamic>? player,int seat) {
    const colors=[Color(0xffe94b61),Color(0xff368be8),Color(0xffefb82f),Color(0xff21a886)];
    final name=player==null?'جای خالی':'بازیکن ${seat+1}';
    return Card(child:ListTile(
      leading:CircleAvatar(backgroundColor:colors[seat],child:Icon(player==null?Icons.person_add_alt_1:Icons.person,color:Colors.white)),
      title:Text(name,style:const TextStyle(fontWeight:FontWeight.w800)),
      subtitle:Text(player==null?'منتظر پیوستن':'${player['is_ready']==true?'آماده':'در لابی'}'),
      trailing:Text(['قرمز','آبی','زرد','سبز'][seat]),
    ));
  }
}
