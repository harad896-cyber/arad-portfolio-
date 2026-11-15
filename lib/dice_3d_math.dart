import 'dart:math' as math;

/// Small immutable vector used by the dice renderer.
class DiceVector3 {
  const DiceVector3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  DiceVector3 operator +(DiceVector3 other) =>
      DiceVector3(x + other.x, y + other.y, z + other.z);

  DiceVector3 operator -(DiceVector3 other) =>
      DiceVector3(x - other.x, y - other.y, z - other.z);

  DiceVector3 operator *(double scale) =>
      DiceVector3(x * scale, y * scale, z * scale);

  double dot(DiceVector3 other) =>
      x * other.x + y * other.y + z * other.z;

  DiceVector3 cross(DiceVector3 other) => DiceVector3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  double get length => math.sqrt(dot(this));

  DiceVector3 normalized() {
    final magnitude = length;
    if (magnitude < 1e-10) return const DiceVector3(0, 0, 0);
    return this * (1 / magnitude);
  }
}

/// Quaternion rotation. The dice uses this instead of rotating a flat image.
class DiceQuaternion {
  const DiceQuaternion(this.w, this.x, this.y, this.z);

  final double w;
  final double x;
  final double y;
  final double z;

  static const identity = DiceQuaternion(1, 0, 0, 0);

  factory DiceQuaternion.axisAngle(DiceVector3 axis, double angle) {
    final unit = axis.normalized();
    final half = angle / 2;
    final sine = math.sin(half);
    return DiceQuaternion(
      math.cos(half),
      unit.x * sine,
      unit.y * sine,
      unit.z * sine,
    ).normalized();
  }

  factory DiceQuaternion.fromTo(DiceVector3 from, DiceVector3 to) {
    final a = from.normalized();
    final b = to.normalized();
    final dot = a.dot(b).clamp(-1.0, 1.0);
    if (dot > 1 - 1e-9) return identity;
    if (dot < -1 + 1e-9) {
      var axis = a.cross(const DiceVector3(1, 0, 0));
      if (axis.length < 1e-8) {
        axis = a.cross(const DiceVector3(0, 1, 0));
      }
      return DiceQuaternion.axisAngle(axis, math.pi);
    }
    final cross = a.cross(b);
    return DiceQuaternion(1 + dot, cross.x, cross.y, cross.z).normalized();
  }

  DiceQuaternion operator *(DiceQuaternion other) => DiceQuaternion(
        w * other.w - x * other.x - y * other.y - z * other.z,
        w * other.x + x * other.w + y * other.z - z * other.y,
        w * other.y - x * other.z + y * other.w + z * other.x,
        w * other.z + x * other.y - y * other.x + z * other.w,
      );

  DiceQuaternion normalized() {
    final magnitude = math.sqrt(w * w + x * x + y * y + z * z);
    if (magnitude < 1e-10) return identity;
    return DiceQuaternion(
      w / magnitude,
      x / magnitude,
      y / magnitude,
      z / magnitude,
    );
  }

  DiceVector3 rotate(DiceVector3 vector) {
    final q = normalized();
    final qv = DiceQuaternion(0, vector.x, vector.y, vector.z);
    final inverse = DiceQuaternion(q.w, -q.x, -q.y, -q.z);
    final result = q * qv * inverse;
    return DiceVector3(result.x, result.y, result.z);
  }
}

/// Standard opposite-face pairs: 1/6, 2/5 and 3/4.
class Dice3DOrientation {
  Dice3DOrientation._();

  static const topNormal = DiceVector3(0, 0, 1);

  static DiceVector3 normalForFace(int face) {
    switch (face) {
      case 1:
        return const DiceVector3(0, 0, 1);
      case 2:
        return const DiceVector3(1, 0, 0);
      case 3:
        return const DiceVector3(0, 1, 0);
      case 4:
        return const DiceVector3(0, -1, 0);
      case 5:
        return const DiceVector3(-1, 0, 0);
      case 6:
        return const DiceVector3(0, 0, -1);
      default:
        throw RangeError.range(face, 1, 6, 'face');
    }
  }

  /// Returns a stable final orientation with [face] facing upward.
  static DiceQuaternion forTopFace(int face) => DiceQuaternion.fromTo(
        normalForFace(face),
        topNormal,
      );
}
