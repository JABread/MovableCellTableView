//
//  ViewController.swift
//  MovableCellTableView
//
//  Created by 张俊安 on 2017/8/14.
//  Copyright © 2017年 cppteam. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    lazy var tableView: MovableCellTableView = {
        let tableView = MovableCellTableView()
        tableView.movableDelegate = self
        tableView.movableDataSource = self
        tableView.dataSource = self
        tableView.delegate = self
        return tableView
    }()
    
    var data = [Array<String>]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for i in 0..<8 {
            var section = Array<String>()
            for j in 0..<4 {
                section.append("\(i) -- \(j)")
            }
            data.append(section)
        }
        
        tableView.frame = view.bounds
        view.addSubview(tableView)
    }

}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        cell.textLabel?.text = data[indexPath.section][indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

extension ViewController: MovableCellTableViewDataSource, MovableCellTableViewDelegate {
    
    func originalDataSource(for tableView: MovableCellTableView) -> Any {
        return data
    }
    
    func newDataSource(for tableView: MovableCellTableView, new dataSource: Any) {
        print(dataSource)
        data = dataSource as! [Array<String>]
        
    }
    
    func movableCellBeganMoving(at indexPath: IndexPath, in tableView: MovableCellTableView) {
//        print("movableCellBeganMoving at \(indexPath.section) - \(indexPath.row)")
    }
    
    func movableCellIsMoving(in tableView: MovableCellTableView) {
//        print("movableCellIsMoving")
    }
    
    func movableCelldidEndMoving(in tableView: MovableCellTableView) {
//        print("movableCelldidEndMoving")
    }
    
}




