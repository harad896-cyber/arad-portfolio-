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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InvitePage()),
                );
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
    final short = clean.substring(0, clean.length >= 8 ? 8 : clean.length);
    return 'ARAD-${short.toUpperCase()}';
  }

  String get inviteText =>
      'سلام 👋\nمن در پیام‌رسان آراد هستم. خوشحال می‌شوم تو هم به آراد بپیوندی.\n\nکد دعوت من: $referralCode\n\nآراد — پیام‌رسان ساده و امن';

  Future<void> shareInvite(BuildContext context) async {
    try {
      await Share.share(inviteText, subject: 'دعوت به آراد');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ارسال دعوت انجام نشد: $e')),
        );
      }
    }
  }

  Future<void> copyInvite(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: inviteText));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('متن دعوت کپی شد.')),
      );
    }
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              children: [
                const CircleAvatar(radius: 34, child: Icon(Icons.person_add_alt_1, size: 34)),
                const SizedBox(height: 18),
                const Text(
                  'دوستت را به آراد دعوت کن',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(
                  'کد دعوت خودت را برای دوستانت بفرست تا بتوانند به آراد بپیوندند.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.confirmation_number_outlined),
              title: const Text('کد دعوت شما'),
              subtitle: Text(
                referralCode,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              trailing: IconButton(
                tooltip: 'کپی',
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: referralCode));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('کد دعوت کپی شد.')),
                    );
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => shareInvite(context),
            icon: const Icon(Icons.share),
            label: const Text('ارسال دعوت برای دوست'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => copyInvite(context),
            icon: const Icon(Icons.content_copy),
            label: const Text('کپی متن دعوت'),
          ),
        ],
      ),
    );
  }
}
