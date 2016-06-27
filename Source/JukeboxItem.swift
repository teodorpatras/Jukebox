//
// JukeboxItem.swift
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

protocol JukeboxItemDelegate : class {
    func jukeboxItemDidLoadPlayerItem(item : JukeboxItem)
    func jukeboxItemDidUpdate(item: JukeboxItem)
}

public class JukeboxItem: NSObject {
    
    // MARK:- Properties -
    
            let identifier       :   String
            var delegate         :   JukeboxItemDelegate?
    private var didLoad          =   false
    public  var localTitle       :   String?
    public  let URL              :   NSURL
    
    private (set) public var playerItem  :   AVPlayerItem?
    
    // meta
    private (set) public var duration    :   Double?
    private (set) public var currentTime :   Double?
    private (set) public var title       :   String?
    private (set) public var album       :   String?
    private (set) public var artist      :   String?
    private (set) public var artwork     :   UIImage?
    
    private var timer: NSTimer?
    private let observedValue = "timedMetadata"
    
    // MARK:- Initializer -
    
    /**
    Create an instance with an URL and local title
    
    - parameter URL: local or remote URL of the audio file
    - parameter localTitle: an optional title for the file
    
    - returns: JukeboxItem instance
    */
    public required init(URL : NSURL, localTitle : String? = nil) {
        self.URL = URL
        self.identifier = NSUUID().UUIDString
        self.localTitle = localTitle
        super.init()
        configureMetadata()
    }
    
    override public func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        
        if keyPath == observedValue {
            if let item = playerItem where item === object {
                guard let metadata = item.timedMetadata else { return }
                for item in metadata {
                    process(metaItem: item)
                }
            }
            scheduleNotification()
        }
    }
    
    deinit {
        playerItem?.removeObserver(self, forKeyPath: observedValue)
    }
    
    // MARK: - Internal methods -
    
    func loadPlayerItem() {
        
        if let item = playerItem {
            refreshPlayerItem(withAsset: item.asset)
            delegate?.jukeboxItemDidLoadPlayerItem(self)
            return
        } else if didLoad {
            return
        } else {
            didLoad = true
        }
        
        loadAsync { (asset) -> () in
            if self.validateAsset(asset) {
                self.refreshPlayerItem(withAsset: asset)
                self.delegate?.jukeboxItemDidLoadPlayerItem(self)
            } else {
                self.didLoad = false
            }
        }
    }
    
    func refreshPlayerItem(withAsset asset: AVAsset) {
        playerItem?.removeObserver(self, forKeyPath: observedValue)
        playerItem = AVPlayerItem(asset: asset)
        playerItem?.addObserver(self, forKeyPath: observedValue, options: NSKeyValueObservingOptions.New, context: nil)
        update()
    }
    
    func update() {
        if let item = playerItem {
            duration = item.asset.duration.seconds
            currentTime = item.currentTime().seconds
        }
    }
    
    public override var description: String {
        return "<JukeboxItem:\ntitle: \(title)\nalbum: \(album)\nartist:\(artist)\nduration : \(duration),\ncurrentTime : \(currentTime)\nURL: \(URL)>"
    }
    
    // MARK:- Private methods -
    
    private func validateAsset(asset : AVURLAsset) -> Bool {
        var e: NSError?
        asset.statusOfValueForKey("duration", error: &e)
        if let error = e {
            var message = "\n\n***** Jukebox fatal error*****\n\n"
            if error.code == -1022 {
                message += "It looks like you're using Xcode 7 and due to an App Transport Security issue (absence of SSL-based HTTP) the asset cannot be loaded from the specified URL: \"\(URL)\".\nTo fix this issue, append the following to your .plist file:\n\n<key>NSAppTransportSecurity</key>\n<dict>\n\t<key>NSAllowsArbitraryLoads</key>\n\t<true/>\n</dict>\n\n"
                fatalError(message)
            }
            return false
        }
        return true
    }
    
    private func scheduleNotification() {
        timer?.invalidate()
        timer = nil
        timer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: #selector(JukeboxItem.notifyDelegate), userInfo: nil, repeats: false)
    }
    
    func notifyDelegate() {
        timer?.invalidate()
        timer = nil
        self.delegate?.jukeboxItemDidUpdate(self)
    }
    
    private func loadAsync(completion: (asset: AVURLAsset) -> ()) {
        let asset = AVURLAsset(URL: URL, options: nil)
        
        asset.loadValuesAsynchronouslyForKeys(["duration"], completionHandler: { () -> Void in
            dispatch_async(dispatch_get_main_queue()) {
                completion(asset: asset)
            }
        })
    }
    
    private func configureMetadata()
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let metadataArray = AVPlayerItem(URL: self.URL).asset.commonMetadata
            
            for item in metadataArray
            {
                item.loadValuesAsynchronouslyForKeys([AVMetadataKeySpaceCommon], completionHandler: { () -> Void in
                    self.process(metaItem: item)
                    dispatch_async(dispatch_get_main_queue(), {
                        self.scheduleNotification()
                    })
                })
            }
        }
    }
    
    private func process(metaItem item: AVMetadataItem) {
        switch item.commonKey
        {
        case "title"? :
            title = item.value as? String
        case "albumName"? :
            album = item.value as? String
        case "artist"? :
            artist = item.value as? String
        case "artwork"? :
            processArtwork(fromMetadataItem : item)
        default :
            break
        }
    }
    
    private func processArtwork(fromMetadataItem item: AVMetadataItem) {
        guard let value = item.value else {return}
        let copiedValue: AnyObject = value.copyWithZone(nil)
        
        if let dict = copiedValue as? [NSObject : AnyObject] {
            //AVMetadataKeySpaceID3
            if let imageData = dict["data"] as? NSData {
                artwork = UIImage(data: imageData)
            }
        } else if let data = copiedValue as? NSData{
            //AVMetadataKeySpaceiTunes
            artwork = UIImage(data: data)
        }
    }
}

private extension CMTime {
    var seconds: Double? {
        let time = CMTimeGetSeconds(self)
        guard time.isNaN == false else { return nil }
        return time
    }
}