from pathlib import Path
p=Path('lib/main.dart')
s=p.read_text(encoding='utf-8')

# Ensure imports are available.
if "import 'package:image_picker/image_picker.dart';" not in s:
    s=s.replace("import 'package:flutter/services.dart';", "import 'package:flutter/services.dart';\nimport 'package:image_picker/image_picker.dart';", 1)

start=s.index('class _ChatPageState extends State<ChatPage> {')
end=s.index('class ProfilePage extends StatefulWidget {', start)
chat=s[start:end]

if 'Map<String, String> attachmentUrls' not in chat:
    chat=chat.replace('  Map<String, Map<String, dynamic>> senderStats = {};', '  Map<String, Map<String, dynamic>> senderStats = {};\n  Map<String, String> attachmentUrls = {};', 1)

# Load verified flag and media attachments.
chat=chat.replace("select('id,display_name,username,avatar_url')", "select('id,display_name,username,avatar_url,is_verified')", 1)
anchor="""      final ids = loaded.map((m) => '${m['id']}').toList();
"""
insert="""      attachmentUrls = {};
      if (ids.isNotEmpty) {
        try {
          final aa = await supabase.from('message_attachments').select('message_id,storage_path,mime_type').inFilter('message_id', ids);
          for (final a in List<Map<String, dynamic>>.from(aa)) {
            final path = '${a['storage_path'] ?? ''}';
            final mime = '${a['mime_type'] ?? ''}'.toLowerCase();
            if (path.isNotEmpty && (mime.isEmpty || mime.startsWith('image'))) {
              try { attachmentUrls['${a['message_id']}'] = await supabase.storage.from('chat-media').createSignedUrl(path, 3600); } catch (_) {}
            }
          }
        } catch (_) {}
      }

"""+anchor
chat=chat.replace(anchor,insert,1)

# Make image sending robust and visible after upload.
old="""      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final path = '${widget.id}/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      await supabase.storage.from('chat-media').uploadBinary(path, bytes);
"""
new="""      final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 1800, maxHeight: 1800);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) throw Exception('فایل تصویر خالی است');
      final safeName = image.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = '${widget.id}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      await supabase.storage.from('chat-media').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: false));
"""
chat=chat.replace(old,new,1)

# Replace image placeholder with actual signed image when available.
old_img="""if (m['message_type'] == 'image') const Padding(padding: EdgeInsets.only(bottom: 5), child: Icon(Icons.image_rounded, size: 42)),"""
new_img="""if (m['message_type'] == 'image') Padding(
  padding: const EdgeInsets.only(bottom: 7),
  child: attachmentUrls['${m['id']}'] != null
      ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(attachmentUrls['${m['id']}']!, width: 250, height: 250, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 42)))
      : const SizedBox(width: 250, height: 120, child: Center(child: CircularProgressIndicator())),
),"""
chat=chat.replace(old_img,new_img,1)

# Verified badge beside sender name.
old_name="""Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),"""
new_name="""Row(mainAxisSize: MainAxisSize.min, children: [
  Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary))),
  if (p?['is_verified'] == true) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, color: Colors.blue, size: 17)),
]),"""
chat=chat.replace(old_name,new_name,1)

s=s[:start]+chat+s[end:]

# Add verified badge to profile header.
old_profile="""          Text('${p['display_name'] ?? ''}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text('@${p['username'] ?? ''}'),
"""
new_profile="""          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(child: Text('${p['display_name'] ?? ''}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            if (p['is_verified'] == true) const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.verified_rounded, color: Colors.blue, size: 22)),
          ]),
          Text('@${p['username'] ?? ''}'),
"""
s=s.replace(old_profile,new_profile,1)

# Real support action: create/find a direct conversation with the configured owner account.
if 'class SupportPage extends StatelessWidget' not in s:
    support=r'''

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  Future<void> start(BuildContext context) async {
    try {
      final cid = await supabase.rpc('start_support_chat');
      if (!context.mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatPage(id: '', title: 'پشتیبانی Arad')));
      // Replace the temporary route with the real conversation id immediately.
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(id: '$cid', title: 'پشتیبانی Arad')));
    } catch (e) {
      if (context.mounted) showMsg(context, 'اتصال به پشتیبانی انجام نشد: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('پشتیبانی Arad')),
    body: ListView(padding: const EdgeInsets.all(22), children: [
      Center(child: Container(width: 86, height: 86, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, shape: BoxShape.circle), child: Icon(Icons.support_agent_rounded, size: 46, color: Theme.of(context).colorScheme.primary))),
      const SizedBox(height: 20),
      const Text('ارتباط مستقیم با پشتیبانی', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      const Text('پیام شما مستقیماً به حساب پشتیبانی مالک Arad ارسال می‌شود. برای بررسی باگ، مشکل ورود، ارسال تصویر یا گزارش خطا همین‌جا پیام بفرستید.', textAlign: TextAlign.center),
      const SizedBox(height: 22),
      FilledButton.icon(onPressed: () => start(context), icon: const Icon(Icons.chat_rounded), label: const Text('شروع گفتگو با پشتیبانی')),
      const SizedBox(height: 12),
      const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('برای گزارش باگ، مدل گوشی، نسخه برنامه و شرح دقیق مشکل را بنویسید.'))),
    ]),
  );
}
'''
    s += support

# Replace the generic support tile with the real support page.
s=s.replace("ListTile(leading: const Icon(Icons.support_agent_outlined), title: const Text('پشتیبانی'), subtitle: const Text('راهنمایی و ارتباط با پشتیبانی'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'پشتیبانی', icon: Icons.support_agent_outlined)))),", "ListTile(leading: const Icon(Icons.support_agent_outlined), title: const Text('پشتیبانی'), subtitle: const Text('ارتباط مستقیم با پشتیبانی مالک Arad'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportPage()))),", 1)

# Add useful settings entries without removing existing options.
needle="""          ListTile(leading: const Icon(Icons.support_agent_outlined), title: const Text('پشتیبانی'),"""
extra="""          ListTile(leading: const Icon(Icons.notifications_none_rounded), title: const Text('اعلان‌ها'), subtitle: const Text('مدیریت اعلان‌ها و صدای پیام‌ها'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'اعلان‌ها', icon: Icons.notifications_none_rounded)))),
          ListTile(leading: const Icon(Icons.block_outlined), title: const Text('مسدودشده‌ها'), subtitle: const Text('مدیریت کاربران مسدودشده'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'مسدودشده‌ها', icon: Icons.block_outlined)))),
          ListTile(leading: const Icon(Icons.devices_other_rounded), title: const Text('دستگاه‌ها و نشست‌ها'), subtitle: const Text('بررسی نشست‌های فعال حساب'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'دستگاه‌ها و نشست‌ها', icon: Icons.devices_other_rounded)))),
"""
if extra not in s:
    s=s.replace(needle,extra+needle,1)

p.write_text(s,encoding='utf-8')
