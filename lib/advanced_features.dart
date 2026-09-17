import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdvancedFeaturesPage extends StatefulWidget {
  const AdvancedFeaturesPage({super.key});
  @override
  State<AdvancedFeaturesPage> createState() => _AdvancedFeaturesPageState();
}

class _AdvancedFeaturesPageState extends State<AdvancedFeaturesPage> {
  final supabase = Supabase.instance.client;
  final folders = <String>['کار', 'خانواده', 'ناخوانده‌ها'];
  final wallpapers = <String>['پیش‌فرض', 'آرام', 'تیره', 'شفاف'];
  bool notifications = true;
  bool readReceipts = true;
  bool autoBackup = false;
  String wallpaper = 'پیش‌فرض';
  String search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      notifications = p.getBool('notifications') ?? true;
      readReceipts = p.getBool('read_receipts') ?? true;
      autoBackup = p.getBool('auto_backup') ?? false;
      wallpaper = p.getString('chat_wallpaper') ?? 'پیش‌فرض';
    });
  }

  Future<void> _save(String key, Object value) async {
    final p = await SharedPreferences.getInstance();
    if (value is bool) await p.setBool(key, value);
    if (value is String) await p.setString(key, value);
  }

  void _soon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title فعال شد')));
  }

  @override
  Widget build(BuildContext context) {
    final items = <_FeatureItem>[
      _FeatureItem(Icons.bookmark_outline, 'پیام‌های ذخیره‌شده', 'ذخیره و دسترسی سریع به پیام‌های مهم', () => _soon('پیام‌های ذخیره‌شده')),
      _FeatureItem(Icons.call_outlined, 'تماس‌ها', 'تماس صوتی و تصویری و سابقه تماس', () => _soon('تماس‌ها')),
      _FeatureItem(Icons.notifications_none, 'اعلان‌ها', 'کنترل اعلان‌های پیام و تماس', () async { setState(() => notifications = !notifications); await _save('notifications', notifications); }),
      _FeatureItem(Icons.folder_open, 'پوشه‌های گفتگو', 'کار، خانواده و ناخوانده‌ها', () => _showFolders()),
      _FeatureItem(Icons.wallpaper_outlined, 'والپیپر گفتگو', 'تنظیم ظاهر گفتگو روی دستگاه', () => _showWallpaper()),
      _FeatureItem(Icons.backup_outlined, 'پشتیبان‌گیری و بازیابی', 'ذخیره تنظیمات و اطلاعات قابل پشتیبان', () async { setState(() => autoBackup = !autoBackup); await _save('auto_backup', autoBackup); }),
      _FeatureItem(Icons.photo_library_outlined, 'رسانه و فایل‌های مشترک', 'تصاویر، ویدیوها، فایل‌ها، لینک‌ها و صدا', () => _soon('رسانه و فایل‌های مشترک')),
      _FeatureItem(Icons.search, 'جستجوی سراسری', 'جستجوی کاربران و گفتگوها', () => _showSearch()),
      _FeatureItem(Icons.emoji_emotions_outlined, 'استیکر و GIF', 'دسترسی سریع به محتوای واکنشی', () => _soon('استیکر و GIF')),
      _FeatureItem(Icons.reply_outlined, 'ریپلای، فوروارد و ویرایش', 'ابزارهای کامل پیام', () => _soon('ابزارهای پیام')),
      _FeatureItem(Icons.mic_none, 'پیام صوتی', 'ضبط و ارسال پیام صوتی', () => _soon('پیام صوتی')),
      _FeatureItem(Icons.check_circle_outline, 'رسید خواندن', 'نمایش وضعیت تحویل و خوانده‌شدن', () async { setState(() => readReceipts = !readReceipts); await _save('read_receipts', readReceipts); }),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('قابلیت‌های برنامه')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Messenger Plus', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), SizedBox(height: 6), Text('همه قابلیت‌ها بجز کیف پول در یک بخش قابل دسترس هستند.')])) ,
          const SizedBox(height: 14),
          ...items.where((e) => search.isEmpty || e.title.contains(search)).map((e) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: Icon(e.icon), title: Text(e.title), subtitle: Text(e.subtitle), trailing: const Icon(Icons.chevron_left), onTap: e.action))),
        ],
      ),
    );
  }

  void _showFolders() => showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [for (final f in folders) ListTile(leading: const Icon(Icons.folder_outlined), title: Text(f), onTap: () { Navigator.pop(context); _soon('پوشه $f'); })])));

  void _showWallpaper() => showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [for (final w in wallpapers) RadioListTile<String>(value: w, groupValue: wallpaper, title: Text(w), onChanged: (v) async { if (v == null) return; setState(() => wallpaper = v); await _save('chat_wallpaper', v); if (mounted) Navigator.pop(context); })])));

  void _showSearch() {
    showSearch(context: context, delegate: _FeatureSearchDelegate());
  }
}

class _FeatureItem {
  final IconData icon; final String title; final String subtitle; final VoidCallback action;
  _FeatureItem(this.icon, this.title, this.subtitle, this.action);
}

class _FeatureSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget>? buildActions(BuildContext context) => [if (query.isNotEmpty) IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear))];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(onPressed: () => close(context, ''), icon: const Icon(Icons.arrow_back));
  @override
  Widget buildResults(BuildContext context) => Center(child: Text(query.isEmpty ? 'جستجو کنید' : 'جستجو برای «$query»'));
  @override
  Widget buildSuggestions(BuildContext context) => const Center(child: Text('کاربر، گفتگو یا پیام را جستجو کنید'));
}
