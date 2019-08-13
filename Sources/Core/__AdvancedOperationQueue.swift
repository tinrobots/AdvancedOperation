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

/// `AdvancedOperationQueue` is an `OperationQueue` subclass that implements "extra features" related to the `AdvancedOperation` class.
//open class AdvancedOperationQueue: OperationQueue {
//  /// Keeps track of every mutual exclusivity conditions defined in the operations running on this queue.
//  internal lazy var exclusivityManager: ExclusivityManager = {
//    let qos: DispatchQoS
//    
//    switch self.qualityOfService {
//    case .userInteractive:
//      qos = .userInteractive
//    case .userInitiated:
//      qos = .userInitiated
//    case .utility:
//      qos = .utility
//    case .background:
//      qos = .background
//    case .`default`:
//      qos = .default
//    @unknown default:
//      qos = .default
//    }
//    
//    let manager = ExclusivityManager(qos: qos)
//    
//    return manager
//  }()
//  
//  private let lock = UnfairLock()
//  
//  open override func addOperation(_ operation: Operation) {
//    lock.synchronized {
//      let preparedOperations = prepareOperation(operation)
//      
//      preparedOperations.forEach {
//        super.addOperation($0)
//      }
//    }
//  }
//  
//  open override func addOperations(_ operations: [Operation], waitUntilFinished wait: Bool) {
//    lock.synchronized {
//      var preparedOperations = [Operation]()
//      operations.forEach {
//        preparedOperations.append(contentsOf: prepareOperation($0))
//      }
//      super.addOperations(preparedOperations, waitUntilFinished: wait)
//    }
//  }
//}
//
//extension AdvancedOperationQueue {
//  /// Adds Conditions and ExclusivityManager features support.
//  /// Returns the passed operation with a list of related operations to support all the available features.
//  private func prepareOperation(_ operation: Operation) -> [Operation] {
//    var operations = [Operation]()
//    
//    // swiftlint:disable:next cyclomatic_complexity
//    func decorateOperation(_ operation: Operation) {
//      if let operation = operation as? AdvancedOperation { /// AdvancedOperation
////        if let evaluator = operation.makeConditionsEvaluator() {
////          decorateOperation(evaluator)
////        }
////        
////        for mutualExclusivityCondition in operation.conditions.compactMap ({ $0 as? MutualExclusivityCondition }) {
////          switch mutualExclusivityCondition.mode {
////          case .cancel(identifier: let identifier):
////            self.exclusivityManager.addOperation(operation, category: identifier, cancellable: true)
////          case .enqueue(identifier: let identifier):
////            self.exclusivityManager.addOperation(operation, category: identifier, cancellable: false)
////          }
////        }
//      }
//      operations.append(operation)
//    }
//    
//    decorateOperation(operation)
//    return operations
//  }
//}