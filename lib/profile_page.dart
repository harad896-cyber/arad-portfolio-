import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'owner_admin_page.dart';
import 'chat_background_page.dart';
import 'polish_widgets.dart';

const _profileSecureAccounts = FlutterSecureStorage();

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> profile = {};
  bool loading = true;
  bool saving = false;
  final name = TextEditingController();
  final username = TextEditingController();
  final bio = TextEditingController();
  ImageProvider? avatarImage;

  @override
  void initState() { super.initState(); loadProfile(); }

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    bio.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final row = await supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      profile = row == null ? {} : Map<String, dynamic>.from(row);
      name.text = '${profile['display_name'] ?? user.userMetadata?['full_name'] ?? ''}';
      username.text = '${profile['username'] ?? ''}';
      bio.text = '${profile['bio'] ?? ''}';
      final url = '${profile['avatar_url'] ?? ''}'.trim();
      if (url.isNotEmpty) avatarImage = NetworkImage(url);
    } catch (e) {
      if (mounted) showMsg(context, 'پروفایل بارگذاری نشد: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> saveProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final display = name.text.trim();
    final cleanUsername = username.text.trim().replaceFirst('@', '').toLowerCase();
    if (display.isEmpty) { showMsg(context, 'نام نمایشی را وارد کنید.'); return; }
    if (cleanUsername.isNotEmpty && !RegExp(r'^[a-z0-9_]{3,32}$').hasMatch(cleanUsername)) {
      showMsg(context, 'آیدی باید ۳ تا ۳۲ کاراکتر و فقط شامل حروف انگلیسی، عدد و _ باشد.');
      return;
    }
    setState(() => saving = true);
    try {
      final data = <String, dynamic>{
        'id': user.id,
        'display_name': display,
        'username': cleanUsername,
        'bio': bio.text.trim(),
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
      };
      await supabase.from('profiles').upsert(data);
      profile.addAll(data);
      if (mounted) {
        Navigator.pop(context);
        showMsg(context, 'پروفایل ذخیره شد.');
        setState(() {});
      }
    } catch (e) {
      if (mounted) showMsg(context, 'ذخیره پروفایل ناموفق بود: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> changeAvatar() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 900, maxHeight: 900);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final uid = supabase.auth.currentUser!.id;
      final path = '$uid/avatar.jpg';
      await supabase.storage.from('avatars').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
      final url = '${supabase.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
      await supabase.from('profiles').upsert({'id': uid, 'avatar_url': url});
      if (mounted) setState(() { profile['avatar_url'] = url; avatarImage = NetworkImage(url); });
    } catch (e) {
      if (mounted) showMsg(context, 'تغییر عکس ناموفق بود: $e');
    }
  }

  Future<void> requestVerification() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final p = await supabase.from('profiles').select('joined_at,is_verified').eq('id', uid).maybeSingle();
      final joined = DateTime.tryParse(p?['joined_at']?.toString() ?? '');
      if (joined == null || DateTime.now().toUtc().isBefore(joined.toUtc().add(const Duration(days: 60)))) {
        showMsg(context, 'برای درخواست تیک آبی باید حداقل دو ماه از عضویت این حساب گذشته باشد.');
        return;
      }
      if (p?['is_verified'] == true) {
        showMsg(context, 'این حساب قبلاً تیک آبی دارد.');
        return;
      }
      final existing = await supabase.from('verification_requests').select('status').eq('user_id', uid).maybeSingle();
      if (existing != null) {
        showMsg(context, existing['status'] == 'pending' ? 'درخواست شما در حال بررسی است.' : 'برای این حساب قبلاً درخواست ثبت شده است.');
        return;
      }
      await supabase.from('verification_requests').insert({'user_id': uid});
      if (mounted) showMsg(context, 'درخواست تیک آبی ارسال شد.');
    } catch (e) {
      if (mounted) showMsg(context, 'ارسال درخواست ناموفق بود: $e');
    }
  }

  Future<void> switchAccount() async {
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSwitcherPage()));
    if (mounted) await loadProfile();
  }

  Future<void> logoutThisAccount() async {
    final email = supabase.auth.currentUser?.email?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) await _profileSecureAccounts.delete(key: 'account_refresh_$email');
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => LoginPage()), (_) => false);
  }

  Widget glass(Widget child) {
    final s = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: s.surface.withValues(alpha: dark ? .62 : .72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: s.onSurface.withValues(alpha: .09)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 20, offset: const Offset(0, 7))],
          ),
          child: child,
        ),
      ),
    );
  }

  Future<void> editProfile() async {
    name.text = '${profile['display_name'] ?? ''}';
    username.text = '${profile['username'] ?? ''}';
    bio.text = '${profile['bio'] ?? ''}';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              color: Theme.of(sheet).colorScheme.surface.withValues(alpha: .92),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
              child: SafeArea(
                top: false,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Theme.of(sheet).colorScheme.onSurface.withValues(alpha: .22), borderRadius: BorderRadius.circular(4)))),
                    const SizedBox(height: 16),
                    const Center(child: Text('ویرایش پروفایل', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900))),
                    const SizedBox(height: 16),
                    TextField(controller: name, textDirection: TextDirection.rtl, decoration: const InputDecoration(labelText: 'نام نمایشی', prefixIcon: Icon(Icons.person_outline_rounded))),
                    const SizedBox(height: 10),
                    TextField(controller: username, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'آیدی', prefixText: '@', prefixIcon: Icon(Icons.alternate_email_rounded))),
                    const SizedBox(height: 10),
                    TextField(controller: bio, textDirection: TextDirection.rtl, maxLines: 3, maxLength: 150, decoration: const InputDecoration(labelText: 'بیو / معرفی کوتاه', prefixIcon: Icon(Icons.info_outline_rounded))),
                    const SizedBox(height: 8),
                    FilledButton.icon(onPressed: saving ? null : saveProfile, icon: const Icon(Icons.check_rounded), label: Text(saving ? 'در حال ذخیره...' : 'ذخیره تغییرات')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const AppSkeletonList(count: 5);
    final s = Theme.of(context).colorScheme;
    final display = '${profile['display_name'] ?? 'کاربر'}';
    final un = '${profile['username'] ?? ''}'.trim();
    final b = '${profile['bio'] ?? ''}'.trim();
    final verified = profile['is_verified'] == true;
    final owner = profile['is_owner'] == true || supabase.auth.currentUser?.email?.toLowerCase() == 'harad896@gmail.com';

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 14, 110),
      children: [
        glass(Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
          child: Column(children: [
            GestureDetector(
              onTap: changeAvatar,
              child: Stack(clipBehavior: Clip.none, children: [
                CircleAvatar(radius: 58, backgroundImage: avatarImage, child: avatarImage == null ? const Icon(Icons.person_rounded, size: 58) : null),
                Positioned(right: -3, bottom: -3, child: CircleAvatar(radius: 19, backgroundColor: s.primary, child: const Icon(Icons.camera_alt_rounded, size: 19))),
              ]),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(child: Text(display, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
              if (verified) ...[const SizedBox(width: 6), Icon(Icons.verified_rounded, color: s.primary, size: 22)],
            ]),
            if (un.isNotEmpty) Text('@$un', style: TextStyle(color: s.primary, fontWeight: FontWeight.w800)),
            IconButton(tooltip: 'کپی آیدی', icon: const Icon(Icons.copy_rounded, size: 18), onPressed: () { Clipboard.setData(ClipboardData(text: '@$un')); showMsg(context, 'آیدی کپی شد.'); }),
            const SizedBox(height: 8),
            Text(b.isEmpty ? 'هنوز بیویی ثبت نشده است.' : b, textAlign: TextAlign.center, style: TextStyle(color: s.onSurfaceVariant, height: 1.4)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: editProfile, icon: const Icon(Icons.edit_rounded), label: const Text('ویرایش پروفایل'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: switchAccount, icon: const Icon(Icons.swap_horiz_rounded), label: const Text('تغییر حساب'))),
            ]),
          ]),
        )),
        const SizedBox(height: 12),
        glass(Column(children: [
          ListTile(
            leading: CircleAvatar(backgroundColor: s.primaryContainer, child: Icon(Icons.person_add_alt_1_rounded, color: s.primary)),
            title: const Text('افزودن حساب', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('تا ۳ حساب روی دستگاه'),
            onTap: switchAccount,
          ),
          const Divider(height: 1),
          ListTile(
            leading: CircleAvatar(backgroundColor: s.primaryContainer, child: Icon(Icons.verified_rounded, color: s.primary)),
            title: const Text('درخواست تیک آبی', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('پس از حداقل دو ماه فعالیت قابل درخواست است'),
            onTap: requestVerification,
          ),
          if (owner) ...[
            const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(backgroundColor: s.primaryContainer, child: Icon(Icons.admin_panel_settings_rounded, color: s.primary)),
              title: const Text('مدیریت تیک آبی', style: TextStyle(fontWeight: FontWeight.w800)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerAdminPage())),
            ),
          ],
          const Divider(height: 1),
          ListTile(
            leading: CircleAvatar(backgroundColor: s.primaryContainer, child: Icon(Icons.palette_rounded, color: s.primary)),
            title: const Text('پس‌زمینه چت', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('رنگ پس‌زمینه برای همین حساب روی این دستگاه'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatBackgroundPage())),
          ),
          const Divider(height: 1),
          ListTile(
            leading: CircleAvatar(backgroundColor: s.primaryContainer, child: Icon(Icons.bookmark_rounded, color: s.primary)),
            title: const Text('پیام‌های ذخیره‌شده', style: TextStyle(fontWeight: FontWeight.w800)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SavedMessagesPage())),
          ),
          const Divider(height: 1),
          ListTile(
            leading: CircleAvatar(backgroundColor: s.errorContainer, child: Icon(Icons.logout_rounded, color: s.error)),
            title: const Text('خروج از حساب', style: TextStyle(fontWeight: FontWeight.w800)),
            onTap: logoutThisAccount,
          ),
        ])),
      ],
    );
  }
}

class ProfileOptionPage extends StatefulWidget {
  final String title;
  final IconData icon;
  const ProfileOptionPage({super.key, required this.title, required this.icon});
  @override
  State<ProfileOptionPage> createState() => _ProfileOptionPageState();
}

class _ProfileOptionPageState extends State<ProfileOptionPage> {
  bool enabled = true;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: s.surface.withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: s.onSurface.withValues(alpha: .08)),
                ),
                child: SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor: s.primaryContainer,
                    child: Icon(widget.icon, color: s.primary),
                  ),
                  title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('تنظیم این بخش برای همین حساب ذخیره می‌شود.'),
                  value: enabled,
                  onChanged: (v) => setState(() => enabled = v),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VerificationAdminPage extends StatefulWidget {
  const VerificationAdminPage({super.key});
  @override
  State<VerificationAdminPage> createState() => _VerificationAdminPageState();
}

class _VerificationAdminPageState extends State<VerificationAdminPage> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await supabase.from('verification_requests').select('id,user_id,status,created_at').order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(data);
      for (final r in list) {
        final p = await supabase.from('profiles').select('display_name,username,avatar_url,is_verified').eq('id', r['user_id']).maybeSingle();
        r['profile'] = p ?? {};
      }
      if (mounted) setState(() { rows = list; loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        showMsg(context, 'بارگذاری درخواست‌ها ناموفق بود: $e');
      }
    }
  }

  Future<void> decide(Map<String, dynamic> row, bool approve) async {
    try {
      await supabase.from('verification_requests').update({'status': approve ? 'approved' : 'rejected'}).eq('id', row['id']);
      await supabase.from('profiles').update({'is_verified': approve}).eq('id', row['user_id']);
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'عملیات ناموفق بود: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    if (loading) return const Scaffold(body: AppSkeletonList(count: 5));
    return Scaffold(
      appBar: AppBar(title: const Text('درخواست‌های تیک آبی')),
      body: rows.isEmpty
          ? const Center(child: Text('درخواستی وجود ندارد.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final row = rows[i];
                final p = Map<String, dynamic>.from(row['profile'] ?? {});
                final status = '${row['status'] ?? 'pending'}';
                return Card(
                  child: ListTile(
                    leading: avatar(p),
                    title: Text('${p['display_name'] ?? p['username'] ?? 'کاربر'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('وضعیت: $status'),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'تأیید',
                          onPressed: status == 'approved' ? null : () => decide(row, true),
                          icon: Icon(Icons.verified_rounded, color: s.primary),
                        ),
                        IconButton(
                          tooltip: 'رد',
                          onPressed: status == 'rejected' ? null : () => decide(row, false),
                          icon: Icon(Icons.close_rounded, color: s.error),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class AccountSwitcherPage extends StatefulWidget {
  const AccountSwitcherPage({super.key});
  @override State<AccountSwitcherPage> createState()=>_AccountSwitcherPageState();
}
class _AccountSwitcherPageState extends State<AccountSwitcherPage>{
  List<String> emails=[]; String? active; bool loading=true;
  @override void initState(){super.initState();load();}
  Future<void> load()async{emails=await rememberedAccountEmails();active=supabase.auth.currentUser?.email?.toLowerCase();if(mounted)setState(()=>loading=false);}
  Future<void> select(String mail)async{
    if(mail.toLowerCase()==active){Navigator.pop(context);return;}
    final token=await _profileSecureAccounts.read(key:'account_refresh_${mail.toLowerCase()}');
    if(token==null||token.isEmpty){showMsg(context,'نشست ذخیره‌شده این حساب پیدا نشد.');return;}
    try{
      final res=await supabase.auth.setSession(token);
      if(res.session==null)throw const AuthException('نشست حساب منقضی شده است.');
      await rememberCurrentSession();await appTheme.loadForUser();
      if(mounted)Navigator.of(context).pop();
    }catch(e){if(mounted)showMsg(context,'تغییر حساب ناموفق بود: $e');}
  }
  Future<void> addAccount()async{
    if(emails.length>=3){showMsg(context,'حداکثر ۳ حساب مجاز است.');return;}
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>const LoginPage(addAccount:true)));
    if(mounted)await load();
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('تغییر حساب')),body:ListView(padding:const EdgeInsets.all(16),children:[
    if(loading)const Center(child:Padding(padding:EdgeInsets.all(30),child:CircularProgressIndicator())),
    if(!loading)...emails.map((mail)=>Card(child:ListTile(
      leading:CircleAvatar(child:Text(mail.isEmpty?'?':mail[0].toUpperCase())),
      title:Text(mail),subtitle:Text(mail.toLowerCase()==active?'حساب فعال':'حساب ذخیره‌شده'),
      trailing:mail.toLowerCase()==active?const Icon(Icons.check_circle_rounded):const Icon(Icons.touch_app_rounded),
      onTap:()=>select(mail),
    ))),
    if(!loading&&emails.length<3)Card(child:ListTile(leading:const Icon(Icons.add_circle_outline_rounded),title:Text('افزودن حساب ${emails.length+1}'),subtitle:const Text('ورود با ایمیل دیگر'),onTap:addAccount)),
  ]));
}
