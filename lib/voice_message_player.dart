import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final Future<Uint8List> Function() loadAudio;
  final int initialDurationMs;
  final bool mine;
  const VoiceMessagePlayer({super.key, required this.loadAudio, this.initialDurationMs = 0, this.mine = false});
  @override State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer player = AudioPlayer();
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool loading = false;
  bool playing = false;
  bool loaded = false;
  double speed = 1.0;

  @override
  void initState() {
    super.initState();
    duration = Duration(milliseconds: widget.initialDurationMs);
    player.onPositionChanged.listen((v) { if (mounted) setState(() => position = v); });
    player.onDurationChanged.listen((v) { if (mounted) setState(() => duration = v); });
    player.onPlayerStateChanged.listen((v) { if (mounted) setState(() => playing = v == PlayerState.playing); });
    player.onPlayerComplete.listen((_) { if (mounted) setState(() { playing = false; position = Duration.zero; }); });
  }

  Future<void> ensureLoaded() async {
    if (loaded) return;
    final bytes = await widget.loadAudio();
    if (bytes.isEmpty) throw Exception('فایل صوتی خالی است');
    await player.setSource(BytesSource(bytes));
    loaded = true;
    await player.setPlaybackRate(speed);
  }

  Future<void> toggle() async {
    if (loading) return;
    try {
      setState(() => loading = true);
      await ensureLoaded();
      if (playing) {
        await player.pause();
      } else {
        if (position >= duration && duration > Duration.zero) await player.seek(Duration.zero);
        await player.resume();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('پخش ویس ناموفق بود: $e')));
    } finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> seekBy(int seconds) async {
    if (duration <= Duration.zero) return;
    var target = position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;
    try { await ensureLoaded(); await player.seek(target); } catch (_) {}
  }

  Future<void> seekToFraction(double fraction) async {
    if (duration <= Duration.zero) return;
    final f = fraction.clamp(0.0, 1.0);
    try {
      await ensureLoaded();
      await player.seek(Duration(milliseconds: (duration.inMilliseconds * f).round()));
    } catch (_) {}
  }

  String formatTime(Duration d) {
    final s = d.inSeconds;
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.mine
        ? Colors.white
        : (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFB99CFF)
            : const Color(0xFF6D4FD8));
    final inactive = widget.mine
        ? Colors.white.withValues(alpha: .34)
        : scheme.onSurface.withValues(alpha: .22);
    final controlSurface = widget.mine
        ? Colors.white.withValues(alpha: .16)
        : scheme.onSurface.withValues(alpha: .08);
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    const bars = <double>[.32,.55,.42,.72,.48,.86,.58,.38,.76,.52,.92,.45,.68,.36,.8,.5,.74,.44,.64,.34,.7,.48,.86,.56,.76,.4,.62,.5,.78,.44,.68,.35,.82,.5,.72,.42,.9,.58,.7,.38];

    return SizedBox(
      width: 285,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            IconButton(
              tooltip: playing ? 'مکث' : 'پخش',
              onPressed: toggle,
              style: IconButton.styleFrom(backgroundColor: controlSurface, foregroundColor: accent),
              icon: loading
                  ? SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2.5, color: accent))
                  : Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, size: 42, color: accent),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) => seekToFraction((d.localPosition.dx / 220).clamp(0.0, 1.0)),
                onHorizontalDragUpdate: (d) => seekToFraction((d.localPosition.dx / 220).clamp(0.0, 1.0)),
                onTapDown: (d) => seekToFraction((d.localPosition.dx / 220).clamp(0.0, 1.0)),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(bars.length, (i) {
                      final active = i / bars.length <= progress;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        width: 3,
                        height: 8 + bars[i] * 27,
                        decoration: BoxDecoration(
                          color: active ? accent : inactive,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            IconButton(onPressed: () => seekBy(10), tooltip: '+۱۰ ثانیه', icon: Icon(Icons.forward_10_rounded, color: accent)),
          ]),
          Row(children: [
            const SizedBox(width: 50),
            Text(formatTime(position), style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w800)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: accent,
                  inactiveTrackColor: inactive,
                  thumbColor: accent,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  min: 0,
                  max: duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1,
                  value: duration.inMilliseconds > 0 ? position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble() : 0,
                  onChanged: duration == Duration.zero ? null : (v) => player.seek(Duration(milliseconds: v.round())),
                ),
              ),
            ),
            Text(formatTime(duration), style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w800)),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(
              onPressed: () async {
                const values = <double>[0.5, 1.0, 1.5, 2.0];
                final i = values.indexOf(speed);
                final next = values[(i + 1) % values.length];
                setState(() => speed = next);
                if (loaded) await player.setPlaybackRate(next);
              },
              icon: Icon(Icons.speed_rounded, size: 16, color: accent),
              label: Text('${speed}x', style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
            ),
          ]),
        ],
      ),
    );
  }

  @override
  void dispose() { player.dispose(); super.dispose(); }
}
