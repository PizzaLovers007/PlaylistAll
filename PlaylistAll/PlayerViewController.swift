//
//  PlayerViewController.swift
//  PlaylistAll
//
//  Created by Terrence Park on 1/15/17.
//  Copyright © 2017 Terrence Park. All rights reserved.
//

import UIKit
import MediaPlayer
import GameKit
import AudioToolbox

class PlayerViewController: UIViewController {
    
    @IBOutlet weak var albumImageView: UIImageView!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var totalTimeLabel: UILabel!
    @IBOutlet weak var songTitleLabel: UILabel!
    @IBOutlet weak var songArtistLabel: UILabel!
    @IBOutlet weak var rewindButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var volumeSliderContainer: UIView!

    var volumeSlider: MPVolumeView! = nil
    var touchingTimeSlider: Bool = false
    var changingTime: Bool = false
    var songs = [AVPlayerItem]()
    var shuffled = [AVPlayerItem]()
    var timer = Timer()
    var player = AVPlayer()
    var currIndex = 0
    var paused = true
    var nowPlayingInfo = [String : Any]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        volumeSlider = MPVolumeView(frame: CGRect(origin: CGPoint.zero, size: volumeSliderContainer.frame.size))
        volumeSliderContainer.addSubview(volumeSlider)
        
        //Check if playlist is saved
        if let songUrls = UserDefaults.standard.object(forKey: "songs") as? [String] {
            //Restore playlist
            songs = [AVPlayerItem]()
            for url in songUrls {
                let song = AVPlayerItem(url: URL(string: url)!)
                songs.append(song)
            }
            
            let index = UserDefaults.standard.integer(forKey: "index")
            let seed = UserDefaults.standard.object(forKey: "seed") as! UInt64
            
            reshuffleQueue(index: index, seed: seed)
            
            //Listen for song change
            for song in songs {
                NotificationCenter.default.addObserver(self, selector: #selector(songChanged), name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: song)
            }
        }
        
        paused = player.rate == 0
        
        //Listen to control center player commands
        MPRemoteCommandCenter.shared().playCommand.addTarget(handler: { (event) -> MPRemoteCommandHandlerStatus in
            self.playPausePressed(self)
            return MPRemoteCommandHandlerStatus.success
        });
        MPRemoteCommandCenter.shared().pauseCommand.addTarget(handler: { (event) -> MPRemoteCommandHandlerStatus in
            self.playPausePressed(self)
            return MPRemoteCommandHandlerStatus.success
        });
        MPRemoteCommandCenter.shared().togglePlayPauseCommand.addTarget(handler: { (event) -> MPRemoteCommandHandlerStatus in
            self.playPausePressed(self)
            return MPRemoteCommandHandlerStatus.success
        });
        MPRemoteCommandCenter.shared().nextTrackCommand.addTarget(handler: { (event) -> MPRemoteCommandHandlerStatus in
            self.forwardPressed(self)
            return MPRemoteCommandHandlerStatus.success
        });
        MPRemoteCommandCenter.shared().previousTrackCommand.addTarget(handler: { (event) -> MPRemoteCommandHandlerStatus in
            self.rewindPressed(self)
            return MPRemoteCommandHandlerStatus.success
        });
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.addTarget(handler: { (event) -> MPRemoteCommandHandlerStatus in
            print(event.timestamp)
            return MPRemoteCommandHandlerStatus.success
        });
        
        //Allow audio scrubbing (for iOS 10 only?)
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled = true
        
        //Listen to remote control events
        UIApplication.shared.beginReceivingRemoteControlEvents()
        self.becomeFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if let song = player.currentItem {
            updatePlayerValues(song)
        }
        if songs.count == 0 {
            tabBarController!.selectedIndex = 1
        }
        
        timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(updateSongTime), userInfo: nil, repeats: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        timer.invalidate()
        
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func startPlaying(queue: [MPMediaItem]) {
        songs.removeAll()
        for media in queue {
            if let url = media.assetURL {
                songs.append(AVPlayerItem(url: url))
            }
        }
        
        let seed = UInt64(Date().timeIntervalSince1970*1000)
        reshuffleQueue(index: 0, seed: seed)
        player.play()
    }
    
    func reshuffleQueue(index: Int, seed: UInt64) {
        //Shuffle songs
        shuffled.removeAll()
        let lcg = GKLinearCongruentialRandomSource(seed: seed)
        shuffled.append(contentsOf: lcg.arrayByShufflingObjects(in: songs) as! [AVPlayerItem])
        
        //Set current song
        player.replaceCurrentItem(with: shuffled[index])
        currIndex = index
        
        //Play song
        updatePlayerValues(shuffled[index])
        if (!paused) {
            player.play()
        }
        
        //Save data
        UserDefaults.standard.set(seed, forKey: "seed")
        UserDefaults.standard.set(index, forKey: "index")
        var songUrls = [String]()
        for song in songs {
            if let url = song.asset as? AVURLAsset {
                songUrls.append(url.url.absoluteString)
            }
        }
        UserDefaults.standard.set(songUrls, forKey: "songs")
    }
    
    func updatePlayerValues(_ song: AVPlayerItem) {
        let meta = song.asset.commonMetadata
        for data in meta {
            if let key = data.commonKey {
                switch key {
                case AVMetadataCommonKeyArtist:
                    songArtistLabel.text = data.stringValue
                case AVMetadataCommonKeyTitle:
                    songTitleLabel.text = data.stringValue
                case AVMetadataCommonKeyArtwork:
                    albumImageView.image = UIImage(data: data.dataValue!)
                default: break
                }
            }
        }
        
        timeSlider.isEnabled = true
        timeSlider.maximumValue = Float(song.asset.duration.seconds)
        timeSlider.setValue(Float(song.currentTime().seconds), animated: false)
        currentTimeLabel.text = convertToString(song.currentTime().seconds)
        totalTimeLabel.text = convertToString(song.asset.duration.seconds)
        rewindButton.isEnabled = true
        playButton.isEnabled = true
        forwardButton.isEnabled = true
        
        nowPlayingInfo[MPMediaItemPropertyArtist] = songArtistLabel.text
        nowPlayingInfo[MPMediaItemPropertyTitle] = songTitleLabel.text
        if let image = albumImageView.image {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: image)
        }
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = TimeInterval(timeSlider.maximumValue)
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func updateSongTime() {
        if (player.currentItem != nil) {
            DispatchQueue.main.async {
                if (!self.touchingTimeSlider) {
                    self.timeSlider.value = Float(self.player.currentTime().seconds)
                    self.currentTimeLabel.text = self.convertToString(self.player.currentTime().seconds)
                }
            }
        }
    }
    
    func convertToString(_ seconds: Double) -> String {
        let hours = seconds/3600
        let minutes = (seconds/60).truncatingRemainder(dividingBy: 60)
        let seconds = seconds.truncatingRemainder(dividingBy: 60)
        if (seconds >= 3600) {
            return String(format: "%d:%02d:%02d", Int(hours), Int(minutes), Int(seconds))
        } else {
            return String(format: "%d:%02d", Int(minutes), Int(seconds))
        }
    }
    
    func songChanged() {
        shuffled[currIndex].seek(to: CMTime(seconds: 0, preferredTimescale: 1))
        currIndex += 1
        if currIndex == songs.count {
            queueFinished()
        }
        playSong()
        UserDefaults.standard.set(currIndex, forKey: "index")
    }
    
    func queueFinished() {
        player.replaceCurrentItem(with: nil)
        let seed = UInt64(Date().timeIntervalSince1970*1000)
        reshuffleQueue(index: 0, seed: seed)
    }
    
    @IBAction func timeSliderValueChanged(_ sender: Any) {
        if (!changingTime) {
            changingTime = true
            DispatchQueue.main.async {
                self.currentTimeLabel.text = self.convertToString(Double(self.timeSlider.value))
                self.changingTime = false
            }
        }
    }
    
    @IBAction func timeSliderTouchDown(_ sender: Any) {
        touchingTimeSlider = true
    }
    
    @IBAction func timeSliderTouchUpInside(_ sender: Any) {
        seekTo(time: Double(timeSlider.value))
        touchingTimeSlider = false
    }
    
    @IBAction func timeSliderTouchUpOutside(_ sender: Any) {
        seekTo(time: Double(timeSlider.value))
        touchingTimeSlider = false
    }
    
    func seekTo(time: Double) {
        if player.currentItem != nil {
            player.pause()
            shuffled[currIndex].seek(to: CMTime(seconds: time, preferredTimescale: 1))
            if (!paused) {
                player.play()
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            }
        }
    }

    @IBAction func playPausePressed(_ sender: Any) {
        if player.rate == 0 {
            player.play()
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            paused = false
        } else {
            player.pause()
            paused = true
        }
    }
    
    @IBAction func forwardPressed(_ sender: Any) {
        songChanged()
    }
    
    @IBAction func rewindPressed(_ sender: Any) {
        if (player.currentTime().seconds >= 3 || currIndex == 0) {
            player.seek(to: CMTime(seconds: 0, preferredTimescale: 1))
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        } else {
            shuffled[currIndex].seek(to: CMTime(seconds: 0, preferredTimescale: 1))
            currIndex -= 1
            UserDefaults.standard.set(currIndex, forKey: "index")
            playSong()
        }
    }
    
    func playSong() {
        if shuffled.count > 0 {
            player.replaceCurrentItem(with: shuffled[currIndex])
            if (!paused) {
                player.play()
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            }
            updatePlayerValues(shuffled[currIndex])
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
