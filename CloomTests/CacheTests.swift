import Testing
@testable import Cloom

@Suite("FrameImageCache")
struct FrameImageCacheTests {

    @Test func evictsOldestWhenFull() {
        var cache = FrameImageCache()

        for i in 0..<8 {
            let key = FrameImageCacheKey(frame: .none, width: i, height: 1)
            let image = createDummyCGImage()
            cache.set(key: key, image: image)
        }

        for i in 0..<8 {
            let key = FrameImageCacheKey(frame: .none, width: i, height: 1)
            #expect(cache.get(key: key) != nil, "Entry \(i) should exist")
        }

        let newKey = FrameImageCacheKey(frame: .none, width: 100, height: 1)
        cache.set(key: newKey, image: createDummyCGImage())

        let evictedKey = FrameImageCacheKey(frame: .none, width: 0, height: 1)
        #expect(cache.get(key: evictedKey) == nil, "Oldest entry should be evicted")
        #expect(cache.get(key: newKey) != nil, "New entry should exist")

        let survivingKey = FrameImageCacheKey(frame: .none, width: 1, height: 1)
        #expect(cache.get(key: survivingKey) != nil, "Second-oldest should survive")
    }

    @Test func updateExistingKeyDoesNotEvict() {
        var cache = FrameImageCache()

        for i in 0..<8 {
            let key = FrameImageCacheKey(frame: .none, width: i, height: 1)
            cache.set(key: key, image: createDummyCGImage())
        }

        let existingKey = FrameImageCacheKey(frame: .none, width: 3, height: 1)
        cache.set(key: existingKey, image: createDummyCGImage())

        for i in 0..<8 {
            let key = FrameImageCacheKey(frame: .none, width: i, height: 1)
            #expect(cache.get(key: key) != nil, "Entry \(i) should still exist after update")
        }
    }

    @Test func clear() {
        var cache = FrameImageCache()
        let key = FrameImageCacheKey(frame: .none, width: 1, height: 1)
        cache.set(key: key, image: createDummyCGImage())
        cache.clear()
        #expect(cache.get(key: key) == nil)
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

@Suite("ShapeMaskCache")
struct ShapeMaskCacheTests {

    @Test func evictsOldestWhenFull() {
        var cache = ShapeMaskCache()
        let ciImage = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))

        for i in 0..<4 {
            let key = ShapeMaskCacheKey(shape: .circle, width: CGFloat(i), height: 1)
            cache.set(key, value: ciImage)
        }

        for i in 0..<4 {
            let key = ShapeMaskCacheKey(shape: .circle, width: CGFloat(i), height: 1)
            #expect(cache.get(key) != nil, "Entry \(i) should exist")
        }

        let newKey = ShapeMaskCacheKey(shape: .circle, width: 100, height: 1)
        cache.set(newKey, value: ciImage)

        let evictedKey = ShapeMaskCacheKey(shape: .circle, width: 0, height: 1)
        #expect(cache.get(evictedKey) == nil, "Oldest entry should be evicted")
        #expect(cache.get(newKey) != nil, "New entry should exist")
    }

    @Test func updateExistingKeyDoesNotEvict() {
        var cache = ShapeMaskCache()
        let ciImage = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))

        for i in 0..<4 {
            let key = ShapeMaskCacheKey(shape: .circle, width: CGFloat(i), height: 1)
            cache.set(key, value: ciImage)
        }

        let existingKey = ShapeMaskCacheKey(shape: .circle, width: 2, height: 1)
        cache.set(existingKey, value: ciImage)

        for i in 0..<4 {
            let key = ShapeMaskCacheKey(shape: .circle, width: CGFloat(i), height: 1)
            #expect(cache.get(key) != nil, "Entry \(i) should still exist")
        }
    }
}
