import 'dart:math';

/// Pure game rules. Keep this object on the trusted server; never serialize
/// [Player.secretRole] into a public room/event payload.
enum MafiaPhase {
  lobby, roleDistribution, night, dawn, day, voting, defense, finalVote,
  execution, finished,
}

enum MafiaTeam { town, mafia, neutral }

enum MafiaRole {
  mafia, citizen, doctor, detective, mafiaBoss, sniper, veteran, mayor,
  interrogator, madman, joker,
}

enum NightActionType { kill, protect, investigate, shoot, alert, interrogate, pass }

class MafiaPlayer {
  MafiaPlayer({
    required this.id,
    required this.displayName,
    this.secretRole,
    this.alive = true,
    this.connected = true,
    this.reconnectDeadline,
  });

  final String id;
  final String displayName;
  MafiaRole? secretRole;
  bool alive;
  bool connected;
  DateTime? reconnectDeadline;
}

class MafiaAction {
  const MafiaAction({
    required this.actorId,
    required this.type,
    this.targetId,
    this.submittedAt,
  });
  final String actorId;
  final NightActionType type;
  final String? targetId;
  final DateTime? submittedAt;
}

class MafiaConfig {
  const MafiaConfig({
    this.nightSeconds = 45,
    this.daySeconds = 180,
    this.voteSeconds = 45,
    this.defenseSeconds = 30,
    this.finalVoteSeconds = 30,
    this.discussionMode = 'free',
    this.allowSniper = true,
    this.allowVeteran = true,
    this.allowMayor = true,
    this.allowInterrogator = true,
    this.allowMadman = true,
    this.allowJoker = true,
    this.customRoles = const {},
  });
  final int nightSeconds, daySeconds, voteSeconds, defenseSeconds, finalVoteSeconds;
  final String discussionMode;
  final bool allowSniper, allowVeteran, allowMayor, allowInterrogator, allowMadman, allowJoker;
  final Map<MafiaRole, int> customRoles;
}

class MafiaGame {
  MafiaGame._(this.players, this.config, this.phase, this.phaseDeadline,
      this.round, this.actions, this.votes, this.events);

  final Map<String, MafiaPlayer> players;
  final MafiaConfig config;
  MafiaPhase phase;
  DateTime? phaseDeadline;
  int round;
  final Map<String, MafiaAction> actions;
  final Map<String, String> votes;
  final List<Map<String, Object?>> events;
  final Set<String> protectedTonight = {};
  final Set<String> alertedVeterans = {};
  final Set<String> usedSniperShots = {};
  final Set<String> investigated = {};
  final Set<String> interrogated = {};
  final Set<String> defenseCandidates = {};
  String? winner;

  List<MafiaPlayer> get alivePlayers => players.values.where((p) => p.alive).toList();
  int get mafiaAlive => alivePlayers.where((p) => teamOf(p.secretRole!) == MafiaTeam.mafia).length;
  int get townAlive => alivePlayers.where((p) => teamOf(p.secretRole!) == MafiaTeam.town).length;
}

class NightResolution {
  const NightResolution({required this.eliminatedIds, required this.privateResults});
  final List<String> eliminatedIds;
  /// Must be delivered only to the corresponding player, never broadcast.
  final Map<String, String> privateResults;
}

class MafiaEngine {
  MafiaEngine._();

  static MafiaTeam teamOf(MafiaRole role) => switch (role) {
    MafiaRole.mafia || MafiaRole.mafiaBoss => MafiaTeam.mafia,
    MafiaRole.madman || MafiaRole.joker => MafiaTeam.neutral,
    _ => MafiaTeam.town,
  };

  static MafiaGame create({
    required List<({String id, String displayName})> roster,
    MafiaConfig config = const MafiaConfig(),
    Random? random,
    DateTime? now,
  }) {
    if (roster.length < 6 || roster.length > 16) {
      throw ArgumentError('Mafia requires 6 to 16 unique players.');
    }
    if (roster.map((p) => p.id).toSet().length != roster.length ||
        roster.any((p) => p.id.trim().isEmpty)) {
      throw ArgumentError('Player IDs must be unique and non-empty.');
    }
    final roles = buildRoleSet(roster.length, config);
    if (roles.length != roster.length) throw StateError('Role set does not match roster.');
    (random ?? Random.secure()).shuffle(roles);
    final players = <String, MafiaPlayer>{};
    for (var i = 0; i < roster.length; i++) {
      final p = roster[i];
      players[p.id] = MafiaPlayer(id: p.id, displayName: p.displayName, secretRole: roles[i]);
    }
    final timestamp = now ?? DateTime.now().toUtc();
    final game = MafiaGame._(players, config, MafiaPhase.roleDistribution,
        timestamp, 0, {}, {}, []);
    _event(game, 'roles_distributed', timestamp, {'playerCount': roster.length});
    return game;
  }

  /// Balanced defaults. For 8 players this is exactly 2 mafia, doctor,
  /// detective and 4 citizens as requested.
  static List<MafiaRole> buildRoleSet(int count, MafiaConfig c) {
    if (count < 6 || count > 16) throw ArgumentError('Player count must be 6..16.');
    final roles = <MafiaRole>[];
    final mafia = count <= 7 ? 2 : count <= 11 ? 3 : count <= 14 ? 4 : 5;
    roles.addAll(List.filled(mafia, MafiaRole.mafia));
    roles.add(MafiaRole.doctor);
    roles.add(MafiaRole.detective);
    if (count >= 9 && c.allowSniper) roles.add(MafiaRole.sniper);
    if (count >= 11 && c.allowVeteran) roles.add(MafiaRole.veteran);
    if (count >= 12 && c.allowMayor) roles.add(MafiaRole.mayor);
    if (count >= 13 && c.allowInterrogator) roles.add(MafiaRole.interrogator);
    if (count >= 14 && c.allowMadman) roles.add(MafiaRole.madman);
    if (count >= 15 && c.allowJoker) roles.add(MafiaRole.joker);
    for (final entry in c.customRoles.entries) {
      if (entry.value < 0 || entry.value > count) throw ArgumentError('Invalid custom role count.');
      for (var i = 0; i < entry.value; i++) roles.add(entry.key);
    }
    while (roles.length < count) roles.add(MafiaRole.citizen);
    if (roles.length > count) throw ArgumentError('Configured roles exceed player count.');
    return roles;
  }

  static void beginNight(MafiaGame g, {required DateTime now}) {
    _require(g, {MafiaPhase.roleDistribution, MafiaPhase.execution, MafiaPhase.day});
    if (_checkWin(g)) return;
    g.phase = MafiaPhase.night;
    g.round++;
    g.phaseDeadline = now.toUtc().add(Duration(seconds: g.config.nightSeconds));
    g.actions.clear(); g.protectedTonight.clear(); g.alertedVeterans.clear();
    g.defenseCandidates.clear(); g.votes.clear();
    _event(g, 'night_started', now, {'round': g.round});
  }

  static void beginDay(MafiaGame g, {required DateTime now}) {
    _require(g, {MafiaPhase.dawn});
    g.phase = MafiaPhase.day;
    g.phaseDeadline = now.toUtc().add(Duration(seconds: g.config.daySeconds));
    _event(g, 'day_started', now, {'round': g.round});
  }

  static void openVoting(MafiaGame g, {required DateTime now}) {
    _require(g, {MafiaPhase.day});
    g.phase = MafiaPhase.voting;
    g.votes.clear();
    g.phaseDeadline = now.toUtc().add(Duration(seconds: g.config.voteSeconds));
    _event(g, 'voting_started', now, {});
  }

  static void submitNightAction(MafiaGame g, MafiaAction action, {required DateTime now}) {
    _require(g, {MafiaPhase.night});
    final actor = _aliveActor(g, action.actorId);
    final role = actor.secretRole!;
    if (g.actions.containsKey(actor.id)) throw StateError('Action already submitted.');
    if (!_canUse(role, action.type)) throw StateError('Role cannot perform this action.');
    if (action.type == NightActionType.pass) {
      if (action.targetId != null) throw ArgumentError('Pass cannot have a target.');
    } else {
      final targetId = action.targetId;
      if (targetId == null || !g.players.containsKey(targetId) || !g.players[targetId]!.alive) {
        throw ArgumentError('Target must be a living player.');
      }
      if (targetId == actor.id && action.type != NightActionType.alert) {
        throw ArgumentError('Self-target is not allowed.');
      }
      if (action.type == NightActionType.kill && teamOf(role) != MafiaTeam.mafia) {
        throw StateError('Only mafia can submit a mafia kill.');
      }
      if (action.type == NightActionType.kill && teamOf(g.players[targetId]!.secretRole!) == MafiaTeam.mafia) {
        throw ArgumentError('Mafia cannot target their own team.');
      }
    }
    if (action.type == NightActionType.shoot && g.usedSniperShots.contains(actor.id)) {
      throw StateError('Sniper shot already used.');
    }
    g.actions[actor.id] = action;
    _event(g, 'night_action_submitted', now, {'actorId': actor.id, 'action': action.type.name});
  }

  /// Missing actions are deterministically treated as pass. Resolution order:
  /// protections -> attacks (mafia, sniper) -> veteran retaliation -> investigations.
  static NightResolution resolveNight(MafiaGame g, {required DateTime now}) {
    _require(g, {MafiaPhase.night});
    final privateResults = <String, String>{};
    final attacks = <String, String>{}; // target -> attacker
    for (final p in g.alivePlayers) {
      final action = g.actions[p.id] ?? MafiaAction(actorId: p.id, type: NightActionType.pass);
      if (action.type == NightActionType.protect) g.protectedTonight.add(action.targetId!);
      if (action.type == NightActionType.alert) g.alertedVeterans.add(p.id);
      if (action.type == NightActionType.kill || action.type == NightActionType.shoot) {
        attacks[action.targetId!] = p.id;
        if (action.type == NightActionType.shoot) g.usedSniperShots.add(p.id);
      }
    }
    final eliminated = <String>{};
    for (final entry in attacks.entries) {
      final target = g.players[entry.key]!;
      if (g.protectedTonight.contains(target.id)) continue;
      eliminated.add(target.id);
      if (g.alertedVeterans.contains(target.id)) eliminated.add(entry.value);
    }
    for (final p in g.alivePlayers) {
      final action = g.actions[p.id];
      if (action == null) continue;
      if (action.type == NightActionType.investigate) {
        final target = g.players[action.targetId!]!;
        privateResults[p.id] = teamOf(target.secretRole!) == MafiaTeam.mafia ? 'مافیا' : 'غیرمافیا';
      } else if (action.type == NightActionType.interrogate) {
        final target = g.players[action.targetId!]!;
        privateResults[p.id] = teamOf(target.secretRole!).name;
      }
    }
    for (final id in eliminated) {
      final p = g.players[id];
      if (p != null && p.alive) p.alive = false;
    }
    g.phase = MafiaPhase.dawn;
    g.phaseDeadline = null;
    _event(g, 'night_resolved', now, {'eliminatedIds': eliminated.toList()..sort()});
    _checkWin(g);
    return NightResolution(
      eliminatedIds: List.unmodifiable(eliminated.toList()..sort()),
      privateResults: Map.unmodifiable(privateResults),
    );
  }

  static void submitVote(MafiaGame g, {required String voterId, required String targetId, required DateTime now}) {
    _require(g, {MafiaPhase.voting, MafiaPhase.finalVote});
    _aliveActor(g, voterId);
    if (!g.players.containsKey(targetId) || !g.players[targetId]!.alive || voterId == targetId) {
      throw ArgumentError('Invalid vote target.');
    }
    g.votes[voterId] = targetId;
    _event(g, 'vote_submitted', now, {'voterId': voterId});
  }

  static Set<String> closeVoting(MafiaGame g, {required DateTime now}) {
    _require(g, {MafiaPhase.voting});
    final counts = _voteCounts(g);
    if (counts.isEmpty) {
      g.defenseCandidates.clear();
    } else {
      final maxVotes = counts.values.reduce(max);
      g.defenseCandidates
        ..clear()
        ..addAll(counts.entries.where((e) => e.value == maxVotes).map((e) => e.key));
    }
    g.phase = MafiaPhase.defense;
    g.phaseDeadline = now.toUtc().add(Duration(seconds: g.config.defenseSeconds));
    g.votes.clear();
    _event(g, 'defense_started', now, {'candidateIds': g.defenseCandidates.toList()..sort()});
    return Set.unmodifiable(g.defenseCandidates);
  }

  static void openFinalVote(MafiaGame g, {required DateTime now}) {
    _require(g, {MafiaPhase.defense});
    g.phase = MafiaPhase.finalVote;
    g.votes.clear();
    g.phaseDeadline = now.toUtc().add(Duration(seconds: g.config.finalVoteSeconds));
    _event(g, 'final_vote_started', now, {});
  }

  /// A tie in final vote means no execution; a unique leader is executed.
  static String? resolveFinalVote(MafiaGame g, {required DateTime now}) {
    _require(g, {MafiaPhase.finalVote});
    final counts = _voteCounts(g);
    String? executed;
    if (counts.isNotEmpty) {
      final maxVotes = counts.values.reduce(max);
      final leaders = counts.entries.where((e) => e.value == maxVotes).toList();
      if (leaders.length == 1) executed = leaders.single.key;
    }
    g.phase = MafiaPhase.execution;
    g.phaseDeadline = null;
    if (executed != null) g.players[executed]!.alive = false;
    _event(g, 'execution_resolved', now, {'executedId': executed});
    _checkWin(g);
    return executed;
  }

  static void setConnection(MafiaGame g, String playerId, bool connected, {required DateTime now}) {
    final p = g.players[playerId];
    if (p == null || !p.alive) throw ArgumentError('Unknown or eliminated player.');
    p.connected = connected;
    p.reconnectDeadline = connected ? null : now.toUtc().add(const Duration(seconds: 60));
    _event(g, connected ? 'player_reconnected' : 'player_disconnected', now, {'playerId': playerId});
  }

  static void expireReconnects(MafiaGame g, {required DateTime now}) {
    for (final p in g.players.values) {
      if (p.alive && !p.connected && p.reconnectDeadline != null &&
          !now.toUtc().isBefore(p.reconnectDeadline!)) {
        p.alive = false;
        p.reconnectDeadline = null;
        _event(g, 'player_forfeit', now, {'playerId': p.id});
      }
    }
    _checkWin(g);
  }

  /// Public projection intentionally omits every secret role and all actions.
  static Map<String, Object?> publicSnapshot(MafiaGame g) => {
    'phase': g.phase.name,
    'round': g.round,
    'winner': g.winner,
    'players': g.players.values.map((p) => {
      'id': p.id, 'displayName': p.displayName, 'alive': p.alive, 'connected': p.connected,
    }).toList(),
  };

  /// Private role response: only the authenticated player's own role and allies.
  static Map<String, Object?> privateSnapshot(MafiaGame g, String authenticatedPlayerId) {
    final p = g.players[authenticatedPlayerId];
    if (p == null) throw ArgumentError('Player is not in this game.');
    final allies = teamOf(p.secretRole!) == MafiaTeam.mafia
        ? g.alivePlayers.where((x) => teamOf(x.secretRole!) == MafiaTeam.mafia).map((x) => x.id).toList()
        : const <String>[];
    return {'playerId': p.id, 'role': p.secretRole!.name, 'mafiaAllyIds': allies};
  }

  static bool _checkWin(MafiaGame g) {
    if (g.phase == MafiaPhase.finished) return true;
    if (g.mafiaAlive == 0) {
      g.winner = 'town';
    } else if (g.mafiaAlive >= g.townAlive) {
      g.winner = 'mafia';
    } else if (g.alivePlayers.every((p) => teamOf(p.secretRole!) == MafiaTeam.neutral)) {
      g.winner = 'neutral';
    }
    if (g.winner != null) {
      g.phase = MafiaPhase.finished;
      g.phaseDeadline = null;
      return true;
    }
    return false;
  }

  static bool _canUse(MafiaRole role, NightActionType type) => switch (type) {
    NightActionType.pass => true,
    NightActionType.kill => role == MafiaRole.mafia || role == MafiaRole.mafiaBoss,
    NightActionType.protect => role == MafiaRole.doctor,
    NightActionType.investigate => role == MafiaRole.detective,
    NightActionType.shoot => role == MafiaRole.sniper,
    NightActionType.alert => role == MafiaRole.veteran,
    NightActionType.interrogate => role == MafiaRole.interrogator,
  };

  static Map<String, int> _voteCounts(MafiaGame g) {
    final counts = <String, int>{};
    for (final entry in g.votes.entries) {
      final voter = g.players[entry.key];
      if (voter == null || !voter.alive) continue;
      final weight = voter.secretRole == MafiaRole.mayor ? 2 : 1;
      counts.update(entry.value, (v) => v + weight, ifAbsent: () => weight);
    }
    return counts;
  }

  static MafiaPlayer _aliveActor(MafiaGame g, String id) {
    final p = g.players[id];
    if (p == null || !p.alive) throw StateError('Actor is not alive in this game.');
    return p;
  }

  static void _require(MafiaGame g, Set<MafiaPhase> phases) {
    if (!phases.contains(g.phase)) throw StateError('Action is invalid during ${g.phase.name}.');
  }

  static void _event(MafiaGame g, String type, DateTime at, Map<String, Object?> data) {
    g.events.add(Map.unmodifiable({'type': type, 'at': at.toUtc().toIso8601String(), ...data}));
  }
}
