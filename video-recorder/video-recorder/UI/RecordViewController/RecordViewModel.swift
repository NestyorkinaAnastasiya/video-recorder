//
//  RecordViewModel.swift
//  video-recorder
//
//  Created by Anastasia Nesterkina on 13.01.2021.
//

import Foundation
import UIKit

class RecordViewModel {
    var coordinator: RecordCoordinator?
    var fileUrl: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("output.mov")
    }
    
    init(coordinator: RecordCoordinator) {
        self.coordinator = coordinator
    }
    
    func timeString(seconds: Int) -> String {
        let minutes = seconds/60
        
        var hoursString = String(minutes/60)
        if hoursString.count == 1 {
            hoursString = "0"+hoursString
        }
        
        var minutesString = String(minutes%60)
        if minutesString.count == 1 {
            minutesString = "0"+minutesString
        }
        
        var secondsString = String(seconds%60)
        if secondsString.count == 1 {
            secondsString = "0"+secondsString
        }
        
        return "\(hoursString):\(minutesString):\(secondsString)"
    }
}
