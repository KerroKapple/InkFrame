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
    // 单次回复守卫：Dart 回调与超时兜底竞争，谁先到谁 reply，另一个变 no-op。
    // 二者都在主线程执行，无需锁；杜绝对 applicationShouldTerminate 的重复 reply。
    var replied = false
    func replyTerminateOnce() {
      if replied { return }
      replied = true
      NSApp.reply(toApplicationShouldTerminate: true)
    }
    let channel = FlutterMethodChannel(
      name: "inkframe/lifecycle",
      binaryMessenger: controller.engine.binaryMessenger)
    channel.invokeMethod("requestTerminate", arguments: nil) { _ in
      replyTerminateOnce()
    }
    // 兜底超时：Dart 若 15s 内未回调（channel 握手异常 / teardown 卡死），
    // 照常退出，避免 Cmd+Q 永久卡死须 Force Quit——最坏退化为「teardown 未跑完」，
    // 与本修复前同级。15s 高于 teardown 内 pg_ctl stop -t 10 的上限；正常路径
    // 由 Dart 回调即时 reply，根本走不到此超时。
    DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
      replyTerminateOnce()
    }
    return .terminateLater
  }
}
