// SPDX-License-Identifier: GPL-3.0-only
import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { inspectGlb } from '../src/assets.mjs';
import { glbFixture } from './fixtures.mjs';

test('inspects animations, skins, local bounds, and content hash', async () => {
  const dir = await mkdtemp(path.join(os.tmpdir(), 'gamewright-assets-'));
  try {
    const filename = path.join(dir, 'hero.glb');
    await writeFile(filename, glbFixture({
      animations: [{ name: 'Idle' }, { name: 'Run' }],
      skins: [{ name: 'Hero', joints: [0, 1] }],
      meshes: [{ primitives: [{ attributes: { POSITION: 0 } }] }],
      accessors: [{ min: [-1, 0, -1], max: [1, 2, 1] }],
    }));
    const result = await inspectGlb(filename);
    assert.deepEqual(result.localBounds.dimensions, [2, 2, 2]);
    assert.equal(result.skins[0].jointCount, 2);
    assert.equal(result.suggestedMappings.run, 'Run');
    assert.equal(result.suggestedMappings.jump, null);
    assert.match(result.sha256, /^[0-9a-f]{64}$/);
    assert.equal((await inspectGlb(filename)).sha256, result.sha256);
  } finally { await rm(dir, { recursive: true, force: true }); }
});

test('rejects malformed GLBs and external asset dependencies', async () => {
  const dir = await mkdtemp(path.join(os.tmpdir(), 'gamewright-assets-'));
  try {
    const filename = path.join(dir, 'bad.glb');
    for (const data of [Buffer.from('invalid'), glbFixture({ buffers: [{ uri: '../missing.bin' }] }), glbFixture({ images: [{ uri: 'https://example.org/a.png' }] })]) {
      await writeFile(filename, data);
      await assert.rejects(inspectGlb(filename));
    }
    const wrongLength = glbFixture();
    wrongLength.writeUInt32LE(999, 8);
    await writeFile(filename, wrongLength);
    await assert.rejects(inspectGlb(filename), /length/);
  } finally { await rm(dir, { recursive: true, force: true }); }
});
