//
//  Jukebox_DemoTests.swift
//  Jukebox-DemoTests
//
//  Created by Teodor Patras on 27/08/15.
//  Copyright (c) 2015 Teodor Patras. All rights reserved.
//

import XCTest
@testable import Jukebox

class JukeboxTests: JukeboxTestCase {
    
    func testJukeboxIntegrity() {
        let jukebox = Jukebox(delegate: nil, items: [JukeboxItem(URL: firstURL as URL), JukeboxItem(URL: secondURL as URL)])!
        
        XCTAssertNotNil(jukebox.currentItem)
        XCTAssert(jukebox.state == .ready)
        XCTAssert(jukebox.queuedItems.count == 2)
    }
    
    func testJukeboxDoesNotPlay() {
        let jukebox = Jukebox()!
        jukebox.append(item: JukeboxItem(URL: self.firstURL as URL), loadingAssets: true)
        
        let expectation = self.expectation(description: "Jukebox does not play")
        
        after(time: 3) { () -> Void in
            XCTAssert(jukebox.state == .ready, "Jukebox should not auto play after loading item!")
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testJukeboxCurrentItem_playFromFirst() {
        let jukebox = Jukebox(delegate: nil, items: [JukeboxItem(URL: firstURL as URL)])!
        jukebox.play()
        
        jukebox.append(item: JukeboxItem(URL: self.secondURL as URL), loadingAssets: false)
        
        let expectation = self.expectation(description: "Jukebox Plays")
        
        after(time: 3) { () -> Void in
            XCTAssertEqual(jukebox.currentItem!.URL, self.firstURL as URL)
            XCTAssert(jukebox.queuedItems.count == 2)
            
            for _ in 1...2 {
                jukebox.playNext()
                
                XCTAssertNotNil(jukebox.currentItem)
                XCTAssertEqual(jukebox.currentItem!.URL, self.secondURL as URL, "Next item should always be \(self.secondURL), no matter how many times playNext() is called!")
            }
            
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testJukeboxCurrentItem_playFromLast() {
        let jukebox = Jukebox(delegate: nil, items: [JukeboxItem(URL: firstURL as URL)])!
        jukebox.append(item: JukeboxItem(URL: (secondURL as NSURL) as URL), loadingAssets: true)
        jukebox.play(atIndex: 1)
        
        let expectation = self.expectation(description: "Jukebox Plays")
        
        after(time: 3) { () -> Void in
            XCTAssertEqual(jukebox.currentItem!.URL, self.secondURL as URL)
            XCTAssert(jukebox.queuedItems.count == 2)
            
            for _ in 1...2 {
                jukebox.playPrevious()
                
                XCTAssertNotNil(jukebox.currentItem)
                XCTAssertEqual(jukebox.currentItem!.URL, self.firstURL as URL,"Next item should always be \(self.firstURL), no matter how many times playNext() is called!")
            }
            
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 5, handler: nil)
    }
}
