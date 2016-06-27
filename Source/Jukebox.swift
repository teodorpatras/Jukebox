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

public protocol JukeboxDelegate: class {
    func jukeboxStateDidChange(state : Jukebox)
    func jukeboxPlaybackProgressDidChange(jukebox : Jukebox)
    func jukeboxDidLoadItem(jukebox : Jukebox, item : JukeboxItem)
    func jukeboxDidUpdateMetadata(jukebox : Jukebox, forItem: JukeboxItem)
}

// MARK: - Public methods extension -

extension Jukebox {
    
    /**
     Starts item playback.
     */
    public func play() {
        play(atIndex: playIndex)
    }
    
    /**
     Plays the item indicated by the passed index
     
     - parameter index: index of the item to be played
     */
    public func play(atIndex index: Int) {
        guard index < queuedItems.count && index >= 0 else {return}
        
        configureBackgroundAudioTask()
        
        if queuedItems[index].playerItem != nil && playIndex == index {
            resumePlayback()
        } else {
            if let item = currentItem?.playerItem {
                unregisterForPlayToEndNotification(withItem: item)
            }
            playIndex = index
            
            if let asset = queuedItems[index].playerItem?.asset {
                playCurrentItem(withAsset: asset)
            } else {
                loadPlaybackItem()
            }
            
            preloadNextAndPrevious(atIndex: playIndex)
        }
        updateInfoCenter()
    }
    
    /**
     Pauses the playback.
     */
    public func pause() {
        stopProgressTimer()
        player?.pause()
        state = .Paused
    }
    
    /**
     Stops the playback.
     */
    public func stop() {
        invalidatePlayback()
        state = .Ready
        UIApplication.sharedApplication().endBackgroundTask(backgroundIdentifier)
        backgroundIdentifier = UIBackgroundTaskInvalid
    }
    
    /**
     Starts playback from the beginning of the queue.
     */
    public func replay(){
        guard playerOperational else {return}
        stopProgressTimer()
        seek(toSecond: 0)
        play(atIndex: 0)
    }
    
    /**
     Plays the next item in the queue.
     */
    public func playNext() {
        guard playerOperational else {return}
        play(atIndex: playIndex + 1)
    }
    
    /**
     Restarts the current item or plays the previous item in the queue
     */
    public func playPrevious() {
        guard playerOperational else {return}
        play(atIndex: playIndex - 1)
    }
    
    /**
     Restarts the playback for the current item
     */
    public func replayCurrentItem() {
        guard playerOperational else {return}
        seek(toSecond: 0, shouldPlay: true)
    }
    
    /**
     Seeks to a certain second within the current AVPlayerItem and starts playing
     
     - parameter second: the second to seek to
     - parameter shouldPlay: pass true if playback should be resumed after seeking
     */
    public func seek(toSecond second: Int, shouldPlay: Bool = false) {
        guard let player = player, let item = currentItem else {return}
        
        player.seekToTime(CMTimeMake(Int64(second), 1))
        item.update()
        if shouldPlay {
            player.play()
            if state != .Playing {
                state = .Playing
            }
        }
        delegate?.jukeboxPlaybackProgressDidChange(self)
    }
    
    /**
     Appends and optionally loads an item
     
     - parameter item:            the item to be appended to the play queue
     - parameter loadingAssets:   pass true to load item's assets asynchronously
     */
    public func append(item item: JukeboxItem, loadingAssets: Bool) {
        queuedItems.append(item)
        item.delegate = self
        if loadingAssets {
            item.loadPlayerItem()
        }
    }

    /**
    Removes an item from the play queue
    
    - parameter item: item to be removed
    */
    public func remove(item item: JukeboxItem) {
        if let index = queuedItems.indexOf({$0.identifier == item.identifier}) {
            queuedItems.removeAtIndex(index)
        }
    }
    
    /**
     Removes all items from the play queue matching the URL
     
     - parameter url: the item URL
     */
    public func removeItems(withURL url : NSURL) {
        let indexes = queuedItems.indexesOf({$0.URL == url})
        for index in indexes {
            queuedItems.removeAtIndex(index)
        }
    }
}


// MARK: - Class implementation -

public class Jukebox: NSObject, JukeboxItemDelegate {
    
    public enum State: Int, CustomStringConvertible {
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
    
    // MARK:- Properties -
    
    private var player                       :   AVPlayer?
    private var progressObserver             :   AnyObject!
    private var backgroundIdentifier         =   UIBackgroundTaskInvalid
    private(set) public weak var delegate    :   JukeboxDelegate?
    
    private (set) public var playIndex       =   0
    private (set) public var queuedItems     :   [JukeboxItem]!
    private (set) public var state           =   State.Ready {
        didSet {
            delegate?.jukeboxStateDidChange(self)
        }
    }
    // MARK:  Computed
    
    public var volume: Float{
        get {
            return player?.volume ?? 0
        }
        set {
            player?.volume = newValue
        }
    }
    
    public var currentItem: JukeboxItem? {
        guard playIndex >= 0 && playIndex < queuedItems.count else {
            return nil
        }
        return queuedItems[playIndex]
    }
    
    private var playerOperational: Bool {
        return player != nil && currentItem != nil
    }
    
    // MARK:- Initializer -
    
    /**
    Create an instance with a delegate and a list of items without loading their assets.
    
    - parameter delegate: jukebox delegate
    - parameter items:    array of items to be added to the play queue
    
    - returns: Jukebox instance
    */
    public required init(delegate: JukeboxDelegate? = nil, items: [JukeboxItem] = [JukeboxItem]()) {
        self.delegate = delegate
        super.init()
        assignQueuedItems(items)
        configureObservers()
        configureAudioSession()
    }
    
    deinit{
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK:- JukeboxItemDelegate -
    
    func jukeboxItemDidUpdate(item: JukeboxItem) {
        guard let item = currentItem else {return}
        updateInfoCenter()
        self.delegate?.jukeboxDidUpdateMetadata(self, forItem: item)
    }
    
    func jukeboxItemDidLoadPlayerItem(item: JukeboxItem) {
        delegate?.jukeboxDidLoadItem(self, item: item)
        let index = queuedItems.indexOf{$0 === item}
        
        guard let playItem = item.playerItem
            where state == .Loading && playIndex == index else {return}
        
        registerForPlayToEndNotification(withItem: playItem)
        startNewPlayer(forItem: playItem)
    }
    
    // MARK:- Private methods -
    
    // MARK: Playback
    
    private func updateInfoCenter() {
        guard let item = currentItem else {return}
        
        let title = (item.title ?? item.localTitle) ?? item.URL.lastPathComponent!
        let currentTime = item.currentTime ?? 0
        let duration = item.duration ?? 0
        let trackNumber = playIndex
        let trackCount = queuedItems.count
        
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
        
        if let img = currentItem?.artwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: img)
        }
        
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = nowPlayingInfo
    }
    
    private func playCurrentItem(withAsset asset: AVAsset) {
        queuedItems[playIndex].refreshPlayerItem(withAsset: asset)
        startNewPlayer(forItem: queuedItems[playIndex].playerItem!)
        guard let playItem = queuedItems[playIndex].playerItem else {return}
        registerForPlayToEndNotification(withItem: playItem)
    }
    
    private func resumePlayback() {
        if state != .Playing {
            startProgressTimer()
            if let player = player {
                player.play()
            } else {
                currentItem!.refreshPlayerItem(withAsset: currentItem!.playerItem!.asset)
                startNewPlayer(forItem: currentItem!.playerItem!)
            }
            state = .Playing
        }
    }
    
    private func invalidatePlayback(shouldResetIndex resetIndex: Bool = true) {
        stopProgressTimer()
        player?.pause()
        player = nil
        
        if resetIndex {
            playIndex = 0
        }
    }
    
    private func startNewPlayer(forItem item : AVPlayerItem) {
        invalidatePlayback(shouldResetIndex: false)
        player = AVPlayer(playerItem: item)
        player?.allowsExternalPlayback = false
        startProgressTimer()
        seek(toSecond: 0, shouldPlay: true)
        updateInfoCenter()
    }
    
    // MARK: Items related
    
    private func assignQueuedItems (items: [JukeboxItem]) {
        queuedItems = items
        for item in queuedItems {
            item.delegate = self
        }
    }
    
    private func loadPlaybackItem() {
        guard playIndex >= 0 && playIndex < queuedItems.count else {
            return
        }
        
        stopProgressTimer()
        player?.pause()
        queuedItems[playIndex].loadPlayerItem()
        state = .Loading
    }
    
    private func preloadNextAndPrevious(atIndex index: Int) {
        guard !queuedItems.isEmpty else {return}
        
        if index - 1 >= 0 {
            queuedItems[index - 1].loadPlayerItem()
        }
        
        if index + 1 < queuedItems.count {
            queuedItems[index + 1].loadPlayerItem()
        }
    }
    
    // MARK: Progress tracking
    
    private func startProgressTimer(){
        guard let player = player where player.currentItem?.duration.isValid == true else {return}
        progressObserver = player.addPeriodicTimeObserverForInterval(CMTimeMakeWithSeconds(0.05, Int32(NSEC_PER_SEC)), queue: nil, usingBlock: { [unowned self] (time : CMTime) -> Void in
            self.timerAction()
        })
    }
    
    private func stopProgressTimer() {
        guard let player = player, let observer = progressObserver else {
            return
        }
        player.removeTimeObserver(observer)
        progressObserver = nil
    }
    
    // MARK: Configurations
    
    private func configureBackgroundAudioTask() {
        backgroundIdentifier =  UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler { () -> Void in
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
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Jukebox.handleStall), name: AVPlayerItemPlaybackStalledNotification, object: nil)
    }
    
    // MARK:- Notifications -
    
    func handleStall() {
        player?.pause()
        player?.play()
    }
    
    func playerItemDidPlayToEnd(notification : NSNotification){
        if playIndex >= queuedItems.count - 1 {
            stop()
        } else {
            play(atIndex: playIndex + 1)
        }
    }
    
    func timerAction() {
        guard player?.currentItem != nil else {return}
        currentItem?.update()
        guard currentItem?.currentTime != nil else {return}
        delegate?.jukeboxPlaybackProgressDidChange(self)
    }
    
    private func registerForPlayToEndNotification(withItem item: AVPlayerItem) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Jukebox.playerItemDidPlayToEnd(_:)), name: AVPlayerItemDidPlayToEndTimeNotification, object: item)
    }
    
    private func unregisterForPlayToEndNotification(withItem item : AVPlayerItem) {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemDidPlayToEndTimeNotification, object: item)
    }
}

private extension CollectionType {
    func indexesOf(@noescape predicate: (Generator.Element) -> Bool) -> [Int] {
        var indexes = [Int]()
        for (index, item) in enumerate() {
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
