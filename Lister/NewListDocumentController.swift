/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `NewListDocumentController` class allows users to create a new list document with a name and preferred color.
*/

import UIKit
import ListerKit

class NewListDocumentController: UIViewController, UITextFieldDelegate {
    // MARK: Properties

    @IBOutlet weak var grayButton: UIButton!
    
    @IBOutlet weak var blueButton: UIButton!
    
    @IBOutlet weak var greenButton: UIButton!
    
    @IBOutlet weak var yellowButton: UIButton!
    
    @IBOutlet weak var orangeButton: UIButton!

    @IBOutlet weak var redButton: UIButton!
    
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    @IBOutlet weak var toolbar: UIToolbar!
    
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var nameField: UITextField!
    
    weak var selectedButton: UIButton?
    
    var selectedColor = List.Color.gray
    var selectedTitle: String?

    var listsController: ListsController!
    
    // MARK: IBActions
    
    @IBAction func pickColor(_ sender: UIButton) {
        // The user is choosing a color, resign first responder on the text field, if necessary.
        if nameField.isFirstResponder {
            nameField.resignFirstResponder()
        }
        
        // Use the button's tag to determine the color.
        selectedColor = List.Color(rawValue: sender.tag)!
        
        // If a button was previously selected, we need to clear out its previous border.
        if let oldButton = selectedButton {
            oldButton.layer.borderWidth = 0.0
        }
        
        sender.layer.borderWidth = 5.0
        sender.layer.borderColor = UIColor.lightGray.cgColor
        selectedButton = sender
        titleLabel.textColor = selectedColor.colorValue
        toolbar.tintColor = selectedColor.colorValue
    }
    
    @IBAction func save(_ sender: AnyObject) {
        let list = List()
        list.color = selectedColor
        
        listsController.createListInfoForList(list, withName: selectedTitle!)
        
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func cancel(_ sender: AnyObject) {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        let possibleTouch = touches.first
        
        if let touch = possibleTouch {
            // The user has tapped outside the text field, resign first responder, if necessary.
            if nameField.isFirstResponder && touch.view != nameField {
                nameField.resignFirstResponder()
            }
        }
    }
    
    // MARK: UITextFieldDelegate
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return false }
        
        let updatedText = (text as NSString).replacingCharacters(in: range, with: string)
        updateForProposedListName(updatedText)
        
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let text = textField.text else { return }
        
        updateForProposedListName(text)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        return true
    }
    
    // MARK: Convenience
    
    func updateForProposedListName(_ name: String) {
        if listsController.canCreateListInfoWithName(name) {
            saveButton.isEnabled = true
            selectedTitle = name
        }
        else {
            saveButton.isEnabled = false
        }
    }
}
