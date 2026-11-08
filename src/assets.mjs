// SPDX-License-Identifier: GPL-3.0-only
import { open } from 'node:fs/promises';
import { createHash } from 'node:crypto';

const MAX_JSON = 16 * 1024 * 1024;

export async function inspectGlb(filename) {
  const file = await open(filename, 'r');
  try {
    const size = (await file.stat()).size;
    async function read(length, position) {
      const bytes = Buffer.alloc(length);
      const result = await file.read(bytes, 0, length, position);
      if (result.bytesRead !== length) throw new Error('Truncated GLB file.');
      return bytes;
    }
    const header = await read(12, 0);
    if (header.readUInt32LE(0) !== 0x46546c67 || header.readUInt32LE(4) !== 2) throw new Error('Expected a glTF 2.0 GLB file.');
    if (header.readUInt32LE(8) !== size) throw new Error('GLB declared length does not match file size.');
    let offset = 12;
    let document;
    while (offset < size) {
      const chunk = await read(8, offset);
      const length = chunk.readUInt32LE(0);
      const type = chunk.readUInt32LE(4);
      if (length % 4 || offset + 8 + length > size) throw new Error('Invalid GLB chunk length.');
      if (offset === 12 && type !== 0x4e4f534a) throw new Error('GLB must start with a JSON chunk.');
      if (type === 0x4e4f534a) {
        if (document || length > MAX_JSON) throw new Error('GLB JSON chunk is duplicated or too large.');
        try { document = JSON.parse((await read(length, offset + 8)).toString('utf8')); }
        catch { throw new Error('Invalid GLB JSON.'); }
      }
      offset += 8 + length;
    }
    if (!document || document.asset?.version !== '2.0') throw new Error('Missing glTF 2.0 asset metadata.');
    for (const collection of ['buffers', 'images', 'meshes', 'skins', 'animations', 'accessors', 'nodes']) {
      if (document[collection] !== undefined && !Array.isArray(document[collection])) throw new Error(`Invalid glTF ${collection}.`);
    }
    for (const resource of [...(document.buffers ?? []), ...(document.images ?? [])]) {
      if (resource.uri !== undefined && (typeof resource.uri !== 'string' || !resource.uri.startsWith('data:'))) {
        throw new Error('External resources are unsupported. Export a self-contained GLB.');
      }
    }
    const animations = (document.animations ?? []).map((animation, index) => animation.name || `animation_${index}`);
    const mappings = {};
    const warnings = [];
    for (const action of ['idle', 'walk', 'run', 'jump']) {
      const matches = animations.filter(name => name.toLowerCase().includes(action));
      mappings[action] = matches.at(-1) ?? null;
      if (matches.length > 1) warnings.push(`Multiple ${action} clips; runtime uses the last matching imported clip.`);
    }
    if (!animations.length) warnings.push('No animation clips found; the model will remain static.');
    if (!(document.skins ?? []).length) warnings.push('No skin found; this may not be a rigged character.');
    const bounds = [];
    for (const mesh of document.meshes ?? []) {
      for (const primitive of mesh.primitives ?? []) {
        const accessor = document.accessors?.[primitive.attributes?.POSITION];
        if ([accessor?.min, accessor?.max].every(v => Array.isArray(v) && v.length === 3 && v.every(Number.isFinite))) {
          bounds.push({ min: accessor.min, max: accessor.max });
        }
      }
    }
    const localBounds = bounds.length ? {
      min: [0, 1, 2].map(i => Math.min(...bounds.map(b => b.min[i]))),
      max: [0, 1, 2].map(i => Math.max(...bounds.map(b => b.max[i]))),
    } : null;
    if (localBounds) localBounds.dimensions = localBounds.max.map((n, i) => n - localBounds.min[i]);
    warnings.push('Bounds use mesh accessor metadata, before node transforms, skinning, or animation; confirm scale in Godot.');
    const hash = createHash('sha256');
    for await (const bytes of file.createReadStream({ start: 0, autoClose: false })) hash.update(bytes);
    return {
      schemaVersion: 1, sha256: hash.digest('hex'), bytes: size,
      meshCount: (document.meshes ?? []).length,
      skins: (document.skins ?? []).map((skin, i) => ({ name: skin.name || `skin_${i}`, jointCount: skin.joints?.length ?? 0 })),
      animations, suggestedMappings: mappings, localBounds, warnings,
    };
  } finally { await file.close(); }
}
