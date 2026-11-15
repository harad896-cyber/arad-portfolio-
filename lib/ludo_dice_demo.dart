import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dice_3d_math.dart';

/// Standalone 3D dice prototype.
///
/// The caller supplies the final face. The animation changes only the
/// orientation of the rendered cube; it never generates a game result.
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
  bool _isRolling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _isRolling = false);
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
      _isRolling = true;
    });
    await _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B141B),
        appBar: AppBar(
          title: const Text('آزمایش پرتاب سه‌بعدی تاس'),
          backgroundColor: const Color(0xFF0B141B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.easeOutCubic.transform(_controller.value);
              final rotation = _rotationAt(t);
              final bounce = _isRolling
                  ? math.sin(t * math.pi * 5).abs() * (1 - t) * 24
                  : 0.0;
              final settleScale = _isRolling
                  ? 1 + math.sin(t * math.pi * 7).abs() * (1 - t) * .045
                  : 1.0;

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'عددِ روی سطح بالایی را تعیین کن',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'تاس می‌چرخد و در پایان همان عدد را بالا نگه می‌دارد.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF9FB0BC),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: 148,
                          child: TextField(
                            controller: _resultController,
                            enabled: !_isRolling,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF172630),
                              hintText: '۱ تا ۶',
                              hintStyle:
                                  const TextStyle(color: Colors.white38),
                              errorText: _error,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF314653),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF314653),
                                ),
                              ),
                            ),
                            onChanged: (_) {
                              if (_error != null) {
                                setState(() => _error = null);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          height: 286,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFF142630),
                                Color(0xFF101D26),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .055),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                bottom: 28,
                                child: Container(
                                  width: 150 + bounce * .5,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(100),
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.black.withValues(
                                          alpha: .48 - t * .12,
                                        ),
                                        Colors.black.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(0, -bounce),
                                child: Transform.scale(
                                  scale: settleScale,
                                  child: CustomPaint(
                                    size: const Size(250, 250),
                                    painter: _Dice3DPainter(
                                      rotation: rotation,
                                      rolling: _isRolling,
                                      progress: t,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 13,
                                child: Text(
                                  _isRolling
                                      ? 'در حال پرتاب...'
                                      : 'آمادهٔ پرتاب',
                                  style: const TextStyle(
                                    color: Color(0xFF9FB0BC),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Text(
                            _isRolling
                                ? 'تاس در حال چرخش است'
                                : 'نتیجه: $_targetFace',
                            key: ValueKey('$_isRolling-$_targetFace'),
                            style: TextStyle(
                              color: _isRolling
                                  ? Colors.white70
                                  : const Color(0xFF79F0A8),
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: 230,
                          height: 60,
                          child: FilledButton.icon(
                            onPressed: _isRolling ? null : _roll,
                            icon: const Icon(Icons.casino_rounded, size: 27),
                            label: Text(
                              _isRolling ? 'منتظر بمان...' : 'پرتاب تاس',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF19A963),
                              disabledBackgroundColor: Colors.white12,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(19),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'این نمونه مستقل است؛ هنوز به بازی لودو یا سرور وصل نشده.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF718793),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  DiceQuaternion _rotationAt(double progress) {
    final finalPose = Dice3DOrientation.forTopFace(_targetFace);
    if (!_isRolling || progress >= 1) return finalPose;

    final remaining = 1 - progress;
    final wobble = math.sin(progress * math.pi * 6) * .16 * remaining;
    final spinX = DiceQuaternion.axisAngle(
      const DiceVector3(1, 0, 0),
      math.pi * 8 * remaining + wobble,
    );
    final spinY = DiceQuaternion.axisAngle(
      const DiceVector3(0, 1, 0),
      math.pi * 10 * remaining - wobble * .7,
    );
    final spinZ = DiceQuaternion.axisAngle(
      const DiceVector3(0, 0, 1),
      math.pi * 6 * remaining,
    );
    return (finalPose * spinX * spinY * spinZ).normalized();
  }
}

class _DiceFace {
  const _DiceFace({
    required this.value,
    required this.normal,
    required this.axisU,
    required this.axisV,
    required this.color,
  });

  final int value;
  final DiceVector3 normal;
  final DiceVector3 axisU;
  final DiceVector3 axisV;
  final Color color;
}

class _ProjectedFace {
  const _ProjectedFace({
    required this.face,
    required this.path,
    required this.depth,
    required this.corners,
  });

  final _DiceFace face;
  final Path path;
  final double depth;
  final List<Offset> corners;
}

class _Dice3DPainter extends CustomPainter {
  const _Dice3DPainter({
    required this.rotation,
    required this.rolling,
    required this.progress,
  });

  final DiceQuaternion rotation;
  final bool rolling;
  final double progress;

  static const _faces = <_DiceFace>[
    _DiceFace(
      value: 1,
      normal: DiceVector3(0, 0, 1),
      axisU: DiceVector3(1, 0, 0),
      axisV: DiceVector3(0, 1, 0),
      color: Color(0xFFFDFEFF),
    ),
    _DiceFace(
      value: 6,
      normal: DiceVector3(0, 0, -1),
      axisU: DiceVector3(-1, 0, 0),
      axisV: DiceVector3(0, 1, 0),
      color: Color(0xFFDAE4EB),
    ),
    _DiceFace(
      value: 2,
      normal: DiceVector3(1, 0, 0),
      axisU: DiceVector3(0, 1, 0),
      axisV: DiceVector3(0, 0, 1),
      color: Color(0xFFE9F0F5),
    ),
    _DiceFace(
      value: 5,
      normal: DiceVector3(-1, 0, 0),
      axisU: DiceVector3(0, -1, 0),
      axisV: DiceVector3(0, 0, 1),
      color: Color(0xFFB9C8D2),
    ),
    _DiceFace(
      value: 3,
      normal: DiceVector3(0, 1, 0),
      axisU: DiceVector3(-1, 0, 0),
      axisV: DiceVector3(0, 0, 1),
      color: Color(0xFFD1DDE5),
    ),
    _DiceFace(
      value: 4,
      normal: DiceVector3(0, -1, 0),
      axisU: DiceVector3(1, 0, 0),
      axisV: DiceVector3(0, 0, 1),
      color: Color(0xFFF2F6F9),
    ),
  ];

  static const _camera = DiceVector3(4, -6, 8);
  static const _worldUp = DiceVector3(0, 0, 1);

  @override
  void paint(Canvas canvas, Size size) {
    final cameraDirection = _camera.normalized();
    final right = _worldUp.cross(cameraDirection).normalized();
    final up = cameraDirection.cross(right).normalized();
    const focalLength = 215.0;
    const cameraDistance = 3.5;
    final origin = Offset(size.width / 2, size.height / 2 + 6);

    Offset project(DiceVector3 point) {
      final depth = point.dot(cameraDirection);
      final perspective = focalLength / (cameraDistance - depth);
      return Offset(
        origin.dx + point.dot(right) * perspective,
        origin.dy - point.dot(up) * perspective,
      );
    }

    final projected = <_ProjectedFace>[];
    for (final face in _faces) {
      final worldNormal = rotation.rotate(face.normal).normalized();
      if (worldNormal.dot(cameraDirection) <= .015) continue;

      final center = face.normal * .5;
      final localCorners = [
        center - face.axisU * .5 - face.axisV * .5,
        center + face.axisU * .5 - face.axisV * .5,
        center + face.axisU * .5 + face.axisV * .5,
        center - face.axisU * .5 + face.axisV * .5,
      ];
      final worldCorners =
          localCorners.map(rotation.rotate).toList(growable: false);
      final points = worldCorners.map(project).toList(growable: false);
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      final depth = worldCorners
              .map((point) => point.dot(cameraDirection))
              .reduce((a, b) => a + b) /
          worldCorners.length;
      projected.add(
        _ProjectedFace(
          face: face,
          path: path,
          depth: depth,
          corners: points,
        ),
      );
    }

    projected.sort((a, b) => a.depth.compareTo(b.depth));

    final shadowRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .79),
      width: 145,
      height: 30,
    );
    canvas.drawOval(
      shadowRect,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x66000000), Color(0x00000000)],
        ).createShader(shadowRect),
    );

    for (final item in projected) {
      final facePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(item.face.color, Colors.white, .08)!,
            item.face.color,
            Color.lerp(item.face.color, const Color(0xFF667986), .22)!,
          ],
        ).createShader(item.path.getBounds());
      canvas.drawPath(item.path, facePaint);
      canvas.drawPath(
        item.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF71818D).withValues(alpha: .75),
      );
      _drawFacePips(canvas, item.face, project);
    }

    if (rolling && progress > .78) {
      final glowRect = Rect.fromCircle(
        center: origin.translate(0, 4),
        radius: 68,
      );
      canvas.drawCircle(
        glowRect.center,
        glowRect.width / 2,
        Paint()
          ..color = const Color(0xFF55E99A).withValues(
            alpha: (progress - .78) * .35,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
      );
    }
  }

  void _drawFacePips(
    Canvas canvas,
    _DiceFace face,
    Offset Function(DiceVector3) project,
  ) {
    const diagonal = .235;
    const positions = <int, List<Offset>>{
      1: [Offset(0, 0)],
      2: [Offset(-diagonal, -diagonal), Offset(diagonal, diagonal)],
      3: [
        Offset(-diagonal, -diagonal),
        Offset(0, 0),
        Offset(diagonal, diagonal),
      ],
      4: [
        Offset(-diagonal, -diagonal),
        Offset(diagonal, -diagonal),
        Offset(-diagonal, diagonal),
        Offset(diagonal, diagonal),
      ],
      5: [
        Offset(-diagonal, -diagonal),
        Offset(diagonal, -diagonal),
        Offset(0, 0),
        Offset(-diagonal, diagonal),
        Offset(diagonal, diagonal),
      ],
      6: [
        Offset(-diagonal, -.27),
        Offset(diagonal, -.27),
        Offset(-diagonal, 0),
        Offset(diagonal, 0),
        Offset(-diagonal, .27),
        Offset(diagonal, .27),
      ],
    };

    for (final pip in positions[face.value]!) {
      final local = face.normal * .506 +
          face.axisU * pip.dx +
          face.axisV * pip.dy;
      final point = project(rotation.rotate(local));
      canvas.drawCircle(
        point,
        5.1,
        Paint()..color = const Color(0xFF203342),
      );
      canvas.drawCircle(
        point.translate(-1.2, -1.4),
        1.15,
        Paint()..color = Colors.white.withValues(alpha: .22),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Dice3DPainter oldDelegate) =>
      oldDelegate.rotation.w != rotation.w ||
      oldDelegate.rotation.x != rotation.x ||
      oldDelegate.rotation.y != rotation.y ||
      oldDelegate.rotation.z != rotation.z ||
      oldDelegate.rolling != rolling ||
      oldDelegate.progress != progress;
}
