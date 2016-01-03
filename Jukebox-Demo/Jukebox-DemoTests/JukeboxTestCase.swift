//
//  JukeboxTestCase.swift
//  Jukebox-Demo
//
//  Created by Teodor Patras on 03/01/16.
//  Copyright © 2016 Teodor Patras. All rights reserved.
//

import XCTest

class JukeboxTestCase: XCTestCase {

    let firstURL = NSURL(string: "http://www.maninblack.org/demos/02%20The%20NYC%20(There%20Will%20Always%20Be).mp3")!
    let secondURL = NSURL(string: "http://www.maninblack.org/demos/We%20Are%20The%20Gonads.mp3")!
    
    func after (time : Double, execute : dispatch_block_t) {
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(time * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue(), execute)
    }

}
