// SPDX-License-Identifier: GPL-3.0-only
import test from 'node:test';
import { glbFixture } from './fixtures.mjs';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, mkdir, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { createPlan, demoPlan, validatePlan } from '../src/plan.mjs';
import { generateProject } from '../src/godot.mjs';

test('rejects malformed or unsafe AI plans', () => {
  for (const change of [{ speed: '6' }, { collectibleCount: 1.5 }, { arenaSize: Infinity }, { background: 'red\ncode' }, { title: '' }]) {
    assert.throws(() => validatePlan({ ...demoPlan, ...change }));
  }
  assert.deepEqual(validatePlan({ ...demoPlan, script: 'ignored' }), demoPlan);
});

test('AI response is parsed, validated, and sent the user prompt', async () => {
  const plan = await createPlan('A moon garden', { fetchImpl: async (url, options) => {
    assert.equal(url.pathname, '/api/chat');
    assert.equal(JSON.parse(options.body).messages[1].content, 'A moon garden');
    return { ok: true, json: async () => ({ message: { content: JSON.stringify(demoPlan) } }) };
  } });
  assert.deepEqual(plan, demoPlan);
  await assert.rejects(createPlan('test', { fetchImpl: async () => ({ ok: false, status: 503 }) }), /503/);
  await assert.rejects(createPlan('test', { fetchImpl: async () => ({ ok: true, json: async () => ({ message: { content: 'broken' } }) }) }), /invalid JSON/);
});

test('exports a complete project and refuses to overwrite it', async () => {
  const temp = await mkdtemp(path.join(os.tmpdir(), 'gamewright-'));
  try {
    const out = path.join(temp, 'game');
    await generateProject(demoPlan, out);
    for (const name of ['project.godot', 'main.tscn', 'player.gd', 'game.gd', 'game-plan.json']) {
      assert.ok((await readFile(path.join(out, name), 'utf8')).length);
    }
    assert.match(await readFile(path.join(out, 'game.gd'), 'utf8'), /range\(12\)/);
    await assert.rejects(generateProject(demoPlan, out), /EEXIST/);
    assert.match(await readFile(path.join(out, 'project.godot'), 'utf8'), /Crystal Garden/);
  } finally { await rm(temp, { recursive: true, force: true }); }
});

test('copies supplied GLB and enables asset scene loading', async () => {
  const temp = await mkdtemp(path.join(os.tmpdir(), 'gamewright-'));
  try {
    const asset = path.join(temp, 'hero.glb');
    const bytes = glbFixture();
    await writeFile(asset, bytes);
    const out = path.join(temp, 'game');
    await generateProject(demoPlan, out, { character: asset });
    assert.deepEqual(await readFile(path.join(out, 'assets/character.glb')), bytes);
    const manifest = JSON.parse(await readFile(path.join(out, 'asset-manifest.json'), 'utf8'));
    assert.equal(manifest.schemaVersion, 1);
    assert.match(await readFile(path.join(out, 'LICENSE'), 'utf8'), /GNU GENERAL PUBLIC LICENSE/);
    assert.match(await readFile(path.join(out, 'game.gd'), 'utf8'), /character.glb/);
    await assert.rejects(generateProject(demoPlan, path.join(temp, 'bad'), { character: 'hero.fbx' }), /\.glb/);
  } finally { await rm(temp, { recursive: true, force: true }); }
});
