// Test host types required by the four unchanged original updater files.
// They are fixture dependencies, not updater implementation replacements.
import Cocoa
import Sparkle

class TerminalWindow: NSWindow {
    static let terminalWillCloseNotification = Notification.Name("UpdaterProbeTerminalWillClose")
}
class QuickTerminalWindow: NSWindow {}
enum ProbeChannel { case tip, stable }
struct ProbeConfig { let autoUpdateChannel = ProbeChannel.stable }
struct ProbeGhostty { let config = ProbeConfig() }
class AppDelegate: NSObject, NSApplicationDelegate {
    let ghostty = ProbeGhostty()
    func checkForUpdates(_ sender: Any?) {}
}

_ = NSApplication.shared
let item = SUAppcastItem(dictionary: [
    "title": "Ghostty 1.3.0",
    "sparkle:version": "130",
    "sparkle:shortVersionString": "1.3.0",
    "enclosure": ["url": "https://example.invalid/ghostty.zip", "sparkle:version": "130", "sparkle:shortVersionString": "1.3.0"]
])!
let model = UpdateViewModel()
let states: [UpdateState] = [
    .idle,
    .permissionRequest(.init(request: SPUUpdatePermissionRequest(systemProfile: []), reply: { _ in })),
    .checking(.init(cancel: {})),
    .updateAvailable(.init(appcastItem: item, reply: { _ in })),
    .notFound(.init(acknowledgement: {})),
    .error(.init(error: NSError(domain: "probe", code: 1, userInfo: [NSLocalizedDescriptionKey: "Source error"]), retry: {}, dismiss: {})),
    .downloading(.init(cancel: {}, expectedLength: nil, progress: 0)),
    .downloading(.init(cancel: {}, expectedLength: 0, progress: 0)),
    .downloading(.init(cancel: {}, expectedLength: 200, progress: 25)),
    .downloading(.init(cancel: {}, expectedLength: 100, progress: 150)),
    .extracting(.init(progress: 0.125)),
    .extracting(.init(progress: 1.5)),
    .installing(.init(retryTerminatingApplication: {}, dismiss: {})),
    .installing(.init(isAutoUpdate: true, retryTerminatingApplication: {}, dismiss: {})),
]
var records: [[String: Any]] = []
for state in states {
    model.state = state
    records.append(["text": model.text, "width": model.maxWidthText,
                    "icon": model.iconName as Any? ?? NSNull(),
                    "badge": model.badge as Any? ?? NSNull(),
                    "installable": state.isInstallable])
}
let controller = UpdateController()
var confirmations = 0
controller.viewModel.state = .checking(.init(cancel: {}))
controller.installUpdate()
precondition(controller.isInstalling)
controller.viewModel.state = .updateAvailable(.init(appcastItem: item, reply: { choice in
    precondition(choice == .install)
    confirmations += 1
}))
precondition(confirmations == 1)
controller.viewModel.state = .idle
precondition(!controller.isInstalling)
controller.viewModel.state = .checking(.init(cancel: {}))
controller.installUpdate()
controller.checkForUpdates()
controller.viewModel.state = .idle
precondition(controller.isInstalling) // canceled optional remains non-nil in source
let encoded = try JSONSerialization.data(withJSONObject: records, options: [.sortedKeys])
print(String(data: encoded, encoding: .utf8)!)
