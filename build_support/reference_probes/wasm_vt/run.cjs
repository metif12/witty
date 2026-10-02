// Exercise the installed V artifact with the unchanged Ghostty C examples'
// inputs and outputs, plus the source Wasm allocation and logging boundary.
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
(async () => {
  const loader = path.resolve(process.argv[2]);
  const logs = [];
  const m = await require(loader)({ghosttyLog: text => logs.push(text)});
  const bytes = fs.readFileSync(loader.replace(/\.js$/, '.wasm'));
  const exports = WebAssembly.Module.exports(new WebAssembly.Module(bytes));
  assert.equal(exports.filter(e => e.name.startsWith('ghostty_')).length, 50);
  const ptr = m._ghostty_wasm_alloc_opaque();
  const size = m._ghostty_wasm_alloc_usize();
  const value = m._ghostty_wasm_alloc_u8();
  const u16 = m._ghostty_wasm_alloc_u16_array(17);
  const attr = m._ghostty_wasm_alloc_sgr_attribute();
  const buffer = m._ghostty_wasm_alloc_u8_array(128);
  for (const p of [ptr, size, value, u16, attr, buffer]) assert.ok(p);
  assert.equal(m._ghostty_key_encoder_new(0, ptr), 0);
  const encoder = m.HEAPU32[ptr >>> 2];
  assert.equal(m._ghostty_key_event_new(0, ptr), 0);
  const event = m.HEAPU32[ptr >>> 2];
  m.HEAPU8[value] = 31; // GHOSTTY_KITTY_KEY_ALL
  m._ghostty_key_encoder_setopt(encoder, 5, value);
  m._ghostty_key_event_set_action(event, 0); // release
  m._ghostty_key_event_set_key(event, 56); // control-left
  m._ghostty_key_event_set_mods(event, 2); // ctrl
  assert.equal(m._ghostty_key_encoder_encode(encoder, event, 0, 0, size), -1);
  const required = m.HEAPU32[size >>> 2];
  assert.equal(m._ghostty_key_encoder_encode(encoder, event, buffer, 128, size), 0);
  assert.equal(m.HEAPU32[size >>> 2], required);
  assert.equal(new TextDecoder().decode(m.HEAPU8.subarray(buffer, buffer + required)), '\x1b[57442;5:3u');
  m._ghostty_key_event_set_action(event, 999);
  assert.equal(m._ghostty_key_event_get_action(event), 0);
  assert.deepEqual(logs, ['warning(key_event): set_action invalid action value=999']);
  m._ghostty_key_event_free(event);
  m._ghostty_key_encoder_free(encoder);
  assert.equal(m._ghostty_osc_new(0, ptr), 0);
  const osc = m.HEAPU32[ptr >>> 2];
  for (const byte of Buffer.from('2;hello')) m._ghostty_osc_next(osc, byte);
  const command = m._ghostty_osc_end(osc, 7);
  assert.equal(m._ghostty_osc_command_type(command), 1);
  assert.equal(m._ghostty_osc_command_data(command, 1, ptr), 1);
  const title = m.HEAPU32[ptr >>> 2];
  const end = m.HEAPU8.indexOf(0, title);
  assert.equal(new TextDecoder().decode(m.HEAPU8.subarray(title, end)), 'hello');
  m._ghostty_osc_reset(osc);
  assert.equal(m._ghostty_osc_command_type(m._ghostty_osc_end(osc, 7)), 0);
  m._ghostty_osc_free(osc);
  assert.equal(m._ghostty_sgr_new(0, ptr), 0);
  const sgr = m.HEAPU32[ptr >>> 2];
  m.HEAPU16.set([4,3,38,2,51,51,51,48,2,170,170,170,58,2,255,97,136], u16 >>> 1);
  m.HEAPU8.set(Buffer.from(':;;;;;;;;;;;;;;;'), buffer);
  assert.equal(m._ghostty_sgr_set_params(sgr, u16, buffer, 17), 0);
  const attributes = [];
  while (m._ghostty_sgr_next(sgr, attr)) {
    const tag = m._ghostty_sgr_attribute_tag(attr);
    const data = m._ghostty_sgr_attribute_value(attr);
    attributes.push([tag, tag === 7 ? m.HEAPU32[data >>> 2] : Array.from(m.HEAPU8.subarray(data, data + 3))]);
  }
  // Pinned terminal/sgr.zig Tag values. The pinned C header has an extra
  // RESET_UNDERLINE entry and different later ordinals; preserve the source.
  assert.deepEqual(attributes, [[7,3],[21,[51,51,51]],[22,[170,170,170]],[8,[255,97,136]]]);
	const overlong = m._ghostty_wasm_alloc_u16_array(25);
	m.HEAPU16.fill(0, overlong >>> 1, (overlong >>> 1) + 25);
	m.HEAPU8.fill(59, buffer, buffer + 25);
	assert.equal(m._ghostty_sgr_set_params(sgr, overlong, buffer, 25), -2);
	assert.equal(logs.at(-1), 'warning(sgr): ghostty_sgr_set_params: separators length 25 exceeds max supported length 24');
	m._ghostty_wasm_free_u16_array(overlong, 25);
  m._ghostty_sgr_free(sgr);
  for (const [text,safe] of [['hello',1],['a\nb',0],['\x1b[201~',0]]) {
    const data = Buffer.from(text);
    m.HEAPU8.set(data, buffer);
    assert.equal(m._ghostty_paste_is_safe(buffer, data.length), safe);
  }
  // Growth must update the vendor runtime's heap views used by the host.
  const before = m.HEAPU8.length;
  const large = m._ghostty_wasm_alloc_u8_array(before + 65536);
  assert.ok(large);
  assert.ok(m.HEAPU8.length > before);
  m.HEAPU8[large] = 42;
  assert.equal(m.HEAPU8[large], 42);
  m._ghostty_wasm_free_u8_array(large, before + 65536);
  m._ghostty_wasm_free_u8_array(buffer, 128);
  m._ghostty_wasm_free_sgr_attribute(attr);
  m._ghostty_wasm_free_u16_array(u16, 17);
  m._ghostty_wasm_free_u8(value);
  m._ghostty_wasm_free_usize(size);
  m._ghostty_wasm_free_opaque(ptr);
  for (const fn of ['opaque','u8','usize']) m['_ghostty_wasm_free_' + fn](0);
  m._ghostty_wasm_free_u8_array(0, 0);
  m._ghostty_wasm_free_u16_array(0, 0);
  console.log('50 exports; source encoder/OSC/SGR/paste/logging; all paired allocations and memory growth passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
