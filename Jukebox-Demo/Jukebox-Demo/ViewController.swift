//
//  ViewController.swift
//  Jukebox-Demo
//
//  Created by Teodor Patras on 27/08/15.
//  Copyright (c) 2015 Teodor Patras. All rights reserved.
//

import Foundation
import UIKit

class ViewController: UIViewController, JukeboxDelegate {
   
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var replayButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var centerContainer: UIView!
    @IBOutlet weak var indicator: UIActivityIndicatorView!

    var jukebox : Jukebox?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.configureUI()

        jukebox = Jukebox(delegate: self, itemURLs: [NSURL(string: "http://megdadhashem.wapego.ru/files/56727/tubidy_mp3_e2afc5.mp3")!,
                                                     NSURL(string: "http://www.maninblack.org/demos/We%20Are%20The%20Gonads.mp3")!])
    }
    
    func configureUI ()
    {
        self.resetUI()
        
        let color = UIColor(hue:0.56, saturation:0.66, brightness:0.81, alpha:1)
        
        self.indicator.color = color
        self.slider.setThumbImage(UIImage(named: "sliderThumb"), forState: .Normal)
        self.slider.minimumTrackTintColor = color
        self.slider.maximumTrackTintColor = UIColor.blackColor()
        
        self.volumeSlider.minimumTrackTintColor = color
        self.volumeSlider.maximumTrackTintColor = UIColor.blackColor()
        
        self.titleLabel.textColor =  color
        
        self.centerContainer.layer.cornerRadius = 12
        self.view.backgroundColor = color
    }
    
    // MARK:- JukeboxDelegate -
    
    func jukeboxDidFinishAppendingItem(jukebox: Jukebox, item: JukeboxItem) {
        println("\n DID FINISH APPENDING: \t \(item.URL)")
    }
    
    func jukeboxPlaybackProgressDidChange(jukebox: Jukebox) {
        
        if let currentTime = jukebox.currentItem?.currentTime, let duration = jukebox.currentItem?.duration  {
            self.slider.value = Float(currentTime / duration)
            self.populateLabelWithTime(self.currentTimeLabel, time: currentTime)
            self.populateLabelWithTime(self.durationLabel, time: duration)
        }
    }
    
    func jukeboxStateDidChange(jukebox: Jukebox) {
        
        UIView.animateWithDuration(0.3, animations: { () -> Void in
            self.indicator.alpha = jukebox.state == .Loading ? 1 : 0
            self.playPauseButton.alpha = jukebox.state == .Loading ? 0 : 1
            self.playPauseButton.enabled = jukebox.state == .Loading ? false : true
        })
        
        if jukebox.state == .Ready {
            self.playPauseButton.setImage(UIImage(named: "playBtn"), forState: .Normal)
        } else if jukebox.state == .Loading  {
            self.playPauseButton.setImage(UIImage(named: "pauseBtn"), forState: .Normal)
        } else {
            self.volumeSlider.value = jukebox.volume
            self.playPauseButton.setImage(UIImage(named: jukebox.state == .Paused ? "playBtn" : "pauseBtn"), forState: .Normal)
        }
    }
    
    // MARK:- Callbacks -

    @IBAction func volumeSliderValueChanged() {
        if let jk = self.jukebox {
            jk.volume = self.volumeSlider.value
        }
    }
    
    @IBAction func progressSliderValueChanged() {
        if let duration = self.jukebox?.currentItem?.duration {
            self.jukebox?.seekToSecond(Int(Double(self.slider.value) * duration))
        }
    }
    
    @IBAction func prevAction() {
        self.jukebox?.playPrevious()
    }
    
    @IBAction func nextAction() {
        self.jukebox?.playNext()
    }
    
    
    @IBAction func playPauseAction() {
        if self.jukebox?.state == .Playing {
            self.jukebox?.pause()
        } else {
            if self.jukebox?.currentItem != nil {
                self.jukebox?.play()
            } else {
                jukebox?.playSingleItem(JukeboxItem(url: NSURL(string: "http://megdadhashem.wapego.ru/files/56727/tubidy_mp3_e2afc5.mp3")!))
                jukebox?.enqueueItem(JukeboxItem(url: NSURL(string: "http://www.maninblack.org/demos/We%20Are%20The%20Gonads.mp3")!))
            }
        }
    }
    
    @IBAction func replayAction() {
        self.resetUI()
        self.jukebox?.replay()
        
    }
    
    @IBAction func stopAction() {
        self.resetUI()
        self.jukebox?.stop()
    }
    
    // MARK:- Helpers -
    
    func populateLabelWithTime(label : UILabel, time: Double) {
        let minutes = Int(time / 60)
        let seconds = Int(time) - minutes * 60
        
        let secondsString = seconds >= 10 ? "\(seconds)" : "0\(seconds)"
        let minutesString = minutes >= 10 ? "\(minutes)" : "0\(minutes)"
        
        label.text = String(format: "%02d", minutes) + ":" + String(format: "%02d", seconds)
    }
    
    
    func resetUI()
    {
        self.durationLabel.text = "00:00"
        self.currentTimeLabel.text = "00:00"
        self.slider.value = 0
    }
}

