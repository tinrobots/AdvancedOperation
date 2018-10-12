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

/// A Condition which will be satisfied if the block returns ´true´.
/// - Note: The block may ´throw´ an error, or return ´false´, both of which are considered as a condition failure.
public struct BlockCondition: OperationCondition {

  /// The block type which returns a Bool.
  public typealias Block = () throws -> Bool

  static var blockConditionKey: String { return "BlockCondition" }

  let block: Block

  public init(block: @escaping Block) {
    self.block = block
  }

  public func evaluate(for operation: AdvancedOperation, completion: @escaping (OperationConditionResult) -> Void) {
    do {
      let result = try block()
      if result {
        completion(.satisfied)
      } else {
        let conditionError = AdvancedOperationError.conditionFailed(message: "The BlockCondition has returned false.",
                                                           userInfo: [operationConditionKey: name])
         completion(.failed([conditionError]))
      }
    } catch {
      let conditionError = AdvancedOperationError.conditionFailed(message: "The BlockCondition has thrown an exception.",
                                                         userInfo: [operationConditionKey: name,
                                                                    type(of: self).blockConditionKey: error])
       completion(.failed([conditionError]))
    }
  }

}