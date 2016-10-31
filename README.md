![Jukebox: audio player in Swift](https://raw.githubusercontent.com/teodorpatras/Jukebox/master/assets/jukebox.png)

![Swift3](https://img.shields.io/badge/Swift-3.0-orange.svg?style=flat")
[![Platform](https://img.shields.io/cocoapods/p/Jukebox.svg?style=flat)](http://cocoapods.org/pods/Jukebox)
[![Build Status](https://travis-ci.org/teodorpatras/Jukebox.svg)](https://travis-ci.org/teodorpatras/Jukebox)
[![Version](https://img.shields.io/cocoapods/v/Jukebox.svg?style=flat)](http://cocoapods.org/pods/Jukebox)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/cocoapods/l/Jukebox.svg?style=flat)](http://cocoapods.org/pods/Jukebox)

Jukebox is an iOS audio player written in Swift.

# Contents
1. [Features](#features)
3. [Installation](#installation)
4. [Supported OS & SDK versions](#supported-versions)
5. [Usage](#usage)
6. [Handling remote events](#remote-events)
7. [Public interface](#public-interface)
8. [Delegation](#delegation)
9. [License](#license)
10. [Contact](#contact)

##<a name="features"> Features </a>

- [x] Support for streaming both remote and local audio files
- [x] Support for streaming live audio feeds
- [x] Functions to ``play``, ``pause``, ``stop``, ``replay``, ``play next``, ``play previous``, ``control volume`` and ``seek`` to a certain second.
- [x] Background mode integration with ``MPNowPlayingInfoCenter``

<a name="installation"> Installation </a>
--------------

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects.

CocoaPods 0.36 adds supports for Swift and embedded frameworks. You can install it with the following command:

```bash
$ gem install cocoapods
```

To integrate ``Jukebox`` into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'Jukebox'
```

Then, run the following command:

```bash
$ pod install
```

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate `Jukebox` into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "teodorpatras/Jukebox"
```

Run `carthage update` to build the framework and drag the built `Jukebox.framework` into your Xcode project.

### Manually

If you prefer not to use either of the aforementioned dependency managers, you can integrate Jukebox into your project manually.

##<a name="supported-versions"> Supported OS & SDK versions </a>

- iOS 8.0+
- Xcode 7+

##<a name="usage"> Usage </a>

### Prerequisites

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

### Getting started

1) Create an instance of ``Jukebox``:

```swift
// configure jukebox
jukebox = Jukebox(delegate: self, items: [
    JukeboxItem(URL: NSURL(string: "http://www.noiseaddicts.com/samples_1w72b820/2514.mp3")!),
    JukeboxItem(URL: NSURL(string: "http://www.noiseaddicts.com/samples_1w72b820/2958.mp3")!)
    ])
```

2) Play and enjoy:

```swift
jukebox?.play()
```

##<a name="remote-events"> Handling remote events </a>

In order to handle remote events, you should do the following:

* First, you need to call for receiving remote events:

`UIApplication.sharedApplication().beginReceivingRemoteControlEvents()`

* Secondly, override `remoteControlReceivedWithEvent(event:)`:

```
override func remoteControlReceived(with event: UIEvent?) {
    if event?.type == .remoteControl {
        switch event!.subtype {
        case .remoteControlPlay :
            jukebox.play()
        case .remoteControlPause :
            jukebox.pause()
        case .remoteControlNextTrack :
            jukebox.playNext()
        case .remoteControlPreviousTrack:
            jukebox.playPrevious()
        case .remoteControlTogglePlayPause:
            if jukebox.state == .playing {
               jukebox.pause()
            } else {
                jukebox.play()
            }
        default:
            break
        }
    }
}
```

##<a name="public-interface">Public interface </a>

##Public methods##
```
/**
 Starts item playback.
*/
public func play()
    
/**
Plays the item indicated by the passed index
     
 - parameter index: index of the item to be played
*/
public func play(atIndex index: Int)
    
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
public func seek(toSecond second: Int, shouldPlay: Bool = false)
    
/**
 Appends and optionally loads an item
     
 - parameter item:            the item to be appended to the play queue
 - parameter loadingAssets:   pass true to load item's assets asynchronously
*/
public func append(item: JukeboxItem, loadingAssets: Bool)

/**
 Removes an item from the play queue
    
 - parameter item: item to be removed
*/
public func remove(item: JukeboxItem)
    
/**
 Removes all items from the play queue matching the URL
     
 - parameter url: the item URL
*/
public func removeItems(withURL url : URL)
```

##Public properties##

| Property   |      Type      | Description |
|----------|-------------|------|
|`volume`| `Float` | volume of the player |
| `currentItem` | `JukeboxItem` | object encapsulating the meta of the current player item |

##<a name="delegation"> Delegation </a>

`Jukebox` defines a delegate protocol which you can use if you want to be announced when about custom events:

```
public protocol JukeboxDelegate: class {
    func jukeboxStateDidChange(_ state : Jukebox)
    func jukeboxPlaybackProgressDidChange(_ jukebox : Jukebox)
    func jukeboxDidLoadItem(_ jukebox : Jukebox, item : JukeboxItem)
    func jukeboxDidUpdateMetadata(_ jukebox : Jukebox, forItem: JukeboxItem)
}
```

##<a name="license"> License </a>

```Jukebox``` is released under the MIT license. See the ```LICENSE``` file for details.

##<a name="contact"> Contact </a>

You can follow or drop me a line on [my Twitter account](https://twitter.com/teodorpatras). If you find any issues on the project, you can open a ticket. Pull requests are also welcome.
