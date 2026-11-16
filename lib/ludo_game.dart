import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'fun_zone_theme.dart';
import 'ludo_customization.dart';
import 'ludo_character_editor.dart';
import 'fun_game_room_chat.dart';
import 'fun_game_voice_call.dart';
import 'ludo_engine.dart' as engine;
import 'ludo_move_decision.dart' as move_decision;
import 'ludo_bot_policy.dart' as bot_policy;

/// Ludo progress: -1 = yard, 0..50 = shared track, 51..56 = home lane, 57 = home.
class LudoRules {
  static const startOffsets = [0, 39, 26, 13];
  static const safeSquares = {0, 8, 13, 21, 26, 34, 39, 47};

  static List<int> legalTokens(List<int> pieces, int dice) => [
    for (var i = 0; i < pieces.length; i++)
      if ((pieces[i] == -1 && dice == 6) ||
          (pieces[i] >= 0 && pieces[i] < 57 && pieces[i] + dice <= 57)) i,
  ];

  static bool _validPositions(List<List<int>> positions) =>
      positions.length >= 2 &&
      positions.length <= 4 &&
      positions.every((row) =>
          row.length == 4 && row.every((progress) => progress >= -1 && progress <= 57));

  static List<int> legalTokensInGame(List<List<int>> positions, int player, int dice) {
    if (!_validPositions(positions) ||
        player < 0 ||
        player >= positions.length ||
        dice < 1 ||
        dice > 6) {
      return const [];
    }
    return legalTokens(positions[player], dice)
        .where((token) => _pathIsClear(positions, player, token, dice))
        .toList();
  }

  static bool _pathIsClear(List<List<int>> positions, int player, int token, int dice) {
    final current = positions[player][token];

    // A token leaving the yard enters directly onto its start square. It does
    // not travel the remaining five pips, so only that entry square can block it.
    if (current == -1) {
      final entrySquare = trackIndex(player, 0, playerCount: positions.length);
      if (entrySquare == null) return true;
      for (var p = 0; p < positions.length; p++) {
        var samePlayerOccupants = 0;
        for (final pieceProgress in positions[p]) {
          if (trackIndex(p, pieceProgress, playerCount: positions.length) == entrySquare) {
            samePlayerOccupants++;
          }
        }
        if (samePlayerOccupants >= 2) return false;
      }
      return true;
    }

    for (var step = 1; step <= dice; step++) {
      final progress = current + step;
      final square = trackIndex(player, progress, playerCount: positions.length);
      if (square == null) continue;
      for (var p = 0; p < positions.length; p++) {
        var samePlayerOccupants = 0;
        for (final pieceProgress in positions[p]) {
          if (trackIndex(p, pieceProgress, playerCount: positions.length) == square) {
            samePlayerOccupants++;
          }
        }
        // A blockade is formed by two pieces belonging to the same player.
        if (samePlayerOccupants >= 2) return false;
      }
    }
    return true;
  }

  /// Advances turns in the fixed board order: red, blue, yellow, green.
  static int nextPlayer(int current, int playerCount) {
    if (playerCount < 2 || playerCount > 4 || current < 0 || current >= playerCount) {
      throw ArgumentError('Invalid Ludo turn.');
    }
    return (current + 1) % playerCount;
  }

  static int offsetFor(int player, int playerCount) =>
      playerCount == 2 && player == 1 ? 26 : startOffsets[player];

  static int? trackIndex(int player, int progress, {int playerCount = 4}) {
    if (playerCount < 2 ||
        playerCount > 4 ||
        player < 0 ||
        player >= playerCount ||
        progress < 0 ||
        progress > 50) {
      return null;
    }
    return (offsetFor(player, playerCount) + progress) % 52;
  }

  static LudoMoveResult move({
    required List<List<int>> positions,
    required int player,
    required int token,
    required int dice,
  }) {
    if (!_validPositions(positions) ||
        player < 0 ||
        player >= positions.length ||
        token < 0 ||
        token >= 4 ||
        dice < 1 ||
        dice > 6 ||
        !legalTokensInGame(positions, player, dice).contains(token)) {
      throw StateError('Illegal Ludo move.');
    }
    final next = positions[player][token] == -1 ? 0 : positions[player][token] + dice;
    final updated = positions.map((row) => List<int>.from(row)).toList();
    updated[player][token] = next;
    var captured = false;
    final landing = trackIndex(player, next, playerCount: updated.length);
    if (landing != null && !safeSquares.contains(landing)) {
      for (var other = 0; other < updated.length; other++) {
        if (other == player) continue;
        for (var piece = 0; piece < 4; piece++) {
          if (trackIndex(other, updated[other][piece], playerCount: updated.length) == landing) {
            updated[other][piece] = -1;
            captured = true;
          }
        }
      }
    }
    return LudoMoveResult(
      positions: updated,
      captured: captured,
      finished: next == 57,
      won: updated[player].every((value) => value == 57),
    );
  }
}

class LudoMoveResult {
  final List<List<int>> positions;
  final bool captured, finished, won;
  const LudoMoveResult({
    required this.positions,
    required this.captured,
    required this.finished,
    required this.won,
  });
}

class LudoGamePage extends StatefulWidget {
  final String? roomId;
  final bool isCaller;
  const LudoGamePage({super.key, this.roomId, this.isCaller = true});
  @override State<LudoGamePage> createState() => _LudoGamePageState();
}

class _LudoGamePageState extends State<LudoGamePage> {
  static const _colors = [
    Color(0xFFE34D55), Color(0xFF3478E5),
    Color(0xFFF0BD35), Color(0xFF269B70),
  ];
  static const _names = ['سرخ', 'آبی', 'زرد', 'سبز'];
  final _random = math.Random();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  bool _soundEnabled = true;
  int _playerCount = 2, _turn = 0, _sixStreak = 0, _diamondBalance = 0;
  bool _againstBot = false, _started = false, _botBusy = false, _moving = false, _bonusRollAvailable = false;
  bool _autoMoveSinglePiece = false;
  bool _showFirstGuide = false;
  int _botGeneration = 0;
  int? _dice, _winner;
  final List<int> _pendingDice = [];
  final List<int?> _diceValues = List<int?>.filled(4, null);
  String _message = 'بازی را آغاز کن.';
  LudoCharacterAppearance _myCharacter = const LudoCharacterAppearance();
  List<List<int>> _positions = [];
  final List<String> _localChatMessages = [];

  SupabaseClient? _tryGetSupabaseClient() {
    // Widget tests and offline preview can open Ludo before Supabase.initialize.
    // Treat an unavailable backend as an offline session, not a page crash.
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    LudoCustomization.current.addListener(_onLookChanged);
    LudoCustomization.load().catchError((_) {});
    final supabaseClient = _tryGetSupabaseClient();
    if (supabaseClient != null) {
      LudoCosmeticRepository(supabaseClient).loadAppearance().then((appearance) {
        if (mounted) setState(() => _myCharacter = appearance);
      }).catchError((_) {});
    }
    _loadFirstGuide();
    _refreshDiamondBalance();
  }

  Future<void> _loadFirstGuide() async {
    final show = await LudoCustomization.shouldShowFirstGuide();
    if (mounted) setState(() => _showFirstGuide = show);
  }

  void _dismissFirstGuide() {
    setState(() => _showFirstGuide = false);
    LudoCustomization.markFirstGuideSeen();
  }

  void _onLookChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LudoCustomization.current.removeListener(_onLookChanged);
    _sfxPlayer.dispose();
    super.dispose();
  }

  Future<void> _sfxQueue = Future<void>.value();

  Future<void> _playSfx(String kind) {
    if (!_soundEnabled || !mounted) return Future<void>.value();
    _sfxQueue = _sfxQueue.then((_) async {
      if (!_soundEnabled || !mounted) return;
      try {
        // Arcade-style dice rattle, crisp token clicks, bright capture chime,
        // and a layered victory fanfare tuned for phone speakers.
        const sampleRate = 44100;
        final duration = switch (kind) {
          'roll' => .62,
          'capture' => .38,
          'win' => 1.05,
          _ => .16,
        };
        final count = (sampleRate * duration).round();
        final bytes = BytesBuilder(copy: false);
        final header = ByteData(44);
        void putText(int offset, String value) {
          for (var i = 0; i < value.length; i++) {
            header.setUint8(offset + i, value.codeUnitAt(i));
          }
        }
        putText(0, 'RIFF');
        header.setUint32(4, 36 + count * 2, Endian.little);
        putText(8, 'WAVE');
        putText(12, 'fmt ');
        header.setUint32(16, 16, Endian.little);
        header.setUint16(20, 1, Endian.little);
        header.setUint16(22, 1, Endian.little);
        header.setUint32(24, sampleRate, Endian.little);
        header.setUint32(28, sampleRate * 2, Endian.little);
        header.setUint16(32, 2, Endian.little);
        header.setUint16(34, 16, Endian.little);
        putText(36, 'data');
        header.setUint32(40, count * 2, Endian.little);
        bytes.add(header.buffer.asUint8List());

        final pcm = ByteData(count * 2);
        final random = math.Random(kind.hashCode ^ DateTime.now().microsecondsSinceEpoch);
        for (var i = 0; i < count; i++) {
          final t = i / sampleRate;
          final p = i / count;
          double sample = 0;

          if (kind == 'roll') {
            // A quiet, rounded rattle made of spaced soft taps and filtered noise.
            final tapPhase = (t * 9.0) % 1.0;
            final tapEnvelope = math.exp(-tapPhase * 13) *
                (t < .53 ? 1.0 : math.max(0, 1 - (t - .53) / .09));
            final noise = (random.nextDouble() - .5) * .24;
            final lowBody = math.sin(2 * math.pi * (205 + 42 * math.sin(t * 15)) * t) * .24;
            final tick = math.sin(2 * math.pi * (920 + 180 * math.sin(t * 24)) * t) * .10;
            sample = (noise + lowBody + tick) * tapEnvelope;
            sample += math.sin(2 * math.pi * 330 * t) *
                math.exp(-math.pow((t - .54) / .07, 2) * 2) * .32;
            sample += math.sin(2 * math.pi * 660 * t) *
                math.exp(-math.pow((t - .57) / .045, 2) * 2) * .12;
          } else if (kind == 'capture') {
            final env = math.exp(-p * 7);
            sample = (math.sin(2 * math.pi * 523.25 * t) * .28 +
                math.sin(2 * math.pi * 783.99 * t) * .16 +
                math.sin(2 * math.pi * 1046.5 * t) * .07) * env;
          } else if (kind == 'win') {
            final notes = [392.0, 493.88, 587.33];
            final noteIndex = math.min(2, (t / .25).floor());
            final noteTime = t - noteIndex * .25;
            final noteEnv = math.exp(-noteTime * 3.8) *
                math.min(1.0, noteTime * 35);
            final fundamental = math.sin(2 * math.pi * notes[noteIndex] * t);
            final softHarmonic = math.sin(2 * math.pi * notes[noteIndex] * 2 * t) * .08;
            sample = (fundamental + softHarmonic) * noteEnv * .30;
          } else {
            // A short, soft wooden/plastic tap for token movement.
            final env = math.exp(-t * 24);
            sample = (math.sin(2 * math.pi * 185 * t) * .34 +
                math.sin(2 * math.pi * 370 * t) * .09) * env;
          }

          // Keep all effects comfortably quiet and avoid harsh clipping.
          final fadeIn = math.min(1.0, t * 90);
          final fadeOut = math.min(1.0, (duration - t) * 35);
          final value = (sample * fadeIn * fadeOut * 8200)
              .round().clamp(-32768, 32767).toInt();
          pcm.setInt16(i * 2, value, Endian.little);
        }
        bytes.add(pcm.buffer.asUint8List());
        await _sfxPlayer.play(BytesSource(bytes.takeBytes(), mimeType: 'audio/wav'));
      } catch (_) {
        // Audio must never interrupt gameplay on restricted Android devices.
      }
    }).catchError((_) {
      // A failed sound effect must not break subsequent effects.
    });
    return _sfxQueue;
  }

  // In bot mode the human always controls red (player 0); every other seat is automated.
  bool get _botTurn => bot_policy.isLudoAutomatedTurn(
    enabled: _againstBot,
    activePlayer: _turn,
  );
  int _colorIndex(int player) => _playerCount == 2 && player == 1 ? 2 : player;
  int _baseIndex(int player) => _playerCount == 2 && player == 1 ? 2 : player;
  Color _playerColor(int player) => _colors[_colorIndex(player)];
  String _playerName(int player) => _names[_colorIndex(player)];
  engine.LudoState get _engineState => {
    'players': List.generate(_playerCount, (i) => {'id': 'player-$i'}),
    'pieces': _positions.map((row) => List<int>.from(row)).toList(),
    'turn': _turn,
    'dice': _dice == null ? null : {'value': _dice},
    'phase': _dice == null ? 'awaiting_roll' : 'awaiting_move',
    'sixStreak': _sixStreak.clamp(0, 2),
    'winners': _winner == null ? <int>[] : <int>[_winner!],
  };
  List<int> get _legal => _dice == null
      ? const []
      : engine.getLegalMoves(_engineState, _dice!);

  void _start({required int players, required bool bot}) {
    setState(() {
      _playerCount = players;
      _againstBot = bot;
      _positions = List.generate(players, (_) => List.filled(4, -1));
      _turn = 0; _dice = null; _winner = null; _sixStreak = 0; _pendingDice.clear(); _bonusRollAvailable = false;
      for (var i = 0; i < _diceValues.length; i++) { _diceValues[i] = null; }
      _botBusy = false; _moving = false; _botGeneration++; _started = true;
      _message = 'نوبت ${_playerName(_turn)} است؛ تاس بینداز.';
    });
  }

  void _roll({bool fromBot = false}) {
    if (!_started || _winner != null || _dice != null || _moving ||
        (_botBusy && !fromBot) || (_pendingDice.isNotEmpty && !_bonusRollAvailable)) return;
    _playSfx('roll');
    final value = _random.nextInt(6) + 1;
    if (value == 6) {
      _sixStreak++;
      if (_sixStreak >= 3) {
        _handleThreeSixes(fromBot: fromBot);
        return;
      }
    } else { _sixStreak = 0; }
    setState(() {
      _diceValues[_turn] = value;
      _pendingDice.add(value);
      _bonusRollAvailable = value == 6;
      _message = value == 6
          ? '۶ آوردی! یک بار دیگر تاس خودت را لمس کن.'
          : 'تاس آماده شد؛ حالا مهرهٔ روشن‌شده را انتخاب کن.';
    });

    // A normal roll is committed to move selection immediately. The player
    // never has to tap the die a second time just to select the rolled value.
    // A six still offers the legitimate bonus roll before choosing a token.
    if (value != 6 && mounted && _pendingDice.isNotEmpty) {
      _chooseDie(_pendingDice.first, fromBot: fromBot);
    }
  }

  Future<void> _refreshDiamondBalance() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final value = await Supabase.instance.client.rpc('get_my_diamond_balance')
          .timeout(const Duration(seconds: 12));
      if (mounted) setState(() => _diamondBalance = (value as num?)?.toInt() ?? 0);
    } catch (_) {
      // A missing wallet or unavailable server must never create free diamonds.
      if (mounted) setState(() => _diamondBalance = 0);
    }
  }

  Future<void> _handleThreeSixes({required bool fromBot}) async {
    if (!mounted) return;
    setState(() { _moving = true; _dice = null; });
    if (fromBot) {
      _burnThreeSixes();
      return;
    }
    await _refreshDiamondBalance();
    if (!mounted) return;
    var paid = false;
    if (_diamondBalance >= 2 && Supabase.instance.client.auth.currentUser != null) {
      final choice = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('سه بار ۶ پشت‌سرهم'),
          content: Text('برای یک پرتاب تازه، ۲ الماس مصرف کنی؟ موجودی: $_diamondBalance 💎'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('سوختن نوبت'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.diamond_outlined),
              label: const Text('مصرف ۲ الماس'),
            ),
          ],
        ),
      );
      if (choice == true) {
        try {
          final result = await Supabase.instance.client.rpc(
            'spend_ludo_diamonds', params: {'p_amount': 2},
          ).timeout(const Duration(seconds: 12));
          paid = result == true;
          await _refreshDiamondBalance();
        } catch (_) {
          paid = false;
        }
      }
    }
    if (!mounted) return;
    if (paid) {
      setState(() {
        _dice = null;
        _moving = false;
        _pendingDice.clear();
        _sixStreak = 0;
        _bonusRollAvailable = false;
        _message = '۲ الماس مصرف شد؛ تاس تازه بینداز.';
      });
      _roll();
    } else {
      _burnThreeSixes();
    }
  }

  void _burnThreeSixes() {
    if (!mounted || _winner != null) return;
    setState(() {
      _dice = null;
      _moving = false;
      _pendingDice.clear();
      _sixStreak = 0;
      _bonusRollAvailable = false;
      _turn = LudoRules.nextPlayer(_turn, _playerCount);
      _message = 'سه ۶ سوخت؛ نوبت ${_playerName(_turn)}';
    });
    _scheduleBot();
  }

  void _chooseDie(int value, {bool fromBot = false}) {
    if (_moving || _winner != null || _dice != null ||
        !_pendingDice.contains(value) || _bonusRollAvailable || (_botBusy && !fromBot)) return;
    final analysisState = <String, dynamic>{
      ..._engineState,
      'dice': {'value': value},
      'phase': 'awaiting_move',
    };
    final analysis = move_decision.getLegalMoveAnalysis(analysisState, value);
    if (!analysis.isValid) {
      setState(() => _message = analysis.error ?? 'وضعیت حرکت معتبر نیست.');
      return;
    }
    final options = analysis.legalMoves.map((move) => move.pieceIndex).toList();
    if (options.isEmpty) {
      setState(() {
        _pendingDice.remove(value);
        _message = _pendingDice.isEmpty ? 'حرکت ممکن نیست' : _pendingDice.join(' · ');
      });
      if (_pendingDice.isEmpty) _finishNoMove();
      return;
    }
    // Consume only the chosen die. The other rolled value remains available
    // for a second, independent token move during this same turn.
    setState(() {
      _pendingDice.remove(value);
      _dice = value;
      _message = 'تاس $value انتخاب شد';
    });
    // Human players always choose a token themselves by default.
    // Bots keep their automatic decision flow; the optional setting only
    // applies to a human turn with exactly one legal token.
    if (fromBot || (options.length == 1 && _autoMoveSinglePiece)) {
      final generation = _botGeneration;
      setState(() => _message = 'حرکت خودکار مهرهٔ ${options.first + 1} تا لحظه‌ای دیگر…');
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (!mounted || generation != _botGeneration || _dice != value || _winner != null) return;
        _moveToken(options.first, fromBot: fromBot);
      });
    } else {
      setState(() => _message = 'یک مهره را برای حرکت انتخاب کن.');
    }
  }

  void _finishNoMove() {
    if (!mounted || _winner != null) return;
    setState(() {
      _dice = null;
      _pendingDice.clear();
      _sixStreak = 0;
      _turn = LudoRules.nextPlayer(_turn, _playerCount);
      _message = 'نوبت ${_playerName(_turn)}';
    });
    _scheduleBot();
  }

  Future<void> _moveToken(int token, {bool fromBot = false}) async {
    if (_dice == null || _winner != null || _moving || (_botBusy && !fromBot) || !_legal.contains(token)) return;
    final movingPlayer = _turn;
    final rolledValue = _dice!;
    final generation = _botGeneration;
    final before = _positions.map((row) => List<int>.from(row)).toList();
    final engineState = <String, dynamic>{
      'players': List.generate(_playerCount, (i) => {'id': 'player-$i'}),
      'pieces': before,
      'turn': movingPlayer,
      'dice': {'value': rolledValue},
      'phase': 'awaiting_move',
      'sixStreak': _sixStreak.clamp(0, 2),
      'winners': <int>[],
    };
    final nextState = engine.applyLudoMove(engineState, token);
    final nextPositions = (nextState['pieces'] as List)
        .map((row) => (row as List).map((value) => (value as num).toInt()).toList())
        .toList();
    final diceEvent = nextState['dice'] as Map?;
    final captured = (diceEvent?['captured'] as List? ?? const []).isNotEmpty;
    final won = (nextState['winners'] as List).contains(movingPlayer);
    setState(() => _moving = true);
    _playSfx('move');
    final current = before[movingPlayer][token];
    final route = current == -1 ? <int>[0] : List<int>.generate(rolledValue, (i) => current + i + 1);
    for (final progress in route) {
      if (!mounted || generation != _botGeneration) return;
      final animatedPositions = _positions.map((row) => List<int>.from(row)).toList();
      animatedPositions[movingPlayer][token] = progress;
      setState(() => _positions = animatedPositions);
      await Future<void>.delayed(const Duration(milliseconds: 205));
    }
    if (!mounted || generation != _botGeneration) return;
    setState(() {
      _moving = false;
      _positions = nextPositions;
      _dice = null;
      if (captured) _playSfx('capture');
      if (won) {
        _playSfx('win');
        _pendingDice.clear();
        _bonusRollAvailable = false;
        _winner = _turn;
        _message = 'بازیکن ${_playerName(_turn)} برنده شد!';
      } else if (_pendingDice.isNotEmpty) {
        // Keep the unspent die for another token; do not advance the turn.
        _message = 'تاس باقی‌مانده: ${_pendingDice.join(' · ')}';
      } else {
        _sixStreak = 0;
        _turn = LudoRules.nextPlayer(_turn, _playerCount);
        _message = 'نوبت ${_playerName(_turn)}';
      }
    });
    _scheduleBot();
  }

  void _scheduleBot() {
    if (!_botTurn || _winner != null || _botBusy || !mounted) return;
    _botBusy = true;
    final generation = _botGeneration;
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (!mounted || generation != _botGeneration || !_botTurn || _winner != null) { _botBusy = false; return; }
      _botBusy = false;
      _roll(fromBot: true);
      if (!mounted || !_botTurn || _winner != null) return;
      for (var extra = 0; extra < 2 && _bonusRollAvailable; extra++) {
        _roll(fromBot: true);
        if (!mounted || !_botTurn || _winner != null) return;
      }
      if (!mounted || !_botTurn || _winner != null) return;
      final usableDice = _pendingDice.where((value) =>
        LudoRules.legalTokensInGame(_positions, _turn, value).isNotEmpty).toList();
      if (usableDice.isEmpty) { _finishNoMove(); return; }
      usableDice.sort((a, b) => b.compareTo(a));
      _chooseDie(usableDice.first, fromBot: true);
      if (!mounted || !_botTurn || _winner != null || _dice == null) return;
      final options = _legal;
      if (options.isEmpty) return;
      final ranked = List<int>.from(options)..sort((a, b) => _botScore(b).compareTo(_botScore(a)));
      _moveToken(ranked.first, fromBot: true);
    });
  }

  int _botScore(int token) {
    final result = LudoRules.move(
      positions: _positions, player: _turn, token: token, dice: _dice!,
    );
    final old = _positions[_turn][token], next = result.positions[_turn][token];
    return (result.won ? 10000 : 0) + (result.captured ? 1000 : 0) +
        (result.finished ? 500 : 0) + (old == -1 ? 100 : 0) + next;
  }

  void _reset() {
    setState(() {
      _started = false; _positions = []; _dice = null; _winner = null; _pendingDice.clear(); _bonusRollAvailable = false;
      for (var i = 0; i < _diceValues.length; i++) { _diceValues[i] = null; }
      _turn = 0; _sixStreak = 0; _botBusy = false; _botGeneration++; _message = 'بازی را آغاز کن.';
    });
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF031A16),
    appBar: AppBar(
      title: const Text('لودو'), backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(
          tooltip: 'ویرایش ظاهر منچ',
          onPressed: () => LudoCustomizationButton.open(context),
          icon: const Icon(Icons.tune_rounded),
        ),
        PopupMenuButton<String>(
          tooltip: 'تنظیمات بازی',
          onSelected: (value) {
            if (value == 'sound') setState(() => _soundEnabled = !_soundEnabled);
            if (value == 'auto') setState(() => _autoMoveSinglePiece = !_autoMoveSinglePiece);
            if (value == 'look') LudoCustomizationButton.open(context);
            if (value == 'rules') _showRules();
            if (value == 'reset') _confirmExit();
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'sound', child: Text(_soundEnabled ? 'خاموش‌کردن صدا' : 'روشن‌کردن صدا')),
            PopupMenuItem(value: 'auto', child: Text(_autoMoveSinglePiece ? 'خاموش‌کردن حرکت خودکار' : 'روشن‌کردن حرکت خودکار')),
            const PopupMenuItem(value: 'look', child: Text('شخصی‌سازی تخته')),
            const PopupMenuItem(value: 'rules', child: Text('قوانین بازی')),
            const PopupMenuItem(value: 'reset', child: Text('پایان بازی')),
          ],
        ),
      ],
    ),
    body: SafeArea(
      child: ValueListenableBuilder<LudoLook>(
        valueListenable: LudoCustomization.current,
        builder: (context, look, _) {
          final backgroundIndex = look.background.clamp(0, LudoCustomization.backgroundPalettes.length - 1).toInt();
          final backgroundBytes = LudoCustomization.decodeImage(look.backgroundImageBase64);
          // Paint the background and page content in one bounded body.
          // Avoid a full-screen Stack here: the game page must remain visible
          // even when a saved/custom background image is invalid or loading.
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: LudoCustomization.backgroundPalettes[backgroundIndex],
              ),
              image: backgroundBytes == null ? null : DecorationImage(
                image: MemoryImage(backgroundBytes),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: .55),
                  BlendMode.darken,
                ),
              ),
            ),
            // Keep the actual game widgets as direct children of the bounded
            // Scaffold body. A transparent Material + expand wrapper previously
            // made the page fragile on some Android route/theme combinations.
            child: Material(
              color: Colors.transparent,
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: _started ? _gameBody() : _modePicker(),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _modePicker() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
    children: [
      Center(
        child: Container(
          width: 104, height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFFFFE7A0), Color(0xFFD59A32), Color(0xFF70451C)],
            ),
            border: Border.all(color: const Color(0xFFFFF0C4), width: 3),
            boxShadow: const [BoxShadow(color: Color(0x66F0BD35), blurRadius: 24, spreadRadius: 2)],
          ),
          child: const Icon(Icons.casino_rounded, size: 58, color: Color(0xFF172638)),
        ),
      ),
      const SizedBox(height: 14),
      const Text('منچ گپ‌رسان', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: .2)),
      const SizedBox(height: 7),
      const Text('یک بازی دوستانه؛ با مهره‌های رنگی، تختهٔ بزرگ و ظاهر دلخواهت.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, height: 1.65, fontSize: 13)),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: () => LudoCustomizationButton.open(context),
        icon: const Icon(Icons.tune_rounded),
        label: const Text('ویرایش ظاهر و قالب‌ها'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFFD477),
          side: const BorderSide(color: Color(0xFFD5A94D)),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
      const SizedBox(height: 22),
      const Text('حالت بازی', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      _modeCard(
        icon: Icons.people_alt_rounded, title: 'بازی آفلاین',
        subtitle: '۲ تا ۴ نفر روی همین گوشی',
        selected: !_againstBot,
        onTap: () => setState(() => _againstBot = false),
      ),
      const SizedBox(height: 9),
      _modeCard(
        icon: Icons.smart_toy_rounded, title: 'بازی با ربات',
        subtitle: 'یک بازیکن انسانی در برابر سه ربات؛ چهار رنگ کامل',
        selected: _againstBot,
        onTap: () => setState(() { _againstBot = true; _playerCount = 4; }),
      ),
      const SizedBox(height: 9),
      _modeCard(
        icon: Icons.public_rounded, title: 'بازی آنلاین',
        subtitle: 'اتصال حریف و همگام‌سازی نوبت‌ها هنوز به سرور لودو وصل نشده است.',
        selected: false, enabled: false,
        onTap: () => _showOnlineUnavailable(),
      ),
      const SizedBox(height: 20),
      if (!_againstBot) ...[
        const Text('تعداد بازیکنان', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 9),
        Wrap(spacing: 9, children: [2, 3, 4].map((count) => ChoiceChip(
          label: Text('${count == 2 ? '۲' : count == 3 ? '۳' : '۴'} نفر'),
          selected: _playerCount == count,
          onSelected: (_) => setState(() => _playerCount = count),
        )).toList()),
        const SizedBox(height: 17),
      ],
      FilledButton.icon(
        onPressed: () => _start(players: _againstBot ? 4 : _playerCount, bot: _againstBot),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('شروع بازی'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ],
  );

  Widget _modeCard({
    required IconData icon, required String title, required String subtitle,
    required bool selected, required VoidCallback onTap, bool enabled = true,
  }) => Opacity(
    opacity: enabled ? 1 : .58,
    child: Material(
      color: selected ? const Color(0xFF174A42) : const Color(0xFF10263A),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : _showOnlineUnavailable,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? const Color(0xFF65D6AC) : Colors.white24, width: selected ? 1.8 : 1),
          ),
          child: Row(children: [
            Icon(icon, color: selected ? const Color(0xFF8AF0C4) : const Color(0xFFFFD477), size: 29),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.45)),
            ])),
            if (selected) const Icon(Icons.check_circle_rounded, color: Color(0xFF8AF0C4)),
            if (!enabled) const Icon(Icons.lock_outline_rounded, color: Colors.white54),
          ]),
        ),
      ),
    ),
  );

  void _showOnlineUnavailable() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بازی آنلاین لودو'),
        content: const Text('در نسخهٔ فعلی سرور فقط برای بازی‌های دیگر آماده است. برای جلوگیری از نمایش آنلاینِ غیرواقعی، لودوی آنلاین تا آماده‌شدن همگام‌سازی امن مهره‌ها و تاس غیرفعال است.'),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('متوجه شدم'))],
      ),
    );
  }

  Widget _gameBody() => LayoutBuilder(
    builder: (context, constraints) {
      final rail = 12.0;
      final boardSize = math.max(220.0, math.min(620.0, constraints.maxWidth - rail * 2));
      final frameSize = boardSize + rail * 2;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _arenaRibbon(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF061D35),
                border: Border.all(color: const Color(0xFFFFD477), width: 1.3),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(children: [
                Icon(Icons.circle, color: _playerColor(_turn), size: 9),
                const SizedBox(width: 9),
                Expanded(child: Text(_message, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
              ]),
            ),
            const SizedBox(height: 8),
            _playerRow(_playerCount == 4
                ? const [3, 2]
                : _playerCount == 3
                    ? const [2]
                    : const [1]),
            const SizedBox(height: 9),
            Center(
              child: SizedBox(
                width: frameSize,
                height: frameSize,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    left: rail, top: rail, width: boardSize, height: boardSize,
                    child: ValueListenableBuilder<FunBackdrop>(
                      valueListenable: FunZoneLook.current,
                      builder: (context, look, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFD9FFF0), width: 2),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
                              BoxShadow(color: Color(0x3300F5A0), blurRadius: 18, spreadRadius: 1),
                            ],
                          ),
                          child: Stack(children: [
                            Positioned.fill(child: CustomPaint(painter: _LudoBoardPainter(
                              colors: _colors, players: _playerCount, positions: _positions,
                              turn: _turn, dice: _moving ? null : _dice,
                              legalTokens: _moving ? const [] : _legal,
                              look: look, styleIndex: LudoCustomization.current.value.board,
                            ))),
                            for (var player = 0; player < _playerCount; player++)
                              for (var token = 0; token < 4; token++)
                                _buildToken(player, token, boardSize),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 9),
            _playerRow(_playerCount == 2 ? const [0] : const [0, 1]),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(top: 5),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF392D4B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFB89BFF).withValues(alpha: .7)),
                ),
                child: Text('$_diamondBalance 💎',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
              ),
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: const Color(0xCC07192A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x5574DDF5))),
                child: _communicationActions(),
              ),
            ),
            if (_winner != null)
              Padding(padding: const EdgeInsets.only(top: 7),
                child: SizedBox(width: double.infinity, child: FilledButton.icon(
                  onPressed: _reset, icon: const Icon(Icons.replay_rounded),
                  label: const Text('بازی دوباره')))),
          ],
        ),
      );
    },
  );

  Widget _arenaRibbon() => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 2, bottom: 3),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.centerRight, end: Alignment.centerLeft,
        colors: [Color(0xCC123D3B), Color(0xCC101C35), Color(0xCC39284B)],
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x66FFD477)),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))],
    ),
    child: const Row(children: [
      Icon(Icons.stadium_rounded, color: Color(0xFFFFD477), size: 17),
      SizedBox(width: 7),
      Expanded(child: Text('لیگ منچ گپ‌رسان', style: TextStyle(
        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .35,
      ))),
      Text('★  LUDO ARENA  ★', textDirection: TextDirection.ltr,
        style: TextStyle(color: Color(0xFFFFD477), fontSize: 9, fontWeight: FontWeight.w900)),
    ]),
  );

  Widget _edgeDiceControl(int player, {bool compact = false}) {
    final color = _playerColor(player);
    final active = _turn == player && _winner == null;
    final canRoll = active && _dice == null && !_botTurn && !_botBusy && !_moving;
    final awaitingToken = active && _dice != null && _legal.isNotEmpty && !_moving;
    final needsBonusRoll = active && _bonusRollAvailable && _pendingDice.isNotEmpty;
    final shownValue = _diceValues[player];
    final label = _againstBot && player == 1 ? 'ربات' : _playerName(player);
    // Compact controls are square so rotating them for each seat never
    // changes their layout footprint or clips inside the player card.
    final width = compact ? 50.0 : 68.0;
    final height = compact ? 50.0 : 78.0;
    final accessibleLabel = shownValue == null ? 'تاس $label' : 'تاس $label: $shownValue';
    return Semantics(
      button: true,
      enabled: canRoll,
      label: accessibleLabel,
      child: Tooltip(
      message: accessibleLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('ludo-die-$player'),
          borderRadius: BorderRadius.circular(13),
          onTap: canRoll ? _roll : null,
          child: TweenAnimationBuilder<double>(
            key: ValueKey('ludo-die-motion-$player-${_diceValues[player]}-${_dice == null}'),
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 620),
            builder: (context, motion, child) => Transform.translate(
              offset: Offset(math.sin(motion * math.pi * 8) * (1 - motion) * 3.2, 0),
              child: child,
            ),
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: width, height: height,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: active
                    ? [const Color(0xFF263D53), const Color(0xFF071626)]
                    : [const Color(0xFF172A3C), const Color(0xFF081523)],
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: active ? color : color.withValues(alpha: .78), width: active ? 2.5 : 1.2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: .42), blurRadius: 7, offset: const Offset(0, 3)),
                if (active) BoxShadow(color: color.withValues(alpha: awaitingToken ? .95 : .72), blurRadius: awaitingToken ? 22 : 15, spreadRadius: awaitingToken ? 3 : 1),
                if (awaitingToken) BoxShadow(color: const Color(0xFFFFE08A).withValues(alpha: .78), blurRadius: 26, spreadRadius: 2),
              ],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (!compact) Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
              if (!compact) const SizedBox(height: 1),
              Stack(clipBehavior: Clip.none, children: [
                _LudoDieFace(value: shownValue, size: compact ? 34 : 46),
                if (awaitingToken || needsBonusRoll)
                  Positioned(
                    top: -8, right: -9,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: awaitingToken ? const Color(0xFFFFD76A) : color,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: color.withValues(alpha: .85), blurRadius: 9, spreadRadius: 1)],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          awaitingToken ? Icons.touch_app_rounded : Icons.casino_rounded,
                          size: compact ? 12 : 15,
                          color: const Color(0xFF102235),
                        ),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
        ),
      ),
      ),
      ),
      ),
    );
  }

  Widget _communicationActions() => Row(mainAxisSize: MainAxisSize.min, children: [
    Tooltip(message: 'پیام‌های بازی', child: SizedBox(width: 42, height: 42,
      child: OutlinedButton(
        key: const ValueKey('ludo-chat-action'), onPressed: _openChat,
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFF64C9E8)), shape: const CircleBorder()),
        child: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
      ))),
    const SizedBox(width: 7),
    Tooltip(message: 'میکروفن', child: SizedBox(width: 42, height: 42,
      child: FilledButton(
        key: const ValueKey('ludo-mic-action'), onPressed: _openVoice,
        style: FilledButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: const Color(0xFF087D68),
          foregroundColor: Colors.white, shape: const CircleBorder()),
        child: const Icon(Icons.mic_none_rounded, size: 20),
      ))),
  ]);

  Future<void> _openChat() async {
    final roomId = widget.roomId;
    if (roomId != null && roomId.trim().isNotEmpty) {
      await showModalBottomSheet<void>(
        context: context, isScrollControlled: true, showDragHandle: true,
        builder: (_) => SafeArea(child: SizedBox(height: 390, child: FunGameRoomChatPanel(roomId: roomId))),
      );
      return;
    }
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, showDragHandle: true,
      backgroundColor: const Color(0xFF102235),
      builder: (sheetContext) => StatefulBuilder(builder: (context, refreshSheet) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 8, 14, 14 + MediaQuery.viewInsetsOf(context).bottom),
          child: SizedBox(height: 330, child: Column(children: [
            const Row(children: [
              Icon(Icons.chat_rounded, color: Color(0xFF64C9E8)),
              SizedBox(width: 8),
              Text('پیام‌های بازی', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              Spacer(),
              Text('بازی محلی', style: TextStyle(color: Colors.white54, fontSize: 10)),
            ]),
            const SizedBox(height: 8),
            Expanded(child: _localChatMessages.isEmpty
              ? const Center(child: Text('هنوز پیامی نوشته نشده است.', style: TextStyle(color: Colors.white60)))
              : ListView.builder(
                  reverse: true,
                  itemCount: _localChatMessages.length,
                  itemBuilder: (_, index) => Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFF1B4965), borderRadius: BorderRadius.circular(13)),
                      child: Text(_localChatMessages[_localChatMessages.length - 1 - index],
                        style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                )),
            Wrap(spacing: 6, children: ['آفرین!','نوبت توست','حرکت خوب بود','صبر کن'].map((phrase) =>
              ActionChip(label: Text(phrase), onPressed: () {
                setState(() => _localChatMessages.add(phrase));
                refreshSheet(() {});
              })).toList()),
            const SizedBox(height: 7),
            Row(children: [
              Expanded(child: TextField(
                controller: controller, style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'پیام کوتاه بنویس…', hintStyle: const TextStyle(color: Colors.white54),
                  filled: true, fillColor: const Color(0xFF071A35),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) {
                  final value = controller.text.trim();
                  if (value.isEmpty) return;
                  setState(() => _localChatMessages.add(value));
                  controller.clear();
                  refreshSheet(() {});
                },
              )),
              IconButton(
                tooltip: 'فرستادن پیام',
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isEmpty) return;
                  setState(() => _localChatMessages.add(value));
                  controller.clear();
                  refreshSheet(() {});
                },
                icon: const Icon(Icons.send_rounded, color: Color(0xFF64C9E8)),
              ),
            ]),
          ])),
        ),
      )),
    );
    controller.dispose();
  }

  Future<void> _openVoice() async {
    final roomId = widget.roomId;
    if (roomId == null || roomId.trim().isEmpty) {
      await showModalBottomSheet<void>(
        context: context, showDragHandle: true,
        builder: (context) => const SafeArea(child: Padding(
          padding: EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.mic_off_rounded, size: 38),
            SizedBox(height: 10),
            Text('میکروفن زنده', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text('تماس صوتی فقط در مسابقهٔ آنلاین با اتاق و حریف متصل فعال می‌شود. این بازی فعلاً محلی یا با ربات است.',
              textAlign: TextAlign.center),
          ]),
        )),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, showDragHandle: true,
      builder: (_) => FunGameVoiceCallSheet(roomId: roomId, isCaller: widget.isCaller),
    );
  }

  void _confirmExit() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('خروج از بازی؟'),
        content: const Text('اگر خارج شوی، بازی فعلی پایان می‌یابد.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ادامه بازی')),
          FilledButton(onPressed: () { Navigator.pop(dialogContext); _reset(); },
            child: const Text('خروج')),
        ],
      ),
    );
  }

  Widget _dockTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) =>
    Material(
      color: const Color(0xFF081A32).withValues(alpha: .94),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(13),
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFD5A94D), width: 1),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: const Color(0xFFFFD477), size: 18),
            const SizedBox(width: 4),
            Flexible(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 7)),
            ])),
          ]),
        ),
      ),
    );

  void _showRules() => showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
    title: const Text('قانون بازی لودو'),
    content: const Text('برای بیرون‌آوردن مهره از خانه ۶ لازم است. خانه‌های امن از زدن مهره محافظت می‌کنند. رسیدن به خانهٔ پایانی باید با عدد دقیق باشد. با آوردن ۶ یا زدن مهره، نوبت اضافه می‌گیری. سه بار ۶ پی‌درپی نوبت را از بین می‌برد.'),
    actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('فهمیدم'))],
  ));

  Widget _playerRow(List<int> baseSlots) => LayoutBuilder(
    builder: (context, constraints) {
      final visible = baseSlots.where((index) => index >= 0 && index < _playerCount).toList();
      if (visible.isEmpty) return const SizedBox.shrink();
      const gap = 8.0;
      final single = visible.length == 1;
      final cardWidth = single ? math.min(constraints.maxWidth * .78, 310.0) : (constraints.maxWidth - gap) / 2;
      return SizedBox(
        width: constraints.maxWidth,
        child: Wrap(
          // The seat order is explicit: green/yellow across the top,
          // red/blue across the bottom, independent of Persian RTL direction.
          textDirection: TextDirection.ltr,
          spacing: gap, runSpacing: gap, alignment: WrapAlignment.center,
          children: visible.map((index) => SizedBox(
            width: cardWidth, height: 88, child: _playerPanel(index),
          )).toList(),
        ),
      );
    },
  );

  Widget _orientedDiceControl(int player) {
    // Seat directions follow the board: red faces down, blue faces right,
    // yellow faces up, and green faces left. A square hit target keeps all
    // four controls aligned while the complete dice control turns to its seat.
    return SizedBox(
      width: 50,
      height: 50,
      child: RotatedBox(
        quarterTurns: _baseIndex(player),
        child: _edgeDiceControl(player, compact: true),
      ),
    );
  }

  Widget _playerPanel(int player) {
    final color = _playerColor(player);
    final active = _turn == player && _winner == null;
    final count = _positions[player].where((value) => value == 57).length;
    final look = LudoCustomization.current.value;
    // Character identities match the four seats in the stadium reference.
    final avatar = player == 0
        ? LudoCustomization.avatars[look.avatar]
        : const ['🦊', '🐬', '🐥', '🐸'][player];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: active
              ? [color.withValues(alpha: .38), const Color(0xEE0A1B2D)]
              : [color.withValues(alpha: .19), const Color(0xDD0A1B2D)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: active ? 1 : .55),
          width: active ? 2 : 1.1,
        ),
        boxShadow: [
          const BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
          if (active) BoxShadow(color: color.withValues(alpha: .30), blurRadius: 14, spreadRadius: 1),
        ],
      ),
      child: Row(textDirection: TextDirection.ltr, children: [
        // Dice sits on the outside edge of each seat, facing that player.
        if (_baseIndex(player) == 0 || _baseIndex(player) == 3) ...[
          _orientedDiceControl(player),
          const SizedBox(width: 5),
        ],
        Container(
          width: 35, height: 35,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white,
            border: Border.all(color: player == 0 ? LudoCustomization.frameColors[look.frame] : color, width: 2.5),
            boxShadow: [BoxShadow(color: color.withValues(alpha: .28), blurRadius: 8)]),
          child: Center(child: Text(avatar, style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 6),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_againstBot && player == 1 ? 'ربات' : _playerName(player),
            textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
          Text('$count/4 مهره رسیده', textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 9)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: count / 4, minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: .12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (active) const Text('● نوبت فعلی',
            style: TextStyle(color: Color(0xFFFFD477), fontSize: 8, fontWeight: FontWeight.w900)),
        ])),
        if (_baseIndex(player) == 1 || _baseIndex(player) == 2) ...[
          const SizedBox(width: 5),
          _orientedDiceControl(player),
        ],
      ]),
    );
  }

  Offset _tokenDisplayPoint(int player, int token, double size) {
    final point = _tokenPoint(player, token, _positions[player][token], size);
    final peers = <(int, int)>[];
    for (var p = 0; p < _playerCount; p++) {
      for (var t = 0; t < 4; t++) {
        final other = _tokenPoint(p, t, _positions[p][t], size);
        if ((other - point).distance < .01) peers.add((p, t));
      }
    }
    if (peers.length < 2) return point;
    final slot = peers.indexOf((player, token));
    final offsets = LudoBoardGeometry.compactStackOffsets(peers.length, size);
    return point + offsets[slot];
  }

  Widget _buildToken(int player, int token, double size) {
    final point = _tokenDisplayPoint(player, token, size);
    final canMove = player == _turn && _dice != null && _legal.contains(token) && !_botTurn && !_moving;
    final diameter = size * .058;
    final hitSize = diameter * 1.22;
    final color = _playerColor(player);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 185), curve: Curves.easeInOutCubic,
      left: point.dx - hitSize / 2, top: point.dy - hitSize / 2,
      width: hitSize, height: hitSize,
      child: Semantics(
        button: canMove,
        label: 'مهره ${token + 1} بازیکن ${_playerName(player)}${canMove ? '، قابل حرکت' : ''}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canMove ? () => _moveToken(token) : null,
          child: Center(child: AnimatedContainer(
            width: diameter, height: diameter,
            duration: const Duration(milliseconds: 260),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-.38, -.42), radius: .95,
                colors: [Color.lerp(color, Colors.white, .68)!, color, Color.lerp(color, Colors.black, .36)!],
                stops: const [0, .52, 1],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: canMove ? 1 : .88), width: canMove ? 2.4 : 1.2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: .38), blurRadius: 5, offset: const Offset(0, 3)),
                if (canMove) BoxShadow(color: color.withValues(alpha: .85), blurRadius: 13, spreadRadius: 1),
              ],
            ),
            child: Stack(children: [
              Align(alignment: const Alignment(-.35, -.55), child: Container(
                width: diameter * .22, height: diameter * .12,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .72), borderRadius: BorderRadius.circular(10)))),
              Center(child: Text(_tokenCharacterEmoji(player),
                style: TextStyle(fontSize: diameter * .66,
                  shadows: const [Shadow(color: Colors.black45, blurRadius: 2)]))),
            ]),
          )),
        ),
      ),
    );
  }
  String _tokenCharacterEmoji(int player) {
    if (player == 0) {
      if (_myCharacter.characterId.startsWith('robot')) return '🤖';
      if (_myCharacter.characterId.startsWith('tiger')) return '🐯';
      if (_myCharacter.characterId.startsWith('astronaut')) return '🧑‍🚀';
      return '🦊';
    }
    return const ['🦊','🐬','🐥','🐸'][player % 4];
  }

  Offset _tokenPoint(int player, int token, int progress, double size) {
    if (progress == 57) {
      const homeOffsets = [Offset(-.30, -.30), Offset(.30, -.30), Offset(-.30, .30), Offset(.30, .30)];
      final offset = homeOffsets[token];
      return Offset((7.5 + offset.dx) / 15 * size, (7.5 + offset.dy) / 15 * size);
    }
    if (progress >= 51) {
      final cell = LudoBoardGeometry.homeLanes[_baseIndex(player)][progress - 51];
      return LudoBoardGeometry.cellCenter(cell.$1, cell.$2, size);
    }
    if (progress >= 0) {
      final index = LudoRules.trackIndex(player, progress, playerCount: _playerCount)!;
      final cell = LudoBoardGeometry.trackCells[index];
      return LudoBoardGeometry.cellCenter(cell.$1, cell.$2, size);
    }
    const yardOffsets = [Offset(-.72, -.72), Offset(.72, -.72), Offset(-.72, .72), Offset(.72, .72)];
    final base = LudoBoardGeometry.baseCenters[_baseIndex(player)];
    final offset = yardOffsets[token];
    return Offset((base.$2 + .5 + offset.dx) / 15 * size, (base.$1 + .5 + offset.dy) / 15 * size);
  }

}

class _LudoDieFace extends StatelessWidget {
  final int? value;
  final double size;
  const _LudoDieFace({required this.value, required this.size});

  static const _patterns = <int, List<int>>{
    1: [4], 2: [0, 8], 3: [0, 4, 8],
    4: [0, 2, 6, 8], 5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  Widget build(BuildContext context) {
    final dots = _patterns[value] ?? const <int>[];
    return Container(
      width: size, height: size,
      padding: EdgeInsets.all(size * .13),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0E7),
        borderRadius: BorderRadius.circular(size * .20),
        border: Border.all(color: const Color(0xFFD7CDBB), width: .8),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        mainAxisSpacing: size * .035,
        crossAxisSpacing: size * .035,
        children: List.generate(9, (index) => Center(
          child: dots.contains(index)
              ? Container(
                  width: size * .16, height: size * .16,
                  decoration: const BoxDecoration(color: Color(0xFF172638), shape: BoxShape.circle),
                )
              : const SizedBox.shrink(),
        )),
      ),
    );
  }
}

class LudoBoardGeometry {
  // Standard 15x15 Ludo cross-track: the route runs around the four
  // 6x6 yards and the central 3x3 finish, not around the board's outer rim.
  // Index 0 = red/bottom start; 13 = green/left; 26 = yellow/top; 39 = blue/right.
  static const trackCells = <(int, int)>[
    (13,6),(12,6),(11,6),(10,6),(9,6),(8,5),(8,4),(8,3),(8,2),(8,1),(8,0),(7,0),(6,0),
    (6,1),(6,2),(6,3),(6,4),(6,5),(5,6),(4,6),(3,6),(2,6),(1,6),(0,6),(0,7),(0,8),
    (1,8),(2,8),(3,8),(4,8),(5,8),(6,9),(6,10),(6,11),(6,12),(6,13),(6,14),(7,14),(8,14),
    (8,13),(8,12),(8,11),(8,10),(8,9),(9,8),(10,8),(11,8),(12,8),(13,8),(14,8),(14,7),(14,6),
  ];
  // Six straight, square home-lane cells for each classic Ludo arm.
  // Player order: red (bottom), blue (right), yellow (top), green (left).
  static const homeLanes = <List<(int, int)>>[
    [(13,7),(12,7),(11,7),(10,7),(9,7),(8,7)],
    [(7,13),(7,12),(7,11),(7,10),(7,9),(7,8)],
    [(1,7),(2,7),(3,7),(4,7),(5,7),(6,7)],
    [(7,1),(7,2),(7,3),(7,4),(7,5),(7,6)],
  ];
  static const baseCenters = <(int, int)>[(12,3),(12,11),(2,11),(2,3)];
  /// Compact, deterministic offsets for tokens sharing one square.
  /// The cluster stays centered and every token remains inside the square.
  static List<Offset> compactStackOffsets(int count, double size) {
    if (count <= 1) return [Offset.zero];
    if (count == 2) {
      return [Offset(-.029 * size, 0), Offset(.029 * size, 0)];
    }
    if (count == 3) {
      return [
        Offset(-.030 * size, -.018 * size),
        Offset(.030 * size, -.018 * size),
        Offset(0, .036 * size),
      ];
    }
    if (count == 4) {
      return [
        Offset(-.030 * size, -.030 * size),
        Offset(.030 * size, -.030 * size),
        Offset(-.030 * size, .030 * size),
        Offset(.030 * size, .030 * size),
      ];
    }
    return List<Offset>.generate(count, (index) {
      final angle = -math.pi / 2 + (2 * math.pi * index / count);
      return Offset(math.cos(angle) * .045 * size, math.sin(angle) * .045 * size);
    });
  }

  static Offset cellCenter(int row, int column, double size) =>
      Offset((column + .5) / 15 * size, (row + .5) / 15 * size);
}

class _LudoBoardPainter extends CustomPainter {
  final List<Color> colors;
  final int players, turn;
  final List<List<int>> positions;
  final int? dice;
  final List<int> legalTokens;
  final FunBackdrop look;
  final int styleIndex;
  const _LudoBoardPainter({required this.colors, required this.players, required this.positions,
    required this.turn, required this.dice, required this.legalTokens, required this.look, required this.styleIndex});

  Color _playerColor(int player) => colors[players == 2 && player == 1 ? 2 : player];

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 15;
    final boardRect = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(boardRect.deflate(unit * .12), Radius.circular(unit * .72));
    canvas.drawRRect(outer.shift(Offset(0, unit * .13)), Paint()
      ..color = const Color(0x99000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13));
    final safeStyle = styleIndex.clamp(0, LudoCustomization.boardPalettes.length - 1).toInt();
    final boardColors = LudoCustomization.boardPalettes[safeStyle];
    final boardAccent = LudoCustomization.frameColors[safeStyle];
    canvas.drawRRect(outer, Paint()..shader = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color.lerp(boardColors[0], boardColors[1], .28)!, boardColors[1], boardColors[0]],
    ).createShader(boardRect));
    canvas.drawRRect(outer, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .09..color = boardAccent);
    canvas.drawRRect(outer.deflate(unit * .16), Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .025..color = boardAccent.withValues(alpha: .35));
    final inner = RRect.fromRectAndRadius(boardRect.deflate(unit * .38), Radius.circular(unit * .48));
    canvas.drawRRect(inner, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .018..color = const Color(0x66F7DFA9));

    if (look == FunBackdrop.stadium) {
      final pitchPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * .045
        ..color = Colors.white.withValues(alpha: .19);
      final pitch = Rect.fromLTRB(unit * 2.35, unit * 2.35, unit * 12.65, unit * 12.65);
      canvas.drawRRect(
        RRect.fromRectAndRadius(pitch, Radius.circular(unit * .18)),
        pitchPaint,
      );
      canvas.drawLine(
        Offset(unit * 7.5, pitch.top),
        Offset(unit * 7.5, pitch.bottom),
        pitchPaint,
      );
      canvas.drawCircle(Offset(unit * 7.5, unit * 7.5), unit * 1.35, pitchPaint);
      canvas.drawRect(
        Rect.fromLTRB(unit * 5.5, pitch.top, unit * 9.5, unit * 3.45),
        pitchPaint,
      );
      canvas.drawRect(
        Rect.fromLTRB(unit * 5.5, unit * 11.55, unit * 9.5, pitch.bottom),
        pitchPaint,
      );
      final stripe = Paint()..color = Colors.white.withValues(alpha: .025);
      for (var band = 0; band < 7; band++) {
        if (band.isEven) {
          canvas.drawRect(
            Rect.fromLTRB(unit * (2.4 + band * 1.45), unit * 2.4,
                unit * (3.85 + band * 1.45), unit * 12.6),
            stripe,
          );
        }
      }
    }

    final texture = Paint()..color = const Color(0x0DFFFFFF)..strokeWidth = .7;
    for (var i = 1; i < 15; i++) {
      canvas.drawLine(Offset(i * unit, unit * .4), Offset(i * unit, size.height - unit * .4), texture);
      canvas.drawLine(Offset(unit * .4, i * unit), Offset(size.width - unit * .4, i * unit), texture);
    }

    for (var baseSlot = 0; baseSlot < 4; baseSlot++) {
      // In a two-player match, the players occupy opposite red/yellow bases.
      // Keep the board bases, yard positions, and token coordinates in sync.
      final activePlayer = players == 2
          ? (baseSlot == 0 ? 0 : baseSlot == 2 ? 1 : -1)
          : baseSlot;
      final base = LudoBoardGeometry.baseCenters[baseSlot];
      final rect = Rect.fromLTWH((base.$2 - 2.9) * unit, (base.$1 - 2.9) * unit, unit * 5.8, unit * 5.8);
      final shape = RRect.fromRectAndRadius(rect, Radius.circular(unit * .55));
      final activeBase = activePlayer >= 0;
      final color = activeBase
          ? _playerColor(activePlayer)
          : Color.lerp(colors[baseSlot], const Color(0xFF102433), .62)!;
      canvas.drawRRect(shape.shift(Offset(0, unit * .10)), Paint()
        ..color = Colors.black.withValues(alpha: .30)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawRRect(shape, Paint()..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, .22)!, color.withValues(alpha: .90), Color.lerp(color, Colors.black, .30)!],
      ).createShader(rect));
      canvas.drawRRect(shape, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .075
        ..color = const Color(0xFFE9D39B).withValues(alpha: .9));
      const offsets = [(-.72,-.72),(.72,-.72),(-.72,.72),(.72,.72)];
      for (final offset in offsets) {
        final p = Offset((base.$2 + .5 + offset.$1) * unit, (base.$1 + .5 + offset.$2) * unit);
        canvas.drawCircle(p, unit * .37, Paint()..color = const Color(0xFF081722).withValues(alpha: .22));
        canvas.drawCircle(p, unit * .37, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .045
          ..color = Colors.white.withValues(alpha: .65));
      }
      final label = TextPainter(
        text: TextSpan(text: ['سرخ','آبی','زرد','سبز'][baseSlot],
          style: TextStyle(color: Colors.white.withValues(alpha: activeBase ? .94 : .42), fontSize: unit * .30, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.rtl,
      )..layout();
      label.paint(canvas, Offset(rect.center.dx - label.width / 2, baseSlot < 2 ? rect.bottom - unit * .52 : rect.top + unit * .18));
    }

    // Draw 52 separate square track cells; avoid the rounded continuous
    // ring that made the route look circular instead of like modern Ludo.

    for (var index = 0; index < 52; index++) {
      final cell = LudoBoardGeometry.trackCells[index];
      final center = LudoBoardGeometry.cellCenter(cell.$1, cell.$2, size.width);
      final rect = Rect.fromCenter(center: center, width: unit * .91, height: unit * .91);
      final owner = List.generate(players, (p) => LudoRules.offsetFor(p, players)).indexOf(index);
      final color = owner >= 0
          ? _playerColor(owner)
          : LudoRules.safeSquares.contains(index)
              ? boardAccent
              : Color.lerp(
                  boardColors[1],
                  const Color(0xFFF3EAD7),
                  safeStyle == 0 ? .68 : .30,
                )!;
      final tile = RRect.fromRectAndRadius(rect, Radius.circular(unit * .055));
      canvas.drawRRect(tile.shift(Offset(0, unit * .055)), Paint()..color = Colors.black.withValues(alpha: .32));
      canvas.drawRRect(tile, Paint()..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, .25)!, color, Color.lerp(color, Colors.black, .12)!],
      ).createShader(rect));
      canvas.drawRRect(tile, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .035..color = Colors.white.withValues(alpha: .9));
      if (LudoRules.safeSquares.contains(index)) {
        final star = TextPainter(
          text: TextSpan(text: owner >= 0 ? '✦' : '★',
            style: TextStyle(color: safeStyle == 0 ? const Color(0xFF57421D) : const Color(0xFF17202A), fontSize: unit * .40, fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr,
        )..layout();
        star.paint(canvas, center - Offset(star.width / 2, star.height / 2));
      }
    }

    for (var player = 0; player < 4; player++) {
      final activeLane = player < players || (players == 2 && player == 2);
      final color = activeLane ? colors[player] : colors[player].withValues(alpha: .22);
      for (final cell in LudoBoardGeometry.homeLanes[player]) {
        final center = LudoBoardGeometry.cellCenter(cell.$1, cell.$2, size.width);
        final rect = Rect.fromCenter(center: center, width: unit * .91, height: unit * .91);
        final tile = RRect.fromRectAndRadius(rect, Radius.circular(unit * .055));
        canvas.drawRRect(tile, Paint()..shader = LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, .35)!, color, Color.lerp(color, Colors.black, .18)!],
        ).createShader(rect));
        canvas.drawRRect(tile, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .04..color = Colors.white.withValues(alpha: .85));
      }
    }

    _drawLegalRoutes(canvas, size, unit);

    // Four classic colored finish triangles meet in the center.
    final centerPoint = Offset(unit * 7.5, unit * 7.5);
    final triangleSpecs = <(Color, Offset, Offset)>[
      // Finish wedges face the matching player's approach lane:
      // green-left, yellow-top, red-bottom, blue-right.
      (colors[3], Offset(unit * 6, unit * 6), Offset(unit * 6, unit * 9)),
      (colors[2], Offset(unit * 6, unit * 6), Offset(unit * 9, unit * 6)),
      (colors[0], Offset(unit * 6, unit * 9), Offset(unit * 9, unit * 9)),
      (colors[1], Offset(unit * 9, unit * 6), Offset(unit * 9, unit * 9)),
    ];
    for (final spec in triangleSpecs) {
      final trianglePath = Path()
        ..moveTo(centerPoint.dx, centerPoint.dy)
        ..lineTo(spec.$2.dx, spec.$2.dy)
        ..lineTo(spec.$3.dx, spec.$3.dy)
        ..close();
      canvas.drawPath(trianglePath, Paint()..color = spec.$1);
      canvas.drawPath(trianglePath, Paint()..style = PaintingStyle.stroke
        ..strokeWidth = unit * .045..color = Colors.white.withValues(alpha: .88));
    }

    final center = Offset(size.width / 2, size.height / 2);
    final vault = Rect.fromCenter(center: center, width: unit * 1.30, height: unit * 1.30);
    final vaultShape = RRect.fromRectAndRadius(vault, Radius.circular(unit * .55));
    canvas.drawRRect(vaultShape.shift(Offset(0, unit * .08)), Paint()..color = Colors.black.withValues(alpha: .35));
    canvas.drawRRect(vaultShape, Paint()..shader = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color.lerp(boardAccent, Colors.white, .55)!, boardAccent, Color.lerp(boardAccent, Colors.black, .42)!],
    ).createShader(vault));
    canvas.drawRRect(vaultShape, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .08..color = Colors.white.withValues(alpha: .9));
    final brand = TextPainter(
      text: TextSpan(text: 'GR', style: TextStyle(color: const Color(0xFF302311), fontSize: unit * .62, fontWeight: FontWeight.w900, letterSpacing: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    brand.paint(canvas, center - Offset(brand.width / 2, brand.height / 2));
  }

  void _drawLegalRoutes(Canvas canvas, Size size, double unit) {
    if (dice == null || legalTokens.isEmpty) return;
    final color = _playerColor(turn);
    for (final token in legalTokens) {
      final progress = positions[turn][token];
      final points = <Offset>[];
      if (progress == -1) {
        final base = LudoBoardGeometry.baseCenters[players == 2 && turn == 1 ? 2 : turn];
        const offsets = [(-.72,-.72),(.72,-.72),(-.72,.72),(.72,.72)];
        final offset = offsets[token];
        points.add(Offset((base.$2 + .5 + offset.$1) / 15 * size.width, (base.$1 + .5 + offset.$2) / 15 * size.width));
        final start = LudoRules.trackIndex(turn, 0, playerCount: players)!;
        final cell = LudoBoardGeometry.trackCells[start];
        points.add(LudoBoardGeometry.cellCenter(cell.$1, cell.$2, size.width));
      } else {
        points.add(_pointForProgress(turn, progress, size.width));
        for (var step = 1; step <= dice!; step++) {
          points.add(_pointForProgress(turn, progress + step, size.width));
        }
      }
      if (points.length < 2) continue;
      // Keep the board clean: do not draw a long colored route across the
      // board while the player is choosing. Mark only this token's landing
      // cell with a subtle pulsing-style halo.
      final destination = points.last;
      canvas.drawCircle(destination, unit * .34, Paint()
        ..color = color.withValues(alpha: .16));
      canvas.drawCircle(destination, unit * .29, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * .045
        ..color = Color.lerp(color, Colors.white, .45)!.withValues(alpha: .92));
      canvas.drawCircle(destination, unit * .075, Paint()
        ..color = Colors.white.withValues(alpha: .95));
    }
  }

  Offset _pointForProgress(int player, int progress, double size) {
    if (progress == 57) return Offset(size * .5, size * .5);
    if (progress >= 51) {
      final cell = LudoBoardGeometry.homeLanes[players == 2 && player == 1 ? 2 : player][progress - 51];
      return LudoBoardGeometry.cellCenter(cell.$1, cell.$2, size);
    }
    final index = LudoRules.trackIndex(player, progress, playerCount: players)!;
    final cell = LudoBoardGeometry.trackCells[index];
    return LudoBoardGeometry.cellCenter(cell.$1, cell.$2, size);
  }

  @override
  bool shouldRepaint(covariant _LudoBoardPainter oldDelegate) =>
      oldDelegate.players != players || oldDelegate.turn != turn || oldDelegate.dice != dice ||
      oldDelegate.positions != positions || oldDelegate.legalTokens != legalTokens || oldDelegate.colors != colors || oldDelegate.look != look || oldDelegate.styleIndex != styleIndex;
}