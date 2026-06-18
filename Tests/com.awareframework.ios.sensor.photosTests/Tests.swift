import XCTest
import Photos
import com_awareframework_ios_sensor_photos
import com_awareframework_ios_core

class Tests: XCTestCase {

    func testControllers() {
        let sensor = PhotosSensor()
        sensor.CONFIG.debug = true

        // set label
        let expectSetLabel = expectation(description: "set label")
        let newLabel = "hello"
        let labelObserver = NotificationCenter.default.addObserver(
            forName: .actionAwarePhotosSetLabel, object: nil, queue: .main
        ) { notification in
            if let dict = notification.userInfo as? [String: String] {
                XCTAssertEqual(dict[PhotosSensor.EXTRA_LABEL], newLabel)
            } else {
                XCTFail()
            }
            expectSetLabel.fulfill()
        }
        sensor.set(label: newLabel)
        wait(for: [expectSetLabel], timeout: 5)
        NotificationCenter.default.removeObserver(labelObserver)

        // sync
        let expectSync = expectation(description: "sync")
        let syncObserver = NotificationCenter.default.addObserver(
            forName: .actionAwarePhotosSync, object: nil, queue: .main
        ) { _ in expectSync.fulfill() }
        sensor.sync()
        wait(for: [expectSync], timeout: 5)
        NotificationCenter.default.removeObserver(syncObserver)

        // stop
        let expectStop = expectation(description: "stop")
        let stopObserver = NotificationCenter.default.addObserver(
            forName: .actionAwarePhotosStop, object: nil, queue: .main
        ) { _ in expectStop.fulfill() }
        sensor.stop()
        wait(for: [expectStop], timeout: 5)
        NotificationCenter.default.removeObserver(stopObserver)
    }

    func testStartControllerWhenPhotoLibraryAuthorized() throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo Library permission is not available in this test environment.")
        }

        let sensor = PhotosSensor()
        sensor.CONFIG.debug = true

        let expectStart = expectation(description: "start")
        let startObserver = NotificationCenter.default.addObserver(
            forName: .actionAwarePhotosStart, object: sensor, queue: .main
        ) { _ in expectStart.fulfill() }

        sensor.start()
        wait(for: [expectStart], timeout: 5)
        NotificationCenter.default.removeObserver(startObserver)
        sensor.stop()
    }

    func testPhotosData() {
        let data = PhotosData()
        let dict = data.toDictionary()

        XCTAssertEqual(dict["localIdentifier"] as? String, "")
        XCTAssertEqual(dict["mediaType"] as? Int, 0)
        XCTAssertEqual(dict["mediaWidth"] as? Int, 0)
        XCTAssertEqual(dict["mediaHeight"] as? Int, 0)
        XCTAssertEqual(dict["creationTimestamp"] as? Int64, 0)
        XCTAssertEqual(dict["duration"] as? Double, 0.0)
        XCTAssertEqual(dict["isFavorite"] as? Bool, false)
    }

    func testPhotosDataDictInit() {
        let source: [String: Any] = [
            "localIdentifier": "test-uuid",
            "mediaType": 1,
            "mediaWidth": 4032,
            "mediaHeight": 3024,
            "creationTimestamp": Int64(1_700_000_000_000),
            "duration": 0.0,
            "isFavorite": true,
        ]
        let data = PhotosData(source)
        XCTAssertEqual(data.localIdentifier, "test-uuid")
        XCTAssertEqual(data.mediaType, 1)
        XCTAssertEqual(data.mediaWidth, 4032)
        XCTAssertEqual(data.mediaHeight, 3024)
        XCTAssertEqual(data.creationTimestamp, 1_700_000_000_000)
        XCTAssertTrue(data.isFavorite)
    }

    func testPhotosRecognitionData() {
        let data = PhotosRecognitionData()
        let dict = data.toDictionary()

        XCTAssertEqual(dict["photoLocalIdentifier"] as? String, "")
        XCTAssertEqual(dict["recognitionLabel"] as? String, "")
        XCTAssertEqual(dict["confidence"] as? Double, 0.0)
        XCTAssertEqual(dict["recognitionType"] as? String, "")
    }

    func testPhotosRecognitionDataDictInit() {
        let source: [String: Any] = [
            "photoLocalIdentifier": "test-uuid",
            "recognitionLabel": "outdoor",
            "confidence": 0.92,
            "recognitionType": "classification",
        ]
        let data = PhotosRecognitionData(source)
        XCTAssertEqual(data.photoLocalIdentifier, "test-uuid")
        XCTAssertEqual(data.recognitionLabel, "outdoor")
        XCTAssertEqual(data.confidence, 0.92, accuracy: 0.001)
        XCTAssertEqual(data.recognitionType, "classification")
    }

    func testSyncModule() {
        #if targetEnvironment(simulator)
        print("Sync test requires a real device.")
        #else
        let sensor = PhotosSensor(PhotosSensor.Config().apply { config in
            config.debug = true
            config.dbHost = "node.awareframework.com:1001"
            config.dbPath = "sync_db"
        })

        let successExpectation = XCTestExpectation(description: "sync success")
        let observer = NotificationCenter.default.addObserver(
            forName: .actionAwarePhotosSyncCompletion, object: sensor, queue: .main
        ) { notification in
            if let status = notification.userInfo?["status"] as? Bool, status {
                successExpectation.fulfill()
            }
        }
        sensor.sync(force: true)
        wait(for: [successExpectation], timeout: 20)
        NotificationCenter.default.removeObserver(observer)
        #endif
    }
}
