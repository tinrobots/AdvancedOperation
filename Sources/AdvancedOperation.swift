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

// TODO: cancel conditions evaluation if the operation is cancelled?
// TODO: better move exclusivity manager to the dependencies if any

/// An advanced subclass of `Operation`.
open class AdvancedOperation: Operation {

  // MARK: - State

  public final override var isExecuting: Bool { return state == .executing }
  public final override var isFinished: Bool { return state == .finished }
  public final override var isCancelled: Bool { return stateLock.synchronized { return _cancelled } }

  internal final var isCancelling: Bool { return stateLock.synchronized { return _cancelling } }
  internal final var isFinishing: Bool { return stateLock.synchronized { return _finishing } }

  // MARK: - OperationState

  internal enum OperationState: Int, CustomDebugStringConvertible {

    case ready
    case executing
    case finished

    func canTransition(to state: OperationState) -> Bool {
      switch (self, state) {
      case (.ready, .executing):
        return true
      case (.ready, .finished): // early bailing out
        return true
      case (.executing, .finished):
        return true
      default:
        return false
      }
    }

    var debugDescription: String {
      switch self {
      case .ready:
        return "ready"
      case .executing:
        return "executing"
      case .finished:
        return "finished"
      }
    }

  }

  // MARK: - Properties

  /// Errors generated during the execution.
  public var errors: [Error] { return _errors.all }

  /// An instance of `OSLog` (by default is disabled).
  public private(set) var log = OSLog.disabled

  /// Returns `true` if the `AdvancedOperation` has generated errors during its lifetime.
  public var hasErrors: Bool { return stateLock.synchronized { !errors.isEmpty } }

  /// A lock to guard reads and writes to the `_state` property
  private let stateLock = NSRecursiveLock()

  /// Private backing stored property for `state`.
  private var _state: OperationState = .ready

  /// Returns `true` if the finish command has been fired and the operation is processing it.
  private var _finishing = false

  /// Returns `true` if the `AdvancedOperation` is cancelling.
  private var _cancelling = false

  /// Returns `true` if the `AdvancedOperation` is cancelled.
  private var _cancelled = false

  /// Errors generated during the execution.
  private let _errors = SynchronizedArray<Error>()

  /// The state of the operation.
  internal var state: OperationState {
    get {
      return stateLock.synchronized { _state }
    }
    set {
      stateLock.synchronized {
        assert(_state.canTransition(to: newValue), "Performing an invalid state transition for: \(_state) to: \(newValue).")
        _state = newValue
      }
    }
  }

  // MARK: - Life Cycle

  deinit {
    for dependency in dependencies {
      removeDependency(dependency)
    }
  }

  // MARK: - Observers

  private(set) var observers = SynchronizedArray<OperationObservingType>()

  // MARK: - Execution

  public final override func start() {

    // Do not start if it's finishing or it's finished
    guard !isFinishing || !isFinished else {
      return
    }

    // Bail out early if cancelled or if there are some errors.
    guard !hasErrors && !isCancelled else {
      _cancelled = true // an operation starting with errors should finish as cancelled
      finish() // fires KVO
      return
    }

    let canBeExecuted = stateLock.synchronized { () -> Bool in
      guard _state == .ready else { return false }
      guard _state != .executing else { return false }
      return true
    }

    guard canBeExecuted else { return }

    willChangeValue(forKey: #keyPath(AdvancedOperation.isExecuting))
    state = .executing
    didChangeValue(forKey: #keyPath(AdvancedOperation.isExecuting))

    willExecute()
    main()
  }

  open override func main() {
    fatalError("\(type(of: self)) must override `main()`.")
  }

  open func cancel(errors: [Error]? = .none) {
    _cancel(errors: errors)
  }

  open override func cancel() {
    _cancel()
  }

  private final func _cancel(errors cancelErrors: [Error]? = nil) {
    let canBeCancelled = stateLock.synchronized { () -> Bool in
      guard !_cancelling else { return false }
      guard !_cancelled else { return false }
      guard !_finishing else { return false }
      guard state != .finished else { return false }

      _cancelling = true
      return true
    }

    guard canBeCancelled else { return }

    let localErrors = errors + (cancelErrors ?? [])

    willChangeValue(forKey: #keyPath(AdvancedOperation.isCancelled))
    willCancel(errors: localErrors) // observers

    stateLock.synchronized {
      if let cancelErrors = cancelErrors {
        self._errors.append(contentsOf: cancelErrors)
      }

      _cancelled = true
      _cancelling = false
    }

    didCancel(errors: errors)
    didChangeValue(forKey: #keyPath(AdvancedOperation.isCancelled))

    super.cancel() // fires isReady KVO
  }

  open func finish(errors: [Error] = []) {
    _finish(errors: errors)
  }

  private final func _finish(errors: [Error] = []) {
    let canBeFinished = stateLock.synchronized { () -> Bool in
      guard !_finishing else { return false }
      guard _state != .finished else { return false }

      _finishing = true
      return true
    }

    guard canBeFinished else { return }

    let updatedErrors = stateLock.synchronized { () -> [Error] in
      self._errors.append(contentsOf: errors)
      return self.errors
    }

    willFinish(errors: updatedErrors)
    willChangeValue(forKey: #keyPath(AdvancedOperation.isFinished))
    state = .finished
    didChangeValue(forKey: #keyPath(AdvancedOperation.isFinished))
    didFinish(errors: updatedErrors)
    stateLock.synchronized { _finishing = false }
  }

  // MARK: - Produced Operations

  /// Produce another operation on the same `AdvancedOperationQueue` that this instance is on.
  ///
  /// - Parameter operation: an `Operation` instance.
  final func produceOperation(_ operation: Operation) {
    didProduceOperation(operation)
  }

  // MARK: - Dependencies

  open override func addDependency(_ operation: Operation) {
    assert(!isExecuting, "Dependencies cannot be modified after execution has begun.")

    super.addDependency(operation)
  }

  // MARK: - Conditions

  public private(set) var conditions = [OperationCondition]()

  public func addCondition(_ condition: OperationCondition) {
    assert(state == .ready, "Cannot add conditions if the operation is \(state).")

    conditions.append(condition)
  }

  // MARK: - Subclass

  /// Subclass this method to know when the operation will start executing.
  /// - Note: Calling the `super` implementation will keep the logging messages.
  open func operationWillExecute() {
    os_log("%{public}s has started.", log: log, type: .info, operationName)
  }

  /// Subclass this method to know if the operation has completed the evaluation of its conditions.
  /// - Note: Calling the `super` implementation will keep the logging messages.
  open func operationDidCompleteConditionsEvaluation(errors: [Error]) {
    os_log("%{public}s has completed the conditions evaluation with %{public}d errors.", log: log, type: .info, operationName, errors.count)
  }

  /// Subclass this method to know when the operation has produced another `Operation`.
  /// - Note: Calling the `super` implementation will keep the logging messages.
  open func operationDidProduceOperation(_ operation: Operation) {
    os_log("%{public}s has produced a new operation: %{public}s.", log: log, type: .info, operationName, operation.operationName)
  }

  /// Subclass this method to know when the operation will be cancelled.
  /// - Note: Calling the `super` implementation will keep the logging messages.
  open func operationWillCancel(errors: [Error]) {
    os_log("%{public}s is cancelling.", log: log, type: .info, operationName)
  }

  /// Subclass this method to know when the operation has been cancelled.
  /// - Note: Calling the `super` implementation will keep the logging messages.
  open func operationDidCancel(errors: [Error]) {
    os_log("%{public}s has been cancelled with %{public}d errors.", log: log, type: .info, operationName, errors.count)
  }

  /// Subclass this method to know when the operation will finish its execution.
  /// - Note: Calling the `super` implementation will keep the logging messages.
  open func operationWillFinish(errors: [Error]) {
    os_log("%{public}s is finishing.", log: log, type: .info, operationName)
  }

  /// Subclass this method to know when the operation has finished executing.
  /// - Note: Calling the `super` implementation will keep the logging messages.
  open func operationDidFinish(errors: [Error]) {
    os_log("%{public}s has finished with %{public}d errors.", log: log, type: .info, operationName, errors.count)
  }

  /// Subclass this method to know when the operation will start evaluating its conditions.
  /// - Note: Calling the `super` implementation will keep the logging messages.
  open func operationWillEvaluateConditions() {
    os_log("%{public}s is evaluating %{public}d conditions.", log: log, type: .info, operationName, conditions.count)
  }

}

// MARK: - OSLog

extension AdvancedOperation {

  /// Logs all the states of an `AdvancedOperation`.
  ///
  /// - Parameters:
  ///   - log: A `OSLog` instance.
  ///   - type: A `OSLogType`.
  public func useOSLog(_ log: OSLog) {
    self.log = log
  }

}

// MARK: - Observers

extension AdvancedOperation {
  /// Add an observer to the to the operation, can only be done prior to the operation starting.
  ///
  /// - Parameter observer: the observer to add.
  /// - Requires: `self must not have started.
  public func addObserver(_ observer: OperationObservingType) {
    assert(!isExecuting, "Cannot modify observers after execution has begun.")

    observers.append(observer)
  }

  internal var willExecuteObservers: [OperationWillExecuteObserving] {
    return observers.compactMap { $0 as? OperationWillExecuteObserving }
  }

  internal var didProduceOperationObservers: [OperationDidProduceOperationObserving] {
    return observers.compactMap { $0 as? OperationDidProduceOperationObserving }
  }

  internal var willCancelObservers: [OperationWillCancelObserving] {
    return observers.compactMap { $0 as? OperationWillCancelObserving }
  }

  internal var didCancelObservers: [OperationDidCancelObserving] {
    return observers.compactMap { $0 as? OperationDidCancelObserving }
  }

  internal var willFinishObservers: [OperationWillFinishObserving] {
    return observers.compactMap { $0 as? OperationWillFinishObserving }
  }

  internal var didFinishObservers: [OperationDidFinishObserving] {
    return observers.compactMap { $0 as? OperationDidFinishObserving }
  }

  private func willEvaluateConditions() {
    operationWillEvaluateConditions()
  }

  private func willExecute() {
    operationWillExecute()

    for observer in willExecuteObservers {
      observer.operationWillExecute(operation: self)
    }
  }

  private func didProduceOperation(_ operation: Operation) {
    operationDidProduceOperation(operation)

    for observer in didProduceOperationObservers {
      observer.operation(operation: self, didProduce: operation)
    }
  }

  private func willFinish(errors: [Error]) {
    operationWillFinish(errors: errors)

    for observer in willFinishObservers {
      observer.operationWillFinish(operation: self, withErrors: errors)
    }
  }

  private func didFinish(errors: [Error]) {
    operationDidFinish(errors: errors)

    for observer in didFinishObservers {
      observer.operationDidFinish(operation: self, withErrors: errors)
    }
  }

  private func willCancel(errors: [Error]) {
    operationWillCancel(errors: errors)

    for observer in willCancelObservers {
      observer.operationWillCancel(operation: self, withErrors: errors)
    }
  }

  private func didCancel(errors: [Error]) {
    operationDidCancel(errors: errors)

    for observer in didCancelObservers {
      observer.operationDidCancel(operation: self, withErrors: errors)
    }
  }
}

// MARK: - Condition Evaluation

extension AdvancedOperation {
  internal func evaluateConditions2(exclusivityManager: ExclusivityManager) -> GroupOperation? {
    guard !conditions.isEmpty else {
      return nil
    }

    let evaluator = ConditionEvaluatorOperation(conditions: self.conditions, operation: self, exclusivityManager: exclusivityManager)
    let observer = BlockObserver(willFinish: { [weak self] _, errors in
      if !errors.isEmpty {
        self?.cancel(errors: errors)
      }
      }, didFinish: nil)
    evaluator.addObserver(observer)

    evaluator.useOSLog(log)

    for dependency in dependencies {
      evaluator.addDependency(dependency)
    }
    addDependency(evaluator)

    return evaluator
  }

}

/// Evalutes all the `OperationCondition`: the evaluation fails if it, once finished, contains errors.
internal final class ConditionEvaluatorOperation: GroupOperation {

  init(conditions: [OperationCondition], operation: AdvancedOperation, exclusivityManager: ExclusivityManager) { //TODO: set
    super.init(operations: [])

    conditions.forEach { condition in
      let evaluatingOperation = EvaluateConditionOperation(condition: condition, for: operation)

      if let dependency = condition.dependency(for: operation) {
        evaluatingOperation.addDependency(dependency)
        addOperation(operation: dependency)
      }

      if condition.mutuallyExclusivityMode != .disabled {
        let category = condition.name
        let cancellable = condition.mutuallyExclusivityMode == .cancel
        exclusivityManager.addOperation(operation, category: category, cancellable: cancellable)
      }

      addOperation(operation: evaluatingOperation)
    }

    name = "ConditionEvaluatorOperation<\(operation.operationName)>"
  }

  override func operationWillExecute() {
    os_log("%{public}s has started evaluating the conditions.", log: log, type: .info, operationName)
  }

  override func operationDidFinish(errors: [Error]) {
    os_log("%{public}s has finished evaluating the conditions with %{public}d errors.", log: log, type: .info, operationName, errors.count)
  }

}

/// Operation responsible to evaluate a single `OperationCondition`.
internal final class EvaluateConditionOperation: AdvancedOperation, OperationInputHaving, OperationOutputHaving {

  internal weak var input: AdvancedOperation? = .none
  internal var output: OperationConditionResult? = .none

  let condition: OperationCondition

  internal convenience init(condition: OperationCondition, for operation: AdvancedOperation) {
    self.init(condition: condition)
    self.input = operation
  }

  internal init(condition: OperationCondition) {
    self.condition = condition
    super.init()
    self.name = condition.name
  }

  internal override func main() {
    guard let evaluatedOperation = input else {
      // TODO: add error
      output = OperationConditionResult.failed([])
      finish()
      return
    }

    condition.evaluate(for: evaluatedOperation) { [weak self] result in
      guard let self = self else {
        return
      }

      self.output = result
      let errors = result.errors ?? []
      self.finish(errors: errors)
    }
  }
}
