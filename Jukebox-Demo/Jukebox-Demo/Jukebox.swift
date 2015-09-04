//
// Jukebox.swift
//
// Copyright (c) 2015 Teodor Patraş
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import AVFoundation
import UIKit

public enum JukeboxState : Int, Printable {
    case Ready = 0
    case Playing
    case Paused
    case Loading
    case Failed
    
    public var description: String {
        get{
            switch self
            {
            case Ready:
                return "Ready"
            case Playing:
                return "Playing"
            case Failed:
                return "Failed"
            case Paused:
                return "Paused"
            case Loading:
                return "Loading"
                
            }
        }
    }
}

public protocol JukeboxDelegate {
    func jukeboxStateDidChange(jukebox : Jukebox)
    func jukeboxPlaybackProgressDidChange(jukebox : Jukebox)
    func jukeboxDidLoadItem(jukebox : Jukebox, item : JukeboxItem)
}

/// Because KVO does not work on pure Swift objects, Jukebox inherits from NSObject
public class Jukebox : NSObject, JukeboxItemDelegate {
    
    // MARK:- Properties -
    private var player              :   AVPlayer?
    private var progressObserver    :   AnyObject!
    private var playIndex           :   Int         = -1
    private var queuedItems                         = [JukeboxItem]()

    public var delegate             :   JukeboxDelegate?
    public var currentItem          :   JukeboxItem?
    public var state                :   JukeboxState = .Ready
    public var volume               :   Float
        {
        get {
            return self.player?.volume ?? 0
        }
        set {
            self.player?.volume = newValue
        }
    }
    
    // MARK:- Initializer -
    
    /**
    Create an instance with a delegate and an empty play queue
    
    :param: delegate jukebox delegate
    
    :returns: Jukebox instance
    */
    public convenience init(delegate : JukeboxDelegate?) {
        self.init(delegate: delegate, items: [])
    }
    
    /**
    Create an instance with a delegate and a list of items without loading their assets.
    
    :param: delegate jukebox delegate
    :param: items    array of items to be added to the play queue
    
    :returns: Jukebox instance
    */
    public required init (delegate : JukeboxDelegate?, items : [JukeboxItem]) {
        self.delegate = delegate
        super.init()
        
        self.configureObservers()
        
        // prepare the audio session
        AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, error: nil)
        AVAudioSession.sharedInstance().setActive(true, error: nil)
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        
        self.queuedItems = items
        for item in self.queuedItems {
            item.delegate = self
        }
    }
    
    deinit{
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK:- JukeboxItemDelegate -
    
    public func jukeboxItemDidLoadPlayerItem(item: JukeboxItem) {
        println("Item loaded: \(item)")
        self.delegate?.jukeboxDidLoadItem(self, item: item)
        let index = find(self.queuedItems, item)
        
        if let playItem = item.playerItem
            where self.state == .Loading && playIndex == index {
                self.playItem(playItem)
                NSNotificationCenter.defaultCenter().addObserver(self, selector: "playerItemDidReachEnd:", name: AVPlayerItemDidPlayToEndTimeNotification, object: playItem)
        }
    }
    
    // MARK:- Public methods -
    
    /**
    Removes an item from the play queue
    
    :param: item item to be removed
    */
    public func removeItem(item : JukeboxItem) {
        self.removeItemWithURL(item.URL)
    }
    
    /**
    Removes an item from the play queue based on URL
    
    :param: url the item URL
    */
    public func removeItemWithURL(url : NSURL) {
        var index = -1
        
        for (idx, item) in enumerate(queuedItems) {
            if item.URL == url {
                index = idx
                break
            }
        }
        
        if index > -1 {
            self.queuedItems.removeAtIndex(index)
        }
    }
    
    /**
    Appends and optionally loads an item
    
    :param: item            the item to be appended to the play queue
    :param: loadingAssets   flag indicating wether or not the item should load it's assets
    */
    public func appendItem(item : JukeboxItem, loadingAssets : Bool) {
        self.checkItemAlreadyExists(item)
        self.queuedItems.append(item)
        item.delegate = self
        if loadingAssets {
            item.loadPlayerItem()
        }
    }
    
    /**
    Plays the item indicated by the passed index
    
    :param: index index of the item to be played
    */
    public func playAtIndex(index : Int) {
        if (index > self.queuedItems.count - 1) {
            return
        }
        
        if let item = self.queuedItems[index].playerItem where self.playIndex == index{
            if self.state == .Paused {
                // resume playing
                self.state = .Playing
                self.player?.play()
                self.delegate?.jukeboxStateDidChange(self)
            }
            return
        }
        
        self.playIndex = index
        if let item = self.currentItem?.playerItem {
            NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemDidPlayToEndTimeNotification, object: item)
        }
        self.currentItem = self.queuedItems[index]
        
        if let asset = self.queuedItems[index].playerItem?.asset {
            
            self.queuedItems[index].refreshPlayerItem(asset)
            self.playItem(self.queuedItems[index].playerItem!)
            /* Observe when the player item has played to its end time */
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "playerItemDidReachEnd:", name: AVPlayerItemDidPlayToEndTimeNotification, object: self.queuedItems[index].playerItem!)
        } else {
            self.stopProgressTimer()
            self.player?.pause()
            self.queuedItems[index].loadPlayerItem()
            self.state = .Loading
            self.delegate?.jukeboxStateDidChange(self)
        }
        
        /**
        *  preload next and previous
        */
        if index - 1 >= 0 {
            self.queuedItems[index - 1].loadPlayerItem()
        }
        
        if index + 1 < self.queuedItems.count {
            self.queuedItems[index + 1].loadPlayerItem()
        }
    }
    
    /**
    Starts playing from the items queue in FIFO order. Call this method only if you previously added at least one item to the queue.
    */
    public func play() {
        
        if (self.playIndex < 0 || self.playIndex >= self.queuedItems.count) {
            return
        }
        self.playAtIndex(self.playIndex)
    }
    
    /**
    Pauses the playback
    */
    public func pause() {
        if (self.player == nil || self.currentItem == nil) {
            return
        }
        
        self.player?.pause()
        self.state = .Paused
        self.stopProgressTimer()
        self.delegate?.jukeboxStateDidChange(self)
    }
    
    /**
    Stops the playback and deallocates most resources
    */
    public func stop() {
        
        if (self.player == nil || self.currentItem == nil) {
            return
        }
        
        self.stopProgressTimer()
        self.player?.pause()
        self.player = nil
        self.currentItem = nil
        self.playIndex = -1
        
        self.state = .Ready
        self.delegate?.jukeboxStateDidChange(self)
    }
    
    /**
    Replays the current item
    */
    public func replay()
    {
        if (self.player == nil || self.currentItem == nil) {
            return
        }
        self.stopProgressTimer()
        self.seekToSecond(0)
        self.playAtIndex(0)
    }
    
    /**
    Plays the next item in the queue
    */
    public func playNext() {
        if (self.player == nil || self.currentItem == nil) {
            return
        }
        
        if self.playIndex >= 0 && playIndex + 1 < self.queuedItems.count {
            self.playAtIndex(playIndex  + 1)
        }
    }
    
    /**
    Restarts the current item or plays the previous item in the queue
    */
    public func playPrevious() {
        if (self.player == nil || self.currentItem == nil) {
            return
        }
        
        if self.currentItem?.currentTime > 1 {
            self.seekToSecond(0)
        } else if playIndex - 1 >= 0 {
            self.playAtIndex(playIndex - 1)
        }
    }
    
    /**
    Seeks to a certain second within the current AVPlayerItem and starts playing
    
    :param: second the second to be seek to
    */
    public func seekToSecond(second: Int) {
        self.seekToSecond(second, shouldPlay: true)
    }
    
    // MARK:- Private methods -
    
    private func playItem(item : AVPlayerItem) {
        
        // Get rid of old data
        self.stopProgressTimer()
        self.player?.pause()
        self.player = nil
        
        // Configure player
        self.player = AVPlayer(playerItem: item)
        
        // Configure time observer
        self.startProgressTimer()
        
        // Play & Update state
        player!.seekToTime(CMTimeMake(Int64(0), 1))
        player!.play()
        self.state = .Playing
        self.delegate?.jukeboxStateDidChange(self)
    }
    
    private func seekToSecond(second : Int, shouldPlay: Bool) {
        if (self.player == nil || self.currentItem == nil) {
            return
        }
        
        if let player = self.player, let item = self.currentItem {
            player.seekToTime(CMTimeMake(Int64(second), 1))
            item.update()
            self.delegate?.jukeboxPlaybackProgressDidChange(self)
            if shouldPlay {
                player.play()
            }
        }
    }
    
    // MARK:- Progress tracking -
    
    private func startProgressTimer(){
        if let player = self.player {
            if player.currentItem.duration.isValid {
                self.progressObserver = player.addPeriodicTimeObserverForInterval(CMTimeMakeWithSeconds(0.1, Int32(NSEC_PER_SEC)), queue: nil, usingBlock: { [unowned self] (time : CMTime) -> Void in
                    self.timerAction()
                    })
            }
        }
    }
    
    private func stopProgressTimer() {
        if let player = self.player, let observer: AnyObject = self.progressObserver{
            player.removeTimeObserver(observer)
            self.progressObserver = nil
        }
    }
    
    // MARK:- Internal methods -
    
    func configureObservers() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleStall", name: AVPlayerItemPlaybackStalledNotification, object: nil)
    }
    
    func checkItemAlreadyExists(item : JukeboxItem) {
        for jItem in self.queuedItems {
            assert(item.URL != jItem.URL, "Cannot append the same item to the Jukebox queue! Only unique items are allowed!")
        }
    }
    
    // MARK:- Notifications -
    
    func handleStall() {
        self.player?.pause()
        self.player?.play()
    }
    
    func playerItemDidReachEnd(notification : NSNotification){
        
        if playIndex >= self.queuedItems.count - 1 {
            self.stop()
        } else {
            self.playAtIndex(self.playIndex + 1)
        }
    }
    
    func timerAction() {
        if let item = self.player?.currentItem {
            self.currentItem?.update()
            if let progress = self.currentItem?.currentTime {
                self.delegate?.jukeboxPlaybackProgressDidChange(self)
            }
        }
    }
}

@objc public protocol JukeboxItemDelegate {
    func jukeboxItemDidLoadPlayerItem(item : JukeboxItem)
}

public class JukeboxItem : NSObject, Printable {
    // MARK:- Properties -
    
    public let URL         :  NSURL
    public var localTitle  :  String?
    
    // meta
    private(set) var duration    :   Double?
    private(set) var currentTime :   Double?
    private(set) var title       :   String?
    private(set) var album       :   String?
    private(set) var artist      :   String?
    private(set) var artwork     :   UIImage?
    private      var delegate    :   JukeboxItemDelegate?
    private      var didLoad   :   Bool = false
    
    private var  playerItem : AVPlayerItem?
    
    public override var description: String {
        get{
            return "<\(self.localTitle)> : <\(self.URL.absoluteString)>"
        }
    }
    
    // MARK:- Initializer -
    
    public required init(url : NSURL) {
        URL = url
        super.init()
        if URL.isFileReferenceURL()
        {
            self.configureMetadata()
        }
    }
    
    // MARK:- Private methods -
    
    private func refreshPlayerItem(asset : AVAsset) {
        self.playerItem = AVPlayerItem(asset: asset)
        self.update()
    }
    
    private func loadPlayerItem () {
        
        if let item = self.playerItem {
            self.refreshPlayerItem(item.asset)
            self.delegate?.jukeboxItemDidLoadPlayerItem(self)
            return
        } else {
            if didLoad {
                return
            } else {
                didLoad = true
            }
        }
        
        let asset = AVURLAsset(URL: self.URL, options: nil)
        
        // duration, tracks
        asset.loadValuesAsynchronouslyForKeys(["playable", "duration"], completionHandler: { () -> Void in
            dispatch_async(dispatch_get_main_queue()) {
                self.refreshPlayerItem(asset)
                self.delegate?.jukeboxItemDidLoadPlayerItem(self)
            }
        })
    }
    
    private func update() {
        if let item = self.playerItem {
            duration = CMTimeGetSeconds(item.asset.duration)
            currentTime = CMTimeGetSeconds(item.currentTime())
        }
    }
    
    private func configureMetadata()
    {
        let metadataArray = AVPlayerItem(URL: self.URL).asset.commonMetadata as! [AVMetadataItem]
        
        for item in metadataArray
        {
            item.loadValuesAsynchronouslyForKeys([AVMetadataKeySpaceCommon], completionHandler: { () -> Void in
                switch item.commonKey
                {
                case "title" :
                    self.title = item.value as? String
                case "albumName" :
                    self.album = item.value as? String
                case "artist" :
                    self.artist = item.value as? String
                case "artwork" :
                    let copiedValue: AnyObject = item.value.copyWithZone(nil)
                    
                    if let dict = copiedValue as? [NSObject : AnyObject] {
                        //AVMetadataKeySpaceID3
                        if let imageData = dict["data"] as? NSData {
                            self.artwork = UIImage(data: imageData)
                        }
                    } else if let data = copiedValue as? NSData
                    {
                        //AVMetadataKeySpaceiTunes
                        self.artwork = UIImage(data: data)
                    }
                default :
                    break
                }
            })
        }
    }
}

private extension CMTime {
    var isValid : Bool { return (flags & .Valid) != nil }
}
