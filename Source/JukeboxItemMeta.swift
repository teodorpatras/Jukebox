//
//  JukeboxMeta.swift
//  Jukebox
//
//  Created by Merrick Sapsford on 13/03/2017.
//  Copyright © 2017 teodorpatras. All rights reserved.
//

import Foundation

public extension JukeboxItem {
    
    /// Item Metadata
    public class Meta: Any {
        
        /// The duration of the item
        internal(set) public var duration: Double?
        /// The title of the item.
        internal(set) public var title: String?
        /// The album name of the item.
        internal(set) public var album: String?
        /// The artist name of the item.
        internal(set) public var artist: String?
        /// Album artwork for the item.
        internal(set) public var artwork: UIImage?
    }
    
    /// Builder for custom Metadata
    public class MetaBuilder: Meta {
        public typealias MetaBuilderClosure = (MetaBuilder) -> ()
        
        // MARK: Properties
        
        private var _title: String?
        public override var title: String? {
            get {
                return _title
            } set (newTitle) {
                _title = newTitle
            }
        }
        
        private var _album: String?
        public override var album: String? {
            get {
                return _album
            } set (newAlbum) {
                _album = newAlbum
            }
        }
        
        private var _artist: String?
        public override var artist: String? {
            get {
                return _artist
            } set (newArtist) {
                _artist = newArtist
            }
        }
        
        private var _artwork: UIImage?
        public override var artwork: UIImage? {
            get {
                return _artwork
            } set (newArtwork) {
                _artwork = newArtwork
            }
        }
        
        // MARK: Init
        
        public init(_ build: MetaBuilderClosure) {
            super.init()
            build(self)
        }
    }
}
