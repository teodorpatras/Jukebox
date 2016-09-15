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
    func jukeboxItemDidLoadPlayerItem(_ item: JukeboxItem)
    func jukeboxItemDidUpdate(_ item: JukeboxItem)
    func jukeboxItemDidFail(_ item: JukeboxItem)
}

open class JukeboxItem: NSObject {
    
    public struct Meta {
        fileprivate(set) public var duration: Double?
        fileprivate(set) public var title: String?
        fileprivate(set) public var album: String?
        fileprivate(set) public var artist: String?
        fileprivate(set) public var artwork: UIImage?
    }
    
    // MARK:- Properties -
    
            let identifier: String
            var delegate: JukeboxItemDelegate?
    fileprivate var didLoad = false
    open  var localTitle: String?
    open  let URL: Foundation.URL
    
    fileprivate(set) open var playerItem: AVPlayerItem?
    fileprivate (set) open var currentTime: Double?
    fileprivate(set) open lazy var meta = Meta()

    
    fileprivate var timer: Timer?
    fileprivate let observedValue = "timedMetadata"
    
    // MARK:- Initializer -
    
    /**
    Create an instance with an URL and local title
    
    - parameter URL: local or remote URL of the audio file
    - parameter localTitle: an optional title for the file
    
    - returns: JukeboxItem instance
    */
    public required init(URL : Foundation.URL, localTitle : String? = nil) {
        self.URL = URL
        self.identifier = UUID().uuidString
        self.localTitle = localTitle
        super.init()
        configureMetadata()
    }
    
    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if change?[NSKeyValueChangeKey(rawValue:"name")] is NSNull {
            delegate?.jukeboxItemDidFail(self)
            return
        }
        
        if keyPath == observedValue {
            if let item = playerItem , item === object as? AVPlayerItem {
                guard let metadata = item.timedMetadata else { return }
                for item in metadata {
                    meta.process(metaItem: item)
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
        playerItem?.addObserver(self, forKeyPath: observedValue, options: NSKeyValueObservingOptions.new, context: nil)
        update()
    }
    
    func update() {
        if let item = playerItem {
            meta.duration = item.asset.duration.seconds
            currentTime = item.currentTime().seconds
        }
    }
    
    open override var description: String {
        return "<JukeboxItem:\ntitle: \(meta.title)\nalbum: \(meta.album)\nartist:\(meta.artist)\nduration : \(meta.duration),\ncurrentTime : \(currentTime)\nURL: \(URL)>"
    }
    
    // MARK:- Private methods -
    
    fileprivate func validateAsset(_ asset : AVURLAsset) -> Bool {
        var e: NSError?
        asset.statusOfValue(forKey: "duration", error: &e)
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
    
    fileprivate func scheduleNotification() {
        timer?.invalidate()
        timer = nil
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(JukeboxItem.notifyDelegate), userInfo: nil, repeats: false)
    }
    
    func notifyDelegate() {
        timer?.invalidate()
        timer = nil
        self.delegate?.jukeboxItemDidUpdate(self)
    }
    
    fileprivate func loadAsync(_ completion: @escaping (_ asset: AVURLAsset) -> ()) {
        let asset = AVURLAsset(url: URL, options: nil)
        
        asset.loadValuesAsynchronously(forKeys: ["duration"], completionHandler: { () -> Void in
            DispatchQueue.main.async {
                completion(asset)
            }
        })
    }
    
    fileprivate func configureMetadata()
    {
        
       DispatchQueue.global(qos: .background).async {
            let metadataArray = AVPlayerItem(url: self.URL).asset.commonMetadata
            
            for item in metadataArray
            {
                item.loadValuesAsynchronously(forKeys: [AVMetadataKeySpaceCommon], completionHandler: { () -> Void in
                    self.meta.process(metaItem: item)
                    DispatchQueue.main.async {
                        self.scheduleNotification()
                    }
                })
            }
        }
    }
}

private extension JukeboxItem.Meta {
    mutating func process(metaItem item: AVMetadataItem) {
        
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
    
    mutating func processArtwork(fromMetadataItem item: AVMetadataItem) {
        guard let value = item.value else { return }
        let copiedValue: AnyObject = value.copy(with: nil) as AnyObject
        
        if let dict = copiedValue as? [AnyHashable: Any] {
            //AVMetadataKeySpaceID3
            if let imageData = dict["data"] as? Data {
                artwork = UIImage(data: imageData)
            }
        } else if let data = copiedValue as? Data{
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
