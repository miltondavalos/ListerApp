/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `CloudListCoordinator` class handles querying for and interacting with lists stored as files in iCloud Drive.
*/

import Foundation

/**
    An object that conforms to the `CloudListCoordinator` protocol and is responsible for implementing
    entry points in order to communicate with an `ListCoordinatorDelegate`. In the case of Lister,
    this is the `ListsController` instance. The main responsibility of a `CloudListCoordinator` is
    to track different `NSURL` instances that are important. The iCloud coordinator is responsible for
    making sure that the `ListsController` knows about the current set of iCloud documents that are
    available.

    There are also other responsibilities that an `CloudListCoordinator` must have that are specific
    to the underlying storage mechanism of the coordinator. A `CloudListCoordinator` determines whether
    or not a new list can be created with a specific name, it removes URLs tied to a specific list, and
    it is also responsible for listening for updates to any changes that occur at a specific URL
    (e.g. a list document is updated on another device, etc.).

    Instances of `CloudListCoordinator` can search for URLs in an asynchronous way. When a new `NSURL`
    instance is found, removed, or updated, the `ListCoordinator` instance must make its delegate
    aware of the updates. If a failure occured in removing or creating an `NSURL` for a given list,
    it must make its delegate aware by calling one of the appropriate error methods defined in the
    `ListCoordinatorDelegate` protocol.
*/
open class CloudListCoordinator: ListCoordinator {
    // MARK: Properties
    
    open weak var delegate: ListCoordinatorDelegate?
    
    /// Closure executed after the first update provided by the coordinator regarding tracked URLs.
    fileprivate var firstQueryUpdateHandler: ((Void) -> Void)?
    
    /// Initialized asynchronously in init(predicate:).
    fileprivate var _documentsDirectory: URL!
    
    open var documentsDirectory: URL {
        var documentsDirectory: URL!
        
        documentsDirectoryQueue.sync {
            documentsDirectory = self._documentsDirectory
        }
        
        return documentsDirectory
    }

    fileprivate var metadataQuery: NSMetadataQuery
    
    /// A private, local queue to `CloudListCoordinator` that is used to ensure serial accesss to `documentsDirectory`.
    fileprivate let documentsDirectoryQueue = DispatchQueue(label: "com.example.apple-samplecode.lister.cloudlistcoordinator", attributes: DispatchQueue.Attributes.concurrent)
    
    // MARK: Initializers
    
    /**
        Initializes an `CloudListCoordinator` based on a path extension used to identify files that can be
        managed by the app. Also provides a block parameter that can be used to provide actions to be executed
        when the coordinator returns its first set of documents. This coordinator monitors the app's iCloud Drive
        container.

        - parameter pathExtension: The extension that should be used to identify documents of interest to this coordinator.
        - parameter firstQueryUpdateHandler: The handler that is executed once the first results are returned.
    */
    public convenience init(pathExtension: String, firstQueryUpdateHandler: ((Void) -> Void)? = nil) {
        let predicate = NSPredicate(format: "(%K.pathExtension = %@)", argumentArray: [NSMetadataItemURLKey, pathExtension])
        
        self.init(predicate: predicate, firstQueryUpdateHandler: firstQueryUpdateHandler)
    }
    
    /**
        Initializes an `CloudListCoordinator` based on a single document used to identify a file that should
        be monitored. Also provides a block parameter that can be used to provide actions to be executed when the
        coordinator returns its initial result. This coordinator monitors the app's iCloud Drive container.

        - parameter lastPathComponent: The file name that should be monitored by this coordinator.
        - parameter firstQueryUpdateHandler: The handler that is executed once the first results are returned.
    */
    public convenience init(lastPathComponent: String, firstQueryUpdateHandler: ((Void) -> Void)? = nil) {
        let predicate = NSPredicate(format: "(%K.lastPathComponent = %@)", argumentArray: [NSMetadataItemURLKey, lastPathComponent])

        self.init(predicate: predicate, firstQueryUpdateHandler: firstQueryUpdateHandler)
    }
    
    fileprivate init(predicate: NSPredicate, firstQueryUpdateHandler: ((Void) -> Void)?) {
        self.firstQueryUpdateHandler = firstQueryUpdateHandler
        
        metadataQuery = NSMetadataQuery()

        // These search scopes search for files in iCloud Drive.
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope, NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope]
        
        metadataQuery.predicate = predicate
        
        documentsDirectoryQueue.async(flags: .barrier, execute: {
            let cloudContainerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)

            self._documentsDirectory = cloudContainerURL?.appendingPathComponent("Documents")
        }) 
        
        // Observe the query.
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.addObserver(self, selector: #selector(CloudListCoordinator.metadataQueryDidFinishGathering(_:)), name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: metadataQuery)

        notificationCenter.addObserver(self, selector: #selector(CloudListCoordinator.metadataQueryDidUpdate(_:)), name: NSNotification.Name.NSMetadataQueryDidUpdate, object: metadataQuery)
    }
    
    // MARK: Lifetime
    
    deinit {
        // Stop observing the query.
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: metadataQuery)
        notificationCenter.removeObserver(self, name: NSNotification.Name.NSMetadataQueryDidUpdate, object: metadataQuery)
    }
    
    // MARK: ListCoordinator
    
    open func startQuery() {
        // `NSMetadataQuery` should always be started on the main thread.
        DispatchQueue.main.async {
            self.metadataQuery.start()
            return
        }
    }
    
    open func stopQuery() {
        // `NSMetadataQuery` should always be stopped on the main thread.
        DispatchQueue.main.async {
            self.metadataQuery.stop()
        }
    }
    
    open func createURLForList(_ list: List, withName name: String) {
        let documentURL = documentURLForName(name)
        
        ListUtilities.createList(list, atURL: documentURL) { error in
            if let realError = error {
                self.delegate?.listCoordinatorDidFailCreatingListAtURL(documentURL, withError: realError)
            }
            else {
                self.delegate?.listCoordinatorDidUpdateContents(insertedURLs: [documentURL], removedURLs: [], updatedURLs: [])
            }
        }
    }

    open func canCreateListWithName(_ name: String) -> Bool {
        if name.isEmpty {
            return false
        }
        
        let documentURL = documentURLForName(name)
        
        return !FileManager.default.fileExists(atPath: documentURL.path)
    }
    
    open func copyListFromURL(_ URL: Foundation.URL, toListWithName name: String) {
        let documentURL = documentURLForName(name)
        
        ListUtilities.copyFromURL(URL, toURL: documentURL)
    }

    open func removeListAtURL(_ URL: Foundation.URL) {
        ListUtilities.removeListAtURL(URL) { error in
            if let realError = error {
                self.delegate?.listCoordinatorDidFailRemovingListAtURL(URL, withError: realError)
            }
            else {
                self.delegate?.listCoordinatorDidUpdateContents(insertedURLs: [], removedURLs: [URL], updatedURLs: [])
            }
        }
    }
    
    // MARK: NSMetadataQuery Notifications
    
    @objc fileprivate func metadataQueryDidFinishGathering(_ notifcation: Notification) {
        metadataQuery.disableUpdates()

        let metadataItems = metadataQuery.results as! [NSMetadataItem]

        let insertedURLs = metadataItems.map { $0.value(forAttribute: NSMetadataItemURLKey) as! URL }

        delegate?.listCoordinatorDidUpdateContents(insertedURLs: insertedURLs, removedURLs: [], updatedURLs: [])
        
        metadataQuery.enableUpdates()
        
        // Execute the `firstQueryUpdateHandler`, it will contain the closure from initialization on first update.
        if let handler = firstQueryUpdateHandler {
            handler()
            // Set `firstQueryUpdateHandler` to an empty closure so that the handler provided is only run on first update.
            firstQueryUpdateHandler = nil
        }
    }

    /**
        Private methods that are used with Objective-C for notifications, target / action, etc. should
        be marked as @objc.
    */
    @objc fileprivate func metadataQueryDidUpdate(_ notification: Notification) {
        metadataQuery.disableUpdates()
        
        let insertedURLs: [URL]
        let removedURLs: [URL]
        let updatedURLs: [URL]
        
        let metadataItemToURLTransform: (NSMetadataItem) -> URL = { metadataItem in
            return metadataItem.value(forAttribute: NSMetadataItemURLKey) as! URL
        }

        if let insertedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] {
            insertedURLs = insertedMetadataItems.map(metadataItemToURLTransform)
        }
        else {
            insertedURLs = []
        }
        
        if let removedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem] {
            removedURLs = removedMetadataItems.map(metadataItemToURLTransform)
        }
        else {
            removedURLs = []
        }
        
        if let updatedMetadataItems = notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] {
            let completelyDownloadedUpdatedMetadataItems = updatedMetadataItems.filter { updatedMetadataItem in
                let downloadStatus = updatedMetadataItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as! String

                return downloadStatus == NSMetadataUbiquitousItemDownloadingStatusCurrent
            }

            updatedURLs = completelyDownloadedUpdatedMetadataItems.map(metadataItemToURLTransform)
        }
        else {
            updatedURLs = []
        }
        
        delegate?.listCoordinatorDidUpdateContents(insertedURLs: insertedURLs, removedURLs: removedURLs, updatedURLs: updatedURLs)
        
        metadataQuery.enableUpdates()
    }
    
    // MARK: Convenience
    
    fileprivate func documentURLForName(_ name: String) -> URL {
        let documentURLWithoutExtension = documentsDirectory.appendingPathComponent(name)
        
        return documentURLWithoutExtension.appendingPathExtension(AppConfiguration.listerFileExtension)
    }
}
