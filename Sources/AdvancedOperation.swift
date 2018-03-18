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

public class AdvancedOperation: Operation {

  // MARK: - State

  public final override var isReady: Bool {
    switch state {

    case .pending:
      if isCancelled {
        return false // TODO: or should be true?
      }

      if super.isReady {
        evaluateConditions()
        return false
      }

      return false // Until conditions have been evaluated

    case .ready:
      return super.isReady

    default:
      return false
    }

  }

  public final override var isExecuting: Bool { return state == .executing }

  public final override var isFinished: Bool { return state == .finished }

// MARK: - OperationState

  @objc
  internal enum OperationState: Int, CustomDebugStringConvertible {

    case ready
    case pending
    case evaluatingConditions
    case executing
    case finished

    func canTransition(to state: OperationState) -> Bool {
      switch (self, state) {
      case (.ready, .executing):
        return true
      case (.ready, .pending):
        return true
      case (.ready, .finished): // early bailing out
        return true
      case (.pending, .evaluatingConditions):
        return true
      case (.evaluatingConditions, .ready):
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
      case .pending:
        return "pending"
      case .evaluatingConditions:
        return "evaluatingConditions"
      case .executing:
        return "executing"
      case .finished:
        return "finished"
      }
    }

  }

  // MARK: - Properties

  /// Returns `true` if the `AdvancedOperation` failed due to errors.
  public var failed: Bool {
    return errors.count > 0
  }

  /// Concurrent queue for synchronizing access to `state`.
  private let stateQueue = DispatchQueue(label: "org.tinrobots.AdvancedOperation.state", attributes: .concurrent)

  /// Private backing stored property for `state`.
  private var _state: OperationState = .ready

  /// The state of the operation
  @objc dynamic
  internal var state: OperationState {
    get { return stateQueue.sync { _state } }
    set {
      stateQueue.sync(flags: .barrier) {
        assert(_state.canTransition(to: newValue), "Performing an invalid state transition form \(_state) to \(newValue).")
        _state = newValue
      }

      switch newValue {
      case .executing:
        willExecute()
      case .finished:
        didFinish()
      default:
        break
      }

    }
  }

  public override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
    switch (key) {
    case ObservableKey.isReady, ObservableKey.isExecuting, ObservableKey.isFinished:
      return Set([#keyPath(state)])
    default:
      return super.keyPathsForValuesAffectingValue(forKey: key)
    }
  }

  //  @objc
  //  private dynamic class func keyPathsForValuesAffectingIsReady() -> Set<String> {
  //    return [#keyPath(state)]
  //  }
  //
  //  @objc
  //  private dynamic class func keyPathsForValuesAffectingIsExecuting() -> Set<String> {
  //    return [#keyPath(state)]
  //  }
  //
  //  @objc
  //  private dynamic class func keyPathsForValuesAffectingIsFinished() -> Set<String> {
  //    return [#keyPath(state)]
  //  }

  // MARK: - Conditions

  public private(set) var conditions = [OperationCondition]() //TODO : set?

  // MARK: - Observers

  private(set) var observers = [OperationObservingType]()

  internal var willExecuteObservers: [OperationWillExecuteObserving] {
    return observers.compactMap { $0 as? OperationWillExecuteObserving }
  }

  internal var didCancelObservers: [OperationDidCancelObserving] {
    return observers.compactMap { $0 as? OperationDidCancelObserving }
  }

  internal var didFinishObservers: [OperationDidFinishObserving] {
    return observers.compactMap { $0 as? OperationDidFinishObserving }
  }

  // MARK: - Errors

  public private(set) var errors = [Error]()

  // MARK: - Initialization

  public override init() {
    super.init()
  }

  // MARK: - Methods

  public final override func start() {
    // Bail out early if cancelled or there are some errors.
    guard errors.isEmpty && !isCancelled else {
      finish()
      return
    }

    guard isReady else { return }
    guard !isExecuting else { return }

    state = .executing
    //Thread.detachNewThreadSelector(#selector(main), toTarget: self, with: nil)
    // https://developer.apple.com/library/content/documentation/General/Conceptual/ConcurrencyProgrammingGuide/OperationObjects/OperationObjects.html#//apple_ref/doc/uid/TP40008091-CH101-SW16
    main()
  }

  public override func main() {
    fatalError("\(type(of: self)) must override `main()`.")
  }

  func cancel(error: Error? = nil) {
    guard !isCancelled else { return }

    if let error = error {
      errors.append(error)
    }

    cancel()
  }

  public override func cancel() {
    super.cancel()
    didCancel()
  }

  fileprivate var _finishing = false
  public final func finish(errors: [Error] = []) {
    guard !_finishing else { return }
    _finishing = true

    self.errors.append(contentsOf: errors)

    state = .finished
  }

  // MARK: - Add Condition

  // Indicate to the operation that it can proceed with evaluating conditions.
  internal func willEnqueue() {
    state = .pending
  }

  public func addCondition(condition: OperationCondition) {
    assert(state == .ready || state == .pending, "Cannot add conditions after the evaluation (or execution) has begun.") // TODO: better assert

    conditions.append(condition)
  }

  private func evaluateConditions() {
    assert(state == .pending, "Cannot evaluate conditions in this state: \(state)")

    state = .evaluatingConditions

    OperationConditionEvaluator.evaluate(conditions, operation: self) { [weak self] errors in
      self?.errors.append(contentsOf: errors)
      self?.state = .ready
    }
  }

  // MARK: - Observer

  /// Add an observer to the to the operation, can only be done prior to the operation starting.
  ///
  /// - Parameter observer: the observer to add.
  /// - Requires: `self must not have started.
  public func addObserver(observer: OperationObservingType) {
    assert(!isExecuting, "Cannot modify observers after execution has begun.")

    observers.append(observer)
  }

  private func willExecute() {
    for observer in willExecuteObservers {
      observer.operationWillExecute(operation: self)
    }
  }

  private func didFinish() {
    for observer in didFinishObservers {
      observer.operationDidFinish(operation: self, withErrors: errors)
    }
  }

  private func didCancel() {
    for observer in didCancelObservers {
      observer.operationDidCancel(operation: self, withErrors: errors)
    }
  }

  // MARK: - Dependencies

  override public func addDependency(_ operation: Operation) {
    assert(!isExecuting, "Dependencies cannot be modified after execution has begun.")

    super.addDependency(operation)
  }

}

// MARK: - Condition Evaluator

private struct OperationConditionEvaluator {
  private init() {}

  static func evaluate(_ conditions: [OperationCondition], operation: AdvancedOperation, completion: @escaping ([Error]) -> Void) {
    let conditionGroup = DispatchGroup()
    var results = [OperationConditionResult?](repeating: nil, count: conditions.count)

    for (index, condition) in conditions.enumerated() {
      conditionGroup.enter()
      condition.evaluate(for: operation) { result in
        results[index] = result
        conditionGroup.leave()
      }
    }

    conditionGroup.notify(queue: DispatchQueue.global()) {
      var failures = results.compactMap { $0?.error }

      if operation.isCancelled {
        failures.append(contentsOf: operation.errors) //TODO better error
      }
      completion(failures)
    }
  }
  
}

