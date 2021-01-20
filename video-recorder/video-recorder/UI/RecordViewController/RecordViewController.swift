//
//  RecordViewController.swift
//  video-recorder
//
//  Created by Anastasia Nesterkina on 13.01.2021.
//

import Foundation
import UIKit
import AVFoundation
import Photos

enum CaptureState {
    case idle, start, capturing, end
}

class RecordViewController: UIViewController, AutoLoadable {
    var viewModel: RecordViewModel!
    private var captureState: CaptureState = .idle
    private let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput!
    private var audioOutput: AVCaptureAudioDataOutput!
    private var currentPosition = AVCaptureDevice.Position.back
    private var preferredPosition = AVCaptureDevice.Position.back
    private var preferredDeviceType = AVCaptureDevice.DeviceType.builtInDualCamera
    private let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera,
                                                                                  .builtInDualCamera,
                                                                                  .builtInWideAngleCamera],
                                                                    mediaType: .video,
                                                                    position: .unspecified)
    
    // values for recording clips
    private var assetWriter: AVAssetWriter!
    private var assetWriterInput: AVAssetWriterInput!
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var filename = ""
    var clips: [String] = []
    
    private var time: Double = 0
    
    @IBOutlet private weak var allowContainerView: UIView!
    @IBOutlet private weak var previewView: PreviewView!
    @IBOutlet private weak var timeLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        previewView.videoPreviewLayer.session = captureSession
        navigationController?.navigationBar.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        
        checkVideoAccess()
        
        // for interruptions such as phone calls, notifications from other apps, and music playback
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionWasInterrupted),
                                               name: .AVCaptureSessionWasInterrupted,
                                               object: captureSession)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionInterruptionEnded),
                                               name: .AVCaptureSessionInterruptionEnded,
                                               object: captureSession)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionRuntimeError),
                                               name: .AVCaptureSessionRuntimeError,
                                               object: captureSession)
    }
    
    @IBAction func didTapCloseButton(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func didTapRecordButton(_ sender: Any) {
        switch captureState {
        case .idle:
            captureState = .start
           /* try? FileManager.default.removeItem(at: url)
            videoOutput.startRecording(to: url, recordingDelegate: self)*/
        case .capturing:
            captureState = .end
        default: break
            /*videoOutput.stopRecording()*/
        }
    }
    
    @IBAction func didTapCheckButton(_ sender: Any) {
        mergeSegmentsAndUpload(clips: clips)
    }
    
    @IBAction func didTapAllowCameraButton(_ sender: Any) {
        openSettings()
    }
    
    @IBAction func didTapAllowMicrophoneButton(_ sender: Any) {
        openSettings()
    }
    
    @IBAction func didTapSwichCameraButton(_ sender: Any) {
        switchCamera()
    }
}

// MARK: session functions
private extension RecordViewController {
    func configSession() {
        captureSession.beginConfiguration()
        let videoDevice = bestDevice(in: currentPosition)
        configureCameraForHighestFrameRate(device: videoDevice)
        videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice)
        guard let videoDeviceInput = videoDeviceInput,
              captureSession.canAddInput(videoDeviceInput),
              let audioDeviceInput = AVCaptureDevice.default(for: AVMediaType.audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDeviceInput),
              captureSession.canAddInput(audioInput) else { return }
        
        captureSession.addInput(videoDeviceInput)
        captureSession.addInput(audioInput)
        
        videoOutput = AVCaptureVideoDataOutput()
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.sessionPreset = .high
        captureSession.addOutput(videoOutput)
        captureSession.commitConfiguration()
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global())
    }
    
    func switchCamera() {
        guard let currentVideoDeviceInput = videoDeviceInput else { return }
        // Remove the existing device input first, because AVCaptureSession doesn't support
        // simultaneous use of the rear and front cameras.
        self.captureSession.removeInput(currentVideoDeviceInput)
        
        setPrefferedDeviceParameters()
        
        let videoDevice = bestDevice(in: preferredPosition)
        configureCameraForHighestFrameRate(device: videoDevice)
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(deviceInput) else {
            captureSession.addInput(currentVideoDeviceInput)
            return
        }
        self.videoDeviceInput = deviceInput
        captureSession.addInput(deviceInput)
        currentPosition = preferredPosition
    }
    
    func setPrefferedDeviceParameters() {
        switch currentPosition {
        case .unspecified, .front:
            preferredPosition = .back
            preferredDeviceType = .builtInDualCamera
            
        case .back:
            preferredPosition = .front
            preferredDeviceType = .builtInTrueDepthCamera
            
        @unknown default:
            print("Unknown capture position. Defaulting to back, dual-camera.")
            preferredPosition = .back
            preferredDeviceType = .builtInDualCamera
        }
    }
    
    func bestDevice(in position: AVCaptureDevice.Position) -> AVCaptureDevice {
        let devices = self.discoverySession.devices
        guard !devices.isEmpty else { fatalError("Missing capture devices.") }

        return devices.first(where: { device in device.position == position })!
    }
    
    func configureCameraForHighestFrameRate(device: AVCaptureDevice) {
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?

        for format in device.formats {
            for range in format.videoSupportedFrameRateRanges where
                range.maxFrameRate > bestFrameRateRange?.maxFrameRate ?? 0 {
                bestFormat = format
                bestFrameRateRange = range
            }
        }
        
        if let bestFormat = bestFormat,
           let bestFrameRateRange = bestFrameRateRange {
            do {
                try device.lockForConfiguration()
                
                // Set the device's active format.
                device.activeFormat = bestFormat
                
                // Set the device's min/max frame duration.
                let duration = bestFrameRateRange.minFrameDuration
                device.activeVideoMinFrameDuration = duration
                device.activeVideoMaxFrameDuration = duration
                
                device.unlockForConfiguration()
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
    
    @objc func sessionWasInterrupted() {
      /*  if reason == .audioDeviceInUseByAnotherClient || reason == .videoDeviceInUseByAnotherClient {
            showResumeButton = true
        } else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
            // Fade-in a label to inform the user that the camera is unavailable.
            cameraUnavailableLabel.alpha = 0
            cameraUnavailableLabel.isHidden = false
            UIView.animate(withDuration: 0.25) {
                self.cameraUnavailableLabel.alpha = 1
            }
        } else if reason == .videoDeviceNotAvailableDueToSystemPressure {
            print("Session stopped running due to shutdown system pressure level.")
        }*/
    }
    
    @objc func sessionInterruptionEnded() {
        
    }
    
    @objc func sessionRuntimeError() {
        // If media services were reset, and the last start succeeded, restart the session.
        /*if error.code == .mediaServicesWereReset {
            sessionQueue.async {
                if self.isSessionRunning {
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                } else {
                    DispatchQueue.main.async {
                        self.resumeButton.isHidden = false
                    }
                }
            }
        } else {
            resumeButton.isHidden = false
        }*/
    }
}

extension RecordViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
    }
}

extension RecordViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        switch captureState {
        case .start:
            startRecord(timestamp: timestamp)
        case .capturing:
            let seconds = timestamp - self.time
            if assetWriterInput?.isReadyForMoreMediaData == true {
                // Append the sample buffer at the correct time
                let time = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(600))
                adaptor?.append(CMSampleBufferGetImageBuffer(sampleBuffer)!, withPresentationTime: time)
            }
            DispatchQueue.main.async {
                self.timeLabel.text = self.viewModel.timeString(seconds: Int(seconds))
            }
        case .end:
            // When we have finished recording, finish writing the video data to disk
            guard assetWriterInput?.isReadyForMoreMediaData == true, assetWriter!.status != .failed else { break }
            assetWriterInput?.markAsFinished()
            assetWriter?.finishWriting { [weak self] in
                guard let self = self else { return }
                // Move to the idle state once we are done writing
                self.captureState = .idle
                self.assetWriter = nil
                self.assetWriterInput = nil
                DispatchQueue.main.async {
                    // Stop animating the record button
                    //self.stopAnimatingRecordButton()
                }
            }
        case .idle:
            DispatchQueue.main.async {
                //self.stopAnimatingRecordButton()
            }
        }
    }
}

// MARK: record functions
private extension RecordViewController {
    func startRecord(timestamp: Double) {
        // Create a new filename for this clip
        filename = UUID().uuidString
        // Create the AVAssetWriter that will write the video data to the output file
        if let videoPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("\(filename).mov"),
           let writer = try? AVAssetWriter(outputURL: videoPath, fileType: .mov),
           let settings = videoOutput?.recommendedVideoSettingsForAssetWriter(writingTo: .mov) {
            // Animate the record button and start playing the chosen audio track
            DispatchQueue.main.async {
                //self.animateRecordButton()
            }
            
            // Keep track of all the clips that will be included in the final video
            clips.append("\(filename).mov")
            
            // AVAssetWriterInput is used to append media samples to a single track of the asset writer's output file.
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.mediaTimeScale = CMTimeScale(bitPattern: 600)
            input.expectsMediaDataInRealTime = true
            input.transform = CGAffineTransform(rotationAngle: .pi / 2)
            
            adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
            
            // Use a buffer to append video samples packaged as pixel buffers to the AVAssetWriterInput
            if writer.canAdd(input) {
                writer.add(input)
            }
            // Start writing to disk
            let startingTimeDelay = CMTimeMakeWithSeconds(0.5, preferredTimescale: 1_000_000_000)
            writer.startWriting()
            writer.startSession(atSourceTime: .zero + startingTimeDelay)
            
            assetWriter = writer
            assetWriterInput = input
            
            captureState = .capturing
            // Keep track of the earliest timestamp of all the samples when we started writing
            time = timestamp
        }
    }
    
    func mergeSegmentsAndUpload(clips _: [String]) {
        DispatchQueue.main.async {
            if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                VideoCompositionWriter.mergeVideos(dir, filename: "\(self.filename).mov", clips: self.clips) { success, outUrl in
                    if success, let url = outUrl {
                        PHPhotoLibrary.shared().performChanges({
                            let options = PHAssetResourceCreationOptions()
                            options.shouldMoveFile = true
                            let creationRequest = PHAssetCreationRequest.forAsset()
                            creationRequest.addResource(with: .video, fileURL: url, options: options)
                        }, completionHandler: { success, error in
                            if !success {
                                print("AVCam couldn't save the movie to your photo library: \(String(describing: error))")
                            }
                        })
                    }
                }
            }
            //self.stopAnimatingRecordButton()
            self.dismiss(animated: true, completion: nil)
        }
    }
}

// MARK: check access functions
private extension RecordViewController {
    func checkVideoAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: // The user has previously granted access to the camera.
            self.checkMicrophoneAccess()
        case .notDetermined: // The user has not yet been asked for camera access.
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.checkMicrophoneAccess()
                } else {
                    
                    DispatchQueue.main.async {
                        self.dismiss(animated: true, completion: nil)
                        
                    }
                    
                }
            }
            
        case .denied: // The user has previously denied access.
            self.allowContainerView.alpha = 1

        default:
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func checkMicrophoneAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: // The user has previously granted access to the camera.
            self.configSession()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                self.captureSession.startRunning()
            }
            self.captureSession.startRunning()
        case .notDetermined: // The user has not yet been asked for camera access.
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    self.configSession()
                    self.captureSession.startRunning()
                } else {
                    DispatchQueue.main.async {
                        self.dismiss(animated: true, completion: nil)
                        
                    }
                }
            }
        case .denied: // The user has previously denied access.
            self.allowContainerView.alpha = 1
        default:
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}
