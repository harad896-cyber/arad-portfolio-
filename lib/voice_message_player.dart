import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final Future<Uint8List> Function() loadAudio;
  final int initialDurationMs;
  final bool mine;

  const VoiceMessagePlayer({
    super.key,
    required this.loadAudio,
    this.initialDurationMs = 0,
    this.mine = false,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;
  bool _loading = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDurationMs > 0) {
      _duration = Duration(milliseconds: widget.initialDurationMs);
    }
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = _duration);
    });
  }

  Future<void> _toggle() async {
    if (_loading) return;
    try {
      if (_playing) {
        await _player.pause();
        return;
      }
      if (_position >= _duration && _duration > Duration.zero) {
        await _player.seek(Duration.zero);
      }
      if (_duration == Duration.zero) {
        setState(() => _loading = true);
        final bytes = await widget.loadAudio();
        if (bytes.isEmpty) throw Exception('فایل صوتی خالی است');
        await _player.play(BytesSource(bytes, mimeType: 'audio/mp4'), mode: PlayerMode.mediaPlayer);
        await _player.setPlaybackRate(_speed);
      } else {
        await _player.resume();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('پخش ویس ناموفق بود: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _seekBy(int seconds) async {
    if (_duration <= Duration.zero) return;
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : target > _duration
            ? _duration
            : target;
    await _player.seek(clamped);
  }

  Future<void> _seekTo(Duration value) async {
    if (_duration <= Duration.zero) return;
    await _player.seek(value);
  }

  Future<void> _changeSpeed() async {
    const speeds = [0.5, 1.0, 1.5, 2.0];
    final next = speeds[(speeds.indexOf(_speed) + 1) % speeds.length];
    setState(() => _speed = next);
    await _player.setPlaybackRate(next);
  }

  String _fmt(Duration d) {
    final total = d.inSeconds;
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = widget.mine ? cs.onPrimary : cs.primary;
    final muted = widget.mine ? cs.onPrimary.withValues(alpha: .72) : cs.onSurfaceVariant;
    final maxMs = _duration.inMilliseconds.toDouble().clamp(1, double.infinity);
    final valueMs = _position.inMilliseconds.toDouble().clamp(0, maxMs);

    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: _playing ? 'مکث' : 'پخش ویس',
                onPressed: _toggle,
                icon: _loading
                    ? SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                    : Icon(_playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, size: 42, color: accent),
              ),
              IconButton(
                tooltip: '۱۰ ثانیه عقب',
                onPressed: () => _seekBy(-10),
                icon: Icon(Icons.replay_10_rounded, color: accent),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: accent,
                    inactiveTrackColor: muted.withValues(alpha: .25),
                    thumbColor: accent,
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMs,
                    value: valueMs,
                    onChanged: _duration == Duration.zero ? null : (v) => _seekTo(Duration(milliseconds: v.round())),
                  ),
                ),
              ),
              IconButton(
                tooltip: '۱۰ ثانیه جلو',
                onPressed: () => _seekBy(10),
                icon: Icon(Icons.forward_10_rounded, color: accent),
                visualDensity: VisualDensity.compact,
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _changeSpeed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  child: Text('${_speed}x', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accent)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48, right: 48, bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(_position), style: TextStyle(fontSize: 11, color: muted)),
                Text(_fmt(_duration), style: TextStyle(fontSize: 11, color: muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
