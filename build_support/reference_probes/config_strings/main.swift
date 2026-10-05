import AppKit

struct Input {
    let label: String
    let bytes: [UInt8]?
}
struct Record: Codable {
    let input: String
    let title: String?
    let family: String?
    let command_title: String?
    let command_description: String?
}

let inputs = [
    Input(label: "empty", bytes: []),
    Input(label: "ascii", bytes: Array("Courier".utf8)),
    Input(label: "unicode", bytes: Array("Ω🚀".utf8)),
    Input(label: "valid-replacement", bytes: [0xef, 0xbf, 0xbd]),
    Input(label: "nul", bytes: [0x61, 0, 0x62]),
    Input(label: "invalid-after-nul", bytes: [0x61, 0, 0xff]),
    Input(label: "invalid-before-nul", bytes: [0xff, 0, 0x61]),
    Input(label: "continuation", bytes: [0x80]),
    Input(label: "invalid-lead", bytes: [0xff]),
    Input(label: "overlong-2", bytes: [0xc0, 0xaf]),
    Input(label: "overlong-3", bytes: [0xe0, 0x80, 0xaf]),
    Input(label: "surrogate", bytes: [0xed, 0xa0, 0x80]),
    Input(label: "beyond-max", bytes: [0xf4, 0x90, 0x80, 0x80]),
    Input(label: "truncated-2", bytes: [0xc2]),
    Input(label: "truncated-3", bytes: [0xe2, 0x82]),
    Input(label: "truncated-4", bytes: [0xf0, 0x9f, 0x92]),
    Input(label: "broken-continuation", bytes: [0xe2, 0x58, 0xa1]),
    Input(label: "maximal-subpart", bytes: [0x61, 0xe2, 0x82, 0x62]),
    Input(label: "broken-4", bytes: [0xf0, 0x9f, 0x41]),
    Input(label: "nil", bytes: nil),
]
let config = Ghostty.Config()
var records: [Record] = []
for input in inputs {
    guard let bytes = input.bytes else {
        currentString = nil
        records.append(Record(input: input.label, title: config.title,
                              family: config.windowTitleFontFamily,
                              command_title: nil, command_description: nil))
        continue
    }
    let backing = bytes + [0]
    backing.withUnsafeBytes { buffer in
        currentString = buffer.baseAddress!.assumingMemoryBound(to: Int8.self)
        let command = Ghostty.Command(cValue: ghostty_command_s(
            title: currentString!, description: currentString!,
            action: currentString!, action_key: currentString!))
        records.append(Record(input: input.label, title: config.title,
                              family: config.windowTitleFontFamily,
                              command_title: command.title,
                              command_description: command.description))
    }
}
print(String(data: try JSONEncoder().encode(records), encoding: .utf8)!)
