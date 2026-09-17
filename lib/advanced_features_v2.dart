import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessengerPlusPage extends StatefulWidget {
  const MessengerPlusPage({super.key});
  @override
  State<MessengerPlusPage> createState() => _MessengerPlusPageState();
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final features = <List<String>>[
      ['پیام‌های ذخیره‌شده', 'ذخیره پیام‌های مهم'],
      ['تماس‌ها', 'صوتی، تصویری و سابقه تماس'],
      ['اعلان‌ها', 'کنترل اعلان‌ها'],
      ['پوشه‌های گفتگو', 'کار، خانواده، ناخوانده‌ها'],
      ['والپیپر گفتگو', 'تنظیم ظاهر گفتگو'],
      ['پشتیبان‌گیری و بازیابی', 'پشتیبان خودکار'],
      ['رسانه و فایل‌های مشترک', 'عکس، ویدیو، فایل، لینک و صدا'],
      ['جستجوی سراسری', 'کاربر، گفتگو و پیام'],
      ['استیکر و GIF', 'محتوای واکنشی'],
      ['ریپلای، فوروارد و ویرایش', 'ابزارهای پیام'],
      ['پیام صوتی', 'ضبط و ارسال ویس'],
      ['رسید خواندن', 'تحویل و خوانده‌شدن'],
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('قابلیت‌های برنامه')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Messenger Plus\nهمه قابلیت‌ها بجز کیف پول',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ...features.map((feature) {
            return Card(
              child: ListTile(
                title: Text(feature[0]),
                subtitle: Text(feature[1]),
                trailing: const Icon(Icons.chevron_left),
                onTap: () async {
                  final name = feature[0];
                  if (name == 'اعلان‌ها') {
                    setState(() => notifications = !notifications);
                    await save('notifications', notifications);
                  } else if (name == 'رسید خواندن') {
                    setState(() => readReceipts = !readReceipts);
                    await save('read_receipts', readReceipts);
                  } else if (name == 'پشتیبان‌گیری و بازیابی') {
                    setState(() => autoBackup = !autoBackup);
                    await save('auto_backup', autoBackup);
                  } else if (name == 'والپیپر گفتگو') {
                    if (!mounted) return;
                    await showModalBottomSheet<void>(
                      context: context,
                      builder: (sheetContext) {
                        const options = ['پیش‌فرض', 'آرام', 'تیره', 'شفاف'];
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: options.map((value) {
                            return ListTile(
                              title: Text(value),
                              onTap: () async {
                                setState(() => wallpaper = value);
                                await save('chat_wallpaper', value);
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                              },
                            );
                          }).toList(),
                        );
                      },
                    );
                  } else {
                    toast('$name فعال شد');
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
