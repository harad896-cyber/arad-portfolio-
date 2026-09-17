import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupAdvancedAdminPage extends StatefulWidget {
  final String conversationId; final String title;
  const GroupAdvancedAdminPage({super.key,required this.conversationId,required this.title});
  @override State<GroupAdvancedAdminPage> createState()=>_GroupAdvancedAdminPageState();
}
class _GroupAdvancedAdminPageState extends State<GroupAdvancedAdminPage>{
  final db=Supabase.instance.client; bool loading=true,busy=false;
  List<Map<String,dynamic>> requests=[],banned=[],pinned=[],messages=[];
  Map<String,Map<String,dynamic>> profiles={};
  String nameOf(String id)=>(profiles[id]?['display_name']??profiles[id]?['username']??'کاربر').toString();
  String avatarOf(String id)=>(profiles[id]?['avatar_url']??'').toString();
  void toast(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
  Future<void> load()async{
    try{
      final rs=List<Map<String,dynamic>>.from(await db.from('group_join_requests').select('id,user_id,created_at,status').eq('conversation_id',widget.conversationId).eq('status','pending').order('created_at',ascending:false));
      final bs=List<Map<String,dynamic>>.from(await db.from('group_banned_members').select('user_id,reason,created_at').eq('conversation_id',widget.conversationId).order('created_at',ascending:false));
      final ps=List<Map<String,dynamic>>.from(await db.from('group_pinned_messages').select('message_id,pinned_by,pinned_at').eq('conversation_id',widget.conversationId).order('pinned_at',ascending:false));
      final ms=List<Map<String,dynamic>>.from(await db.from('messages').select('id,sender_id,body,message_type,created_at').eq('conversation_id',widget.conversationId).order('created_at',ascending:false).limit(60));
      final ids=<String>{...rs.map((x)=>x['user_id'].toString()),...bs.map((x)=>x['user_id'].toString()),...ms.map((x)=>x['sender_id'].toString())};
      final prof=ids.isEmpty?<Map<String,dynamic>>[]:List<Map<String,dynamic>>.from(await db.from('profiles').select('id,display_name,username,avatar_url,is_verified').inFilter('id',ids.toList()));
      if(!mounted)return; setState(() { requests=rs; banned=bs; pinned=ps; messages=ms; profiles={for(final p in prof)p['id'].toString():p}; loading=false; });
    }catch(e){if(mounted){setState(()=>loading=false);toast('مدیریت پیشرفته بارگذاری نشد: $e');}}
  }
  Future<void> review(String id,bool approve)async{if(busy)return;setState(()=>busy=true);try{await db.rpc('review_group_join_request',params:{'p_request_id':id,'p_approve':approve});toast(approve?'درخواست پذیرفته شد.':'درخواست رد شد.');await load();}catch(e){toast('عملیات ناموفق بود: $e');}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> unban(String id)async{if(busy)return;setState(()=>busy=true);try{await db.rpc('unban_group_member',params:{'p_conversation_id':widget.conversationId,'p_user_id':id});toast('محرومیت برداشته شد.');await load();}catch(e){toast('رفع محرومیت ناموفق بود: $e');}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> restrict(String id)async{
    final form=await showDialog<Map<String,bool>>(context:context,builder:(d){bool msg=true,media=true,links=true;return StatefulBuilder(builder:(d,setD)=>AlertDialog(title:Text('محدودیت '+nameOf(id)),content:Column(mainAxisSize:MainAxisSize.min,children:[
      SwitchListTile(title:const Text('ارسال پیام'),value:msg,onChanged:(v)=>setD(()=>msg=v)),SwitchListTile(title:const Text('ارسال رسانه'),value:media,onChanged:(v)=>setD(()=>media=v)),SwitchListTile(title:const Text('ارسال لینک'),value:links,onChanged:(v)=>setD(()=>links=v))]),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(d,{'msg':msg,'media':media,'links':links}),child:const Text('اعمال'))]));});
    if(form==null)return;try{await db.rpc('restrict_group_member',params:{'p_conversation_id':widget.conversationId,'p_user_id':id,'p_can_send_messages':form['msg'] ?? true,'p_can_send_media':form['media'] ?? true,'p_can_send_links':form['links'] ?? true,'p_expires_at':null});toast('محدودیت اعمال شد.');}catch(e){toast('اعمال محدودیت ناموفق بود: $e');}
  }
  Future<void> pin(String id)async{try{await db.rpc('pin_group_message',params:{'p_conversation_id':widget.conversationId,'p_message_id':id});toast('پیام سنجاق شد.');await load();}catch(e){toast('سنجاق کردن ناموفق بود: $e');}}
  Future<void> unpin(String id)async{try{await db.rpc('unpin_group_message',params:{'p_conversation_id':widget.conversationId,'p_message_id':id});toast('سنجاق برداشته شد.');await load();}catch(e){toast('برداشتن سنجاق ناموفق بود: $e');}}
  Future<void> permissions(String id)async{
    final raw=await db.from('group_admin_permissions').select().eq('conversation_id',widget.conversationId).eq('user_id',id).maybeSingle();
    final current=Map<String,dynamic>.from(raw??{});bool add=current['can_add_members']??true,remove=current['can_remove_members']??false,del=current['can_delete_messages']??false,edit=current['can_edit_group']??false,pinx=current['can_pin_messages']??false;
    final ok=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(title:Text('اختیارات '+nameOf(id)),content:Column(mainAxisSize:MainAxisSize.min,children:[
      SwitchListTile(title:const Text('افزودن عضو'),value:add,onChanged:(v)=>setD(()=>add=v)),SwitchListTile(title:const Text('حذف عضو'),value:remove,onChanged:(v)=>setD(()=>remove=v)),SwitchListTile(title:const Text('حذف پیام‌ها'),value:del,onChanged:(v)=>setD(()=>del=v)),SwitchListTile(title:const Text('ویرایش گروه'),value:edit,onChanged:(v)=>setD(()=>edit=v)),SwitchListTile(title:const Text('سنجاق پیام'),value:pinx,onChanged:(v)=>setD(()=>pinx=v))]),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('ذخیره'))])));
    if(ok!=true)return;try{await db.rpc('set_group_admin_permissions',params:{'p_conversation_id':widget.conversationId,'p_user_id':id,'p_can_add_members':add,'p_can_remove_members':remove,'p_can_delete_messages':del,'p_can_edit_group':edit,'p_can_pin_messages':pinx});toast('اختیارات مدیر ذخیره شد.');}catch(e){toast('ذخیره اختیارات ناموفق بود: $e');}
  }
  @override void initState(){super.initState();load();}
  @override Widget build(BuildContext context){
    if(loading)return Scaffold(appBar:AppBar(title:const Text('مدیریت پیشرفته')),body:const Center(child:CircularProgressIndicator()));
    final pinnedIds=pinned.map((p)=>p['message_id'].toString()).toSet();
    return Scaffold(appBar:AppBar(title:const Text('مدیریت پیشرفته')),body:ListView(padding:const EdgeInsets.all(12),children:[
      Card(child:ListTile(leading:const Icon(Icons.how_to_reg_rounded),title:const Text('درخواست‌های عضویت',style:TextStyle(fontWeight:FontWeight.w900)),subtitle:Text(requests.length.toString()+' درخواست در انتظار بررسی'))),
      ...requests.map((r){final id=r['user_id'].toString();final a=avatarOf(id);return Card(child:ListTile(leading:CircleAvatar(backgroundImage:a.isNotEmpty?NetworkImage(a):null,child:a.isEmpty?const Icon(Icons.person):null),title:Text(nameOf(id)),subtitle:const Text('درخواست عضویت'),trailing:Wrap(children:[IconButton(onPressed:busy?null:()=>review(r['id'].toString(),false),icon:const Icon(Icons.close_rounded)),IconButton(onPressed:busy?null:()=>review(r['id'].toString(),true),icon:const Icon(Icons.check_rounded))])));}),
      const SizedBox(height:8),
      Card(child:ListTile(leading:const Icon(Icons.block_rounded),title:const Text('محروم‌شده‌ها',style:TextStyle(fontWeight:FontWeight.w900)),subtitle:Text(banned.length.toString()+' نفر'))),
      ...banned.map((b){final id=b['user_id'].toString();final a=avatarOf(id);return Card(child:ListTile(leading:CircleAvatar(backgroundImage:a.isNotEmpty?NetworkImage(a):null,child:a.isEmpty?const Icon(Icons.person):null),title:Text(nameOf(id)),subtitle:Text((b['reason']??'بدون دلیل').toString()),trailing:Wrap(children:[IconButton(onPressed:busy?null:()=>unban(id),icon:const Icon(Icons.lock_open_rounded)),IconButton(onPressed:busy?null:()=>restrict(id),icon:const Icon(Icons.tune_rounded))])));}),
      const SizedBox(height:8),
      Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('سنجاق پیام‌ها',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),const SizedBox(height:4),
        if(pinned.isEmpty)const Text('هنوز پیامی سنجاق نشده است.'),
        ...pinned.map((p){final id=p['message_id'].toString();final m=messages.firstWhere((x)=>x['id'].toString()==id,orElse:()=>{});return ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.push_pin_rounded),title:Text((m['body']??'پیام رسانه‌ای').toString(),maxLines:2,overflow:TextOverflow.ellipsis),subtitle:Text(nameOf((m['sender_id']??'').toString())),trailing:IconButton(onPressed:()=>unpin(id),icon:const Icon(Icons.close_rounded)));}),
        const Divider(),const Text('آخرین پیام‌ها برای سنجاق',style:TextStyle(fontWeight:FontWeight.w700)),
        ...messages.where((m)=>!pinnedIds.contains(m['id'].toString())).take(12).map((m)=>ListTile(contentPadding:EdgeInsets.zero,title:Text((m['body']??'پیام رسانه‌ای').toString(),maxLines:1,overflow:TextOverflow.ellipsis),subtitle:Text(nameOf(m['sender_id'].toString())),trailing:IconButton(onPressed:()=>pin(m['id'].toString()),icon:const Icon(Icons.push_pin_outlined)))),
      ]))),
    ]));
  }
}
