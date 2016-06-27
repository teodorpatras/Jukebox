![Jukebox: audio player in Swift](https://raw.githubusercontent.com/teodorpatras/Jukebox/master/assets/jukebox.png)

[![Version](https://img.shields.io/cocoapods/v/Jukebox.svg?style=flat)](http://cocoapods.org/pods/Jukebox)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/cocoapods/l/Jukebox.svg?style=flat)](http://cocoapods.org/pods/Jukebox)
[![Platform](https://img.shields.io/cocoapods/p/Jukebox.svg?style=flat)](http://cocoapods.org/pods/Jukebox)
[![Build Status](https://travis-ci.org/teodorpatras/Jukebox.svg)](https://travis-ci.org/teodorpatras/Jukebox)

Jukebox is an iOS audio player written in Swift.

# Table of Contents
1. [Features](#features)
3. [Installation](#installation)
4. [Supported OS & SDK versions](#supported-versions)
5. [Usage](#usage)
6. [Handling remote events](#remote-events)
7. [Delegation] (#delegation)
8. [License](#license)
9. [Contact](#contact)

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
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
use_frameworks!

pod 'Jukebox', '~> 0.1.2'
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

If you prefer not to use either of the aforementioned dependency managers, you can integrate EasyTipView into your project manually.

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
jukebox.play()
```

##<a name="remote-events"> Handling remove events </a>

In order to handle remote events, you should do the following:

* First, you need to call for receiving remote events:

`UIApplication.sharedApplication().beginReceivingRemoteControlEvents()`

* Secondly, override `remoteControlReceivedWithEvent(event:)`:

```
override func remoteControlReceivedWithEvent(event: UIEvent?) {
    if event?.type == .RemoteControl {
        switch event!.subtype {
        case .RemoteControlPlay :
            jukebox.play()
        case .RemoteControlPause :
            jukebox.pause()
        case .RemoteControlNextTrack :
            jukebox.playNext()
        case .RemoteControlPreviousTrack:
            jukebox.playPrevious()
        case .RemoteControlTogglePlayPause:
            if jukebox.state == .Playing {
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

##<a name="delegation"> Delegation </a>

`Jukebox` defines a delegate protocol which you can use if you want to be announced when about custom events:

```
public protocol JukeboxDelegate: class {
    func jukeboxStateDidChange(state : Jukebox)
    func jukeboxPlaybackProgressDidChange(jukebox : Jukebox)
    func jukeboxDidLoadItem(jukebox : Jukebox, item : JukeboxItem)
    func jukeboxDidUpdateMetadata(jukebox : Jukebox, forItem: JukeboxItem)
}
```

##<a name="license"> License </a>

```Jukebox``` is released under the MIT license. See the ```LICENSE``` file for details.

##<a name="contact"> Contact </a>

You can follow or drop me a line on [my Twitter account](https://twitter.com/teodorpatras). If you find any issues on the project, you can open a ticket. Pull requests are also welcome.
