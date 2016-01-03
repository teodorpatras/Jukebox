![Jukebox: audio player in Swift](https://raw.githubusercontent.com/teodorpatras/Jukebox/master/assets/jukebox.png)

[![Version](https://img.shields.io/cocoapods/v/Jukebox.svg?style=flat)](http://cocoapods.org/pods/Jukebox)
[![License](https://img.shields.io/cocoapods/l/Jukebox.svg?style=flat)](http://cocoapods.org/pods/Jukebox)
[![Platform](https://img.shields.io/cocoapods/p/Jukebox.svg?style=flat)](http://cocoapods.org/pods/Jukebox)

Jukebox is an iOS audio player written in Swift.

## Features

- [x] Support for streaming both remote and local audio files
- [x] Functions to ``play``, ``pause``, ``stop``, ``replay``, ``play next``, ``play previous``, ``control volume`` and ``seek`` to a certain second.
- [x] Background mode integration with ``MPNowPlayingInfoCenter``


## Requirements

- iOS 8.0+
- Xcode 7+


Installation
--------------

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects.

CocoaPods 0.36 adds supports for Swift and embedded frameworks. You can install it with the following command:

```bash
$ gem install cocoapods
```

To integrate ``Jukebox`` into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
use_frameworks!

pod 'Jukebox', '~> 0.1.0'
```

Then, run the following command:

```bash
$ pod install
```
## Prerequisites

* In order to support background mode, append the following to your ``Info.plist``:

```
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```
* If you want to stream from ``http://`` URLs, append the following to your ``Info.plist``:
```
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
        <true/>
</dict>
```

## Usage

1) Create an instance of ``Jukebox``:
```swift
// configure jukebox
self.jukebox = Jukebox(delegate: self, items: [
    JukeboxItem(URL: NSURL(string: "http://www.noiseaddicts.com/samples_1w72b820/2514.mp3")!),
    JukeboxItem(URL: NSURL(string: "http://www.noiseaddicts.com/samples_1w72b820/2958.mp3")!)
    ])
```

2) Play and enjoy:

```swift
self.jukebox.play()
```

## Classes

JukeboxItem
--------------

Class which encapsulates an audio URL. This class is used in order to provision a ``Jukebox`` instance with playable items.

### Attributes

```swift
public var localTitle       :   String?
public let URL              :   NSURL

private (set) public var playerItem  :   AVPlayerItem?
// meta
private (set) public var duration    :   Double?
private (set) public var currentTime :   Double?
private (set) public var title       :   String?
private (set) public var album       :   String?
private (set) public var artist      :   String?
private (set) public var artwork     :   UIImage?
```

### Methods

```swift
/**
Create an instance with an URL and local title

- parameter URL: local or remote URL of the audio file
- parameter localTitle: an optional title for the file

- returns: Jukebox instance
*/
public required init(URL : NSURL, localTitle : String? = nil)
```



Jukebox
--------------

The main class responsible with the playback management.

### Custom types

```swift
public enum JukeboxState : Int, CustomStringConvertible {
    case Ready = 0
    case Playing
    case Paused
    case Loading
    case Failed
}
```

Defines the five possible states that ``Jukebox`` can be in.

```swift
public protocol JukeboxDelegate : class {
    func jukeboxStateDidChange(jukebox : Jukebox)
    func jukeboxPlaybackProgressDidChange(jukebox : Jukebox)
    func jukeboxDidLoadItem(jukebox : Jukebox, item : JukeboxItem)
}
```

Defines three methods to be implemented by the delegate in order to be notified when certain events occur.

### Attributes

```swift
private (set) public var queuedItems      :   [JukeboxItem]
private (set) public var state            :   JukeboxState
private (set) public var currentItem      :   JukeboxItem?
private (set) public var playIndex        =   Int
              public var volume           :   Float
```

### Methods

```swift
/**
Starts item playback.
*/
public func play()

/**
Plays the item indicated by the passed index

- parameter index: index of the item to be played
*/
public func playAtIndex(index : Int)

/**
Pauses the playback.
*/
public func pause()

/**
Stops the playback.
*/
public func stop()

/**
Starts playback from the beginning of the queue.
*/
public func replay()

/**
Plays the next item in the queue.
*/
public func playNext()

/**
Restarts the current item or plays the previous item in the queue
*/
public func playPrevious()

/**
Restarts the playback for the current item
*/
public func replayCurrentItem()

/**
Seeks to a certain second within the current AVPlayerItem and starts playing

- parameter second: the second to seek to
- parameter shouldPlay: pass true if playback should be resumed after seeking
*/
public func seekToSecond(second : Int, shouldPlay: Bool = false)

/**
Appends and optionally loads an item

- parameter item:            the item to be appended to the play queue
- parameter loadingAssets:   pass true to load item's assets asynchronously
*/
public func appendItem(item : JukeboxItem, loadingAssets : Bool)

/**
Removes an item from the play queue

- parameter item: item to be removed
*/
public func removeItem(item : JukeboxItem)

/**
 Removes all items from the play queue matching the URL

 - parameter url: the item URL
 */
public func removeItems(withURL url : NSURL)
```

## License

```Jukebox``` is released under the MIT license. See the ```LICENSE``` file for details.

## Contact

You can follow or drop me a line on [my Twitter account](https://twitter.com/teodorpatras). If you find any issues on the project, you can open a ticket. Pull requests are also welcome.
