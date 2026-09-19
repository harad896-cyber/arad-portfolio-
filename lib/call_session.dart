import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CallSessionPage extends StatefulWidget {
  final String conversationId;
  final String title;
  final bool video;
  final String? existingCallId;
  final bool incoming;

  const CallSessionPage({
    super.key,
    required this.conversationId,
    required this.title,
    required this.video,
    this.existingCallId,
    this.incoming = false,
  });

  @override
  State<CallSessionPage> createState() => _CallSessionPageState();
}

class _CallSessionPageState extends State<CallSessionPage> {
  final supabase = Supabase.instance.client;
  static const _turnUrl = String.fromEnvironment('TURN_URL', defaultValue: '');
  static const _turnUser = String.fromEnvironment('TURN_USERNAME', defaultValue: '');
  static const _turnCredential = String.fromEnvironment('TURN_CREDENTIAL', defaultValue: '');

  RTCPeerConnection? _peer;
  MediaStream? _localStream;
  RealtimeChannel? _channel;
  String? _callId;
  String? _peerUserId;
  Timer? _durationTimer;
  DateTime? _connectedAt;
  Duration _duration = Duration.zero;

  bool _starting = true;
  bool _connected = false;
  bool _muted = false;
  bool _speaker = true;
  bool _ending = false;
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  bool _acceptedIncoming = false;
  String? _pendingOfferSdp;
  String _status = 'در حال آماده‌سازی تماس...';

  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  bool _remoteDescriptionSet = false;

  @override
  void initState() {
    super.initState();
    if (widget.video) {
      _localRenderer = RTCVideoRenderer();
      _remoteRenderer = RTCVideoRenderer();
      _initRenderers();
    }
    if (widget.incoming && widget.existingCallId != null) {
      _startIncomingCall();
    } else {
      _startOutgoingCall();
    }
  }

  Future<void> _initRenderers() async {
    try {
      await _localRenderer?.initialize();
      await _remoteRenderer?.initialize();
    } catch (_) {}
  }

  Future<void> _startIncomingCall() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw Exception('برای تماس باید وارد حساب شوید.');
      _callId = widget.existingCallId;
      if (_callId == null) throw Exception('شناسه تماس نامعتبر است.');
      final row = await supabase.from('call_sessions').select('caller_id,callee_id,status,call_type,offer_sdp').eq('id', _callId!).single();
      _pendingOfferSdp = row['offer_sdp']?.toString();
      _peerUserId = row['caller_id']?.toString();
      if (_peerUserId == null || _peerUserId == uid) throw Exception('تماس‌کننده نامعتبر است.');
      await _setupChannel();
      await _createPeerConnection();
      if (mounted) {
        setState(() {
          _starting = false;
          _status = 'تماس ورودی';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _starting = false; _status = 'تماس برقرار نشد'; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
      await _cleanup();
    }
  }

  Future<void> _acceptIncoming() async {
    final sdp = _pendingOfferSdp;
    final peer = _peer;
    if (sdp == null || peer == null) {
      if (mounted) setState(() => _status = 'در انتظار اطلاعات تماس...');
      return;
    }
    try {
      _acceptedIncoming = true;
      await peer.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
      _remoteDescriptionSet = true;
      await _flushRemoteCandidates();
      final answer = await peer.createAnswer({'offerToReceiveAudio': 1, 'offerToReceiveVideo': widget.video ? 1 : 0, 'voiceActivityDetection': true});
      await peer.setLocalDescription(answer);
      await _sendSignal({'type': 'answer', 'sdp': answer.sdp});
      if (_callId != null) {
        await supabase.from('call_sessions').update({
          'status': 'accepted',
          'accepted_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', _callId!);
      }
      if (mounted) setState(() => _status = 'در حال اتصال...');
    } catch (_) {
      await _failCall('پذیرش تماس ناموفق بود.');
    }
  }

  Future<void> _rejectIncoming() async {
    try { await _sendSignal({'type': 'reject'}); } catch (_) {}
    await _finishStatus('rejected');
    await _cleanup();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<String?> _findPeerUserId() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;
    final rows = List<Map<String, dynamic>>.from(
      await supabase.from('conversation_members').select('user_id').eq('conversation_id', widget.conversationId),
    );
    for (final row in rows) {
      final id = row['user_id']?.toString();
      if (id != null && id.isNotEmpty && id != uid) return id;
    }
    return null;
  }

  Future<void> _startOutgoingCall() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw Exception('برای تماس باید وارد حساب شوید.');
      _peerUserId = await _findPeerUserId();
      if (_peerUserId == null) throw Exception('طرف مقابل این گفت‌وگو پیدا نشد.');

      final row = await supabase.from('call_sessions').insert({
        'conversation_id': widget.conversationId,
        'caller_id': uid,
        'callee_id': _peerUserId,
        'call_type': widget.video ? 'video' : 'voice',
        'status': 'ringing',
      }).select('id').single();
      _callId = row['id'].toString();

      await _setupChannel();
      await _createPeerConnection();
      await _createAndSendOffer();

      if (mounted) {
        setState(() {
          _starting = false;
          _status = 'در انتظار پاسخ...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _starting = false;
          _status = 'تماس برقرار نشد';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
      await _cleanup();
    }
  }

  Future<void> _setupChannel() async {
    final callId = _callId;
    if (callId == null) throw Exception('شناسه تماس ایجاد نشد.');
    final channel = supabase.channel('call:$callId', opts: const RealtimeChannelConfig(private: true));
    channel.onBroadcast(event: 'signal', callback: (payload) {
      unawaited(_handleSignal(payload));
    });
    channel.subscribe();
    _channel = channel;
  }

  Future<void> _createPeerConnection() async {
    final configuration = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        if (_turnUrl.isNotEmpty && _turnUser.isNotEmpty && _turnCredential.isNotEmpty)
          {'urls': _turnUrl, 'username': _turnUser, 'credential': _turnCredential},
      ],
      'iceCandidatePoolSize': 10,
      'iceTransportPolicy': 'all',
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    };

    final peer = await createPeerConnection(configuration);
    _peer = peer;

    peer.onIceCandidate = (candidate) {
      if (candidate.candidate == null || _channel == null) return;
      unawaited(_sendSignal({
        'type': 'ice',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      }));
    };

    peer.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _markConnected();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _failCall('اتصال تماس ناموفق شد.');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        if (mounted && !_ending) setState(() => _status = 'ارتباط ناپایدار...');
      }
    };

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': widget.video ? {
        'width': {'ideal': 480, 'max': 854},
        'height': {'ideal': 270, 'max': 480},
        'frameRate': {'ideal': 20, 'max': 24},
        'facingMode': 'user',
      } : false,
    });

    if (widget.video && _localRenderer != null) {
      _localRenderer!.srcObject = _localStream;
    }
    for (final track in _localStream!.getTracks()) {
      await peer.addTrack(track, _localStream!);
    }
    peer.onTrack = (event) {
      if (event.streams.isNotEmpty && _remoteRenderer != null) {
        _remoteRenderer!.srcObject = event.streams.first;
      }
    };
  }

  Future<void> _createAndSendOffer() async {
    final peer = _peer;
    if (peer == null) return;
    final offer = await peer.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': widget.video ? 1 : 0,
      'voiceActivityDetection': true,
      'iceRestart': true,
    });
    await peer.setLocalDescription(offer);
    await supabase.from('call_sessions').update({'offer_sdp': offer.sdp}).eq('id', _callId!);
    await _sendSignal({'type': 'offer', 'sdp': offer.sdp});
  }

  Future<void> _handleSignal(Map<String, dynamic> payload) async {
    final type = payload['type']?.toString();
    final peer = _peer;
    if (peer == null) return;

    try {
      if (type == 'offer' && widget.incoming) {
        _pendingOfferSdp = payload['sdp']?.toString();
        if (mounted && !_acceptedIncoming) setState(() => _status = 'تماس ورودی — آماده پاسخ');
      } else if (type == 'answer') {
        final sdp = payload['sdp']?.toString();
        if (sdp == null) return;
        await peer.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
        _remoteDescriptionSet = true;
        await _flushRemoteCandidates();
      } else if (type == 'ice') {
        final candidate = payload['candidate']?.toString();
        if (candidate == null || candidate.isEmpty) return;
        final ice = RTCIceCandidate(
          candidate,
          payload['sdpMid']?.toString(),
          (payload['sdpMLineIndex'] as num?)?.toInt(),
        );
        if (_remoteDescriptionSet) {
          await peer.addCandidate(ice);
        } else {
          _pendingRemoteCandidates.add(ice);
        }
      } else if (type == 'reject' || type == 'hangup') {
        if (mounted && !_ending) setState(() => _status = type == 'reject' ? 'تماس رد شد' : 'تماس پایان یافت');
        await _finishStatus(type == 'reject' ? 'rejected' : 'ended');
        await _cleanup();
        if (mounted) Navigator.of(context).maybePop();
      }
    } catch (_) {
      await _failCall('خطا در برقراری ارتباط صوتی.');
    }
  }

  Future<void> _flushRemoteCandidates() async {
    final peer = _peer;
    if (peer == null) return;
    for (final candidate in List<RTCIceCandidate>.from(_pendingRemoteCandidates)) {
      await peer.addCandidate(candidate);
    }
    _pendingRemoteCandidates.clear();
  }

  Future<void> _sendSignal(Map<String, dynamic> payload) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.sendBroadcastMessage(event: 'signal', payload: payload);
  }

  Future<void> _markConnected() async {
    if (_connected) return;
    _connected = true;
    _connectedAt = DateTime.now();
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = _connectedAt;
      if (!mounted || started == null) return;
      setState(() => _duration = DateTime.now().difference(started));
    });

    if (_callId != null) {
      await supabase.from('call_sessions').update({
        'status': 'accepted',
        'accepted_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', _callId!);
    }
    if (mounted) setState(() => _status = 'متصل');
  }

  Future<void> _toggleMute() async {
    final stream = _localStream;
    if (stream == null) return;
    final next = !_muted;
    for (final track in stream.getAudioTracks()) {
      track.enabled = !next;
    }
    if (mounted) setState(() => _muted = next);
  }

  Future<void> _toggleSpeaker() async {
    try {
      await Helper.setSpeakerphoneOn(!_speaker);
    } catch (_) {}
    if (mounted) setState(() => _speaker = !_speaker);
  }

  Future<void> _failCall(String message) async {
    if (_ending) return;
    if (mounted) setState(() => _status = message);
    await _finishStatus('failed');
    await _cleanup();
  }

  Future<void> _finishStatus(String status) async {
    final id = _callId;
    if (id == null) return;
    try {
      await supabase.from('call_sessions').update({
        'status': status,
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
    } catch (_) {}
  }

  Future<void> _endCall({bool notifyPeer = true}) async {
    if (_ending) return;
    _ending = true;
    if (notifyPeer) {
      try {
        await _sendSignal({'type': 'hangup'});
      } catch (_) {}
    }
    await _finishStatus(_connected ? 'ended' : 'cancelled');
    await _cleanup();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _cleanup() async {
    _durationTimer?.cancel();
    _durationTimer = null;
    try {
      for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
        await track.stop();
      }
    } catch (_) {}
    try { await _localStream?.dispose(); } catch (_) {}
    _localStream = null;
    try { await _localRenderer?.dispose(); } catch (_) {}
    try { await _remoteRenderer?.dispose(); } catch (_) {}
    _localRenderer = null;
    _remoteRenderer = null;

    try {
      await _peer?.close();
      await _peer?.dispose();
    } catch (_) {}
    _peer = null;

    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try { await supabase.removeChannel(channel); } catch (_) {}
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours.toString().padLeft(2, '0')}:' : ''}$m:$s';
  }

  @override
  void dispose() {
    unawaited(_cleanup());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _endCall(),
      child: Scaffold(
        backgroundColor: scheme.brightness == Brightness.dark ? const Color(0xFF090A0D) : const Color(0xFFEFF2F7),
        appBar: AppBar(
          title: Text(widget.video ? 'تماس تصویری' : 'تماس صوتی'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.video && _remoteRenderer != null)
              Positioned.fill(
                child: RTCVideoView(_remoteRenderer!, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
            if (widget.video && _localRenderer != null)
              Positioned(
                top: 18,
                right: 18,
                width: 120,
                height: 170,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: RTCVideoView(_localRenderer!, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.video)
                  Container(
                    width: 164,
                    height: 164,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary.withValues(alpha: .12),
                      border: Border.all(color: scheme.primary.withValues(alpha: .25)),
                    ),
                    child: Icon(Icons.person_rounded, size: 86, color: scheme.primary),
                  ),
                  if (!widget.video) const SizedBox(height: 22),
                  if (widget.video && !_connected && _status.contains('در انتظار')) const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('در حال برقراری تماس تصویری…')),
                  Text(widget.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(_connected ? _formatDuration(_duration) : _status, style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),

                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (widget.incoming && !_acceptedIncoming) ...[
                      FilledButton.icon(onPressed: _rejectIncoming, icon: const Icon(Icons.call_end_rounded), label: const Text('رد تماس')),
                      FilledButton.icon(onPressed: _acceptIncoming, icon: const Icon(Icons.call_rounded), label: const Text('پاسخ')),
                    ] else ...[
                    _control(Icons.mic_off_rounded, _muted, _toggleMute),
                    _control(_speaker ? Icons.volume_up_rounded : Icons.volume_off_rounded, _speaker, _toggleSpeaker),
                    Material(
                      color: scheme.error,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _endCall(),
                        child: const Padding(
                          padding: EdgeInsets.all(19),
                          child: Icon(Icons.call_end_rounded, color: Colors.white, size: 29),
                        ),
                      ),
                    ),
                    ],
                  ],
                ),
              ),
            ),
            if (_starting)
              const Positioned.fill(
                child: ColoredBox(color: Color(0x66000000), child: Center(child: CircularProgressIndicator())),
              ),
          ],
        ),
      ),
    );
  }

  Widget _control(IconData icon, bool active, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: active ? scheme.primary.withValues(alpha: .14) : scheme.surfaceContainerHighest.withValues(alpha: .78),
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
