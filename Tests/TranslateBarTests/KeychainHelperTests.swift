// Tests/TranslateBarTests/KeychainHelperTests.swift
import Testing
@testable import TranslateBar

struct KeychainHelperTests {
    private let testService = "com.translatebar.test"
    private let testAccount = "test-api-key"

    private func cleanup() {
        KeychainHelper.delete(service: testService, account: testAccount)
    }

    @Test func saveAndRetrieve() throws {
        defer { cleanup() }
        try KeychainHelper.save("test-key-123", service: testService, account: testAccount)
        let retrieved = KeychainHelper.retrieve(service: testService, account: testAccount)
        #expect(retrieved == "test-key-123")
    }

    @Test func retrieveNonExistent() {
        let retrieved = KeychainHelper.retrieve(service: testService, account: "nonexistent")
        #expect(retrieved == nil)
    }

    @Test func overwrite() throws {
        defer { cleanup() }
        try KeychainHelper.save("old-key", service: testService, account: testAccount)
        try KeychainHelper.save("new-key", service: testService, account: testAccount)
        let retrieved = KeychainHelper.retrieve(service: testService, account: testAccount)
        #expect(retrieved == "new-key")
    }

    @Test func delete() throws {
        try KeychainHelper.save("to-delete", service: testService, account: testAccount)
        KeychainHelper.delete(service: testService, account: testAccount)
        let retrieved = KeychainHelper.retrieve(service: testService, account: testAccount)
        #expect(retrieved == nil)
    }
}
