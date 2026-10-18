import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'polish_widgets.dart';
import 'main.dart';

class ChatBackgroundPage extends StatefulWidget {
  const ChatBackgroundPage({super.key});
  @override
  State<ChatBackgroundPage> createState() => _ChatBackgroundPageState();
}

class _ChatBackgroundPageState extends State<ChatBackgroundPage> with SingleTickerProviderStateMixin {
  bool _choosingImage = false;
  late final AnimationController _previewMotion;

  @override
  void initState() {
    super.initState();
    _previewMotion = AnimationController(vsync: this, duration: const Duration(seconds: 9));
    if (appTheme.backgroundEffects) _previewMotion.repeat(reverse: true);
  }

  @override
  void dispose() {
    _previewMotion.dispose();
    super.dispose();
  }

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
    0xFF11131A,
    0xFF17152B,
    0xFF10202D,
    0xFF20242B,
    0xFF302047,
    0xFF173A45,
    0xFF3B2437,
    0xFF0B1220,
    0xFFF5F5F7,
    0xFFEAF4FF,
    0xFFEAFBF3,
    0xFFFFF4E5,
    0xFFFFEEF5,
    0xFFF1ECFF,
  ];
  static const colorLabels = <int, String>{
    0xFF11131A: 'ذغالی',
    0xFF17152B: 'بنفش شب',
    0xFF10202D: 'آبی نفتی',
    0xFF20242B: 'خاکستری تیره',
    0xFF302047: 'بنفش عمیق',
    0xFF173A45: 'سبز دریایی',
    0xFF3B2437: 'زرشکی تیره',
    0xFF0B1220: 'سرمه‌ای',
    0xFFF5F5F7: 'سفید روشن',
    0xFFEAF4FF: 'آبی روشن',
    0xFFEAFBF3: 'سبز روشن',
    0xFFFFF4E5: 'کرم',
    0xFFFFEEF5: 'صورتی روشن',
    0xFFF1ECFF: 'یاسی روشن',
  };

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
              color: appTheme.backgroundEffects ? null : Color(selected),
              gradient: appTheme.backgroundEffects ? RadialGradient(
                center: const Alignment(-.65, -.75),
                radius: 1.35,
                colors: [Theme.of(context).colorScheme.primary.withValues(alpha: .28), Color(selected)],
              ) : null,
              image: appTheme.backgroundImageBase64 == null ? null : DecorationImage(image: MemoryImage(base64Decode(appTheme.backgroundImageBase64!)), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: .12), BlendMode.darken)),
              borderRadius: BorderRadius.circular(kPolishRadius),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kPolishRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (appTheme.backgroundEffects)
                    AnimatedBuilder(
                      animation: _previewMotion,
                      builder: (context, _) {
                        final t = Curves.easeInOutSine.transform(_previewMotion.value);
                        return Stack(children: [
                          Positioned(
                            top: -70 + t * 22, right: -45 + t * 16, width: 200, height: 200,
                            child: IgnorePointer(child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  Theme.of(context).colorScheme.primary.withValues(alpha: .32),
                                  Theme.of(context).colorScheme.primary.withValues(alpha: .08),
                                  Colors.transparent,
                                ]),
                              ),
                            )),
                          ),
                          Positioned(
                            bottom: -95 + t * 18, left: -45 + t * 12, width: 220, height: 220,
                            child: IgnorePointer(child: DecoratedBox(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  Color(0x4436B8FF), Color(0x1036B8FF), Colors.transparent,
                                ]),
                              ),
                            )),
                          ),
                        ]);
                      },
                    ),
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 280),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: .68),
                        borderRadius: BorderRadius.circular(kPolishRadius),
                        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: .15)),
                      ),
                      child: const Text('پیش‌نمایش پس‌زمینه پیام‌ها', textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _choosingImage ? null : _chooseGalleryImage,
            icon: _choosingImage ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.photo_library_outlined),
            label: Text(_choosingImage ? 'در حال انتخاب...' : 'انتخاب عکس از گالری'),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              value: appTheme.backgroundEffects,
              onChanged: (value) async {
                HapticFeedback.selectionClick();
                await appTheme.setBackgroundEffects(value);
                if (value) {
                  _previewMotion.repeat(reverse: true);
                } else {
                  _previewMotion.stop();
                  _previewMotion.value = 0;
                }
                if (mounted) setState(() {});
              },
              secondary: const Icon(Icons.auto_awesome_rounded),
              title: const Text('افکت نور ملایم'),
              subtitle: const Text('درخشش بنفش و آبی با مصرف سبک؛ هر زمان خواستی خاموشش کن.'),
            ),
          ),
          if (appTheme.backgroundImageBase64 != null)
            TextButton.icon(onPressed: () { HapticFeedback.selectionClick(); _removeGalleryImage(); }, icon: const Icon(Icons.delete_outline), label: const Text('حذف عکس پس‌زمینه')),
          const SizedBox(height: 22),
          const Text('قالب‌های آماده', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('با یک لمس، ظاهر گفتگوها را یکدست کن.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.75,
            children: const [
              _ChatPreset(label: 'بنفش فضایی', colors: [Color(0xFF302047), Color(0xFF11131A)], seed: 0xFF8B5CF6),
              _ChatPreset(label: 'اقیانوس آبی', colors: [Color(0xFF10202D), Color(0xFF0B1220)], seed: 0xFF36B8FF),
              _ChatPreset(label: 'سبز آرام', colors: [Color(0xFF173A45), Color(0xFF11131A)], seed: 0xFF39C6A5),
              _ChatPreset(label: 'رز تیره', colors: [Color(0xFF3B2437), Color(0xFF17152B)], seed: 0xFFFF78B7),
              _ChatPreset(label: 'یاسی روشن', colors: [Color(0xFFF1ECFF), Color(0xFFF6F7FB)], seed: 0xFF8B5CF6),
              _ChatPreset(label: 'سفید مینیمال', colors: [Color(0xFFF5F5F7), Color(0xFFEAF4FF)], seed: 0xFF5264D8),
              _ChatPreset(label: 'غروب گرم', colors: [Color(0xFF552B42), Color(0xFF21172D)], seed: 0xFFFF916D),
              _ChatPreset(label: 'زمردی لوکس', colors: [Color(0xFF123B35), Color(0xFF0C191A)], seed: 0xFF40D6A0),
              _ChatPreset(label: 'گرافیت مدرن', colors: [Color(0xFF303643), Color(0xFF11141B)], seed: 0xFF9AA8C5),
              _ChatPreset(label: 'یخ آبی', colors: [Color(0xFFE6F5FF), Color(0xFFF8FBFF)], seed: 0xFF2586D8),
            ],
          ),
          const SizedBox(height: 22),
          const Text('رنگ پس‌زمینه', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: colors.map((value) {
              final active = value == selected;
              return Tooltip(
                message: active ? '${colorLabels[value]} — انتخاب‌شده' : 'انتخاب ${colorLabels[value]}',
                child: Semantics(
                  button: true,
                  selected: active,
                  label: active ? 'رنگ فعلی: ${colorLabels[value]}' : 'انتخاب رنگ ${colorLabels[value]}',
                  child: GestureDetector(
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await appTheme.setBackgroundSeed(value);
                      if (mounted) setState(() {});
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 58,
                      height: 58,
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
                  ),
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


class _ChatPreset extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final int seed;
  const _ChatPreset({required this.label, required this.colors, required this.seed});

  @override
  Widget build(BuildContext context) {
    final selected = appTheme.backgroundSeed == colors.first.value;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          HapticFeedback.selectionClick();
          await appTheme.setBackgroundSeed(colors.first.value);
          await appTheme.setSeed(seed);
          await appTheme.setBackgroundEffects(true);
        },
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2.5 : 1),
            boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(selected ? Icons.check_circle_rounded : Icons.palette_outlined, color: colors.first.computeLuminance() < .35 ? Colors.white : const Color(0xFF252238), size: 20),
                Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: colors.first.computeLuminance() < .35 ? Colors.white : const Color(0xFF252238))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
