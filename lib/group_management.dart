import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'group_moderation.dart';

class GroupProfilePage extends StatefulWidget {
  final String conversationId;
  final String title;
  const GroupProfilePage({super.key, required this.conversationId, required this.title});
  @override State<GroupProfilePage> createState() => _GroupProfilePageState();
}

class _GroupProfilePageState extends State<GroupProfilePage> {
  final db = Supabase.instance.client;
  Map<String,dynamic>? group;
  List<Map<String,dynamic>> members=[];
  Map<String,Map<String,dynamic>> profiles={};
  bool loading=true, busy=false, isAdmin=false, isOwner=false;

  String nameOf(String id)=>(profiles[id]?['display_name'] ?? profiles[id]?['username'] ?? 'کاربر').toString();
  String avatarOf(String id)=>(profiles[id]?['avatar_url'] ?? '').toString();
  void toast(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}

  Future<void> load() async {
    try {
      final g=Map<String,dynamic>.from(await db.from('conversations').select('id,type,title,avatar_url,description,created_by,username,is_public').eq('id',widget.conversationId).single());
      final ms=List<Map<String,dynamic>>.from(await db.from('conversation_members').select('user_id,role,joined_at').eq('conversation_id',widget.conversationId).order('joined_at'));
      final ids=ms.map((m)=>m['user_id'].toString()).toList();
      final people=ids.isEmpty?<Map<String,dynamic>>[]:List<Map<String,dynamic>>.from(await db.from('profiles').select('id,display_name,username,avatar_url,is_verified').inFilter('id',ids));
      final uid=db.auth.currentUser?.id;
      if(!mounted)return;
      setState((){
        group=g;members=ms;profiles={for(final p in people)p['id'].toString():p};
        isOwner=uid!=null&&'${g['created_by']}'==uid;
        isAdmin=uid!=null&&(isOwner||ms.any((m)=>'${m['user_id']}'==uid&&['admin','owner'].contains(m['role'])));
        loading=false;
      });
    }catch(e){if(mounted){setState(()=>loading=false);toast('پروفایل گروه بارگذاری نشد.');}}
  }

  Future<void> leave() async {
    if(busy)return;
    if(isOwner){toast('مالک گروه نمی‌تواند از گروه خارج شود؛ ابتدا گروه را حذف کنید.');return;}
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('خروج از گروه'),content:const Text('از این گروه خارج می‌شوید و دیگر پیام‌های آن را دریافت نمی‌کنید.'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('خروج'))]))??false;
    if(!ok)return;
    setState(()=>busy=true);
    try{await db.rpc('leave_group',params:{'p_conversation_id':widget.conversationId});if(mounted)Navigator.pop(context,true);}catch(e){toast('خروج از گروه ناموفق بود: $e');}finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> deleteGroup() async {
    if(!isOwner||busy)return;
    final controller=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
      title:const Text('حذف کامل گروه'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[const Text('گروه، اعضا و پیام‌های آن برای همیشه حذف می‌شوند.'),const SizedBox(height:12),TextField(controller:controller,decoration:const InputDecoration(labelText:'برای تأیید بنویسید: حذف گروه'))]),
      actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(d,controller.text.trim()=='حذف گروه'),child:const Text('حذف کامل'))],
    ))??false;
    controller.dispose();
    if(!ok)return;
    setState(()=>busy=true);
    try{await db.rpc('delete_group',params:{'p_conversation_id':widget.conversationId});if(mounted){toast('گروه حذف شد.');Navigator.of(context).pop(true);}}catch(e){toast('حذف گروه ناموفق بود: $e');}finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> openManagement() async {
    final changed=await Navigator.push(context,MaterialPageRoute(builder:(_)=>GroupManagementPage(conversationId:widget.conversationId,title:(group?['title']??widget.title).toString())));
    if(changed==true)load();
  }

  Widget glass(Widget child){final s=Theme.of(context).colorScheme;return ClipRRect(borderRadius:BorderRadius.circular(26),child:BackdropFilter(filter:ImageFilter.blur(sigmaX:18,sigmaY:18),child:Container(decoration:BoxDecoration(color:s.surface.withValues(alpha:.76),borderRadius:BorderRadius.circular(26),border:Border.all(color:s.onSurface.withValues(alpha:.08))),child:child)));}

  @override void initState(){super.initState();load();}
  @override Widget build(BuildContext context){
    if(loading)return Scaffold(appBar:AppBar(title:const Text('پروفایل گروه')),body:const Center(child:CircularProgressIndicator()));
    final g=group!;final title=(g['title']??widget.title).toString();final desc=(g['description']??'').toString().trim();final url=(g['avatar_url']??'').toString();
    return Scaffold(appBar:AppBar(title:const Text('پروفایل گروه')),body:ListView(padding:const EdgeInsets.all(14),children:[
      glass(Padding(padding:const EdgeInsets.fromLTRB(20,24,20,20),child:Column(children:[
        CircleAvatar(radius:52,backgroundImage:url.isNotEmpty?NetworkImage(url):null,child:url.isEmpty?const Icon(Icons.groups_rounded,size:52):null),
        const SizedBox(height:12),Text(title,textAlign:TextAlign.center,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),
        if('${g['username']??''}'.trim().isNotEmpty)Text('@${g['username']}',style:TextStyle(color:Theme.of(context).colorScheme.primary,fontWeight:FontWeight.w800)),
        const SizedBox(height:8),Text(desc.isEmpty?'توضیحاتی برای این گروه ثبت نشده است.':desc,textAlign:TextAlign.center,style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height:16),Row(mainAxisAlignment:MainAxisAlignment.center,children:[_stat(Icons.groups_rounded,'${members.length}','عضو'),const SizedBox(width:22),_stat(Icons.verified_user_rounded,isOwner?'مالک':'مدیر',isOwner?'دسترسی کامل':'دسترسی مدیریتی')]),
      ]))),
      const SizedBox(height:12),
      glass(Column(children:[
        ListTile(leading:CircleAvatar(child:Icon(Icons.people_rounded)),title:const Text('اعضای گروه',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${members.length} عضو'),trailing:const Icon(Icons.chevron_left_rounded),onTap:()=>showModalBottomSheet<void>(context:context,showDragHandle:true,builder:(_)=>ListView(padding:const EdgeInsets.all(14),children:[const Text('اعضای گروه',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:8),...members.map((m){final id=m['user_id'].toString();final u=group?['created_by'].toString()==id;final a=avatarOf(id);return ListTile(leading:CircleAvatar(backgroundImage:a.isNotEmpty?NetworkImage(a):null,child:a.isEmpty?const Icon(Icons.person):null),title:Text(nameOf(id)),subtitle:Text(u?'👑 مالک':(m['role']??'عضو').toString()));})]))),
        const Divider(height:1),
        if(isAdmin)ListTile(leading:const Icon(Icons.admin_panel_settings_rounded),title:const Text('مدیریت اعضا و محرومیت',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('حذف از گروه، محروم کردن، رفع محرومیت و حذف پیام'),trailing:const Icon(Icons.chevron_left_rounded),onTap:openManagement),
        if(isAdmin)const Divider(height:1),
        ListTile(leading:const Icon(Icons.logout_rounded),title:Text(isOwner?'حذف گروه':'خروج از گروه',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(isOwner?'حذف دائمی گروه و محتوای آن':'خروج از این گروه'),onTap:isOwner?deleteGroup:leave),
      ])),
      const SizedBox(height:14),
      if(busy)const Center(child:Padding(padding:EdgeInsets.all(8),child:CircularProgressIndicator())),
    ]));
  }
  Widget _stat(IconData icon,String value,String label)=>Column(children:[Icon(icon,color:Theme.of(context).colorScheme.primary),const SizedBox(height:3),Text(value,style:const TextStyle(fontWeight:FontWeight.w900)),Text(label,style:const TextStyle(fontSize:11))]);
}

class GroupManagementPage extends StatefulWidget {
  final String conversationId;
  final String title;
  const GroupManagementPage({super.key,required this.conversationId,required this.title});
  @override State<GroupManagementPage> createState()=>_GroupManagementPageState();
}

class _GroupManagementPageState extends State<GroupManagementPage>{
  final db=Supabase.instance.client;
  Map<String,dynamic>? group;
  List<Map<String,dynamic>> members=[];
  Map<String,Map<String,dynamic>> profiles={};
  bool loading=true,busy=false,isAdmin=false,isOwner=false;

  String nameOf(String id)=>(profiles[id]?['display_name']??profiles[id]?['username']??'کاربر').toString();
  String avatarOf(String id)=>(profiles[id]?['avatar_url']??'').toString();
  void toast(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}

  Future<void> load() async {
    try{
      final g=Map<String,dynamic>.from(await db.from('conversations').select('id,type,title,avatar_url,description,created_by,allow_reactions,is_public,username,auto_delete_seconds,join_approval,only_admins_can_post,only_admins_can_add').eq('id',widget.conversationId).single());
      final rows=List<Map<String,dynamic>>.from(await db.from('conversation_members').select('conversation_id,user_id,role,joined_at').eq('conversation_id',widget.conversationId).order('joined_at'));
      final ids=rows.map((e)=>e['user_id'].toString()).toList();
      final people=ids.isEmpty?<Map<String,dynamic>>[]:List<Map<String,dynamic>>.from(await db.from('profiles').select('id,display_name,username,avatar_url,is_verified').inFilter('id',ids));
      final uid=db.auth.currentUser?.id;
      if(!mounted)return;
      setState(()=>{group=g,members=rows,profiles={for(final p in people)p['id'].toString():p},isOwner=uid!=null&&'${g['created_by']}'==uid,isAdmin=uid!=null&&('${g['created_by']}'==uid||rows.any((m)=>'${m['user_id']}'==uid&&['admin','owner'].contains(m['role']))),loading=false});
    }catch(e){if(mounted){setState(()=>loading=false);toast('بارگذاری مدیریت گروه ناموفق بود.');}}
  }

  Future<void> updateSettings({String? title,String? description,bool? publicGroup,bool? approval,bool? adminsPost,bool? adminsAdd,bool? reactions}) async {
    if(!isAdmin||group==null||busy)return;setState(()=>busy=true);final g=group!;
    try{await db.rpc('update_group_settings',params:{'p_conversation_id':widget.conversationId,'p_title':title??g['title'],'p_description':description??g['description'],'p_avatar_url':g['avatar_url'],'p_is_public':publicGroup??g['is_public']??false,'p_username':g['username'],'p_join_approval':approval??g['join_approval']??false,'p_only_admins_can_post':adminsPost??g['only_admins_can_post']??false,'p_only_admins_can_add':adminsAdd??g['only_admins_can_add']??false,'p_auto_delete_seconds':g['auto_delete_seconds']??0,'p_allow_reactions':reactions??g['allow_reactions']??true});await load();}catch(e){toast('تنظیمات ذخیره نشد: $e');}finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> editGroup() async {
    if(!isAdmin||group==null)return;final title=TextEditingController(text:(group!['title']??widget.title).toString());final desc=TextEditingController(text:(group!['description']??'').toString());
    await showDialog<void>(context:context,builder:(d)=>AlertDialog(title:const Text('ویرایش پروفایل گروه'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'نام گروه')),const SizedBox(height:10),TextField(controller:desc,maxLines:3,decoration:const InputDecoration(labelText:'توضیحات گروه'))]),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('لغو')),FilledButton(onPressed:(){Navigator.pop(d);updateSettings(title:title.text.trim(),description:desc.text.trim());},child:const Text('ذخیره'))]));
    title.dispose();desc.dispose();
  }

  Future<void> removeMember(String id) async {if(!isAdmin||busy||id==group?['created_by'].toString())return;setState(()=>busy=true);try{await db.rpc('remove_group_member',params:{'p_conversationId':widget.conversationId,'p_user_id':id});toast('عضو از گروه حذف شد.');await load();}catch(e){toast('حذف عضو ناموفق بود: $e');}finally{if(mounted)setState(()=>busy=false);}}

  Future<void> banMember(String id) async {
    if(!isAdmin||busy||id==group?['created_by'].toString())return;final reason=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:Text('محروم کردن ${nameOf(id)}'),content:TextField(controller:reason,maxLines:3,decoration:const InputDecoration(labelText:'دلیل (اختیاری)')),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('محروم و حذف شود'))]))??false;
    final r=reason.text.trim();reason.dispose();if(!ok)return;setState(()=>busy=true);try{await db.rpc('ban_group_member',params:{'p_conversation_id':widget.conversationId,'p_user_id':id,'p_reason':r.isEmpty?null:r});toast('عضو محروم و از گروه حذف شد.');await load();}catch(e){toast('محروم کردن ناموفق بود: $e');}finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> changeRole(String id,String role) async {if(!isAdmin||busy)return;setState(()=>busy=true);try{await db.rpc('set_group_member_role',params:{'p_conversation_id':widget.conversationId,'p_user_id':id,'p_role':role});toast(role=='admin'?'عضو مدیر شد.':'مدیریت عضو برداشته شد.');await load();}catch(e){toast('تغییر نقش ناموفق بود: $e');}finally{if(mounted)setState(()=>busy=false);}}

  @override void initState(){super.initState();load();}
  @override Widget build(BuildContext context){
    if(loading)return Scaffold(appBar:AppBar(title:const Text('مدیریت گروه')),body:const Center(child:CircularProgressIndicator()));
    if(group==null||group!['type']!='group')return Scaffold(appBar:AppBar(title:Text(widget.title)),body:const Center(child:Text('این گفتگو گروه نیست.')));
    final title=(group!['title']??widget.title).toString();
    return Scaffold(appBar:AppBar(title:const Text('مدیریت گروه'),actions:[IconButton(onPressed:busy?null:editGroup,tooltip:'ویرایش پروفایل',icon:const Icon(Icons.edit_rounded))]),body:RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(14),children:[
      Card(child:ListTile(leading:CircleAvatar(backgroundColor:Theme.of(context).colorScheme.primaryContainer,child:Icon(Icons.groups_rounded,color:Theme.of(context).colorScheme.primary)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('${members.length} عضو'),trailing:IconButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>GroupProfilePage(conversationId:widget.conversationId,title:title)).then((_)=>load())),icon:const Icon(Icons.chevron_left_rounded)))),
      const SizedBox(height:10),
      Card(child:Column(children:[
        ListTile(leading:const Icon(Icons.manage_accounts_rounded),title:const Text('مدیریت اعضا',style:TextStyle(fontWeight:FontWeight.w900)),subtitle:const Text('حذف از گروه و محروم کردن را جداگانه انتخاب کنید.')),
        const Divider(height:1),
        ...members.map((m){final id=m['user_id'].toString();final owner=id==group!['created_by'].toString();final role=(m['role']??'member').toString();final mine=id==db.auth.currentUser?.id;final a=avatarOf(id);if(owner)return ListTile(leading:CircleAvatar(backgroundImage:a.isNotEmpty?NetworkImage(a):null,child:a.isEmpty?const Icon(Icons.person):null),title:Text(nameOf(id)),subtitle:const Text('👑 مالک گروه'),trailing:const Chip(label:Text('مالک')));return ListTile(leading:CircleAvatar(backgroundImage:a.isNotEmpty?NetworkImage(a):null,child:a.isEmpty?const Icon(Icons.person):null),title:Text(nameOf(id)),subtitle:Text(role=='admin'?'🛡️ مدیر':'عضو'),trailing:mine?const Chip(label:Text('شما')):PopupMenuButton<String>(onSelected:(v){if(v=='remove')removeMember(id);else if(v=='ban')banMember(id);else changeRole(id,v);},itemBuilder:(_)=>[PopupMenuItem(value:role=='admin'?'member':'admin',child:Text(role=='admin'?'برداشتن مدیریت':'ارتقا به مدیر')),const PopupMenuDivider(),const PopupMenuItem(value:'remove',child:Text('حذف از گروه')),const PopupMenuItem(value:'ban',child:Text('محروم کردن'))]));}),
      ])),
      const SizedBox(height:10),
      Card(child:Column(children:[
        const ListTile(leading:Icon(Icons.tune_rounded),title:Text('تنظیمات گروه',style:TextStyle(fontWeight:FontWeight.w900))),
        SwitchListTile(title:const Text('گروه عمومی'),value:group!['is_public']==true,onChanged:busy?null:(v)=>updateSettings(publicGroup:v)),
        SwitchListTile(title:const Text('تأیید عضویت'),value:group!['join_approval']==true,onChanged:busy?null:(v)=>updateSettings(approval:v)),
        SwitchListTile(title:const Text('فقط مدیران پیام بفرستند'),value:group!['only_admins_can_post']==true,onChanged:busy?null:(v)=>updateSettings(adminsPost:v)),
        SwitchListTile(title:const Text('فقط مدیران عضو اضافه کنند'),value:group!['only_admins_can_add']==true,onChanged:busy?null:(v)=>updateSettings(adminsAdd:v)),
        SwitchListTile(title:const Text('واکنش به پیام‌ها'),value:group!['allow_reactions']!=false,onChanged:busy?null:(v)=>updateSettings(reactions:v)),
      ])),
      const SizedBox(height:10),
      Card(child:ListTile(leading:const Icon(Icons.shield_rounded),title:const Text('محرومیت و حذف پیام',style:TextStyle(fontWeight:FontWeight.w900)),subtitle:const Text('صفحه کامل مدیریت برای محروم‌شده‌ها و حذف پیام برای همه'),trailing:const Icon(Icons.chevron_left_rounded),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>GroupModerationPage(conversationId:widget.conversationId,title:title)).then((_)=>load())))),
      if(isOwner) ...[const SizedBox(height:10),Card(child:ListTile(leading:Icon(Icons.delete_forever_rounded,color:Theme.of(context).colorScheme.error),title:Text('حذف کامل گروه',style:TextStyle(fontWeight:FontWeight.w900,color:Theme.of(context).colorScheme.error)),subtitle:const Text('گروه و محتوای آن برای همیشه حذف می‌شود.'),onTap:deleteGroup))],
    ])));
  }

  Future<void> deleteGroup() async {
    if(!isOwner||busy)return;
    final c=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('حذف کامل گروه'),content:Column(mainAxisSize:MainAxisSize.min,children:[const Text('این عملیات قابل برگشت نیست.'),const SizedBox(height:10),TextField(controller:c,decoration:const InputDecoration(labelText:'بنویسید: حذف گروه'))]),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('انصراف')),FilledButton(onPressed:()=>Navigator.pop(d,c.text.trim()=='حذف گروه'),child:const Text('حذف کامل'))]))??false;c.dispose();if(!ok)return;setState(()=>busy=true);try{await db.rpc('delete_group',params:{'p_conversation_id':widget.conversationId});if(mounted)Navigator.of(context).pop(true);}catch(e){toast('حذف گروه ناموفق بود: $e');}finally{if(mounted)setState(()=>busy=false);}
  }
}
