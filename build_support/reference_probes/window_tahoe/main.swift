import AppKit
import SwiftUI

struct Record: Codable {
    let input: String
    let title: String
    let display_title: String
    let has_tab_bar: Bool
    let main: Bool
    let font_name: String?
    let toolbar_id: String
    let allowed: [String]
    let defaults: [String]
    let centered: Bool
    let priority: Int
    let compression: Float
    let bordered: Bool
}
func drain() { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1)) }

_ = NSApplication.shared
let window = TitlebarTabsTahoeTerminalWindow(contentRect: NSRect(x: 100, y: 100, width: 480, height: 320),
    styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
window.isReleasedWhenClosed = false
window.awakeFromNib()
window.title = "original title"
let model = Mirror(reflecting: window).children.first { $0.label == "viewModel" }!.value
    as! TitlebarTabsTahoeTerminalWindow.ViewModel
let toolbar = window.toolbar!
let item = window.toolbar(toolbar, itemForItemIdentifier: .title, willBeInsertedIntoToolbar: true)!
func record(_ input: String) -> Record {
    Record(input: input, title: model.title,
        display_title: TitlebarTabsTahoeTerminalWindow.TitleItem(viewModel: model).title,
        has_tab_bar: model.hasTabBar, main: model.isMainWindow, font_name: model.titleFont?.fontName,
        toolbar_id: toolbar.identifier,
        allowed: window.toolbarAllowedItemIdentifiers(toolbar).map(\.rawValue),
        defaults: window.toolbarDefaultItemIdentifiers(toolbar).map(\.rawValue),
        centered: toolbar.centeredItemIdentifiers.contains(.title), priority: item.visibilityPriority.rawValue,
        compression: item.view!.contentCompressionResistancePriority(for: .horizontal).rawValue,
        bordered: item.isBordered)
}
var records = [record("initial")]
drain()
records.append(record("original"))
window.title = "changed title"
records.append(record("queued-title"))
drain()
records.append(record("changed"))
window.titlebarFont = NSFont(name: "Menlo", size: NSFont.systemFontSize)
drain()
records.append(record("font"))
window.resignMain()
records.append(record("inactive"))
window.becomeMain()
window.title = ""
drain()
records.append(record("empty"))
model.hasTabBar = true
records.append(record("tabs"))
window.removeTabBar()
drain()
records.append(record("removed"))
window.titlebarFont = nil
drain()
records.append(record("no-font"))
window.close()
print(String(data: try JSONEncoder().encode(records), encoding: .utf8)!)
