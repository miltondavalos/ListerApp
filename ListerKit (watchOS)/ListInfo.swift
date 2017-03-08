/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `ListInfo` class is a caching abstraction over an `List` object that contains information about lists (e.g. color and name). This object is distinct from the one used by the iOS application.
*/

import UIKit
import ListerWatchKit

open class ListInfo: NSObject {
    // MARK: Properties
    
    open var name: String
    
    open var color: List.Color
    
    // MARK: Initializers
    
    public init(name: String, color: List.Color) {
        self.name = name
        self.color = color
    }
    
    // MARK: NSObject
    
    override open func isEqual(_ object: Any?) -> Bool {
        if let listInfo = object as? ListInfo {
            return listInfo.name == name
        }
        
        return false
    }
}
