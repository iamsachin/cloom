import Testing
@testable import Cloom

@Suite("FFI Bridge")
struct FFIBridgeTests {

    @Test func helloFromRustReturnsNonEmpty() {
        let result = helloFromRust(name: "Test")
        #expect(!result.isEmpty)
        #expect(result.contains("Test"))
    }

    @Test func cloomCoreVersionIsValidSemver() {
        let version = cloomCoreVersion()
        #expect(!version.isEmpty)
        let parts = version.split(separator: ".")
        #expect(parts.count == 3, "Version should be semver (major.minor.patch)")
        for part in parts {
            #expect(Int(part) != nil, "Each version component should be numeric")
        }
    }
}
