import AppKit

struct ghostty_action_start_search_s { let needle: UnsafePointer<CChar>? }
struct ghostty_action_key_table_activate_s { let name: UnsafeRawPointer; let len: Int }
struct ghostty_action_key_table_value { let activate: ghostty_action_key_table_activate_s }
struct ghostty_action_key_table_s { let tag: Int32; let value: ghostty_action_key_table_value }
let GHOSTTY_KEY_TABLE_ACTIVATE: Int32 = 0
let GHOSTTY_KEY_TABLE_DEACTIVATE: Int32 = 1
let GHOSTTY_KEY_TABLE_DEACTIVATE_ALL: Int32 = 2
typealias ghostty_app_t = Int
struct ghostty_target_value { let surface: Int? }
struct ghostty_target_s { let tag: Int32; let target: ghostty_target_value }
let GHOSTTY_TARGET_APP: Int32 = 0
let GHOSTTY_TARGET_SURFACE: Int32 = 1
struct ghostty_action_mouse_over_link_s { let url: UnsafeRawPointer?; let len: Int }
struct LoggerFixture { func warning(_ message: String) {} }
final class SurfaceViewFixture { var hoverUrl: String? }
let surfaceViewFixture = SurfaceViewFixture()

struct SourceStringRecord: Codable {
    let input: String
    let search: String?
    let key_table: String
    let hover: String?
    let c_strict: String?
}
struct Input { let label: String; let bytes: [UInt8]; let length: Int }
let inputs = [
    Input(label: "empty", bytes: [], length: -1),
    Input(label: "ascii", bytes: Array("ghostty".utf8), length: -1),
    Input(label: "unicode", bytes: Array("Ω🚀".utf8), length: -1),
    Input(label: "valid-replacement", bytes: [0xef,0xbf,0xbd], length: -1),
    Input(label: "nul", bytes: [97,0,98], length: -1),
    Input(label: "invalid-after-nul", bytes: [97,0,0xff], length: -1),
    Input(label: "invalid-before-nul", bytes: [0xff,0,97], length: -1),
    Input(label: "continuation", bytes: [0x80], length: -1),
    Input(label: "invalid-lead", bytes: [0xff], length: -1),
    Input(label: "overlong-2", bytes: [0xc0,0xaf], length: -1),
    Input(label: "overlong-3", bytes: [0xe0,0x80,0xaf], length: -1),
    Input(label: "surrogate", bytes: [0xed,0xa0,0x80], length: -1),
    Input(label: "beyond-max", bytes: [0xf4,0x90,0x80,0x80], length: -1),
    Input(label: "obsolete-5", bytes: [0xf8,0x88,0x80,0x80,0x80], length: -1),
    Input(label: "truncated-2", bytes: [0xc2], length: -1),
    Input(label: "truncated-3", bytes: [0xe2,0x82], length: -1),
    Input(label: "truncated-4", bytes: [0xf0,0x9f,0x92], length: -1),
    Input(label: "broken-continuation", bytes: [0xe2,88,0xa1], length: -1),
    Input(label: "maximal-subpart", bytes: [97,0xe2,0x82,98], length: -1),
    Input(label: "broken-4", bytes: [0xf0,0x9f,65], length: -1),
    Input(label: "bounded-tail", bytes: [116,97,98,108,101,0xff], length: 5),
]
var records: [SourceStringRecord] = []
for input in inputs {
    let backing = input.bytes + [0]
    let length = input.length >= 0 ? input.length : input.bytes.count
    backing.withUnsafeBytes { buffer in
        let pointer = buffer.baseAddress!
        let cString = pointer.assumingMemoryBound(to: CChar.self)
        let search = Ghostty.Action.StartSearch(c: ghostty_action_start_search_s(needle: cString)).needle
        let action = Ghostty.Action.KeyTable(c: ghostty_action_key_table_s(tag: GHOSTTY_KEY_TABLE_ACTIVATE,
            value: ghostty_action_key_table_value(activate: ghostty_action_key_table_activate_s(name: pointer, len: length))))!
        guard case .activate(let name) = action else { fatalError() }
        SourceHoverAction.setMouseOverLink(1,
            target: ghostty_target_s(tag: GHOSTTY_TARGET_SURFACE, target: ghostty_target_value(surface: 1)),
            v: ghostty_action_mouse_over_link_s(url: pointer, len: length))
        records.append(SourceStringRecord(input: input.label, search: search, key_table: name,
            hover: surfaceViewFixture.hoverUrl, c_strict: String(cString: cString, encoding: .utf8)))
    }
}
records.append(SourceStringRecord(input: "nil-search",
    search: Ghostty.Action.StartSearch(c: ghostty_action_start_search_s(needle: nil)).needle,
    key_table: "", hover: nil, c_strict: nil))
print(String(data: try JSONEncoder().encode(records), encoding: .utf8)!)
