//
//  RecordViewController.swift
//  video-recorder
//
//  Created by Anastasia Nesterkina on 13.01.2021.
//

import Foundation
import UIKit
import AVFoundation

class RecordViewController: UIViewController, AutoLoadable {
    var viewModel: RecordViewModel!
    private let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureMovieFileOutput!
    private var currentPosition = AVCaptureDevice.Position.back
    private var preferredPosition = AVCaptureDevice.Position.back
    private var preferredDeviceType = AVCaptureDevice.DeviceType.builtInDualCamera
    private let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera,
                                                                                  .builtInDualCamera,
                                                                                  .builtInWideAngleCamera],
                                                                    mediaType: .video,
                                                                    position: .unspecified)
    
    @IBOutlet private weak var allowContainerView: UIView!
    @IBOutlet weak var previewView: PreviewView!
    
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
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileUrl = paths[0].appendingPathComponent("output.mov")
        try? FileManager.default.removeItem(at: fileUrl)
        videoOutput.startRecording(to: fileUrl, recordingDelegate: self)
    }
    
    @IBAction func didTapCheckButton(_ sender: Any) {
        
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
        
        videoOutput = AVCaptureMovieFileOutput()
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.sessionPreset = .high
        captureSession.addOutput(videoOutput)
        captureSession.commitConfiguration()
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
