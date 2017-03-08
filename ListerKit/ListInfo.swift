/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `ListInfo` class is a caching abstraction over a `List` object that contains information about lists (e.g. color and name).
*/

import UIKit

open class ListInfo: NSObject {
    // MARK: Properties

    open let URL: Foundation.URL
    
    open var color: List.Color?

    open var name: String {
        let displayName = FileManager.default.displayName(atPath: URL.path)

        return (displayName as NSString).deletingPathExtension
    }

    fileprivate let fetchQueue = DispatchQueue(label: "com.example.apple-samplecode.listinfo", attributes: [])

    // MARK: Initializers

    public init(URL: Foundation.URL) {
        self.URL = URL
    }

    // MARK: Fetch Methods

    open func fetchInfoWithCompletionHandler(_ completionHandler: @escaping (Void) -> Void) {
        fetchQueue.async {
            // If the color hasn't been set yet, the info hasn't been fetched.
            if self.color != nil {
                completionHandler()
                
                return
            }
            
            ListUtilities.readListAtURL(self.URL) { list, error in
                self.fetchQueue.async {
                    if let list = list {
                        self.color = list.color
                    }
                    else {
                        self.color = .gray
                    }
                    
                    completionHandler()
                }
            }
        }
    }
    
    // MARK: NSObject
    
    override open func isEqual(_ object: Any?) -> Bool {
        if let listInfo = object as? ListInfo {
            return listInfo.URL == URL
        }

        return false
    }
}
