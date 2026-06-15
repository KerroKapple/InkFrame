import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // Cmd+Q / 菜单 Quit 走 NSApp.terminate，不经 window_manager 的 windowShouldClose，
  // 故在此请求 Dart 侧先完成 AppTeardown（停队列→关连接池→pg_ctl stop），
  // 回收完成后再 reply terminateNow，避免嵌入式 PostgreSQL postmaster 孤儿化。
  override func applicationShouldTerminate(
    _ sender: NSApplication
  ) -> NSApplication.TerminateReply {
    guard
      let window = NSApp.windows.first(where: {
        $0.contentViewController is FlutterViewController
      }),
      let controller = window.contentViewController as? FlutterViewController
    else {
      return .terminateNow
    }
    let channel = FlutterMethodChannel(
      name: "inkframe/lifecycle",
      binaryMessenger: controller.engine.binaryMessenger)
    channel.invokeMethod("requestTerminate", arguments: nil) { _ in
      NSApp.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
  }
}
