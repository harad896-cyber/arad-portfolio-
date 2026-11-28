import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';

test('embedded browser module parses as valid JavaScript', () => {
  const html = readFileSync(new URL('./index.html', import.meta.url), 'utf8');
  const openTag = '<script type="module">';
  const start = html.indexOf(openTag);
  const end = html.indexOf('</script>', start + openTag.length);
  assert.ok(start >= 0 && end > start, 'index.html must contain its module script');
  const moduleSource = html.slice(start + openTag.length, end);
  const checked = spawnSync(process.execPath, ['--check', '--input-type=module'], {
    input: moduleSource, encoding: 'utf8'
  });
  assert.equal(checked.status, 0, checked.stderr || checked.stdout);
});
