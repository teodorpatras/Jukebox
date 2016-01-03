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
import MediaPlayer

public enum JukeboxState : Int, CustomStringConvertible {
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

public protocol JukeboxDelegate : class {
    func jukeboxStateDidChange(jukebox : Jukebox)
    func jukeboxPlaybackProgressDidChange(jukebox : Jukebox)
    func jukeboxDidLoadItem(jukebox : Jukebox, item : JukeboxItem)
}

public class Jukebox : NSObject, JukeboxItemDelegate {
    
    // MARK:- Properties -
    
    private var player                :   AVPlayer?
    private var progressObserver      :   AnyObject!
    private var playIndex             =   0
    private var backgroundIdentifier  =   UIBackgroundTaskInvalid
    
    private (set) public var queuedItems      :   [JukeboxItem]!
    private (set) public var delegate         :   JukeboxDelegate?
    private (set) public var state            =   JukeboxState.Ready {
        didSet {
            self.delegate?.jukeboxStateDidChange(self)
        }
    }
    
    public var volume :   Float
        {
        get {
            return self.player?.volume ?? 0
        }
        set {
            self.player?.volume = newValue
        }
    }
    
    // MARK:  Computed
    
    public var currentItem  :   JukeboxItem? {
        guard self.playIndex >= 0 && self.playIndex < self.queuedItems.count else {
            return nil
        }
        return self.queuedItems[self.playIndex]
    }
    
    private var playerOperational : Bool {
        return self.player != nil && self.currentItem != nil
    }
    
    // MARK:- Initializer -
    
    /**
    Create an instance with a delegate and a list of items without loading their assets.
    
    - parameter delegate: jukebox delegate
    - parameter items:    array of items to be added to the play queue
    
    - returns: Jukebox instance
    */
    public required init (delegate : JukeboxDelegate? = nil, items : [JukeboxItem] = [JukeboxItem]()) {
        self.delegate = delegate
        super.init()
        assignQueuedItems(items)
        configureObservers()
        configureAudioSession()
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
    }
    
    deinit{
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK:- JukeboxItemDelegate -
    
    public func jukeboxItemDidLoadPlayerItem(item: JukeboxItem) {
        
        self.delegate?.jukeboxDidLoadItem(self, item: item)
        let index = self.queuedItems.indexOf{$0 === item}
        
        guard let playItem = item.playerItem
            where self.state == .Loading && playIndex == index else {return;}
        
        registerForPlayToEndNotification(withItem: playItem)
        startNewPlayer(forItem: playItem)
    }
    
    // MARK:- Public methods -
    
    /**
    Removes an item from the play queue
    
    - parameter item: item to be removed
    */
    public func removeItem(item : JukeboxItem) {
        removeItemWithURL(item.URL)
    }
    
    /**
    Removes an item from the play queue based on URL
    
    - parameter url: the item URL
    */
    public func removeItemWithURL(url : NSURL) {
        guard let index = self.queuedItems.indexOf({$0.URL == url}) else {return;}
        self.queuedItems.removeAtIndex(index)
    }
    
    /**
    Appends and optionally loads an item
    
    - parameter item:            the item to be appended to the play queue
    - parameter loadingAssets:   flag indicating wether or not the item should load it's assets
    */
    public func appendItem(item : JukeboxItem, loadingAssets : Bool) {
        checkItemAlreadyExists(item)
        self.queuedItems.append(item)
        item.delegate = self
        if loadingAssets {
            item.loadPlayerItem()
        }
    }
    
    /**
    Plays the item indicated by the passed index
    
    - parameter index: index of the item to be played
    */
    public func playAtIndex(index : Int) {
        guard index < self.queuedItems.count && index >= 0 else {return;}
        
        configureBackgroundAudioTask()
        
        if self.queuedItems[index].playerItem != nil && self.playIndex == index {
            resumePlaying()
        } else {
            self.playIndex = index
            if let item = self.currentItem?.playerItem {
                unregisterForPlayToEndNotification(withItem: item)
            }
            
            if let asset = self.queuedItems[index].playerItem?.asset {
                playCurrentItemWithAsset(asset)
            } else {
                loadPlaybackItem()
            }
            
            preloadNextAndPrevious(atIndex: self.playIndex)
        }
        updateInfoCenter()
    }
    
    /**
    Starts playing from the items queue in FIFO order. Call this method only if you previously added at least one item to the queue.
    */
    public func play() {
        playAtIndex(self.playIndex)
    }
    
    /**
    Pauses the playback
    */
    public func pause() {
        stopProgressTimer()
        self.player?.pause()
        self.state = .Paused
    }
    
    /**
    Stops the playback
    */
    public func stop() {
        invalidatePlayback()
        self.state = .Ready
        UIApplication.sharedApplication().endBackgroundTask(self.backgroundIdentifier)
        self.backgroundIdentifier = UIBackgroundTaskInvalid
    }
    
    /**
    Starts playback from the beginning of the queue
    */
    public func replay(){
        guard self.playerOperational else {return;}
        stopProgressTimer()
        seekToSecond(0)
        playAtIndex(0)
    }
    
    /**
    Plays the next item in the queue
    */
    public func playNext() {
        guard self.playerOperational else {
            print("EXiting...\(self.player) :: \(self.currentItem)")
            return;
        }
        playAtIndex(self.playIndex  + 1)
    }
    
    /**
    Restarts the current item or plays the previous item in the queue
    */
    public func playPrevious() {
        guard self.playerOperational else {return;}
        
        if self.currentItem?.currentTime > 5 {
            seekToSecond(0)
        } else {
            playAtIndex(self.playIndex - 1)
        }
    }
    
    /**
    Seeks to a certain second within the current AVPlayerItem and starts playing
    
    - parameter second: the second to seek to
    */
    public func seekToSecond(second: Int) {
        seekToSecond(second, autoPlay: true)
    }
    
    // MARK:- Private methods -
    
    // MARK: Playback
    
    private func updateInfoCenter() {
        
        guard let item = self.currentItem else {return;}
        
        let title = (item.title ?? item.localTitle) ?? item.URL.lastPathComponent!
        let currentTime = item.currentTime ?? 0
        let duration = item.duration ?? 0
        let trackNumber = self.playIndex
        let trackCount = self.queuedItems.count
        
        var nowPlayingInfo : [String : AnyObject] = [
            MPMediaItemPropertyPlaybackDuration : duration,
            MPMediaItemPropertyTitle : title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime : currentTime,
            MPNowPlayingInfoPropertyPlaybackQueueCount :trackCount,
            MPNowPlayingInfoPropertyPlaybackQueueIndex : trackNumber,
            MPMediaItemPropertyMediaType : MPMediaType.AnyAudio.rawValue
        ]
        
        if let artist = item.artist {
            nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        }
        
        if let album = item.album {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        }
        
        if let img = self.currentItem?.artwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: img)
        }
        
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = nowPlayingInfo
    }
    
    private func playCurrentItemWithAsset(asset : AVAsset) {
        self.queuedItems[self.playIndex].refreshPlayerItem(asset)
        startNewPlayer(forItem: self.queuedItems[self.playIndex].playerItem!)
        guard let playItem = self.queuedItems[self.playIndex].playerItem else {return;}
        registerForPlayToEndNotification(withItem: playItem)
    }
    
    private func resumePlaying() {
        if self.state == .Paused {
            startProgressTimer()
            self.state = .Playing
            self.player?.play()
        }
    }
    
    private func invalidatePlayback(resetIndex resetIndex : Bool = true) {
        stopProgressTimer()
        self.player?.pause()
        self.player = nil
        
        if resetIndex {
            self.playIndex = 0
        }
    }
    
    private func startNewPlayer(forItem item : AVPlayerItem) {
        invalidatePlayback(resetIndex: false)
        self.player = AVPlayer(playerItem: item)
        self.player?.allowsExternalPlayback = false
        startProgressTimer()
        seekToSecond(0)
        updateInfoCenter()
    }
    
    private func seekToSecond(second : Int, autoPlay: Bool) {
        guard let player = self.player, let item = self.currentItem else {return;}
        
        player.seekToTime(CMTimeMake(Int64(second), 1))
        item.update()
        if autoPlay {
            player.play()
            self.state = .Playing
        }
        self.delegate?.jukeboxPlaybackProgressDidChange(self)
    }
    
    // MARK: Items related
    
    private func assignQueuedItems (items : [JukeboxItem]) {
        self.queuedItems = items
        for item in self.queuedItems {
            item.delegate = self
        }
    }
    
    private func loadPlaybackItem() {
        guard self.playIndex >= 0 && self.playIndex < self.queuedItems.count else {
            return;
        }
        self.stopProgressTimer()
        self.player?.pause()
        self.queuedItems[self.playIndex].loadPlayerItem()
        self.state = .Loading
    }
    
    private func preloadNextAndPrevious(atIndex index: Int) {
        guard !self.queuedItems.isEmpty else {return;}
        
        if index - 1 >= 0 {
            self.queuedItems[index - 1].loadPlayerItem()
        }
        
        if index + 1 < self.queuedItems.count {
            self.queuedItems[index + 1].loadPlayerItem()
        }
    }
    
    // MARK: Progress tracking
    
    private func startProgressTimer(){
        guard let player = self.player where player.currentItem?.duration.isValid == true else {return;}
        self.progressObserver = player.addPeriodicTimeObserverForInterval(CMTimeMakeWithSeconds(0.05, Int32(NSEC_PER_SEC)), queue: nil, usingBlock: { [unowned self] (time : CMTime) -> Void in
            self.timerAction()
        })
    }
    
    private func stopProgressTimer() {
        if let player = self.player, let observer: AnyObject = self.progressObserver{
            player.removeTimeObserver(observer)
            self.progressObserver = nil
        }
    }
    
    // MARK: Configurations
    
    private func configureBackgroundAudioTask() {
        self.backgroundIdentifier =  UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler { () -> Void in
            UIApplication.sharedApplication().endBackgroundTask(self.backgroundIdentifier)
            self.backgroundIdentifier = UIBackgroundTaskInvalid
        }
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            fatalError("Could not open the audio session, hence Jukebox is unusable!")
        }
    }
    
    private func configureObservers() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleStall", name: AVPlayerItemPlaybackStalledNotification, object: nil)
    }
    
    // MARK: Validations
    
    private func checkItemAlreadyExists(item : JukeboxItem) {
        for jItem in self.queuedItems {
            guard item.URL != jItem.URL else {
                fatalError("Cannot append the same item <\(item)> to the Jukebox queue! Only unique items are allowed!")
            }
        }
    }
    
    // MARK:- Notifications -
    
    func handleStall() {
        self.player?.pause()
        self.player?.play()
    }
    
    func playerItemDidPlayToEnd(notification : NSNotification){
        
        if playIndex >= self.queuedItems.count - 1 {
            stop()
        } else {
            playAtIndex(self.playIndex + 1)
        }
    }
    
    func timerAction() {
        guard self.player?.currentItem != nil else {return;}
        self.currentItem?.update()
        guard self.currentItem?.currentTime != nil else {return;}
        self.delegate?.jukeboxPlaybackProgressDidChange(self)
    }
    
    private func registerForPlayToEndNotification(withItem item: AVPlayerItem) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "playerItemDidPlayToEnd:", name: AVPlayerItemDidPlayToEndTimeNotification, object: item)
    }
    
    private func unregisterForPlayToEndNotification(withItem item : AVPlayerItem) {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemDidPlayToEndTimeNotification, object: item)
    }
}


private extension CMTime {
    var isValid : Bool { return (flags.intersect(.Valid)) != [] }
}
