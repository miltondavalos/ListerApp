/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `ListDocument` class is a `UIDocument` subclass that represents a list. `ListDocument` manages the serialization / deserialization of the list object in addition to a list presenter.
*/

import UIKit
import WatchConnectivity

/// Protocol that allows a list document to notify other objects of it being deleted.
@objc public protocol ListDocumentDelegate {
    func listDocumentWasDeleted(_ listDocument: ListDocument)
}

open class ListDocument: UIDocument {
    // MARK: Properties

    open weak var delegate: ListDocumentDelegate?
    
    // Use a default, empty list.
    open var listPresenter: ListPresenterType?

    // MARK: Initializers
    
    public init(fileURL URL: Foundation.URL, listPresenter: ListPresenterType? = nil) {
        self.listPresenter = listPresenter

        super.init(fileURL: URL)
    }

    // MARK: Serialization / Deserialization

    override open func load(fromContents contents: Any, ofType typeName: String?) throws {
        if let unarchivedList = NSKeyedUnarchiver.unarchiveObject(with: contents as! Data) as? List {
            /*
                This method is called on the queue that the `openWithCompletionHandler(_:)` method was called
                on (typically, the main queue). List presenter operations are main queue only, so explicitly
                call on the main queue.
            */
            DispatchQueue.main.async {
                self.listPresenter?.setList(unarchivedList)
                
                return
            }

            return
        }
        
        throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError, userInfo: [
            NSLocalizedDescriptionKey: NSLocalizedString("Could not read file", comment: "Read error description"),
            NSLocalizedFailureReasonErrorKey: NSLocalizedString("File was in an invalid format", comment: "Read failure reason")
        ])
    }

    override open func contents(forType typeName: String) throws -> Any {
        if let archiveableList = listPresenter?.archiveableList {
            return NSKeyedArchiver.archivedData(withRootObject: archiveableList)
        }

        throw NSError(domain: "ListDocumentDomain", code: -1, userInfo: [
            NSLocalizedDescriptionKey: NSLocalizedString("Could not archive list", comment: "Archive error description"),
            NSLocalizedFailureReasonErrorKey: NSLocalizedString("No list presenter was available for the document", comment: "Archive failure reason")
        ])
    }
    
    // MARK: Saving
    
    override open func save(to url: URL, for saveOperation: UIDocumentSaveOperation, completionHandler: ((Bool) -> Void)?) {
        super.save(to: url, for: saveOperation) { success in
            // If `WCSession` isn't supported there is nothing else required.
            guard WCSession.isSupported() else {
                completionHandler?(success)
                return
            }
            
            let session = WCSession.default()
            
            // Do not proceed if `session` is not currently `.Activated` or the watch app is not installed.
            guard session.activationState == .activated && session.isWatchAppInstalled else {
                completionHandler?(success)
                return
            }
            
            // On a successful save, transfer the file to the paired watch if appropriate.
            if success {
                let fileCoordinator = NSFileCoordinator()
                let readingIntent = NSFileAccessIntent.readingIntent(with: url, options: [])
                fileCoordinator.coordinate(with: [readingIntent], queue: OperationQueue()) { accessError in
                    if accessError != nil {
                        return
                    }
                    
                    // Do not proceed if `session` is not currently `.Activated`.
                    guard session.activationState == .activated else { return }
                    
                    for transfer in session.outstandingFileTransfers {
                        if transfer.file.fileURL == readingIntent.url {
                            transfer.cancel()
                            break
                        }
                    }
                    
                    session.transferFile(readingIntent.url, metadata: nil)
                }
            }
            
            completionHandler?(success)
        }
    }
    
    // MARK: Deletion

    override open func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        super.accommodatePresentedItemDeletion(completionHandler: completionHandler)
        
        delegate?.listDocumentWasDeleted(self)
    }
    
    // MARK: Handoff
    
    override open func updateUserActivityState(_ userActivity: NSUserActivity) {
        super.updateUserActivityState(userActivity)
        
        if let rawColorValue = listPresenter?.color.rawValue {
            userActivity.addUserInfoEntries(from: [
                AppConfiguration.UserActivity.listColorUserInfoKey: rawColorValue
            ])
        }
    }
}
