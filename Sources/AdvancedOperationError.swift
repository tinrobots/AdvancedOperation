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

import Foundation

public struct AdvancedOperationError {

  public enum Code {
    static let conditionFailed = 100
    static let executionCancelled = 200
  }

  static var domain = identifier

  static func conditionFailed(message: String, userInfo: [String: Any]? = nil) -> NSError {
    var info: [String: Any] =  [
      NSLocalizedFailureReasonErrorKey: "The operation condition wasn't satisfied.",
      NSLocalizedDescriptionKey: message
    ]

    userInfo?.forEach { (key, value) in
      info[key] = value
    }

    return NSError(domain: domain, code: Code.conditionFailed, userInfo: info)
  }

  static func executionCancelled(message: String, userInfo: [String: Any]? = nil) -> NSError {
    var info: [String: Any] =  [
      NSLocalizedFailureReasonErrorKey: "The operation execution has been cancelled.",
      NSLocalizedDescriptionKey: message
    ]

    userInfo?.forEach { (key, value) in
      info[key] = value
    }

    return NSError(domain: domain, code: Code.executionCancelled, userInfo: info)
  }
}
