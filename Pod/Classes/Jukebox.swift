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

// MARK: - Custom types -

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

// MARK: - Public methods extension -

extension Jukebox {
    
    /**
     Starts item playback.
     */
    public func play() {
        playAtIndex(self.playIndex)
    }
    
    /**
     Plays the item indicated by the passed index
     
     - parameter index: index of the item to be played
     */
    public func playAtIndex(index : Int) {
        guard index < self.queuedItems.count && index >= 0 else {return}
        
        configureBackgroundAudioTask()
        
        if self.queuedItems[index].playerItem != nil && self.playIndex == index {
            resumePlayback()
        } else {
            if let item = self.currentItem?.playerItem {
                unregisterForPlayToEndNotification(withItem: item)
            }
            self.playIndex = index
            
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
     Pauses the playback.
     */
    public func pause() {
        stopProgressTimer()
        self.player?.pause()
        self.state = .Paused
    }
    
    /**
     Stops the playback.
     */
    public func stop() {
        invalidatePlayback()
        self.state = .Ready
        UIApplication.sharedApplication().endBackgroundTask(self.backgroundIdentifier)
        self.backgroundIdentifier = UIBackgroundTaskInvalid
    }
    
    /**
     Starts playback from the beginning of the queue.
     */
    public func replay(){
        guard self.playerOperational else {return}
        stopProgressTimer()
        seekToSecond(0)
        playAtIndex(0)
    }
    
    /**
     Plays the next item in the queue.
     */
    public func playNext() {
        guard self.playerOperational else {return;}
        playAtIndex(self.playIndex  + 1)
    }
    
    /**
     Restarts the current item or plays the previous item in the queue
     */
    public func playPrevious() {
        guard self.playerOperational else {return}
        playAtIndex(self.playIndex - 1)
    }
    
    /**
     Restarts the playback for the current item
     */
    public func replayCurrentItem() {
        guard self.playerOperational else {return}
        seekToSecond(0, shouldPlay: true)
    }
    
    /**
     Seeks to a certain second within the current AVPlayerItem and starts playing
     
     - parameter second: the second to seek to
     - parameter shouldPlay: pass true if playback should be resumed after seeking
     */
    public func seekToSecond(second : Int, shouldPlay: Bool = false) {
        guard let player = self.player, let item = self.currentItem else {return}
        
        player.seekToTime(CMTimeMake(Int64(second), 1))
        item.update()
        if shouldPlay {
            player.play()
            if self.state != .Playing {
                self.state = .Playing
            }
        }
        self.delegate?.jukeboxPlaybackProgressDidChange(self)
    }
    
    /**
     Appends and optionally loads an item
     
     - parameter item:            the item to be appended to the play queue
     - parameter loadingAssets:   pass true to load item's assets asynchronously
     */
    public func appendItem(item : JukeboxItem, loadingAssets : Bool) {
        self.queuedItems.append(item)
        item.delegate = self
        if loadingAssets {
            item.loadPlayerItem()
        }
    }

    /**
    Removes an item from the play queue
    
    - parameter item: item to be removed
    */
    public func removeItem(item : JukeboxItem) {
        if let index = self.queuedItems.indexOf({$0.identifier == item.identifier}) {
            self.queuedItems.removeAtIndex(index)
        }
    }
    
    /**
     Removes all items from the play queue matching the URL
     
     - parameter url: the item URL
     */
    public func removeItems(withURL url : NSURL) {
        let indexes = self.queuedItems.indexesOf({$0.URL == url})
        for index in indexes {
            self.queuedItems.removeAtIndex(index)
        }
    }
}


// MARK: - Class implementation -

public class Jukebox : NSObject, JukeboxItemDelegate {
    
    // MARK:- Properties -
    
    private var player                       :   AVPlayer?
    private var progressObserver             :   AnyObject!
    private var backgroundIdentifier         =   UIBackgroundTaskInvalid
    private var delegate                     :   JukeboxDelegate?
    
    private (set) public var playIndex       =   0
    private (set) public var queuedItems     :   [JukeboxItem]!
    private (set) public var state           =   JukeboxState.Ready {
        didSet {
            self.delegate?.jukeboxStateDidChange(self)
        }
    }
    
    // MARK:  Computed
    
    public var volume : Float{
        get {
            return self.player?.volume ?? 0
        }
        set {
            self.player?.volume = newValue
        }
    }
    
    public var currentItem : JukeboxItem? {
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
    
    func jukeboxItemDidLoadPlayerItem(item: JukeboxItem) {
        self.delegate?.jukeboxDidLoadItem(self, item: item)
        let index = self.queuedItems.indexOf{$0 === item}
        
        guard let playItem = item.playerItem
            where self.state == .Loading && playIndex == index else {return}
        
        registerForPlayToEndNotification(withItem: playItem)
        startNewPlayer(forItem: playItem)
    }
    
    // MARK:- Private methods -
    
    // MARK: Playback
    
    private func updateInfoCenter() {
        guard let item = self.currentItem else {return}
        
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
    
    private func resumePlayback() {
        if self.state != .Playing {
            startProgressTimer()
            if let player = self.player {
                player.play()
            } else {
                self.currentItem!.refreshPlayerItem(self.currentItem!.playerItem!.asset)
                startNewPlayer(forItem: self.currentItem!.playerItem!)
            }
            self.state = .Playing
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
        seekToSecond(0, shouldPlay: true)
        updateInfoCenter()
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
            return
        }
        
        self.stopProgressTimer()
        self.player?.pause()
        self.queuedItems[self.playIndex].loadPlayerItem()
        self.state = .Loading
    }
    
    private func preloadNextAndPrevious(atIndex index: Int) {
        guard !self.queuedItems.isEmpty else {return}
        
        if index - 1 >= 0 {
            self.queuedItems[index - 1].loadPlayerItem()
        }
        
        if index + 1 < self.queuedItems.count {
            self.queuedItems[index + 1].loadPlayerItem()
        }
    }
    
    // MARK: Progress tracking
    
    private func startProgressTimer(){
        guard let player = self.player where player.currentItem?.duration.isValid == true else {return}
        self.progressObserver = player.addPeriodicTimeObserverForInterval(CMTimeMakeWithSeconds(0.05, Int32(NSEC_PER_SEC)), queue: nil, usingBlock: { [unowned self] (time : CMTime) -> Void in
            self.timerAction()
        })
    }
    
    private func stopProgressTimer() {
        guard let player = self.player, let observer = self.progressObserver else {
            return
        }
        player.removeTimeObserver(observer)
        self.progressObserver = nil
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
        guard self.player?.currentItem != nil else {return}
        self.currentItem?.update()
        guard self.currentItem?.currentTime != nil else {return}
        self.delegate?.jukeboxPlaybackProgressDidChange(self)
    }
    
    private func registerForPlayToEndNotification(withItem item: AVPlayerItem) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "playerItemDidPlayToEnd:", name: AVPlayerItemDidPlayToEndTimeNotification, object: item)
    }
    
    private func unregisterForPlayToEndNotification(withItem item : AVPlayerItem) {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemDidPlayToEndTimeNotification, object: item)
    }
}

private extension CollectionType {
    func indexesOf(@noescape predicate: (Self.Generator.Element) -> Bool) -> [Int] {
        var indexes = [Int]()
        for (index, item) in self.enumerate() {
            if predicate(item){
                indexes.append(index)
            }
        }
        return indexes
    }
}

private extension CMTime {
    var isValid : Bool { return (flags.intersect(.Valid)) != [] }
}
