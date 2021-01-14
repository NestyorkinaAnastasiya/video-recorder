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
    
    @IBOutlet private weak var allowContainerView: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        
        checkVideoAccess()
        checkMicrophoneAccess()
    }
    
    @IBAction func didTapCloseButton(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func didTapRecordButton(_ sender: Any) {
        
    }
    
    @IBAction func didTapCheckButton(_ sender: Any) {
        
    }
    
    @IBAction func didTapAllowCameraButton(_ sender: Any) {
        openSettings()
    }
    
    @IBAction func didTapAllowMicrophoneButton(_ sender: Any) {
        openSettings()
    }
}

private extension RecordViewController {
    func checkVideoAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: // The user has previously granted access to the camera.
            //self.setupCaptureSession()
            break
        case .notDetermined: // The user has not yet been asked for camera access.
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    
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
            //self.setupCaptureSession()
            break
        case .notDetermined: // The user has not yet been asked for camera access.
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    
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
