//
//  Continuation.swift
//
//
//  Created by Stuart A. Malone on 11/29/23.
//

import Foundation

// Used checked continuations for safety in debug mode,
// and unsafe continuations for speed in release mode.

#if DEBUG
typealias Continuation = CheckedContinuation

@inlinable func withContinuation<T>(function: String = #function,
                                    _ body: (CheckedContinuation<T, Never>) -> Void) async -> T
{
    await withCheckedContinuation(function: function, body)
}

@inlinable func withThrowingContinuation<T>(function: String = #function,
                                            _ body: (CheckedContinuation<T, Error>) -> Void) async throws -> T
{
    try await withCheckedThrowingContinuation(function: function, body)
}
#else
typealias Continuation = UnsafeContinuation

@inlinable func withContinuation<T>(_ body: @escaping (UnsafeContinuation<T, Never>) -> Void) async -> T {
    return await withUnsafeContinuation { continuation in
        body(continuation)
    }
}

@inlinable func withThrowingContinuation<T>(_ body: @escaping (UnsafeContinuation<T, Error>) -> Void) async throws -> T {
    return try await withUnsafeThrowingContinuation { continuation in
        body(continuation)
    }
}
#endif

/// A Continuation with a timeout. The continuation will either resume with
/// the value passed to `resume(returning:)`, or with the provided
/// error after the timeout expires.
actor TimedContinuation<T> {
    init(continuation: Continuation<T, Error>,
         error timeoutError: Error,
         timeout: Duration,
         tolerance: Duration? = nil) async {
        self.continuation = continuation
        timeoutTask = Task {
            do {
                try await Task.sleep(for: timeout, tolerance: tolerance)
                self.resume(throwing: timeoutError)
            } catch {
                self.resume(throwing: error)
            }
        }
    }

    var continuation: Continuation<T, Error>?
    var timeoutTask: Task<Void, Error>?

    func resume(throwing error: Error) {
        guard let continuation else { return }
        continuation.resume(throwing: error)
        self.continuation = nil
        cancelTimeout()
    }

    func resume(returning value: T) {
        guard let continuation else { return }
        continuation.resume(returning: value)
        self.continuation = nil
        cancelTimeout()
    }

    private func cancelTimeout() {
        guard let timeoutTask else { return }
        timeoutTask.cancel()
        self.timeoutTask = nil
    }
}
