//
//  PreviewView.swift
//  video-recorder
//
//  Created by Anastasia Nesterkina on 15.01.2021.
//

import Foundation
import UIKit
import AVFoundation

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    /// Convenience wrapper to get layer as its statically known type.
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        let videoLayer = layer as! AVCaptureVideoPreviewLayer
        videoLayer.videoGravity = .resizeAspectFill
        videoLayer.connection?.videoOrientation = .portrait
        return videoLayer
    }
}
