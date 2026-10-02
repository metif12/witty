module no_main
import wasm_log
@[export: 'probe_log']
fn emit(index int) {
  match index {
    0 { wasm_log.write(.err, '', 'failure') }
    1 { wasm_log.write(.warn, 'key_event', 'warning') }
    2 { wasm_log.write(.info, 'test', 'information') }
    3 { wasm_log.write(.debug, '', 'details') }
    4 { wasm_log.write(.warn, 'test', 'a'.repeat(2020)) }
    5 { wasm_log.write(.warn, 'test', 'a'.repeat(3000)) }
    else { panic('unknown fixture') }
  }
}
