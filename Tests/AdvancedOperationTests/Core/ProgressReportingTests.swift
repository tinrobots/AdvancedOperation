// AdvancedOperation
//
// https://developer.apple.com/videos/play/wwdc2015/232/

import XCTest
@testable import AdvancedOperation

final class ProgressReportingTests: XCTestCase {

  static var isTestAvailable: Bool {
    if #available(iOS 13.0, iOSApplicationExtension 13.0, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *) {
      return true
    }
    return false
  }

  // MARK: - GroupOperation

  @available(iOS 13.0, iOSApplicationExtension 13.0, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  func testProgressReportingWhenAddingOperationsWhileGroupOperationIsExecuting() throws {
    try XCTSkipIf(!Self.isTestAvailable, "Test unavailable")
    // ⚠️ backwards moving progress scenario.
    //
    // if the queue is serial, the fractionCompleted doesn't surpass 1.0
    // if the queue is concurrent, the fractionCompleted may surpass 1.0
    let currentProgress = Progress(totalUnitCount: 1)
    let groupOperation = GroupOperation()

    let operation1 = BlockOperation { [unowned groupOperation] in
      groupOperation.addOperation(BlockOperation())
      groupOperation.addOperation(BlockOperation())
      groupOperation.addOperation(BlockOperation())
      groupOperation.addOperation(AsyncBlockOperation {
        groupOperation.addOperation(AsyncBlockOperation { $0() })
        groupOperation.addOperation(AsyncBlockOperation { $0() })
        $0() })
    }

    groupOperation.addOperation(operation1)

    currentProgress.addChild(groupOperation.progress, withPendingUnitCount: 1)

    let expectation0 = self.expectation(description: "Progress is completed")
    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: groupOperation, expectedValue: true)
    expectation0.assertForOverFulfill = false
    let token = currentProgress.observe(\.fractionCompleted, options: [.initial, .old, .new]) { (progress, change) in
      print("fraction: \(progress.fractionCompleted)", "-", progress.localizedAdditionalDescription ?? "")

      if progress.completedUnitCount == 1 && progress.fractionCompleted == 1.0 {
        expectation0.fulfill()
      }
    }

    groupOperation.maxConcurrentOperationCount = 1
    groupOperation.start()
    wait(for: [expectation0, expectation1], timeout: 5)
    print(groupOperation.isFinished)
    token.invalidate()
  }

  @available(iOS 13.0, iOSApplicationExtension 13.0, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  func testCancelProgressReport() throws {
    try XCTSkipIf(!Self.isTestAvailable, "Test unavailable")
    let operation = AsyncBlockOperation { $0() }
    let expectation = XCTKVOExpectation(keyPath: #keyPath(Operation.isCancelled), object: operation, expectedValue: true)
    operation.progress.cancel()
    wait(for: [expectation], timeout: 3)
    XCTAssertTrue(operation.progress.isCancelled)
  }

 @available(iOS 13.0, iOSApplicationExtension 13.0, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  func testOperationCancellationShouldSetProgressReportToCancelled() throws {
    try XCTSkipIf(!Self.isTestAvailable, "Test unavailable")
    let operation = AsyncBlockOperation { $0() }
    let expectation = XCTKVOExpectation(keyPath: #keyPath(Operation.isCancelled), object: operation, expectedValue: true)
    operation.cancel()
    wait(for: [expectation], timeout: 3)
    XCTAssertTrue(operation.progress.isCancelled)
  }

 @available(iOS 13.0, iOSApplicationExtension 13.0, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  func testProgressReportingWhenAddingCancelledOperationsToGroupOperation() throws {
    try XCTSkipIf(!Self.isTestAvailable, "Test unavailable")
    let currentProgress = Progress(totalUnitCount: 1)
    let operation1 = AsyncBlockOperation { $0() }
    let operation2 = BlockOperation { }
    let operation3 = BlockOperation { }

    // When added to the GroupOperation, since it's cancelled it won't increase the internal queue progress totalUnitCount
    operation1.cancel()

    let groupOperation = GroupOperation(operations: [operation1, operation2, operation3])

    currentProgress.addChild(groupOperation.progress, withPendingUnitCount: 1)

    let expectation0 = self.expectation(description: "Progress is completed")
    let token = currentProgress.observe(\.fractionCompleted, options: [.initial, .old, .new]) { (progress, change) in
      print("fraction: \(progress.fractionCompleted)", "-", progress.localizedAdditionalDescription ?? "")

      if progress.completedUnitCount == 1 && progress.fractionCompleted == 1.0 {
        expectation0.fulfill()
      }
    }

    groupOperation.maxConcurrentOperationCount = 1
    groupOperation.start()
    wait(for: [expectation0], timeout: 5)
    token.invalidate()
  }
  
  @available(iOS 13.0, iOSApplicationExtension 13.0, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  func testStress() throws {
    try (1...1000).forEach { (i) in
      print(i)
      try testProgressReportingWhenAddingOperationsToGroupOperationWhileIsBeingCancelled()
    }
  }

 @available(iOS 13.0, iOSApplicationExtension 13.0, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  func testProgressReportingWhenAddingOperationsToGroupOperationWhileIsBeingCancelled() throws {
    try XCTSkipIf(!Self.isTestAvailable, "Test unavailable")
    let currentProgress = Progress(totalUnitCount: 1)
    let operation1 = RunUntilCancelledAsyncOperation()
    let operation2 = SleepyAsyncOperation(interval1: 1, interval2: 0, interval3: 0)
    let operation3 = InfiniteAsyncOperation()
    let operation4 = CancelledOperation()

    operation1.name = "op1"
    operation2.name = "op2"
    operation3.name = "op3"
    operation4.name = "op4"

    let groupOperation = GroupOperation(operations: [operation1, operation2, operation3])

    // cancellation is done while at least one operation is running
    operation3.onExecutionStarted = { [unowned groupOperation] in
      groupOperation.cancel()
      groupOperation.addOperation(operation4)
    }

    operation4.completionBlock = { [unowned operation3] in
      operation3.stop()
    }

    let expectation0 = self.expectation(description: "Progress is completed")
    expectation0.assertForOverFulfill = false // groupOperation has a concurrent queue
    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: groupOperation, expectedValue: true)
    let expectation2 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation4, expectedValue: true)

    currentProgress.addChild(groupOperation.progress, withPendingUnitCount: 1)

    let token = currentProgress.observe(\.fractionCompleted, options: [.initial, .old, .new]) { (progress, change) in
      print("fraction: \(progress.fractionCompleted)", "-", progress.localizedAdditionalDescription ?? "")

      if progress.completedUnitCount == 1 && progress.fractionCompleted == 1.0 {
        expectation0.fulfill()
      }
    }

    groupOperation.start()
    wait(for: [expectation0, expectation1, expectation2], timeout: 5)
    token.invalidate()
  }


 @available(iOS 13.0, iOSApplicationExtension 13.0, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  func testProgressReportingOnGroupOperationCancelledBeforeStarting() throws {
    try XCTSkipIf(!Self.isTestAvailable, "Test unavailable")
    let currentProgress = Progress(totalUnitCount: 1)

    let operation1 = AsyncBlockOperation { complete in
      sleep(1)
      complete()
    }

    let operation3 = AsyncBlockOperation { complete in
      sleep(1)
      complete()
    }

    let operation2 = AsyncBlockOperation { complete in
      sleep(1)
      complete()
    }

    let operation4 = BlockOperation { sleep(1) }

    let expectation0 = self.expectation(description: "Progress is completed")
    let groupOperation = GroupOperation(operations: [operation1, operation2, operation3, operation4])

    currentProgress.addChild(groupOperation.progress, withPendingUnitCount: 1)

    let token = currentProgress.observe(\.fractionCompleted, options: [.initial, .old, .new]) { (progress, change) in
      print("fraction: \(progress.fractionCompleted)", "-", progress.localizedAdditionalDescription ?? "")

      if progress.completedUnitCount == 1 && progress.fractionCompleted == 1.0 {
        expectation0.fulfill()
      }
    }

    groupOperation.maxConcurrentOperationCount = 1
    groupOperation.cancel()
    groupOperation.start()
    wait(for: [expectation0], timeout: 3)
    token.invalidate()
  }

 @available(iOS 13.0, iOSApplicationExtension 13.0, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  func testProgressReportingOnGroupOperationHavingAnInternalSerialQueue() throws {
    try XCTSkipIf(!Self.isTestAvailable, "Test unavailable")
    let currentProgress = Progress(totalUnitCount: 1)

    let operation1 = AsyncBlockOperation { complete in
      sleep(1)
      complete()
    }

    let operation3 = AsyncBlockOperation { complete in
      sleep(1)
      complete()
    }

    let operation2 = AsyncBlockOperation { complete in
      sleep(1)
      complete()
    }

    let operation4 = BlockOperation { sleep(1) }

    let expectation0 = self.expectation(description: "Progress is completed")
    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation1, expectedValue: true)
    let expectation2 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation2, expectedValue: true)
    let expectation3 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation3, expectedValue: true)
    let expectation4 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation4, expectedValue: true)

    let groupOperation = GroupOperation(operations: [operation1, operation2, operation3, operation4])

    currentProgress.addChild(groupOperation.progress, withPendingUnitCount: 1)

    let token = currentProgress.observe(\.fractionCompleted, options: [.initial, .old, .new]) { (progress, change) in
      print("fraction: \(progress.fractionCompleted)", "-", progress.localizedAdditionalDescription ?? "")

      if progress.completedUnitCount == 1 && progress.fractionCompleted == 1.0 {
        expectation0.fulfill()
      }
    }

    groupOperation.maxConcurrentOperationCount = 1
    groupOperation.start()
    wait(for: [expectation1, expectation2, expectation3, expectation4, expectation0], timeout: 10)
    token.invalidate()
  }

 @available(iOS 13.0, iOSApplicationExtension 13.0, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  func testProgressReportingOnGroupOperationRunningInAnOperationQueue() throws {
    try XCTSkipIf(!Self.isTestAvailable, "Test unavailable")
    let queue = OperationQueue()
    let currentProgress = Progress(totalUnitCount: 1)
    let sleepTime: UInt32 = 1

    let operation1 = AsyncBlockOperation { complete in
      sleep(sleepTime)
      complete()
    }

    let operation2 = AsyncBlockOperation { complete in
      sleep(sleepTime)
      complete()
    }

    let operation3 = AsyncBlockOperation { complete in
      sleep(sleepTime)
      complete()
    }

    let operation4 = BlockOperation { sleep(sleepTime) }

    operation1.name = "operation1"
    operation2.name = "operation2"
    operation3.name = "operation3"
    operation4.name = "operation4"

    let expectation0 = self.expectation(description: "Progress is completed")
    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation1, expectedValue: true)
    let expectation2 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation2, expectedValue: true)
    let expectation3 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation3, expectedValue: true)
    let expectation4 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation4, expectedValue: true)

    let groupOperation = GroupOperation(operations: [operation1, operation2, operation3, operation4])

    currentProgress.addChild(queue.progress, withPendingUnitCount: 1)

    let token = currentProgress.observe(\.fractionCompleted, options: [.initial, .old, .new]) { (progress, change) in
      print("fraction: \(progress.fractionCompleted)", "-", progress.localizedAdditionalDescription ?? "")

      if progress.completedUnitCount == 1 && progress.fractionCompleted == 1.0 {
        expectation0.fulfill()
      }
    }

    groupOperation.maxConcurrentOperationCount = 1
    queue.progress.totalUnitCount = 1
    queue.addOperation(groupOperation)

    wait(for: [expectation1, expectation2, expectation3, expectation4, expectation0], timeout: 10)
    token.invalidate()
  }

  // MARK: AsyncOperation

 @available(iOS 13.0, iOSApplicationExtension 13.0, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  func testCustomProgressReporting() throws {
    try XCTSkipIf(!Self.isTestAvailable, "Test unavailable")
    let currentProgress = Progress(totalUnitCount: 1)
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    queue.isSuspended = true

    let operation1 = ProgressReportingAsyncOperation()
    let operation2 = ProgressReportingAsyncOperation()

    let expectation0 = self.expectation(description: "Progress is completed")
    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation1, expectedValue: true)
    let expectation2 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation2, expectedValue: true)

    queue.progress.totalUnitCount = 2
    queue.addOperation(operation1)
    queue.addOperation(operation2)

    currentProgress.addChild(queue.progress, withPendingUnitCount: 1)

    var fractions = [Double]()
    let expectedFractions = [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875,  1.0]
    let token = currentProgress.observe(\.fractionCompleted, options: [.initial, .old, .new]) { (progress, change) in
      print("fraction: \(progress.fractionCompleted)", "-", progress.localizedAdditionalDescription ?? "")
      fractions.append(progress.fractionCompleted
      )
      if progress.completedUnitCount == 1 && progress.fractionCompleted == 1.0 {
        expectation0.fulfill()
      }
    }

    queue.isSuspended = false
    wait(for: [expectation1, expectation2, expectation0], timeout: 10)
    XCTAssertEqual(expectedFractions, fractions)
    token.invalidate()
  }

 @available(iOS 13.0, iOSApplicationExtension 13.0, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  func testExplicitProgressUsingSerialQueue() throws {
    try XCTSkipIf(!Self.isTestAvailable, "Test unavailable")
    // AsyncOperation implementation needs to call super.start() in order to enable progress reporting
    // even if the Operation documentation says to not call super.start()
    let currentProgress = Progress(totalUnitCount: 1)
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    queue.isSuspended = true

    // -[NSProgress addChild:withPendingUnitCount:]
    // po ((_NSOperationQueueProgress*)$arg1)->_queue
    // for operation4:
    // po ((NSBlockOperation*)((NSOperationQueue*)((_NSOperationQueueProgress*)$arg1)->_queue).operations[0])

    //    let operation1 = BlockOperation { sleep(1); print("operation 1 executed") }
    //    let operation2 = BlockOperation { sleep(1); print("operation 2 executed") }
    //    let operation3 = BlockOperation { sleep(1); print("operation 3 executed") }

    let operation1 = AsyncBlockOperation { complete in
      sleep(1)
      complete()
    }

    let operation3 = AsyncBlockOperation { complete in
      sleep(1)
      complete()
    }

    let operation2 = AsyncBlockOperation { complete in
      sleep(1)
      // if we cancel an operation we need to be sure to reduce the progress totalUnitCount
      OperationQueue.current?.progress.totalUnitCount -= 1
      operation3.cancel()
      complete()
    }

    let operation4 = BlockOperation { sleep(1); print("operation 4 executed") }

    let expectation0 = self.expectation(description: "Progress is completed")
    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation1, expectedValue: true)
    let expectation2 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation2, expectedValue: true)
    let expectation3 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation3, expectedValue: true)
    let expectation4 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation4, expectedValue: true)

    queue.progress.totalUnitCount = 4
    queue.addOperation(operation1)
    queue.addOperation(operation2)
    queue.addOperation(operation3)
    queue.addOperation(operation4)

    currentProgress.addChild(queue.progress, withPendingUnitCount: 1)

    let token = currentProgress.observe(\.fractionCompleted, options: [.initial, .old, .new]) { (progress, change) in
      print("fraction: \(progress.fractionCompleted)", "-", progress.localizedAdditionalDescription ?? "")

      if progress.completedUnitCount == 1 && progress.fractionCompleted == 1.0 {
        expectation0.fulfill()
      }
    }

    queue.isSuspended = false
    wait(for: [expectation1, expectation2, expectation3, expectation4, expectation0], timeout: 10)
    token.invalidate()
  }

 @available(iOS 13.0, iOSApplicationExtension 13.0, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  func testExplicitProgressWithRsultAndFailableOperationsUsingSerialQueue() throws {
    try XCTSkipIf(!Self.isTestAvailable, "Test unavailable")
    let currentProgress = Progress(totalUnitCount: 1)
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    queue.isSuspended = true

    let operation1 = DummyResultOperation()
    let operation2 = DummyFailableOperation(shouldFail: false)
    let operation3 = DummyFailableOperation(shouldFail: true)
    let operation4 = BlockOperation { }

    let expectation0 = self.expectation(description: "Progress is completed")
    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation1, expectedValue: true)
    let expectation2 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation2, expectedValue: true)
    let expectation3 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation3, expectedValue: true)
    let expectation4 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation4, expectedValue: true)

    queue.progress.totalUnitCount = 4
    queue.addOperation(operation1)
    queue.addOperation(operation2)
    queue.addOperation(operation3)
    queue.addOperation(operation4)

    currentProgress.addChild(queue.progress, withPendingUnitCount: 1)

    let token = currentProgress.observe(\.fractionCompleted, options: [.initial, .old, .new]) { (progress, change) in
      print("fraction: \(progress.fractionCompleted)", "-", progress.localizedAdditionalDescription ?? "")

      if progress.completedUnitCount == 1 && progress.fractionCompleted == 1.0 {
        expectation0.fulfill()
      }
    }

    queue.isSuspended = false
    wait(for: [expectation1, expectation2, expectation3, expectation4, expectation0], timeout: 10)
    token.invalidate()
  }

 @available(iOS 13.0, iOSApplicationExtension 13.0, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  func testImplicitProgressUsingSerialQueue() throws {
    try XCTSkipIf(!Self.isTestAvailable, "Test unavailable")
    let expectation0 = self.expectation(description: "Progress is completed")
    let currentProgress = Progress(totalUnitCount: 1)
    let token = currentProgress.observe(\.fractionCompleted, options: [.initial, .old, .new]) { (progress, change) in
      print("fraction: \(progress.fractionCompleted)", "-", progress.localizedAdditionalDescription ?? "")

      if progress.completedUnitCount == 1 && progress.fractionCompleted == 1.0 {
        expectation0.fulfill()
      }
    }

    // ➡️ the rule of thumb for implicit progress is to call becomeCurrent() and resignCurrent() as closely a possible around the code which you want to track.
    // ➡️ Note: Only the first progress attached to the parent during that window will be tracked; the rest will be ignored.
    currentProgress.becomeCurrent(withPendingUnitCount: 1)
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    queue.isSuspended = true

    let operation1 = AsyncBlockOperation { $0() }
    let operation3 = AsyncBlockOperation { $0() }
    let operation2 = AsyncBlockOperation { $0() }
    // let operation1 = BlockOperation { sleep(1); print("operation 1 executed") }
    // let operation2 = BlockOperation { sleep(1); print("operation 2 executed") }
    // let operation3 = BlockOperation { sleep(1); print("operation 3 executed") }
    let operation4 = BlockOperation { sleep(1); print("operation 4 executed") }

    queue.progress.totalUnitCount = 4
    queue.addOperation(operation1)
    queue.addOperation(operation2)
    queue.addOperation(operation3)
    queue.addOperation(operation4)

    queue.isSuspended = false
    // ➡️ resign immediately when the queue resumes work
    // TODO: It seems that with implicit progress fractionCompleted isn't reported (even using standard BlockOperation)
    currentProgress.resignCurrent()
    wait(for: [expectation0], timeout: 10)
    token.invalidate()
  }
}

