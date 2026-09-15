from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# Add a real Saved Messages page backed by Supabase and protected by RLS.
profile_marker = 'class ProfilePage extends StatefulWidget {'
if profile_marker not in s:
    raise SystemExit('ProfilePage marker not found')

if 'class SavedMessagesPage extends StatefulWidget' not in s:
    page = r'''
class SavedMessagesPage extends StatefulWidget {
  const SavedMessagesPage({super.key});

  @override
  State<SavedMessagesPage> createState() => _SavedMessagesPageState();
}

class _SavedMessagesPageState extends State<SavedMessagesPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;

  Future<void> load() async {
    try {
      final rows = await supabase
          .from('saved_messages')
          .select('id,body,message_type,created_at')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        items = List<Map<String, dynamic>>.from(rows);
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        showMsg(context, 'پیام‌های ذخیره‌شده بارگذاری نشد: $e');
      }
    }
  }

  Future<void> remove(String id) async {
    try {
      await supabase.from('saved_messages').delete().eq('id', id);
      await load();
    } catch (e) {
      if (mounted) showMsg(context, 'حذف پیام ناموفق بود: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('پیام‌های ذخیره‌شده')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.bookmark_border_rounded, size: 64), SizedBox(height: 12), Text('هنوز پیامی ذخیره نکرده‌اید.'), SizedBox(height: 6), Text('روی یک پیام نگه دارید و «ذخیره پیام» را بزنید.')]))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final m = items[i];
                    final type = '${m['message_type'] ?? 'text'}';
                    final body = '${m['body'] ?? ''}';
                    return Card(
                      child: ListTile(
                        leading: Icon(type == 'image' ? Icons.image_rounded : type == 'audio' ? Icons.audiotrack_rounded : Icons.bookmark_rounded),
                        title: Text(body.isEmpty ? (type == 'image' ? 'تصویر' : type == 'audio' ? 'پیام صوتی' : 'پیام') : body, maxLines: 3, overflow: TextOverflow.ellipsis),
                        subtitle: const Text('ذخیره‌شده در Arad Messenger'),
                        trailing: IconButton(tooltip: 'حذف', icon: const Icon(Icons.delete_outline_rounded), onPressed: () => remove('${m['id']}')),
                      ),
                    );
                  },
                ),
    );
  }
}

'''
    s = s.replace(profile_marker, page + profile_marker, 1)

# Add saving to the existing Telegram-style message action sheet.
start = s.index('class _ChatPageState extends State<ChatPage> {')
end = s.index(profile_marker, start)
chat = s[start:end]

if 'Future<void> saveMessage(Map<String, dynamic> message) async {' not in chat:
    method = r'''
  Future<void> saveMessage(Map<String, dynamic> message) async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;
      await supabase.from('saved_messages').insert({
        'user_id': uid,
        'source_message_id': message['id'],
        'body': '${message['body'] ?? ''}',
        'message_type': '${message['message_type'] ?? 'text'}',
      });
      if (mounted) showMsg(context, 'پیام در پیام‌های ذخیره‌شده ذخیره شد.');
    } catch (e) {
      if (mounted) showMsg(context, 'ذخیره پیام ناموفق بود: $e');
    }
  }

'''
    marker = '  Widget _replyPreview(Map<String, dynamic> message) {'
    if marker not in chat:
        raise SystemExit('reply preview marker not found')
    chat = chat.replace(marker, method + marker, 1)

# Insert the save option into the existing message action bottom sheet.
save_tile = r'''              ListTile(
                leading: const Icon(Icons.bookmark_add_outlined),
                title: const Text('ذخیره پیام'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  saveMessage(message);
                },
              ),
'''
copy_tile = "              ListTile(\n                leading: const Icon(Icons.copy_rounded),"
if 'title: const Text(\'ذخیره پیام\')' not in chat:
    if copy_tile not in chat:
        raise SystemExit('copy action marker not found')
    chat = chat.replace(copy_tile, save_tile + copy_tile, 1)

s = s[:start] + chat + s[end:]

# Turn the existing profile placeholder into the real Saved Messages page.
placeholder = "ListTile(leading: const Icon(Icons.bookmark_outline), title: const Text('پیام‌های ذخیره‌شده'), subtitle: const Text('دسترسی سریع به پیام‌های مهم'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'پیام‌های ذخیره‌شده', icon: Icons.bookmark_outline)))),"
replacement = "ListTile(leading: const Icon(Icons.bookmark_outline), title: const Text('پیام‌های ذخیره‌شده'), subtitle: const Text('پیام‌هایی که برای خودتان نگه داشته‌اید'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedMessagesPage()))),"
if placeholder not in s:
    raise SystemExit('saved messages profile tile not found')
s = s.replace(placeholder, replacement, 1)

p.write_text(s, encoding='utf-8')
print('Applied Saved Messages page and message save action')
