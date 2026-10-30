import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Open at a desktop size, where OSMS shows all three panes, never smaller than its
    // tablet layout, and where the reader left it last time.
    self.setContentSize(NSSize(width: 1280, height: 820))
    self.contentMinSize = NSSize(width: 900, height: 600)
    self.center()
    self.setFrameAutosaveName("OSMSMainWindow")

    RegisterGeneratedPlugins(registry: flutterViewController)
    WindowChannel.register(messenger: flutterViewController.engine.binaryMessenger, window: self)

    super.awakeFromNib()
  }
}

/// `osms/window`: after the reader signs in in their browser, the app comes back to
/// the front. Best effort: macOS may decline, and the browser tab says where to go.
enum WindowChannel {
  static func register(messenger: FlutterBinaryMessenger, window: NSWindow) {
    let channel = FlutterMethodChannel(name: "osms/window", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak window] call, result in
      guard call.method == "bringToFront" else {
        result(FlutterMethodNotImplemented)
        return
      }
      NSApp.activate(ignoringOtherApps: true)
      window?.makeKeyAndOrderFront(nil)
      result(nil)
    }
  }
}
