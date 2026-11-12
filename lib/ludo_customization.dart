import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LudoLook {
  final int board, avatar, frame, banner, background, charm, diceSkin;
  final String? bannerImageBase64, backgroundImageBase64;
  const LudoLook({
    this.board = 0, this.avatar = 0, this.frame = 0, this.banner = 0,
    this.background = 0, this.charm = 0, this.diceSkin = 0,
    this.bannerImageBase64, this.backgroundImageBase64,
  });
  LudoLook copyWith({
    int? board, int? avatar, int? frame, int? banner, int? background, int? charm, int? diceSkin,
    String? bannerImageBase64, String? backgroundImageBase64,
  }) => LudoLook(
    board: board ?? this.board, avatar: avatar ?? this.avatar, frame: frame ?? this.frame,
    banner: banner ?? this.banner, background: background ?? this.background, charm: charm ?? this.charm, diceSkin: diceSkin ?? this.diceSkin,
    bannerImageBase64: bannerImageBase64 ?? this.bannerImageBase64,
    backgroundImageBase64: backgroundImageBase64 ?? this.backgroundImageBase64,
  );
}

class LudoCustomization {
  LudoCustomization._();
  static final ValueNotifier<LudoLook> current = ValueNotifier(const LudoLook());
  static Future<void>? _loadFuture;
  static String? _loadedScope;
  static String get _accountScope {
    try {
      return Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    } catch (_) {
      return 'guest';
    }
  }
  static String _accountKey(String key) => 'ludo_${_accountScope}_$key';
  static const avatars = ['🙂', '😎', '🦁', '🐼', '🐯', '🦊', '🐉', '👑', '🦅', '🐺'];
  static const diceSkins = ['یاقوتی', 'زمردی', 'یخی', 'طلایی', 'بنفش', 'نئون'];
  static const dicePalettes = <List<Color>>[
    [Color(0xFF7F1D2D), Color(0xFFE34D55)], [Color(0xFF07583D), Color(0xFF35C98A)],
    [Color(0xFF17628B), Color(0xFFB8F0FF)], [Color(0xFF8A5A13), Color(0xFFFFD477)],
    [Color(0xFF492477), Color(0xFFB88CFF)], [Color(0xFF075B73), Color(0xFF49F0FF)],
  ];
  static const frames = ['طلایی', 'یخی', 'زمردی', 'یاقوتی', 'نئونی', 'نقره‌ای', 'آتشین', 'کریستالی'];
  static const charms = ['⭐', '⚽', '💎', '🔥', '👑', '🧿', '🍀', '🎯', '⚡', '🏆'];
  static const banners = ['سلطنتی', 'ورزشگاه', 'شفق', 'اقیانوس', 'غروب', 'کهکشانی', 'زمردی', 'یخی'];
  static const backgrounds = ['تیره', 'زمردی', 'آبی', 'بنفش', 'طلایی', 'شب', 'یخی', 'آتشفشانی'];
  static const boardNames = ['کلاسیک طلایی', 'زمرد جنگلی', 'اقیانوس', 'سلطنتی', 'غروب', 'نئون شب', 'یخی کریستالی', 'آتشفشانی'];
  static const boardPalettes = <List<Color>>[
    [Color(0xFF102535), Color(0xFF23495B), Color(0xFF0A1724)],
    [Color(0xFF073B2E), Color(0xFF167653), Color(0xFF06251F)],
    [Color(0xFF092D50), Color(0xFF176D91), Color(0xFF071C35)],
    [Color(0xFF26143F), Color(0xFF57318A), Color(0xFF160D2A)],
    [Color(0xFF54243A), Color(0xFFB45B48), Color(0xFF2D1427)],
    [Color(0xFF080F24), Color(0xFF173C55), Color(0xFF090A18)],
    [Color(0xFF17354A), Color(0xFF75C8E8), Color(0xFF091A31)],
    [Color(0xFF451B1B), Color(0xFFB94A35), Color(0xFF210D16)],
  ];
  static const frameColors = <Color>[
    Color(0xFFE8C36C), Color(0xFFB9E8FF), Color(0xFF55D6A4),
    Color(0xFFFF6D85), Color(0xFF6CEBFF), Color(0xFFC7D1DE),
    Color(0xFFFF9B54), Color(0xFF9BE7F5),
  ];
  static const bannerPalettes = <List<Color>>[
    [Color(0xFF39234F), Color(0xFFC89A45)],
    [Color(0xFF0B5B3D), Color(0xFF55C98B)],
    [Color(0xFF102B55), Color(0xFF49B8C9)],
    [Color(0xFF123E69), Color(0xFF35A6C9)],
    [Color(0xFF743B43), Color(0xFFE6A45C)],
    [Color(0xFF171A3C), Color(0xFF7046A5)],
    [Color(0xFF0B5B45), Color(0xFF8BE0B0)],
    [Color(0xFF244B68), Color(0xFFB8E9F6)],
  ];
  static const backgroundPalettes = <List<Color>>[
    [Color(0xFF101722), Color(0xFF1D2938)],
    [Color(0xFF082B23), Color(0xFF145542)],
    [Color(0xFF0B2945), Color(0xFF174F73)],
    [Color(0xFF24153D), Color(0xFF45256D)],
    [Color(0xFF332719), Color(0xFF76552B)],
    [Color(0xFF090D1A), Color(0xFF20284A)],
    [Color(0xFF163B52), Color(0xFF78B8D7)],
    [Color(0xFF36191B), Color(0xFF8E3A2C)],
  ];

  static Future<void> load() {
    final scope = _accountScope;
    if (_loadFuture != null && _loadedScope == scope) return _loadFuture!;
    _loadedScope = scope;
    return _loadFuture = _loadSavedLook();
  }

  static Future<void> _loadSavedLook() async {
    try {
      final p = await SharedPreferences.getInstance();
      current.value = LudoLook(
        board: (p.getInt(_accountKey('board_skin')) ?? 0).clamp(0, boardNames.length - 1).toInt(),
        avatar: (p.getInt(_accountKey('avatar')) ?? 0).clamp(0, avatars.length - 1).toInt(),
        frame: (p.getInt(_accountKey('avatar_frame')) ?? 0).clamp(0, frames.length - 1).toInt(),
        banner: (p.getInt(_accountKey('profile_banner')) ?? 0).clamp(0, banners.length - 1).toInt(),
        background: (p.getInt(_accountKey('profile_background')) ?? 0).clamp(0, backgrounds.length - 1).toInt(),
        charm: (p.getInt(_accountKey('avatar_charm')) ?? 0).clamp(0, charms.length - 1).toInt(),
        diceSkin: (p.getInt(_accountKey('dice_skin')) ?? 0).clamp(0, diceSkins.length - 1).toInt(),
        bannerImageBase64: p.getString(_accountKey('banner_image')),
        backgroundImageBase64: p.getString(_accountKey('background_image')),
      );
    } catch (_) {}
  }

  static Uint8List? decodeImage(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final bytes = base64Decode(encoded);
      // Reject arbitrary/corrupt preference strings before passing them to
      // MemoryImage, which otherwise throws during image decoding.
      final isPng = bytes.length >= 8 &&
          bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E &&
          bytes[3] == 0x47 && bytes[4] == 0x0D && bytes[5] == 0x0A &&
          bytes[6] == 0x1A && bytes[7] == 0x0A;
      final isJpeg = bytes.length >= 3 &&
          bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
      final isGif = bytes.length >= 6 &&
          String.fromCharCodes(bytes.sublist(0, 6)).startsWith('GIF8');
      final isWebp = bytes.length >= 12 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
      final isBmp = bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D;
      return isPng || isJpeg || isGif || isWebp || isBmp ? bytes : null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> pickProfileImage({required bool banner}) async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 68, maxWidth: 1000, maxHeight: 1000,
      );
      if (file == null) return false;
      final encoded = base64Encode(await file.readAsBytes());
      // Avoid filling preferences with an unusually large original photo.
      if (encoded.length > 1900000) return false;
      final prefs = await SharedPreferences.getInstance();
      final key = _accountKey(banner ? 'banner_image' : 'background_image');
      await prefs.setString(key, encoded);
      current.value = banner
          ? current.value.copyWith(bannerImageBase64: encoded)
          : current.value.copyWith(backgroundImageBase64: encoded);
      return true;
    } catch (_) { return false; }
  }

  static Future<void> clearProfileImage({required bool banner}) async {
    final key = _accountKey(banner ? 'banner_image' : 'background_image');
    try { final prefs = await SharedPreferences.getInstance(); await prefs.remove(key); } catch (_) {}
    current.value = banner
        ? current.value.copyWith(bannerImageBase64: '')
        : current.value.copyWith(backgroundImageBase64: '');
  }

  static Future<bool> shouldShowFirstGuide() async {
    try {
      final p = await SharedPreferences.getInstance();
      return !(p.getBool(_accountKey('first_guide_seen')) ?? false);
    } catch (_) { return true; }
  }

  static Future<void> markFirstGuideSeen() async {
    try { final p = await SharedPreferences.getInstance(); await p.setBool(_accountKey('first_guide_seen'), true); } catch (_) {}
  }

  static Future<void> select(String key, int value) async {
    final old = current.value;
    final next = switch (key) {
      'board' => old.copyWith(board: value),
      'avatar' => old.copyWith(avatar: value),
      'frame' => old.copyWith(frame: value),
      'banner' => old.copyWith(banner: value),
      'background' => old.copyWith(background: value),
      'diceSkin' => old.copyWith(diceSkin: value),
      _ => old.copyWith(charm: value),
    };
    current.value = next;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_accountKey(key), value);
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
            image: LudoCustomization.decodeImage(look.bannerImageBase64) == null ? null : DecorationImage(
              image: MemoryImage(LudoCustomization.decodeImage(look.bannerImageBase64)!),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: .42), BlendMode.darken),
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
            ('bannerPhoto','عکس بنر'), ('backgroundPhoto','عکس پس‌زمینه'),
          ])
            ChoiceChip(label: Text(item.$2), selected: category == item.$1,
              onSelected: (_) => setState(() => category = item.$1)),
        ]),
        const SizedBox(height: 12),
        if (category == 'bannerPhoto' || category == 'backgroundPhoto')
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(category == 'bannerPhoto' ? 'عکس دلخواه برای بنر پروفایل' : 'عکس دلخواه برای پس‌زمینه',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  await LudoCustomization.pickProfileImage(banner: category == 'bannerPhoto');
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('انتخاب عکس از گالری'),
              )),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'حذف عکس انتخاب‌شده',
                onPressed: () async {
                  await LudoCustomization.clearProfileImage(banner: category == 'bannerPhoto');
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
              ),
            ]),
            Builder(builder: (context) {
              final bytes = LudoCustomization.decodeImage(category == 'bannerPhoto'
                  ? LudoCustomization.current.value.bannerImageBase64
                  : LudoCustomization.current.value.backgroundImageBase64);
              return bytes == null
                  ? Container(height: 90, alignment: Alignment.center, child: const Text('هنوز عکسی انتخاب نشده است', style: TextStyle(color: Colors.white54)))
                  : ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(bytes, height: 120, width: double.infinity, fit: BoxFit.cover));
            }),
          ])
        else if (category == 'board' || category == 'banner' || category == 'background')
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
              image: LudoCustomization.decodeImage(value.bannerImageBase64) == null ? null : DecorationImage(
                image: MemoryImage(LudoCustomization.decodeImage(value.bannerImageBase64)!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: .42), BlendMode.darken),
              ),
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
