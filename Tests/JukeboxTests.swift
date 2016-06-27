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
        let jukebox = Jukebox(delegate: nil, items: [JukeboxItem(URL: firstURL), JukeboxItem(URL: secondURL)])
        
        XCTAssertNotNil(jukebox.currentItem)
        XCTAssert(jukebox.state == .Ready)
        XCTAssert(jukebox.queuedItems.count == 2)
    }
    
    func testJukeboxDoesNotPlay() {
        let jukebox = Jukebox()
        jukebox.append(item: JukeboxItem(URL: self.firstURL), loadingAssets: true)
        
        let expectation = self.expectationWithDescription("Jukebox does not play")
        
        after(3) { () -> Void in
            XCTAssert(jukebox.state == .Ready, "Jukebox should not auto play after loading item!")
            expectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
    }
    
    func testJukeboxCurrentItem_playFromFirst() {
        let jukebox = Jukebox(delegate: nil, items: [JukeboxItem(URL: firstURL)])
        jukebox.play()
        
        jukebox.append(item: JukeboxItem(URL: self.secondURL), loadingAssets: false)
        
        let expectation = self.expectationWithDescription("Jukebox Plays")
        
        after(3) { () -> Void in
            XCTAssertEqual(jukebox.currentItem!.URL, self.firstURL)
            XCTAssert(jukebox.queuedItems.count == 2)
            
            for _ in 1...2 {
                jukebox.playNext()
                
                XCTAssertNotNil(jukebox.currentItem)
                XCTAssertEqual(jukebox.currentItem!.URL, self.secondURL, "Next item should always be \(self.secondURL), no matter how many times playNext() is called!")
            }
            
            expectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
    }
    
    func testJukeboxCurrentItem_playFromLast() {
        let jukebox = Jukebox(delegate: nil, items: [JukeboxItem(URL: firstURL)])
        jukebox.append(item: JukeboxItem(URL: secondURL), loadingAssets: true)
        jukebox.play(atIndex: 1)
        
        let expectation = self.expectationWithDescription("Jukebox Plays")
        
        after(3) { () -> Void in
            XCTAssertEqual(jukebox.currentItem!.URL, self.secondURL)
            XCTAssert(jukebox.queuedItems.count == 2)
            
            for _ in 1...2 {
                jukebox.playPrevious()
                
                XCTAssertNotNil(jukebox.currentItem)
                XCTAssertEqual(jukebox.currentItem!.URL, self.firstURL,"Next item should always be \(self.firstURL), no matter how many times playNext() is called!")
            }
            
            expectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
    }
}
