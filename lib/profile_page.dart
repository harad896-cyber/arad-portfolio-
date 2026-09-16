import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'main.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override State<ProfilePage> createState() => _ProfilePageState();
}
class _ProfilePageState extends State<ProfilePage> {
  Map<String,dynamic> profile={}; bool loading=true,saving=false;
  final name=TextEditingController(), username=TextEditingController(), bio=TextEditingController();
  ImageProvider? avatarImage;
  Future<void> loadProfile() async {
    try {
      final u=supabase.auth.currentUser; if(u==null)return;
      final r=await supabase.from('profiles').select().eq('id',u.id).maybeSingle();
      profile=r==null?{}:Map<String,dynamic>.from(r);
      name.text='${profile['display_name']??u.userMetadata?['full_name']??''}';
      username.text='${profile['username']??''}'; bio.text='${profile['bio']??''}';
      final url='${profile['avatar_url']??''}'.trim();
      if(url.isNotEmpty)avatarImage=NetworkImage(url);
    }catch(e){if(mounted)showMsg(context,'پروفایل بارگذاری نشد: $e');}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> saveProfile() async {
    final uid=supabase.auth.currentUser?.id; if(uid==null)return;
    final display=name.text.trim(); if(display.isEmpty){showMsg(context,'نام نمایشی را وارد کنید.');return;}
    setState(()=>saving=true);
    try{
      final data={'id':uid,'display_name':display,'username':username.text.trim().replaceFirst('@',''),'bio':bio.text.trim(),'is_online':true,'last_seen':DateTime.now().toIso8601String()};
      await supabase.from('profiles').upsert(data); profile.addAll(data);
      if(mounted){setState((){});showMsg(context,'پروفایل ذخیره شد.');}
    }catch(e){if(mounted)showMsg(context,'ذخیره پروفایل ناموفق بود: $e');}
    finally{if(mounted)setState(()=>saving=false);}
  }
  Future<void> editProfile() async {
    name.text='${profile['display_name']??''}'; username.text='${profile['username']??''}'; bio.text='${profile['bio']??''}';
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,backgroundColor:Colors.transparent,builder:(c)=>ClipRRect(
      borderRadius:const BorderRadius.vertical(top:Radius.circular(30)),
      child:BackdropFilter(filter:ImageFilter.blur(sigmaX:20,sigmaY:20),child:Container(
        color:Theme.of(c).colorScheme.surface.withValues(alpha:.84),
        padding:EdgeInsets.fromLTRB(18,16,18,MediaQuery.viewInsetsOf(c).bottom+20),
        child:SafeArea(top:false,child:ListView(shrinkWrap:true,children:[
          const Center(child:Text('ویرایش پروفایل',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900))),
          const SizedBox(height:16),
          TextField(controller:name,decoration:const InputDecoration(labelText:'نام نمایشی',prefixIcon:Icon(Icons.person_outline_rounded))),
          const SizedBox(height:10),
          TextField(controller:username,decoration:const InputDecoration(labelText:'نام کاربری',prefixText:'@',prefixIcon:Icon(Icons.alternate_email_rounded))),
          const SizedBox(height:10),
          TextField(controller:bio,maxLines:3,decoration:const InputDecoration(labelText:'بیو / معرفی کوتاه',prefixIcon:Icon(Icons.info_outline_rounded))),
          const SizedBox(height:15),
          FilledButton.icon(onPressed:saving?null:()async{await saveProfile();if(mounted)Navigator.pop(c);},icon:const Icon(Icons.check_rounded),label:Text(saving?'در حال ذخیره...':'ذخیره تغییرات')),
        ])),
      )),
    ));
  }
  Future<void> changeAvatar() async {
    try{
      final x=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:88,maxWidth:900,maxHeight:900); if(x==null)return;
      final bytes=await x.readAsBytes(); final uid=supabase.auth.currentUser!.id; final path='$$uid/avatar.jpg';
      await supabase.storage.from('avatars').uploadBinary(path,bytes,fileOptions:const FileOptions(upsert:true,contentType:'image/jpeg'));
      final url='$${supabase.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
      await supabase.from('profiles').upsert({'id':uid,'avatar_url':url});
      if(mounted)setState((){profile['avatar_url']=url;avatarImage=NetworkImage(url);});
    }catch(e){if(mounted)showMsg(context,'تغییر عکس ناموفق بود: $e');}
  }
  Future<void> switchAccount() async {
    await supabase.auth.signOut(); if(!mounted)return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const LoginPage()),(_)=>false);
  }
  Widget glass(Widget child){
    final s=Theme.of(context).colorScheme;
    return ClipRRect(borderRadius:BorderRadius.circular(25),child:BackdropFilter(filter:ImageFilter.blur(sigmaX:18,sigmaY:18),child:Container(
      decoration:BoxDecoration(color:s.surface.withValues(alpha:Theme.of(context).brightness==Brightness.dark?.60:.72),borderRadius:BorderRadius.circular(25),border:Border.all(color:s.onSurface.withValues(alpha:.09)),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.08),blurRadius:18,offset:const Offset(0,6))]),
      child:child)));
  }
  @override void initState(){super.initState();loadProfile();}
  @override void dispose(){name.dispose();username.dispose();bio.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator());
    final s=Theme.of(context).colorScheme;
    final display='${profile['display_name']??'کاربر'}', un='${profile['username']??''}'.trim(), b='${profile['bio']??''}'.trim();
    return ListView(physics:const BouncingScrollPhysics(),padding:const EdgeInsets.fromLTRB(14,18,14,100),children:[
      glass(Padding(padding:const EdgeInsets.fromLTRB(18,22,18,20),child:Column(children:[
        Stack(clipBehavior:Clip.none,children:[
          CircleAvatar(radius:55,backgroundImage:avatarImage,child:avatarImage==null?const Icon(Icons.person_rounded,size:55):null),
          Positioned(right:-4,bottom:-4,child:IconButton.filled(onPressed:changeAvatar,icon:const Icon(Icons.camera_alt_rounded))),
        ]),
        const SizedBox(height:12), Text(display,textAlign:TextAlign.center,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),
        if(un.isNotEmpty)Text('@$un',style:TextStyle(color:s.primary,fontWeight:FontWeight.w700)),
        const SizedBox(height:9), Text(b.isEmpty?'هنوز بیویی ثبت نشده است.':b,textAlign:TextAlign.center,style:TextStyle(color:s.onSurfaceVariant,height:1.4)),
        const SizedBox(height:16),
        Row(children:[Expanded(child:FilledButton.icon(onPressed:editProfile,icon:const Icon(Icons.edit_rounded),label:const Text('ویرایش پروفایل'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:switchAccount,icon:const Icon(Icons.swap_horiz_rounded),label:const Text('تغییر حساب')))]),
      ])),
      const SizedBox(height:12),
      glass(Column(children:[
        ListTile(leading:CircleAvatar(backgroundColor:s.primaryContainer,child:Icon(Icons.person_add_alt_1_rounded,color:s.primary)),title:const Text('افزودن حساب',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('تا ۳ حساب روی دستگاه'),onTap:switchAccount),
        const Divider(height:1),
        ListTile(leading:CircleAvatar(backgroundColor:s.primaryContainer,child:Icon(Icons.bookmark_rounded,color:s.primary)),title:const Text('پیام‌های ذخیره‌شده',style:TextStyle(fontWeight:FontWeight.w800)),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const SavedMessagesPage()))),
        const Divider(height:1),
        ListTile(leading:CircleAvatar(backgroundColor:s.errorContainer,child:Icon(Icons.logout_rounded,color:s.error)),title:const Text('خروج از حساب',style:TextStyle(fontWeight:FontWeight.w800)),onTap:switchAccount),
      ])),
    ]);
  }
}
