import 'package:flutter/material.dart';
import 'advanced_features.dart';
import 'chat_background_page.dart';
import 'notifications_page.dart';

/// Entry point for features that have a real screen/handler.
/// Unsupported items are deliberately omitted instead of pretending to be enabled.
class MessengerPlusPage extends StatelessWidget {
  const MessengerPlusPage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final features = <({IconData icon, String title, String subtitle, Widget page})>[
      (
        icon: Icons.notifications_active_outlined,
        title: 'اعلان‌ها و پیام‌های خوانده‌نشده',
        subtitle: 'مشاهده گفتگوهای دارای پیام خوانده‌نشده',
        page: const NotificationsPage(),
      ),
      (
        icon: Icons.folder_copy_outlined,
        title: 'پوشه‌های گفتگو',
        subtitle: 'ساخت و مدیریت پوشه‌های شخصی گفتگو',
        page: const ChatFolderManagerPage(),
      ),
      (
        icon: Icons.timer_outlined,
        title: 'حذف خودکار پیام‌ها',
        subtitle: 'تنظیم زمان حذف خودکار برای گفتگوها',
        page: const MessageAutoDeletePage(),
      ),
      (
        icon: Icons.wallpaper_outlined,
        title: 'پس‌زمینهٔ گفتگو',
        subtitle: 'انتخاب یا حذف پس‌زمینهٔ گفتگو',
        page: const ChatBackgroundPage(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('قابلیت‌های برنامه')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'قابلیت‌های فعال',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...features.map((feature) => Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(feature.icon),
              ),
              title: Text(
                feature.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(feature.subtitle),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => _open(context, feature.page),
            ),
          )),
          const SizedBox(height: 12),
          Text(
            'گزینه‌هایی که هنوز به عملکرد واقعی وصل نشده‌اند، در این فهرست نمایش داده نمی‌شوند.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
