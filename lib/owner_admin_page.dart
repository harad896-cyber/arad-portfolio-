import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'polish_widgets.dart';

class OwnerAdminPage extends StatefulWidget {
  const OwnerAdminPage({super.key});

  @override
  State<OwnerAdminPage> createState() => _OwnerAdminPageState();
}

class _OwnerAdminPageState extends State<OwnerAdminPage> {
  List<Map<String, dynamic>> users = [];
  Set<String> banned = <String>{};
  bool loading = true;
  String query = '';

  bool get isOwner =>
      (supabase.auth.currentUser?.email ?? '').trim().toLowerCase() ==
      ownerEmail.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      if (!isOwner) {
        if (mounted) setState(() => loading = false);
        return;
      }
      final data = await supabase
          .from('profiles')
          .select('id,display_name,username,avatar_url,is_verified,is_owner,joined_at')
          .order('display_name');
      final banRows = await supabase.rpc('owner_list_app_bans');
      final nextBanned = <String>{
        for (final row in List<Map<String, dynamic>>.from(banRows as List))
          '${row['user_id']}',
      };
      if (mounted) {
        setState(() {
          users = List<Map<String, dynamic>>.from(data);
          banned = nextBanned;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        showMsg(context, 'بارگذاری مدیریت مالک ناموفق بود: $e');
      }
    }
  }

  Future<void> setVerified(Map<String, dynamic> user, bool value) async {
    try {
      await supabase.rpc('owner_set_verification', params: {
        'p_user_id': user['id'],
        'p_verified': value,
      });
      await load();
      if (mounted) showMsg(context, value ? 'تیک آبی فعال شد.' : 'تیک آبی برداشته شد.');
    } catch (e) {
      if (mounted) showMsg(context, 'تغییر تیک آبی ناموفق بود: $e');
    }
  }

  Future<void> setBanned(Map<String, dynamic> user, bool value) async {
    if ('${user['id']}' == supabase.auth.currentUser?.id) {
      showMsg(context, 'مالک نمی‌تواند خودش را محروم کند.');
      return;
    }
    String? reason;
    if (value) {
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          final c = TextEditingController();
          return AlertDialog(
            title: const Text('محروم کردن کاربر'),
            content: TextField(
              controller: c,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'دلیل محرومیت (اختیاری)',
                hintText: 'مثلاً نقض قوانین برنامه',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('لغو'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, c.text.trim()),
                child: const Text('محروم کن'),
              ),
            ],
          );
        },
      );
      if (reason == null) return;
    }
    try {
      await supabase.rpc('owner_set_app_ban', params: {
        'p_user_id': user['id'],
        'p_banned': value,
        'p_reason': reason,
      });
      await load();
      if (mounted) showMsg(context, value ? 'کاربر از ورود به برنامه محروم شد.' : 'محرومیت کاربر برداشته شد.');
    } catch (e) {
      if (mounted) showMsg(context, 'تغییر محرومیت ناموفق بود: $e');
    }
  }

  List<Map<String, dynamic>> get filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return users;
    return users.where((u) {
      final name = '${u['display_name'] ?? ''}'.toLowerCase();
      final username = '${u['username'] ?? ''}'.toLowerCase();
      return name.contains(q) || username.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('مدیریت مالک')),
        body: const Center(child: Text('این بخش فقط برای مالک برنامه فعال است.')),
      );
    }
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت مالک'),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: loading
          ? const AppSkeletonList(count: 7)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: TextField(
                    onChanged: (v) => setState(() => query = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'جستجوی نام یا آیدی کاربر',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings_rounded, color: s.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'مالک می‌تواند تیک آبی را فعال/غیرفعال کند و دسترسی کاربر به برنامه را قطع یا دوباره فعال کند.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('کاربری پیدا نشد.'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final u = filtered[i];
                            final id = '${u['id']}';
                            final isUserOwner = u['is_owner'] == true;
                            final isVerified = u['is_verified'] == true;
                            final isBanned = banned.contains(id);
                            return Card(
                              child: ListTile(
                                leading: avatar(u),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${u['display_name'] ?? 'کاربر'}',
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isVerified) ...[
                                      const SizedBox(width: 5),
                                      Icon(Icons.verified_rounded, color: s.primary, size: 19),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  '@${u['username'] ?? ''}${isUserOwner ? ' • مالک' : ''}${isBanned ? ' • محروم' : ''}',
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'verify') setVerified(u, !isVerified);
                                    if (action == 'ban') setBanned(u, !isBanned);
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'verify',
                                      child: Row(
                                        children: [
                                          Icon(Icons.verified_rounded, color: s.primary),
                                          const SizedBox(width: 10),
                                          Text(isVerified ? 'برداشتن تیک آبی' : 'گذاشتن تیک آبی'),
                                        ],
                                      ),
                                    ),
                                    if (!isUserOwner)
                                      PopupMenuItem(
                                        value: 'ban',
                                        child: Row(
                                          children: [
                                            Icon(isBanned ? Icons.lock_open_rounded : Icons.block_rounded, color: s.error),
                                            const SizedBox(width: 10),
                                            Text(isBanned ? 'رفع محرومیت' : 'محروم کردن از برنامه'),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
