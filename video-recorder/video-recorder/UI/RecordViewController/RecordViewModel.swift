//
//  RecordViewModel.swift
//  video-recorder
//
//  Created by Anastasia Nesterkina on 13.01.2021.
//

import Foundation
import UIKit

class RecordViewModel {
    var coordinator: RootCoordinator?
    
    init(coordinator: RootCoordinator) {
        self.coordinator = coordinator
    }
}
