//
//  RootCoordinator.swift
//  video-recorder
//
//  Created by Anastasia Nesterkina on 13.01.2021.
//

import Foundation
import UIKit
class RootCoordinator: NSObject, Coordinator {
    
    weak var parent: Coordinator?
    
    var rootNavigationController: UINavigationController
    var rootViewController: UIViewController? {
        return rootNavigationController
    }
    
    init(navigationController: UINavigationController) {
        self.rootNavigationController = navigationController
    }
    
    func start() {
        let viewController = UITabBarController.instantiate(withIdentifier: "MainTabBarController")
        viewController.delegate = self
        
        rootNavigationController.pushViewController(viewController, animated: true)
        
        // Add childCoordinators
        viewController.viewControllers?.forEach {
            guard let navController = $0 as? UINavigationController,
                  let  viewController = navController.viewControllers.last else { return }
            
            if let homeViewController = viewController as? HomeViewController {
                let childCoordinator = HomeCoordinator(parent: self, rootViewController: navController)
                homeViewController.viewModel = HomeViewModel(coordinator: childCoordinator)
            }
        }
        
    }
}

extension RootCoordinator: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if viewController is RecordViewController {
            
            let viewController = RecordViewController.instantiate()
            let navigationController = UINavigationController(rootViewController: viewController)
            navigationController.modalPresentationStyle = .fullScreen
            let childCoordinator = RecordCoordinator(parent: self, rootViewController: navigationController)
            childCoordinator.parent = self
            
            viewController.viewModel = RecordViewModel(coordinator: childCoordinator)
            
            rootNavigationController.present(navigationController, animated: true, completion: nil)
            
            return false
        }
        return true
    }
}
