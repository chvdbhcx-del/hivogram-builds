#!/usr/bin/env node
// Signs a file in minisign's format ("ED": Ed25519 over the file's BLAKE2b-512, as `minisign -S` does), with Node's
// own crypto and no packages. The in-app updaters (alltginone: src-tauri/src/update.rs, lite/core/src/update.rs) check
// SHA256SUMS.txt with this signature and the public key built into them before trusting any checksum.
//
//   UPDATE_SIGNING_KEY=<secret key file> node minisign.mjs <file> <trusted comment>  ->  <file>.minisig
//
// The key is an unencrypted minisign secret key (`rsign generate --unencrypted -W`): the whole file or only its
// base64 line. `minisign -V -P <public key> -m <file>` (or `rsign verify`) checks the result.
import { createHash, createPrivateKey, createPublicKey, sign, verify } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';

// The public key of the updaters (minisign format, key id D1A95BB642FD7144)
const PUBLIC_KEY = 'RWREcf1Ctlup0X1o4PMGGXIGBJL4XwWVfMDdkasA9j787S+nJefsATMJ';

const [file, trusted] = process.argv.slice(2);
if (!file || !trusted || /[\r\n]/.test(trusted)) {
  console.error('usage: node minisign.mjs <file> <one-line trusted comment>');
  process.exit(2);
}
const fail = (msg) => {
  console.error(`::error::${msg}`);
  process.exit(1);
};

const text = (process.env.UPDATE_SIGNING_KEY || '').trim();
const line = text.split(/\r?\n/).map((l) => l.trim()).find((l) => l && !l.startsWith('untrusted comment:'));
if (!line) fail('UPDATE_SIGNING_KEY is empty');
const raw = Buffer.from(line, 'base64');
// sig_alg(2) kdf_alg(2) cksum_alg(2) salt(32) opslimit(8) memlimit(8) | key id(8) secret key(64) checksum(32)
if (raw.length !== 158 || raw.toString('latin1', 0, 2) !== 'Ed') fail('UPDATE_SIGNING_KEY is not a minisign secret key');
if (raw[2] !== 0 || raw[3] !== 0) fail('UPDATE_SIGNING_KEY is encrypted: an unencrypted key is expected');
const keyId = raw.subarray(54, 62);
const seed = raw.subarray(62, 94);
const pub = raw.subarray(94, 126);

const pk = Buffer.from(PUBLIC_KEY, 'base64'); // "Ed" | key id(8) | public key(32)
if (!keyId.equals(pk.subarray(2, 10)) || !pub.equals(pk.subarray(10, 42))) {
  fail('UPDATE_SIGNING_KEY does not match the public key built into the apps');
}

const der = (prefix, key) => Buffer.concat([Buffer.from(prefix, 'hex'), key]);
const privateKey = createPrivateKey({ key: der('302e020100300506032b657004220420', seed), format: 'der', type: 'pkcs8' });
const publicKey = createPublicKey({ key: der('302a300506032b6570032100', pub), format: 'der', type: 'spki' });
if (!createPublicKey(privateKey).export({ format: 'der', type: 'spki' }).subarray(12).equals(pub)) {
  fail('UPDATE_SIGNING_KEY is damaged');
}

const data = createHash('blake2b512').update(readFileSync(file)).digest();
const sig = sign(null, data, privateKey);
const comment = Buffer.from(trusted, 'utf8');
const globalSig = sign(null, Buffer.concat([sig, comment]), privateKey);
if (!verify(null, data, publicKey, sig) || !verify(null, Buffer.concat([sig, comment]), publicKey, globalSig)) {
  fail('the signature does not verify');
}

const out = [
  `untrusted comment: signature from Hivogram update key ${Buffer.from(keyId).reverse().toString('hex').toUpperCase()}`,
  Buffer.concat([Buffer.from('ED'), keyId, sig]).toString('base64'),
  `trusted comment: ${trusted}`,
  globalSig.toString('base64'),
  '',
].join('\n');
writeFileSync(`${file}.minisig`, out);
console.log(`signed ${file} -> ${file}.minisig (${trusted})`);
