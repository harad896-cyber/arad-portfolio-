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
  int _botGeneration = 0;
  int? _dice, _winner;
  final List<int?> _diceValues = List<int?>.filled(4, null);
  String _message = 'بازی را آغاز کن.';
  List<List<int>> _positions = [];

  bool get _botTurn => _againstBot && _turn == 1;
  int _colorIndex(int player) => _playerCount == 2 && player == 1 ? 2 : player;
  int _baseIndex(int player) => _playerCount == 2 && player == 1 ? 2 : player;
  Color _playerColor(int player) => _colors[_colorIndex(player)];
  String _playerName(int player) => _names[_colorIndex(player)];
  List<int> get _legal => _dice == null ? const [] : LudoRules.legalTokensInGame(_positions, _turn, _dice!);

  void _start({required int players, required bool bot}) {
    setState(() {
      _playerCount = players;
      _againstBot = bot;
      _positions = List.generate(players, (_) => List.filled(4, -1));
      _turn = 0; _dice = null; _winner = null; _sixStreak = 0;
      for (var i = 0; i < _diceValues.length; i++) { _diceValues[i] = null; }
      _botBusy = false; _botGeneration++; _started = true;
      _message = 'نوبت ${_playerName(_turn)} است؛ تاس بینداز.';
    });
  }

  void _roll({bool fromBot = false}) {
    if (!_started || _winner != null || _dice != null || (_botBusy && !fromBot)) return;
    final value = _random.nextInt(6) + 1;
    _diceValues[_turn] = value;
    if (value == 6) {
      _sixStreak++;
      if (_sixStreak >= 3) {
        setState(() {
          _dice = null; _sixStreak = 0; _turn = (_turn + 1) % _playerCount;
          _message = 'سه بار پشت سرهم ۶ آمد؛ نوبت ${_playerName(_turn)} شد.';
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
      final generation = _botGeneration;
      final player = _turn;
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (!mounted || generation != _botGeneration || _turn != player || _dice != value || _winner != null) return;
        setState(() {
          _dice = null; _turn = (_turn + 1) % _playerCount;
          _message = 'نوبت ${_playerName(_turn)} است؛ تاس بینداز.';
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
        _winner = _turn; _message = 'بازیکن ${_playerName(_turn)} برنده شد!';
      } else if (rolledSix || result.captured || result.finished) {
        _message = result.captured
            ? 'مهرهٔ حریف زده شد؛ نوبت اضافه داری!'
            : result.finished ? 'یک مهره به خانه رسید؛ دوباره تاس بینداز.'
            : '۶ آوردی؛ دوباره تاس بینداز.';
      } else {
        _sixStreak = 0; _turn = (_turn + 1) % _playerCount;
        _message = 'نوبت ${_playerName(_turn)} است؛ تاس بینداز.';
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
      for (var i = 0; i < _diceValues.length; i++) { _diceValues[i] = null; }
      _turn = 0; _sixStreak = 0; _botBusy = false; _botGeneration++; _message = 'بازی را آغاز کن.';
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
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 22),
    children: [
      _playerRow([3, 2]),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF142B3B), Color(0xFF203E4D)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD7B56D).withValues(alpha: .65)),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 5))],
        ),
        child: Text(_message, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, height: 1.4)),
      ),
      const SizedBox(height: 8),
      AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight);
          return Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _LudoBoardPainter(
              colors: _colors, players: _playerCount, positions: _positions,
              turn: _turn, dice: _dice, legalTokens: _legal,
            ))),
            for (var player = 0; player < _playerCount; player++)
              for (var token = 0; token < 4; token++) _buildToken(player, token, size),
          ]);
        }),
      ),
      const SizedBox(height: 8),
      _playerRow([0, 1]),
      const SizedBox(height: 10),
      if (_winner != null)
        FilledButton.icon(onPressed: _reset, icon: const Icon(Icons.replay_rounded), label: const Text('بازی دوباره')),
      if (_winner == null)
        Text(_dice == null ? 'تاس بازیکن فعال را بزن؛ مسیر حرکت با نور مشخص می‌شود.' :
          _legal.isEmpty ? 'حرکت ممکن نیست.' : 'یکی از مهره‌های نورانی را انتخاب کن.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
    ],
  );

  Widget _playerRow(List<int> baseSlots) {
    final playersByBase = <int, int>{
      for (var player = 0; player < _playerCount; player++) _baseIndex(player): player,
    };
    return Row(children: [
      for (final slot in baseSlots) ...[
        if (playersByBase[slot] case final player?)
          Expanded(child: _playerPanel(player))
        else
          const Expanded(child: SizedBox(height: 66)),
        if (slot != baseSlots.last) const SizedBox(width: 8),
      ],
    ]);
  }

  Widget _playerPanel(int player) {
    final color = _playerColor(player);
    final active = _turn == player && _winner == null;
    final canRoll = active && _dice == null && !_botTurn && !_botBusy;
    final count = _positions[player].where((value) => value == 57).length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: active ? .30 : .13), color.withValues(alpha: .055)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: active ? 1 : .35), width: active ? 2 : 1),
        boxShadow: active ? [BoxShadow(color: color.withValues(alpha: .22), blurRadius: 12)] : const [],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(_againstBot && player == 1 ? 'ربات' : _playerName(player),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13)),
          const SizedBox(height: 3),
          Text(count.toString() + ' / 4 خانه', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (active && _botTurn) const Text('در حال بازی…', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
          if (canRoll) const Text('نوبت تو · تاس بزن', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
        ])),
        const SizedBox(width: 6),
        Semantics(
          button: true,
          label: 'تاس ' + _playerName(player) + '، ' + (_diceValues[player]?.toString() ?? 'آماده'),
          child: GestureDetector(
            onTap: canRoll ? _roll : null,
            child: _LudoDieFace(value: _diceValues[player], color: color, active: active, enabled: canRoll),
          ),
        ),
      ]),
    );
  }

  Widget _buildToken(int player, int token, double size) {
    final point = _tokenPoint(player, token, _positions[player][token], size);
    final canMove = player == _turn && _dice != null && _legal.contains(token) && !_botTurn;
    final diameter = size * .055;
    final color = _playerColor(player);
    return Positioned(
      left: point.dx - diameter / 2, top: point.dy - diameter / 2,
      width: diameter, height: diameter,
      child: GestureDetector(
        onTap: canMove ? () => _moveToken(token) : null,
        child: AnimatedContainer(
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
            Center(child: Text((token + 1).toString(),
              style: TextStyle(color: _colorIndex(player) == 2 ? const Color(0xFF33250A) : Colors.white,
                fontSize: diameter * .34, fontWeight: FontWeight.w900, shadows: const [Shadow(color: Colors.black45, blurRadius: 2)]))),
          ]),
        ),
      ),
    );
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


class LudoBoardGeometry {
  static const trackCells = <(int, int)>[
    (14,1),(14,2),(14,3),(14,4),(14,5),(14,6),(14,7),(14,8),(14,9),(14,10),(14,11),(14,12),(14,13),
    (13,14),(12,14),(11,14),(10,14),(9,14),(8,14),(7,14),(6,14),(5,14),(4,14),(3,14),(2,14),(1,14),
    (0,13),(0,12),(0,11),(0,10),(0,9),(0,8),(0,7),(0,6),(0,5),(0,4),(0,3),(0,2),(0,1),
    (1,0),(2,0),(3,0),(4,0),(5,0),(6,0),(7,0),(8,0),(9,0),(10,0),(11,0),(12,0),(13,0),
  ];
  static const homeLanes = <List<(int, int)>>[
    [(11,1),(10,2),(9,3),(8,4),(8,5),(8,6)],
    [(13,13),(12,12),(11,11),(10,10),(9,9),(8,8)],
    [(1,13),(2,12),(3,11),(4,10),(5,9),(6,8)],
    [(1,1),(2,2),(3,3),(4,4),(5,5),(6,6)],
  ];
  static const baseCenters = <(int, int)>[(11,3),(11,11),(3,11),(3,3)];
  static Offset cellCenter(int row, int column, double size) =>
      Offset((column + .5) / 15 * size, (row + .5) / 15 * size);
}

class _LudoBoardPainter extends CustomPainter {
  final List<Color> colors;
  final int players, turn;
  final List<List<int>> positions;
  final int? dice;
  final List<int> legalTokens;
  const _LudoBoardPainter({required this.colors, required this.players, required this.positions,
    required this.turn, required this.dice, required this.legalTokens});

  Color _playerColor(int player) => colors[players == 2 && player == 1 ? 2 : player];

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 15;
    final boardRect = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(boardRect.deflate(unit * .12), Radius.circular(unit * .72));
    canvas.drawRRect(outer.shift(Offset(0, unit * .13)), Paint()
      ..color = const Color(0x99000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13));
    canvas.drawRRect(outer, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF36566A), Color(0xFF102433), Color(0xFF081722)],
    ).createShader(boardRect));
    canvas.drawRRect(outer, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .09..color = const Color(0xFFD6B36B));
    final inner = RRect.fromRectAndRadius(boardRect.deflate(unit * .38), Radius.circular(unit * .48));
    canvas.drawRRect(inner, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .018..color = const Color(0x66F7DFA9));

    final texture = Paint()..color = const Color(0x0DFFFFFF)..strokeWidth = .7;
    for (var i = 1; i < 15; i++) {
      canvas.drawLine(Offset(i * unit, unit * .4), Offset(i * unit, size.height - unit * .4), texture);
      canvas.drawLine(Offset(unit * .4, i * unit), Offset(size.width - unit * .4, i * unit), texture);
    }

    for (var player = 0; player < 4; player++) {
      final base = LudoBoardGeometry.baseCenters[player];
      final rect = Rect.fromLTWH((base.$2 - 2.45) * unit, (base.$1 - 2.45) * unit, unit * 4.9, unit * 4.9);
      final shape = RRect.fromRectAndRadius(rect, Radius.circular(unit * .55));
      final color = colors[player];
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
        text: TextSpan(text: ['قرمز','آبی','زرد','سبز'][player],
          style: TextStyle(color: Colors.white.withValues(alpha: .94), fontSize: unit * .30, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.rtl,
      )..layout();
      label.paint(canvas, Offset(rect.center.dx - label.width / 2, player < 2 ? rect.bottom - unit * .52 : rect.top + unit * .18));
    }

    final trackPath = Path();
    for (var i = 0; i < LudoBoardGeometry.trackCells.length; i++) {
      final cell = LudoBoardGeometry.trackCells[i];
      final point = LudoBoardGeometry.cellCenter(cell.$1, cell.$2, size.width);
      if (i == 0) { trackPath.moveTo(point.dx, point.dy); } else { trackPath.lineTo(point.dx, point.dy); }
    }
    trackPath.close();
    canvas.drawPath(trackPath, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .77
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..color = const Color(0xFF091B27));
    canvas.drawPath(trackPath, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .67
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..color = const Color(0xFFDBCEA9));

    for (var index = 0; index < 52; index++) {
      final cell = LudoBoardGeometry.trackCells[index];
      final center = LudoBoardGeometry.cellCenter(cell.$1, cell.$2, size.width);
      final rect = Rect.fromCenter(center: center, width: unit * .79, height: unit * .79);
      final owner = List.generate(players, (p) => LudoRules.offsetFor(p, players)).indexOf(index);
      final color = owner >= 0 ? _playerColor(owner) :
        LudoRules.safeSquares.contains(index) ? const Color(0xFFFFD477) : const Color(0xFFF3EAD7);
      final tile = RRect.fromRectAndRadius(rect, Radius.circular(unit * .17));
      canvas.drawRRect(tile.shift(Offset(0, unit * .055)), Paint()..color = Colors.black.withValues(alpha: .32));
      canvas.drawRRect(tile, Paint()..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, .25)!, color, Color.lerp(color, Colors.black, .12)!],
      ).createShader(rect));
      canvas.drawRRect(tile, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .035..color = Colors.white.withValues(alpha: .9));
      if (LudoRules.safeSquares.contains(index)) {
        final star = TextPainter(
          text: TextSpan(text: owner >= 0 ? '✦' : '★',
            style: TextStyle(color: const Color(0xFF57421D), fontSize: unit * .40, fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr,
        )..layout();
        star.paint(canvas, center - Offset(star.width / 2, star.height / 2));
      }
    }

    for (var player = 0; player < 4; player++) {
      final color = colors[player];
      for (final cell in LudoBoardGeometry.homeLanes[player]) {
        final center = LudoBoardGeometry.cellCenter(cell.$1, cell.$2, size.width);
        final rect = Rect.fromCenter(center: center, width: unit * .77, height: unit * .77);
        final tile = RRect.fromRectAndRadius(rect, Radius.circular(unit * .18));
        canvas.drawRRect(tile, Paint()..shader = LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, .35)!, color, Color.lerp(color, Colors.black, .18)!],
        ).createShader(rect));
        canvas.drawRRect(tile, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .04..color = Colors.white.withValues(alpha: .85));
      }
    }

    _drawLegalRoutes(canvas, size, unit);

    final center = Offset(size.width / 2, size.height / 2);
    final vault = Rect.fromCenter(center: center, width: unit * 1.30, height: unit * 1.30);
    final vaultShape = RRect.fromRectAndRadius(vault, Radius.circular(unit * .55));
    canvas.drawRRect(vaultShape.shift(Offset(0, unit * .08)), Paint()..color = Colors.black.withValues(alpha: .35));
    canvas.drawRRect(vaultShape, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFFFFE7A3), Color(0xFFC89A45), Color(0xFF8C642B)],
    ).createShader(vault));
    canvas.drawRRect(vaultShape, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .08..color = const Color(0xFFFFF2CC));
    final brand = TextPainter(
      text: const TextSpan(text: 'GR', style: TextStyle(color: Color(0xFF302311), fontSize: unit * .62, fontWeight: FontWeight.w900, letterSpacing: 1)),
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
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) { path.lineTo(point.dx, point.dy); }
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .24
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..color = color.withValues(alpha: .24));
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * .075
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round
        ..color = Color.lerp(color, Colors.white, .52)!.withValues(alpha: .98));
      for (var i = 1; i < points.length; i++) {
        canvas.drawCircle(points[i], unit * .105, Paint()..color = Colors.white);
        canvas.drawCircle(points[i], unit * .065, Paint()..color = color);
      }
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
      oldDelegate.positions != positions || oldDelegate.legalTokens != legalTokens || oldDelegate.colors != colors;
}

class _LudoDieFace extends StatelessWidget {
  final int? value;
  final Color color;
  final bool active, enabled;
  const _LudoDieFace({required this.value, required this.color, required this.active, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final spots = switch (value) {
      1 => const [(1,1)],
      2 => const [(0,0),(2,2)],
      3 => const [(0,0),(1,1),(2,2)],
      4 => const [(0,0),(0,2),(2,0),(2,2)],
      5 => const [(0,0),(0,2),(1,1),(2,0),(2,2)],
      6 => const [(0,0),(0,1),(0,2),(2,0),(2,1),(2,2)],
      _ => const <(int,int)>[],
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 43, height: 43,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF5EAD3), Color(0xFFD7C7A5)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? color : const Color(0xFFB7A77F), width: active ? 2.3 : 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .24), blurRadius: 6, offset: const Offset(0, 3)),
          if (active) BoxShadow(color: color.withValues(alpha: .35), blurRadius: 9),
        ],
      ),
      child: Opacity(opacity: enabled ? 1 : active ? .88 : .72, child: value == null
        ? Icon(Icons.casino_rounded, color: color, size: 25)
        : Stack(children: [
            for (final spot in spots)
              Positioned(
                left: 7 + spot.$2 * 12.5, top: 7 + spot.$1 * 12.5,
                child: Container(width: 7, height: 7,
                  decoration: const BoxDecoration(shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFF45515A), Color(0xFF101820)]))),
              ),
          ])),
    );
  }
}
