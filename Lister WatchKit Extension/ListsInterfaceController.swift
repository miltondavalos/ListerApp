/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `ListInterfaceController` that presents a single list managed by a `ListPresenterType` instance.
*/

import WatchKit
import ListerKit

class ListsInterfaceController: WKInterfaceController, ListsControllerDelegate {
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
    
    var listsController: ListsController!

    // MARK: Initializers
    
    override init() {
        super.init()

        listsController = AppConfiguration.sharedConfiguration.listsControllerForCurrentConfigurationWithPathExtension(AppConfiguration.listerFileExtension)

        let noListsIndexSet = IndexSet(integer: 0)
        interfaceTable.insertRows(at: noListsIndexSet, withRowType: Storyboard.RowTypes.noLists)
        
        if AppConfiguration.sharedConfiguration.isFirstLaunch {
            print("Lister does not currently support configuring a storage option before the iOS app is launched. Please launch the iOS app first. See the Release Notes section in README.md for more information.")
        }
    }
    
    // MARK: ListsControllerDelegate

    func listsController(_ listsController: ListsController, didInsertListInfo listInfo: ListInfo, atIndex index: Int) {
        let indexSet = IndexSet(integer: index)
        
        // The lists controller was previously empty. Remove the "no lists" row.
        if index == 0 && listsController.count == 1 {
            interfaceTable.removeRows(at: indexSet)
        }
        
        interfaceTable.insertRows(at: indexSet, withRowType: Storyboard.RowTypes.list)

        configureRowControllerAtIndex(index)
    }
    
    func listsController(_ listsController: ListsController, didRemoveListInfo listInfo: ListInfo, atIndex index: Int) {
        let indexSet = IndexSet(integer: index)
        
        // The lists controller is now empty. Add the "no lists" row.
        if index == 0 && listsController.count == 0 {
            interfaceTable.insertRows(at: indexSet, withRowType: Storyboard.RowTypes.noLists)
        }
        
        interfaceTable.removeRows(at: indexSet)
    }
    
    func listsController(_ listsController: ListsController, didUpdateListInfo listInfo: ListInfo, atIndex index: Int) {
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
        
        listRowController.setText(listInfo.name)
        
        listInfo.fetchInfoWithCompletionHandler() {
            /*
                The fetchInfoWithCompletionHandler(_:) method calls its completion handler on a background
                queue, dispatch back to the main queue to make UI updates.
            */
            DispatchQueue.main.async {
                let listRowController = self.interfaceTable.rowController(at: index) as! ColoredTextRowController

                listRowController.setColor(listInfo.color!.colorValue)
            }
        }
    }
    
    // MARK: Interface Life Cycle

    override func willActivate() {
        // If the `ListsController` is activating, we should invalidate any pending user activities.
        invalidateUserActivity()
        
        listsController.delegate = self

        listsController.startSearching()
    }

    override func didDeactivate() {
        listsController.stopSearching()
        
        listsController.delegate = nil
    }
    
    override func handleUserActivity(_ userInfo: [AnyHashable: Any]?) {
        /*
            The Lister watch app only supports continuing activities where
            `AppConfiguration.UserActivity.listURLPathUserInfoKey` is provided.
        */
        let listInfoFilePath = userInfo?[AppConfiguration.UserActivity.listURLPathUserInfoKey] as? String
        
        // If no `listInfoFilePath` is found, there is no activity of interest to handle.
        if listInfoFilePath == nil {
            return
        }
        
        let listInfoURL = URL(fileURLWithPath: listInfoFilePath!, isDirectory: false)
        // Create a `ListInfo` that represents the list at `listInfoURL`.
        let listInfo = ListInfo(URL: listInfoURL)
        
        // Present a `ListInterfaceController`.
        pushController(withName: ListInterfaceController.Storyboard.interfaceControllerName, context: listInfo)
    }
}
