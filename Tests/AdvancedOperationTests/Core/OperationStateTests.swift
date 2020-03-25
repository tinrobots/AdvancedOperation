//
// AdvancedOperation
//
// Copyright © 2016-2020 Tinrobots.
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

import XCTest
@testable import AdvancedOperation

final class OperationStateTests: XCTestCase {
  func testTransition() {
    // ready
    XCTAssertTrue(AsyncOperation.State.pending.canTransition(to: .executing))
    XCTAssertTrue(AsyncOperation.State.pending.canTransition(to: .finished))
    XCTAssertFalse(AsyncOperation.State.pending.canTransition(to: .pending))

    // Executing
    XCTAssertFalse(AsyncOperation.State.executing.canTransition(to: .executing))
    XCTAssertTrue(AsyncOperation.State.executing.canTransition(to: .finished))
    XCTAssertFalse(AsyncOperation.State.executing.canTransition(to: .pending))

    // finished
    XCTAssertFalse(AsyncOperation.State.finished.canTransition(to: .executing))
    XCTAssertFalse(AsyncOperation.State.finished.canTransition(to: .finished))
    XCTAssertFalse(AsyncOperation.State.finished.canTransition(to: .pending))
  }

  func testDebugDescription() {
    XCTAssertEqual(AsyncOperation.State.pending.debugDescription.lowercased(), "pending")
    XCTAssertEqual(AsyncOperation.State.executing.debugDescription.lowercased(), "executing")
    XCTAssertEqual(AsyncOperation.State.finished.debugDescription.lowercased(), "finished")
  }
}
