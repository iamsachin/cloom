import XCTest
@testable import Cloom

final class FrameImageCacheTests: XCTestCase {

    func testEvictsOldestWhenFull() {
        var cache = FrameImageCache()

        // Insert 8 entries (max capacity)
        for i in 0..<8 {
            let key = FrameImageCacheKey(frame: .none, width: i, height: 1)
            let image = createDummyCGImage()
            cache.set(key: key, image: image)
        }

        // All 8 should be present
        for i in 0..<8 {
            let key = FrameImageCacheKey(frame: .none, width: i, height: 1)
            XCTAssertNotNil(cache.get(key: key), "Entry \(i) should exist")
        }

        // Insert 9th — should evict the first (width: 0)
        let newKey = FrameImageCacheKey(frame: .none, width: 100, height: 1)
        cache.set(key: newKey, image: createDummyCGImage())

        let evictedKey = FrameImageCacheKey(frame: .none, width: 0, height: 1)
        XCTAssertNil(cache.get(key: evictedKey), "Oldest entry should be evicted")
        XCTAssertNotNil(cache.get(key: newKey), "New entry should exist")

        // Entry 1 should still exist
        let survivingKey = FrameImageCacheKey(frame: .none, width: 1, height: 1)
        XCTAssertNotNil(cache.get(key: survivingKey), "Second-oldest should survive")
    }

    func testUpdateExistingKeyDoesNotEvict() {
        var cache = FrameImageCache()

        for i in 0..<8 {
            let key = FrameImageCacheKey(frame: .none, width: i, height: 1)
            cache.set(key: key, image: createDummyCGImage())
        }

        // Update an existing key (should NOT trigger eviction)
        let existingKey = FrameImageCacheKey(frame: .none, width: 3, height: 1)
        cache.set(key: existingKey, image: createDummyCGImage())

        // All 8 should still be present
        for i in 0..<8 {
            let key = FrameImageCacheKey(frame: .none, width: i, height: 1)
            XCTAssertNotNil(cache.get(key: key), "Entry \(i) should still exist after update")
        }
    }

    func testClear() {
        var cache = FrameImageCache()
        let key = FrameImageCacheKey(frame: .none, width: 1, height: 1)
        cache.set(key: key, image: createDummyCGImage())
        cache.clear()
        XCTAssertNil(cache.get(key: key))
    }

    private func createDummyCGImage() -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil, width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return ctx.makeImage()!
    }
}

final class ShapeMaskCacheTests: XCTestCase {

    func testEvictsOldestWhenFull() {
        var cache = ShapeMaskCache()
        let ciImage = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))

        // Insert 4 entries (max capacity)
        for i in 0..<4 {
            let key = ShapeMaskCacheKey(shape: .circle, width: CGFloat(i), height: 1)
            cache.set(key, value: ciImage)
        }

        // All 4 should be present
        for i in 0..<4 {
            let key = ShapeMaskCacheKey(shape: .circle, width: CGFloat(i), height: 1)
            XCTAssertNotNil(cache.get(key), "Entry \(i) should exist")
        }

        // Insert 5th — should evict oldest (width: 0)
        let newKey = ShapeMaskCacheKey(shape: .circle, width: 100, height: 1)
        cache.set(newKey, value: ciImage)

        let evictedKey = ShapeMaskCacheKey(shape: .circle, width: 0, height: 1)
        XCTAssertNil(cache.get(evictedKey), "Oldest entry should be evicted")
        XCTAssertNotNil(cache.get(newKey), "New entry should exist")
    }

    func testUpdateExistingKeyDoesNotEvict() {
        var cache = ShapeMaskCache()
        let ciImage = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))

        for i in 0..<4 {
            let key = ShapeMaskCacheKey(shape: .circle, width: CGFloat(i), height: 1)
            cache.set(key, value: ciImage)
        }

        // Update existing — no eviction should happen
        let existingKey = ShapeMaskCacheKey(shape: .circle, width: 2, height: 1)
        cache.set(existingKey, value: ciImage)

        for i in 0..<4 {
            let key = ShapeMaskCacheKey(shape: .circle, width: CGFloat(i), height: 1)
            XCTAssertNotNil(cache.get(key), "Entry \(i) should still exist")
        }
    }
}
