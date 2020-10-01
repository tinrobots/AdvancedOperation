// AdvancedOperation

import Foundation

/// An `AsynchronousOperation` subclass which enables a finite grouping of other operations.
/// Use a `GroupOperation` to associate related operations together, thereby creating higher levels of abstractions.
open class GroupOperation: AsynchronousOperation {
  // MARK: - Public Properties

  /// The maximum number of queued operations that can execute at the same time inside the `GroupOperation`.
  ///
  /// The value in this property affects only the operations that the current GroupOperation has executing at the same time.
  /// Reducing the number of concurrent operations does not affect any operations that are currently executing.
  public var maxConcurrentOperationCount: Int {
    get { operationQueue.maxConcurrentOperationCount }
    set { operationQueue.maxConcurrentOperationCount = newValue }
  }

  /// The relative amount of importance for granting system resources to the operation.
  public override var qualityOfService: QualityOfService {
    get { operationQueue.qualityOfService }
    set {
      super.qualityOfService = newValue
      operationQueue.qualityOfService = newValue
    }
  }

  // MARK: - Private Properties

  private let dispatchGroup = DispatchGroup()
  private let dispatchQueue = DispatchQueue(label: "\(identifier).GroupOperation.serialQueue")
  private var tokens = [NSKeyValueObservation]()
  private lazy var operationQueue: OperationQueue = {
    $0.isSuspended = true
    return $0
  }(OperationQueue())

  // MARK: - Initializers

  /// Creates a new `GroupOperation`.
  /// - Parameters:
  ///   - underlyingQueue: The dispatch queue used to execute operations (the default value is nil).
  ///   - operations: Operations to be executed by the `GroupOperation`
  public init(underlyingQueue: DispatchQueue? = nil, operations: [Operation]) {
    super.init()
    self.operationQueue.underlyingQueue = underlyingQueue
    operations.forEach { addOperation($0) }
  }

  /// Creates a new `GroupOperation`.
  /// - Parameters:
  ///   - underlyingQueue: The dispatch queue used to execute operations (the default value is nil).
  ///   - operations: Operations to be executed by the `GroupOperation`
  public convenience init(underlyingQueue: DispatchQueue? = nil, operations: Operation...) {
    self.init(underlyingQueue: underlyingQueue, operations: operations)
  }

  deinit {
    tokens.forEach { $0.invalidate() }
    tokens.removeAll()
  }

  // MARK: - Public Methods

  ///  The default implementation of this method executes the scheduled operations.
  ///  If you override this method to perform the desired task,  invoke super in your implementation as last statement.
  ///  This method will automatically execute within an autorelease pool provided by Operation, so you do not need to create your own autorelease pool block in your implementation.
  public final override func main() {
    if #available(iOS 13.0, iOSApplicationExtension 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *) {
      progress.addChild(operationQueue.progress, withPendingUnitCount: 1)
    }

    guard !isCancelled else {
      self.finish()
      return
    }

    // Debug only: count how many tasks have entered the dispatchGroup
    // let entersCount = dispatchGroup.debugDescription
    // .components(separatedBy: ",").filter({$0.contains("count")}).first?
    // .components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap{Int($0)}.first

    // 1. configuration started: enter the group
    // Without entering the group here, the notify block could be called before firing the queue if no operations were added.
    dispatchGroup.enter()
    // 2. setup the completion block to be called when all the operations are finished
    dispatchGroup.notify(queue: dispatchQueue) { [weak self] in
      self?.operationQueue.isSuspended = true
      self?.finish()
    }
    // 3. start running the operations
    operationQueue.isSuspended = false
    // 4. configuration finished: leave the group
    dispatchGroup.leave()
  }

  public final override func cancel() {
    dispatchQueue.sync {
      super.cancel()
      operationQueue.cancelAllOperations()
      // If the GroupOperation gets cancelled before being executed, the underlying operation queue is still suspended
      // and the operations will be cancelled without having a chance to finish.
    }
  }

  /// Adds new `operations` to the `GroupOperation`.
  ///
  /// If the `GroupOperation` is already cancelled,  the new  operations will be cancelled before being added.
  /// If the `GroupOperation` is finished, new operations will be ignored.
  public func addOperations(_ operations: Operation...) {
    dispatchQueue.sync {
      guard !isFinished else { return }

      operations.forEach { operation in
        // 1. observe when the operation finishes
        dispatchGroup.enter()
        let finishToken = operation.observe(\.isFinished, options: [.old, .new]) { [weak self] (_, changes) in
          guard let self = self else { return }
          guard
            let oldValue = changes.oldValue,
            let newValue = changes.newValue,
            oldValue != newValue, newValue
          else { return }

          self.dispatchGroup.leave()
        }
        tokens.append(finishToken)

        // If the GroupOperation is cancelled, operations will be cancelled before being added to the queue.
        if isCancelled {
          operation.cancel()
        } else {
          // 2. observe when the operation gets cancelled if it's not cancelled yet
          let cancelToken = operation.observe(\.isCancelled, options: [.old, .new]) { [weak self] (operation, changes) in
            guard let self = self else { return }
            guard let oldValue = changes.oldValue, let newValue = changes.newValue, oldValue != newValue, newValue else { return }

            if #available(iOS 13.0, iOSApplicationExtension 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *) {
              // if the cancelled operation is executing, the queue progress will be updated when the operation finishes
              if !operation.isExecuting && self.operationQueue.progress.totalUnitCount > 0 {
                self.operationQueue.progress.totalUnitCount -= 1
              }
            }
          }
          tokens.append(cancelToken)

          // the progress totalUnitCount is increased by 1 only if the operation is not cancelled
          if #available(iOS 13.0, iOSApplicationExtension 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *) {
            operationQueue.progress.totalUnitCount += 1
          }
        }

        operationQueue.addOperation(operation)
      }
    }
  }

  /// Adds a new `operation` to the `GroupOperation`.
  ///
  /// If the `GroupOperation` is already cancelled,  the new  operation will be cancelled before being added.
  /// If the `GroupOperation` is finished, the new operation will be ignored.
  public final func addOperation(_ operation: Operation) {
    addOperations(operation)
  }
}
