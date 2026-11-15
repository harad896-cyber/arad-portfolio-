import 'dart:math' as _math;

/// Pure Ludo progression rules shared by server integration and unit tests.
/// The database RPC remains the only writer of XP in production.
class LudoXpResult {
  const LudoXpResult({
    required this.baseXp,
    required this.awardedXp,
    required this.newLevel,
    required this.xpIntoLevel,
    required this.totalXp,
    required this.unlockedLevels,
  });

  final int baseXp;
  final int awardedXp;
  final int newLevel;
  final int xpIntoLevel;
  final int totalXp;
  final List<int> unlockedLevels;
}

class LudoXpService {
  const LudoXpService._();

  static const int maxLevel = 100;
  static const int dailyCap = 500;

  static int xpRequiredForLevel(int level) {
    if (level < 1 || level >= maxLevel) {
      if (level == maxLevel) return 0;
      throw RangeError.range(level, 1, maxLevel, 'level');
    }
    return (100 * _pow(level.toDouble(), 1.4)).ceil();
  }

  static double _pow(double value, double exponent) =>
      _math.pow(value, exponent).toDouble();

  static int calculateBaseXp({
    required int placement,
    required int piecesHome,
    required int captures,
    bool friendMatch = false,
    bool botMatch = false,
    bool completed = true,
    bool abandoned = false,
  }) {
    if (placement < 1 || placement > 4 ||
        piecesHome < 0 || piecesHome > 4 ||
        captures < 0 || captures > 16) {
      throw ArgumentError('Invalid Ludo match result.');
    }
    if (!completed || abandoned) return 0;
    final placementXp = switch (placement) {
      1 => 150,
      2 => 80,
      3 => 40,
      _ => 0,
    };
    var xp = 50 + piecesHome * 10 + captures * 15 + placementXp;
    // Bot games award reduced XP; the friend bonus is reserved for human matches.
    if (botMatch) {
      xp = (xp * 0.25).floor();
    } else if (friendMatch) {
      xp = (xp * 1.20).floor();
    }
    return xp;
  }

  static LudoXpResult calculateProgress({
    required int currentLevel,
    required int xpIntoLevel,
    required int totalXp,
    required int dailyXp,
    required int baseXp,
  }) {
    if (currentLevel < 1 || currentLevel > maxLevel ||
        xpIntoLevel < 0 || totalXp < 0 || dailyXp < 0 || baseXp < 0) {
      throw ArgumentError('Invalid progression state.');
    }
    final remainingDailyXp = (dailyCap - dailyXp).clamp(0, dailyCap);
    final awarded = baseXp.clamp(0, remainingDailyXp);
    var level = currentLevel;
    var xp = xpIntoLevel + awarded;
    final unlocked = <int>[];
    while (level < maxLevel) {
      final required = xpRequiredForLevel(level);
      if (xp < required) break;
      xp -= required;
      level++;
      unlocked.add(level);
    }
    if (level == maxLevel) xp = 0;
    return LudoXpResult(
      baseXp: baseXp,
      awardedXp: awarded,
      newLevel: level,
      xpIntoLevel: xp,
      totalXp: totalXp + awarded,
      unlockedLevels: List.unmodifiable(unlocked),
    );
  }
}
