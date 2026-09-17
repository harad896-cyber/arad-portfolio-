import 'dart:ui';

import 'package:flutter/material.dart';

class CallSessionPage extends StatefulWidget {
  final String conversationId;
  final String title;
  final bool video;

  const CallSessionPage({
    super.key,
    required this.conversationId,
    required this.title,
    required this.video,
  });

  @override
  State<CallSessionPage> createState() => _CallSessionPageState();
}

class _CallSessionPageState extends State<CallSessionPage> {
  bool muted = false;
  bool speaker = true;
  bool camera = true;
  bool connected = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => connected = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.brightness == Brightness.dark
          ? const Color(0xFF090A0D)
          : const Color(0xFFEFF2F7),
      appBar: AppBar(
        title: Text(widget.video ? 'تماس تصویری' : 'تماس صوتی'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.video)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primary.withValues(alpha: .35),
                    scheme.surface,
                  ],
                ),
              ),
              child: const Center(
                child: Icon(Icons.person_rounded, size: 120, color: Colors.white54),
              ),
            )
          else
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(120),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .14),
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.primary.withValues(alpha: .22)),
                    ),
                    child: Icon(Icons.person_rounded, size: 92, color: scheme.primary),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 18,
            right: 18,
            top: 18,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: .68),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: scheme.onSurface.withValues(alpha: .08)),
                  ),
                  child: Column(
                    children: [
                      Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(connected ? 'متصل' : 'در حال اتصال...', style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: .78),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: scheme.onSurface.withValues(alpha: .08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _button(Icons.mic_off_rounded, muted, () => setState(() => muted = !muted)),
                      _button(Icons.volume_up_rounded, speaker, () => setState(() => speaker = !speaker)),
                      if (widget.video)
                        _button(Icons.videocam_rounded, camera, () => setState(() => camera = !camera)),
                      Material(
                        color: scheme.error,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.pop(context),
                          child: const Padding(
                            padding: EdgeInsets.all(18),
                            child: Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(IconData icon, bool active, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: active ? scheme.primary.withValues(alpha: .14) : scheme.surfaceContainerHighest.withValues(alpha: .75),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Icon(icon, color: active ? scheme.primary : scheme.onSurface, size: 25),
        ),
      ),
    );
  }
}
