//
// AdvancedOperation
//
// Copyright © 2016-2018 Tinrobots.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#if canImport(UIKit) && !os(watchOS)

import UIKit

public class UIBackgroundObserver: NSObject {

  public static let backgroundTaskName = "\(identifier).UIBackgroundObserver"

  private let application: UIApplication
  private var taskIdentifier: UIBackgroundTaskIdentifier = .invalid

  public init(application: UIApplication) {
    self.application = application
    super.init()

    let active = #selector(UIBackgroundObserver.didBecomeActive(notification:))
    let background = #selector(UIBackgroundObserver.didEnterBackground(notification:))
    NotificationCenter.default.addObserver(self, selector: background, name: UIApplication.didEnterBackgroundNotification, object: .none)
    NotificationCenter.default.addObserver(self, selector: active, name: UIApplication.didBecomeActiveNotification, object: .none)

    if isInBackground {
      startBackgroundTask()
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  private var isInBackground: Bool {
    return application.applicationState == .background
  }

  @objc
  private func didEnterBackground(notification: NSNotification) {
    if isInBackground {
      startBackgroundTask()
    }
  }

  @objc
  private func didBecomeActive(notification: NSNotification) {
    if !isInBackground {
      endBackgroundTask()
    }
  }

  private func startBackgroundTask() {
    if taskIdentifier == .invalid {
      taskIdentifier = application.beginBackgroundTask(withName: type(of: self).backgroundTaskName) {
        self.endBackgroundTask()
      }
    }
  }

  private func endBackgroundTask() {
    if taskIdentifier != .invalid {
      application.endBackgroundTask(taskIdentifier)
      taskIdentifier = .invalid
    }
  }

}

extension UIBackgroundObserver: OperationDidFinishObserving {

  public func operationDidFinish(operation: Operation, withErrors errors: [Error]) {
    endBackgroundTask()
  }
  
}

#endif
