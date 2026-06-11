# AWARE: Photos

[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)

This sensor module monitors the photo library using the Photos framework and detects newly added photos or videos in real time. When a new image is captured, it optionally runs Apple's Vision framework to classify the image content and store recognition labels with confidence scores.

## Requirements
iOS 15 or later

## Installation

1. Open Package Manager Windows
    * Open `Xcode` -> Select `Menu Bar` -> `File` -> `App Package Dependencies...`

2. Find the package using the manager
    * Select `Search Package URL` and type `https://github.com/awareframework/com.awareframework.ios.sensor.photos.git`

3. Import the package into your target.

4. Add the following keys to your `Info.plist`:
    * `NSPhotoLibraryUsageDescription`
    * `NSPhotoLibraryAddUsageDescription`

## Public functions

### PhotosSensor

+ `init(_ config: PhotosSensor.Config)`: Initializes the sensor with the given configuration.
+ `start()`: Requests photo library authorization and registers as a PHPhotoLibraryChangeObserver.
+ `stop()`: Unregisters the photo library change observer.
+ `sync(force:)`: Syncs stored data to the configured host (PhotosData and PhotosRecognitionData tables are synced sequentially).
+ `set(label:)`: Sets a custom label applied to all subsequent data points.

### PhotosSensor.Config

Class to hold the configuration of the sensor.

#### Fields

+ `sensorObserver: PhotosObserver?`: Callback for live data updates.
+ `performRecognition: Bool`: If `true`, runs Vision image classification on newly captured images. (default = `true`)
+ `recognitionMinConfidence: Float`: Minimum Vision confidence threshold to store a result [0.0–1.0]. (default = `0.5`)
+ `recognitionImageSize: CGSize`: Pixel size of the thumbnail requested for Vision analysis. Smaller sizes are faster. (default = `640×640`)
+ `enabled: Bool`: Sensor is enabled or not. (default = `false`)
+ `debug: Bool`: Enable/disable logging. (default = `false`)
+ `label: String`: Label for the data. (default = "")
+ `deviceId: String`: Id of the device associated with the events. (default = "")
+ `dbEncryptionKey`: Encryption key for the database. (default = `nil`)
+ `dbType: Engine`: Which db engine to use for saving data. (default = `Engine.DatabaseType.NONE`)
+ `dbPath: String`: Path of the database. (default = "aware_photos")
+ `dbHost: String`: Host for syncing the database. (default = `nil`)

## Broadcasts

### Fired Broadcasts

+ `PhotosSensor.ACTION_AWARE_PHOTO_TAKEN`: fired when a new photo or video is added to the library.
+ `PhotosSensor.ACTION_AWARE_PHOTOS_RECOGNIZED`: fired when Vision classification results are available for a new image.

### Received Broadcasts

+ `PhotosSensor.ACTION_AWARE_PHOTOS_START`: received broadcast to start the sensor.
+ `PhotosSensor.ACTION_AWARE_PHOTOS_STOP`: received broadcast to stop the sensor.
+ `PhotosSensor.ACTION_AWARE_PHOTOS_SYNC`: received broadcast to send sync attempt to the host.
+ `PhotosSensor.ACTION_AWARE_PHOTOS_SET_LABEL`: received broadcast to set the data label. Label is expected in the `PhotosSensor.EXTRA_LABEL` field of the notification userInfo.

## Data Representations

### PhotosData

Contains metadata for a newly added photo or video asset.

| Field             | Type   | Description                                                         |
| ----------------- | ------ | ------------------------------------------------------------------- |
| localIdentifier   | String | PHAsset.localIdentifier — unique identifier within the photo library |
| mediaType         | Int    | PHMediaType raw value: 1=image, 2=video, 3=audio                   |
| mediaWidth        | Int    | Width of the asset in pixels                                        |
| mediaHeight       | Int    | Height of the asset in pixels                                       |
| creationTimestamp | Int64  | PHAsset.creationDate as Unix milliseconds                           |
| duration          | Double | Duration in seconds (non-zero for videos)                           |
| isFavorite        | Bool   | Whether the asset is marked as a favorite                           |
| label             | String | Customizable label. Useful for data calibration or traceability     |
| deviceId          | String | AWARE device UUID                                                   |
| timestamp         | Int64  | Unixtime milliseconds when the event was recorded                   |
| timezone          | Int    | Timezone of the device                                              |
| os                | String | Operating system of the device (iOS)                                |
| jsonVersion       | Int    | JSON schema version                                                 |

### PhotosRecognitionData

Contains Vision image classification results for a photo.

| Field               | Type   | Description                                                           |
| ------------------- | ------ | --------------------------------------------------------------------- |
| photoLocalIdentifier | String | Links to PhotosData.localIdentifier                                  |
| recognitionLabel    | String | Detected content label (e.g., "outdoor", "person", "plant")          |
| confidence          | Double | Confidence score [0.0–1.0]                                            |
| recognitionType     | String | Recognition method ("classification")                                |
| label               | String | Customizable label                                                    |
| deviceId            | String | AWARE device UUID                                                     |
| timestamp           | Int64  | Unixtime milliseconds when recognition was performed                  |
| timezone            | Int    | Timezone of the device                                                |
| os                  | String | Operating system of the device (iOS)                                  |
| jsonVersion         | Int    | JSON schema version                                                   |

## Example usage

```swift
import com_awareframework_ios_sensor_photos
```

```swift
let sensor = PhotosSensor(PhotosSensor.Config().apply { config in
    config.sensorObserver = Observer()
    config.performRecognition = true
    config.recognitionMinConfidence = 0.6
    config.debug = true
})

sensor.start()

// Later...
sensor.stop()
```

```swift
class Observer: PhotosObserver {
    func onPhotoTaken(data: PhotosData) {
        print("New asset:", data.localIdentifier, "type:", data.mediaType)
    }

    func onImageRecognized(data: PhotosRecognitionData) {
        print("Recognized:", data.recognitionLabel, "confidence:", data.confidence)
    }
}
```

## Author
Yuuki Nishiyama (The University of Tokyo), nishiyama@csis.u-tokyo.ac.jp

## Related Links
* [Apple | Photos](https://developer.apple.com/documentation/photos)
* [Apple | Vision](https://developer.apple.com/documentation/vision)
* [Apple | VNClassifyImageRequest](https://developer.apple.com/documentation/vision/vnclassifyimagerequest)

## License
Copyright (c) 2018 AWARE Mobile Context Instrumentation Middleware/Framework (http://www.awareframework.com)

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.