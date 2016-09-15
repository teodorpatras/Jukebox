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
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        // configure jukebox
        jukebox = Jukebox(delegate: self, items: [
            JukeboxItem(URL: URL(string: "http://www.kissfm.ro/listen.pls")!),
            JukeboxItem(URL: URL(string: "http://www.noiseaddicts.com/samples_1w72b820/2514.mp3")!),
            JukeboxItem(URL: URL(string: "http://www.noiseaddicts.com/samples_1w72b820/2958.mp3")!)
            ])!
        
        /// Later add another item
        let delay = DispatchTime.now() + Double(Int64(3 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: delay) {
            self.jukebox.append(item: JukeboxItem (URL: URL(string: "http://www.noiseaddicts.com/samples_1w72b820/2228.mp3")!), loadingAssets: true)
        }
    }
    
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    func configureUI ()
    {
        resetUI()
        
        let color = UIColor(red:0.84, green:0.09, blue:0.1, alpha:1)
        
        indicator.color = color
        slider.setThumbImage(UIImage(named: "sliderThumb"), for: UIControlState())
        slider.minimumTrackTintColor = color
        slider.maximumTrackTintColor = UIColor.black
        
        volumeSlider.minimumTrackTintColor = color
        volumeSlider.maximumTrackTintColor = UIColor.black
        volumeSlider.thumbTintColor = color
        
        titleLabel.textColor =  color
        
        centerContainer.layer.cornerRadius = 12
        view.backgroundColor = UIColor.black
    }
    
    // MARK:- JukeboxDelegate -
    
    func jukeboxDidLoadItem(_ jukebox: Jukebox, item: JukeboxItem) {
        print("Jukebox did load: \(item.URL.lastPathComponent)")
    }
    
    func jukeboxPlaybackProgressDidChange(_ jukebox: Jukebox) {
        
        if let currentTime = jukebox.currentItem?.currentTime, let duration = jukebox.currentItem?.meta.duration {
            let value = Float(currentTime / duration)
            slider.value = value
            populateLabelWithTime(currentTimeLabel, time: currentTime)
            populateLabelWithTime(durationLabel, time: duration)
        } else {
            resetUI()
        }
    }
    
    func jukeboxStateDidChange(_ jukebox: Jukebox) {
        
        UIView.animate(withDuration: 0.3, animations: { () -> Void in
            self.indicator.alpha = jukebox.state == .loading ? 1 : 0
            self.playPauseButton.alpha = jukebox.state == .loading ? 0 : 1
            self.playPauseButton.isEnabled = jukebox.state == .loading ? false : true
        })
        
        if jukebox.state == .ready {
            playPauseButton.setImage(UIImage(named: "playBtn"), for: UIControlState())
        } else if jukebox.state == .loading  {
            playPauseButton.setImage(UIImage(named: "pauseBtn"), for: UIControlState())
        } else {
            volumeSlider.value = jukebox.volume
            let imageName: String
            switch jukebox.state {
            case .playing, .loading:
                imageName = "pauseBtn"
            case .paused, .failed, .ready:
                imageName = "playBtn"
            }
            playPauseButton.setImage(UIImage(named: imageName), for: UIControlState())
        }
        
        print("Jukebox state changed to \(jukebox.state)")
    }
    
    func jukeboxDidUpdateMetadata(_ jukebox: Jukebox, forItem: JukeboxItem) {
        print("Item updated:\n\(forItem)")
    }
    
    
    override func remoteControlReceived(with event: UIEvent?) {
        if event?.type == .remoteControl {
            switch event!.subtype {
            case .remoteControlPlay :
                jukebox.play()
            case .remoteControlPause :
                jukebox.pause()
            case .remoteControlNextTrack :
                jukebox.playNext()
            case .remoteControlPreviousTrack:
                jukebox.playPrevious()
            case .remoteControlTogglePlayPause:
                if jukebox.state == .playing {
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
        
        if let time = jukebox.currentItem?.currentTime, time > 5.0 || jukebox.playIndex == 0 {
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
            case .ready :
                jukebox.play(atIndex: 0)
            case .playing :
                jukebox.pause()
            case .paused :
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
    
    func populateLabelWithTime(_ label : UILabel, time: Double) {
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

