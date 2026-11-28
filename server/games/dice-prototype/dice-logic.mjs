export const FACE_NORMALS = Object.freeze({
  1: [0, 1, 0],
  2: [0, -1, 0],
  3: [1, 0, 0],
  4: [-1, 0, 0],
  5: [0, 0, 1],
  6: [0, 0, -1],
});

const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a, b) => [
  a[1] * b[2] - a[2] * b[1],
  a[2] * b[0] - a[0] * b[2],
  a[0] * b[1] - a[1] * b[0],
];

/** Quaternion rotating a local face normal onto world-up (0,1,0). */
export function faceUpQuaternion(number) {
  const from = FACE_NORMALS[number];
  if (!from) throw new RangeError('Dice result must be an integer from 1 to 6.');
  const to = [0, 1, 0];
  const d = dot(from, to);
  if (d < -0.999999) return { x: 1, y: 0, z: 0, w: 0 };
  const c = cross(from, to);
  const q = { x: c[0], y: c[1], z: c[2], w: 1 + d };
  const length = Math.hypot(q.x, q.y, q.z, q.w);
  return { x: q.x / length, y: q.y / length, z: q.z / length, w: q.w / length };
}

export function rotateVectorByQuaternion(v, q) {
  const u = [q.x, q.y, q.z];
  const uv = cross(u, v);
  const uuv = cross(u, uv);
  return [
    v[0] + 2 * (q.w * uv[0] + uuv[0]),
    v[1] + 2 * (q.w * uv[1] + uuv[1]),
    v[2] + 2 * (q.w * uv[2] + uuv[2]),
  ];
}

export function isValidDiceResult(value) {
  return Number.isInteger(value) && value >= 1 && value <= 6;
}
