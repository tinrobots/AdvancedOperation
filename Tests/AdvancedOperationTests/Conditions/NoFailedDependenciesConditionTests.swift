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

import XCTest
@testable import AdvancedOperation

final class NoFailedDependenciesConditionTests: XCTestCase {

  func testIsMutuallyExclusive() {
    XCTAssertTrue(NoFailedDependenciesCondition().mutuallyExclusivityMode == .no)
  }

  func testFinishedAndFailedOperation() {
    let queue = AdvancedOperationQueue()

    let expectation1 = expectation(description: "\(#function)\(#line)")
    let expectation2 = expectation(description: "\(#function)\(#line)")
    let expectation3 = expectation(description: "\(#function)\(#line)")
    let expectation4 = expectation(description: "\(#function)\(#line)")

    let operation1 = XCTFailOperation()
    operation1.name = "operation1"

    let operation2 = FailingAsyncOperation(errors: [.failed])
    operation2.name = "operation2"

    let operation3 = SleepyAsyncOperation()
    operation3.name = "operation3"

    let operation4 = DelayOperation(interval: 1)
    operation4.name = "operation4"

    operation1.addCompletionBlock { expectation1.fulfill() }
    operation2.addCompletionBlock { expectation2.fulfill() }
    operation3.addCompletionBlock { expectation3.fulfill() }
    operation4.addCompletionBlock { expectation4.fulfill() }

    operation1.addCondition(NoFailedDependenciesCondition())
    [operation4, operation3, operation2].then(operation1)
    queue.addOperations([operation1, operation2, operation3, operation4], waitUntilFinished: false)
    waitForExpectations(timeout: 5)
    XCTAssertTrue(operation1.failed)
    XCTAssertEqual(operation1.errors.count, 2)
  }

  func testCancelledAndFailedOperation() {
    let queue = AdvancedOperationQueue()

    let expectation1 = expectation(description: "\(#function)\(#line)")
    let expectation2 = expectation(description: "\(#function)\(#line)")
    let expectation3 = expectation(description: "\(#function)\(#line)")
    let expectation4 = expectation(description: "\(#function)\(#line)")

    let operation1 = XCTFailOperation()
    operation1.name = "operation1"

    let operation2 = SleepyAsyncOperation()
    operation2.name = "operation2"

    let operation3 = SleepyAsyncOperation()
    operation3.name = "operation3"

    let operation4 = DelayOperation(interval: 1)
    operation4.name = "operation4"

    operation2.cancel(error: MockError.failed)

    operation1.addCompletionBlock { expectation1.fulfill() }
    operation2.addCompletionBlock { expectation2.fulfill() }
    operation3.addCompletionBlock { expectation3.fulfill() }
    operation4.addCompletionBlock { expectation4.fulfill() }

    operation1.addCondition(NoFailedDependenciesCondition())
    [operation4, operation3, operation2].then(operation1)
    queue.addOperations([operation1, operation2, operation3, operation4], waitUntilFinished: false)
    waitForExpectations(timeout: 5)
    XCTAssertTrue(operation1.failed)
    XCTAssertEqual(operation1.errors.count, 2)
  }

  func testIgnoredCancelledAndFailedOperation() {
    let queue = AdvancedOperationQueue()

    let expectation1 = expectation(description: "\(#function)\(#line)")
    let expectation2 = expectation(description: "\(#function)\(#line)")
    let expectation3 = expectation(description: "\(#function)\(#line)")
    let expectation4 = expectation(description: "\(#function)\(#line)")

    let operation1 = AdvancedBlockOperation { }
    operation1.name = "operation1"

    let operation2 = SleepyAsyncOperation()
    operation2.name = "operation2"

    let operation3 = SleepyAsyncOperation()
    operation3.name = "operation3"

    let operation4 = DelayOperation(interval: 1)
    operation4.name = "operation4"

    operation2.cancel(error: MockError.failed)

    operation1.addCompletionBlock { expectation1.fulfill() }
    operation2.addCompletionBlock { expectation2.fulfill() }
    operation3.addCompletionBlock { expectation3.fulfill() }
    operation4.addCompletionBlock { expectation4.fulfill() }

    operation1.addCondition(NoFailedDependenciesCondition(ignoreCancellations: true))
    [operation4, operation3, operation2].then(operation1)
    queue.addOperations([operation1, operation2, operation3, operation4], waitUntilFinished: false)
    waitForExpectations(timeout: 10)
    XCTAssertFalse(operation1.failed)
  }

  func testIgnoredCancelledAndFailedOperationAndFailedOperation() {
    let queue = AdvancedOperationQueue()

    let expectation1 = expectation(description: "\(#function)\(#line)")
    let expectation2 = expectation(description: "\(#function)\(#line)")
    let expectation3 = expectation(description: "\(#function)\(#line)")
    let expectation4 = expectation(description: "\(#function)\(#line)")

    let operation1 = XCTFailOperation()
    operation1.name = "operation1"

    let operation2 = SleepyAsyncOperation()
    operation2.name = "operation2"

    let operation3 = SleepyAsyncOperation()
    operation3.name = "operation3"

    let operation4 = FailingAsyncOperation(errors: [.failed, .cancelled(date: Date())])
    operation4.name = "operation4"

    operation2.cancel(error: MockError.failed)

    operation1.addCompletionBlock { expectation1.fulfill() }
    operation2.addCompletionBlock { expectation2.fulfill() }
    operation3.addCompletionBlock { expectation3.fulfill() }
    operation4.addCompletionBlock { expectation4.fulfill() }

    operation1.addCondition(NoFailedDependenciesCondition(ignoreCancellations: true))
    [operation4, operation3, operation2].then(operation1)
    queue.addOperations([operation1, operation2, operation3, operation4], waitUntilFinished: false)
    waitForExpectations(timeout: 10)
    XCTAssertTrue(operation1.failed)
    XCTAssertEqual(operation1.errors.count, 3)
  }

  func testFinishedAndFailedOperationNegated() {
    let queue = AdvancedOperationQueue()

    let expectation1 = expectation(description: "\(#function)\(#line)")
    let expectation2 = expectation(description: "\(#function)\(#line)")
    let expectation3 = expectation(description: "\(#function)\(#line)")
    let expectation4 = expectation(description: "\(#function)\(#line)")

    let operation1 = AdvancedBlockOperation { }
    operation1.name = "operation1"

    let operation2 = FailingAsyncOperation(errors: [.failed])
    operation2.name = "operation2"

    let operation3 = SleepyAsyncOperation()
    operation3.name = "operation3"

    let operation4 = DelayOperation(interval: 1)
    operation4.name = "operation4"

    operation1.addCompletionBlock { expectation1.fulfill() }
    operation2.addCompletionBlock { expectation2.fulfill() }
    operation3.addCompletionBlock { expectation3.fulfill() }
    operation4.addCompletionBlock { expectation4.fulfill() }

    operation1.addCondition(NegatedCondition(condition: NoFailedDependenciesCondition()))
    [operation4, operation3, operation2].then(operation1)
    queue.addOperations([operation1, operation2, operation3, operation4], waitUntilFinished: false)
    waitForExpectations(timeout: 5)
    XCTAssertFalse(operation1.failed)
  }

}
