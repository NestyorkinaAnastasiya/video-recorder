//
//  ChildCoordinator.swift
//  video-recorder
//
//  Created by Anastasia Nesterkina on 13.01.2021.
//

import Foundation
import UIKit

class HomeCoordinator: Coordinator {
    weak var parent: Coordinator?
    
    var rootNavigationController: UINavigationController?
    var rootViewController: UIViewController? {
        return rootNavigationController
    }
    
    init(parent: RootCoordinator, rootViewController: UINavigationController) {
        self.parent = parent
        self.rootNavigationController = rootViewController
    }
}
