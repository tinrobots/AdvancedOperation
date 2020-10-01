// AdvancedOperation

import Foundation

#if swift(<5.1)
/// Workaround to solve some  multithreading bugs in Swift's KVO.
/// This needs to execute before anything can register KVO in the background so the best way to do this is before the application ever runs
///
/// `KVOCrashWorkaround.installFix()`
///
/// - Note: it's not required for Swift 5.1 and above, see this [Swift PR](https://github.com/apple/swift/pull/20103)
public final class KVOCrashWorkaround: NSObject {
  @objc dynamic var test: String = ""

  /// Install the workaround: it shoud be done from the **main** thread.
  public static func installFix() {
    assert(Thread.isMainThread)
    let obj = KVOCrashWorkaround()
    let observer = obj.observe(\.test, options: [.new]) { (_, _) in
      fatalError("Shouldn't be called, value doesn't change")
    }
    observer.invalidate()
  }
}
#endif
