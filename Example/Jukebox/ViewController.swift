//
//  ViewController.swift
//  Jukebox-Demo
//
//  Created by Teodor Patras on 27/08/15.
//  Copyright (c) 2015 Teodor Patras. All rights reserved.
//

import Foundation
import UIKit
import MediaPlayer
import Jukebox

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
        
        // configure jukebox
        self.jukebox = Jukebox(delegate: self, items: [
            JukeboxItem(URL: NSURL(string: "http://www.noiseaddicts.com/samples_1w72b820/2514.mp3")!),
            JukeboxItem(URL: NSURL(string: "http://www.noiseaddicts.com/samples_1w72b820/2958.mp3")!)
            ])
        
        /// Later add another item
        let delay = dispatch_time(DISPATCH_TIME_NOW, Int64(3 * Double(NSEC_PER_SEC)))
        dispatch_after(delay, dispatch_get_main_queue()) {
            self.jukebox?.appendItem(JukeboxItem (URL: NSURL(string: "http://www.noiseaddicts.com/samples_1w72b820/2228.mp3")!), loadingAssets: true)
        }
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    func configureUI ()
    {
        
        UIApplication.sharedApplication().setStatusBarHidden(true, withAnimation: .None)
        
        self.resetUI()
        
        let color = UIColor(red:0.84, green:0.09, blue:0.1, alpha:1)
        
        self.indicator.color = color
        self.slider.setThumbImage(UIImage(named: "sliderThumb"), forState: .Normal)
        self.slider.minimumTrackTintColor = color
        self.slider.maximumTrackTintColor = UIColor.blackColor()
        
        self.volumeSlider.minimumTrackTintColor = color
        self.volumeSlider.maximumTrackTintColor = UIColor.blackColor()
        self.volumeSlider.thumbTintColor = color
        
        self.titleLabel.textColor =  color
        
        self.centerContainer.layer.cornerRadius = 12
        self.view.backgroundColor = UIColor.blackColor()
    }
    
    // MARK:- JukeboxDelegate -
    
    func jukeboxDidLoadItem(jukebox: Jukebox, item: JukeboxItem) {
        print("Jukebox did load: \(item.URL.lastPathComponent)")
    }
    
    func jukeboxPlaybackProgressDidChange(jukebox: Jukebox) {
        
        if let currentTime = jukebox.currentItem?.currentTime, let duration = jukebox.currentItem?.duration  {
            let value = Float(currentTime / duration)
            self.slider.value = value
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
        
        print("Jukebox state changed to \(jukebox.state)")
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
        if let state = self.jukebox?.state {
            switch state {
            case .Ready :
                self.jukebox?.playAtIndex(0)
            case .Playing :
                self.jukebox?.pause()
            case .Paused :
                self.jukebox?.play()
            default:
                self.jukebox?.stop()
            }
        }
    }
    
    override func remoteControlReceivedWithEvent(event: UIEvent?) {
        if event?.type == .RemoteControl {
            switch event!.subtype {
            case .RemoteControlPlay :
                self.jukebox?.play()
            case .RemoteControlPause :
                self.jukebox?.pause()
            case .RemoteControlNextTrack :
                self.jukebox?.playNext()
            case .RemoteControlPreviousTrack:
                self.jukebox?.playPrevious()
            default:
                break
            }
        } else {
            print("NO EVENT!!!")
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
        
        label.text = String(format: "%02d", minutes) + ":" + String(format: "%02d", seconds)
    }
    
    
    func resetUI()
    {
        self.durationLabel.text = "00:00"
        self.currentTimeLabel.text = "00:00"
        self.slider.value = 0
    }
}

