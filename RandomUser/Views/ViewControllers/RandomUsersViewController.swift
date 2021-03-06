//
//  RandomUsersViewController.swift
//  RandomUser
//
//  Created by Kálai Kristóf on 2020. 05. 12..
//  Copyright © 2020. Kálai Kristóf. All rights reserved.
//

import UIKit
import Lottie

// MARK: - The main View base part.
class RandomUsersViewController: UIViewController {
    
    /// MVP architecture element.
    var randomUsersPresenter: RandomUserPresenterProtocol = RandomUsersPresenter()
    
    @IBOutlet weak var tableView: UITableView!
    
    private let refreshControl = UIRefreshControl()
    
    /// Shows weather the initial users' data downloaded (or retrieved from cache).
    private var animationView = AnimationView(name: "loading")
    
    /// After the user claims that wants to refresh, the cells dissolves with this delay.
    /// After that the Presenter can start the refresh.
    private let refreshDelay = 0.33
    private var selectedRow: Int? = nil
    private let detailsSegue = "showDetailsSegue"
}

// MARK: - UIViewController lifecycle (and all that related to it) part.
extension RandomUsersViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        randomUsersPresenter.inject(self)
        
        setupBackButtonOnNextVC()
        setupLeftBarButton()
        
        animationView.configure(on: view)
        setupTableViewAndRefreshing()
        
        randomUsersPresenter.getCachedUsers()
        
        navigationController?.hero.isEnabled = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        tableView.visibleCells.forEach { cell in
            if let cell = cell as? RandomUserTableViewCell {
                cell.userImage.hero.id = HeroIDs.defaultValue.rawValue
                cell.userName.hero.id = HeroIDs.defaultValue.rawValue
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        /// If the segue is the `detailsSegue`, then store the selected user in the destintion ViewController.
        if segue.identifier == detailsSegue,
            let selectedRow = selectedRow,
            let destinationViewController = segue.destination as? UserDetailsViewController {
            destinationViewController.user = randomUsersPresenter.users[selectedRow]
        }
    }
}

// MARK: - UITableView functions part.
extension RandomUsersViewController: UITableViewDelegate, UITableViewDataSource {
    
    /// If currently refreshing or downloads the initial users, show `0` cells. Otherwise show the `currentMaxUsers`.
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        refreshUserCounter()
        if animationView.isAnimationPlaying || refreshControl.isRefreshing {
            return 0
        } else {
            return randomUsersPresenter.currentMaxUsers
        }
    }
    
    /// If the cell is ready to be displayed, then display it, otherwise show a loading animation (with hidden content).
    /// - SeeAlso:
    /// `RandomUsersPresenter`'s `currentMaxUsers` variable.
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: RandomUserTableViewCell = tableView.cell(indexPath: indexPath)
        cell.initialize()
        if indexPath.row < randomUsersPresenter.users.count {
            cell.showContent()
            cell.configureData(withUser: randomUsersPresenter.users[indexPath.row])
        } else {
            cell.hideContent()
            randomUsersPresenter.getMoreRandomUsers()
        }
        return cell
    }
    
    /// After the initial download (while the `animationView` is animating), refresh the data.
    @objc func tableViewPullToRefresh() {
        if !animationView.isAnimationPlaying {
            randomUsersPresenter.refresh(withDelay: refreshDelay)
        } else {
            refreshControl.endRefreshing()
        }
    }
    
    /// If possible, go to the first cell.
    @objc func tableViewGoToTop() {
        if tableView.numberOfRows(inSection: 0) > 0 {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        }
    }
    
    /// After a cell get selected, perform a segue and deselect the cell.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedRow = indexPath.row
        let cell: RandomUserTableViewCell = tableView.cell(at: indexPath)
        cell.userImage.heroID = HeroIDs.imageEnlarging.rawValue
        cell.userName.heroID = HeroIDs.textEnlarging.rawValue
        performSegue(withIdentifier: detailsSegue, sender: self)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Additional UI-related functions, methods.
extension RandomUsersViewController {
    
    /// Get called only once, setup the delegates, `UIRefreshControl`, etc.
    private func setupBackButtonOnNextVC() {
        navigationItem.backBarButtonItem = UIBarButtonItem.create()
    }
    
    /// In the top left corner write out "Top", and when the user clicks on it, the `UITableView` must go to the top.
    private func setupLeftBarButton() {
        navigationItem.leftBarButtonItem = UIBarButtonItem
            .create(title: "Top", target: self, action: #selector(tableViewGoToTop))
    }
    
    /// In the top right corner write out the number of the currently downloaded distinct named users.
    private func refreshUserCounter() {
        let title = "Users: \(randomUsersPresenter.numberOfDistinctNamedPeople)"
        navigationItem.rightBarButtonItem = UIBarButtonItem
            .create(title: title, isEnabled: false)
    }
    
    /// Get called only once, setup the delegates, `UIRefreshControl`, etc.
    private func setupTableViewAndRefreshing() {
        tableView.delegate = self
        tableView.dataSource = self
        refreshControl.tintColor = .white
        refreshControl.addTarget(self, action: #selector(tableViewPullToRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    private func stopAnimating(completion: @escaping () -> () = { }) {
        refreshControl.endRefreshing()
        animationView.hide(1.0) { [weak self] in
            guard let self = self else { return }
            self.animationView.stop()
            completion()
        }
    }
}

// MARK: - RandomUserProtocol (reaction to the Presenter) part.
extension RandomUsersViewController: RandomUserViewProtocol {
    
    /// After successfully filled the array of the data, stop the animation and animate the `UITableView`.
    func didRandomUsersAvailable(_ completion: @escaping () -> Void) {
        stopAnimating { [weak self] in
            guard let self = self else { return }
            self.tableView.animateUITableView {
                completion()
            }
        }
    }
    
    /// After started the refresh, hide the cells.
    func willRandomUsersRefresh() {
        UIView.transition(with: tableView, duration: refreshDelay, options: .transitionCrossDissolve, animations: { [weak self] in
            guard let self = self else { return }
            self.tableView.reloadData()
        })
    }
    
    /// After an error occured, show it to the user.
    func didErrorOccuredWhileDownload(errorMessage: String) {
        stopAnimating()
        
        let alert = UIAlertController(title: "Error", message: errorMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    /// After the paging done, show the new cells (reload the data).
    func didEndRandomUsersPaging() {
        tableView.reloadData()
    }
}
