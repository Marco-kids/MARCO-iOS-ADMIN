//
//  EditorViewController.swift
//  ARPersistencySwiftUI
//
//  Created by Jose Castillo on 2/16/23.
//

import UIKit

protocol EditorViewControllerDelegate: AnyObject {
    func loadedData(locations: [ARLocation])
}

class EditorViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, EditorViewControllerDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    var locations: [ARLocation] = []
    let network = Network.shared
    let refreshControl = UIRefreshControl()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        network.delegateARVC = self
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        tableView.addSubview(refreshControl)
    }
    
    // MARK: TableView delegate methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return locations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: EditorTableViewCell = tableView.dequeueReusableCell(withIdentifier: "cell") as! EditorTableViewCell
        cell.location = self.locations[indexPath.row]
        cell.setCell()
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "loadSegue", sender: indexPath)
    }
    
    @objc func refresh(_ sender: AnyObject) {
        network.getLocations()
    }
    
    // MARK: UIButtons
    
    @IBAction func didTapAdd(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "addSegue", sender: nil)
    }
    
    // MARK: Protocol Methods
    
    func loadedData(locations: [ARLocation]) {
        refreshControl.endRefreshing()
        self.locations = locations
        self.tableView.reloadData()
    }
    
    // MARK: Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        #if !targetEnvironment(simulator)
        if segue.identifier == "loadSegue"{
            let destination = segue.destination as! ARViewController
            let indexPath = sender as! IndexPath
            destination.location = self.locations[indexPath.row]
        }
        #endif
    }

}
