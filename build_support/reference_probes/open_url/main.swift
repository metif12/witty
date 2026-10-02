import AppKit

// Host C action fixtures only. The action body is extracted unchanged except
// its shared workspace receiver, which records opens instead of launching apps.
struct ghostty_action_open_url_s { let url: String; let kind: Int32 }
enum Ghostty {
    enum Action {
        struct OpenURL {
            enum Kind: Int32 { case unknown = 0, text = 1, html = 2 }
            let url: String
            let kind: Kind
            init(c: ghostty_action_open_url_s) { url = c.url; kind = Kind(rawValue: c.kind)! }
        }
    }
}

final class URLProbeWorkspace {
    static let shared = URLProbeWorkspace()
    var lastURL = ""
    var lastEditor = ""
    var calls = 0
    var defaultTextEditor: URL? { NSWorkspace.shared.defaultTextEditor }
    func defaultApplicationURL(forExtension ext: String) -> URL? {
        NSWorkspace.shared.defaultApplicationURL(forExtension: ext)
    }
    func open(_ url: URL) -> Bool {
        lastURL = url.absoluteString
        lastEditor = ""
        calls += 1
        return false
    }
    func open(_ urls: [URL], withApplicationAt editor: URL, configuration: NSWorkspace.OpenConfiguration) {
        precondition(urls.count == 1)
        lastURL = urls[0].absoluteString
        lastEditor = editor.absoluteString
        calls += 1
    }
}

struct URLProbeRecord: Codable { let input: String; let kind: Int32; let url: String; let editor: String }
let inputs = ["https://ghostty.org/docs?query=hello world", "https://ghostty.org/docs/a%20b",
              "/tmp/witty config.ghostty", "relative config.txt", "file:///tmp/witty%20config.txt",
              "/tmp/readme.md", "/tmp/unknown-extension.witty-ultra-nonexistent-extension",
              "/tmp/no-extension", "", "mailto:alex@example.test", "/tmp/native.html"]
var records: [URLProbeRecord] = []
for input in inputs {
    for kind: Int32 in [0, 1, 2] {
        let before = URLProbeWorkspace.shared.calls
        precondition(SourceURLAction.openURL(ghostty_action_open_url_s(url: input, kind: kind)))
        precondition(URLProbeWorkspace.shared.calls == before + 1)
        records.append(URLProbeRecord(input: input, kind: kind,
                                      url: URLProbeWorkspace.shared.lastURL,
                                      editor: URLProbeWorkspace.shared.lastEditor))
    }
}
print(String(data: try JSONEncoder().encode(records), encoding: .utf8)!)
