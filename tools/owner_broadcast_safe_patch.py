from pathlib import Path
p=Path('lib/main.dart')
s=p.read_text(encoding='utf-8')

if 'class OwnerBroadcastPage extends StatefulWidget' not in s:
    s += r'''

class OwnerAwareHomePage extends StatelessWidget {
  const OwnerAwareHomePage({super.key});
  Future<bool> admin() async {
    final uid=supabase.auth.currentUser?.id; if(uid==null)return false;
    return await supabase.from('admin_users').select('user_id').eq('user_id',uid).maybeSingle()!=null;
  }
  @override Widget build(BuildContext context)=>FutureBuilder<bool>(future:admin(),builder:(c,snap)=>snap.data==true?Stack(children:[const HomePage(),Positioned(right:16,bottom:88,child:FloatingActionButton.small(heroTag:'owner-panel',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AdminDashboardPage())),child:const Icon(Icons.admin_panel_settings_rounded))) ]):const HomePage());
}

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});
  Future<Map<String,int>> stats() async {
    final users=await supabase.from('profiles').select('id');
    final groups=await supabase.from('conversations').select('id').eq('type','group');
    final channels=await supabase.from('conversations').select('id').eq('type','channel');
    final messages=await supabase.from('messages').select('id');
    return {'users':users.length,'groups':groups.length,'channels':channels.length,'messages':messages.length};
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('مدیریت مالک')),body:FutureBuilder<Map<String,int>>(future:stats(),builder:(c,s)=>ListView(padding:const EdgeInsets.all(16),children:[Card(child:ListTile(leading:const Icon(Icons.campaign_rounded),title:const Text('پیام همگانی',style:TextStyle(fontWeight:FontWeight.w900)),subtitle:const Text('اطلاعیه یا تبلیغ برای همه کاربران'),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>const OwnerBroadcastPage())))),const SizedBox(height:12),if(s.connectionState==ConnectionState.waiting)const Center(child:CircularProgressIndicator()) else if(s.hasError)const Text('آمار قابل دریافت نیست.') else ...[Row(children:[_statCard(c,'کاربران','${s.data!['users']}',Icons.people_alt_rounded),_statCard(c,'گروه‌ها','${s.data!['groups']}',Icons.groups_rounded)]),const SizedBox(height:8),Row(children:[_statCard(c,'کانال‌ها','${s.data!['channels']}',Icons.campaign_rounded),_statCard(c,'پیام‌ها','${s.data!['messages']}',Icons.chat_rounded)])]])));
}
Widget _statCard(BuildContext c,String title,String value,IconData icon)=>Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[Icon(icon,color:Theme.of(c).colorScheme.primary),const SizedBox(height:6),Text(value,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900)),Text(title,style:const TextStyle(fontWeight:FontWeight.w700))]))));

class OwnerBroadcastPage extends StatefulWidget { const OwnerBroadcastPage({super.key}); @override State<OwnerBroadcastPage> createState()=>_OwnerBroadcastPageState(); }
class _OwnerBroadcastPageState extends State<OwnerBroadcastPage>{
 final title=TextEditingController(),body=TextEditingController(),link=TextEditingController(); bool sending=false;
 Future<void> publish() async { if(title.text.trim().isEmpty||body.text.trim().isEmpty){showMsg(context,'عنوان و متن را وارد کنید.');return;} setState(()=>sending=true); try{await supabase.rpc('owner_create_announcement',params:{'p_title':title.text.trim(),'p_body':body.text.trim(),'p_link_url':link.text.trim().isEmpty?null:link.text.trim()});if(mounted){showMsg(context,'برای همه کاربران منتشر شد.');Navigator.pop(context);}}catch(_){if(mounted)showMsg(context,'انتشار ناموفق بود. ابتدا migration پیام همگانی را روی Supabase اجرا کنید.');}finally{if(mounted)setState(()=>sending=false);}}
 @override void dispose(){title.dispose();body.dispose();link.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('پیام همگانی')),body:ListView(padding:const EdgeInsets.all(18),children:[Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Theme.of(context).colorScheme.primaryContainer,borderRadius:BorderRadius.circular(18)),child:const Text('هر چیزی اینجا منتشر کنید، به‌صورت اطلاعیه برای همه کاربران نمایش داده می‌شود.',style:TextStyle(fontWeight:FontWeight.w800))),const SizedBox(height:16),TextField(controller:title,decoration:const InputDecoration(labelText:'عنوان')),const SizedBox(height:12),TextField(controller:body,maxLines:6,decoration:const InputDecoration(labelText:'متن اطلاعیه / تبلیغ')),const SizedBox(height:12),TextField(controller:link,keyboardType:TextInputType.url,decoration:const InputDecoration(labelText:'لینک اختیاری')),const SizedBox(height:18),FilledButton.icon(onPressed:sending?null:publish,icon:const Icon(Icons.send_rounded),label:Text(sending?'در حال انتشار...':'انتشار برای همه'))]));
}

class GlobalAnnouncementGate extends StatefulWidget { final Widget child; const GlobalAnnouncementGate({super.key,required this.child}); @override State<GlobalAnnouncementGate> createState()=>_GlobalAnnouncementGateState(); }
class _GlobalAnnouncementGateState extends State<GlobalAnnouncementGate>{ bool done=false; Future<void> check() async {if(done||supabase.auth.currentUser==null)return;try{final r=await supabase.from('announcements').select('id,title,body,link_url').eq('is_active',true).order('created_at',ascending:false).limit(1).maybeSingle();if(r==null||!mounted)return;final p=await SharedPreferences.getInstance();final id='${r['id']}';if(p.getString('arad_seen_announcement')==id)return;await p.setString('arad_seen_announcement',id);done=true;if(mounted)await showDialog(context:context,builder:(d)=>AlertDialog(title:Row(children:[Icon(Icons.campaign_rounded,color:Theme.of(context).colorScheme.primary),const SizedBox(width:8),Expanded(child:Text('${r['title']}'))]),content:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${r['body']}'),if('${r['link_url']??''}'.isNotEmpty)...[const SizedBox(height:12),SelectableText('${r['link_url']}')]])),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('باشه'))]));}catch(_){}}
 @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_){check();});}@override Widget build(BuildContext c)=>widget.child; }
'''

needle="return snapshot.data! ? const HomePage() : const ProfileSetupPage();"
if needle in s and 'GlobalAnnouncementGate(child:' not in s:
    s=s.replace(needle,"return snapshot.data! ? const GlobalAnnouncementGate(child: OwnerAwareHomePage()) : const ProfileSetupPage();",1)

p.write_text(s,encoding='utf-8')
