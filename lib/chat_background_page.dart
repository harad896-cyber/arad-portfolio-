import 'package:flutter/material.dart';
import 'main.dart';

class ChatBackgroundPage extends StatefulWidget {
  const ChatBackgroundPage({super.key});
  @override
  State<ChatBackgroundPage> createState() => _ChatBackgroundPageState();
}

class _ChatBackgroundPageState extends State<ChatBackgroundPage> {
  static const colors = <int>[
    0xFFF5F5F7,
    0xFFEAF4FF,
    0xFFEAFBF3,
    0xFFFFF4E5,
    0xFFFFEEF5,
    0xFFF1ECFF,
    0xFF20242B,
    0xFF111827,
  ];

  @override
  Widget build(BuildContext context) {
    final selected = appTheme.backgroundSeed;
    return Scaffold(
      appBar: AppBar(title: const Text('پس‌زمینه چت')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Color(selected),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('پیش‌نمایش پس‌زمینه پیام‌ها', textAlign: TextAlign.center),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text('رنگ پس‌زمینه', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: colors.map((value) {
              final active = value == selected;
              return GestureDetector(
                onTap: () async {
                  await appTheme.setBackgroundSeed(value);
                  if (mounted) setState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Color(value),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                      width: active ? 3 : 1,
                    ),
                    boxShadow: const [BoxShadow(blurRadius: 8, offset: Offset(0, 3), color: Color(0x22000000))],
                  ),
                  child: active ? Icon(Icons.check_rounded, color: value == 0x20242B || value == 0x111827 ? Colors.white : Colors.black87) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Text('این انتخاب برای همین حساب روی دستگاه ذخیره می‌شود.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
