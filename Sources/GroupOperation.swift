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
import os.log

open class GroupOperation: AdvancedOperation {

  // MARK: - Public Properties

  /// ExclusivityManager used by `AdvancedOperationQueue`.
  public let exclusivityManager: ExclusivityManager

  // MARK: - Private Properties

  /// Internal `AdvancedOperationQueue`.
  private let underlyingOperationQueue = AdvancedOperationQueue() // TODO remove exclusivity manager

  /// Internal starting operation.
  private lazy var startingOperation = BlockOperation { }

  /// Internal finishing operation.
  private lazy var finishingOperation = BlockOperation { }

  private let lock = NSLock()

  private var _temporaryCancelErrors = [Error]()

  /// Holds the cancellation error.
  private var temporaryCancelErrors: [Error] {
    get {
      return lock.synchronized { _temporaryCancelErrors }
    }
    set {
      lock.synchronized {
        _temporaryCancelErrors = newValue
      }
    }
  }

  private var _aggregatedErrors = [Error]()

  /// Stores all of the `AdvancedOperation` errors during the execution.
  internal var aggregatedErrors: [Error] {
    get {
      return lock.synchronized { _aggregatedErrors }
    }
    set {
      lock.synchronized {
        _aggregatedErrors = newValue
      }
    }
  }

  public override func useOSLog(_ log: OSLog) {
    super.useOSLog(log) //TODO improve this for addOperation
    underlyingOperationQueue.operations.forEach { operation in
      if let advancedOperation = operation as? AdvancedOperation {
        advancedOperation.useOSLog(log)
      }
    }
  }

  // MARK: - Initialization

  /// Creates a `GroupOperation`instance.
  ///
  /// - Parameters:
  ///   - operations: The operations of which the `GroupOperation` is composed of.
  ///   - exclusivityManager: An instance of `ExclusivityManager`.
  ///   - underlyingQueue: An optional DispatchQueue which defaults to nil, this parameter is set as the underlying queue of the group's own `AdvancedOperationQueue`.
  public convenience init(operations: Operation..., exclusivityManager: ExclusivityManager = .sharedInstance, underlyingQueue: DispatchQueue? = .none) {
    self.init(operations: operations, exclusivityManager: exclusivityManager, underlyingQueue: underlyingQueue)
  }

  /// Creates a `GroupOperation`instance.
  ///
  /// - Parameters:
  ///   - operations: The operations of which the `GroupOperation` is composed of.
  ///   - exclusivityManager: An instance of `ExclusivityManager`.
  ///   - underlyingQueue: An optional DispatchQueue which defaults to nil, this parameter is set as the underlying queue of the group's own `AdvancedOperationQueue`.
  public init(operations: [Operation], exclusivityManager: ExclusivityManager = .sharedInstance, underlyingQueue: DispatchQueue? = .none) {
    self.exclusivityManager = exclusivityManager

    super.init()

    self.underlyingOperationQueue.isSuspended = true
    self.underlyingOperationQueue.delegate = self
    self.underlyingOperationQueue.underlyingQueue = underlyingQueue

    self.startingOperation.name = "Star<\(operationName)>"
    self.underlyingOperationQueue.addOperation(startingOperation)

    self.finishingOperation.name = "End<\(operationName)>"
    self.finishingOperation.addDependency(startingOperation)
    self.underlyingOperationQueue.addOperation(finishingOperation)

    for operation in operations {
      addOperation(operation: operation)
    }
  }

  private var _cancellationTriggered = false

  /// Advises the `GroupOperation` object that it should stop executing its tasks.
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

    for operation in underlyingOperationQueue.operations where operation !== finishingOperation && operation !== startingOperation && !operation.isFinished && !operation.isCancelled {
      operation.cancel()
    }

    // TODO
    // find opeartion not executing, reverse the order (hoping that they are enqueue in a serial way) --> cancel
    // find operation executing, reverse the order -> cancel and wait

    /// once all the operations will be cancelled and then finished, the finishing operation will be called

    if !isExecuting && !isFinished {
      // if it's ready or pending (waiting for depedencies)
      queueSuspendLock.synchronized {
        underlyingOperationQueue.isSuspended = false
      }
    }

  }

  open override func cancel() {
    cancel(errors: [])
  }

  /// Performs the receiver’s non-concurrent task.
  /// - Note: If overridden, be sure to call the parent `main` as the **end** of the new implementation.
  open override func main() {
    // if it's cancelling, the finish command we be called automatically
    if lock.synchronized({ _cancellationTriggered }) && !isCancelled {
      return
    }

    if isCancelled {
      finish()
      return
    }

    queueSuspendLock.synchronized {
      if !_suspended {
        underlyingOperationQueue.isSuspended = false
      }
    }
  }

  open override func finish(errors: [Error] = []) {
    queueSuspendLock.synchronized {
      underlyingOperationQueue.isSuspended = true
    }
    super.finish(errors: errors)
  }

  public func addOperation(operation: Operation) {
    assert(!finishingOperation.isCancelled || !finishingOperation.isFinished, "The GroupOperation is finishing and cannot accept more operations.")

    finishingOperation.addDependency(operation)
    operation.addDependency(startingOperation)
    underlyingOperationQueue.addOperation(operation)
  }

  /// The maximum number of queued operations that can execute at the same time.
  /// - Note: Reducing the number of concurrent operations does not affect any operations that are currently executing.
  public final var maxConcurrentOperationCount: Int {
    get {
      return queueSuspendLock.synchronized { underlyingOperationQueue.maxConcurrentOperationCount }
    }
    set {
      queueSuspendLock.synchronized {
        underlyingOperationQueue.maxConcurrentOperationCount = newValue
      }
    }
  }

  /// Lock to manage the underlyingOperationQueue isSuspended property.
  private let queueSuspendLock = NSLock() //TODO rename or use different lock for different properties

  private var _suspended = false

  /// A Boolean value indicating whether the GroupOpeation is actively scheduling operations for execution.
  public final var isSuspended: Bool {
    get {
      return queueSuspendLock.synchronized { _suspended }
    }
    set {
      queueSuspendLock.synchronized {
        underlyingOperationQueue.isSuspended = newValue
        _suspended = newValue
      }
    }
  }

  /// Accesses the group operation queue's quality of service. It defaults to background quality.
  public final override var qualityOfService: QualityOfService {
    get {
      return queueSuspendLock.synchronized { underlyingOperationQueue.qualityOfService }
    }
    set(value) {
      queueSuspendLock.synchronized { underlyingOperationQueue.qualityOfService = value }
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
      assertionFailure("There shouldn't be Operations but only AdvancedOperations in this delegate implementation call.")
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

    if operation === finishingOperation {
      let allOperationsCancelled = lock.synchronized { _cancellationTriggered }
      if allOperationsCancelled {
        super.cancel(errors: temporaryCancelErrors)
        finish()
      } else {
        finish(errors: self.aggregatedErrors)
    }
  }
  }

  public func operationQueue(operationQueue: AdvancedOperationQueue, operationWillCancel operation: AdvancedOperation, withErrors errors: [Error]) { }

  public func operationQueue(operationQueue: AdvancedOperationQueue, operationDidCancel operation: AdvancedOperation, withErrors errors: [Error]) { }

}
