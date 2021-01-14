//
//  Coordinator.swift
//  video-recorder
//
//  Created by Anastasia Nesterkina on 13.01.2021.
//

import Foundation
import UIKit

protocol Coordinator: class {
    
    var parent: Coordinator? {get}
    var rootViewController: UIViewController? {get}
    
    func start()
    func start(from: UIViewController)
    
}

extension Coordinator {
    func start() {
        assertionFailure("""
            This coordinator does not support starting outside of view controller hierarchy.\
            You need to use start(from: ) method to start from a particular place in the application.
        """)
    }
        
    func start(from: UIViewController) {
        assertionFailure("""
            This coordinator does not support starting from another view controller.\
            You should use start() and then manually add this coordinator's rootViewController into view hierarchy.
            """)
    }
}
