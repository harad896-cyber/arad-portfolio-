import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessengerPlusPage extends StatefulWidget {
  const MessengerPlusPage({super.key});
  @override State<MessengerPlusPage> createState() => _MessengerPlusPageState();
}

class _MessengerPlusPageState extends State<MessengerPlusPage> {
  bool notifications = true;
  bool readReceipts = true;
  bool autoBackup = false;
  String wallpaper = 'پیش‌فرض';

  Future<void> save(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  void toast(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override Widget build(BuildContext context) {
    final features = <Map<String, String>>[
      {'title': 'پیام‌های ذخیره‌شده', 'subtitle': 'ذخیره پیام‌های مهم'},
      {'title': 'تماس‌ها', 'subtitle': 'صوتی، تصویری و سابقه تماس'},
      {'title': 'اعلان‌ها', 'subtitle': 'کنترل اعلان‌ها'},
      {'title': 'پوشه‌های گفتگو', 'subtitle': 'کار، خانواده، ناخوانده‌ها'},
      {'title': 'والپیپر گفتگو', 'subtitle': 'تنظیم ظاهر گفتگو'},
      {'title': 'پشتیبان‌گیری و بازیابی', 'subtitle': 'پشتیبان خودکار'},
      {'title': 'رسانه و فایل‌های مشترک', 'subtitle': 'عکس، ویدیو، فایل، لینک و صدا'},
      {'title': 'جستجوی سراسری', 'subtitle': 'کاربر، گفتگو و پیام'},
      {'title': 'استیکر و GIF', 'subtitle': 'محتوای واکنشی'},
      {'title': 'ریپلای، فوروارد و ویرایش', 'subtitle': 'ابزارهای پیام'},
      {'title': 'پیام صوتی', 'subtitle': 'ضبط و ارسال ویس'},
      {'title': 'رسید خواندن', 'subtitle': 'تحویل و خوانده‌شدن'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('قابلیت‌های برنامه')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Messenger Plus\nهمه قابلیت‌ها بجز کیف پول', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
          ...features.map((feature) {
            final title = feature['title']!;
            return Card(child: ListTile(
              title: Text(title),
              subtitle: Text(feature['subtitle']!),
              trailing: const Icon(Icons.chevron_left),
              onTap: () async {
                if (title == 'اعلان‌ها') {
                  setState(() => notifications = !notifications);
                  await save('notifications', notifications);
                } else if (title == 'رسید خواندن') {
                  setState(() => readReceipts = !readReceipts);
                  await save('read_receipts', readReceipts);
                } else if (title == 'پشتیبان‌گیری و بازیابی') {
                  setState(() => autoBackup = !autoBackup);
                  await save('auto_backup', autoBackup);
                } else if (title == 'والپیپر گفتگو') {
                  await showModalBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: ['پیش‌فرض', 'آرام', 'تیره', 'شفاف'].map((value) => ListTile(
                        title: Text(value),
                        onTap: () async {
                          setState(() => wallpaper = value);
                          await save('chat_wallpaper', value);
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                      )).toList(),
                    ),
                  );
                } else {
                  toast('$title فعال شد');
                }
              },
            ));
          }),
        ],
      ),
    );
  }
}
