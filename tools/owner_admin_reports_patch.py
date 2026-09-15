from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# Expose the owner dashboard from the owner's home screen only.
needle = "return snapshot.data! ? const HomePage() : const ProfileSetupPage();"
if needle in s and 'class OwnerAwareHomePage' not in s:
    s = s.replace(needle, "return snapshot.data! ? const OwnerAwareHomePage() : const ProfileSetupPage();", 1)

# Add a report flow to the existing message action sheet.
chat_start = s.index('class _ChatPageState extends State<ChatPage> {')
chat_end = s.index('class ProfilePage extends StatefulWidget {', chat_start)
chat = s[chat_start:chat_end]

report_helper = r'''  Future<void> reportMessage(Map<String, dynamic> message) async {
    const reasons = <String, String>{
      'spam': 'اسپم یا تبلیغات ناخواسته',
      'abuse': 'توهین یا آزار',
      'scam': 'کلاهبرداری یا فریب',
      'violence': 'خشونت یا تهدید',
      'adult': 'محتوای نامناسب',
      'other': 'سایر',
    };
    String selected = 'spam';
    final details = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: const Text('گزارش پیام', style: TextStyle(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(alignment: Alignment.centerRight, child: Text('دلیل گزارش را انتخاب کنید:', style: TextStyle(fontWeight: FontWeight.w700))),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selected,
              items: reasons.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) { if (v != null) setDialog(() => selected = v); },
              decoration: const InputDecoration(labelText: 'دلیل'),
            ),
            const SizedBox(height: 10),
            TextField(controller: details, maxLines: 3, decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)', hintText: 'اگر لازم است توضیح بیشتری بدهید')),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('ارسال گزارش')),
          ],
        ),
      ),
    );
    if (ok != true) { details.dispose(); return; }
    try {
      await supabase.rpc('submit_message_report', params: {
        'p_message_id': '${message['id']}',
        'p_reason': selected,
        'p_details': details.text.trim(),
      });
      if (mounted) showMsg(context, 'گزارش شما برای پشتیبانی ارسال شد.');
    } on PostgrestException catch (e) {
      if (mounted) showMsg(context, e.message == 'Already reported' ? 'این پیام را قبلاً گزارش کرده‌اید.' : 'ارسال گزارش ناموفق بود.');
    } catch (_) {
      if (mounted) showMsg(context, 'ارسال گزارش ناموفق بود.');
    } finally {
      details.dispose();
    }
  }

'''
if 'Future<void> reportMessage(Map<String, dynamic> message)' not in chat:
    marker = '  @override\n  void initState()'
    if marker not in chat:
        raise SystemExit('Chat initState marker not found')
    chat = chat.replace(marker, report_helper + marker, 1)

# Add a report item to the existing showMessageActions method without replacing its other actions.
if 'Future<void> showMessageActions' in chat and "title: const Text('گزارش پیام')" not in chat:
    m = re.search(r'  Future<void> showMessageActions\(Map<String, dynamic> m\) async \{', chat)
    if not m:
        raise SystemExit('showMessageActions signature not found')
    start = m.start()
    brace = chat.find('{', m.start())
    depth = 0
    end = None
    for i in range(brace, len(chat)):
        if chat[i] == '{': depth += 1
        elif chat[i] == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        raise SystemExit('Could not locate showMessageActions end')
    method = chat[start:end]
    # Insert before the first closing of a ListTile list when possible; otherwise append a small modal action after the existing sheet.
    if 'showModalBottomSheet' in method and 'children:' in method:
        pos = method.rfind(']')
        if pos > 0:
            action = ",\n              ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('گزارش پیام'), onTap: () { Navigator.pop(context); reportMessage(m); })"
            method = method[:pos] + action + method[pos:]
            chat = chat[:start] + method + chat[end:]
        else:
            raise SystemExit('Could not inject report action')
    else:
        raise SystemExit('showMessageActions structure not recognized')

s = s[:chat_start] + chat + s[chat_end:]

# Owner dashboard UI. Access is still enforced by SECURITY DEFINER RPCs; the UI gate is only convenience.
if 'class AdminDashboardPage extends StatefulWidget' not in s:
    s += r'''

class OwnerAwareHomePage extends StatelessWidget {
  const OwnerAwareHomePage({super.key});

  Future<bool> _isAdmin() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await supabase.from('admin_users').select('user_id').eq('user_id', uid).maybeSingle();
    return row != null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAdmin(),
      builder: (context, snap) {
        if (snap.data != true) return const HomePage();
        return Stack(children: [
          const HomePage(),
          Positioned(
            right: 16,
            bottom: 88,
            child: FloatingActionButton.small(
              heroTag: 'owner-dashboard',
              tooltip: 'مدیریت مالک',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardPage())),
              child: const Icon(Icons.admin_panel_settings_rounded),
            ),
          ),
        ]);
      },
    );
  }
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  Map<String, dynamic> stats = {};
  List<Map<String, dynamic>> reports = [];
  bool busy = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final st = await supabase.rpc('owner_dashboard_stats');
      final rr = await supabase.rpc('owner_recent_reports', params: {'p_limit': 100});
      if (!mounted) return;
      setState(() {
        stats = Map<String, dynamic>.from(st as Map);
        reports = List<Map<String, dynamic>>.from(rr as List);
      });
    } catch (e) {
      if (mounted) showMsg(context, 'دریافت گزارش مالک ناموفق بود.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resolve(String id, String status) async {
    try {
      await supabase.rpc('resolve_message_report', params: {'p_report_id': id, 'p_status': status});
      await load();
    } catch (_) {
      if (mounted) showMsg(context, 'تغییر وضعیت گزارش ناموفق بود.');
    }
  }

  Widget stat(String title, String key, IconData icon) {
    return Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
      Icon(icon, size: 27, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 6),
      Text('${stats[key] ?? 0}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
    ]))));
  }

  String reasonLabel(String value) {
    const map = {'spam':'اسپم','abuse':'توهین/آزار','scam':'کلاهبرداری','violence':'تهدید/خشونت','adult':'محتوای نامناسب','other':'سایر'};
    return map[value] ?? value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مدیریت مالک'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))]),
      body: busy && stats.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(20)), child: const Row(children: [
                  Icon(Icons.admin_panel_settings_rounded, size: 34), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('پنل مالک Arad', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), SizedBox(height: 3), Text('آمار کاربران، گروه‌ها، کانال‌ها و گزارش‌های پیام', style: TextStyle(fontSize: 12.5))]),
                ])),
                const SizedBox(height: 14),
                Row(children: [stat('کاربران', 'users', Icons.people_alt_rounded), const SizedBox(width: 8), stat('گروه‌ها', 'groups', Icons.groups_rounded), const SizedBox(width: 8), stat('کانال‌ها', 'channels', Icons.campaign_rounded)]),
                const SizedBox(height: 8),
                Row(children: [stat('پیام‌ها', 'messages', Icons.chat_bubble_rounded), const SizedBox(width: 8), stat('گزارش باز', 'open_reports', Icons.flag_rounded), const SizedBox(width: 8), stat('کل گزارش', 'total_reports', Icons.assessment_rounded)]),
                const SizedBox(height: 20),
                const Text('گزارش‌های پیام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (reports.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('گزارشی ثبت نشده است.')))),
                ...reports.map((r) => Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text(reasonLabel('${r['reason'] ?? 'other'}'), style: const TextStyle(fontWeight: FontWeight.w900))), Chip(label: Text('${r['status']}'))]),
                  const SizedBox(height: 4),
                  Text('فرستنده: ${r['sender_name'] ?? 'کاربر'}  •  گزارش‌دهنده: ${r['reporter_name'] ?? 'کاربر'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('${r['message_body'] ?? '[فایل/رسانه]'}', maxLines: 4, overflow: TextOverflow.ellipsis),
                  if ('${r['details'] ?? ''}'.trim().isNotEmpty) ...[const SizedBox(height: 6), Text('توضیح: ${r['details']}', style: const TextStyle(fontSize: 12.5))],
                  const SizedBox(height: 8),
                  Row(children: [
                    if (r['status'] == 'open') TextButton.icon(onPressed: () => resolve('${r['id']}', 'reviewing'), icon: const Icon(Icons.visibility_rounded), label: const Text('در حال بررسی')),
                    if (r['status'] != 'resolved') TextButton.icon(onPressed: () => resolve('${r['id']}', 'resolved'), icon: const Icon(Icons.check_circle_outline_rounded), label: const Text('حل شد')),
                    if (r['status'] != 'dismissed') TextButton.icon(onPressed: () => resolve('${r['id']}', 'dismissed'), icon: const Icon(Icons.close_rounded), label: const Text('رد شد')),
                  ]),
                ]))))),
              ]),
            ),
    );
  }
}
'''

p.write_text(s, encoding='utf-8')
