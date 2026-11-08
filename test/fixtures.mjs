// SPDX-License-Identifier: GPL-3.0-only
export function glbFixture(overrides = {}) {
  const json = JSON.stringify({ asset: { version: '2.0' }, ...overrides });
  const padded = Buffer.from(json + ' '.repeat((4 - Buffer.byteLength(json) % 4) % 4));
  const header = Buffer.alloc(20);
  header.writeUInt32LE(0x46546c67, 0);
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(20 + padded.length, 8);
  header.writeUInt32LE(padded.length, 12);
  header.writeUInt32LE(0x4e4f534a, 16);
  return Buffer.concat([header, padded]);
}
