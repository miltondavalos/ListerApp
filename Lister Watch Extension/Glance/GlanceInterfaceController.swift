/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    Controls the interface of the Glance. The controller displays statistics about the Today list.
*/

import WatchKit
import ListerWatchKit

class GlanceInterfaceController: WKInterfaceController, ConnectivityListsControllerDelegate, ListPresenterDelegate, NSFilePresenter {
    // MARK: Properties
    
    @IBOutlet weak var glanceBadgeImage: WKInterfaceImage!
    
    @IBOutlet weak var glanceBadgeGroup: WKInterfaceGroup!
    
    @IBOutlet weak var remainingItemsLabel: WKInterfaceLabel!
    
    let listsController = ConnectivityListsController(listName: AppConfiguration.localizedTodayDocumentName)
    
    let listPresenter = AllListItemsPresenter()
    
    var isPresenting = false
    
    var listURL: URL?
    
    var presentedItemURL: URL? {
        return listURL
    }
    
    var presentedItemOperationQueue = OperationQueue()
    
    // Tracks underlying values that represent the badge.
    var previousPresentedBadgeCounts: (totalListItemCount: Int, completeListItemCount: Int)?
    
    // MARK: Setup

    func setupInterface() {
        // If no previously presented data exists, clear the initial UI elements.
        if previousPresentedBadgeCounts == nil {
            glanceBadgeGroup.setBackgroundImage(nil)
            glanceBadgeImage.setImage(nil)
            remainingItemsLabel.setHidden(true)
        }
        
        initializeListsController()
    }
    
    func initializeListsController() {
        listsController.delegate = self
        
        listsController.startSearching()
    }
    
    // MARK: ListsControllerDelegate

    func listsController(_: ConnectivityListsController, didInsertListInfo listInfo: ListInfo, atIndex index: Int) {
        // We only expect a single result to be returned, so we will treat this listInfo as the Today document.
        processListInfoAsTodayDocument(listInfo)
    }
    
    // MARK: ListPresenterDelegate
    
    func listPresenterDidRefreshCompleteLayout(_: ListPresenterType) {
        // Since the list changed completely, show present the Glance badge.
        presentGlanceBadge()
    }
    
    /**
        These methods are no ops because all of the data is bulk rendered after the the content changes. This
        can occur in `listPresenterDidRefreshCompleteLayout(_:)` or in `listPresenterDidChangeListLayout(_:isInitialLayout:)`.
    */
    func listPresenterWillChangeListLayout(_: ListPresenterType, isInitialLayout: Bool) {}
    func listPresenter(_: ListPresenterType, didInsertListItem listItem: ListItem, atIndex index: Int) {}
    func listPresenter(_: ListPresenterType, didRemoveListItem listItem: ListItem, atIndex index: Int) {}
    func listPresenter(_: ListPresenterType, didUpdateListItem listItem: ListItem, atIndex index: Int) {}
    func listPresenter(_: ListPresenterType, didUpdateListColorWithColor color: List.Color) {}
    func listPresenter(_: ListPresenterType, didMoveListItem listItem: ListItem, fromIndex: Int, toIndex: Int) {}
    
    func listPresenterDidChangeListLayout(_: ListPresenterType, isInitialLayout: Bool) {
        /*
            The list's layout changed. However, since we don't care that a small detail about the list changed,
            we're going to re-animate the badge.
        */
        presentGlanceBadge()
    }
    
    // MARK: Lifecycle
    
    override func willActivate() {
        /*
            Setup the interface in `willActivate` to ensure the interface is refreshed each time the interface
            controller is presented.
        */
        setupInterface()
    }
    
    override func didDeactivate() {
        listsController.stopSearching()
        listsController.delegate = nil
        
        removeFilePresenterIfNeeded()
    }
    
    // MARK: Convenience
    
    func addFilePresenterIfNeeded() {
        if !isPresenting {
            isPresenting = true
            NSFileCoordinator.addFilePresenter(self)
        }
    }
    
    func removeFilePresenterIfNeeded() {
        if isPresenting {
            isPresenting = false
            NSFileCoordinator.removeFilePresenter(self)
        }
    }
    
    func processListInfoAsTodayDocument(_ listInfo: ListInfo) {
        listPresenter.delegate = self
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        listURL = documentsURL.appendingPathComponent("\(listInfo.name).\(AppConfiguration.listerFileExtension)")
        
        readTodayDocument()
    }
    
    func readTodayDocument() {
        ListUtilities.readListAtURL(presentedItemURL!) { list, error in
            if error != nil {
                NSLog("Couldn't open document: \(self.presentedItemURL!.absoluteString)")
            }
            else {
                self.addFilePresenterIfNeeded()
                self.listPresenter.setList(list!)
                
                /*
                    Once the Today document has been found and opened, update the user activity with its URL path
                    to enable a tap on the glance to jump directly to the Today document in the watch app. A URL path
                    is passed instead of a URL because the `userInfo` dictionary of a WatchKit app's user activity
                    does not allow NSURL values.
                */
                let userInfo: [AnyHashable: Any] = [
                    AppConfiguration.UserActivity.listURLPathUserInfoKey: self.presentedItemURL!.path,
                    AppConfiguration.UserActivity.listColorUserInfoKey: self.listPresenter.color.rawValue
                ]
                
                /*
                    Lister uses a specific user activity name registered in the Info.plist and defined as a constant to
                    separate this action from the built-in UIDocument handoff support.
                */
                self.updateUserActivity(AppConfiguration.UserActivity.watch, userInfo: userInfo, webpageURL: nil)
            }
        }
    }
    
    func presentGlanceBadge() {
        let totalListItemCount = listPresenter.count
        
        let completeListItemCount = listPresenter.presentedListItems.filter { $0.isComplete }.count
        
        /* 
            If the `totalListItemCount` and the `completeListItemCount` haven't changed, there's no need to re-present
            the badge.
        */
        if let previousPresentedBadgeCounts = previousPresentedBadgeCounts {
            if previousPresentedBadgeCounts.totalListItemCount == totalListItemCount && previousPresentedBadgeCounts.completeListItemCount == completeListItemCount {
                return
            }
        }

        // Update `previousPresentedBadgeCounts`.
        previousPresentedBadgeCounts = (totalListItemCount, completeListItemCount)
        
        // Construct and present the new badge.
        let glanceBadge = GlanceBadge(totalItemCount: totalListItemCount, completeItemCount: completeListItemCount)
        
        glanceBadgeGroup.setBackgroundImage(glanceBadge.groupBackgroundImage)
        glanceBadgeImage.setImageNamed(glanceBadge.imageName)
        glanceBadgeImage.startAnimatingWithImages(in: glanceBadge.imageRange, duration: glanceBadge.animationDuration, repeatCount: 1)
        
        /*
            Create a localized string for the # items remaining in the Glance badge. The string is retrieved
            from the Localizable.stringsdict file.
        */
        let itemsRemainingText = String.localizedStringWithFormat(NSLocalizedString("%d items left", comment: ""), glanceBadge.incompleteItemCount)
        remainingItemsLabel.setText(itemsRemainingText)
        remainingItemsLabel.setHidden(false)
    }
    
    // MARK: NSFilePresenter
    
    func relinquishPresentedItem(toWriter writer: @escaping ((() -> Void)?) -> Void) {
        writer {
            self.readTodayDocument()
        }
    }
    
    func presentedItemDidMove(to newURL: URL) {
        listURL = newURL
    }
}
