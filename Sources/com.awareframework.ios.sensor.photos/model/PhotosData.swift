import Foundation
import GRDB
import com_awareframework_ios_core

public struct PhotosData: BaseDbModelSQLite {
    public static let databaseTableName = "ios_photos"
    public static let TABLE_NAME = databaseTableName

    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String = ""
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1

    /// PHAsset.localIdentifier
    public var localIdentifier: String = ""
    /// PHMediaType raw value: 1=image, 2=video, 3=audio
    public var mediaType: Int = 0
    public var mediaWidth: Int = 0
    public var mediaHeight: Int = 0
    /// PHAsset.creationDate as Unix milliseconds
    public var creationTimestamp: Int64 = 0
    /// Duration in seconds (non-zero for videos)
    public var duration: Double = 0.0
    public var isFavorite: Bool = false

    public init(timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000), label: String = "") {
        self.timestamp = timestamp
        self.label = label
    }

    public init(_ dict: [String: Any]) {
        self.id = dict["id"] as? Int64
        self.timestamp = dict["timestamp"] as? Int64 ?? Int64(Date().timeIntervalSince1970 * 1000)
        self.deviceId = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        self.label = dict["label"] as? String ?? ""
        self.localIdentifier = dict["localIdentifier"] as? String ?? ""
        self.mediaType = dict["mediaType"] as? Int ?? 0
        self.mediaWidth = dict["mediaWidth"] as? Int ?? 0
        self.mediaHeight = dict["mediaHeight"] as? Int ?? 0
        self.creationTimestamp = dict["creationTimestamp"] as? Int64 ?? 0
        self.duration = dict["duration"] as? Double ?? 0.0
        self.isFavorite = dict["isFavorite"] as? Bool ?? false
    }

    public func toDictionary() -> [String: Any] {
        [
            "id": id ?? -1,
            "timestamp": timestamp,
            "deviceId": deviceId,
            "label": label,
            "localIdentifier": localIdentifier,
            "mediaType": mediaType,
            "mediaWidth": mediaWidth,
            "mediaHeight": mediaHeight,
            "creationTimestamp": creationTimestamp,
            "duration": duration,
            "isFavorite": isFavorite,
            "os": os,
            "timezone": timezone,
            "jsonVersion": jsonVersion,
        ]
    }

    public static func createTable(queue: DatabaseQueue) throws {
        try queue.write { db in
            try db.create(table: databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .integer).notNull()
                t.column("deviceId", .text).notNull()
                t.column("label", .text)
                t.column("localIdentifier", .text).notNull()
                t.column("mediaType", .integer).notNull()
                t.column("mediaWidth", .integer).notNull()
                t.column("mediaHeight", .integer).notNull()
                t.column("creationTimestamp", .integer).notNull()
                t.column("duration", .double).notNull()
                t.column("isFavorite", .boolean).notNull()
                t.column("os", .text).notNull()
                t.column("timezone", .integer).notNull()
                t.column("jsonVersion", .integer).notNull()
            }
        }
    }
}
