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
import os.log

/// An `AdvancedOperation` subclass which enables a finite grouping of other operations.
/// Use a `GroupOperation` to associate related operations together, thereby creating higher levels of abstractions.
/// - Attention: If you add normal `Operations`, the progress report will ignore them, instead consider using only `AdvancedOperations`.
open class GroupOperation: AdvancedOperation {
  // MARK: - Properties

  public override var log: OSLog {
    didSet {
      underlyingOperationQueue.operations.forEach { operation in
        if let advancedOperation = operation as? AdvancedOperation, advancedOperation !== startingOperation, advancedOperation !== finishingOperation, advancedOperation.log === OSLog.disabled {
          advancedOperation.log = log
        }
      }
    }
  }

  /// Stores all of the `AdvancedOperation` errors during the execution.
  internal private(set) var aggregatedErrors: [Error] {
    get {
      return lock.synchronized { _aggregatedErrors }
    }
    set {
      lock.synchronized {
        _aggregatedErrors = newValue
      }
    }
  }

  private var _aggregatedErrors = [Error]()

  /// Internal `AdvancedOperationQueue`.
  private let underlyingOperationQueue: AdvancedOperationQueue

  /// Internal starting operation.
  private lazy var startingOperation = AdvancedBlockOperation { complete in complete([]) }

  /// Internal finishing operation.
  private lazy var finishingOperation = AdvancedBlockOperation { complete in complete([]) }

  private let lock = UnfairLock()

  private var _temporaryCancelErrors = [Error]()

  private var _cancellationTriggered = false

  /// Holds the cancellation error.
  private var temporaryCancelErrors: [Error] {
    return lock.synchronized { _temporaryCancelErrors }
  }

  // MARK: - Initialization

  /// Creates a `GroupOperation`instance.
  ///
  /// - Parameters:
  ///   - operations: The operations of which the `GroupOperation` is composed of.
  ///   - qualityOfService: The default service level to apply to operations executed using the queue.
  ///   - maxConcurrentOperationCount: The maximum number of queued operations that can execute at the same time.
  ///   - underlyingQueue: An optional DispatchQueue which defaults to nil, this parameter is set as the underlying queue of the group's own `AdvancedOperationQueue`.
  /// - Note: If the operation object has an explicit quality of service level set, that value is used instead.
  public convenience init(
    operations: Operation...,
    qualityOfService: QualityOfService = .default,
    maxConcurrentOperationCount: Int = OperationQueue.defaultMaxConcurrentOperationCount,
    underlyingQueue: DispatchQueue? = .none
    ) {
    self.init(operations: operations,
              qualityOfService: qualityOfService,
              maxConcurrentOperationCount: maxConcurrentOperationCount,
              underlyingQueue: underlyingQueue)
  }

  /// Creates a `GroupOperation`instance.
  ///
  /// - Parameters:
  ///   - operations: The operations of which the `GroupOperation` is composed of.
  ///   - qualityOfService: The default service level to apply to operations executed using the queue.
  ///   - maxConcurrentOperationCount: The maximum number of queued operations that can execute at the same time.
  ///   - underlyingQueue: An optional DispatchQueue which defaults to nil, this parameter is set as the underlying queue of the group's own `AdvancedOperationQueue`.
  /// - Note: If the operation object has an explicit quality of service level set, that value is used instead.
  public init(operations: [Operation],
              qualityOfService: QualityOfService = .default,
              maxConcurrentOperationCount: Int = OperationQueue.defaultMaxConcurrentOperationCount,
              underlyingQueue: DispatchQueue? = .none) {
    let queue = AdvancedOperationQueue()
    queue.underlyingQueue = underlyingQueue
    queue.qualityOfService = qualityOfService
    queue.maxConcurrentOperationCount = maxConcurrentOperationCount
    queue.isSuspended = true

    self.underlyingOperationQueue = queue // TODO: EXC_BAD_ACCESS possible fix

    super.init()

    self.progress.totalUnitCount = 0
    self.underlyingOperationQueue.delegate = self
    self.startingOperation.name = "Start<\(operationName)>"
    self.underlyingOperationQueue.addOperation(startingOperation)
    self.finishingOperation.name = "Finish<\(operationName)>"
    self.finishingOperation.addDependency(startingOperation)
    /// the finishingOperation progress is needed in case the GroupOperation queue is concurrent.
    self.progress.totalUnitCount += 1
    self.progress.addChild(finishingOperation.progress, withPendingUnitCount: 1)
    self.underlyingOperationQueue.addOperation(finishingOperation)

    for operation in operations {
      addOperation(operation: operation)
    }
  }

  deinit {
    self.underlyingOperationQueue.delegate = nil
  }

  /// Advises the `GroupOperation` object that it should stop executing its tasks.
  /// - Note: Once all the tasks are cancelled, the GroupOperation state will be set as finished if it's started.
  public final override func cancel(errors: [Error]) {
    let canBeCancelled = lock.synchronized { () -> Bool in
      if _cancellationTriggered {
        return false
      } else {
        _cancellationTriggered = true
        _temporaryCancelErrors = errors
        return true
      }
    }

    guard canBeCancelled else {
      return
    }

    guard !isCancelled && !isFinished else {
      return
    }

    for operation in underlyingOperationQueue.operations.reversed() where operation !== finishingOperation && operation !== startingOperation && !operation.isFinished && !operation.isCancelled {
      operation.cancel()
    }

    queueLock.synchronized {
      underlyingOperationQueue.isSuspended = false
    }
  }

  open override func cancel() {
    cancel(errors: [])
  }

  /// Performs the receiver’s non-concurrent task.
  /// - Note: If overridden, be sure to call the parent `main` as the **end** of the new implementation.
  open override func main() {
    // if it's cancelling, the finish command will be called automatically
    if lock.synchronized({ _cancellationTriggered }) && !isCancelled {
      return
    }

    if isCancelled {
      finish()
      return
    }

    queueLock.synchronized {
      if !_suspended {
        underlyingOperationQueue.isSuspended = false
      }
    }
  }

  open override func finish(errors: [Error] = []) {
    queueLock.synchronized {
      /// Avoiding pending operations after cancellation using waitUntilAllOperationsAreFinished.
      /// When a GroupOperation is cancelled, the finish method gets called when the finishingOperation is finished,
      /// but there could be cancelled operations still pending to run to move their state to finished.
      underlyingOperationQueue.waitUntilAllOperationsAreFinished()
      underlyingOperationQueue.isSuspended = true
    }
    super.finish(errors: errors)
  }

  /// Add an operation.
  ///
  /// - Parameters:
  ///   - operation: The operation to add.
  ///   - weight: The `AdvancedOperation` weight for the progress report (it defaults to 1).
  ///   - Atention: The progress report ignores normal `Operations`, instead consider using only `AdvancedOperations`.
  public func addOperation(operation: Operation, withProgressWeight weight: Int64 = 1) {
    assert(!isExecuting, "The GroupOperation is executing and cannot accept more operations.")
    assert(!finishingOperation.isCancelled || !finishingOperation.isFinished, "The GroupOperation is finishing and cannot accept more operations.")

    finishingOperation.addDependency(operation)
    operation.addDependency(startingOperation)

    if let advancedOperation = operation as? AdvancedOperation {
      progress.totalUnitCount += weight
      progress.addChild(advancedOperation.progress, withPendingUnitCount: weight)

      if advancedOperation.log === OSLog.disabled {
        advancedOperation.log = log
      }
    }
    underlyingOperationQueue.addOperation(operation)

    //    if let advancedOperation = operation as? AdvancedOperation, advancedOperation.log === OSLog.disabled {
    //      advancedOperation.log = log)
    //    }
  }

  /// The maximum number of queued operations that can execute at the same time.
  /// - Note: Reducing the number of concurrent operations does not affect any operations that are currently executing.
  public final var maxConcurrentOperationCount: Int {
    get {
      return queueLock.synchronized { underlyingOperationQueue.maxConcurrentOperationCount }
    }
    set {
      queueLock.synchronized {
        underlyingOperationQueue.maxConcurrentOperationCount = newValue
      }
    }
  }

  /// Lock to manage the underlyingOperationQueue isSuspended property.
  private let queueLock = UnfairLock()

  private var _suspended = false

  /// A Boolean value indicating whether the GroupOpeation is actively scheduling operations for execution.
  public final var isSuspended: Bool {
    get {
      return queueLock.synchronized { _suspended }
    }
    set {
      queueLock.synchronized {
        underlyingOperationQueue.isSuspended = newValue
        _suspended = newValue
      }
    }
  }

  /// This property specifies the service level applied to operation objects added to the `GroupOperation`. (It defaults to the `default` quality.)
  /// If the operation object has an explicit service level set, that value is used instead.
  public final override var qualityOfService: QualityOfService {
    get {
      return queueLock.synchronized { underlyingOperationQueue.qualityOfService }
    }
    set(value) {
      queueLock.synchronized { underlyingOperationQueue.qualityOfService = value }
    }
  }
}

extension GroupOperation: AdvancedOperationQueueDelegate {
  public func operationQueue(operationQueue: AdvancedOperationQueue, willAddOperation operation: Operation) {
    assert(!finishingOperation.isFinished && !finishingOperation.isExecuting, "The GroupOperation is finished and cannot accept more operations.")

    /// An operation is added to the group or an operation in this group has produced a new operation to execute.

    /// make the finishing operation dependent on this newly-produced operation.
    if operation !== finishingOperation && !operation.dependencies.contains(finishingOperation) {
      finishingOperation.addDependency(operation)
    }

    /// All operations should be dependent on the "startingOperation". This way, we can guarantee that the conditions for other operations
    /// will not evaluate until just before the operation is about to run. Otherwise, the conditions could be evaluated at any time, even
    /// before the internal operation queue is unsuspended.
    if operation !== startingOperation && !operation.dependencies.contains(startingOperation) {
      operation.addDependency(startingOperation)
    }
  }

  public func operationQueue(operationQueue: AdvancedOperationQueue, didAddOperation operation: Operation) { }

  public func operationQueue(operationQueue: AdvancedOperationQueue, operationWillFinish operation: AdvancedOperation, withErrors errors: [Error]) {
    guard operationQueue === underlyingOperationQueue else {
      return
    }

    guard operation !== finishingOperation && operation !== startingOperation else {
      // assertionFailure("There shouldn't be Operations but only AdvancedOperations in this delegate implementation call.")
      return
    }

    if !errors.isEmpty { // avoid TSAN _swiftEmptyArrayStorage
      aggregatedErrors.append(contentsOf: errors)
    }
  }

  public func operationQueue(operationQueue: AdvancedOperationQueue, operationDidFinish operation: Operation, withErrors errors: [Error]) {
    guard operationQueue === underlyingOperationQueue else {
      return
    }

    /// The finishingOperation finishes when all the other operations have been finished.
    /// If some operations have been cancelled but not finished, the finishingOperation will not finish.
    if operation === finishingOperation {
      let cancellation = lock.synchronized { _cancellationTriggered }
      if cancellation {
        super.cancel(errors: temporaryCancelErrors)
        if isExecuting { // sanity check to avoid some rare inconsistencies
          finish()
        }
      } else {
        finish(errors: self.aggregatedErrors)
      }
    }
  }

  public func operationQueue(operationQueue: AdvancedOperationQueue, operationWillCancel operation: AdvancedOperation, withErrors errors: [Error]) { }

  public func operationQueue(operationQueue: AdvancedOperationQueue, operationDidCancel operation: AdvancedOperation, withErrors errors: [Error]) { }
}