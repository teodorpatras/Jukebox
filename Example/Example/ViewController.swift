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
    
    var jukebox : Jukebox!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        
        // begin receiving remote events
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        
        // configure jukebox
        jukebox = Jukebox(delegate: self, items: [
            JukeboxItem(URL: NSURL(string: "http://www.kissfm.ro/listen.pls")!),
            JukeboxItem(URL: NSURL(string: "http://www.noiseaddicts.com/samples_1w72b820/2514.mp3")!),
            JukeboxItem(URL: NSURL(string: "http://www.noiseaddicts.com/samples_1w72b820/2958.mp3")!)
            ])!
        
        /// Later add another item
        let delay = dispatch_time(DISPATCH_TIME_NOW, Int64(3 * Double(NSEC_PER_SEC)))
        dispatch_after(delay, dispatch_get_main_queue()) {
            self.jukebox.append(item: JukeboxItem (URL: NSURL(string: "http://www.noiseaddicts.com/samples_1w72b820/2228.mp3")!), loadingAssets: true)
        }
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    func configureUI ()
    {
        resetUI()
        
        let color = UIColor(red:0.84, green:0.09, blue:0.1, alpha:1)
        
        indicator.color = color
        slider.setThumbImage(UIImage(named: "sliderThumb"), forState: .Normal)
        slider.minimumTrackTintColor = color
        slider.maximumTrackTintColor = UIColor.blackColor()
        
        volumeSlider.minimumTrackTintColor = color
        volumeSlider.maximumTrackTintColor = UIColor.blackColor()
        volumeSlider.thumbTintColor = color
        
        titleLabel.textColor =  color
        
        centerContainer.layer.cornerRadius = 12
        view.backgroundColor = UIColor.blackColor()
    }
    
    // MARK:- JukeboxDelegate -
    
    func jukeboxDidLoadItem(jukebox: Jukebox, item: JukeboxItem) {
        print("Jukebox did load: \(item.URL.lastPathComponent)")
    }
    
    func jukeboxPlaybackProgressDidChange(jukebox: Jukebox) {
        
        if let currentTime = jukebox.currentItem?.currentTime, let duration = jukebox.currentItem?.meta.duration {
            let value = Float(currentTime / duration)
            slider.value = value
            populateLabelWithTime(currentTimeLabel, time: currentTime)
            populateLabelWithTime(durationLabel, time: duration)
        } else {
            resetUI()
        }
    }
    
    func jukeboxStateDidChange(jukebox: Jukebox) {
        
        UIView.animateWithDuration(0.3, animations: { () -> Void in
            self.indicator.alpha = jukebox.state == .Loading ? 1 : 0
            self.playPauseButton.alpha = jukebox.state == .Loading ? 0 : 1
            self.playPauseButton.enabled = jukebox.state == .Loading ? false : true
        })
        
        if jukebox.state == .Ready {
            playPauseButton.setImage(UIImage(named: "playBtn"), forState: .Normal)
        } else if jukebox.state == .Loading  {
            playPauseButton.setImage(UIImage(named: "pauseBtn"), forState: .Normal)
        } else {
            volumeSlider.value = jukebox.volume
            let imageName: String
            switch jukebox.state {
            case .Playing, .Loading:
                imageName = "pauseBtn"
            case .Paused, .Failed, .Ready:
                imageName = "playBtn"
            }
            playPauseButton.setImage(UIImage(named: imageName), forState: .Normal)
        }
        
        print("Jukebox state changed to \(jukebox.state)")
    }
    
    func jukeboxDidUpdateMetadata(jukebox: Jukebox, forItem: JukeboxItem) {
        print("Item updated:\n\(forItem)")
    }
    
    
    override func remoteControlReceivedWithEvent(event: UIEvent?) {
        if event?.type == .RemoteControl {
            switch event!.subtype {
            case .RemoteControlPlay :
                jukebox.play()
            case .RemoteControlPause :
                jukebox.pause()
            case .RemoteControlNextTrack :
                jukebox.playNext()
            case .RemoteControlPreviousTrack:
                jukebox.playPrevious()
            case .RemoteControlTogglePlayPause:
                if jukebox.state == .Playing {
                    jukebox.pause()
                } else {
                    jukebox.play()
                }
            default:
                break
            }
        }
    }
    
    // MARK:- Callbacks -
    
    @IBAction func volumeSliderValueChanged() {
        if let jk = jukebox {
            jk.volume = volumeSlider.value
        }
    }
    
    @IBAction func progressSliderValueChanged() {
        if let duration = jukebox.currentItem?.meta.duration {
            jukebox.seek(toSecond: Int(Double(slider.value) * duration))
        }
    }
    
    @IBAction func prevAction() {
        if jukebox.currentItem?.currentTime > 5 || jukebox.playIndex == 0 {
            jukebox.replayCurrentItem()
        } else {
            jukebox.playPrevious()
        }
    }
    
    @IBAction func nextAction() {
        jukebox.playNext()
    }
    
    @IBAction func playPauseAction() {
        switch jukebox.state {
            case .Ready :
                jukebox.play(atIndex: 0)
            case .Playing :
                jukebox.pause()
            case .Paused :
                jukebox.play()
            default:
                jukebox.stop()
        }
    }
    
    @IBAction func replayAction() {
        resetUI()
        jukebox.replay()
        
    }
    
    @IBAction func stopAction() {
        resetUI()
        jukebox.stop()
    }
    
    // MARK:- Helpers -
    
    func populateLabelWithTime(label : UILabel, time: Double) {
        let minutes = Int(time / 60)
        let seconds = Int(time) - minutes * 60
        
        label.text = String(format: "%02d", minutes) + ":" + String(format: "%02d", seconds)
    }
    
    
    func resetUI()
    {
        durationLabel.text = "00:00"
        currentTimeLabel.text = "00:00"
        slider.value = 0
    }
}

