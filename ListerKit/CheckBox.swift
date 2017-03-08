/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    A custom check box used in the lists. It supports designing live in Interface Builder.
*/

import UIKit

@IBDesignable open class CheckBox: UIControl {
    // MARK: Properties
    
    @IBInspectable open var isChecked: Bool {
        get {
            return checkBoxLayer.isChecked
        }
        
        set {
            checkBoxLayer.isChecked = newValue
        }
    }

    @IBInspectable open var strokeFactor: CGFloat {
        set {
            checkBoxLayer.strokeFactor = newValue
        }

        get {
            return checkBoxLayer.strokeFactor
        }
    }
    
    @IBInspectable open var insetFactor: CGFloat {
        set {
            checkBoxLayer.insetFactor = newValue
        }

        get {
            return checkBoxLayer.insetFactor
        }
    }
    
    @IBInspectable open var markInsetFactor: CGFloat {
        set {
            checkBoxLayer.markInsetFactor = newValue
        }
    
        get {
            return checkBoxLayer.markInsetFactor
        }
    }
    
    // MARK: Overrides
    
    override open func didMoveToWindow() {
        if let window = window {
            contentScaleFactor = window.screen.scale
        }
    }

    override open class var layerClass : AnyClass {
        return CheckBoxLayer.self
    }
    
    override open func tintColorDidChange() {
        super.tintColorDidChange()
        
        checkBoxLayer.tintColor = tintColor.cgColor
    }

    // MARK: Convenience
    
    var checkBoxLayer: CheckBoxLayer {
        return layer as! CheckBoxLayer
    }
}
