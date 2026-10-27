import AppKit
import XCTest
@testable import AugmaDesktopDemo

final class AppleIconTests: XCTestCase {
  @MainActor func testFinderUsesItsNativeIconWithItsLegacyPackageType() throws {
    let path = "/System/Library/CoreServices/Finder.app"
    guard FileManager.default.fileExists(atPath: path) else { throw XCTSkip("Finder is unavailable on this host") }
    guard case .image(let icon) = AppleIconResolver().resolve(.application(bundlePath: path)) else {
      return XCTFail("Finder is a native application even though its package type is FNDR")
    }
    XCTAssertGreaterThan(icon.size.width, 0)
    XCTAssertGreaterThan(icon.size.height, 0)
  }

  @MainActor func testApplicationArtworkUsesFullBundlePathAndPreservesOriginalMetadata() {
    let first = NSImage(size: NSSize(width: 40, height: 60))
    first.isTemplate = true
    let second = NSImage(size: NSSize(width: 48, height: 48))
    let firstPath = "/Applications/One/Example.app"
    let secondPath = "/Applications/Two/Example.app"
    var paths: [String] = []
    let resolver = AppleIconResolver(typeIdentifiers: { _ in
      XCTFail("Application requests must not query device types")
      return []
    }, image: { _ in
      XCTFail("Application requests must not load device artwork")
      return nil
    }, applicationImage: { path in
      paths.append(path)
      return path == firstPath ? first : second
    })

    guard case .image(let resolvedFirst) = resolver.resolve(.application(bundlePath: firstPath)),
          case .image(let resolvedSecond) = resolver.resolve(.application(bundlePath: secondPath)),
          case .image(let cachedFirst) = resolver.resolve(.application(bundlePath: firstPath)) else {
      return XCTFail("Each app bundle must resolve to its original image")
    }
    XCTAssertTrue(resolvedFirst === first)
    XCTAssertTrue(cachedFirst === first)
    XCTAssertTrue(resolvedSecond === second, "Identically named apps in different folders must not share an icon")
    XCTAssertEqual(resolvedFirst.size, NSSize(width: 40, height: 60))
    XCTAssertTrue(resolvedFirst.isTemplate, "Loading must not mutate the source image")
    XCTAssertEqual(paths, [firstPath, secondPath], "Repeated reads of an unchanged bundle use the shared cache")
  }

  @MainActor func testMissingApplicationArtworkCachesAppFallbackUntilInvalidation() {
    let artwork = NSImage(size: NSSize(width: 32, height: 32))
    var available = false
    var loads = 0
    let resolver = AppleIconResolver(applicationImage: { _ in
      loads += 1
      return available ? artwork : nil
    })
    let request = AppleIconRequest.application(bundlePath: "/Applications/Future.app")
    for _ in 0..<2 {
      guard case .symbol(let symbol) = resolver.resolve(request) else { return XCTFail("Missing apps need an app fallback") }
      XCTAssertEqual(symbol, "app")
      available = true
    }
    XCTAssertEqual(loads, 1)

    resolver.invalidateCache()
    guard case .image(let refreshed) = resolver.resolve(request) else { return XCTFail("Cache invalidation must retry an app miss") }
    XCTAssertTrue(refreshed === artwork)
    XCTAssertEqual(loads, 2)
  }

  @MainActor func testInvalidOrMissingApplicationBundlesUseAnAppSymbolRatherThanAFolderIcon() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("augma-app-icons-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("File.app")
    try Data().write(to: file)
    let emptyBundle = directory.appendingPathComponent("Empty.app")
    try FileManager.default.createDirectory(at: emptyBundle, withIntermediateDirectories: true)
    let resolver = AppleIconResolver()
    for path in ["", "Relative.app", "https://example.com/App.app", directory.path,
                 directory.appendingPathComponent("Missing.app").path, file.path, emptyBundle.path] {
      guard case .symbol(let symbol) = resolver.resolve(.application(bundlePath: path)) else {
        XCTFail("Invalid or missing bundle must not be presented as a folder image: \(path)")
        continue
      }
      XCTAssertEqual(symbol, "app")
    }
  }

  @MainActor func testOfficialArtworkRetainsItsIdentitySizeAndTemplateMetadata() {
    for template in [false, true] {
      let artwork = NSImage(size: NSSize(width: 40, height: 60))
      artwork.isTemplate = template
      var queriedModels: [String] = []
      let resolver = AppleIconResolver(typeIdentifiers: { model in
        queriedModels.append(model)
        return ["com.apple.fixture.iphone"]
      }, image: { _ in artwork })

      guard case .image(let resolved) = resolver.resolve(.device(modelIdentifier: "iPhone18,1")) else {
        return XCTFail("A declared model with available artwork must use the supplied original image")
      }
      XCTAssertTrue(resolved === artwork)
      XCTAssertEqual(resolved.size, NSSize(width: 40, height: 60))
      XCTAssertEqual(resolved.isTemplate, template, "The resolver must not mutate shared system artwork")
      XCTAssertEqual(queriedModels, ["iPhone18,1"])
    }
  }

  @MainActor func testColorVariantsHaveDeterministicSelectionAndMissingArtworkFallsThrough() {
    let artwork = NSImage(size: NSSize(width: 32, height: 32))
    var attemptedTypes: [String] = []
    let resolver = AppleIconResolver(typeIdentifiers: { _ in
      ["com.apple.fixture.9", "com.apple.fixture.2", "com.apple.fixture.1"]
    }, image: { identifier in
      attemptedTypes.append(identifier)
      return identifier == "com.apple.fixture.2" ? artwork : nil
    })

    guard case .image(let resolved) = resolver.resolve(.device(modelIdentifier: "iPhone18,1")) else {
      return XCTFail("A missing first variant must not hide a later available official image")
    }
    XCTAssertTrue(resolved === artwork)
    XCTAssertEqual(attemptedTypes, ["com.apple.fixture.1", "com.apple.fixture.2"])
  }

  @MainActor func testUnknownModelsUseFamilyFallbacksWithoutInventingOfficialArtwork() {
    var attemptedTypes: [String] = []
    let resolver = AppleIconResolver(typeIdentifiers: { _ in [] }, image: { identifier in
      attemptedTypes.append(identifier)
      return nil
    })
    let cases: [(AppleIconRequest, String)] = [
      (.device(modelIdentifier: "iPhone99,99"), "iphone.gen3"),
      (.device(modelIdentifier: "iPad99,99"), "ipad"),
      (.device(modelIdentifier: "MacBookPro99,1"), "laptopcomputer"),
      (.device(simulatorDeviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-Duo"), "iphone.gen3"),
      (.device(simulatorDeviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch"), "ipad"),
      (.device(platform: .watchOS), "applewatch"),
      (.device(platform: .tvOS), "appletv"),
      (.device(platform: .visionOS), "visionpro"),
      (.device(platform: .macOS), "desktopcomputer"),
      (.device(), "rectangle"),
    ]
    for (request, expected) in cases {
      guard case .symbol(let symbol) = resolver.resolve(request) else {
        XCTFail("A missing model image must remain a family symbol")
        continue
      }
      XCTAssertEqual(symbol, expected)
    }
    XCTAssertTrue(attemptedTypes.isEmpty, "No matching system type means there is no artwork to load")
  }

  @MainActor func testRealModelTakesPrecedenceOverOtherFamilyHints() {
    let resolver = AppleIconResolver(typeIdentifiers: { _ in [] }, image: { _ in nil })
    let request = AppleIconRequest.device(modelIdentifier: "iPhone99,99",
      simulatorDeviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPad-Pro", platform: .watchOS)
    guard case .symbol(let symbol) = resolver.resolve(request) else { return XCTFail("Expected a family fallback") }
    XCTAssertEqual(symbol, "iphone.gen3")
  }

  @MainActor func testSuccessfulArtworkIsCachedUntilExplicitInvalidation() {
    let first = NSImage(size: NSSize(width: 32, height: 32))
    let replacement = NSImage(size: NSSize(width: 48, height: 48))
    var current = first
    var modelQueries = 0
    var imageLoads = 0
    let resolver = AppleIconResolver(typeIdentifiers: { _ in
      modelQueries += 1
      return ["com.apple.fixture.iphone"]
    }, image: { _ in imageLoads += 1; return current })
    let request = AppleIconRequest.device(modelIdentifier: "iPhone18,3")
    _ = resolver.resolve(request)
    current = replacement
    guard case .image(let cached) = resolver.resolve(request) else { return XCTFail("Expected cached artwork") }
    XCTAssertTrue(cached === first)
    XCTAssertEqual(modelQueries, 1)
    XCTAssertEqual(imageLoads, 1)

    resolver.invalidateCache()
    guard case .image(let refreshed) = resolver.resolve(request) else { return XCTFail("Expected refreshed artwork") }
    XCTAssertTrue(refreshed === replacement)
    XCTAssertEqual(modelQueries, 2)
    XCTAssertEqual(imageLoads, 2)
  }

  @MainActor func testMissingArtworkIsCachedAndCanBeRefreshed() {
    let artwork = NSImage(size: NSSize(width: 32, height: 32))
    var available = false
    var modelQueries = 0
    var imageLoads = 0
    let resolver = AppleIconResolver(typeIdentifiers: { _ in
      modelQueries += 1
      return ["com.apple.fixture.future-iphone"]
    }, image: { _ in imageLoads += 1; return available ? artwork : nil })
    let request = AppleIconRequest.device(modelIdentifier: "iPhone99,99")
    _ = resolver.resolve(request)
    available = true
    guard case .symbol(let fallback) = resolver.resolve(request) else { return XCTFail("A miss must also be cached") }
    XCTAssertEqual(fallback, "iphone.gen3")
    XCTAssertEqual(modelQueries, 1)
    XCTAssertEqual(imageLoads, 1)

    resolver.invalidateCache()
    guard case .image(let refreshed) = resolver.resolve(request) else { return XCTFail("Invalidation must retry misses") }
    XCTAssertTrue(refreshed === artwork)
    XCTAssertEqual(modelQueries, 2)
    XCTAssertEqual(imageLoads, 2)
  }

  @MainActor func testPlatformEmblemsDoNotPerformDeviceQueriesOrLoadArtwork() {
    var modelQueries = 0
    var imageLoads = 0
    let resolver = AppleIconResolver(typeIdentifiers: { _ in modelQueries += 1; return [] },
                                    image: { _ in imageLoads += 1; return nil })
    for platform in ApplePlatform.allCases {
      guard case .platformLabel(let label) = resolver.resolve(.platform(platform)) else {
        XCTFail("Operating systems must remain identifiable platform emblems")
        continue
      }
      XCTAssertFalse(label.isEmpty)
    }
    XCTAssertEqual(modelQueries, 0)
    XCTAssertEqual(imageLoads, 0)
  }

  func testRuntimeIdentifiersNormalizeToPlatformIdentity() {
    let cases: [(String, ApplePlatform)] = [
      ("com.apple.CoreSimulator.SimRuntime.iOS-27-1", .iOS),
      ("com.apple.CoreSimulator.SimRuntime.iPadOS-27-1", .iPadOS),
      ("com.apple.CoreSimulator.SimRuntime.watchOS-27-0", .watchOS),
      ("com.apple.CoreSimulator.SimRuntime.tvOS-27-0", .tvOS),
      ("com.apple.CoreSimulator.SimRuntime.xrOS-27-0", .visionOS),
      ("com.apple.CoreSimulator.SimRuntime.visionOS-27-0", .visionOS),
      ("com.apple.CoreSimulator.SimRuntime.macOS-27-0", .macOS),
      ("com.apple.CoreSimulator.SimRuntime.FutureOS-1-0", .unknown),
    ]
    for (identifier, expected) in cases { XCTAssertEqual(ApplePlatform(runtimeIdentifier: identifier), expected) }
  }

  @MainActor func testInstalledOfficialIPhoneArtworkWhenExplicitlyRequested() throws {
    guard ProcessInfo.processInfo.environment["AUGMA_TEST_APPLE_ICONS"] == "1" else {
      throw XCTSkip("Opt-in read-only system device artwork check")
    }
    let resolver = AppleIconResolver()
    for model in ["iPhone18,3", "iPhone18,1", "iPhone19,4"] {
      guard case .image(let artwork) = resolver.resolve(.device(modelIdentifier: model)) else {
        XCTFail("Installed official artwork was not found for \(model)")
        continue
      }
      XCTAssertGreaterThan(artwork.size.width, 0)
      XCTAssertGreaterThan(artwork.size.height, 0)
    }
  }
}
