import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:arad_messenger/mafia/mafia_engine.dart';

void main() {
  final roster = List.generate(8, (i) => (id: 'p$i', displayName: 'Player $i'));

  group('Mafia engine role setup and secrecy', () {
    test('8-player default composition is exactly 2 mafia, doctor, detective, 4 citizens', () {
      final roles = MafiaEngine.buildRoleSet(8, const MafiaConfig());
      expect(roles.where((r) => r == MafiaRole.mafia), hasLength(2));
      expect(roles.where((r) => r == MafiaRole.doctor), hasLength(1));
      expect(roles.where((r) => r == MafiaRole.detective), hasLength(1));
      expect(roles.where((r) => r == MafiaRole.citizen), hasLength(4));
    });

    test('role distribution is server-side and public projection never leaks it', () {
      final g = MafiaEngine.create(roster: roster, random: Random(7), now: DateTime.utc(2026));
      final pub = MafiaEngine.publicSnapshot(g).toString();
      expect(pub, isNot(contains('secretRole')));
      for (final p in g.players.values) {
        final own = MafiaEngine.privateSnapshot(g, p.id);
        expect(own['role'], p.secretRole!.name);
        if (MafiaEngine.teamOf(p.secretRole!) != MafiaTeam.mafia) {
          expect(own['mafiaAllyIds'], isEmpty);
        }
      }
      expect(() => MafiaEngine.privateSnapshot(g, 'outsider'), throwsArgumentError);
    });

    test('roster bounds and duplicate IDs are rejected', () {
      expect(() => MafiaEngine.create(roster: roster.take(5).toList()), throwsArgumentError);
      final duplicate = [...roster, (id: 'p0', displayName: 'duplicate')];
      expect(() => MafiaEngine.create(roster: duplicate), throwsArgumentError);
    });
  });

  group('Mafia phase machine and night resolution', () {
    test('doctor protection resolves before mafia attack', () {
      final g = MafiaEngine.create(roster: roster, random: Random(1), now: DateTime.utc(2026));
      _assign(g, {'p0': MafiaRole.mafia, 'p1': MafiaRole.mafia, 'p2': MafiaRole.doctor,
        'p3': MafiaRole.detective, 'p4': MafiaRole.citizen, 'p5': MafiaRole.citizen,
        'p6': MafiaRole.citizen, 'p7': MafiaRole.citizen});
      MafiaEngine.beginNight(g, now: DateTime.utc(2026));
      MafiaEngine.submitNightAction(g, const MafiaAction(actorId: 'p0', type: NightActionType.kill, targetId: 'p4'), now: DateTime.utc(2026));
      MafiaEngine.submitNightAction(g, const MafiaAction(actorId: 'p2', type: NightActionType.protect, targetId: 'p4'), now: DateTime.utc(2026));
      final result = MafiaEngine.resolveNight(g, now: DateTime.utc(2026));
      expect(result.eliminatedIds, isEmpty);
      expect(g.players['p4']!.alive, isTrue);
    });

    test('mafia kill is a shared plurality ballot; a tie produces no attack', () {
      final g = MafiaEngine.create(roster: roster, random: Random(1), now: DateTime.utc(2026));
      _assign(g, {'p0': MafiaRole.mafia, 'p1': MafiaRole.mafia, 'p2': MafiaRole.doctor,
        'p3': MafiaRole.detective, 'p4': MafiaRole.citizen, 'p5': MafiaRole.citizen,
        'p6': MafiaRole.citizen, 'p7': MafiaRole.citizen});
      MafiaEngine.beginNight(g, now: DateTime.utc(2026));
      MafiaEngine.submitNightAction(g, const MafiaAction(actorId: 'p0', type: NightActionType.kill, targetId: 'p4'), now: DateTime.utc(2026));
      MafiaEngine.submitNightAction(g, const MafiaAction(actorId: 'p1', type: NightActionType.kill, targetId: 'p5'), now: DateTime.utc(2026));
      final result = MafiaEngine.resolveNight(g, now: DateTime.utc(2026));
      expect(result.eliminatedIds, isEmpty);
      expect(g.players['p4']!.alive, isTrue);
      expect(g.players['p5']!.alive, isTrue);
    });

    test('detective receives a private result only in private response', () {
      final g = MafiaEngine.create(roster: roster, random: Random(1), now: DateTime.utc(2026));
      _assign(g, {'p0': MafiaRole.mafia, 'p1': MafiaRole.mafia, 'p2': MafiaRole.doctor,
        'p3': MafiaRole.detective, 'p4': MafiaRole.citizen, 'p5': MafiaRole.citizen,
        'p6': MafiaRole.citizen, 'p7': MafiaRole.citizen});
      MafiaEngine.beginNight(g, now: DateTime.utc(2026));
      MafiaEngine.submitNightAction(g, const MafiaAction(actorId: 'p3', type: NightActionType.investigate, targetId: 'p0'), now: DateTime.utc(2026));
      final result = MafiaEngine.resolveNight(g, now: DateTime.utc(2026));
      expect(result.privateResults, {'p3': 'مافیا'});
      expect(MafiaEngine.publicSnapshot(g).toString(), isNot(contains('مافیا')));
    });

    test('missing night action becomes pass and phase transitions are enforced', () {
      final g = MafiaEngine.create(roster: roster, random: Random(1), now: DateTime.utc(2026));
      MafiaEngine.beginNight(g, now: DateTime.utc(2026));
      expect(() => MafiaEngine.openVoting(g, now: DateTime.utc(2026)), throwsStateError);
      final result = MafiaEngine.resolveNight(g, now: DateTime.utc(2026));
      expect(result.eliminatedIds, isEmpty);
      expect(g.phase, MafiaPhase.dawn);
    });

    test('invalid actor, target, role action and duplicate action are rejected', () {
      final g = MafiaEngine.create(roster: roster, random: Random(1), now: DateTime.utc(2026));
      _assign(g, {'p0': MafiaRole.mafia, 'p1': MafiaRole.mafia, 'p2': MafiaRole.doctor,
        'p3': MafiaRole.detective, 'p4': MafiaRole.citizen, 'p5': MafiaRole.citizen,
        'p6': MafiaRole.citizen, 'p7': MafiaRole.citizen});
      MafiaEngine.beginNight(g, now: DateTime.utc(2026));
      expect(() => MafiaEngine.submitNightAction(g, const MafiaAction(actorId: 'p4', type: NightActionType.kill, targetId: 'p0'), now: DateTime.utc(2026)), throwsStateError);
      expect(() => MafiaEngine.submitNightAction(g, const MafiaAction(actorId: 'p0', type: NightActionType.kill, targetId: 'p0'), now: DateTime.utc(2026)), throwsArgumentError);
      MafiaEngine.submitNightAction(g, const MafiaAction(actorId: 'p0', type: NightActionType.kill, targetId: 'p4'), now: DateTime.utc(2026));
      expect(() => MafiaEngine.submitNightAction(g, const MafiaAction(actorId: 'p0', type: NightActionType.kill, targetId: 'p5'), now: DateTime.utc(2026)), throwsStateError);
    });
  });

  group('Mafia votes, win conditions and reconnect', () {
    test('final vote tie results in no execution', () {
      final g = MafiaEngine.create(roster: roster, random: Random(1), now: DateTime.utc(2026));
      _assign(g, {'p0': MafiaRole.mafia, 'p1': MafiaRole.mafia, 'p2': MafiaRole.doctor,
        'p3': MafiaRole.detective, 'p4': MafiaRole.citizen, 'p5': MafiaRole.citizen,
        'p6': MafiaRole.citizen, 'p7': MafiaRole.citizen});
      MafiaEngine.beginNight(g, now: DateTime.utc(2026));
      MafiaEngine.resolveNight(g, now: DateTime.utc(2026));
      MafiaEngine.beginDay(g, now: DateTime.utc(2026));
      MafiaEngine.openVoting(g, now: DateTime.utc(2026));
      final firstBallot = {'p0': 'p4', 'p1': 'p4', 'p2': 'p4', 'p3': 'p5', 'p6': 'p5', 'p7': 'p5'};
      for (final e in firstBallot.entries) {
        MafiaEngine.submitVote(g, voterId: e.key, targetId: e.value, now: DateTime.utc(2026));
      }
      MafiaEngine.closeVoting(g, now: DateTime.utc(2026));
      MafiaEngine.openFinalVote(g, now: DateTime.utc(2026));
      MafiaEngine.submitVote(g, voterId: 'p0', targetId: 'p4', now: DateTime.utc(2026));
      MafiaEngine.submitVote(g, voterId: 'p1', targetId: 'p5', now: DateTime.utc(2026));
      expect(MafiaEngine.resolveFinalVote(g, now: DateTime.utc(2026)), isNull);
      expect(g.players['p4']!.alive, isTrue);
    });

    test('mafia wins at parity and town wins when mafia are eliminated', () {
      final g = MafiaEngine.create(roster: roster, random: Random(1), now: DateTime.utc(2026));
      _assign(g, {'p0': MafiaRole.mafia, 'p1': MafiaRole.mafia, 'p2': MafiaRole.citizen,
        'p3': MafiaRole.citizen, 'p4': MafiaRole.citizen, 'p5': MafiaRole.citizen,
        'p6': MafiaRole.citizen, 'p7': MafiaRole.citizen});
      for (var i = 2; i < 8; i++) g.players['p$i']!.alive = false;
      MafiaEngine.beginNight(g, now: DateTime.utc(2026));
      expect(g.phase, MafiaPhase.finished);
      expect(g.winner, 'mafia');
      final g2 = MafiaEngine.create(roster: roster, random: Random(1), now: DateTime.utc(2026));
      _assign(g2, {'p0': MafiaRole.mafia, 'p1': MafiaRole.mafia, 'p2': MafiaRole.doctor,
        'p3': MafiaRole.detective, 'p4': MafiaRole.citizen, 'p5': MafiaRole.citizen,
        'p6': MafiaRole.citizen, 'p7': MafiaRole.citizen});
      g2.players['p0']!.alive = false; g2.players['p1']!.alive = false;
      MafiaEngine.beginNight(g2, now: DateTime.utc(2026));
      expect(g2.phase, MafiaPhase.finished);
      expect(g2.winner, 'town');
    });

    test('disconnect reconnect window is 60 seconds; expiry eliminates player', () {
      final t = DateTime.utc(2026);
      final g = MafiaEngine.create(roster: roster, random: Random(1), now: t);
      MafiaEngine.setConnection(g, 'p4', false, now: t);
      MafiaEngine.expireReconnects(g, now: t.add(const Duration(seconds: 59)));
      expect(g.players['p4']!.alive, isTrue);
      MafiaEngine.setConnection(g, 'p4', true, now: t.add(const Duration(seconds: 59)));
      expect(g.players['p4']!.connected, isTrue);
      MafiaEngine.setConnection(g, 'p4', false, now: t);
      MafiaEngine.expireReconnects(g, now: t.add(const Duration(seconds: 60)));
      expect(g.players['p4']!.alive, isFalse);
    });
  });
}

void _assign(MafiaGame game, Map<String, MafiaRole> roles) {
  for (final e in roles.entries) {
    game.players[e.key]!.secretRole = e.value;
  }
}
