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

    let firstURL = URL(string: "http://www.noiseaddicts.com/samples_1w72b820/2514.mp3")!
    let secondURL = URL(string: "http://www.noiseaddicts.com/samples_1w72b820/2958.mp3")!
    
    func after (_ time : Double, execute : @escaping ()->()) {
        let delayTime = DispatchTime.now() + Double(Int64(time * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: delayTime, execute: execute)
    }

}
