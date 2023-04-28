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
        return self.frame.size.width
    }
    
    public var height: CGFloat {
        return self.frame.size.height
    }
    
    public var top: CGFloat {
        return self.frame.origin.y
    }
    
    public var bottom: CGFloat {
        return self.height + self.top
    }
    
    public var left: CGFloat {
        return self.frame.origin.x
    }
    
    public var right: CGFloat {
        return self.width + self.left
    }
}
