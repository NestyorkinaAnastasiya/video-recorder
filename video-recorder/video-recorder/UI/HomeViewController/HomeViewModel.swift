//
//  HomeViewModel.swift
//  video-recorder
//
//  Created by Anastasia Nesterkina on 13.01.2021.
//

import Foundation
import UIKit

class HomeViewModel {
    var coordinator: ChildCoordinator?
    
    init(coordinator: ChildCoordinator) {
        self.coordinator = coordinator
    }
}
