import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'polish_widgets.dart';
import 'main.dart';

class ChatBackgroundPage extends StatefulWidget {
  const ChatBackgroundPage({super.key});
  @override
  State<ChatBackgroundPage> createState() => _ChatBackgroundPageState();
}

class _ChatBackgroundPageState extends State<ChatBackgroundPage> {
  bool _choosingImage = false;

  Future<void> _chooseGalleryImage() async {
    if (_choosingImage) return;
    setState(() => _choosingImage = true);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 60, maxWidth: 900, maxHeight: 900);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 700 * 1024) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تصویر خیلی بزرگ است؛ عکس کوچک‌تری انتخاب کن.')));
        return;
      }
      await appTheme.setBackgroundImage(base64Encode(bytes));
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('انتخاب تصویر انجام نشد.')));
    } finally {
      if (mounted) setState(() => _choosingImage = false);
    }
  }

  Future<void> _removeGalleryImage() async {
    await appTheme.setBackgroundImage(null);
    if (mounted) setState(() {});
  }
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
              image: appTheme.backgroundImageBase64 == null ? null : DecorationImage(image: MemoryImage(base64Decode(appTheme.backgroundImageBase64!)), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: .12), BlendMode.darken)),
              borderRadius: BorderRadius.circular(kPolishRadius),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(kPolishRadius),
                ),
                child: const Text('پیش‌نمایش پس‌زمینه پیام‌ها', textAlign: TextAlign.center),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _choosingImage ? null : _chooseGalleryImage,
            icon: _choosingImage ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.photo_library_outlined),
            label: Text(_choosingImage ? 'در حال انتخاب...' : 'انتخاب عکس از گالری'),
          ),
          if (appTheme.backgroundImageBase64 != null)
            TextButton.icon(onPressed: _removeGalleryImage, icon: const Icon(Icons.delete_outline), label: const Text('حذف عکس پس‌زمینه')),
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
                  child: active ? Icon(Icons.check_rounded, color: value == 0xFF20242B || value == 0xFF111827 ? Colors.white : Colors.black87) : null,
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
