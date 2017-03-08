/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The test case class for the `List` class.
*/

import ListerKit
import XCTest

class ListTests: XCTestCase {
    // MARK: Properties

    // `items` is initialized again in setUp().
    var items = [ListItem]()
    
    var color = List.Color.green

    // Both of these lists are initialized in setUp().
    var list: List!

    // MARK: Setup
    
    override func setUp() {
        super.setUp()

        items = [
            ListItem(text: "zero", complete: false),
            ListItem(text: "one", complete: false),
            ListItem(text: "two", complete: false),
            ListItem(text: "three", complete: true),
            ListItem(text: "four", complete: true),
            ListItem(text: "five", complete: true)
        ]

        list = List(color: color, items: items)
    }
    
    // MARK: Initializers
    
    func testDefaultInitializer() {
        list = List()

        XCTAssertEqual(list.color, List.Color.gray, "The default list color is Gray.")
        XCTAssertTrue(list.items.isEmpty, "A default list has no list items.")
    }
    
    func testColorAndItemsDesignatedInitializer() {
        XCTAssertEqual(list.color, color)

        XCTAssertTrue(list.items == items)
    }

    func testColorAndItemsDesignatedInitializerCopiesItems() {
        for (index, item) in list.items.enumerated() {
            XCTAssertFalse(items[index] === item, "ListItems should be copied in List's init().")
        }
    }
    
    // MARK: NSCopying
    
    func testCopyingLists() {
        let listCopy = list.copy() as? List

        XCTAssertNotNil(listCopy)
        
        if listCopy != nil {
            XCTAssertEqual(list, listCopy!)
        }
    }
    
    // MARK: NSCoding

    func testEncodingLists() {
        let archivedListData = NSKeyedArchiver.archivedData(withRootObject: list)

        XCTAssertTrue(archivedListData.count > 0)
    }
    
    func testDecodingLists() {
        let archivedListData = NSKeyedArchiver.archivedData(withRootObject: list)
        
        let unarchivedList = NSKeyedUnarchiver.unarchiveObject(with: archivedListData) as? List

        XCTAssertNotNil(unarchivedList)

        if list != nil {
            XCTAssertEqual(list, unarchivedList!)
        }
    }

    // MARK: Equality
    
    func testIsEqual() {
        let listOne = List(color: .gray, items: items)
        let listTwo = List(color: .gray, items: items)
        let listThree = List(color: .green, items: items)
        let listFour = List(color: .gray, items: [])

        XCTAssertEqual(listOne, listTwo)
        XCTAssertNotEqual(listTwo, listThree)
        XCTAssertNotEqual(listTwo, listFour)
    }

    // MARK: Archive Compatibility
    
    /**
        Ensure that the runtime name of the `List` class is "ListerKit.List". This is to ensure compatibility
        with earlier versions of the app.
    */
    func testClassRuntimeNameForArchiveCompatibility() {
        let classRuntimeName = NSStringFromClass(List.self)

        XCTAssertNotNil(classRuntimeName, "The List class should be an @objc subclass.")

        XCTAssertEqual(classRuntimeName, "AAPLList", "List should be archivable with earlier versions of Lister.")
    }
}
