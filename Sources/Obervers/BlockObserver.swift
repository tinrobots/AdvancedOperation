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

/// The `BlockObserver` is a way to attach arbitrary blocks to significant events in an `Operation`'s lifecycle.
public class BlockObserver: OperationObserving {

  // MARK: - Properties

  private let willExecuteHandler: ((AdvancedOperation) -> Void)?
  private let willFinishHandler: ((AdvancedOperation, [Error]) -> Void)?
  private let didFinishHandler: ((AdvancedOperation, [Error]) -> Void)?
  private let willCancelHandler: ((AdvancedOperation, [Error]) -> Void)?
  private let didCancelHandler: ((AdvancedOperation, [Error]) -> Void)?
  private let didProduceOperationHandler: ((Operation, Operation) -> Void)?
  private let didFailConditionsEvaluationsHandler: ((AdvancedOperation, [Error]) -> Void)?

  public init (willExecute: ((AdvancedOperation) -> Void)? = nil,
               didProduce: ((Operation, Operation) -> Void)? = nil,
               didFailConditionsEvaluations: ((AdvancedOperation, [Error]) -> Void)? = nil,
               willCancel: ((AdvancedOperation, [Error]) -> Void)? = nil,
               didCancel: ((AdvancedOperation, [Error]) -> Void)? = nil,
               willFinish: ((AdvancedOperation, [Error]) -> Void)? = nil,
               didFinish: ((AdvancedOperation, [Error]) -> Void)? = nil) {
    self.willExecuteHandler = willExecute
    self.didProduceOperationHandler = didProduce
    self.didFailConditionsEvaluationsHandler = didFailConditionsEvaluations
    self.willFinishHandler = willFinish
    self.didFinishHandler = didFinish
    self.willCancelHandler = willCancel
    self.didCancelHandler = didCancel
  }

  // MARK: - OperationObserving

  public func operationWillExecute(operation: AdvancedOperation) {
    willExecuteHandler?(operation)
  }

  public func operationWillFinish(operation: AdvancedOperation, withErrors errors: [Error]) {
    willFinishHandler?(operation, errors)
  }

  public func operationDidFinish(operation: AdvancedOperation, withErrors errors: [Error]) {
    didFinishHandler?(operation, errors)
  }

  public func operationWillCancel(operation: AdvancedOperation, withErrors errors: [Error]) {
    willCancelHandler?(operation, errors)
  }

  public func operationDidCancel(operation: AdvancedOperation, withErrors errors: [Error]) {
    didCancelHandler?(operation, errors)
  }

  public func operation(operation: AdvancedOperation, didProduce producedOperation: Operation) {
    didProduceOperationHandler?(operation, producedOperation)
  }

  public func operationDidFailConditionsEvaluations(operation: AdvancedOperation, withErrors errors: [Error]) {
    didFailConditionsEvaluationsHandler?(operation, errors)
  }

}