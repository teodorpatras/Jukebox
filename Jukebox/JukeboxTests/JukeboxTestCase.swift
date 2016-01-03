//
//  JukeboxTestCase.swift
//  Jukebox-Demo
//
//  Created by Teodor Patras on 03/01/16.
//  Copyright © 2016 Teodor Patras. All rights reserved.
//

import XCTest
import CoreMedia

class JukeboxTestCase: XCTestCase {

    let firstURL = NSURL(string: "http://www.noiseaddicts.com/samples_1w72b820/2514.mp3")!
    let secondURL = NSURL(string: "http://www.noiseaddicts.com/samples_1w72b820/2958.mp3")!
    
    func after (time : Double, execute : dispatch_block_t) {
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(time * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue(), execute)
    }

}
