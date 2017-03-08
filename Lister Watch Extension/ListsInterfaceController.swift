/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `ListInterfaceController` that presents a single list managed by a `ListPresenterType` instance.
*/

import WatchKit
import ListerWatchKit

class ListsInterfaceController: WKInterfaceController, ConnectivityListsControllerDelegate {
    // MARK: Types
    
    struct Storyboard {
        struct RowTypes {
            static let list = "ListsInterfaceControllerListRowType"
            static let noLists = "ListsInterfaceControllerNoListsRowType"
        }
        
        struct Segues {
            static let listSelection = "ListsInterfaceControllerListSelectionSegue"
        }
    }
    
    // MARK: Properties
    
    @IBOutlet weak var interfaceTable: WKInterfaceTable!
    
    let listsController = ConnectivityListsController()

    // MARK: Initializers
    
    override init() {
        super.init()

        let noListsIndexSet = IndexSet(integer: 0)
        interfaceTable.insertRows(at: noListsIndexSet, withRowType: Storyboard.RowTypes.noLists)
    }
    
    // MARK: ConnectivityListsControllerDelegate

    func listsController(_ listsController: ConnectivityListsController, didInsertListInfo listInfo: ListInfo, atIndex index: Int) {
        let indexSet = IndexSet(integer: index)
        
        // The lists controller was previously empty. Remove the "no lists" row.
        if index == 0 && listsController.count == 1 {
            interfaceTable.removeRows(at: indexSet)
        }
        
        interfaceTable.insertRows(at: indexSet, withRowType: Storyboard.RowTypes.list)

        configureRowControllerAtIndex(index)
    }
    
    func listsController(_ listsController: ConnectivityListsController, didRemoveListInfo listInfo: ListInfo, atIndex index: Int) {
        let indexSet = IndexSet(integer: index)
        
        // The lists controller is now empty. Add the "no lists" row.
        if index == 0 && listsController.count == 0 {
            interfaceTable.insertRows(at: indexSet, withRowType: Storyboard.RowTypes.noLists)
        }
        
        interfaceTable.removeRows(at: indexSet)
    }
    
    func listsController(_ listsController: ConnectivityListsController, didUpdateListInfo listInfo: ListInfo, atIndex index: Int) {
        configureRowControllerAtIndex(index)
    }

    // MARK: Segues
    
    override func contextForSegue(withIdentifier segueIdentifier: String, in table: WKInterfaceTable, rowIndex: Int) -> Any? {
        if segueIdentifier == Storyboard.Segues.listSelection {
            let listInfo = listsController[rowIndex]

            return listInfo
        }
        
        return nil
    }
    
    // MARK: Convenience
    
    func configureRowControllerAtIndex(_ index: Int) {
        let listRowController = interfaceTable.rowController(at: index) as! ColoredTextRowController
        
        let listInfo = listsController[index]
        
        listRowController.setColor(listInfo.color.colorValue)
        listRowController.setText(listInfo.name)
    }
    
    // MARK: Interface Life Cycle

    override func willActivate() {
        let extensionDelegate = WKExtension.shared().delegate as? ExtensionDelegate
        
        extensionDelegate?.mainInterfaceController = self
        
        // If the `ListsController` is activating, we should invalidate any pending user activities.
        invalidateUserActivity()
        
        listsController.delegate = self

        listsController.startSearching()
    }

    override func didDeactivate() {
        listsController.stopSearching()
    }
    
    override func handleUserActivity(_ userInfo: [AnyHashable: Any]?) {
        //The Lister watch app only supports continuing activities where `AppConfiguration.UserActivity.listURLPathUserInfoKey` is provided.
        guard let listInfoFilePath = userInfo?[AppConfiguration.UserActivity.listURLPathUserInfoKey] as? String,
              let rawColor = userInfo?[AppConfiguration.UserActivity.listColorUserInfoKey] as? Int,
              let color = List.Color(rawValue: rawColor) else { return }
        
        // Create a `ListInfo` that represents the list at `listInfoURL`.
        let lastPathComponent = (listInfoFilePath as NSString).lastPathComponent
        let name = (lastPathComponent as NSString).deletingPathExtension
        let listInfo = ListInfo(name: name, color: color)
        
        // Present a `ListInterfaceController`.
        pushController(withName: ListInterfaceController.Storyboard.interfaceControllerName, context: listInfo)
    }
}
