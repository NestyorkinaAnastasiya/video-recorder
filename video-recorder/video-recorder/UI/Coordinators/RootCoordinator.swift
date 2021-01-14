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
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        guard let viewController = storyboard.instantiateViewController(withIdentifier: "MainTabBarController")
            as? UITabBarController else { return }
        viewController.delegate = self
        
        rootNavigationController.pushViewController(viewController, animated: true)
        
        // Add childCoordinators
        if let controllers = viewController.viewControllers {
            for controller in controllers {
                guard let navController = controller as? UINavigationController,
                    let  viewController = navController.viewControllers.last else { return }
                
                let childCoordinator = ChildCoordinator(parent: self, rootViewController: navController)
                
                if let homeViewController = viewController as? HomeViewController {
                    homeViewController.viewModel = HomeViewModel(coordinator: childCoordinator)
                    
                }
            }
        }
        
    }
}

extension RootCoordinator: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if viewController is RecordViewController {
            
            let viewController = RecordViewController.instantiate()
            viewController.viewModel = RecordViewModel(coordinator: self)
            rootNavigationController.present(viewController, animated: true, completion: nil)
            
            return false
        }
        return true
    }
}
