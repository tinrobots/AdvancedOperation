//
// AdvancedOperation
//
// Copyright © 2016-2019 Tinrobots.
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

extension NSError {
  // Not localizable debug error message.
  var debugErrorMessage: String {
    return userInfo[NSDebugDescriptionErrorKey] as? String ?? "No debug message evailable for NSDebugDescriptionErrorKey."
  }
}

extension NSError {
  enum AdvancedOperation {
    // Error thrown when an Operation gets cancelled.
    static let cancelled: NSError = {
      var info = [String: Any]()
      info[NSDebugDescriptionErrorKey] = "The operation has been cancelled."
      let error = NSError(domain: identifier, code: 1, userInfo: info)
      return error
    }()

    // Creates an AdvancedOperation generic error.
    static func makeFinishError(debugMessage message: String) -> NSError {
      var info = [String: Any]()
      info[NSDebugDescriptionErrorKey] = message
      let error = NSError(domain: identifier, code: 2, userInfo: info)
      return error
    }
  }
}

//public typealias DomainError = CustomNSError
//
//public struct Failure: Error {
//  let underlyingNSError: NSError
//
//  public init(_ error: NSError) {
//    self.underlyingNSError = error
//  }
//
//  public init(_ error: DomainError) {
//    self.underlyingNSError = NSError(error)
//  }
//
//  public init(debugDescription: String, localizedDescription: String?) {
//    var info = [String: Any]()
//    info[NSLocalizedDescriptionKey] = localizedDescription
//    info[NSDebugDescriptionErrorKey] = debugDescription
//    self.underlyingNSError = NSError(domain: identifier, code: 3, userInfo: info)
//  }
//}
//
//extension NSError {
//  convenience init(_ error: DomainError) {
//    self.init(domain: type(of: error.self).errorDomain,
//              code: error.errorCode,
//              userInfo: error.errorUserInfo)
//  }
//}
//
//extension Result where Failure == AdvancedOperation.Failure {
//  func eraseFailureError() -> Result<Success,Error> {
//    switch self {
//    case .success(let success): return .success(success)
//    case .failure(let failure): return .failure(failure.underlyingNSError)
//    }
//  }
//}
