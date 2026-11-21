import Foundation
import Testing
@testable import WattspurCore

/// A stand-in for UIKit's background tasks: counts what was begun and ended.
@MainActor
private final class FakeTasks {
    var begun: [Int] = []
    var ended: [Int] = []
    var expiry: (() -> Void)?
    var next = 1
    var refuses = false

    func begin(_ expired: @escaping () -> Void) -> Int? {
        guard !refuses else { return nil }
        defer { next += 1 }
        begun.append(next)
        expiry = expired
        return next
    }

    func end(_ id: Int) { ended.append(id) }

    func hold() -> WriteHold {
        WriteHold(begin: { [unowned self] in self.begin($0) }, end: { [unowned self] in self.end($0) })
    }
}

@Suite("Holding the app awake while the library writes (B-366)")
@MainActor
struct WriteHoldTests {
    @Test("One background task for overlapping writes, ended after the last")
    func overlapping() {
        let tasks = FakeTasks()
        let hold = tasks.hold()
        hold.hold()
        hold.hold()
        #expect(tasks.begun == [1])
        hold.release()
        #expect(tasks.ended.isEmpty)
        #expect(hold.isHeld)
        hold.release()
        #expect(tasks.ended == [1])
        #expect(!hold.isHeld)
    }

    @Test("A new write after the end begins a new task")
    func again() {
        let tasks = FakeTasks()
        let hold = tasks.hold()
        hold.hold()
        hold.release()
        hold.hold()
        hold.release()
        #expect(tasks.begun == [1, 2])
        #expect(tasks.ended == [1, 2])
    }

    @Test("When iOS's time runs out, the task ends once and late releases do nothing")
    func expiry() {
        let tasks = FakeTasks()
        let hold = tasks.hold()
        hold.hold()
        hold.hold()
        tasks.expiry?()
        #expect(tasks.ended == [1])
        #expect(!hold.isHeld)
        hold.release()
        hold.release()
        #expect(tasks.ended == [1])
    }

    @Test("A release without a hold does nothing")
    func strayRelease() {
        let tasks = FakeTasks()
        let hold = tasks.hold()
        hold.release()
        #expect(tasks.ended.isEmpty)
        hold.hold()
        #expect(tasks.begun == [1])
    }

    @Test("If iOS gives no time, writing still works and nothing is ended")
    func refused() {
        let tasks = FakeTasks()
        tasks.refuses = true
        let hold = tasks.hold()
        let value = hold.during { 42 }
        #expect(value == 42)
        #expect(tasks.ended.isEmpty)
    }

    @Test("during holds while the body runs")
    func during() {
        let tasks = FakeTasks()
        let hold = tasks.hold()
        hold.during {
            #expect(hold.isHeld)
        }
        #expect(tasks.ended == [1])
    }
}
