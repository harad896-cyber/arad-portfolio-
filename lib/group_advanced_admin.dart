import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'polish_widgets.dart';

class GroupAdvancedAdminPage extends StatefulWidget {
  final String conversationId; final String title;
  const GroupAdvancedAdminPage({super.key,required this.conversationId,required this.title});
  @override State<GroupAdvancedAdminPage> createState()=>_GroupAdvancedAdminPageState();
}
class _GroupAdvancedAdminPageState extends State<GroupAdvancedAdminPage>{
  final db=Supabase.instance.client; bool loading=true,busy=false,owner=false;
  List<Map<String,dynamic>> requests=[],banned=[],pinned=[],messages=[],admins=[];
  Map<String,Map<String,dynamic>> profiles={};
  String nameOf(String id)=>(profiles[id]?['display_name']??profiles[id]?['username']??'کاربر').toString();
  String avatarOf(String id)=>(profiles[id]?['avatar_url']??'').toString();
  void toast(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
  Future<void> load()async{
    try{
      final group=Map<String,dynamic>.from(await db.from('conversations').select('created_by,type').eq('id',widget.conversationId).single());
      final isOwner=db.auth.currentUser?.id!=null && group['created_by']?.toString()==db.auth.currentUser!.id && group['type']=='group';
      if(!isOwner){if(mounted)setState(() { owner=false; loading=false; });return;}
      final rs=List<Map<String,dynamic>>.from(await db.from('group_join_requests').select('id,user_id,created_at,status').eq('conversation_id',widget.conversationId).eq('status','pending').order('created_at',ascending:false));
      final adminRows=List<Map<String,dynamic>>.from(await db.from('conversation_members').select('user_id,role').eq('conversation_id',widget.conversationId).eq('role','admin').order('joined_at'));
      final bs=List<Map<String,dynamic>>.from(await db.from('group_banned_members').select('user_id,reason,created_at').eq('conversation_id',widget.conversationId).order('created_at',ascending:false));
      final ps=List<Map<String,dynamic>>.from(await db.from('group_pinned_messages').select('message_id,pinned_by,pinned_at').eq('conversation_id',widget.conversationId).order('pinned_at',ascending:false));
      final ms=List<Map<String,dynamic>>.from(await db.from('messages').select('id,sender_id,body,message_type,created_at').eq('conversation_id',widget.conversationId).order('created_at',ascending:false).limit(60));
      final ids=<String>{...rs.map((x)=>x['user_id'].toString()),...adminRows.map((x)=>x['user_id'].toString()),...bs.map((x)=>x['user_id'].toString()),...ms.map((x)=>x['sender_id'].toString())};
      final prof=ids.isEmpty?<Map<String,dynamic>>[]:List<Map<String,dynamic>>.from(await db.from('profiles').select('id,display_name,username,avatar_url,is_verified').inFilter('id',ids.toList()));
      if(!mounted)return; setState(() { owner=true; requests=rs; admins=adminRows; banned=bs; pinned=ps; messages=ms; profiles={for(final p in prof)p['id'].toString():p}; loading=false; });
    }catch(e){if(mounted){setState(()=>loading=false);toast('مدیریت پیشرفته بارگذاری نشد: $e');}}
  }
  Future<void> review(String id,bool approve)async{if(!owner||busy)return;setState(()=>busy=true);try{await db.rpc('review_group_join_request',params:{'p_request_id':id,'p_approve':approve});toast(approve?'درخواست پذیرفته شد.':'درخواست رد شد.');await load();}catch(e){toast('عملیات ناموفق بود: $e');}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> unban(String id)async{if(!owner||busy)return;setState(()=>busy=true);try{await db.rpc('unban_group_member',params:{'p_conversation_id':widget.conversationId,'p_user_id':id});toast('محرومیت برداشته شد.');await load();}catch(e){toast('رفع محرومیت ناموفق بود: $e');}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> restrict(String id)async{
    if(!owner||busy)return;
    final form=await showDialog<Map<String,dynamic>>(context:context,builder:(d){
      bool msg=true,media=true,links=true;int duration=0;
      return StatefulBuilder(builder:(d,setD)=>AlertDialog(
        title:Text('محدودیت '+nameOf(id)),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('ارسال پیام'),value:msg,onChanged:(v)=>setD(()=>msg=v)),
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('ارسال رسانه و فایل'),value:media,onChanged:(v)=>setD(()=>media=v)),
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('ارسال لینک'),value:links,onChanged:(v)=>setD(()=>links=v)),
          const SizedBox(height:8),
          DropdownButtonFormField<int>(
            value:duration,
            decoration:const InputDecoration(labelText:'مدت محدودیت',border:OutlineInputBorder()),
            items:const [
              DropdownMenuItem(value:0,child:Text('دائمی تا لغو مدیر')),
              DropdownMenuItem(value:3600,child:Text('۱ ساعت')),
              DropdownMenuItem(value:86400,child:Text('۲۴ ساعت')),
              DropdownMenuItem(value:604800,child:Text('۷ روز')),
            ],
            onChanged:(v)=>setD(()=>duration=v??0),
          ),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(d),child:const Text('لغو')),
          FilledButton(onPressed:()=>Navigator.pop(d,{'msg':msg,'media':media,'links':links,'duration':duration}),child:const Text('اعمال محدودیت')),
        ],
      ));
    });
    if(form==null)return;
    setState(()=>busy=true);
    try{
      final seconds=(form['duration'] as num?)?.toInt()??0;
      final expires=seconds==0?null:DateTime.now().toUtc().add(Duration(seconds:seconds)).toIso8601String();
      await db.rpc('restrict_group_member',params:{
        'p_conversation_id':widget.conversationId,
        'p_user_id':id,
        'p_can_send_messages':form['msg']??true,
        'p_can_send_media':form['media']??true,
        'p_can_send_links':form['links']??true,
        'p_expires_at':expires,
      });
      toast(seconds==0?'محدودیت دائمی اعمال شد.':'محدودیت موقت اعمال شد.');
      await load();
    }catch(e){toast('اعمال محدودیت ناموفق بود: $e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> pin(String id) async {
    if (!owner || busy) return;
    setState(() => busy = true);
    try {
      await db.rpc('pin_group_message', params: {
        'p_conversation_id': widget.conversationId,
        'p_message_id': id,
      });
      toast('پیام سنجاق شد.');
      await load();
    } catch (e) {
      toast('سنجاق کردن ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> unpin(String id) async {
    if (!owner || busy) return;
    setState(() => busy = true);
    try {
      await db.rpc('unpin_group_message', params: {
        'p_conversation_id': widget.conversationId,
        'p_message_id': id,
      });
      toast('سنجاق برداشته شد.');
      await load();
    } catch (e) {
      toast('برداشتن سنجاق ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  Future<void> permissions(String id)async{
    if(!owner||busy)return;
    try {
      final raw=await db.from('group_admin_permissions').select().eq('conversation_id',widget.conversationId).eq('user_id',id).maybeSingle();
      final current=Map<String,dynamic>.from(raw??{});
      bool add=current['can_add_members']??true,remove=current['can_remove_members']??false,del=current['can_delete_messages']??false,edit=current['can_edit_group']??false,pinx=current['can_pin_messages']??false;
      final ok=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
        title:Text('اختیارات '+nameOf(id)),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          const Text('فقط دسترسی‌های لازم را فعال کنید. مالک گروه همیشه اختیار کامل دارد.'),
          const SizedBox(height:8),
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('افزودن عضو'),subtitle:const Text('دعوت یا افزودن کاربران به گروه'),value:add,onChanged:(v)=>setD(()=>add=v)),
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('حذف عضو'),subtitle:const Text('اخراج اعضا از گروه'),value:remove,onChanged:(v)=>setD(()=>remove=v)),
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('حذف پیام‌ها'),subtitle:const Text('مدیریت و حذف پیام‌های گروه'),value:del,onChanged:(v)=>setD(()=>del=v)),
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('ویرایش گروه'),subtitle:const Text('تغییر نام، توضیحات، عکس و تنظیمات'),value:edit,onChanged:(v)=>setD(()=>edit=v)),
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('سنجاق پیام'),subtitle:const Text('سنجاق یا برداشتن سنجاق پیام‌ها'),value:pinx,onChanged:(v)=>setD(()=>pinx=v)),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('لغو')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('ذخیره اختیارات'))])));
      if(ok!=true)return;
      setState(()=>busy=true);
      await db.rpc('set_group_admin_permissions',params:{'p_conversation_id':widget.conversationId,'p_user_id':id,'p_can_add_members':add,'p_can_remove_members':remove,'p_can_delete_messages':del,'p_can_edit_group':edit,'p_can_pin_messages':pinx});
      toast('اختیارات مدیر ذخیره شد.');
    }catch(e){toast('خواندن یا ذخیره اختیارات ناموفق بود: $e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override void initState(){super.initState();load();}
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('مدیریت پیشرفته')),
        body: const AppSkeletonList(count: 6),
      );
    }
    if (!owner) {
      return Scaffold(
        appBar: AppBar(title: const Text('مدیریت پیشرفته')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 48),
                const SizedBox(height: 12),
                const Text('این بخش فقط برای مالک گروه قابل دسترسی است.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('بررسی دوباره'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pinnedIds = pinned.map((p) => p['message_id'].toString()).toSet();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت پیشرفته'),
        actions: [
          IconButton(
            tooltip: 'تازه‌سازی',
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مدیران و اختیارات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    'اختیارات هر مدیر را جداگانه تنظیم کنید.',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (admins.isEmpty)
                    const ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.admin_panel_settings_outlined),
                      title: Text('مدیر دیگری تعیین نشده است'),
                    ),
                  ...admins.map((m) {
                    final id = m['user_id'].toString();
                    final a = avatarOf(id);
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 19,
                        backgroundImage: a.isNotEmpty ? NetworkImage(a) : null,
                        child: a.isEmpty ? const Icon(Icons.person, size: 19) : null,
                      ),
                      title: Text(nameOf(id), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: const Text('مدیر گروه'),
                      trailing: IconButton(
                        tooltip: 'تنظیم اختیارات',
                        onPressed: busy ? null : () => permissions(id),
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              leading: const Icon(Icons.how_to_reg_rounded),
              title: const Text('درخواست‌های عضویت', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${requests.length} درخواست در انتظار بررسی'),
              children: requests.isEmpty
                  ? [const ListTile(dense: true, title: Text('درخواستی برای بررسی وجود ندارد.'))]
                  : requests.map((r) {
                      final id = r['user_id'].toString();
                      final a = avatarOf(id);
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 19,
                          backgroundImage: a.isNotEmpty ? NetworkImage(a) : null,
                          child: a.isEmpty ? const Icon(Icons.person, size: 19) : null,
                        ),
                        title: Text(nameOf(id), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: const Text('درخواست عضویت'),
                        trailing: Wrap(
                          spacing: 0,
                          children: [
                            IconButton(
                              tooltip: 'رد درخواست',
                              onPressed: busy ? null : () => review(r['id'].toString(), false),
                              icon: const Icon(Icons.close_rounded),
                            ),
                            IconButton(
                              tooltip: 'پذیرش درخواست',
                              onPressed: busy ? null : () => review(r['id'].toString(), true),
                              icon: const Icon(Icons.check_rounded),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              leading: const Icon(Icons.block_rounded),
              title: const Text('محروم‌شده‌ها', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${banned.length} نفر'),
              children: banned.isEmpty
                  ? [const ListTile(dense: true, title: Text('عضو محروم‌شده‌ای وجود ندارد.'))]
                  : banned.map((b) {
                      final id = b['user_id'].toString();
                      final a = avatarOf(id);
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 19,
                          backgroundImage: a.isNotEmpty ? NetworkImage(a) : null,
                          child: a.isEmpty ? const Icon(Icons.person, size: 19) : null,
                        ),
                        title: Text(nameOf(id), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text((b['reason'] ?? 'بدون دلیل').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Wrap(
                          spacing: 0,
                          children: [
                            IconButton(
                              tooltip: 'رفع محرومیت',
                              onPressed: busy ? null : () => unban(id),
                              icon: const Icon(Icons.lock_open_rounded),
                            ),
                            IconButton(
                              tooltip: 'تنظیم محدودیت',
                              onPressed: busy ? null : () => restrict(id),
                              icon: const Icon(Icons.tune_rounded),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              leading: const Icon(Icons.push_pin_rounded),
              title: const Text('سنجاق پیام‌ها', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${pinned.length} پیام سنجاق‌شده • ${messages.length} پیام اخیر'),
              children: [
                if (pinned.isEmpty)
                  const ListTile(dense: true, title: Text('هنوز پیامی سنجاق نشده است.')),
                ...pinned.map((p) {
                  final id = p['message_id'].toString();
                  final m = messages.firstWhere((x) => x['id'].toString() == id, orElse: () => {});
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.push_pin_rounded),
                    title: Text((m['body'] ?? 'پیام رسانه‌ای').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(nameOf((m['sender_id'] ?? '').toString())),
                    trailing: IconButton(
                      tooltip: 'برداشتن سنجاق',
                      onPressed: busy ? null : () => unpin(id),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  );
                }),
                const Divider(height: 1),
                const ListTile(dense: true, title: Text('پیام‌های اخیر برای سنجاق', style: TextStyle(fontWeight: FontWeight.w700))),
                ...messages.where((m) => !pinnedIds.contains(m['id'].toString())).take(12).map((m) {
                  final id = m['id'].toString();
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.chat_bubble_outline_rounded),
                    title: Text((m['body'] ?? 'پیام رسانه‌ای').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(nameOf(m['sender_id'].toString())),
                    trailing: IconButton(
                      tooltip: 'سنجاق پیام',
                      onPressed: busy ? null : () => pin(id),
                      icon: const Icon(Icons.push_pin_outlined),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
