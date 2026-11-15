import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';

test('embedded browser module parses as valid JavaScript', () => {
  const html = readFileSync(new URL('./index.html', import.meta.url), 'utf8');
  const match = html.match(/<script type="module">([\\s\\S]*?)<\\/script>/);
  assert.ok(match, 'index.html must contain its module script');
  const checked = spawnSync(process.execPath, ['--check', '--input-type=module'], {
    input: match[1], encoding: 'utf8'
  });
  assert.equal(checked.status, 0, checked.stderr || checked.stdout);
});
