import Foundation

/// The FIT and GPX files the tests read, shared by the tests of both modules.
public enum Fixture {
    public struct Missing: Error { public let name: String }

    public static func url(_ name: String, extension ext: String, subdirectory: String = "Fixtures") -> URL? {
        Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
    }

    /// A FIT file from `Fixtures`.
    public static func data(_ name: String) throws -> Data {
        guard let url = url(name, extension: "fit") else { throw Missing(name: name) }
        return try Data(contentsOf: url)
    }
}

/// The GPX files and the FIT/GPX pairs from `Fixtures/GPX`.
public enum GPXFixture {
    public static func data(_ name: String) throws -> Data {
        guard let url = Fixture.url(name, extension: "gpx", subdirectory: "Fixtures/GPX") else { throw Fixture.Missing(name: name) }
        return try Data(contentsOf: url)
    }

    public static func fitData(_ name: String) throws -> Data {
        guard let url = Fixture.url(name, extension: "fit", subdirectory: "Fixtures/GPX") else { throw Fixture.Missing(name: name) }
        return try Data(contentsOf: url)
    }
}
