const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
(async () => {
  const sourceMessages = [], translatedMessages = [];
  let source;
  source = (await WebAssembly.instantiate(fs.readFileSync(process.argv[2]), {
    env: {log: (ptr,len) => sourceMessages.push(new TextDecoder().decode(new Uint8Array(source.exports.memory.buffer,ptr,len)))}
  })).instance;
  const translated = await require(path.resolve(process.argv[3]))({ghosttyLog: text => translatedMessages.push(text)});
  for (let i=0;i<6;i++) source.exports.probe_log(i);
  for (let i=0;i<6;i++) translated._probe_log(i);
  const mode = process.argv[4] || 'Debug';
  assert.deepEqual(translatedMessages, sourceMessages);
  console.log(mode + ': six source log fixtures, including stack and allocation fallback, matched');
})().catch(error => { console.error(error); process.exitCode = 1; });
