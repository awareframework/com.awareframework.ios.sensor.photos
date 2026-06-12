import Foundation
import GRDB
import com_awareframework_ios_core

public struct PhotosRecognitionData: BaseDbModelSQLite {
    public static let databaseTableName = "ios_photos_recognition"
    public static let TABLE_NAME = databaseTableName

    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String = ""
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1

    /// Links to PhotosData.localIdentifier
    public var photoLocalIdentifier: String = ""
    /// Detected label from Vision (e.g. "outdoor", "plant", "person")
    public var recognitionLabel: String = ""
    /// Confidence score [0.0, 1.0]
    public var confidence: Double = 0.0
    /// "classification" | "text" | "face" | "animal" | "barcode"
    public var recognitionType: String = ""

    public init(timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000), label: String = "") {
        self.timestamp = timestamp
        self.label = label
    }

    public init(_ dict: [String: Any]) {
        self.id = dict["id"] as? Int64
        self.timestamp = dict["timestamp"] as? Int64 ?? Int64(Date().timeIntervalSince1970 * 1000)
        self.deviceId = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        self.label = dict["label"] as? String ?? ""
        self.photoLocalIdentifier = dict["photoLocalIdentifier"] as? String ?? ""
        self.recognitionLabel = dict["recognitionLabel"] as? String ?? ""
        self.confidence = dict["confidence"] as? Double ?? 0.0
        self.recognitionType = dict["recognitionType"] as? String ?? ""
    }

    public func toDictionary() -> [String: Any] {
        [
            "id": id ?? -1,
            "timestamp": timestamp,
            "deviceId": deviceId,
            "label": label,
            "photoLocalIdentifier": photoLocalIdentifier,
            "recognitionLabel": recognitionLabel,
            "confidence": confidence,
            "recognitionType": recognitionType,
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
                t.column("photoLocalIdentifier", .text).notNull()
                t.column("recognitionLabel", .text).notNull()
                t.column("confidence", .double).notNull()
                t.column("recognitionType", .text).notNull()
                t.column("os", .text).notNull()
                t.column("timezone", .integer).notNull()
                t.column("jsonVersion", .integer).notNull()
            }
        }
    }
}
