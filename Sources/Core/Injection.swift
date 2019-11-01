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

public protocol InputConsuming: Operation {
  associatedtype Input
  var input: Input { get set }
}

public protocol OutputProducing: Operation {
  associatedtype Output
  var output: Output { get }
}

extension OutputProducing {
  /// Creates a new operation that passes the output of `self` into the given `Operation`
  ///
  /// - Parameters:
  ///   - operation: The operation that needs the output of `self` to generate an output.
  ///   - requirements: A list of options that the injected input must satisfy.
  /// - Returns: Returns an *adapter* operation which passes the output of `self` into the given `Operation`.
  public func inject<E: InputConsuming>(into operation: E) -> Operation where Output == E.Input {
    let injectionOperation = BlockOperation { [unowned self, unowned operation] in
      operation.input = self.output
    }

    injectionOperation.addDependency(self)
    operation.addDependency(injectionOperation)

    return injectionOperation
  }

  public func inject<E: InputConsuming>(into operation: E, transform: @escaping (Output) -> E.Input) -> Operation {
    let injectionOperation = BlockOperation { [unowned self, unowned operation] in
      operation.input = transform(self.output)
    }

    injectionOperation.addDependency(self)
    operation.addDependency(injectionOperation)

    return injectionOperation
  }
}