import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'fun_zone_theme.dart';

/// Ludo progress: -1 = yard, 0..50 = shared track, 51..56 = home lane, 57 = home.
class LudoRules {
  static const startOffsets = [0, 13, 26, 39];
  static const safeSquares = {0, 8, 13, 21, 26, 34, 39, 47};

  static List<int> legalTokens(List<int> pieces, int dice) => [
    for (var i = 0; i < pieces.length; i++)
      if ((pieces[i] == -1 && dice == 6) ||
          (pieces[i] >= 0 && pieces[i] < 57 && pieces[i] + dice <= 57)) i,
  ];

  static List<int> legalTokensInGame(List<List<int>> positions, int player, int dice) =>
      legalTokens(positions[player], dice)
          .where((token) => _pathIsClear(positions, player, token, dice))
          .toList();

  static bool _pathIsClear(List<List<int>> positions, int player, int token, int dice) {
    final current = positions[player][token];
    for (var step = 1; step <= dice; step++) {
      final progress = current == -1 ? 0 : current + step;
      final square = trackIndex(player, progress, playerCount: positions.length);
      if (square == null) continue;
      var occupants = 0;
      for (var p = 0; p < positions.length; p++) {
        for (final pieceProgress in positions[p]) {
          if (trackIndex(p, pieceProgress, playerCount: positions.length) == square) occupants++;
        }
      }
      // Two pieces on one track square form a blockade; nobody may pass it.
      if (occupants >= 2) return false;
    }
    return true;
  }

  static int offsetFor(int player, int playerCount) =>
      playerCount == 2 && player == 1 ? 26 : startOffsets[player];

  static int? trackIndex(int player, int progress, {int playerCount = 4}) {
    if (progress < 0 || progress > 50) return null;
    return (offsetFor(player, playerCount) + progress) % 52;
  }

  static LudoMoveResult move({
    required List<List<int>> positions,
    required int player,
    required int token,
    required int dice,
  }) {
    if (player < 0 || player >= positions.length || token < 0 || token >= 4 ||
        dice < 1 || dice > 6 ||
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
  const LudoGamePage({super.key});
  @override State<LudoGamePage> createState() => _LudoGamePageState();
}

class _LudoGamePageState extends State<LudoGamePage> {
  static const _colors = [
    Color(0xFFE34D55), Color(0xFF3478E5),
    Color(0xFFF0BD35), Color(0xFF269B70),
  ];
  static const _names = ['سرخ', 'آبی', 'زرد', 'سبز'];
  final _random = math.Random();
  int _playerCount = 2, _turn = 0, _sixStreak = 0;
  bool _againstBot = false, _started = false, _botBusy = false;
  int? _dice, _winner;
  String _message = 'بازی را آغاز کن.';
  List<List<int>> _positions = [];

  bool get _botTurn => _againstBot && _turn == 1;
  List<int> get _legal => _dice == null ? const [] : LudoRules.legalTokensInGame(_positions, _turn, _dice!);

  void _start({required int players, required bool bot}) {
    setState(() {
      _playerCount = players;
      _againstBot = bot;
      _positions = List.generate(players, (_) => List.filled(4, -1));
      _turn = 0; _dice = null; _winner = null; _sixStreak = 0;
      _botBusy = false; _started = true;
      _message = 'نوبت ${_names[_turn]} است؛ تاس بینداز.';
    });
  }

  void _roll({bool fromBot = false}) {
    if (!_started || _winner != null || _dice != null || (_botBusy && !fromBot)) return;
    final value = _random.nextInt(6) + 1;
    if (value == 6) {
      _sixStreak++;
      if (_sixStreak >= 3) {
        setState(() {
          _dice = null; _sixStreak = 0; _turn = (_turn + 1) % _playerCount;
          _message = 'سه بار پشت سرهم ۶ آمد؛ نوبت ${_names[_turn]} شد.';
        });
        _scheduleBot();
        return;
      }
    } else {
      _sixStreak = 0;
    }
    final options = LudoRules.legalTokensInGame(_positions, _turn, value);
    if (options.isEmpty && value == 6) {
      setState(() { _dice = null; _message = '۶ آمد؛ مهره‌ای برای حرکت نداری، دوباره تاس بینداز.'; });
      _scheduleBot();
      return;
    }
    setState(() {
      _dice = value;
      _message = options.isEmpty
          ? 'عدد $value آمد؛ حرکت قانونی نداری.'
          : 'عدد $value آمد؛ مهرهٔ موردنظر را انتخاب کن.';
    });
    if (options.isEmpty) {
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (!mounted || _dice != value || _winner != null) return;
        setState(() {
          _dice = null; _turn = (_turn + 1) % _playerCount;
          _message = 'نوبت ${_names[_turn]} است؛ تاس بینداز.';
        });
        _scheduleBot();
      });
    } else if (_botTurn && !fromBot) {
      _scheduleBot();
    }
  }

  void _moveToken(int token, {bool fromBot = false}) {
    if (_dice == null || _winner != null || (_botBusy && !fromBot) || !_legal.contains(token)) return;
    final result = LudoRules.move(
      positions: _positions, player: _turn, token: token, dice: _dice!,
    );
    final rolledSix = _dice == 6;
    setState(() {
      _positions = result.positions; _dice = null;
      if (result.won) {
        _winner = _turn; _message = 'بازیکن ${_names[_turn]} برنده شد!';
      } else if (rolledSix || result.captured || result.finished) {
        _message = result.captured
            ? 'مهرهٔ حریف زده شد؛ نوبت اضافه داری!'
            : result.finished ? 'یک مهره به خانه رسید؛ دوباره تاس بینداز.'
            : '۶ آوردی؛ دوباره تاس بینداز.';
      } else {
        _sixStreak = 0; _turn = (_turn + 1) % _playerCount;
        _message = 'نوبت ${_names[_turn]} است؛ تاس بینداز.';
      }
    });
    _scheduleBot();
  }

  void _scheduleBot() {
    if (!_botTurn || _winner != null || _botBusy || !mounted) return;
    _botBusy = true;
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (!mounted || !_botTurn || _winner != null) { _botBusy = false; return; }
      _botBusy = false;
      _roll(fromBot: true);
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
      _started = false; _positions = []; _dice = null; _winner = null;
      _turn = 0; _sixStreak = 0; _botBusy = false; _message = 'بازی را آغاز کن.';
    });
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      title: const Text('لودو'), backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      actions: [IconButton(onPressed: _reset, tooltip: 'بازی تازه', icon: const Icon(Icons.refresh_rounded))],
    ),
    floatingActionButton: const FunZoneThemeButton(),
    body: SafeArea(child: FunZoneBackdrop(child: !_started ? _modePicker() : _gameBody())),
  );

  Widget _modePicker() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const SizedBox(height: 12),
      const Icon(Icons.casino_rounded, size: 68, color: Color(0xFFF0BD35)),
      const SizedBox(height: 12),
      const Text('لودوی گپ‌رسان', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text('مهره‌ها را با تاس حرکت بده، مهره‌های حریف را بزن و زودتر از همه به خانه برس.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.6)),
      const SizedBox(height: 26),
      const Text('تعداد بازیکنان', style: TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, children: [2, 3, 4].map((count) => ChoiceChip(
        label: Text('$count نفر'), selected: _playerCount == count,
        onSelected: (_) => setState(() => _playerCount = count),
      )).toList()),
      const SizedBox(height: 18),
      SwitchListTile(
        contentPadding: EdgeInsets.zero, title: const Text('بازی با ربات'),
        subtitle: const Text('یک بازیکن انسانی در برابر ربات بازی می‌کند.'),
        value: _againstBot,
        onChanged: (value) => setState(() { _againstBot = value; if (value) _playerCount = 2; }),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: () => _start(players: _againstBot ? 2 : _playerCount, bot: _againstBot),
        icon: const Icon(Icons.play_arrow_rounded), label: const Text('شروع بازی')),
      const SizedBox(height: 10),
      const Text(
        'قوانین: برای بیرون‌آوردن مهره ۶ لازم است؛ خانه‌های امن از زدن محافظت می‌کنند؛ رسیدن به خانه با عدد دقیق انجام می‌شود؛ با آوردن ۶ یا زدن مهره، نوبت اضافه می‌گیری.',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.6, color: Colors.white70)),
    ],
  );

  Widget _gameBody() => ListView(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
    children: [
      Wrap(
        alignment: WrapAlignment.center, spacing: 8, runSpacing: 8,
        children: List.generate(_playerCount, (i) => _playerChip(i)),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          Text(_message, textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, height: 1.4)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 52, height: 52, alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))]),
              child: Text(_dice?.toString() ?? '–',
                style: const TextStyle(color: Color(0xFF17202A), fontSize: 28, fontWeight: FontWeight.w900))),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _dice == null && !_botTurn && _winner == null ? _roll : null,
              icon: const Icon(Icons.casino_rounded), label: const Text('تاس بینداز')),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight);
          return Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _LudoBoardPainter(colors: _colors, players: _playerCount))),
            for (var player = 0; player < _playerCount; player++)
              for (var token = 0; token < 4; token++) _buildToken(player, token, size),
          ]);
        }),
      ),
      const SizedBox(height: 10),
      if (_winner != null)
        FilledButton.icon(onPressed: _reset, icon: const Icon(Icons.replay_rounded), label: const Text('بازی دوباره')),
      if (_winner == null)
        Text(_dice == null ? 'برای ادامه تاس بینداز.' :
          _legal.isEmpty ? 'حرکت ممکن نیست.' : 'مهره‌های قابل حرکت را انتخاب کن.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
    ],
  );

  Widget _playerChip(int player) {
    final color = _colors[player], active = _turn == player && _winner == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? .22 : .10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: active ? color : color.withValues(alpha: .35), width: active ? 2 : 1)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle_rounded, color: color, size: 14),
        const SizedBox(width: 5),
        Text(_againstBot && player == 1 ? 'ربات' : _names[player],
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        const SizedBox(width: 6),
        Text('${_positions[player].where((p) => p == 57).length}/4',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _buildToken(int player, int token, double size) {
    final point = _tokenPoint(player, token, _positions[player][token], size);
    final canMove = player == _turn && _dice != null && _legal.contains(token) && !_botTurn;
    final diameter = size * .075;
    return Positioned(
      left: point.dx - diameter / 2, top: point.dy - diameter / 2,
      width: diameter, height: diameter,
      child: GestureDetector(
        onTap: canMove ? () => _moveToken(token) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: _colors[player], shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: canMove ? 1 : .85), width: canMove ? 3 : 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 4, offset: const Offset(0, 2)),
              if (canMove) BoxShadow(color: _colors[player].withValues(alpha: .7), blurRadius: 12),
            ]),
          child: Center(child: Text('${token + 1}',
            style: TextStyle(color: player == 2 ? Colors.black : Colors.white,
              fontSize: diameter * .40, fontWeight: FontWeight.w900))),
        ),
      ),
    );
  }

  Offset _tokenPoint(int player, int token, int progress, double size) {
    final center = Offset(size / 2, size / 2), radius = size * .345;
    if (progress == 57) return center + Offset((token - 1.5) * size * .018, (token.isEven ? -1 : 1) * size * .018);
    if (progress >= 51) {
      final angle = -math.pi / 2 + LudoRules.offsetFor(player, _playerCount) * 2 * math.pi / 52;
      final r = radius * (1 - (progress - 50) / 7);
      return center + Offset(math.cos(angle) * r, math.sin(angle) * r);
    }
    if (progress >= 0) {
      final index = (LudoRules.offsetFor(player, _playerCount) + progress) % 52;
      final angle = -math.pi / 2 + index * 2 * math.pi / 52;
      return center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    }
    const bases = [Offset(.235, .235), Offset(.765, .235), Offset(.765, .765), Offset(.235, .765)];
    const offsets = [Offset(-.055, -.055), Offset(.055, -.055), Offset(-.055, .055), Offset(.055, .055)];
    return Offset(bases[player].dx * size + offsets[token].dx * size,
      bases[player].dy * size + offsets[token].dy * size);
  }
}

class _LudoBoardPainter extends CustomPainter {
  final List<Color> colors;
  final int players;
  const _LudoBoardPainter({required this.colors, required this.players});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2), radius = size.width * .345;
    final cellRadius = size.width * .023;
    final outline = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = Colors.white.withValues(alpha: .85);
    canvas.drawCircle(center, size.width * .475, Paint()..color = const Color(0xFF16252D));
    canvas.drawCircle(center, size.width * .465, Paint()..color = const Color(0xFF263B45));
    const baseFractions = [Offset(.235, .235), Offset(.765, .235), Offset(.765, .765), Offset(.235, .765)];
    for (var player = 0; player < 4; player++) {
      final base = Offset(baseFractions[player].dx * size.width, baseFractions[player].dy * size.height);
      final rect = Rect.fromCenter(center: base, width: size.width * .29, height: size.height * .29);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(size.width * .045)),
        Paint()..color = colors[player].withValues(alpha: players > player ? .32 : .10));
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(size.width * .045)), outline);
      const offsets = [Offset(-.055, -.055), Offset(.055, -.055), Offset(-.055, .055), Offset(.055, .055)];
      for (final offset in offsets) {
        final p = base + Offset(offset.dx * size.width, offset.dy * size.height);
        canvas.drawCircle(p, size.width * .045, Paint()..color = colors[player].withValues(alpha: .22));
        canvas.drawCircle(p, size.width * .045, outline);
      }
    }
    for (var index = 0; index < 52; index++) {
      final angle = -math.pi / 2 + index * 2 * math.pi / 52;
      final p = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      final owner = List.generate(players, (p) => LudoRules.offsetFor(p, players)).indexOf(index);
      final fill = owner >= 0 ? colors[owner] :
        LudoRules.safeSquares.contains(index) ? const Color(0xFFFFD66B) : const Color(0xFFEAF0F0);
      canvas.drawCircle(p, cellRadius, Paint()..color = fill);
      canvas.drawCircle(p, cellRadius, outline);
      if (LudoRules.safeSquares.contains(index)) {
        final star = TextPainter(
          text: const TextSpan(text: '★', style: TextStyle(color: Color(0xFF263238), fontSize: 9, fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr)..layout();
        star.paint(canvas, p - Offset(star.width / 2, star.height / 2));
      }
    }
    for (var player = 0; player < 4; player++) {
      final angle = -math.pi / 2 + LudoRules.offsetFor(player, players) * 2 * math.pi / 52;
      for (var step = 1; step <= 6; step++) {
        final r = radius * (1 - step / 7);
        final p = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
        canvas.drawCircle(p, cellRadius, Paint()..color = colors[player].withValues(alpha: .9));
        canvas.drawCircle(p, cellRadius, outline);
      }
    }
    canvas.drawCircle(center, size.width * .075, Paint()..color = const Color(0xFFFFD66B));
    canvas.drawCircle(center, size.width * .075, outline);
    final home = TextPainter(
      text: const TextSpan(text: 'HOME', style: TextStyle(color: Color(0xFF263238), fontSize: 10, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr)..layout();
    home.paint(canvas, center - Offset(home.width / 2, home.height / 2));
  }

  @override
  bool shouldRepaint(covariant _LudoBoardPainter oldDelegate) =>
      oldDelegate.players != players || oldDelegate.colors != colors;
}
