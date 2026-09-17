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
    player.onPlayerComplete.listen((_) { if (mounted) setState(() => position = duration); });
  }

  Future<void> ensureLoaded() async {
    if (loaded) return;
    final bytes = await widget.loadAudio();
    if (bytes.isEmpty) throw Exception('فایل صوتی خالی است');
    await player.setSource(BytesSource(bytes, mimeType: 'audio/mp4'));
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

  String formatTime(Duration d) {
    final s = d.inSeconds;
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.mine ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.primary;
    final double maxValue = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
    final double currentValue = position.inMilliseconds.toDouble().clamp(0.0, maxValue).toDouble();
    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(onPressed: toggle, icon: loading ? CircularProgressIndicator(color: accent) : Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 40, color: accent)),
              IconButton(onPressed: () => seekBy(-10), icon: Icon(Icons.replay_10, color: accent)),
              Expanded(child: Slider(min: 0.0, max: maxValue, value: currentValue, onChanged: duration == Duration.zero ? null : (v) => player.seek(Duration(milliseconds: v.round())))),
              IconButton(onPressed: () => seekBy(10), icon: Icon(Icons.forward_10, color: accent)),
            ],
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(formatTime(position)),
            TextButton(onPressed: () async { const values = <double>[0.5, 1.0, 1.5, 2.0]; final i = values.indexOf(speed); final next = values[(i + 1) % values.length]; setState(() => speed = next); if (loaded) await player.setPlaybackRate(next); }, child: Text('${speed}x')),
            Text(formatTime(duration)),
          ]),
        ],
      ),
    );
  }

  @override
  void dispose() { player.dispose(); super.dispose(); }
}
