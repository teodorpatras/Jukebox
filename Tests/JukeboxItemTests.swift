//
//  JukeboxItemTests.swift
//  Jukebox-Demo
//
//  Created by Teodor Patras on 03/01/16.
//  Copyright © 2016 Teodor Patras. All rights reserved.
//

import XCTest
import CoreMedia
@testable import Jukebox

class JukeboxItemTests: JukeboxTestCase {
    
    func testAssetLoading() {
        let item = JukeboxItem(URL: self.firstURL as URL)
        
        item.loadPlayerItem()
        
        let expectation = self.expectation(description: "Item loaded")
        
        after(time: 5) { () -> Void in
            XCTAssertNotNil(item.playerItem)
            XCTAssert(CMTimeGetSeconds(item.playerItem!.asset.duration) > 0)
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 7, handler: nil)
    }
    
    func testAssetLoading_redundantCalls() {
        let item = JukeboxItem(URL: self.secondURL as URL)
        
        item.loadPlayerItem()
        // redundant calls
        item.loadPlayerItem()
        item.loadPlayerItem()
        item.loadPlayerItem()
        
        let expectation = self.expectation(description: "Item loaded")
        
        after(time: 5) { () -> Void in
            XCTAssertNotNil(item.playerItem)
            XCTAssert(CMTimeGetSeconds(item.playerItem!.asset.duration) > 0)
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 7, handler: nil)
    }
}
