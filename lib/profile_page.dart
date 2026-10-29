import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'owner_admin_page.dart';
import 'chat_background_page.dart';
import 'polish_widgets.dart';

const _profileSecureAccounts = FlutterSecureStorage();

class ProfilePage extends StatefulWidget {
  final VoidCallback? onOpenContacts;
  const ProfilePage({super.key, this.onOpenContacts});
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
  StreamSubscription<AuthState>? _profileAuthSubscription;
  String? _observedProfileUserId;

  @override
  void initState() {
    super.initState();
    _observedProfileUserId = supabase.auth.currentUser?.id;
    loadProfile();
    // If the auth session is restored or refreshed after the profile page
    // opens, retry profile loading for that authenticated account.
    _profileAuthSubscription = supabase.auth.onAuthStateChange.listen((state) {
      final nextUserId = state.session?.user.id;
      if (nextUserId == null) return;
      if (nextUserId != _observedProfileUserId ||
          state.event == AuthChangeEvent.signedIn ||
          state.event == AuthChangeEvent.tokenRefreshed) {
        _observedProfileUserId = nextUserId;
        loadProfile();
      }
    });
  }

  @override
  void dispose() {
    _profileAuthSubscription?.cancel();
    name.dispose();
    username.dispose();
    bio.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    var user = supabase.auth.currentUser;
    // On some cold starts the auth SDK restores the token just after this page
    // is constructed. Ask Supabase to restore/validate it once instead of
    // immediately rendering an empty profile.
    if (user == null) {
      try {
        user = (await supabase.auth.getUser().timeout(const Duration(seconds: 5))).user;
      } catch (authError) {
        debugPrint('Profile auth restore failed: $authError');
      }
    }
    if (user == null) {
      if (mounted) {
        setState(() => loading = false);
        showMsg(context, 'حساب واردشده پیدا نشد؛ یک‌بار از حساب خارج و دوباره وارد شوید.');
      }
      return;
    }
    final cacheKey = 'arad_profile_cache_${user.id}';
    // Paint the last known profile immediately; refresh from Supabase in the background.
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
      final cached = prefs.getString(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        final decoded = jsonDecode(cached);
        if (decoded is Map) {
          profile = Map<String, dynamic>.from(decoded);
          name.text = '${profile['display_name'] ?? user.userMetadata?['full_name'] ?? ''}';
          username.text = '${profile['username'] ?? ''}';
          bio.text = '${profile['bio'] ?? ''}';
          final cachedUrl = '${profile['avatar_url'] ?? ''}'.trim();
          if (cachedUrl.isNotEmpty) avatarImage = NetworkImage(cachedUrl);
          if (mounted) setState(() => loading = false);
        }
      }
    } catch (_) {}
    try {
      Map<String, dynamic>? row;
      // Keep the profile screen compatible with databases where newer optional
      // columns have not been migrated yet. A missing joined_at/is_verified
      // column must not blank the entire account page.
      try {
        row = await supabase.from('profiles')
            .select('id,username,display_name,avatar_url,bio,is_online,last_seen,is_verified,created_at,joined_at')
            .eq('id', user.id).maybeSingle()
            .timeout(const Duration(seconds: 6));
      } catch (schemaError) {
        debugPrint('Profile optional columns unavailable; retrying minimal profile query: $schemaError');
        row = await supabase.from('profiles')
            .select('id,username,display_name,avatar_url,bio')
            .eq('id', user.id).maybeSingle()
            .timeout(const Duration(seconds: 6));
      }
      final metadata = user.userMetadata ?? <String, dynamic>{};
      final metadataName = (metadata['full_name'] ?? metadata['name'] ?? user.email?.split('@').first ?? '').toString();
      final metadataAvatar = (metadata['avatar_url'] ?? metadata['picture'] ?? '').toString();
      if (row == null) {
        // A verified account can exist before its profile row is created.
        // Create a minimal row where permitted, but keep the page usable if
        // database policy/schema prevents that insert.
        try {
          await supabase.from('profiles').upsert({
            'id': user.id,
            'display_name': metadataName,
          }).timeout(const Duration(seconds: 4));
        } catch (createError) {
          debugPrint('Could not bootstrap missing profile row: $createError');
        }
        row = <String, dynamic>{
          'id': user.id,
          'display_name': metadataName,
          'avatar_url': metadataAvatar,
          'username': '',
          'bio': '',
        };
      }
      final fresh = Map<String, dynamic>.from(row);
      if ((fresh['display_name'] ?? '').toString().trim().isEmpty && metadataName.trim().isNotEmpty) {
        fresh['display_name'] = metadataName;
      }
      if ((fresh['avatar_url'] ?? '').toString().trim().isEmpty && metadataAvatar.trim().isNotEmpty) {
        fresh['avatar_url'] = metadataAvatar;
      }
      profile = fresh;
      name.text = '${profile['display_name'] ?? metadataName}';
      username.text = '${profile['username'] ?? ''}';
      bio.text = '${profile['bio'] ?? ''}';
      final url = '${profile['avatar_url'] ?? ''}'.trim();
      avatarImage = url.isNotEmpty ? NetworkImage(url) : null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(profile));
      } catch (_) {}
    } catch (e) {
      // A profile/network/schema failure must not leave the account screen blank.
      // Keep the cached row when available; otherwise construct a usable local
      // profile from the authenticated user's metadata and email.
      debugPrint('Profile refresh failed; keeping a local fallback: $e');
      final metadata = user.userMetadata ?? <String, dynamic>{};
      final metadataName = (metadata['full_name'] ?? metadata['name'] ??
          user.email?.split('@').first ?? 'کاربر').toString();
      final metadataAvatar = (metadata['avatar_url'] ?? metadata['picture'] ?? '').toString();
      if (profile.isEmpty) {
        profile = <String, dynamic>{
          'id': user.id,
          'display_name': metadataName,
          'username': '',
          'bio': '',
          'avatar_url': metadataAvatar,
        };
      } else {
        if ('${profile['display_name'] ?? ''}'.trim().isEmpty) {
          profile['display_name'] = metadataName;
        }
        if ('${profile['avatar_url'] ?? ''}'.trim().isEmpty && metadataAvatar.isNotEmpty) {
          profile['avatar_url'] = metadataAvatar;
        }
      }
      name.text = '${profile['display_name'] ?? metadataName}';
      username.text = '${profile['username'] ?? ''}';
      bio.text = '${profile['bio'] ?? ''}';
      final fallbackAvatar = '${profile['avatar_url'] ?? ''}'.trim();
      avatarImage = fallbackAvatar.isNotEmpty ? NetworkImage(fallbackAvatar) : null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(profile));
      } catch (_) {}
      if (mounted && loading) {
        showMsg(context, 'نمایش پروفایل محلی؛ برای به‌روزرسانی اطلاعات اینترنت را بررسی کنید.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> saveProfile([BuildContext? editorContext]) async {
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
      // Keep the local profile snapshot in sync so the next open is instant and not stale.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('arad_profile_cache_${user.id}', jsonEncode(profile));
      } catch (_) {}
      if (mounted) {
        // Dismiss the editor sheet, not the profile page behind it.
        Navigator.of(editorContext ?? context).pop();
        showMsg(context, 'پروفایل ذخیره شد.');
        setState(() {});
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        final message = e.message.toLowerCase();
        if (message.contains('username') && (message.contains('duplicate') || message.contains('unique'))) {
          showMsg(context, 'این آیدی قبلاً انتخاب شده است؛ یک آیدی دیگر امتحان کنید.');
        } else {
          showMsg(context, 'ذخیره پروفایل ناموفق بود. اتصال و اطلاعات واردشده را بررسی کنید.');
        }
      }
    } catch (_) {
      if (mounted) showMsg(context, 'ذخیره پروفایل ناموفق بود؛ اینترنت را بررسی و دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> showAvatarPreview() async {
    if (avatarImage == null) {
      await changeAvatar();
      return;
    }
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .94),
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image(image: avatarImage!, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 8,
              right: 12,
              child: IconButton.filledTonal(
                tooltip: 'بستن عکس',
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(ctx).padding.bottom + 18,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await changeAvatar();
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('تغییر عکس'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await removeAvatar();
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('حذف عکس'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
      profile['avatar_url'] = url;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('arad_profile_cache_${uid}', jsonEncode(profile));
      } catch (_) {}
      if (mounted) setState(() { avatarImage = NetworkImage(url); });
    } catch (e) {
      if (mounted) showMsg(context, 'تغییر عکس ناموفق بود: $e');
    }
  }

  Future<void> removeAvatar() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await supabase.from('profiles').update({'avatar_url': null}).eq('id', user.id);
      profile.remove('avatar_url');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('arad_profile_cache_${user.id}', jsonEncode(profile));
      } catch (_) {}
      if (mounted) {
        setState(() {
          avatarImage = null;
        });
      }
      // The profile is cleared even if storage cleanup is blocked by bucket policy.
      try {
        await supabase.storage.from('avatars').remove(['${user.id}/avatar.jpg']);
      } catch (_) {}
      if (mounted) showMsg(context, 'عکس پروفایل حذف شد.');
    } catch (e) {
      if (mounted) showMsg(context, 'حذف عکس ناموفق بود: $e');
    }
  }

  Future<void> showProfileQr() async {
    final un='${profile['username'] ?? ''}'.trim();
    if(un.isEmpty){showMsg(context,'ابتدا یک آیدی برای پروفایل تنظیم کنید.');return;}
    final link='https://arad-messenger.app/u/$un';
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('QR پروفایل'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:QrImageView(data:link,size:220,version:QrVersions.auto)),
        const SizedBox(height:12),Text('@$un',style:const TextStyle(fontWeight:FontWeight.w900)),
        const SizedBox(height:6),Text(link,textAlign:TextAlign.center,style:TextStyle(color:Theme.of(ctx).colorScheme.onSurfaceVariant,fontSize:12)),
      ]),
      actions:[TextButton(onPressed:()=>Clipboard.setData(ClipboardData(text:link)),child:const Text('کپی لینک')),FilledButton.icon(onPressed:()=>Share.share(link),icon:const Icon(Icons.share_rounded),label:const Text('اشتراک‌گذاری'))],
    ));
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
    final emails = await rememberedAccountEmails();
    if (!mounted) return;
    if (emails.length <= 1) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSwitcherPage()));
      if (mounted) await loadProfile();
      return;
    }
    final active = supabase.auth.currentUser?.email?.trim().toLowerCase();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('تغییر حساب', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            ),
            ...emails.map((mail) {
              final isActive = mail.toLowerCase() == active;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(mail.isEmpty ? '?' : mail[0].toUpperCase())),
                  title: Text(mail, overflow: TextOverflow.ellipsis),
                  subtitle: Text(isActive ? 'حساب فعال' : 'برای ورود به این حساب بزنید'),
                  trailing: Icon(isActive ? Icons.check_circle_rounded : Icons.touch_app_rounded),
                  onTap: isActive ? () => Navigator.pop(sheet) : () async {
                    final token = await _profileSecureAccounts.read(key: 'account_refresh_${mail.toLowerCase()}');
                    if (token == null || token.isEmpty) {
                      if (sheet.mounted) showMsg(sheet, 'نشست ذخیره‌شده این حساب پیدا نشد.');
                      return;
                    }
                    try {
                      final res = await supabase.auth.setSession(token);
                      if (res.session == null) throw const AuthException('نشست حساب منقضی شده است.');
                      await rememberCurrentSession();
                      await appTheme.loadForUser();
                      if (sheet.mounted) Navigator.pop(sheet);
                    } catch (e) {
                      if (sheet.mounted) showMsg(sheet, 'تغییر حساب ناموفق بود: $e');
                    }
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
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
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: s.surface.withValues(alpha: dark ? .72 : .82),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: s.onSurface.withValues(alpha: .09)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 20, offset: const Offset(0, 7))],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _profileFieldLabel(BuildContext context, String label, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Icon(icon, size: 17, color: scheme.primary),
      const SizedBox(width: 7),
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: scheme.onSurface)),
    ]);
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
                    const SizedBox(height: 18),
                    const Text('ویرایش پروفایل', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.3)),
                    const SizedBox(height: 5),
                    Text('اطلاعاتت را مرتب و به‌روز نگه دار', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(sheet).colorScheme.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(height: 22),
                    _profileFieldLabel(sheet, 'نام نمایشی', Icons.badge_outlined),
                    const SizedBox(height: 7),
                    TextField(controller: name, textDirection: TextDirection.rtl, textInputAction: TextInputAction.next, maxLength: 40, decoration: const InputDecoration(hintText: 'نامی که دیگران می‌بینند', counterText: '', prefixIcon: Icon(Icons.person_outline_rounded))),
                    const SizedBox(height: 14),
                    _profileFieldLabel(sheet, 'شناسه کاربری', Icons.alternate_email_rounded),
                    const SizedBox(height: 7),
                    TextField(controller: username, textDirection: TextDirection.ltr, textInputAction: TextInputAction.next, maxLength: 32, decoration: const InputDecoration(hintText: 'your_username', counterText: '', prefixText: '@', prefixIcon: Icon(Icons.alternate_email_rounded))),
                    const SizedBox(height: 4),
                    Text('فقط حروف انگلیسی، عدد و زیرخط؛ حداقل ۳ کاراکتر', textDirection: TextDirection.rtl, style: TextStyle(color: Theme.of(sheet).colorScheme.onSurfaceVariant, fontSize: 11.5)),
                    const SizedBox(height: 14),
                    _profileFieldLabel(sheet, 'بیوگرافی', Icons.notes_rounded),
                    const SizedBox(height: 7),
                    TextField(controller: bio, textDirection: TextDirection.rtl, textAlignVertical: TextAlignVertical.top, maxLines: 4, minLines: 3, maxLength: 150, decoration: const InputDecoration(hintText: 'چند کلمه درباره خودت بنویس…', alignLabelWithHint: true, prefixIcon: Icon(Icons.info_outline_rounded))),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: bio,
                      builder: (context, value, _) {
                        final text = value.text.trim();
                        final scheme = Theme.of(sheet).colorScheme;
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(alpha: .55),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: scheme.outlineVariant.withValues(alpha: .6)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Icon(Icons.visibility_outlined, size: 16, color: scheme.primary),
                              const SizedBox(width: 6),
                              Text('پیش‌نمایش بیو', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.primary)),
                              const Spacer(),
                              Text('${value.text.length}/150', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                            ]),
                            const SizedBox(height: 7),
                            Text(
                              text.isEmpty ? 'بیوی شما اینجا نمایش داده می‌شود…' : text,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(height: 1.55, color: text.isEmpty ? scheme.onSurfaceVariant : scheme.onSurface),
                            ),
                          ]),
                        );
                      },
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(sheet).colorScheme.primaryContainer.withValues(alpha: .42), borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Icon(Icons.tips_and_updates_outlined, color: Theme.of(sheet).colorScheme.primary, size: 19),
                        const SizedBox(width: 9),
                        Expanded(child: Text('نام واضح، آیدی کوتاه و بیوی مختصر، پیدا کردن حسابت را آسان‌تر می‌کند.', style: TextStyle(fontSize: 12, height: 1.45, color: Theme.of(sheet).colorScheme.onSurfaceVariant))),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(width: double.infinity, child: FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: saving ? null : () => saveProfile(sheet),
                      icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
                      label: Text(saving ? 'در حال ذخیره…' : 'ذخیره تغییرات', style: const TextStyle(fontWeight: FontWeight.w800)),
                    )),
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
    final profileAvatarUrl = '${profile['avatar_url'] ?? ''}'.trim();
    final profileAvatarFallbackUrl = supabase.auth.currentUser?.id == null ? '' : supabase.storage.from('avatars').getPublicUrl('${supabase.auth.currentUser!.id}/avatar.jpg');

    final email = supabase.auth.currentUser?.email?.trim() ?? '';
    final phone = supabase.auth.currentUser?.phone?.trim() ?? '';
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
      children: [
        glass(Padding(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(color: s.primaryContainer.withValues(alpha: .72), borderRadius: BorderRadius.circular(30)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.account_circle_outlined, size: 15, color: s.primary),
                  const SizedBox(width: 6),
                  Text('حساب کاربری من', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: s.primary)),
                ]),
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: showAvatarPreview,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [s.primary, s.tertiary, s.primary.withValues(alpha: .45)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    boxShadow: [BoxShadow(color: s.primary.withValues(alpha: .22), blurRadius: 22, spreadRadius: 1)],
                  ),
                  child: CircleAvatar(
                    radius: 58,
                    backgroundColor: s.surfaceContainerHighest,
                    // Render the image as a child so a broken remote URL
                    // cannot leave a blank avatar with no recovery affordance.
                    backgroundImage: null,
                    child: profileAvatarUrl.startsWith('emoji:')
                        ? Text(profileAvatarUrl.substring(6), style: const TextStyle(fontSize: 58))
                        : avatarImage == null
                            ? Icon(Icons.person_rounded, size: 58, color: s.onSurfaceVariant)
                            : ClipOval(
                                child: SizedBox(
                                  width: 116,
                                  height: 116,
                                  child: Image(
                                    image: avatarImage!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      if (profileAvatarFallbackUrl.isNotEmpty &&
                                          profileAvatarFallbackUrl != profileAvatarUrl) {
                                        return Image.network(
                                          profileAvatarFallbackUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.person_rounded,
                                            size: 58,
                                            color: s.onSurfaceVariant,
                                          ),
                                        );
                                      }
                                      return Icon(
                                        Icons.person_rounded,
                                        size: 58,
                                        color: s.onSurfaceVariant,
                                      );
                                    },
                                  ),
                                ),
                              ),
                  ),
                ),
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: Material(
                    color: s.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: changeAvatar,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(child: Text(display, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
              if (verified) ...[const SizedBox(width: 6), Icon(Icons.verified_rounded, color: s.primary, size: 22)],
            ]),
            if (un.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: s.surfaceContainerHighest.withValues(alpha: .65), borderRadius: BorderRadius.circular(30)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('@$un', textDirection: TextDirection.ltr, style: TextStyle(color: s.primary, fontWeight: FontWeight.w800, letterSpacing: .2)),
                  const SizedBox(width: 7),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () { Clipboard.setData(ClipboardData(text: '@$un')); showMsg(context, 'آیدی کپی شد.'); },
                    child: Padding(padding: const EdgeInsets.all(3), child: Icon(Icons.copy_rounded, size: 15, color: s.onSurfaceVariant)),
                  ),
                ]),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text('هنوز آیدی تنظیم نشده', style: TextStyle(color: s.onSurfaceVariant, fontSize: 12)),
            ],
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: s.primaryContainer.withValues(alpha: .42),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: s.primary.withValues(alpha: .18)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(Icons.auto_awesome_rounded, size: 19, color: s.primary),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('درباره من', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900))),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'ویرایش بیو',
                    onPressed: editProfile,
                    icon: Icon(Icons.edit_outlined, color: s.primary, size: 19),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(
                  b.isEmpty ? 'چند کلمه درباره خودت بنویس تا دیگران بهتر بشناسنت.' : b,
                  textAlign: TextAlign.start,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(color: b.isEmpty ? s.onSurfaceVariant : s.onSurface, height: 1.65, fontSize: 14),
                ),
                if (b.isEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: editProfile,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('نوشتن بیو'),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: editProfile,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('ویرایش پروفایل', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: showProfileQr,
                  icon: const Icon(Icons.qr_code_rounded, size: 19),
                  label: const Text('QR پروفایل'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: switchAccount,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 19),
                  label: const Text('تغییر حساب'),
                ),
              ),
            ]),
          ]),
        )),
        const SizedBox(height: 20),
        Row(children: [
          Icon(Icons.manage_accounts_rounded, color: s.primary, size: 22),
          const SizedBox(width: 8),
          const Text('مدیریت حساب و دسترسی‌ها', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 10),
        glass(Column(children: [
          if (email.isNotEmpty || phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('اطلاعات حساب', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: s.onSurface)),
                const SizedBox(height: 10),
                if (email.isNotEmpty) Row(children: [
                  Icon(Icons.email_outlined, size: 19, color: s.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(email, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr)),
                ]),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.phone_outlined, size: 19, color: s.primary),
                    const SizedBox(width: 10),
                    Text(phone, textDirection: TextDirection.ltr),
                  ]),
                ],
              ]),
            ),
          if (email.isNotEmpty || phone.isNotEmpty) const Divider(height: 1),
          ListTile(
            leading: CircleAvatar(backgroundColor: s.primaryContainer, child: Icon(Icons.person_add_alt_1_rounded, color: s.primary)),
            title: const Text('حساب‌ها', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('مدیریت و افزودن حساب‌های دیگر'),
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
            leading: CircleAvatar(backgroundColor: s.primaryContainer, child: Icon(Icons.people_alt_rounded, color: s.primary)),
            title: const Text('شخصی و مخاطبین', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('دسترسی به مخاطبین و مدیریت ارتباط‌ها'),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: widget.onOpenContacts ?? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ContactsToolsPage()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: CircleAvatar(backgroundColor: s.primaryContainer, child: Icon(Icons.settings_rounded, color: s.primary)),
            title: const Text('تنظیمات حساب کاربری', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('حریم خصوصی، اعلان‌ها، ظاهر و تنظیمات برنامه'),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfessionalSettingsPage())),
          ),
          const Divider(height: 1),
          ListTile(
            leading: CircleAvatar(backgroundColor: s.primaryContainer, child: Icon(Icons.palette_rounded, color: s.primary)),
            title: const Text('شخصی‌سازی چت', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('پس‌زمینه و ظاهر گفتگوها'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatBackgroundPage())),
          ),
          const Divider(height: 1),
          ListTile(
            leading: CircleAvatar(backgroundColor: s.primaryContainer, child: Icon(Icons.bookmark_rounded, color: s.primary)),
            title: const Text('پیام‌های ذخیره‌شده', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('دسترسی سریع به پیام‌های مهم'),
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
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>LoginPage(addAccount:true)));
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
