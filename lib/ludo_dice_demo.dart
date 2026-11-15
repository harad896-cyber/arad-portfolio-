import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Standalone dice interaction prototype.
///
/// The result is supplied by the caller. This widget never generates a
/// gameplay result or changes the supplied face value.
class DiceRollDemo extends StatefulWidget {
  const DiceRollDemo({super.key});

  @override
  State<DiceRollDemo> createState() => _DiceRollDemoState();
}

class _DiceRollDemoState extends State<DiceRollDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final TextEditingController _resultController =
      TextEditingController(text: '6');

  int _targetFace = 6;
  int _visibleFace = 6;
  bool _isRolling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..addListener(() {
        if (_controller.isCompleted && mounted) {
          setState(() {
            _isRolling = false;
            _visibleFace = _targetFace;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _roll() async {
    if (_isRolling) return;
    final parsed = int.tryParse(_resultController.text.trim());
    if (parsed == null || parsed < 1 || parsed > 6) {
      setState(() => _error = 'عدد باید بین ۱ تا ۶ باشد.');
      return;
    }

    setState(() {
      _error = null;
      _targetFace = parsed;
      _visibleFace = parsed;
      _isRolling = true;
    });

    // The animation is presentation-only. The final face is fixed before
    // the animation starts and cannot be replaced by a random value.
    await _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF101820),
        appBar: AppBar(
          title: const Text('نمونهٔ مستقل تاس'),
          backgroundColor: const Color(0xFF101820),
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.easeInOutCubic.transform(_controller.value);
              final rollPhase = _isRolling ? t : 1.0;
              final hops = _isRolling
                  ? math.sin(t * math.pi * 5).abs() * (1 - t) * 28
                  : 0.0;
              final spin = _isRolling ? t * math.pi * 9 : 0.0;

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'عدد فرود را انتخاب کن',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: 132,
                        child: TextField(
                          controller: _resultController,
                          enabled: !_isRolling,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF1D2B36),
                            hintText: '۱ تا ۶',
                            hintStyle: const TextStyle(color: Colors.white54),
                            errorText: _error,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onChanged: (_) {
                            if (_error != null) {
                              setState(() => _error = null);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: 260,
                        height: 230,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              bottom: 22 + hops * .12,
                              child: Container(
                                width: 124 + hops * 1.1,
                                height: 24 + hops * .12,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(100),
                                  color: Colors.black.withValues(
                                    alpha: .22 + (1 - rollPhase) * .2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: .28,
                                      ),
                                        blurRadius: 18 + hops,
                                        spreadRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(0, -hops),
                              child: Transform.rotate(
                                angle: spin,
                                child: Transform.scale(
                                  scale: _isRolling
                                      ? .96 + math.sin(t * math.pi) * .12
                                      : 1,
                                  child: CustomPaint(
                                    size: const Size(180, 180),
                                    painter: _IsometricDicePainter(
                                      face: _visibleFace,
                                      rolling: _isRolling,
                                      progress: rollPhase,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          _isRolling
                              ? 'در حال چرخش...'
                              : 'نتیجه: $_targetFace',
                          key: ValueKey('$_isRolling-$_targetFace'),
                          style: TextStyle(
                            color: _isRolling
                                ? Colors.white70
                                : const Color(0xFF8CF5B2),
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 220,
                        height: 64,
                        child: FilledButton.icon(
                          onPressed: _isRolling ? null : _roll,
                          icon: const Icon(Icons.casino, size: 26),
                          label: Text(
                            _isRolling ? 'منتظر بمان...' : 'بنداز 🎲',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF20B86A),
                            disabledBackgroundColor: Colors.white24,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'نتیجه از ورودی گرفته می‌شود؛ تاس عدد تصادفی تولید نمی‌کند.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _IsometricDicePainter extends CustomPainter {
  const _IsometricDicePainter({
    required this.face,
    required this.rolling,
    required this.progress,
  });

  final int face;
  final bool rolling;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 5);
    const half = 57.0;
    const depth = 30.0;
    final top = Path()
      ..moveTo(center.dx, center.dy - half - depth)
      ..lineTo(center.dx + half, center.dy - depth / 2)
      ..lineTo(center.dx, center.dy + half - depth)
      ..lineTo(center.dx - half, center.dy - depth / 2)
      ..close();
    final left = Path()
      ..moveTo(center.dx - half, center.dy - depth / 2)
      ..lineTo(center.dx, center.dy + half - depth)
      ..lineTo(center.dx, center.dy + half + depth / 2)
      ..lineTo(center.dx - half, center.dy + depth / 2)
      ..close();
    final right = Path()
      ..moveTo(center.dx, center.dy + half - depth)
      ..lineTo(center.dx + half, center.dy - depth / 2)
      ..lineTo(center.dx + half, center.dy + depth / 2)
      ..lineTo(center.dx, center.dy + half + depth / 2)
      ..close();

    final shadow = Paint()..color = const Color(0xFF000000).withValues(alpha: .2);
    canvas.drawShadow(top, Colors.black, 14, true);
    canvas.drawPath(left, Paint()..color = const Color(0xFFD7E2EC));
    canvas.drawPath(right, Paint()..color = const Color(0xFF9EADBA));
    canvas.drawPath(top, Paint()..color = const Color(0xFFF8FBFF));
    canvas.drawPath(
      top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );

    _drawPips(canvas, center, half, depth, rolling ? _rollingFace() : face);

    if (!rolling || progress > .7) {
      final glow = Paint()
        ..color = const Color(0xFF79F2A5).withValues(
          alpha: rolling ? (progress - .7) : .22,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(
        Offset(center.dx, center.dy - depth / 2),
        36,
        glow,
      );
    }
  }

  int _rollingFace() {
    // A repeatable visual sequence only; it never changes the target.
    final frame = (progress * 18).floor();
    return (frame % 6) + 1;
  }

  void _drawPips(
    Canvas canvas,
    Offset center,
    double half,
    double depth,
    int value,
  ) {
    const positions = <int, List<Offset>>{
      1: [Offset(0, 0)],
      2: [Offset(-.23, -.13), Offset(.23, .13)],
      3: [Offset(-.23, -.13), Offset(0, 0), Offset(.23, .13)],
      4: [
        Offset(-.23, -.13), Offset(.23, -.13),
        Offset(-.23, .13), Offset(.23, .13),
      ],
      5: [
        Offset(-.23, -.13), Offset(.23, -.13), Offset(0, 0),
        Offset(-.23, .13), Offset(.23, .13),
      ],
      6: [
        Offset(-.23, -.17), Offset(.23, -.17),
        Offset(-.23, 0), Offset(.23, 0),
        Offset(-.23, .17), Offset(.23, .17),
      ],
    };
    final pipPaint = Paint()..color = const Color(0xFF203342);
    final pipCenter = Offset(center.dx, center.dy - depth / 2);
    for (final point in positions[value]!) {
      final x = pipCenter.dx + point.dx * half * 1.55;
      final y = pipCenter.dy + point.dy * half * 1.55;
      canvas.drawCircle(Offset(x, y), 6.2, pipPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _IsometricDicePainter oldDelegate) =>
      oldDelegate.face != face ||
      oldDelegate.rolling != rolling ||
      oldDelegate.progress != progress;
}
