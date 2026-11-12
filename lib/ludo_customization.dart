import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LudoLook {
  final int board, avatar, frame, banner, background, charm;
  const LudoLook({this.board = 0, this.avatar = 0, this.frame = 0, this.banner = 0, this.background = 0, this.charm = 0});
  LudoLook copyWith({int? board, int? avatar, int? frame, int? banner, int? background, int? charm}) => LudoLook(
    board: board ?? this.board, avatar: avatar ?? this.avatar, frame: frame ?? this.frame,
    banner: banner ?? this.banner, background: background ?? this.background, charm: charm ?? this.charm,
  );
}

class LudoCustomization {
  LudoCustomization._();
  static final ValueNotifier<LudoLook> current = ValueNotifier(const LudoLook());
  static Future<void>? _loadFuture;
  static const avatars = ['🙂', '😎', '🦁', '🐼', '🐯', '🦊', '🐉', '👑'];
  static const frames = ['طلایی', 'یخی', 'زمردی', 'یاقوتی', 'نئونی', 'نقره‌ای'];
  static const charms = ['⭐', '⚽', '💎', '🔥', '👑', '🧿', '🍀', '🎯'];
  static const banners = ['سلطنتی', 'ورزشگاه', 'شفق', 'اقیانوس', 'غروب', 'کهکشانی'];
  static const backgrounds = ['تیره', 'زمردی', 'آبی', 'بنفش', 'طلایی', 'شب'];
  static const boardNames = ['کلاسیک طلایی', 'زمرد جنگلی', 'اقیانوس', 'سلطنتی', 'غروب', 'نئون شب'];
  static const boardPalettes = <List<Color>>[
    [Color(0xFF102535), Color(0xFF23495B), Color(0xFF0A1724)],
    [Color(0xFF073B2E), Color(0xFF167653), Color(0xFF06251F)],
    [Color(0xFF092D50), Color(0xFF176D91), Color(0xFF071C35)],
    [Color(0xFF26143F), Color(0xFF57318A), Color(0xFF160D2A)],
    [Color(0xFF54243A), Color(0xFFB45B48), Color(0xFF2D1427)],
    [Color(0xFF080F24), Color(0xFF173C55), Color(0xFF090A18)],
  ];
  static const frameColors = <Color>[
    Color(0xFFE8C36C), Color(0xFFB9E8FF), Color(0xFF55D6A4),
    Color(0xFFFF6D85), Color(0xFF6CEBFF), Color(0xFFC7D1DE),
  ];
  static const bannerPalettes = <List<Color>>[
    [Color(0xFF39234F), Color(0xFFC89A45)],
    [Color(0xFF0B5B3D), Color(0xFF55C98B)],
    [Color(0xFF102B55), Color(0xFF49B8C9)],
    [Color(0xFF123E69), Color(0xFF35A6C9)],
    [Color(0xFF743B43), Color(0xFFE6A45C)],
    [Color(0xFF171A3C), Color(0xFF7046A5)],
  ];
  static const backgroundPalettes = <List<Color>>[
    [Color(0xFF101722), Color(0xFF1D2938)],
    [Color(0xFF082B23), Color(0xFF145542)],
    [Color(0xFF0B2945), Color(0xFF174F73)],
    [Color(0xFF24153D), Color(0xFF45256D)],
    [Color(0xFF332719), Color(0xFF76552B)],
    [Color(0xFF090D1A), Color(0xFF20284A)],
  ];

  static Future<void> load() => _loadFuture ??= _loadSavedLook();

  static Future<void> _loadSavedLook() async {
    try {
      final p = await SharedPreferences.getInstance();
      current.value = LudoLook(
        board: (p.getInt('ludo_board_skin') ?? 0).clamp(0, boardNames.length - 1).toInt(),
        avatar: (p.getInt('ludo_avatar') ?? 0).clamp(0, avatars.length - 1).toInt(),
        frame: (p.getInt('ludo_avatar_frame') ?? 0).clamp(0, frames.length - 1).toInt(),
        banner: (p.getInt('ludo_profile_banner') ?? 0).clamp(0, banners.length - 1).toInt(),
        background: (p.getInt('ludo_profile_background') ?? 0).clamp(0, backgrounds.length - 1).toInt(),
        charm: (p.getInt('ludo_avatar_charm') ?? 0).clamp(0, charms.length - 1).toInt(),
      );
    } catch (_) {}
  }

  static Future<bool> shouldShowFirstGuide() async {
    try {
      final p = await SharedPreferences.getInstance();
      return !(p.getBool('ludo_first_guide_seen') ?? false);
    } catch (_) { return true; }
  }

  static Future<void> markFirstGuideSeen() async {
    try { final p = await SharedPreferences.getInstance(); await p.setBool('ludo_first_guide_seen', true); } catch (_) {}
  }

  static Future<void> select(String key, int value) async {
    final old = current.value;
    final next = switch (key) {
      'board' => old.copyWith(board: value),
      'avatar' => old.copyWith(avatar: value),
      'frame' => old.copyWith(frame: value),
      'banner' => old.copyWith(banner: value),
      'background' => old.copyWith(background: value),
      _ => old.copyWith(charm: value),
    };
    current.value = next;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('ludo_$key', value);
    } catch (_) {}
  }
}

class LudoCustomizationButton extends StatelessWidget {
  const LudoCustomizationButton({super.key});

  static Future<void> open(BuildContext context) async {
    await LudoCustomization.load();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, showDragHandle: true,
      backgroundColor: const Color(0xFF101B28),
      builder: (sheet) => const _LudoCustomizationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'شخصی‌سازی لودو',
    icon: const Icon(Icons.style_rounded),
    onPressed: () => open(context),
  );
}

class LudoCustomizationShowcase extends StatelessWidget {
  const LudoCustomizationShowcase({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<LudoLook>(
    valueListenable: LudoCustomization.current,
    builder: (context, look, _) => Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => LudoCustomizationButton.open(context),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topRight, end: Alignment.bottomLeft,
              colors: LudoCustomization.backgroundPalettes[look.background],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .16)),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 7))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 58, height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white,
                  border: Border.all(color: LudoCustomization.frameColors[look.frame], width: 4),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                ),
                child: Center(child: Text(LudoCustomization.avatars[look.avatar], style: const TextStyle(fontSize: 31))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('پروفایل بازیکن من', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('بنر ${LudoCustomization.banners[look.banner]}  •  قاب ${LudoCustomization.frames[look.frame]}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ])),
              Text(LudoCustomization.charms[look.charm], style: const TextStyle(fontSize: 27)),
            ]),
            const SizedBox(height: 13),
            Row(children: [
              const Icon(Icons.palette_outlined, color: Colors.white70, size: 18),
              const SizedBox(width: 7),
              Expanded(child: Text('تخته: ${LudoCustomization.boardNames[look.board]}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
              const Icon(Icons.wallpaper_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 5),
              Text(LudoCustomization.backgrounds[look.background], style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
            const SizedBox(height: 12),
            Container(
              height: 7, decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(colors: LudoCustomization.bannerPalettes[look.banner]),
              ),
            ),
            const SizedBox(height: 9),
            const Row(children: [
              Icon(Icons.edit_rounded, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text('برای تغییر آواتار، قاب، بنر، پس‌زمینه و آویز بزن',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              Spacer(),
              Icon(Icons.chevron_left_rounded, color: Colors.white),
            ]),
          ]),
        ),
      ),
    ),
  );
}

class _LudoCustomizationSheet extends StatefulWidget {
  const _LudoCustomizationSheet();
  @override State<_LudoCustomizationSheet> createState() => _LudoCustomizationSheetState();
}

class _LudoCustomizationSheetState extends State<_LudoCustomizationSheet> {
  String category = 'board';

  @override
  Widget build(BuildContext context) {
    final look = LudoCustomization.current.value;
    final selected = switch (category) {
      'board' => look.board, 'avatar' => look.avatar, 'frame' => look.frame,
      'banner' => look.banner, 'background' => look.background, _ => look.charm,
    };
    final labels = switch (category) {
      'board' => LudoCustomization.boardNames,
      'avatar' => LudoCustomization.avatars,
      'frame' => LudoCustomization.frames,
      'banner' => LudoCustomization.banners,
      'background' => LudoCustomization.backgrounds,
      _ => LudoCustomization.charms,
    };
    return SafeArea(child: SingleChildScrollView(child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ظاهر اختصاصی لودو', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('انتخاب‌ها روی همین دستگاه ذخیره می‌شوند.', style: TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 12),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final item in <(String,String)>[
            ('board','قالب تخته'), ('avatar','آواتار'), ('frame','قاب'),
            ('banner','بنر'), ('background','پس‌زمینه'), ('charm','آویز'),
          ])
            ChoiceChip(label: Text(item.$2), selected: category == item.$1,
              onSelected: (_) => setState(() => category = item.$1)),
        ]),
        const SizedBox(height: 12),
        if (category == 'board' || category == 'banner' || category == 'background')
          SizedBox(height: 74, child: ListView(scrollDirection: Axis.horizontal, children: [
            for (var i = 0; i < labels.length; i++)
              GestureDetector(onTap: () { LudoCustomization.select(category, i); setState(() {}); },
                child: Container(width: 76, margin: const EdgeInsetsDirectional.only(end: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(colors: category == 'board'
                      ? LudoCustomization.boardPalettes[i]
                      : category == 'banner' ? LudoCustomization.bannerPalettes[i]
                      : LudoCustomization.backgroundPalettes[i]),
                    border: Border.all(color: selected == i ? Colors.white : Colors.white24, width: selected == i ? 2.5 : 1),
                  ),
                  child: Center(child: Text(labels[i], textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
                )),
          ]))
        else
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (var i = 0; i < labels.length; i++)
              GestureDetector(onTap: () { LudoCustomization.select(category, i); setState(() {}); },
                child: Container(width: 76, height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2B3B), borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: selected == i ? const Color(0xFFFFD477) : Colors.white24, width: selected == i ? 2.5 : 1),
                  ),
                  child: Center(child: category == 'avatar' || category == 'charm'
                    ? Text(labels[i], style: const TextStyle(fontSize: 29))
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.circle, color: LudoCustomization.frameColors[i], size: 25),
                        Text(labels[i], style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ])),
                )),
          ]),
        const SizedBox(height: 14),
        ValueListenableBuilder<LudoLook>(valueListenable: LudoCustomization.current,
          builder: (context, value, _) => Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: LudoCustomization.bannerPalettes[value.banner]),
            ),
            child: Row(children: [
              Container(width: 48, height: 48,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white,
                  border: Border.all(color: LudoCustomization.frameColors[value.frame], width: 4)),
                child: Center(child: Text(LudoCustomization.avatars[value.avatar], style: const TextStyle(fontSize: 25))),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('پروفایل بازیکن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
              Text(LudoCustomization.charms[value.charm], style: const TextStyle(fontSize: 25)),
            ]),
          )),
      ]),
    )));
  }
}
