import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum FunBackdrop { emerald, stadium, snow, aurora, sunset, midnight }

class FunBackdropAccess {
  final bool verified;
  final int points;
  final int level;

  const FunBackdropAccess({required this.verified, required this.points, required this.level});

  static const levelThresholds = <int>[0, 50, 120, 220, 350, 520];

  static int levelFor(int points) {
    var level = 1;
    for (var i = 1; i < levelThresholds.length; i++) {
      if (points >= levelThresholds[i]) level = i + 1;
    }
    return level;
  }

  static int requiredPoints(FunBackdrop backdrop) =>
      levelThresholds[FunBackdrop.values.indexOf(backdrop)];

  bool canUse(FunBackdrop backdrop) =>
      verified || level >= FunBackdrop.values.indexOf(backdrop) + 1;

  static Future<FunBackdropAccess> load() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return const FunBackdropAccess(verified: false, points: 0, level: 1);

    var verified = false;
    var points = 0;
    try {
      final profile = await client.from('profiles').select('is_verified').eq('id', uid).maybeSingle();
      verified = profile?['is_verified'] == true;
    } catch (_) {
      // A failed badge lookup must never grant verified-only access.
    }
    try {
      final stats = await client.from('fun_game_stats').select('points').eq('user_id', uid).maybeSingle();
      points = (stats?['points'] as num?)?.toInt() ?? 0;
    } catch (_) {
      // Until the score migration is deployed, non-verified users stay at level 1.
    }
    return FunBackdropAccess(verified: verified, points: points, level: levelFor(points));
  }
}

class FunZoneLook {
  FunZoneLook._();
  static final ValueNotifier<FunBackdrop> current =
      ValueNotifier<FunBackdrop>(FunBackdrop.emerald);
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('gapresan_fun_backdrop');
      final requested = FunBackdrop.values.firstWhere(
        (value) => value.name == saved,
        orElse: () => FunBackdrop.emerald,
      );
      final access = await FunBackdropAccess.load();
      current.value = access.canUse(requested) ? requested : FunBackdrop.emerald;
      if (current.value != requested) {
        await prefs.setString('gapresan_fun_backdrop', FunBackdrop.emerald.name);
      }
    } catch (_) {
      // If access cannot be confirmed, keep only the universally unlocked default.
      current.value = FunBackdrop.emerald;
    }
  }

  static Future<bool> select(FunBackdrop value) async {
    final access = await FunBackdropAccess.load();
    if (!access.canUse(value)) return false;
    current.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gapresan_fun_backdrop', value.name);
    } catch (_) {
      // A failed preference write must not interrupt the current game.
    }
    return true;
  }

  static const labels = <FunBackdrop, String>{
    FunBackdrop.emerald: 'سبز زمردی',
    FunBackdrop.stadium: 'ورزشگاه',
    FunBackdrop.snow: 'برف و زمستان',
    FunBackdrop.aurora: 'شفق قطبی',
    FunBackdrop.sunset: 'غروب طلایی',
    FunBackdrop.midnight: 'شب نئونی',
  };

  static List<Color> colors(FunBackdrop value) => switch (value) {
    FunBackdrop.emerald => const [Color(0xFF061F1C), Color(0xFF0B4037), Color(0xFF102B36)],
    FunBackdrop.stadium => const [Color(0xFF092D24), Color(0xFF155B3C), Color(0xFF071C23)],
    FunBackdrop.snow => const [Color(0xFF18344D), Color(0xFF38658A), Color(0xFF9ABBD0)],
    FunBackdrop.aurora => const [Color(0xFF101B3B), Color(0xFF174C59), Color(0xFF3A2867)],
    FunBackdrop.sunset => const [Color(0xFF48233D), Color(0xFF9B4C45), Color(0xFFE3A45B)],
    FunBackdrop.midnight => const [Color(0xFF090E1D), Color(0xFF20264C), Color(0xFF172C3B)],
  };
}

class FunZoneBackdrop extends StatefulWidget {
  final Widget child;
  const FunZoneBackdrop({super.key, required this.child});

  @override
  State<FunZoneBackdrop> createState() => _FunZoneBackdropState();
}

class _FunZoneBackdropState extends State<FunZoneBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    FunZoneLook.load();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FunBackdrop>(
      valueListenable: FunZoneLook.current,
      builder: (context, look, _) {
        final colors = FunZoneLook.colors(look);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 650),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _motion,
                builder: (context, _) => CustomPaint(
                  painter: _AtmospherePainter(
                    look: look,
                    progress: _motion.value,
                  ),
                ),
              ),
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  final FunBackdrop look;
  final double progress;
  const _AtmospherePainter({required this.look, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withValues(alpha: .075);

    if (look == FunBackdrop.stadium) {
      final center = Offset(size.width * .5, size.height * .43);
      final rect = Rect.fromCenter(
        center: center,
        width: size.width * .88,
        height: size.width * .58,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(28)),
        paint,
      );
      canvas.drawLine(
        Offset(center.dx, rect.top),
        Offset(center.dx, rect.bottom),
        paint,
      );
      canvas.drawCircle(center, size.width * .105, paint);
      final ballPaint = Paint()..color = Colors.white.withValues(alpha: .08);
      canvas.drawCircle(
        Offset(size.width * .82, size.height * (.22 + .025 * math.sin(progress * math.pi * 2))),
        19,
        ballPaint,
      );
    } else if (look == FunBackdrop.snow) {
      final snow = Paint()..color = Colors.white.withValues(alpha: .48);
      for (var i = 0; i < 34; i++) {
        final x = ((i * 73.7) % size.width);
        final baseY = ((i * 41.3) % size.height);
        final y = (baseY + progress * (size.height + 20)) % (size.height + 20) - 10;
        final radius = 1.2 + (i % 4) * .65;
        canvas.drawCircle(Offset(x, y), radius, snow);
      }
    } else {
      final glow = Paint()
        ..color = Colors.white.withValues(alpha: .045)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
      for (var i = 0; i < 5; i++) {
        final x = size.width * (.12 + i * .19);
        final y = size.height * (.18 + .07 * math.sin(progress * math.pi * 2 + i));
        canvas.drawCircle(Offset(x, y), 42 + (i % 2) * 16, glow);
      }
      if (look == FunBackdrop.aurora) {
        final auroraPaint = Paint()
          ..color = const Color(0xFF7AF5C5).withValues(alpha: .08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);
        final path = Path()
          ..moveTo(0, size.height * .24)
          ..quadraticBezierTo(
            size.width * .5,
            size.height * (.08 + .04 * math.sin(progress * math.pi * 2)),
            size.width,
            size.height * .3,
          )
          ..lineTo(size.width, size.height * .43)
          ..quadraticBezierTo(size.width * .5, size.height * .2, 0, size.height * .4)
          ..close();
        canvas.drawPath(path, auroraPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter old) =>
      old.look != look || old.progress != progress;
}

class FunZoneThemeButton extends StatelessWidget {
  const FunZoneThemeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'gapresan-fun-look',
      tooltip: 'تغییر پس‌زمینه',
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF101C27),
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: FutureBuilder<FunBackdropAccess>(
            future: FunBackdropAccess.load(),
            builder: (context, accessSnapshot) {
              if (!accessSnapshot.hasData) {
                return const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()));
              }
              final access = accessSnapshot.data!;
              return ValueListenableBuilder<FunBackdrop>(
                valueListenable: FunZoneLook.current,
                builder: (context, selected, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ظاهر بخش سرگرمی', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(
                        access.verified ? 'تیک آبی فعال است؛ همهٔ پس‌زمینه‌ها برای شما باز است.' : 'سطح ${access.level} · ${access.points} امتیاز',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      if (!access.verified) ...[
                        const SizedBox(height: 5),
                        const Text('با جمع‌کردن امتیاز بازی‌ها، پس‌زمینه‌ها یکی‌یکی باز می‌شوند.',
                          style: TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                      const SizedBox(height: 12),
                      for (final look in FunBackdrop.values)
                        Builder(builder: (context) {
                          final unlocked = access.canUse(look);
                          final required = FunBackdropAccess.requiredPoints(look);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            enabled: unlocked,
                            leading: Opacity(
                              opacity: unlocked ? 1 : .42,
                              child: Container(width: 42, height: 42,
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(13),
                                  gradient: LinearGradient(colors: FunZoneLook.colors(look))),
                              ),
                            ),
                            title: Text(FunZoneLook.labels[look]!,
                              style: TextStyle(color: unlocked ? Colors.white : Colors.white54, fontWeight: FontWeight.w700)),
                            subtitle: unlocked ? null : Text(
                              'قفل · سطح ${FunBackdrop.values.indexOf(look) + 1}  •  ${required} امتیاز',
                              style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            trailing: selected == look && unlocked
                                ? const Icon(Icons.check_circle, color: Color(0xFF6CE0B3))
                                : unlocked
                                    ? const Icon(Icons.circle_outlined, color: Colors.white54)
                                    : const Icon(Icons.lock_rounded, color: Colors.white38),
                            onTap: !unlocked
                                ? () => ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('برای بازشدن این پس‌زمینه به ${required} امتیاز نیاز داری.')))
                                : () async {
                                    final selectedOk = await FunZoneLook.select(look);
                                    if (!selectedOk) {
                                      if (sheetContext.mounted) {
                                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                                          const SnackBar(content: Text('این پس‌زمینه هنوز برای سطح حساب شما باز نشده است.')),
                                        );
                                      }
                                      return;
                                    }
                                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                                  },
                          );
                        }),
                    ],
                  ),
                ),
              );
            },
          ),
        )
      ),
      backgroundColor: const Color(0xFFB9F4D8),
      foregroundColor: const Color(0xFF073D32),
      child: const Icon(Icons.palette_rounded),
    );
  }
}
