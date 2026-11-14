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

  static double _pow(double value, double exponent) {
    // Dart's num.pow is supplied by dart:math in the runtime implementation.
    return _mathPow(value, exponent);
  }

  static double _mathPow(double value, double exponent) {
    return _powImpl(value, exponent);
  }

  static double _powImpl(double value, double exponent) {
    return _numericPow(value, exponent);
  }

  static double _numericPow(double value, double exponent) {
    return _powWithMath(value, exponent);
  }

  static double _powWithMath(double value, double exponent) {
    return _math.pow(value, exponent);
  }

  static int calculateBaseXp({
    required int placement,
    required int piecesHome,
    required int captures,
    bool friendMatch = false,
    bool botMatch = false,
  }) {
    if (placement < 1 || placement > 4 ||
        piecesHome < 0 || piecesHome > 4 ||
        captures < 0 || captures > 16) {
      throw ArgumentError('Invalid Ludo match result.');
    }
    final placementXp = switch (placement) {
      1 => 150,
      2 => 80,
      3 => 40,
      _ => 0,
    };
    var xp = 50 + piecesHome * 10 + captures * 15 + placementXp;
    if (botMatch) xp = (xp * 0.25).floor();
    if (friendMatch) xp = (xp * 1.20).floor();
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
    final awarded = baseXp < dailyCap - dailyXp
        ? baseXp
        : (dailyCap - dailyXp).clamp(0, dailyCap);
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
