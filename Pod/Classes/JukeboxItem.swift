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
}

public class JukeboxItem {
    
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
    
    // MARK:- Initializer -
    
    /**
    Create an instance with an URL and local title
    
    - parameter URL: local or remote URL of the audio file
    - parameter localTitle: an optional title for the file
    
    - returns: Jukebox instance
    */
    public required init(URL : NSURL, localTitle : String? = nil) {
        self.URL = URL
        self.identifier = NSUUID().UUIDString
        self.localTitle = localTitle
        if URL.filePathURL != nil{
            // local file
            self.configureMetadata()
        }
    }
    
    // MARK: - Internal methods -
    
    func loadPlayerItem () {
        
        if let item = self.playerItem {
            self.refreshPlayerItem(item.asset)
            self.delegate?.jukeboxItemDidLoadPlayerItem(self)
            return
        } else if didLoad {
            return
        } else {
            didLoad = true
        }
        
        loadAsync { (asset) -> () in
            self.validateAsset(asset)
            self.refreshPlayerItem(asset)
            self.delegate?.jukeboxItemDidLoadPlayerItem(self)
        }
    }
    
    func refreshPlayerItem(asset : AVAsset) {
        self.playerItem = AVPlayerItem(asset: asset)
        update()
    }
    
    func update() {
        if let item = self.playerItem {
            duration = CMTimeGetSeconds(item.asset.duration)
            currentTime = CMTimeGetSeconds(item.currentTime())
        }
    }
    
    // MARK:- Private methods -
    
    private func validateAsset(asset : AVURLAsset) {
        var e : NSError?
        asset.statusOfValueForKey("duration", error: &e)
        if let error = e {
            var message = "\n\n***** Jukebox fatal error*****\n\n"
            if error.code == -1022 {
                message += "It looks like you're using Xcode 7 and due to an App Transport Security issue (absence of SSL-based HTTP) the asset cannot be loaded from the specified URL: \"\(self.URL)\".\nTo fix this issue, append the following to your .plist file:\n\n<key>NSAppTransportSecurity</key>\n<dict>\n\t<key>NSAllowsArbitraryLoads</key>\n\t<true/>\n</dict>\n\n"
                fatalError(message)
            } else {
                fatalError("\(message)\(error.description)\n\n")
            }
        }
    }
    
    private func loadAsync(completion : (asset : AVURLAsset) -> ()) {
        let asset = AVURLAsset(URL: self.URL, options: nil)
        
        asset.loadValuesAsynchronouslyForKeys(["duration"], completionHandler: { () -> Void in
            dispatch_async(dispatch_get_main_queue()) {
                completion(asset: asset)
            }
        })
    }
    
    private func configureMetadata()
    {
        let metadataArray = AVPlayerItem(URL: self.URL).asset.commonMetadata
        
        for item in metadataArray
        {
            item.loadValuesAsynchronouslyForKeys([AVMetadataKeySpaceCommon], completionHandler: { () -> Void in
                switch item.commonKey
                {
                case "title"? :
                    self.title = item.value as? String
                case "albumName"? :
                    self.album = item.value as? String
                case "artist"? :
                    self.artist = item.value as? String
                case "artwork"? :
                    self.processArtwork(forMetadataItem : item)
                default :
                    break
                }
            })
        }
    }
    
    private func processArtwork(forMetadataItem item : AVMetadataItem) {
        guard let value = item.value else {return;}
        let copiedValue: AnyObject = value.copyWithZone(nil)
        
        if let dict = copiedValue as? [NSObject : AnyObject] {
            //AVMetadataKeySpaceID3
            if let imageData = dict["data"] as? NSData {
                self.artwork = UIImage(data: imageData)
            }
        } else if let data = copiedValue as? NSData{
            //AVMetadataKeySpaceiTunes
            self.artwork = UIImage(data: data)
        }
    }
}