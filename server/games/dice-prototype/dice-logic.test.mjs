import test from 'node:test';
import assert from 'node:assert/strict';
import { FACE_NORMALS, faceUpQuaternion, rotateVectorByQuaternion, isValidDiceResult } from './dice-logic.mjs';

test('each of the six results rotates its own face exactly upward', () => {
  for (let n = 1; n <= 6; n++) {
    const up = rotateVectorByQuaternion(FACE_NORMALS[n], faceUpQuaternion(n));
    assert.ok(Math.abs(up[0]) < 1e-10, `face ${n} x alignment`);
    assert.ok(Math.abs(up[1] - 1) < 1e-10, `face ${n} y alignment`);
    assert.ok(Math.abs(up[2]) < 1e-10, `face ${n} z alignment`);
  }
});

test('result validation accepts only integer values 1..6', () => {
  for (let n = 1; n <= 6; n++) assert.equal(isValidDiceResult(n), true);
  for (const n of [0, 7, -1, 1.5, '6', NaN, Infinity]) assert.equal(isValidDiceResult(n), false);
});

test('invalid face values are rejected', () => {
  assert.throws(() => faceUpQuaternion(0), RangeError);
  assert.throws(() => faceUpQuaternion(7), RangeError);
});

test('ten thousand requested outcomes always map to the requested top face', () => {
  for (let i = 0; i < 10_000; i++) {
    const n = (i % 6) + 1;
    const top = rotateVectorByQuaternion(FACE_NORMALS[n], faceUpQuaternion(n));
    assert.ok(top[1] > 0.999999999);
  }
});
