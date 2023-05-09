//
//  Extensions.swift
//  iOS_messenger
//
//  Created by Taiming Liu on 4/28/23.
//

import Foundation
import UIKit


extension UIView {
    public var width: CGFloat {
        return frame.size.width
    }
    
    public var height: CGFloat {
        return frame.size.height
    }
    
    public var top: CGFloat {
        return frame.origin.y
    }
    
    public var bottom: CGFloat {
        return height + top
    }
    
    public var left: CGFloat {
        return frame.origin.x
    }
    
    public var right: CGFloat {
        return width + left
    }
}

extension Notification.Name {
    static let didLogInNofication = Notification.Name("didLogInNotification")
}
