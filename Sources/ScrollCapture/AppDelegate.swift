import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    private var quitting = false
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if quitting { return .terminateLater }
        guard let model else { return .terminateNow }
        quitting = true
        Task { await model.shutdown(); sender.reply(toApplicationShouldTerminate:true) }
        return .terminateLater
    }
}
