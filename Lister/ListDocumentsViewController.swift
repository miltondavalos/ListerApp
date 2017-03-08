/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    The `ListDocumentsViewController` displays a list of available documents for users to open.
*/

import UIKit
import WatchConnectivity
import ListerKit

class ListDocumentsViewController: UITableViewController, ListsControllerDelegate, UIDocumentMenuDelegate, UIDocumentPickerDelegate, WCSessionDelegate, SegueHandlerType {
    // MARK: Types

    struct MainStoryboard {
        struct ViewControllerIdentifiers {
            static let listViewController = "listViewController"
            static let listViewNavigationController = "listViewNavigationController"
        }
        
        struct TableViewCellIdentifiers {
            static let listDocumentCell = "listDocumentCell"
        }
    }
    
    // MARK: SegueHandlerType
    
    enum SegueIdentifier: String {
        case ShowNewListDocument
        case ShowListDocument
        case ShowListDocumentFromUserActivity
    }
    
    // MARK: Properties

    var listsController: ListsController! {
        didSet {
            listsController.delegate = self
        }
    }
    
    fileprivate var pendingLaunchContext: AppLaunchContext?
    
    fileprivate var watchAppInstalledAtLastStateChange = false
    
    // MARK: Initializers
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        if WCSession.isSupported() {
            WCSession.default().delegate = self
            WCSession.default().activate()
        }
    }

    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = 44.0
        
        navigationController?.navigationBar.titleTextAttributes = [
            NSFontAttributeName: UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline),
            NSForegroundColorAttributeName: List.Color.gray.colorValue
        ]
        
        NotificationCenter.default.addObserver(self, selector: #selector(ListDocumentsViewController.handleContentSizeCategoryDidChangeNotification(_:)), name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.navigationBar.titleTextAttributes = [
            NSFontAttributeName: UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline),
            NSForegroundColorAttributeName: List.Color.gray.colorValue
        ]
        
        let grayListColor = List.Color.gray.colorValue
        navigationController?.navigationBar.tintColor = grayListColor
        navigationController?.toolbar?.tintColor = grayListColor
        tableView.tintColor = grayListColor
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let launchContext = pendingLaunchContext {
            configureViewControllerWithLaunchContext(launchContext)
        }
        
        pendingLaunchContext = nil
    }
    
    // MARK: Lifetime
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIContentSizeCategoryDidChange, object: nil)
    }
    
    // MARK: UIResponder
    
    override func restoreUserActivityState(_ activity: NSUserActivity) {
        // Obtain an app launch context from the provided activity and configure the view controller with it.
        guard let launchContext = AppLaunchContext(userActivity: activity, listsController: listsController) else { return }
        
        configureViewControllerWithLaunchContext(launchContext)
    }
    
    // MARK: IBActions

    /**
        Note that the document picker requires that code signing, entitlements, and provisioning for
        the project have been configured before you run Lister. If you run the app without configuring
        entitlements correctly, an exception when this method is invoked (i.e. when the "+" button is
        clicked).
    */
    @IBAction func pickDocument(_ barButtonItem: UIBarButtonItem) {
        let documentMenu = UIDocumentMenuViewController(documentTypes: [AppConfiguration.listerUTI], in: .open)
        documentMenu.delegate = self

        let newDocumentTitle = NSLocalizedString("New List", comment: "")
        documentMenu.addOption(withTitle: newDocumentTitle, image: nil, order: .first) {
            // Show the `NewListDocumentController`.
            self.performSegueWithIdentifier(.ShowNewListDocument, sender: self)
        }
        
        documentMenu.modalPresentationStyle = .popover
        documentMenu.popoverPresentationController?.barButtonItem = barButtonItem
        
        present(documentMenu, animated: true, completion: nil)
    }
    
    // MARK: UIDocumentMenuDelegate
    
    func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self

        present(documentPicker, animated: true, completion: nil)
    }
    
    func documentMenuWasCancelled(_ documentMenu: UIDocumentMenuViewController) {
        /**
            The user cancelled interacting with the document menu. In your own app, you may want to
            handle this with other logic.
        */
    }
    
    // MARK: UIPickerViewDelegate
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        // The user selected the document and it should be picked up by the `ListsController`.
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        /**
            The user cancelled interacting with the document picker. In your own app, you may want to
            handle this with other logic.
        */
    }
    
    // MARK: ListsControllerDelegate
    
    func listsControllerWillChangeContent(_ listsController: ListsController) {
        tableView.beginUpdates()
    }
    
    func listsController(_ listsController: ListsController, didInsertListInfo listInfo: ListInfo, atIndex index: Int) {
        let indexPath = IndexPath(row: index, section: 0)
        
        tableView.insertRows(at: [indexPath], with: .automatic)
    }
    
    func listsController(_ listsController: ListsController, didRemoveListInfo listInfo: ListInfo, atIndex index: Int) {
        let indexPath = IndexPath(row: index, section: 0)
        
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
    
    func listsController(_ listsController: ListsController, didUpdateListInfo listInfo: ListInfo, atIndex index: Int) {
        let indexPath = IndexPath(row: index, section: 0)
        
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    func listsControllerDidChangeContent(_ listsController: ListsController) {
        tableView.endUpdates()
        
        // This method will handle interactions with the watch connectivity session on behalf of the app.
        updateWatchConnectivitySessionApplicationContext()
    }
    
    func listsController(_ listsController: ListsController, didFailCreatingListInfo listInfo: ListInfo, withError error: NSError) {
        let title = NSLocalizedString("Failed to Create List", comment: "")
        let message = error.localizedDescription
        let okActionTitle = NSLocalizedString("OK", comment: "")
        
        let errorOutController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let action = UIAlertAction(title: okActionTitle, style: .cancel, handler: nil)
        errorOutController.addAction(action)
        
        present(errorOutController, animated: true, completion: nil)
    }
    
    func listsController(_ listsController: ListsController, didFailRemovingListInfo listInfo: ListInfo, withError error: NSError) {
        let title = NSLocalizedString("Failed to Delete List", comment: "")
        let message = error.localizedFailureReason
        let okActionTitle = NSLocalizedString("OK", comment: "")
        
        let errorOutController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let action = UIAlertAction(title: okActionTitle, style: .cancel, handler: nil)
        errorOutController.addAction(action)
        
        present(errorOutController, animated: true, completion: nil)
    }
    
    // MARK: UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // If the controller is nil, return no rows. Otherwise return the number of total rows.
        return listsController?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: MainStoryboard.TableViewCellIdentifiers.listDocumentCell, for: indexPath) as! ListCell
    }
    
    // MARK: UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        switch cell {
            case let listCell as ListCell:
                let listInfo = listsController[indexPath.row]
                
                listCell.label.text = listInfo.name
                listCell.label.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
                listCell.listColorView.backgroundColor = UIColor.clear
                
                // Once the list info has been loaded, update the associated cell's properties.
                listInfo.fetchInfoWithCompletionHandler {
                    /*
                        The fetchInfoWithCompletionHandler(_:) method calls its completion handler on a background
                        queue, dispatch back to the main queue to make UI updates.
                    */
                    DispatchQueue.main.async {
                        // Make sure that the list info is still visible once the color has been fetched.
                        guard let indexPathsForVisibleRows = self.tableView.indexPathsForVisibleRows else { return }
                        
                        if indexPathsForVisibleRows.contains(indexPath) {
                            listCell.listColorView.backgroundColor = listInfo.color!.colorValue
                        }
                    }
                }
            default:
                fatalError("Attempting to configure an unknown or unsupported cell type in ListDocumentViewController.")
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    // MARK: WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("session activation failed with error: \(error.localizedDescription)")
            return
        }
        
        // Return early if `session` is not currently `.Activated`.
        guard activationState == .activated else { return }
        
        updateWatchConnectivitySessionApplicationContext()
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        /*
             The `sessionDidBecomeInactive(_:)` callback indicates sending has been disabled. If your iOS app
             sends content to its Watch extension it will need to stop trying at this point. This sample
             checks the session state before transmitting so no further action is required.
         */
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        /*
             The `sessionDidDeactivate(_:)` callback indicates `WCSession` is finished delivering content to
             the iOS app. iOS apps that process content delivered from their Watch Extension should finish
             processing that content and call `activateSession()`. This sample immediately calls
             `activateSession()` as the data provided by the Watch Extension is handled immediately.
         */
        WCSession.default().activate()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        // Return early if `session` is not currently `.Activated`.
        guard session.activationState == .activated else { return }
        
        if !watchAppInstalledAtLastStateChange && session.isWatchAppInstalled {
            watchAppInstalledAtLastStateChange = session.isWatchAppInstalled
            updateWatchConnectivitySessionApplicationContext()
        }
    }
    
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error = error {
            print("\(#function), file: \(fileTransfer.file.fileURL), error: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
//        guard let lastPathComponent = file.fileURL!.lastPathComponent else { return }
        listsController.copyListFromURL(file.fileURL!, toListWithName:(file.fileURL!.lastPathComponent as NSString).deletingPathExtension)
    }
    
    // MARK: UIStoryboardSegue Handling

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let segueIdentifier = segueIdentifierForSegue(segue)
        
        switch segueIdentifier {
            case .ShowNewListDocument:
                let newListDocumentController = segue.destination as! NewListDocumentController
                
                newListDocumentController.listsController = listsController

            case .ShowListDocument, .ShowListDocumentFromUserActivity:
                let listNavigationController = segue.destination as! UINavigationController
                let listViewController = listNavigationController.topViewController as! ListViewController
                listViewController.listsController = listsController
                
                listViewController.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                listViewController.navigationItem.leftItemsSupplementBackButton = true
            
                if segueIdentifier == .ShowListDocument {
                    let indexPath = tableView.indexPathForSelectedRow!
                    listViewController.configureWithListInfo(listsController[indexPath.row])
                }
                else {
                    let userActivityListInfo = sender as! ListInfo
                    listViewController.configureWithListInfo(userActivityListInfo)
                }
        }
    }

    // MARK: Notifications
    
    func handleContentSizeCategoryDidChangeNotification(_: Notification) {
        tableView.setNeedsLayout()
    }
    
    // MARK: Convenience
    
    func configureViewControllerWithLaunchContext(_ launchContext: AppLaunchContext) {
        /**
            If there is a list currently displayed; pop to the root view controller (this controller) and
            continue configuration from there. Otherwise, configure the view controller directly.
        */
        if navigationController?.topViewController is UINavigationController {
            DispatchQueue.main.async {
                // Ensure that any UI updates occur on the main queue.
                self.navigationController?.popToRootViewController(animated: false)
                self.pendingLaunchContext = launchContext
            }
            return
        }
        
        let listInfo = ListInfo(URL: launchContext.listURL)
        listInfo.color = launchContext.listColor
        
        DispatchQueue.main.async {
            self.performSegueWithIdentifier(.ShowListDocumentFromUserActivity, sender: listInfo)
        }
    }
    
    func updateWatchConnectivitySessionApplicationContext() {
        // Return if `WCSession` is not supported on this iOS device or the `listsController` is unavailable.
        guard let listsController = listsController, WCSession.isSupported() else { return }
        
        let session = WCSession.default()
        
        // Do not proceed if `session` is not currently `.Activated`.
        guard session.activationState == .activated else { return }
        
        // Do not proceed if the watch app is not installed on the paired watch.
        guard session.isWatchAppInstalled else { return }
        
        // This array will be used to collect the data about the lists for the application context.
        var lists = [[String: AnyObject]]()
        // A background queue to execute operations on to fetch the information about the lists.
        let queue = OperationQueue()
        
        // This operation will execute last and will actually update the application context.
        let updateApplicationContextOperation = BlockOperation {
            do {
                // Do not proceed if `session` is not currently `.Activated`.
                guard session.activationState == .activated else { return }
                
                try session.updateApplicationContext([AppConfiguration.ApplicationActivityContext.currentListsKey: lists])
            }
            catch let error as NSError {
                print("Error updating watch application context: \(error.localizedDescription)")
            }
            // Requiring an additional catch to satisfy exhaustivity is a known issue.
            catch {}
        }
        
        // Loop through the available lists in order to accumulate contextual information about them.
        for idx in 0..<listsController.count {
            // Obtain the list info object from the controller.
            let info = listsController[idx]
            
            // This operation will fetch the information for an individual list.
            let listInfoOperation = BlockOperation {
                // The `fetchInfoWithCompletionHandler(_:)` method executes asynchronously. Use a semaphore to wait.
                let semaphore = DispatchSemaphore(value: 0)
                info.fetchInfoWithCompletionHandler {
                    // Now that the `info` object is fully populated. Add an entry to the `lists` dictionary.
                    lists.append([
                        AppConfiguration.ApplicationActivityContext.listNameKey: info.name as NSString,
                        AppConfiguration.ApplicationActivityContext.listColorKey: NSNumber(value:info.color!.rawValue)
                    ])
                
                    // Signal the semaphore indicating that it can stop waiting.
                    semaphore.signal()
                }
            
                // Wait on the semaphore to ensure the operation doesn't return until the fetch is complete.
                semaphore.wait(timeout: DispatchTime.distantFuture)
            }
            
            // Depending on `listInfoOperation` ensures it completes before `updateApplicationContextOperation` executes.
            updateApplicationContextOperation.addDependency(listInfoOperation)
            queue.addOperation(listInfoOperation)
            
            // Use file coordination to obtain exclusive access to read the file in order to initiate a transfer.
            let fileCoordinator = NSFileCoordinator()
            let readingIntent = NSFileAccessIntent.readingIntent(with: info.URL, options: [])
            fileCoordinator.coordinate(with: [readingIntent], queue: OperationQueue()) { accessError in
                if accessError != nil {
                    return
                }
                
                // Do not proceed if `session` is not currently `.Activated`.
                guard session.activationState == .activated else { return }
                
                // Iterate through outstanding transfers; and cancel any for the same URL as they are obsolete.
                for transfer in session.outstandingFileTransfers {
                    if transfer.file.fileURL == readingIntent.url {
                        transfer.cancel()
                        break
                    }
                }
                
                // Initiate the new transfer.
                session.transferFile(readingIntent.url, metadata: nil)
            }
        }
        
        queue.addOperation(updateApplicationContextOperation)
    }
}
