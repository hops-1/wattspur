import CloudKit
import Foundation

extension LibrarySync {
    /// What one record type takes in the private database of the container.
    public struct TypeUsage: Sendable {
        public var records = 0
        /// Bytes of the fields stored in the record itself (strings, data, numbers, dates, references).
        public var fieldBytes = 0
        /// Bytes of the assets, by field name.
        public var assetBytes: [String: Int] = [:]
        public var assetCount = 0
        public var totalAssetBytes: Int { assetBytes.values.reduce(0, +) }
    }

    /// Counts what the CloudKit mirror keeps in the private database, per zone and record type, to
    /// find out why iCloud lists far more for Wattspur than the library takes on disk. Downloads every
    /// asset once to measure it and deletes it right after. Reads only. Debug builds only, with the
    /// iCloud entitlement; the environment is the one of the entitlement.
    public static func measureCloudKitUsage(log: @Sendable (String) -> Void) async throws -> [String: [String: TypeUsage]] {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let zones = try await database.allRecordZones()
        log("zones: \(zones.map(\.zoneID.zoneName))")
        var result: [String: [String: TypeUsage]] = [:]
        // The default zone has no change list; the mirror uses a zone of its own.
        for zone in zones where zone.zoneID != CKRecordZone.default().zoneID {
            var usage: [String: TypeUsage] = [:]
            var token: CKServerChangeToken?
            var moreComing = true
            while moreComing {
                let changes = try await database.recordZoneChanges(inZoneWith: zone.zoneID, since: token, resultsLimit: 40)
                for (_, outcome) in changes.modificationResultsByID {
                    guard case .success(let modification) = outcome else { continue }
                    let record = modification.record
                    var entry = usage[record.recordType] ?? TypeUsage()
                    entry.records += 1
                    for key in record.allKeys() {
                        guard let value = record[key] else { continue }
                        if let asset = value as? CKAsset {
                            let size = asset.fileURL.flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize } ?? 0
                            entry.assetBytes[key, default: 0] += size
                            entry.assetCount += 1
                            if let url = asset.fileURL { try? FileManager.default.removeItem(at: url) }
                        } else {
                            entry.fieldBytes += byteCount(of: value as Any)
                        }
                    }
                    usage[record.recordType] = entry
                }
                token = changes.changeToken
                moreComing = changes.moreComing
                let records = usage.values.reduce(0) { $0 + $1.records }
                log("\(zone.zoneID.zoneName): \(records) records so far")
            }
            result[zone.zoneID.zoneName] = usage
        }
        return result
    }

    private static func byteCount(of value: Any) -> Int {
        switch value {
        case let string as String: return string.utf8.count
        case let string as NSString: return string.length
        case let data as Data: return data.count
        case let list as [Any]: return list.reduce(0) { sum, item in
            sum + byteCount(of: item)
        }
        case let reference as CKRecord.Reference: return reference.recordID.recordName.utf8.count
        default: return 8
        }
    }
}
