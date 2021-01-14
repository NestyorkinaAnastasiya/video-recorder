//
//  AutoLoadable.swift
//  video-recorder
//
//  Created by Anastasia Nesterkina on 13.01.2021.
//

import Foundation
import UIKit

protocol AutoLoadable {
    static func instantiate() -> Self
    static func instantiate(withIdentifier: String) -> Self
    
    static func instantiate(from storyboardName: String) -> Self
    static func instantiate(from storyboardName: String, withIdentifier: String) -> Self
}

extension AutoLoadable where Self: UIViewController {
    static func instantiate() -> Self {
        return instantiate(from: "Main")
    }
    
    static func instantiate(from storyboardName: String) -> Self {
        let fullName = NSStringFromClass(self)
        let className = fullName.components(separatedBy: ".")[1]

        let storyboard = UIStoryboard(name: storyboardName, bundle: Bundle.main)
        return storyboard.instantiateViewController(withIdentifier: className) as! Self
    }
    
    static func instantiate(withIdentifier: String) -> Self {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        return storyboard.instantiateViewController(withIdentifier: withIdentifier) as! Self
    }
    
    static func instantiate(from storyboardName: String, withIdentifier: String) -> Self {
        let storyboard = UIStoryboard(name: storyboardName, bundle: Bundle.main)
        return storyboard.instantiateViewController(withIdentifier: withIdentifier) as! Self
    }
}

extension UITabBarController: AutoLoadable {}
