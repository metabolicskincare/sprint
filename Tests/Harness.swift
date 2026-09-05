import Foundation

// A very small test harness. The Command Line Tools on this machine don't ship
// XCTest, so rather than depend on a full Xcode install these tests run as a
// plain executable that exits non-zero when anything fails.

struct TestFailure: Error, CustomStringConvertible {
    let message: String
    let file: String
    let line: UInt
    var description: String { "\(message)  (\((file as NSString).lastPathComponent):\(line))" }
}

final class Suite {
    let name: String
    private(set) var tests: [(name: String, body: @MainActor () async throws -> Void)] = []

    init(_ name: String) { self.name = name }

    func test(_ name: String, _ body: @escaping @MainActor () async throws -> Void) {
        tests.append((name, body))
    }
}

// MARK: - Assertions

func expect(_ condition: Bool, _ message: @autoclosure () -> String = "expected true",
            file: String = #file, line: UInt = #line) throws {
    if !condition { throw TestFailure(message: message(), file: file, line: line) }
}

func expectFalse(_ condition: Bool, _ message: @autoclosure () -> String = "expected false",
                 file: String = #file, line: UInt = #line) throws {
    try expect(!condition, message(), file: file, line: line)
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String = "",
                               file: String = #file, line: UInt = #line) throws {
    if actual != expected {
        throw TestFailure(
            message: "\(label.isEmpty ? "" : label + ": ")expected \(expected), got \(actual)",
            file: file, line: line)
    }
}

func expectClose(_ actual: Double, _ expected: Double, tolerance: Double,
                 _ label: String = "", file: String = #file, line: UInt = #line) throws {
    if abs(actual - expected) > tolerance {
        throw TestFailure(
            message: "\(label.isEmpty ? "" : label + ": ")expected \(expected) ± \(tolerance), got \(actual)",
            file: file, line: line)
    }
}

func expectContains(_ haystack: String, _ needle: String,
                    file: String = #file, line: UInt = #line) throws {
    if !haystack.contains(needle) {
        throw TestFailure(message: "expected to find \"\(needle)\" in \"\(haystack)\"", file: file, line: line)
    }
}

func expectNotContains(_ haystack: String, _ needle: String,
                       file: String = #file, line: UInt = #line) throws {
    if haystack.contains(needle) {
        throw TestFailure(message: "did not expect \"\(needle)\" in \"\(haystack)\"", file: file, line: line)
    }
}

func expectThrows(_ body: () throws -> Void, _ message: String = "expected an error",
                  file: String = #file, line: UInt = #line) throws {
    do {
        try body()
        throw TestFailure(message: message, file: file, line: line)
    } catch is TestFailure {
        throw TestFailure(message: message, file: file, line: line)
    } catch {
        return
    }
}

// MARK: - Runner

@MainActor
func run(_ suites: [Suite]) async -> Int32 {
    var passed = 0
    var failures: [String] = []

    for suite in suites {
        print("\n\(suite.name)")
        for test in suite.tests {
            do {
                try await test.body()
                passed += 1
                print("  ✓ \(test.name)")
            } catch {
                failures.append("\(suite.name) › \(test.name)\n      \(error)")
                print("  ✗ \(test.name)\n      \(error)")
            }
        }
    }

    print("\n\(passed) passed, \(failures.count) failed")
    return failures.isEmpty ? 0 : 1
}
