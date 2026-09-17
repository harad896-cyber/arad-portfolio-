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
  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;
  bool _loading = false, _playing = false, _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDurationMs > 0) _duration = Duration(milliseconds: widget.initialDurationMs);
    _player.onPositionChanged.listen((p) { if (mounted) setState(() => _position = p); });
    _player.onDurationChanged.listen((d) { if (mounted) setState(() => _duration = d); });
    _player.onPlayerStateChanged.listen((s) { if (mounted) setState(() => _playing = s == PlayerState.playing); });
    _player.onPlayerComplete.listen((_) { if (mounted) setState(() => _position = _duration); });
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final bytes = await widget.loadAudio();
    if (bytes.isEmpty) throw Exception('فایل صوتی خالی است');
    await _player.setSource(BytesSource(bytes, mimeType: 'audio/mp4'));
    _loaded = true;
    await _player.setPlaybackRate(_speed);
  }

  Future<void> _toggle() async {
    if (_loading) return;
    try {
      setState(() => _loading = true);
      await _ensureLoaded();
      if (_playing) {
        await _player.pause();
      } else {
        if (_position >= _duration && _duration > Duration.zero) await _player.seek(Duration.zero);
        await _player.resume();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('پخش ویس ناموفق بود: $e')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _seekBy(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero ? Duration.zero : (target > _duration ? _duration : target);
    await _seekTo(clamped);
  }

  Future<void> _seekTo(Duration value) async {
    if (_duration <= Duration.zero) return;
    try { await _ensureLoaded(); await _player.seek(value); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('جابه‌جایی ویس ناموفق بود: $e'))); }
  }

  Future<void> _changeSpeed() async {
    const speeds = <double>[0.5, 1.0, 1.5, 2.0];
    final index = speeds.indexOf(_speed);
    final next = speeds[(index + 1) % speeds.length];
    setState(() => _speed = next);
    if (_loaded) { try { await _player.setPlaybackRate(next); } catch (_) {} }
  }

  String _fmt(Duration d) {
    final total = d.inSeconds;
    final h = total ~/ 3600, m = (total % 3600) ~/ 60, s = total % 60;
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}' : '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = widget.mine ? cs.onPrimary : cs.primary;
    final muted = widget.mine ? cs.onPrimary.withValues(alpha: .72) : cs.onSurfaceVariant;
    final double maxMs = _duration.inMilliseconds.toDouble().clamp(1.0, double.infinity).toDouble();
    final double valueMs = _position.inMilliseconds.toDouble().clamp(0.0, maxMs).toDouble();
    return SizedBox(
      width: 280,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          IconButton(onPressed: _toggle, icon: _loading ? SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2, color: accent)) : Icon(_playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, size: 42, color: accent)),
          IconButton(onPressed: () => _seekBy(-10), icon: Icon(Icons.replay_10_rounded, color: accent), visualDensity: VisualDensity.compact),
          Expanded(child: SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5), overlayShape: const RoundSliderOverlayShape(overlayRadius: 12), activeTrackColor: accent, inactiveTrackColor: muted.withValues(alpha: .25), thumbColor: accent), child: Slider(min: 0, max: maxMs, value: valueMs, onChanged: _duration == Duration.zero ? null : (v) => _seekTo(Duration(milliseconds: v.round())))),
          IconButton(onPressed: () => _seekBy(10), icon: Icon(Icons.forward_10_rounded, color: accent), visualDensity: VisualDensity.compact),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_fmt(_position), style: TextStyle(fontSize: 11, color: muted)), TextButton(onPressed: _changeSpeed, child: Text('${_speed}x')) , Text(_fmt(_duration), style: TextStyle(fontSize: 11, color: muted))]),
      ]),
    );
  }

  @override
  void dispose() { _player.dispose(); super.dispose(); }
}
