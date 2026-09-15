import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InviteDrawer extends StatelessWidget {
  const InviteDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 28, child: Icon(Icons.person_add_alt_1)),
                  SizedBox(height: 12),
                  Text('آراد', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4),
                  Text('دعوت از دوستان برای پیوستن به آراد'),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1),
              title: const Text('دعوت به آراد'),
              subtitle: const Text('ارسال دعوت برای یک دوست'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const InvitePage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class InvitePage extends StatelessWidget {
  const InvitePage({super.key});

  String get referralCode {
    final id = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (id.isEmpty) return 'ARAD';
    final clean = id.replaceAll('-', '');
    return 'ARAD-${clean.toUpperCase()}';
  }

  String get inviteLink =>
      'https://bkbdcqequyvubjmrbpqo.supabase.co/functions/v1/invite-redirect?code=${Uri.encodeComponent(referralCode)}';

  String get inviteText =>
      'سلام 👋\nمن در پیام‌رسان آراد هستم. خوشحال می‌شوم تو هم به آراد بپیوندی.\n\nلینک دعوت:\n$inviteLink\n\nکد دعوت: $referralCode\n\nآراد — پیام‌رسان ساده و امن';

  Future<void> shareInvite(BuildContext context) async {
    try {
      await Share.share(inviteText, subject: 'دعوت به آراد');
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ارسال دعوت انجام نشد: $e')));
    }
  }

  Future<void> copyInvite(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: inviteText));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لینک و متن دعوت کپی شد.')));
  }

  Future<void> copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: inviteLink));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لینک دعوت کپی شد.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دعوت به آراد')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: Theme.of(context).colorScheme.primaryContainer),
            child: const Column(
              children: [
                CircleAvatar(radius: 34, child: Icon(Icons.person_add_alt_1, size: 34)),
                SizedBox(height: 18),
                Text('دوستت را به آراد دعوت کن', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                SizedBox(height: 10),
                Text('لینک دعوت را بفرست تا دوستت صفحه دعوت آراد را باز کند.', textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('لینک دعوت شما'),
              subtitle: Text(inviteLink, maxLines: 3, overflow: TextOverflow.ellipsis),
              trailing: IconButton(icon: const Icon(Icons.copy), onPressed: () => copyLink(context)),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.confirmation_number_outlined),
              title: const Text('کد دعوت شما'),
              subtitle: Text(referralCode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              trailing: IconButton(icon: const Icon(Icons.copy), onPressed: () async {
                await Clipboard.setData(ClipboardData(text: referralCode));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کد دعوت کپی شد.')));
              }),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: () => shareInvite(context), icon: const Icon(Icons.share), label: const Text('ارسال دعوت برای دوست')),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () => copyInvite(context), icon: const Icon(Icons.content_copy), label: const Text('کپی متن دعوت')),
        ],
      ),
    );
  }
}
