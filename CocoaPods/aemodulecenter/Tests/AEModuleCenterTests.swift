//
//  AEModuleCenterTests.swift
//  AEModuleCenter Tests
//
//  Created on 2026/04/14.
//

import XCTest
@testable import AEModuleCenter

/// 测试模块 A
class TestModuleA: NSObject, AEModuleProtocol {
    var didFinishLaunchingCalled = false
    var didBecomeActiveCalled = false
    var didEnterBackgroundCalled = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        didFinishLaunchingCalled = true
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        didBecomeActiveCalled = true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        didEnterBackgroundCalled = true
    }
}

/// 测试模块 B
class TestModuleB: NSObject, AEModuleProtocol {
    var callCount = 0

    func applicationDidBecomeActive(_ application: UIApplication) {
        callCount += 1
    }
}

/// 测试模块 C - 会返回 false
class TestModuleC: NSObject, AEModuleProtocol {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return false
    }
}

class AEModuleCenterTests: XCTestCase {

    var moduleCenter: AEModuleCenter!

    override func setUp() {
        super.setUp()
        moduleCenter = AEModuleCenter.shared
        moduleCenter.unregisterAll()
    }

    override func tearDown() {
        moduleCenter.unregisterAll()
        super.tearDown()
    }

    // MARK: - Module Management Tests

    func testRegisterModule() {
        let module = TestModuleA()
        let result = moduleCenter.register(module: module)

        XCTAssertTrue(result, "模块注册应该成功")
        XCTAssertEqual(moduleCenter.moduleCount, 1, "应该有 1 个模块")
    }

    func testRegisterDuplicateModule() {
        let module = TestModuleA()

        let result1 = moduleCenter.register(module: module)
        XCTAssertTrue(result1, "首次注册应该成功")

        let result2 = moduleCenter.register(module: module)
        XCTAssertFalse(result2, "重复注册应该失败")

        XCTAssertEqual(moduleCenter.moduleCount, 1, "应该只有 1 个模块")
    }

    func testUnregisterModule() {
        let module = TestModuleA()
        moduleCenter.register(module: module)

        let result = moduleCenter.unregister(module: module)

        XCTAssertTrue(result, "模块移除应该成功")
        XCTAssertEqual(moduleCenter.moduleCount, 0, "应该没有模块")
    }

    func testUnregisterNonExistentModule() {
        let module = TestModuleA()

        let result = moduleCenter.unregister(module: module)

        XCTAssertFalse(result, "移除不存在的模块应该失败")
    }

    func testUnregisterAllModules() {
        let module1 = TestModuleA()
        let module2 = TestModuleB()

        moduleCenter.register(module: module1)
        moduleCenter.register(module: module2)

        XCTAssertEqual(moduleCenter.moduleCount, 2, "应该有 2 个模块")

        moduleCenter.unregisterAll()

        XCTAssertEqual(moduleCenter.moduleCount, 0, "应该没有模块")
    }

    // MARK: - Lifecycle Forwarding Tests

    func testDidFinishLaunchingForwarding() {
        let module = TestModuleA()
        moduleCenter.register(module: module)

        let result = moduleCenter.application(
            UIApplication.shared,
            didFinishLaunchingWithOptions: nil
        )

        XCTAssertTrue(result, "应该返回 true")
        XCTAssertTrue(module.didFinishLaunchingCalled, "模块的方法应该被调用")
    }

    func testDidFinishLaunchingWithFailingModule() {
        let moduleA = TestModuleA()
        let moduleC = TestModuleC()

        moduleCenter.register(module: moduleA)
        moduleCenter.register(module: moduleC)

        let result = moduleCenter.application(
            UIApplication.shared,
            didFinishLaunchingWithOptions: nil
        )

        XCTAssertFalse(result, "应该返回 false（因为 moduleC 返回 false）")
        XCTAssertTrue(moduleA.didFinishLaunchingCalled, "moduleA 的方法应该被调用")
    }

    func testDidBecomeActiveForwarding() {
        let module = TestModuleA()
        moduleCenter.register(module: module)

        moduleCenter.applicationDidBecomeActive(UIApplication.shared)

        XCTAssertTrue(module.didBecomeActiveCalled, "模块的方法应该被调用")
    }

    func testDidEnterBackgroundForwarding() {
        let module = TestModuleA()
        moduleCenter.register(module: module)

        moduleCenter.applicationDidEnterBackground(UIApplication.shared)

        XCTAssertTrue(module.didEnterBackgroundCalled, "模块的方法应该被调用")
    }

    func testMultipleModulesForwarding() {
        let module1 = TestModuleB()
        let module2 = TestModuleB()

        moduleCenter.register(module: module1)
        moduleCenter.register(module: module2)

        moduleCenter.applicationDidBecomeActive(UIApplication.shared)

        XCTAssertEqual(module1.callCount, 1, "module1 应该被调用 1 次")
        XCTAssertEqual(module2.callCount, 1, "module2 应该被调用 1 次")
    }

    // MARK: - Thread Safety Tests

    func testConcurrentRegistration() {
        let expectation = self.expectation(description: "Concurrent registration")
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let modules = (0..<100).map { _ in TestModuleA() }
        var successCount = 0
        let lock = NSLock()

        for module in modules {
            concurrentQueue.async {
                let result = self.moduleCenter.register(module: module)
                lock.lock()
                if result {
                    successCount += 1
                }
                lock.unlock()

                if successCount == modules.count {
                    expectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 5) { error in
            XCTAssertNil(error, "不应该超时")
            XCTAssertEqual(successCount, 100, "所有模块都应该注册成功")
            XCTAssertEqual(self.moduleCenter.moduleCount, 100, "应该有 100 个模块")
        }
    }

    func testConcurrentUnregistration() {
        let modules = (0..<50).map { _ in TestModuleA() }
        modules.forEach { moduleCenter.register(module: $0) }

        let expectation = self.expectation(description: "Concurrent unregistration")
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        var successCount = 0
        let lock = NSLock()

        for module in modules {
            concurrentQueue.async {
                let result = self.moduleCenter.unregister(module: module)
                lock.lock()
                if result {
                    successCount += 1
                }
                lock.unlock()

                if successCount == modules.count {
                    expectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 5) { error in
            XCTAssertNil(error, "不应该超时")
            XCTAssertEqual(successCount, 50, "所有模块都应该移除成功")
            XCTAssertEqual(self.moduleCenter.moduleCount, 0, "应该没有模块")
        }
    }

    func testConcurrentRegistrationAndForwarding() {
        let expectation = self.expectation(description: "Concurrent operations")
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let modules = (0..<50).map { _ in TestModuleB() }

        // 并发注册和调用
        for module in modules {
            concurrentQueue.async {
                self.moduleCenter.register(module: module)
            }
        }

        concurrentQueue.async {
            for _ in 0..<100 {
                self.moduleCenter.applicationDidBecomeActive(UIApplication.shared)
                Thread.sleep(forTimeInterval: 0.001)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10) { error in
            XCTAssertNil(error, "不应该超时")
            // 验证没有崩溃就是成功
        }
    }

    // MARK: - Memory Management Tests

    func testWeakReferenceToModules() {
        var module: TestModuleA? = TestModuleA()
        weak var weakModule = module

        moduleCenter.register(module: module!)
        XCTAssertEqual(moduleCenter.moduleCount, 1, "应该有 1 个模块")

        module = nil

        XCTAssertNil(weakModule, "模块应该被释放")
        // NSHashTable.weakObjects 会在下次访问时自动清理
        // 触发一次访问以清理
        _ = moduleCenter.moduleCount
    }

    // MARK: - Edge Cases Tests

    func testForwardingToNoModules() {
        XCTAssertEqual(moduleCenter.moduleCount, 0, "应该没有模块")

        // 不应该崩溃
        let result = moduleCenter.application(
            UIApplication.shared,
            didFinishLaunchingWithOptions: nil
        )

        XCTAssertTrue(result, "没有模块时应该返回 true")
    }

    func testModuleCountAfterModuleReleased() {
        autoreleasepool {
            let module = TestModuleA()
            moduleCenter.register(module: module)
            XCTAssertEqual(moduleCenter.moduleCount, 1, "应该有 1 个模块")
        }

        // 模块被释放后，count 可能还是 1（因为 NSHashTable 延迟清理）
        // 但不会导致崩溃
        _ = moduleCenter.moduleCount
    }
}

// MARK: - Performance Tests

extension AEModuleCenterTests {

    func testPerformanceRegister() {
        measure {
            let modules = (0..<1000).map { _ in TestModuleA() }
            modules.forEach { moduleCenter.register(module: $0) }
            moduleCenter.unregisterAll()
        }
    }

    func testPerformanceForwarding() {
        let modules = (0..<100).map { _ in TestModuleA() }
        modules.forEach { moduleCenter.register(module: $0) }

        measure {
            for _ in 0..<100 {
                moduleCenter.applicationDidBecomeActive(UIApplication.shared)
            }
        }
    }
}
