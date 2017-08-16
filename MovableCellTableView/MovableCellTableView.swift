//
//  MovableTableView.swift
//  Moo
//
//  Created by 张俊安 on 2017/8/13.
//  Copyright © 2017年 cppteam. All rights reserved.
//

import UIKit


@objc protocol MovableCellTableViewDataSource: NSObjectProtocol {
    
    /// 将原始数据源传入
    func originalDataSource(for tableView: MovableCellTableView) -> Any
}

@objc protocol MovableCellTableViewDelegate: NSObjectProtocol {
    
    /// 将重新排列的数据源传出`并赋值给原数据源`
    func newDataSource(for tableView: MovableCellTableView, new dataSource: Any)
    
    /// 长按选中cell准备好开始移动
    @objc optional func movableCellBeganMoving(at indexPath: IndexPath, in tableView: MovableCellTableView)

    /// 长按选中cell正在移动
    @objc optional func movableCellIsMoving(in tableView: MovableCellTableView)
    
    /// 长按选中cell完成移动
    @objc optional func movableCelldidEndMoving(in tableView: MovableCellTableView)
}

final class MovableCellTableView: UITableView {
    
    
    // MARK:- Constants
    
    struct Metric {
        /// cell贴磁动画归位时长
        static let magnetDuration = 0.4
        /// 开启滚动触发范围, 与屏幕边缘的距离
        static let edgeScrollDistance: CGFloat = 40.0
        /// 自动滚动的最大速度
        static let maxPixelSpeed: CGFloat = 10.0
    }
    
    // MARK:- Protocol interface

    weak var movableDataSource: MovableCellTableViewDataSource?
    weak var movableDelegate: MovableCellTableViewDelegate?
    
    // MARK:- Properties
    
    /// 判断移动的cell位于屏幕上边缘还是下边缘
    fileprivate enum AutoScrollDirection {
        case top
        case bottom
    }
    
    /// 长按选中的cell截图
    fileprivate lazy var snapshotView = UIView()
    
    /// 长按选中的cell的原始indexPath
    fileprivate var originalIndexPath: IndexPath?
    
    /// 长按选中的cell移动时的新indexPath
    fileprivate var relocatedIndexPath: IndexPath?
    
    /// 手指位置
    fileprivate var touchLocation: CGPoint?
    
    /// 长按选中的cell移动到屏幕边缘开启自动滚动tableView的计时器
    fileprivate var autoScrollTimer: CADisplayLink?
    
    /// 长按选中的cell移动到屏幕边缘的方向
    fileprivate var autoScrollDirection: AutoScrollDirection?
    

    // MARK:- Initialzing
    
    override init(frame: CGRect, style: UITableViewStyle) {
        super.init(frame: frame, style: style)
        
        allowsSelection = false
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(MovableCellTableView.longPress(recognizer:)))
        addGestureRecognizer(longPressGesture)

    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK:- Deinit
    
    deinit {
        movableDataSource = nil
        movableDelegate = nil
    }
    
    
}


extension MovableCellTableView {
    
    @objc func longPress(recognizer: UILongPressGestureRecognizer) {
        
        touchLocation = recognizer.location(in: self)
        guard let touchLocation = touchLocation else { return }
        
        let state = recognizer.state
        switch state {
        case .began:
            if let originalIndexPath = indexPathForRow(at: touchLocation) {
                self.originalIndexPath = originalIndexPath
                selectedCell(at: originalIndexPath)
                
                if let moveDelegate = movableDelegate {
                    if moveDelegate.responds(to: #selector(MovableCellTableViewDelegate.movableCellBeganMoving(at:in:))) {
                        moveDelegate.movableCellBeganMoving!(at: originalIndexPath, in: self)
                    }
                }
            }
            
        case .changed:
            snapshotView.center.y = touchLocation.y
            
            judgeCellIfMeetingScreenEdge() == true ? startAutoScrollTimer() : stopAutoScrollTimer()
            
            guard let relocatedIndexPath = indexPathForRow(at: touchLocation) else { return }
            if relocatedIndexPath != originalIndexPath {
                self.relocatedIndexPath = relocatedIndexPath
                movableCellRelocated(to: relocatedIndexPath)
            }
            
            if let moveDelegate = movableDelegate {
                if moveDelegate.responds(to: #selector(MovableCellTableViewDelegate.movableCellIsMoving(in:))) {
                    moveDelegate.movableCellIsMoving!(in: self)
                }
            }
        
        default:
            stopAutoScrollTimer()
            movableCellDidEndDraging()
            if let moveDelegate = movableDelegate {
                if moveDelegate.responds(to: #selector(MovableCellTableViewDelegate.movableCelldidEndMoving(in:))) {
                    moveDelegate.movableCelldidEndMoving!(in: self)
                }
            }
            
            
        }
        
    }
}


extension MovableCellTableView {
    /// 长按选中的cell先生成截图, 再去隐藏原cell
    fileprivate func selectedCell(at indexPath: IndexPath) {
        let cell = cellForRow(at: indexPath)!
        
        let snapshotView = cell.snapshot()
        self.snapshotView = snapshotView
        addSubview(snapshotView)
        cell.isHidden = true
        
        var center = snapshotView.center
        center.y = touchLocation!.y
        
        UIView.animate(withDuration: 0.2) { 
            snapshotView.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
            snapshotView.alpha = 0.98
            snapshotView.center = center
        }
        
        
    }
}

extension MovableCellTableView {
    
    /// 判断移动的cell是否接触到屏幕上下边缘
    ///
    /// - Returns: 是否接触
    fileprivate func judgeCellIfMeetingScreenEdge() -> Bool {
        let maxY = snapshotView.frame.maxY
        let minY = snapshotView.frame.minY
        
        if minY < contentOffset.y + Metric.edgeScrollDistance {
            autoScrollDirection = .top
            return true
        }
        
        if maxY > bounds.height + contentOffset.y - Metric.edgeScrollDistance {
            autoScrollDirection = .bottom
            return true
        }
        
        return false
    }
}

extension MovableCellTableView {
    
    fileprivate func movableCellRelocated(to newIndexPath: IndexPath) {
        updateDataSource()
        guard let originalIndexPath = originalIndexPath else { return }
        moveRow(at: originalIndexPath, to: newIndexPath)
        self.originalIndexPath = newIndexPath
    }
    
    fileprivate func updateDataSource() {
        var tempArr = [Array<Any>]()

        guard let movableDataSource = movableDataSource,
              let movableDelegate = movableDelegate,
              let originalIndexPath = originalIndexPath,
              let relocatedIndexPath = relocatedIndexPath
            else { return }
        
        if movableDataSource.responds(to: #selector(MovableCellTableViewDataSource.originalDataSource(for:))) {
            let type = movableDataSource.originalDataSource(for: self)
            if ((type as? [Array<Any>]) != nil) { // type: [[]]
                tempArr = movableDataSource.originalDataSource(for: self) as! [Array<Any>]
            } else { // type: []
                tempArr = [movableDataSource.originalDataSource(for: self) as! Array<Any>]
            }
        
        } else { return }
        
        if tempArr.count > 1 { // 多个section
            
            if originalIndexPath.section == relocatedIndexPath.section { // 同section
                moveElement(in: &tempArr[originalIndexPath.section], from: originalIndexPath.row, to: relocatedIndexPath.row)
            } else { // 不同section
                let origin = tempArr[originalIndexPath.section][originalIndexPath.item]
                tempArr[relocatedIndexPath.section].insert(origin, at: relocatedIndexPath.item)
                tempArr[originalIndexPath.section].remove(at: originalIndexPath.item)
                
            }
            
        } else { // 单个section
            moveElement(in: &tempArr[0], from: originalIndexPath.row, to: relocatedIndexPath.row)
        }
        
        // 将重新排列的数组传出
        if movableDelegate.responds(to: #selector(MovableCellTableViewDelegate.newDataSource(for:new:))) {
            let type = movableDataSource.originalDataSource(for: self)
            if ((type as? [Array<Any>]) != nil) { // type: [[]]
                movableDelegate.newDataSource(for: self, new: tempArr)
            } else { // type: []
                movableDelegate.newDataSource(for: self, new: tempArr[0])
            }
        }
        
    }
    
    
}


extension MovableCellTableView {
    fileprivate func moveElement(in array: inout [Any],from: Int, to: Int) {
        if from <= to {
            for i in from..<to {
                swap(&array[i], &array[i+1])
            }
            
        } else {
            for i in ((to + 1)...from).reversed() {
                swap(&array[i], &array[i-1])
            }
            
        }
    }
}

extension MovableCellTableView {
    
    fileprivate func movableCellDidEndDraging() {
        guard let originalIndexPath = originalIndexPath else { return }
        guard let cell = cellForRow(at: originalIndexPath) else { return }
        cell.isHidden = false
        cell.alpha = 0
        UIView.animate(withDuration: Metric.magnetDuration, animations: {
            self.snapshotView.center = cell.center
            self.snapshotView.alpha = 0
            self.snapshotView.transform = CGAffineTransform.identity
            cell.alpha = 1
        }) { (_) in
            cell.isHidden = false
            self.snapshotView.removeFromSuperview()
            self.originalIndexPath = nil
            self.relocatedIndexPath = nil
        }
    }
}



extension MovableCellTableView {
    fileprivate func startAutoScrollTimer() {
        if (autoScrollTimer == nil) {
            autoScrollTimer = CADisplayLink(target: self, selector: #selector(MovableCellTableView.startAutoScoll))
            autoScrollTimer!.add(to: RunLoop.main, forMode: .commonModes)
        }
    }
    
    fileprivate func stopAutoScrollTimer() {
        if (autoScrollTimer != nil) {
            autoScrollTimer?.invalidate()
            autoScrollTimer = nil
        }
    }
    
    @objc fileprivate func startAutoScoll() {
        let maxY = snapshotView.frame.maxY
        let minY = snapshotView.frame.minY

        var maxSpeed: CGFloat = Metric.maxPixelSpeed
        
        if autoScrollDirection == .top {
            if contentOffset.y > 0 {
                
                if contentOffset.y  <= minY {
                    maxSpeed = maxSpeed * (contentOffset.y + Metric.edgeScrollDistance - minY) / Metric.edgeScrollDistance
                }
                
                setContentOffset(CGPoint.init(x: 0, y: contentOffset.y - maxSpeed), animated: false)
                snapshotView.center = CGPoint.init(x: snapshotView.center.x, y: snapshotView.center.y - maxSpeed)
            }
            
        }
        else if autoScrollDirection == .bottom {
            if contentOffset.y + bounds.height < contentSize.height {
                
                if ((bounds.height + contentOffset.y - maxY)/Metric.edgeScrollDistance) >= 0 {
                    maxSpeed = maxSpeed * (1 - (bounds.height + contentOffset.y - maxY)/Metric.edgeScrollDistance)
                }
                
                setContentOffset(CGPoint.init(x: 0, y: contentOffset.y + maxSpeed), animated: false)
                snapshotView.center = CGPoint(x: snapshotView.center.x, y: snapshotView.center.y + maxSpeed)
            }
            
        }
        
        relocatedIndexPath = indexPathForRow(at: snapshotView.center)
        guard let relocated = relocatedIndexPath, let original = originalIndexPath else { return }
        if relocated != original {
            movableCellRelocated(to: relocated)
        }

    }
}


extension UIView {
    
    /** 返回view的截图 */
    func snapshot() -> UIImageView {
        
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0.0)
        layer.render(in: UIGraphicsGetCurrentContext()!)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        let snapshot = UIImageView.init(image: image)
        snapshot.center = self.center
        snapshot.layer.shadowOffset = CGSize(width: -5.0, height: 0)
        snapshot.layer.cornerRadius = 0.0
        snapshot.layer.masksToBounds = false
        snapshot.layer.shadowRadius = 5.0
        snapshot.layer.shadowOpacity = 0.5
        
        return snapshot
    }
}





