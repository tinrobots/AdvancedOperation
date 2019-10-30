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

/// A Condition which will be satisfied if the block returns a successful result.
/// If the block is not satisfied, the target operation will be cancelled.
/// - Note: The block may ´throw´ an error, or return a failure, both of which are considered as a condition failure.
//public struct BlockCondition: Condition {
//  public typealias Block = (Operation) throws -> Result<Void, Error>
//  private let block: Block
//
//  public init(block: @escaping Block) {
//    self.block = block
//  }
//
//  public func evaluate(for operation: Operation, completion: @escaping (Result<Void, Error>) -> Void) {
//    do {
//      let result = try block(operation)
//      completion(result)
//    } catch {
//      completion(.failure(error))
//    }
//  }
//}
