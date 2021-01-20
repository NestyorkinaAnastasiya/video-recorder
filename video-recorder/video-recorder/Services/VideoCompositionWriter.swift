//
//  VideoCompositionWriter.swift
//  video-recorder
//
//  Created by Anastasia Nesterkina on 20.01.2021.
//

import Foundation
import AVFoundation
import UIKit

class VideoCompositionWriter: NSObject {
    private static func merge(arrayVideos: [AVAsset]) -> AVMutableComposition {
        // Create a new mutable compositon
        let mainComposition = AVMutableComposition()
        // Add a video track to the composition
        let compositionVideoTrack = mainComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        compositionVideoTrack?.preferredTransform = CGAffineTransform(rotationAngle: .pi / 2)
        // Starting at time = 0, loop over each video asset and add them to the track
        var insertTime = CMTime.zero
        for videoAsset in arrayVideos {
            try? compositionVideoTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero,
                                                                        duration: videoAsset.duration),
                                                        of: videoAsset.tracks(withMediaType: .video)[0],
                                                        at: insertTime)
            // Update the next insert time by the video asset's duration
            insertTime = CMTimeAdd(insertTime, videoAsset.duration)
        }
        return mainComposition
    }
    
// This function takes the path to a directory containing the video clips, an output filenname and an array of filenames identifying the clips to be merged
   static func mergeVideos(_ documentsDirectory: URL, filename: String, clips: [String], completion: @escaping (Bool, URL?) -> Void) {
        // Start by creating an asset from each of the clips' filenames
        // Keep track of the total duration of all these clips combined
        // This will be used to determine the length of the audio in our composition
        var assets: [AVAsset] = []
        var totalDuration = CMTime.zero
        for clip in clips {
            let videoFile = documentsDirectory.appendingPathComponent(clip)
            let asset = AVURLAsset(url: videoFile)
            assets.append(asset)
            totalDuration = CMTimeAdd(totalDuration, asset.duration)
        }
        // Use our merge function to get a new composition containing all the video clips
        let mixComposition = merge(arrayVideos: assets)
    
        // Get path to the output file
        let url = documentsDirectory.appendingPathComponent("out_\(filename)")
        // Create an AVAssetExportSession, passing in our composition
        guard let exporter = AVAssetExportSession(asset: mixComposition,
                                                  presetName: AVAssetExportPresetHighestQuality) else { return }
        // Set the export session's output URL
        exporter.outputURL = url
        exporter.outputFileType = AVFileType.mov
        exporter.shouldOptimizeForNetworkUse = true
        // Carry out the export
        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                if exporter.status == .completed {
                    completion(true, exporter.outputURL)
                } else {
                    completion(false, nil)
                }
            }
        }
    }
}
