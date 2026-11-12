import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Two-player, audio-only WebRTC room call. Signalling is private to room members.
class FunGameVoiceCallButton extends StatelessWidget {
  final String roomId;
  final bool isCaller;
  const FunGameVoiceCallButton({super.key, required this.roomId, required this.isCaller});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => showModalBottomSheet<void>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (_) => _FunGameVoiceCallSheet(roomId: roomId, isCaller: isCaller),
    ),
    icon: const Icon(Icons.headset_mic_rounded),
    label: const Text('مکالمهٔ صوتی زنده'),
  );
}

class _FunGameVoiceCallSheet extends StatefulWidget {
  final String roomId;
  final bool isCaller;
  const _FunGameVoiceCallSheet({required this.roomId, required this.isCaller});
  @override State<_FunGameVoiceCallSheet> createState() => _FunGameVoiceCallSheetState();
}

class _FunGameVoiceCallSheetState extends State<_FunGameVoiceCallSheet> {
  final _db = Supabase.instance.client;
  RTCPeerConnection? _peer;
  MediaStream? _local;
  RealtimeChannel? _channel;
  final List<RTCIceCandidate> _pendingIce = [];
  bool _starting = false, _active = false, _muted = false, _remoteDescriptionSet = false;
  bool _offerSent = false, _readyResponseSent = false;\n  String? _pendingOfferSdp;
  String _status = 'برای صحبت، میکروفن را روشن کن.';
  String? get _uid => _db.auth.currentUser?.id;

  @override
  void dispose() {
    unawaited(_cleanup(sendHangup: true));
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting || _peer != null) return;
    if (_uid == null) { _showError('برای تماس باید وارد حساب شوی.'); return; }
    setState(() { _starting = true; _status = 'در حال آماده‌سازی میکروفن…'; });
    try {
      final channel = _db.channel('fun-game-voice:${widget.roomId}',
        opts: const RealtimeChannelConfig(private: true));
      channel.onBroadcast(event: 'signal', callback: (payload) {
        if (payload['from']?.toString() == _uid) return;
        unawaited(_handleSignal(payload));
      });
      await channel.subscribe();
      if (!mounted) { await _db.removeChannel(channel); return; }
      _channel = channel;
      final peer = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun.cloudflare.com:3478'},
          {'urls': 'turn:openrelay.metered.ca:443','username':'openrelayproject','credential':'openrelayproject'},
        ],
        'iceCandidatePoolSize': 8,
        'iceTransportPolicy': 'all',
        'sdpSemantics': 'unified-plan',
      });
      _peer = peer;
      peer.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        unawaited(_signal({
          'type':'ice','candidate':candidate.candidate,
          'sdpMid':candidate.sdpMid,'sdpMLineIndex':candidate.sdpMLineIndex,
        }));
      };
      peer.onConnectionState = (state) {
        if (!mounted) return;
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          setState(() { _active = true; _status = 'تماس صوتی برقرار است'; });
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          setState(() { _active = false; _status = 'ارتباط ناپایدار است؛ دوباره تلاش کن.'; });
        }
      };
      _local = await navigator.mediaDevices.getUserMedia({
        'audio': {'echoCancellation':true,'noiseSuppression':true,'autoGainControl':true},
        'video': false,
      });
      for (final track in _local!.getAudioTracks()) {
        await peer.addTrack(track, _local!);
      }
      if (!mounted) return;
      setState(() { _starting = false; _status = 'در انتظار اتصال حریف…'; });
      await _signal({'type':'ready'});
    } catch (e) {
      if (mounted) setState(() { _starting = false; _status = 'میکروفن یا اتصال آماده نشد.'; });
      _showError(e.toString().replaceFirst('Exception: ', ''));
      await _cleanup(sendHangup: false);
    }
  }

  Future<void> _handleSignal(Map<String,dynamic> data) async {
    final peer = _peer;
    if (peer == null || !mounted) return;
    final type = data['type']?.toString();
    try {
      if (type == 'ready') {
        if (widget.isCaller && !_offerSent) await _createOffer();
        if (!widget.isCaller && !_readyResponseSent) {
          _readyResponseSent = true;
          await _signal({'type':'ready'});
        }
      } else if (type == 'offer' && !widget.isCaller) {
        final sdp = data['sdp']?.toString();
        if (sdp == null) return;
        await peer.setRemoteDescription(RTCSessionDescription(sdp,'offer'));
        _remoteDescriptionSet = true;
        await _flushIce();
        final answer = await peer.createAnswer({'offerToReceiveAudio':1,'voiceActivityDetection':true});
        await peer.setLocalDescription(answer);
        await _signal({'type':'answer','sdp':answer.sdp});
      } else if (type == 'answer' && widget.isCaller) {
        final sdp = data['sdp']?.toString();
        if (sdp == null) return;
        await peer.setRemoteDescription(RTCSessionDescription(sdp,'answer'));
        _remoteDescriptionSet = true;
        await _flushIce();
      } else if (type == 'ice') {
        final raw = data['candidate']?.toString();
        if (raw == null || raw.isEmpty) return;
        final ice = RTCIceCandidate(raw,data['sdpMid']?.toString(),(data['sdpMLineIndex'] as num?)?.toInt());
        if (_remoteDescriptionSet) { await peer.addCandidate(ice); } else { _pendingIce.add(ice); }
      } else if (type == 'hangup') {
        if (mounted) setState(() { _active = false; _status = 'حریف تماس را پایان داد.'; });
        await _cleanup(sendHangup: false);
      }
    } catch (_) {
      if (mounted) setState(() { _active = false; _status = 'تماس برقرار نشد؛ دوباره امتحان کن.'; });
    }
  }

  Future<void> _createOffer() async {
    if (_offerSent || _peer == null) return;
    _offerSent = true;
    final offer = await _peer!.createOffer({
      'offerToReceiveAudio':1,'voiceActivityDetection':true,'iceRestart':true,
    });
    await _peer!.setLocalDescription(offer);
    await _signal({'type':'offer','sdp':offer.sdp});
  }

  Future<void> _flushIce() async {
    final peer = _peer;
    if (peer == null) return;
    for (final item in List<RTCIceCandidate>.from(_pendingIce)) {
      await peer.addCandidate(item);
    }
    _pendingIce.clear();
  }

  Future<void> _signal(Map<String,dynamic> payload) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.sendBroadcastMessage(event:'signal',payload:{...payload,'from':_uid});
  }

  void _toggleMute() {
    final next = !_muted;
    for (final track in _local?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !next;
    }
    setState(() => _muted = next);
  }

  Future<void> _end() async {
    try { await _signal({'type':'hangup'}); } catch (_) {}
    await _cleanup(sendHangup:false);
    if (mounted) setState(() { _active = false; _status = 'تماس پایان یافت.'; });
  }

  Future<void> _cleanup({required bool sendHangup}) async {
    if (sendHangup) { try { await _signal({'type':'hangup'}); } catch (_) {} }
    final channel = _channel; _channel = null;
    final local = _local; _local = null;
    final peer = _peer; _peer = null;
    for (final track in local?.getTracks() ?? <MediaStreamTrack>[]) {
      try { await track.stop(); } catch (_) {}
    }
    try { await local?.dispose(); } catch (_) {}
    try { await peer?.close(); } catch (_) {}
    try { await peer?.dispose(); } catch (_) {}
    if (channel != null) { try { await _db.removeChannel(channel).timeout(const Duration(seconds:2)); } catch (_) {} }
  }

  void _showError(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22,12,22,26),
      child: Column(mainAxisSize:MainAxisSize.min,children:[
        const Icon(Icons.graphic_eq_rounded,size:42),
        const SizedBox(height:8),
        const Text('مکالمهٔ صوتی داخل بازی',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
        const SizedBox(height:6),
        Text(_status,textAlign:TextAlign.center),
        const SizedBox(height:16),
        Wrap(alignment:WrapAlignment.center,spacing:12,children:[
          FilledButton.icon(
            onPressed:_peer==null&&!_starting?_start:null,
            icon:_starting?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.mic_rounded),
            label:Text(_starting?'در حال اتصال':'شروع میکروفن'),
          ),
          if(_peer!=null) IconButton.filledTonal(
            onPressed:_toggleMute,
            icon:Icon(_muted?Icons.mic_off_rounded:Icons.mic_rounded),
            tooltip:_muted?'روشن‌کردن میکروفن':'قطع میکروفن',
          ),
          if(_peer!=null) IconButton.filled(
            style:IconButton.styleFrom(backgroundColor:Colors.red),
            onPressed:_end,icon:const Icon(Icons.call_end_rounded),tooltip:'پایان تماس',
          ),
        ]),
        const SizedBox(height:4),
        const Text('تماس صوتی فقط برای دو عضو همین اتاق قابل دسترسی است.',style:TextStyle(fontSize:10)),
      ]),
    ),
  );
}
