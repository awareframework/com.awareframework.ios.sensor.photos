//
//  PhotosSensor.swift
//  com.aware.ios.sensor.photos
//
//  Created by Yuuki Nishiyama on 2026/06/03.
//

import UIKit
import Photos
import Vision
import com_awareframework_ios_core

extension Notification.Name {
    public static let actionAwarePhotos = Notification.Name(PhotosSensor.ACTION_AWARE_PHOTOS)
    public static let actionAwarePhotosStart = Notification.Name(PhotosSensor.ACTION_AWARE_PHOTOS_START)
    public static let actionAwarePhotosStop = Notification.Name(PhotosSensor.ACTION_AWARE_PHOTOS_STOP)
    public static let actionAwarePhotosSync = Notification.Name(PhotosSensor.ACTION_AWARE_PHOTOS_SYNC)
    public static let actionAwarePhotosSyncCompletion = Notification.Name(PhotosSensor.ACTION_AWARE_PHOTOS_SYNC_COMPLETION)
    public static let actionAwarePhotosSetLabel = Notification.Name(PhotosSensor.ACTION_AWARE_PHOTOS_SET_LABEL)
    public static let actionAwarePhotoTaken = Notification.Name(PhotosSensor.ACTION_AWARE_PHOTO_TAKEN)
    public static let actionAwarePhotosRecognized = Notification.Name(PhotosSensor.ACTION_AWARE_PHOTOS_RECOGNIZED)
}

public protocol PhotosObserver {
    /// Called when a new photo or video is added to the library.
    func onPhotoTaken(data: PhotosData)
    /// Called for each Vision result above the configured confidence threshold.
    func onImageRecognized(data: PhotosRecognitionData)
}

public class PhotosSensor: AwareSensor {

    public static let TAG = "AWARE::Photos"

    public static let ACTION_AWARE_PHOTOS = "com.awareframework.ios.sensor.photos"
    public static let ACTION_AWARE_PHOTOS_START = "com.awareframework.ios.sensor.photos.SENSOR_START"
    public static let ACTION_AWARE_PHOTOS_STOP = "com.awareframework.ios.sensor.photos.SENSOR_STOP"
    public static let ACTION_AWARE_PHOTOS_SET_LABEL = "com.awareframework.ios.sensor.photos.SET_LABEL"
    public static let EXTRA_LABEL = "label"
    public static let ACTION_AWARE_PHOTOS_SYNC = "com.awareframework.ios.sensor.photos.SENSOR_SYNC"
    public static let ACTION_AWARE_PHOTOS_SYNC_COMPLETION = "com.awareframework.ios.sensor.photos.SENSOR_SYNC_COMPLETION"
    public static let EXTRA_STATUS = "status"
    public static let EXTRA_ERROR = "error"
    public static let EXTRA_OBJECT_TYPE = "objectType"
    public static let EXTRA_TABLE_NAME = "tableName"
    public static let ACTION_AWARE_PHOTO_TAKEN = "com.awareframework.ios.sensor.photos.ACTION_AWARE_PHOTO_TAKEN"
    public static let ACTION_AWARE_PHOTOS_RECOGNIZED = "com.awareframework.ios.sensor.photos.ACTION_AWARE_PHOTOS_RECOGNIZED"

    public var CONFIG = Config()

    /// PHFetchResult kept up-to-date by the change observer so we can diff each change.
    private var fetchResult: PHFetchResult<PHAsset>?
    private let fetchResultQueue = DispatchQueue(label: "com.awareframework.ios.sensor.photos.fetchResult")
    private let recognitionQueue = DispatchQueue(label: "com.awareframework.ios.sensor.photos.recognition", qos: .utility)

    public class Config: SensorConfig {
        public var sensorObserver: PhotosObserver?

        /// Whether to run Vision image classification on new images. Defaults to false (opt-in).
        public var performRecognition: Bool = false

        /// Minimum Vision confidence to store a recognition result [0.0–1.0].
        public var recognitionMinConfidence: Float = 0.5

        /// Pixel size used when requesting the image thumbnail for Vision (smaller = faster).
        public var recognitionImageSize: CGSize = CGSize(width: 640, height: 640)

        public override init() {
            super.init()
            dbPath = "aware_photos"
        }

        public func apply(closure: (_ config: PhotosSensor.Config) -> Void) -> Self {
            closure(self)
            return self
        }
    }

    public override convenience init() {
        self.init(PhotosSensor.Config())
    }

    public init(_ config: PhotosSensor.Config) {
        super.init()
        CONFIG = config
        initializeDbEngine(config: config)
        super.syncConfig = DbSyncConfig().apply { syncConfig in
            syncConfig.serverType = config.serverType
            syncConfig.debug = config.debug
            syncConfig.batchSize = 1000
            syncConfig.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.photos.sync.queue")
            syncConfig.completionHandler = { [weak self] status, error in
                guard let self else { return }
                var userInfo: [String: Any] = [PhotosSensor.EXTRA_STATUS: status]
                if let error { userInfo[PhotosSensor.EXTRA_ERROR] = error }
                self.notificationCenter.post(name: .actionAwarePhotosSyncCompletion, object: self, userInfo: userInfo)
            }
        }
        initializeTables()
    }

    // MARK: - AwareSensor lifecycle

    public override func start() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            guard let self else { return }
            switch status {
            case .authorized, .limited:
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    let options = PHFetchOptions()
                    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                    self.fetchResultQueue.sync {
                        self.fetchResult = PHAsset.fetchAssets(with: options)
                    }
                    PHPhotoLibrary.shared().register(self)
                    self.notificationCenter.post(name: .actionAwarePhotosStart, object: self)
                }
            default:
                if self.CONFIG.debug {
                    print(PhotosSensor.TAG, "Photo library access denied or restricted.")
                }
            }
        }
    }

    public override func stop() {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        notificationCenter.post(name: .actionAwarePhotosStop, object: self)
    }

    public override func sync(force: Bool = false) {
        guard let syncConfig = super.syncConfig else { return }
        notificationCenter.post(name: .actionAwarePhotosSync, object: self)
        startSequentialSync(
            for: [PhotosData.TABLE_NAME, PhotosRecognitionData.TABLE_NAME],
            syncConfig: syncConfig,
            currentIndex: 0,
            hasFailure: false,
            lastError: nil)
    }

    public override func set(label: String) {
        CONFIG.label = label
        notificationCenter.post(name: .actionAwarePhotosSetLabel, object: self,
                                userInfo: [PhotosSensor.EXTRA_LABEL: label])
    }

    // MARK: - Photo event handling

    private func handleNewAsset(_ asset: PHAsset) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        var data = PhotosData(timestamp: now, label: CONFIG.label)
        data.localIdentifier = asset.localIdentifier
        data.mediaType = asset.mediaType.rawValue
        data.mediaWidth = asset.pixelWidth
        data.mediaHeight = asset.pixelHeight
        data.duration = asset.duration
        data.isFavorite = asset.isFavorite
        if let creationDate = asset.creationDate {
            data.creationTimestamp = Int64(creationDate.timeIntervalSince1970 * 1000)
        }

        saveModels([data])
        CONFIG.sensorObserver?.onPhotoTaken(data: data)
        notificationCenter.post(name: .actionAwarePhotoTaken, object: self)

        if CONFIG.debug {
            print(PhotosSensor.TAG, "Photo taken:", asset.localIdentifier, "type:", asset.mediaType.rawValue)
        }

        if CONFIG.performRecognition && asset.mediaType == .image {
            performClassification(asset: asset)
        }
    }

    // MARK: - Vision image classification

    private func performClassification(asset: PHAsset) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        let targetSize = CONFIG.recognitionImageSize

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] image, _ in
            guard let self, let cgImage = image?.cgImage else { return }
            self.recognitionQueue.async {
                self.runVisionClassification(cgImage: cgImage, localIdentifier: asset.localIdentifier)
            }
        }
    }

    private func runVisionClassification(cgImage: CGImage, localIdentifier: String) {
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNClassifyImageRequest()

        do {
            try handler.perform([request])
        } catch {
            if CONFIG.debug { print(PhotosSensor.TAG, "Vision error:", error) }
            return
        }

        guard let observations = request.results as? [VNClassificationObservation] else { return }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let minConfidence = CONFIG.recognitionMinConfidence
        let results: [PhotosRecognitionData] = observations
            .filter { $0.confidence >= minConfidence }
            .map { obs in
                var recData = PhotosRecognitionData(timestamp: now, label: CONFIG.label)
                recData.photoLocalIdentifier = localIdentifier
                recData.recognitionLabel = obs.identifier
                recData.confidence = Double(obs.confidence)
                recData.recognitionType = "classification"
                return recData
            }

        guard !results.isEmpty else { return }

        saveModels(results)
        for recData in results {
            CONFIG.sensorObserver?.onImageRecognized(data: recData)
        }
        notificationCenter.post(name: .actionAwarePhotosRecognized, object: self)

        if CONFIG.debug {
            print(PhotosSensor.TAG, "Recognized \(results.count) labels for:", localIdentifier)
        }
    }

    // MARK: - Database helpers

    private func initializeTables() {
        guard let queue = (dbEngine as? SQLiteEngine)?.getSQLiteInstance() else { return }
        do {
            try PhotosData.createTable(queue: queue)
            try PhotosRecognitionData.createTable(queue: queue)
        } catch {
            if CONFIG.debug { print(PhotosSensor.TAG, "DB init error:", error) }
        }
    }

    private func saveModels<T: BaseDbModelSQLite>(_ models: [T]) {
        guard let engine = dbEngine as? SQLiteEngine else { return }
        engine.save(models)
    }

    // MARK: - Sync helpers (mirroring ScreenSensor pattern)

    private func makeSyncEngine(for tableName: String) -> Engine {
        Engine.Builder()
            .setPath(CONFIG.dbPath)
            .setType(CONFIG.dbType)
            .setHost(CONFIG.dbHost)
            .setEncryptionKey(CONFIG.dbEncryptionKey)
            .setTableName(tableName)
            .build()
    }

    private func makeSyncConfig(from base: DbSyncConfig, completionHandler: DbSyncCompletionHandler?) -> DbSyncConfig {
        let config = DbSyncConfig()
        config.removeAfterSync = base.removeAfterSync
        config.batchSize = base.batchSize
        config.markAsSynced = base.markAsSynced
        config.skipSyncedData = base.skipSyncedData
        config.keepLastData = base.keepLastData
        config.deviceId = base.deviceId
        config.debug = base.debug
        config.debugLevel = base.debugLevel
        config.progressHandler = base.progressHandler
        config.dispatchQueue = base.dispatchQueue
        config.backgroundSession = base.backgroundSession
        config.compactDataFormat = base.compactDataFormat
        config.serverType = base.serverType
        config.test = base.test
        config.completionHandler = completionHandler
        return config
    }

    private func startSequentialSync(
        for tables: [String],
        syncConfig: DbSyncConfig,
        currentIndex: Int,
        hasFailure: Bool,
        lastError: Error?
    ) {
        guard currentIndex < tables.count else {
            syncConfig.completionHandler?(hasFailure == false, lastError)
            return
        }
        let tableName = tables[currentIndex]
        let engine = makeSyncEngine(for: tableName)
        let perTableConfig = makeSyncConfig(from: syncConfig) { [weak self] status, error in
            guard let self else { return }
            var userInfo: [String: Any] = [
                PhotosSensor.EXTRA_STATUS: status,
                PhotosSensor.EXTRA_TABLE_NAME: tableName,
            ]
            if tableName == PhotosData.TABLE_NAME {
                userInfo[PhotosSensor.EXTRA_OBJECT_TYPE] = PhotosData.self
            } else {
                userInfo[PhotosSensor.EXTRA_OBJECT_TYPE] = PhotosRecognitionData.self
            }
            if let error { userInfo[PhotosSensor.EXTRA_ERROR] = error }
            self.notificationCenter.post(name: .actionAwarePhotosSyncCompletion, object: self, userInfo: userInfo)
            self.startSequentialSync(
                for: tables,
                syncConfig: syncConfig,
                currentIndex: currentIndex + 1,
                hasFailure: hasFailure || status == false,
                lastError: error ?? lastError)
        }
        engine.startSync(perTableConfig)
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension PhotosSensor: PHPhotoLibraryChangeObserver {
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        var currentFetchResult: PHFetchResult<PHAsset>?
        fetchResultQueue.sync { currentFetchResult = self.fetchResult }

        guard let currentFetchResult else { return }
        guard let changeDetails = changeInstance.changeDetails(for: currentFetchResult) else { return }

        fetchResultQueue.sync {
            self.fetchResult = changeDetails.fetchResultAfterChanges
        }

        for asset in changeDetails.insertedObjects {
            handleNewAsset(asset)
        }

        notificationCenter.post(name: .actionAwarePhotos, object: self)
    }
}
