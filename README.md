![Jukebox: audio player in Swift](https://raw.githubusercontent.com/teodorpatras/Jukebox/master/assets/jukebox.png)

Jukebox is an iOS audio player written in Swift.

## Features

- [x] Support for both remote and local audio files
- [x] Controls for ``play``, ``pause``, ``stop``, ``replay``, ``play next``, ``play previous``, ``volume control`` and ``seek`` to a certain second.
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

/// Later you can another item
let delay = dispatch_time(DISPATCH_TIME_NOW, Int64(5 * Double(NSEC_PER_SEC)))
dispatch_after(delay, dispatch_get_main_queue()) {
    self.jukebox?.appendItem(JukeboxItem (URL: NSURL(string: "http://www.noiseaddicts.com/samples_1w72b820/2228.mp3")!), loadingAssets: true)
}
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
public  let URL :   NSURL

private (set) public var playerItem  :   AVPlayerItem?

// meta
private (set) public var duration    :   Double?
private (set) public var currentTime :   Double?
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
private (set) public var queuedItems      :   [JukeboxItem]!
private (set) public var delegate         :   JukeboxDelegate?
private (set) public var state            :   JukeboxState

public var volume       :   Float
public var currentItem  :   JukeboxItem?
```

### Methods

```swift
/**
Create an instance with a delegate and a list of items without loading their assets.

- parameter delegate: jukebox delegate
- parameter items:    array of items to be added to the play queue

- returns: Jukebox instance
*/
public required init (delegate : JukeboxDelegate? = nil, items : [JukeboxItem] = [JukeboxItem]())

/**
Removes an item from the play queue

- parameter item: item to be removed
*/
public func removeItem(item : JukeboxItem)

/**
Removes an item from the play queue based on URL

- parameter url: the item URL
*/
public func removeItemWithURL(url : NSURL)

/**
Appends and optionally loads an item

- parameter item:            the item to be appended to the play queue
- parameter loadingAssets:   flag indicating wether or not the item should load it's assets
*/
public func appendItem(item : JukeboxItem, loadingAssets : Bool)

/**
Plays the item indicated by the passed index

- parameter index: index of the item to be played
*/
public func playAtIndex(index : Int)

/**
Starts playing from the items queue in FIFO order. Call this method only if you previously added at least one item to the queue.
*/
public func play()

/**
Pauses the playback
*/
public func pause()

/**
Stops the playback
*/
public func stop()

/**
Starts playback from the beginning of the queue
*/
public func replay()

/**
Plays the next item in the queue
*/
public func playNext()

/**
Restarts the current item if current item progress > 5s or plays the previous item in the queue
*/
public func playPrevious()

/**
Seeks to a certain second within the current AVPlayerItem and starts playing

- parameter second: the second to seek to
- parameter shouldPlay: flag indicating wether or not the playback should start after seeking
*/
public func seekToSecond(second : Int, shouldPlay: Bool = false)
```

## License

```Jukebox``` is released under the MIT license. See the ```LICENSE``` file for details.

## Contact

You can follow or drop me a line on [my Twitter account](https://twitter.com/teodorpatras). If you find any issues on the project, you can open a ticket. Pull requests are also welcome.
