// AdvancedOperation

import XCTest
@testable import AdvancedOperation

final class GroupOperationTests: XCTestCase {
  override class func setUp() {
    #if swift(<5.1)
    AdvancedOperation.KVOCrashWorkaround.installFix()
    #endif
  }

  func testSuccessfulExecution() {
    let operation1 = SleepyAsyncOperation()
    let operation2 = SleepyAsyncOperation()
    let operation3 = SleepyAsyncOperation()
    let groupOperation = GroupOperation(operations: [operation1, operation2, operation3])
    groupOperation.qualityOfService = .userInitiated

    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: groupOperation, expectedValue: true)
    groupOperation.start()
    wait(for: [expectation1], timeout: 5)
    XCTAssertTrue(operation1.isFinished)
    XCTAssertTrue(operation2.isFinished)
    XCTAssertTrue(operation3.isFinished)
    XCTAssertEqual(groupOperation.qualityOfService, .userInitiated)
  }

  func testAddingOperationAfterExecution() {
    let groupOperation = GroupOperation(operations: [])
    let operation = BlockOperation {
      XCTFail("It shouldn't be executed because GroupOperation is already finished at this point")
    }

    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: groupOperation, expectedValue: true)
    let expectation2 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation, expectedValue: true)
    expectation2.isInverted = true
    groupOperation.start()
    wait(for: [expectation1], timeout: 5)
    groupOperation.addOperation(operation)
    wait(for: [expectation2], timeout: 5)
  }

  func testExecutionWithNestedGroupOperation() {
    let operation1 = SleepyAsyncOperation()
    let operation2 = SleepyAsyncOperation()
    let operation3 = SleepyAsyncOperation()
    let operation4 = SleepyAsyncOperation()

    let groupOperation1 = GroupOperation(operations: [operation1, operation2])
    let groupOperation2 = GroupOperation(operations: [operation3, operation4])
    let groupOperation3 = GroupOperation(operations: [groupOperation1, groupOperation2])
    groupOperation3.qualityOfService = .userInitiated

    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: groupOperation3, expectedValue: true)
    groupOperation3.start()
    wait(for: [expectation1], timeout: 5)
    XCTAssertTrue(operation1.isFinished)
    XCTAssertTrue(operation2.isFinished)
    XCTAssertTrue(operation3.isFinished)
    XCTAssertTrue(operation4.isFinished)
  }

  func testSuccessfulExecutionWithMaxConcurrentOperationCountToOne() {
    let operation1 = SleepyAsyncOperation(interval1: 1, interval2: 0, interval3: 0)
    let operation2 = SleepyAsyncOperation(interval1: 1, interval2: 0, interval3: 0)
    let operation3 = BlockOperation()

    let groupOperation = GroupOperation(operations: [operation1, operation2, operation3])
    groupOperation.maxConcurrentOperationCount = 1

    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: groupOperation, expectedValue: true)
    groupOperation.start()
    wait(for: [expectation1], timeout: 15)
    XCTAssertTrue(operation1.isFinished)
    XCTAssertTrue(operation2.isFinished)
    XCTAssertTrue(operation3.isFinished)
    XCTAssertEqual(groupOperation.maxConcurrentOperationCount, 1)
  }

  func testCancelledExecution() {
    let operation1 = RunUntilCancelledAsyncOperation()
    let operation2 = SleepyAsyncOperation()
    let operation3 = SleepyAsyncOperation()

    let groupOperation = GroupOperation(operations: [operation1, operation2, operation3])
    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: groupOperation, expectedValue: true)
    groupOperation.start()
    groupOperation.cancel()
    wait(for: [expectation1], timeout: 5)
  }

  func testAddingOperationWhileGroupOperationIsBeingCancelled() {
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

    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: groupOperation, expectedValue: true)
    let expectation2 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation4, expectedValue: true)
    groupOperation.start()
    wait(for: [expectation1, expectation2], timeout: 5)
  }

  func testCancelledExecutionBeforeStarting() {
    let operation1 = SleepyAsyncOperation()
    let operation2 = SleepyAsyncOperation()
    let operation3 = SleepyAsyncOperation()

    let groupOperation = GroupOperation(operations: [operation1, operation2, operation3])
    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: groupOperation, expectedValue: true)
    groupOperation.cancel()
    groupOperation.start()
    wait(for: [expectation1], timeout: 5)
  }

  func testExecutionOnOperationQueue() {
    let queue = OperationQueue()
    let operation1 = SleepyAsyncOperation()
    let operation2 = SleepyAsyncOperation()
    let operation3 = SleepyAsyncOperation()

    let groupOperation = GroupOperation(operations: [operation1, operation2, operation3])
    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: groupOperation, expectedValue: true)
    queue.addOperation(groupOperation)
    wait(for: [expectation1], timeout: 5)
  }

  func testExecutionOnDispatchQueue() {
    let queue = OperationQueue()
    let dispatchQueue = DispatchQueue(label: "\(#function)")
    let operation = BlockOperation {
      dispatchPrecondition(condition: .onQueue(dispatchQueue))
    }

    let groupOperation = GroupOperation.init(underlyingQueue: dispatchQueue, operations: operation)
    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: groupOperation, expectedValue: true)
    queue.addOperation(groupOperation)
    wait(for: [expectation1], timeout: 5)
  }

  func testCancelledExecutionOnOperationQueue() {
    let queue = OperationQueue()
    let operation1 = SleepyAsyncOperation()
    let operation2 = SleepyAsyncOperation()
    let operation3 = SleepyAsyncOperation()
    let groupOperation = GroupOperation(operations: [operation1, operation2, operation3])
    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: groupOperation, expectedValue: true)
    groupOperation.cancel()
    queue.addOperation(groupOperation)
    wait(for: [expectation1], timeout: 5)
  }

  func testCustomGroupOperationWithInputAndOutput() {
    let queue = OperationQueue()
    let groupOperation = IOGroupOperation(input: 10)
    let groupOperation2 = IOGroupOperation()
    groupOperation2.input = 11
    let outputExepectation = expectation(description: "Output Produced")
    outputExepectation.expectedFulfillmentCount = 2
    groupOperation.onOutputProduced = { output in
      XCTAssertEqual(output, 10)
      outputExepectation.fulfill()
    }
    groupOperation2.onOutputProduced = { output in
      XCTAssertEqual(output, 11)
      outputExepectation.fulfill()
    }
    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: groupOperation, expectedValue: true)
    let expectation2 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: groupOperation2, expectedValue: true)
    queue.addOperations([groupOperation, groupOperation2], waitUntilFinished: false)
    wait(for: [expectation1, expectation2, outputExepectation], timeout: 5)
    XCTAssertEqual(groupOperation.output, 10)
    XCTAssertEqual(groupOperation2.output, 11)
  }

  func testAddingOperationWhileExecuting() {
    let operation = BlockOperation {}
    let queue = OperationQueue()
    let group = ProducerGroupOperation { return operation }
    let expectation1 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: group, expectedValue: true)
    let expectation2 = XCTKVOExpectation(keyPath: #keyPath(Operation.isFinished), object: operation, expectedValue: true)
    queue.addOperation(group)
    wait(for: [expectation1, expectation2], timeout: 5)
  }
}
