//
//  Jukebox.swift
//  Jukebox-Demo
//
//  Created by Teodor Patras on 27/08/15.
//  Copyright (c) 2015 Teodor Patras. All rights reserved.
//

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
    func jukeboxDidFinishAppendingItem(jukebox : Jukebox, item : JukeboxItem)
}

/// Because KVO does not work on pure Swift objects, Jukebox inherits from NSObject
public class Jukebox : NSObject {
    
    // MARK:- Properties -
    private var player          :   AVQueuePlayer?
    private var progressTimer   :   NSTimer?
    private var playIndex       :   Int         = -1
    private var queuedItems                     = [JukeboxItem]()
    
    public var delegate         :   JukeboxDelegate?
    public var currentItem      :   JukeboxItem?
    public var state            :   JukeboxState = .Ready
    public var volume           :   Float
    {
        get {
            return self.player?.volume ?? 0
        }
        set {
            self.player?.volume = newValue
        }
    }
    
    // MARK:- Initializer -
    
    public convenience init(delegate : JukeboxDelegate?) {
        self.init(delegate: delegate, itemURLs: [])
    }
    
    public required init (delegate : JukeboxDelegate?, itemURLs : [NSURL]) {
        self.delegate = delegate
        super.init()
        
        // prepare the audio session
        AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, error: nil)
        AVAudioSession.sharedInstance().setActive(true, error: nil)
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        
        // append items, if any
        
        if itemURLs.count > 0 {
            self.state = .Loading
            self.delegate?.jukeboxStateDidChange(self)
        }
        
        for (index, url) in enumerate(itemURLs) {
            self.loadAndAppendItem(JukeboxItem(url: url), completion:{item in
                if index == 0 {
                    // first
                    self.currentItem = item
                } else if (index == itemURLs.count - 1) {
                    // last
                    self.state = .Ready
                    self.delegate?.jukeboxStateDidChange(self)
                }
            })
        }
    }
    
    
    deinit{
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK:- KVO -
    
    public override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if keyPath == "currentItem" {
            if self.player?.currentItem != nil {
                var old: AVPlayerItem? = change["old"] as? AVPlayerItem
                var new: AVPlayerItem? = change["new"] as? AVPlayerItem
                
                if let new = change["new"] as? AVPlayerItem {
                    for (index, jItem) in enumerate(self.queuedItems) {
                        if jItem.playerItem == new {
                            self.currentItem = jItem
                            self.playIndex = index
                            break
                        }
                    }
                }
            }
        }
    }
    
    // MARK:- Public methods -
    
    /**
    Starts playing from the items queue in FIFO order. Call this method only if you previously added at least one item to the queue.
    */
    public func play() {
        
        if (self.player == nil || self.currentItem == nil) {
            return
        }
        
        self.player?.play()
        self.state = .Playing
        self.scheduleProgressTimer()
        self.delegate?.jukeboxStateDidChange(self)
    }
    
    /**
    Configures the jukebox with one item to begin with and starts playing
    
    :param: item the first item to be played
    */
    public func playSingleItem(item : JukeboxItem) {
        
        self.currentItem = item
        
        self.loadAndAppendItem(item, completion: { _ in
            self.play()
        })
        
        self.state = .Loading
        self.delegate?.jukeboxStateDidChange(self)
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
        NSNotificationCenter.defaultCenter().removeObserver(self)
        
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
        self.play()
    }
    
    /**
    Plays the next item in the queue
    */
    public func playNext() {
        if (self.player == nil || self.currentItem == nil) {
            return
        }
        
        if self.playIndex + 1 < self.queuedItems.count {
            //self.playItemAtIndex(self.playIndex + 1)
            self.player?.advanceToNextItem()
        }
    }
    
    /**
    Restarts the current item or plays the previous item in the queue
    */
    public func playPrevious() {
        if (self.player == nil || self.currentItem == nil) {
            return
        }
        
        if self.queuedItems.count > 0{
            
            if let time = self.currentItem?.currentTime  {
                if time <= 1 && self.playIndex - 1 >= 0 {
                    self.playItemAtIndex(playIndex - 1)
                } else  {
                    self.seekToSecond(0)
                }
            }
        }
    }
    
    /**
    Seeks to a certain second within the current AVPlayerItem that is playing
    
    :param: second the second to be seek to
    */
    public func seekToSecond(second: Int) {
        if (self.player == nil || self.currentItem == nil) {
            return
        }
        
        if let player = self.player, let item = self.currentItem {
            player.seekToTime(CMTimeMake(Int64(second), 1))
            item.updateWithPlayerItem(player.currentItem)
            self.delegate?.jukeboxPlaybackProgressDidChange(self)
            player.play()
        }
    }
    
    /**
    Appends a new item to the queue
    
    :param: item the item to be appended
    */
    public func enqueueItem(item : JukeboxItem) {
        self.loadAndAppendItem(item, completion: nil)
    }
    
    // MARK:- Progress tracking -
    
    private func scheduleProgressTimer(){
        
        var timerInterval : Double = 0.3
        
        if let rate = self.player?.rate {
            timerInterval = 1 / Double(rate)
        }
        self.progressTimer = NSTimer.scheduledTimerWithTimeInterval(timerInterval, target: self, selector: "timerAction", userInfo: nil, repeats: true)
    }
    
    private func stopProgressTimer() {
        self.progressTimer?.invalidate()
        self.progressTimer = nil
    }
    
    // MARK:- Internal methods -
    
    func loadAndAppendItem(item : JukeboxItem, completion : ((item : JukeboxItem) -> ())?) {
        let asset = AVURLAsset(URL: item.URL, options: nil)
        
        // duration, tracks
        asset.loadValuesAsynchronouslyForKeys(["playable", "duration"], completionHandler: { () -> Void in
                dispatch_async(dispatch_get_main_queue()) {
                    
                    if self.player == nil {
                        self.player = AVQueuePlayer()
                        self.player?.actionAtItemEnd = .Advance
                        self.player?.addObserver(self, forKeyPath: "currentItem", options: .New | .Old, context: nil)
                        self.configureObservers()
                        
                        self.playIndex = 0
                        self.queuedItems = [JukeboxItem]()
                    }
                    
                    self.appendItem(item, asset: asset)
                    completion?(item: item)
                }
        })
    }
    
    func appendItem(item : JukeboxItem, asset: AVAsset) {
        
        if let player = self.player {
            
            checkItemAlreadyExists(item)
            
            let playerItem = AVPlayerItem(asset: asset)
            item.updateWithPlayerItem(playerItem)
            
            self.queuedItems.append(item)
            
            if player.canInsertItem(playerItem, afterItem: nil){
                player.insertItem(playerItem, afterItem: nil)
                self.delegate?.jukeboxDidFinishAppendingItem(self, item: item)
            }
        }
    }
    
    func playItemAtIndex(index: Int) {
        if let player = self.player {
            if self.queuedItems.count > index {
                player.removeAllItems()
                player.pause()
                for var i = index; i < self.queuedItems.count; i++ {
                    if let item = self.queuedItems[i].playerItem {
                        if player.canInsertItem(item, afterItem: nil) {
                            item.seekToTime(kCMTimeZero)
                            player.insertItem(item, afterItem: nil)
                        }
                    }
                }
                player.play()
            }
        }
    }
    
    func configureObservers() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleStall", name: AVPlayerItemPlaybackStalledNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "aPlaybackEnded", name: AVPlayerItemDidPlayToEndTimeNotification, object: nil)
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
    
    func aPlaybackEnded(){
        
        if playIndex == self.queuedItems.count - 1 {
            // playback done
            self.stop()
        }
    }
    
    func timerAction() {
        if let item = self.player?.currentItem {
            self.currentItem?.updateWithPlayerItem(item)
            if let progress = self.currentItem?.currentTime {
                self.delegate?.jukeboxPlaybackProgressDidChange(self)
            }
            
            if self.currentItem?.currentTime == self.currentItem?.duration
            {
                self.stop()
            }
        }
    }
}

public class JukeboxItem {
    // MARK:- Properties -
    
    let URL         :  NSURL
    
    // meta
    private(set) var duration    :   Double?
    private(set) var currentTime :   Double?
    private(set) var title       :   String?
    private(set) var album       :   String?
    private(set) var artist      :   String?
    private(set) var artwork     :   UIImage?
    
    private(set) var playerItem : AVPlayerItem?
    
    // MARK:- Initializer -
    
    public required init(url : NSURL) {
        URL = url
        if URL.isFileReferenceURL()
        {
            self.configureMetadata()
        }
    }
    
    // MARK:- Public methods -
    
    func updateWithPlayerItem(item : AVPlayerItem) {
        
        if let asset = item.asset as? AVURLAsset
        {
           assert(self.URL == asset.URL, "URL mismatch!")
            
            if self.playerItem == nil {
                self.playerItem = item
            }
            
            duration = CMTimeGetSeconds(item.asset.duration)
            currentTime = CMTimeGetSeconds(item.currentTime())
        }
    }
    
    // MARK:- Private methods -
    
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
