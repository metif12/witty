import AppKit

let fixtureBoard = NSPasteboard.withUniqueName()
defer { fixtureBoard.releaseGlobally() }
var completed = ""
var completedConfirmed = false
var completionCount = 0
var approved = false
var prompts = 0

func ghostty_surface_complete_clipboard_request(_ surface: Int, _ value: UnsafePointer<CChar>, _ state: UnsafeMutableRawPointer?, _ confirmed: Bool) {
    completed = String(cString: value)
    completedConfirmed = confirmed
    completionCount += 1
}

let controller = FixtureController()
let observer = NotificationCenter.default.addObserver(forName: .confirmClipboard, object: nil, queue: nil) { notification in
    prompts += 1
    controller.clipboardConfirmation = FixtureConfirmation(contents: notification.userInfo![Notification.ConfirmClipboardStrKey] as! String)
    controller.clipboardConfirmationComplete(approved ? .confirm : .cancel,
        notification.userInfo![Notification.ConfirmClipboardRequestKey] as! Ghostty.ClipboardRequest)
}
defer { NotificationCenter.default.removeObserver(observer) }

var records: [[String: Any]] = []
func record(_ name: String, _ value: String = "", _ type: String = "", _ confirmed: Bool = false) {
    records.append(["name": name, "value": value, "type_": type, "confirmed": confirmed])
}
func write(_ values: [(String, [UInt8])], _ confirm: Bool = false, _ location: Int = 1) {
    var owned: [UnsafeMutablePointer<CChar>] = []
    let contents = values.map { mime, data -> ghostty_clipboard_content_s in
        func cString(_ bytes: [UInt8]) -> UnsafePointer<CChar> {
            let ptr = UnsafeMutablePointer<CChar>.allocate(capacity: bytes.count + 1)
            for (i, value) in bytes.enumerated() { ptr[i] = CChar(bitPattern: value) }
            ptr[bytes.count] = 0
            owned.append(ptr)
            return UnsafePointer(ptr)
        }
        return ghostty_clipboard_content_s(mime: cString(Array(mime.utf8)), data: cString(data))
    }
    defer { for ptr in owned { ptr.deallocate() } }
    contents.withUnsafeBufferPointer {
        FixtureApp.writeClipboard(nil, location: location, content: $0.baseAddress, len: $0.count, confirm: confirm)
    }
}
func text(_ value: String) { fixtureBoard.setString(value, forType: .string) }
for (scenario, name) in ["empty", "text", "file", "file-and-text", "web", "mixed"].enumerated() {
    fixtureBoard.clearContents()
    switch scenario {
    case 1: text("ordinary text")
    case 2, 3: fixtureBoard.writeObjects([NSURL(fileURLWithPath: "/tmp/a b;$?.txt")])
    case 4: fixtureBoard.writeObjects([NSURL(string: "https://example.org/a%20b?x=1&y=2")!])
    case 5: fixtureBoard.writeObjects([NSURL(fileURLWithPath: "/tmp/a b"), NSURL(string: "https://example.org/c?x=1&y=2")!])
    default: break
    }
    if scenario == 3 { text("fallback") }
    let value = fixtureBoard.getOpinionatedStringContents() ?? ""
    FixtureApp.readClipboard(nil, location: 1, state: nil)
    precondition(completed == value && !completedConfirmed, "read \(name): \(String(reflecting: value)) / \(String(reflecting: completed)) confirmed=\(completedConfirmed)")
    record(name, value)
}
for mime in ["text/plain", "text/html", "text/rtf", "application/json", "application/xml", "image/png", "application/x-witty-unknown", "", "invalid mime"] {
    write([(mime, Array("payload".utf8))])
    let type = fixtureBoard.types!.first!
    let value = fixtureBoard.string(forType: type) ?? ""
    precondition(value == "payload")
    record("mime:" + mime, value, type.rawValue)
}
fixtureBoard.clearContents()
text("before\0after")
FixtureApp.readClipboard(nil, location: 1, state: nil)
precondition(completed == "before")
record("read-c-prefix", completed)
let malformed: [UInt8] = [0x61, 0xff, 0x62, 0, 0x63]
write([("application/json\0text/plain", malformed)])
record("write-c-prefix-repair", fixtureBoard.string(forType: .init("public.json"))!, "public.json")
write([("text/plain", Array("untouched".utf8))])
let before = prompts
write([("text/html", Array("rich".utf8))], true)
write([("text/plain", Array("invalid".utf8))], true, 99)
precondition(prompts == before && fixtureBoard.string(forType: .string) == "untouched")
let values = [("text/plain\0ignored", malformed), ("text/html", Array("rich".utf8))]
approved = false
write(values, true)
record("write-denied", fixtureBoard.string(forType: .string)!, fixtureBoard.types!.first!.rawValue)
approved = true
write(values, true)
precondition(!fixtureBoard.types!.contains(.html))
record("write-approved", fixtureBoard.string(forType: .string)!, fixtureBoard.types!.first!.rawValue)
let countBeforeInvalid = completionCount
var bad = malformed.map { CChar(bitPattern: $0) }
bad.append(0)
bad.withUnsafeBufferPointer {
    FixtureApp.confirmReadClipboard(nil, string: $0.baseAddress, state: nil, request: 1)
}
precondition(completionCount == countBeforeInvalid)
let promptCountBeforeInvalid = prompts
"read".withCString {
    FixtureApp.confirmReadClipboard(nil, string: $0, state: nil, request: 255)
}
precondition(completionCount == countBeforeInvalid && prompts == promptCountBeforeInvalid)
"read\0ignored".withCString {
    FixtureApp.confirmReadClipboard(nil, string: $0, state: nil, request: 1)
}
precondition(completed == "read" && completedConfirmed)
record("read-approved", completed, "", true)
approved = false
"read".withCString {
    FixtureApp.confirmReadClipboard(nil, string: $0, state: nil, request: 1)
}
precondition(completed == "" && completedConfirmed)
record("read-denied", "", "", true)
let output = try JSONSerialization.data(withJSONObject: records, options: [.sortedKeys])
print(String(decoding: output, as: UTF8.self))
