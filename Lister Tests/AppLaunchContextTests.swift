/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The test case class for the `AppLaunchContext` class.
*/

import Lister
import ListerKit
import UIKit
import XCTest

class AppLaunchContextTests: XCTestCase {
    // MARK: Types
    
    struct UserActivity {
        static let testing = "com.example.apple-samplecode.Lister.testing"
    }
    
    // MARK: Properties
    
    var listURLs = [URL]()
    
    var color = List.Color.blue
    
    // MARK: Setup
    
    override func setUp() {
        super.setUp()
        
        listURLs = Bundle.main.urls(forResourcesWithExtension: AppConfiguration.listerFileExtension, subdirectory: "") ?? []
    }
    
    // MARK: Initializers
    
    func testUserActivityInitializerWithNSUserActivityDocumentURLKey() {
        let userActivity = NSUserActivity(activityType: UserActivity.testing)
        
        userActivity.addUserInfoEntries(from: [
            NSUserActivityDocumentURLKey: listURLs.first!,
            AppConfiguration.UserActivity.listColorUserInfoKey: color.rawValue
        ])
        
        let listsController = AppConfiguration.sharedConfiguration.listsControllerForCurrentConfigurationWithPathExtension(AppConfiguration.listerFileExtension, firstQueryHandler: nil)
        let possibleLaunchContext = AppLaunchContext(userActivity: userActivity, listsController: listsController)
        
        XCTAssertNotNil(possibleLaunchContext)
        
        guard let launchContext = possibleLaunchContext else { return }
        
        XCTAssertEqual(launchContext.listURL.absoluteURL, listURLs.first!.absoluteURL)
        XCTAssertEqual(launchContext.listColor, color)
    }
    
    func testUserActivityInitializerWithAppConfigurationUserActivitylistURLPathUserInfoKey() {
        let userActivity = NSUserActivity(activityType: UserActivity.testing)
        
        userActivity.addUserInfoEntries(from: [
            AppConfiguration.UserActivity.listURLPathUserInfoKey: listURLs.first!.path!,
            AppConfiguration.UserActivity.listColorUserInfoKey: color.rawValue
            ])
        
        let listsController = AppConfiguration.sharedConfiguration.listsControllerForCurrentConfigurationWithPathExtension(AppConfiguration.listerFileExtension, firstQueryHandler: nil)
        let possibleLaunchContext = AppLaunchContext(userActivity: userActivity, listsController: listsController)
        
        XCTAssertNotNil(possibleLaunchContext)
        
        guard let launchContext = possibleLaunchContext else { return }
        
        XCTAssertEqual(launchContext.listURL.absoluteURL, listURLs.first!.absoluteURL)
        XCTAssertEqual(launchContext.listColor, color)
    }
    
    func testUserActivityInitializerPrefersNSUserActivityDocumentURLKey() {
        let userActivity = NSUserActivity(activityType: UserActivity.testing)
        
        userActivity.addUserInfoEntries(from: [
            NSUserActivityDocumentURLKey: listURLs.first!,
            AppConfiguration.UserActivity.listURLPathUserInfoKey: listURLs.last!.path!,
            AppConfiguration.UserActivity.listColorUserInfoKey: color.rawValue
            ])
        
        let listsController = AppConfiguration.sharedConfiguration.listsControllerForCurrentConfigurationWithPathExtension(AppConfiguration.listerFileExtension, firstQueryHandler: nil)
        let possibleLaunchContext = AppLaunchContext(userActivity: userActivity, listsController: listsController)
        
        XCTAssertNotNil(possibleLaunchContext)
        
        guard let launchContext = possibleLaunchContext else { return }
        
        XCTAssertEqual(launchContext.listURL.absoluteURL, listURLs.first!.absoluteURL)
        XCTAssertEqual(launchContext.listColor, color)
    }
    
    func testListerURLSchemeInitializer() {
        // Construct a URL with the lister scheme and the file path of the document.
        var urlComponents = URLComponents()
        urlComponents.scheme = AppConfiguration.ListerScheme.name
        urlComponents.path = listURLs.first!.path
        
        // Add a query item to encode the color associated with the list.
        let colorQueryValue = "\(color.rawValue)"
        let colorQueryItem = URLQueryItem(name: AppConfiguration.ListerScheme.colorQueryKey, value: colorQueryValue)
        urlComponents.queryItems = [colorQueryItem]
        
        let possibleLaunchContext = AppLaunchContext(listerURL: urlComponents.url!)
        
        XCTAssertNotNil(possibleLaunchContext)
        
        guard let launchContext = possibleLaunchContext else { return }
        
        XCTAssertEqual(launchContext.listURL.absoluteURL, listURLs.first!.absoluteURL)
        XCTAssertEqual(launchContext.listColor, color)
    }
}
