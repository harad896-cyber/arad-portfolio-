import 'dart:convert';

/// Stable identity shared by every quick-game module.
class GamePlayer {
  final String id;
  final String displayName;

  const GamePlayer({required this.id, required this.displayName});

  Map<String, dynamic> toJson() => {'id': id, 'displayName': displayName};

  factory GamePlayer.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['displayName'];
    if (id is! String || id.trim().isEmpty || name is! String) {
      throw const FormatException('Invalid game player.');
    }
    return GamePlayer(id: id, displayName: name);
  }
}

enum GameStatus { active, won, draw }

class GameResult {
  final GameStatus status;
  final String? winnerId;

  const GameResult._(this.status, this.winnerId);

  const GameResult.active() : this._(GameStatus.active, null);
  const GameResult.draw() : this._(GameStatus.draw, null);
  const GameResult.won(String winnerId) : this._(GameStatus.won, winnerId);

  bool get isFinished => status != GameStatus.active;
}

/// Pure game contract. Implementations must not perform I/O or mutate [state].
abstract interface class GameModule<S, M> {
  String get id;
  int get schemaVersion;

  S init(List<GamePlayer> players);

  List<M> getLegalMoves(S state, String playerId);

  S applyMove(S state, String playerId, M move);

  GameResult getResult(S state);

  Map<String, dynamic> toJson(S state);

  S fromJson(Map<String, dynamic> json);

  /// Compact transport representation for chat/realtime persistence.
  String serialize(S state) {
    final encoded = jsonEncode(toJson(state));
    if (utf8.encode(encoded).length >= 2048) {
      throw StateError('Game state must be smaller than 2 KB.');
    }
    return encoded;
  }

  S deserialize(String encoded) {
    if (utf8.encode(encoded).length >= 2048) {
      throw const FormatException('Game state exceeds 2 KB.');
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Game state must be a JSON object.');
    }
    return fromJson(decoded);
  }
}

/// Registry keeps game selection independent from chat UI and routing.
class GameRegistry {
  GameRegistry._();

  static final GameRegistry instance = GameRegistry._();
  final Map<String, Object> _modules = {};

  void register<S, M>(GameModule<S, M> module) {
    final key = module.id.trim();
    if (key.isEmpty) throw ArgumentError.value(module.id, 'id');
    if (_modules.containsKey(key)) {
      throw StateError('Game "$key" is already registered.');
    }
    _modules[key] = module;
  }

  GameModule<S, M> get<S, M>(String id) {
    final module = _modules[id];
    if (module == null) throw StateError('Game "$id" is not registered.');
    if (module is! GameModule<S, M>) {
      throw StateError('Game "$id" was requested with incompatible types.');
    }
    return module;
  }

  bool contains(String id) => _modules.containsKey(id);

  List<String> get registeredIds =>
      List<String>.unmodifiable(_modules.keys.toList()..sort());

  void unregisterForTesting(String id) => _modules.remove(id);
}
