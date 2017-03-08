/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `ListUtilities` class provides a suite of convenience methods for interacting with `List` objects and their associated files.
*/

import Foundation

/// An internal queue to the `ListUtilities` class that is used for `NSFileCoordinator` callbacks.
private var listUtilitiesQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    
    return queue
}()

open class ListUtilities {
    // MARK: Properties

    open class var localDocumentsDirectory: URL  {
        let documentsURL = sharedApplicationGroupContainer.appendingPathComponent("Documents", isDirectory: true)
        
        do {
            // This will throw if the directory cannot be successfully created, or does not already exist.
            try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
            
            return documentsURL
        }
        catch let error as NSError {
            fatalError("The shared application group documents directory doesn't exist and could not be created. Error: \(error.localizedDescription)")
        }
    }
    
    fileprivate class var sharedApplicationGroupContainer: URL {
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfiguration.ApplicationGroups.primary)

        if containerURL == nil {
            fatalError("The shared application group container is unavailable. Check your entitlements and provisioning profiles for this target. Details on proper setup can be found in the PDFs referenced from the README.")
        }
        
        return containerURL!
    }
    
    // MARK: List Handling Methods
    
    open class func copyInitialLists() {
        let defaultListURLs = Bundle.main.urls(forResourcesWithExtension: AppConfiguration.listerFileExtension, subdirectory: "")!
        
        for url in defaultListURLs {
            copyURLToDocumentsDirectory(url)
        }
    }
    
    open class func copyTodayList() {
        let url = Bundle.main.url(forResource: AppConfiguration.localizedTodayDocumentName, withExtension: AppConfiguration.listerFileExtension)!
        copyURLToDocumentsDirectory(url)
    }

    open class func migrateLocalListsToCloud() {
        let defaultQueue = DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default)

        defaultQueue.async {
            let fileManager = FileManager.default
            
            // Note the call to URLForUbiquityContainerIdentifier(_:) should be on a background queue.
            if let cloudDirectoryURL = fileManager.url(forUbiquityContainerIdentifier: nil) {
                let documentsDirectoryURL = cloudDirectoryURL.appendingPathComponent("Documents")
                
                do {
                    let localDocumentURLs = try fileManager.contentsOfDirectory(at: ListUtilities.localDocumentsDirectory, includingPropertiesForKeys: nil, options: .skipsPackageDescendants)
                
                    for URL in localDocumentURLs {
                        if URL.pathExtension == AppConfiguration.listerFileExtension {
                            self.makeItemUbiquitousAtURL(URL, documentsDirectoryURL: documentsDirectoryURL)
                        }
                    }
                }
                catch let error as NSError {
                    print("The contents of the local documents directory could not be accessed. Error: \(error.localizedDescription)")
                }
                // Requiring an additional catch to satisfy exhaustivity is a known issue.
                catch {}
            }
        }
    }
    
    // MARK: Convenience
    
    fileprivate class func makeItemUbiquitousAtURL(_ sourceURL: URL, documentsDirectoryURL: URL) {
        let destinationFileName = sourceURL.lastPathComponent
        
        let fileManager = FileManager()
        let destinationURL = documentsDirectoryURL.appendingPathComponent(destinationFileName)
        
        if fileManager.isUbiquitousItem(at: destinationURL) ||
            fileManager.fileExists(atPath: destinationURL.path) {
            // If the file already exists in the cloud, remove the local version and return.
            removeListAtURL(sourceURL, completionHandler: nil)
            return
        }
        
        let defaultQueue = DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default)
        
        defaultQueue.async {
            do {
                try fileManager.setUbiquitous(true, itemAt: sourceURL, destinationURL: destinationURL)
                return
            }
            catch let error as NSError {
                print("Failed to make list ubiquitous. Error: \(error.localizedDescription)")
            }
            // Requiring an additional catch to satisfy exhaustivity is a known issue.
            catch {}
        }
    }

    open class func readListAtURL(_ url: URL, completionHandler: @escaping (List?, NSError?) -> Void) {
        let fileCoordinator = NSFileCoordinator()
        
        // `url` may be a security scoped resource.
        let successfulSecurityScopedResourceAccess = url.startAccessingSecurityScopedResource()
        
        let readingIntent = NSFileAccessIntent.readingIntent(with: url, options: .withoutChanges)
        fileCoordinator.coordinate(with: [readingIntent], queue: listUtilitiesQueue) { accessError in
            if accessError != nil {
                if successfulSecurityScopedResourceAccess {
                    url.stopAccessingSecurityScopedResource()
                }
                
                completionHandler(nil, accessError as NSError?)
                
                return
            }
            
            // Local variables that will be used as parameters to `completionHandler`.
            var deserializedList: List?
            var readError: NSError?
            
            do {
                let contents = try Data(contentsOf: readingIntent.url, options: .uncached)
                deserializedList = NSKeyedUnarchiver.unarchiveObject(with: contents) as? List
                
                assert(deserializedList != nil, "The provided URL must correspond to a `List` object.")
            }
            catch let error as NSError {
                readError = error as NSError
            }
            // Requiring an additional catch to satisfy exhaustivity is a known issue.
            catch {}

            if successfulSecurityScopedResourceAccess {
                url.stopAccessingSecurityScopedResource()
            }
            
            completionHandler(deserializedList, readError)
        }
    }

    open class func createList(_ list: List, atURL url: URL, completionHandler: ((NSError?) -> Void)? = nil) {
        let fileCoordinator = NSFileCoordinator()
        
        let writingIntent = NSFileAccessIntent.writingIntent(with: url, options: .forReplacing)
        fileCoordinator.coordinate(with: [writingIntent], queue: listUtilitiesQueue) { accessError in
            if accessError != nil {
                completionHandler?(accessError as NSError?)
                
                return
            }
            
            var writeError: NSError?

            let seralizedListData = NSKeyedArchiver.archivedData(withRootObject: list)
            
            do {
                try seralizedListData.write(to: writingIntent.url, options: .atomic)
            
                let fileAttributes = [FileAttributeKey.extensionHidden: true]
                
                try FileManager.default.setAttributes(fileAttributes, ofItemAtPath: writingIntent.url.path)
            }
            catch let error as NSError {
                writeError = error
            }
            // Requiring an additional catch to satisfy exhaustivity is a known issue.
            catch {}
            
            completionHandler?(writeError)
        }
    }
    
    class func removeListAtURL(_ url: URL, completionHandler: ((NSError?) -> Void)? = nil) {
        let fileCoordinator = NSFileCoordinator()
        
        // `url` may be a security scoped resource.
        let successfulSecurityScopedResourceAccess = url.startAccessingSecurityScopedResource()

        let writingIntent = NSFileAccessIntent.writingIntent(with: url, options: .forDeleting)
        fileCoordinator.coordinate(with: [writingIntent], queue: listUtilitiesQueue) { accessError in
            if accessError != nil {
                completionHandler?(accessError as NSError?)
                
                return
            }
            
            let fileManager = FileManager()
            
            var removeError: NSError?
            
            do {
                try fileManager.removeItem(at: writingIntent.url)
            }
            catch let error as NSError {
                removeError = error
            }
            // Requiring an additional catch to satisfy exhaustivity is a known issue.
            catch {}
            
            if successfulSecurityScopedResourceAccess {
                url.stopAccessingSecurityScopedResource()
            }

            completionHandler?(removeError)
        }
    }
    
    // MARK: Convenience
    
    fileprivate class func copyURLToDocumentsDirectory(_ url: URL) {
        let toURL = ListUtilities.localDocumentsDirectory.appendingPathComponent(url.lastPathComponent)
        
        if FileManager().fileExists(atPath: toURL.path) {
            // If the file already exists, don't attempt to copy the version from the bundle.
            return
        }
        
        copyFromURL(url, toURL: toURL)
    }
    
    open class func copyFromURL(_ fromURL: URL, toURL: URL) {
        let fileCoordinator = NSFileCoordinator()
        
        // `url` may be a security scoped resource.
        let successfulSecurityScopedResourceAccess = fromURL.startAccessingSecurityScopedResource()
        
        let fileManager = FileManager()
        
        // First copy the source file into a temporary location where the replace can be carried out.
        var tempDirectory: URL?
        var tempURL: URL?
        do {
            tempDirectory = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: toURL, create: true)
            tempURL = tempDirectory!.appendingPathComponent(toURL.lastPathComponent)
            try fileManager.copyItem(at: fromURL, to: tempURL!)
        }
        catch let error as NSError {
            // An error occured when moving `url` to `toURL`. In your app, handle this gracefully.
            print("Couldn't create temp file from: \(fromURL) at: \(tempURL) error: \(error.localizedDescription).")
            print("Error\nCode: \(error.code)\nDomain: \(error.domain)\nDescription: \(error.localizedDescription)\nReason: \(error.localizedFailureReason)\nUser Info: \(error.userInfo)\n")
            
            return
        }

        // Now perform a coordinated replace to move the file from the temporary location to its final destination.
        let movingIntent = NSFileAccessIntent.writingIntent(with: tempURL!, options: .forMoving)
        let mergingIntent = NSFileAccessIntent.writingIntent(with: toURL, options: .forMerging)
        fileCoordinator.coordinate(with: [movingIntent, mergingIntent], queue: listUtilitiesQueue) { accessError in
            if accessError != nil {
                print("Couldn't move file: \(fromURL.absoluteString) to: \(toURL.absoluteString) error: \(accessError!.localizedDescription).")
                return
            }
            
            do {
                try Data(contentsOf: movingIntent.url, options: []).write(to: mergingIntent.url, options: [.atomic])
                
                let fileAttributes = [FileAttributeKey.extensionHidden: true]
                
                try fileManager.setAttributes(fileAttributes, ofItemAtPath: mergingIntent.url.path)
            }
            catch let error as NSError {
                // An error occured when moving `url` to `toURL`. In your app, handle this gracefully.
                print("Couldn't move file: \(fromURL) to: \(toURL) error: \(error.localizedDescription).")
                print("Error\nCode: \(error.code)\nDomain: \(error.domain)\nDescription: \(error.localizedDescription)\nReason: \(error.localizedFailureReason)\nUser Info: \(error.userInfo)\n")
            }
            // Requiring an additional catch to satisfy exhaustivity is a known issue.
            catch {}
            
            if successfulSecurityScopedResourceAccess {
                fromURL.stopAccessingSecurityScopedResource()
            }
            
            // Cleanup
            guard let directoryToRemove = tempDirectory else { return }
            do {
                try fileManager.removeItem(at: directoryToRemove)
            }
            catch {}
        }
    }
}
