//
//  JXPhotoBrowserImageCell.swift
//  JXPhotoBrowser
//
//  Created by JiongXing on 2019/11/12.
//  Copyright © 2019 JiongXing. All rights reserved.
//

import UIKit

open class JXPhotoBrowserImageCell: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate, JXPhotoBrowserCell, JXPhotoBrowserZoomSupportedCell {
    
    /// 弱引用PhotoBrowser
    open weak var photoBrowser: JXPhotoBrowser?
    
    open var index: Int = 0
    
    open var scrollDirection: JXPhotoBrowser.ScrollDirection = .horizontal {
        didSet {
            if scrollDirection == .horizontal {
                addPanGesture()
            } else if let existed = existedPan {
                scrollView.removeGestureRecognizer(existed)
            }
        }
    }
    
    open lazy var imageView: JXPhotoBrowserImageView = {
        let imgView = JXPhotoBrowserImageView()
        imgView.clipsToBounds = true
        imgView.imageDidChangedHandler = { [weak self] in
            self?.setNeedsLayout()
        }
        return imgView
    }()
    
    open var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.maximumZoomScale = 2.0
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        if #available(iOS 11.0, *) {
            view.contentInsetAdjustmentBehavior = .never
        }
        return view
    }()
    
    deinit {
        JXPhotoBrowserLog.low("deinit - \(self.classForCoder)")
    }
    
    public required override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    /// 生成实例
    public static func generate(with browser: JXPhotoBrowser) -> Self {
        let cell = Self.init(frame: .zero)
        cell.photoBrowser = browser
        cell.scrollDirection = browser.scrollDirection
        return cell
    }
    
    /// 子类可重写，创建子视图。完全自定义时不必调super。
    open func constructSubviews() {
        scrollView.delegate = self
        addSubview(scrollView)
        scrollView.addSubview(imageView)
    }
    
    open func setup() {
        backgroundColor = .clear
        constructSubviews()
        
        /// 拖动手势
        addPanGesture()
        
        // 双击手势
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(onDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        
        // 单击手势
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(onSingleTap(_:)))
        singleTap.require(toFail: doubleTap)
        addGestureRecognizer(singleTap)
    }
    
    // 长按事件
    public typealias LongPressAction = (JXPhotoBrowserImageCell, UILongPressGestureRecognizer) -> Void
    
    /// 长按时回调。赋值时自动添加手势，赋值为nil时移除手势
    open var longPressedAction: LongPressAction? {
        didSet {
            if oldValue != nil && longPressedAction == nil {
                removeGestureRecognizer(longPress)
            } else if oldValue == nil && longPressedAction != nil {
                addGestureRecognizer(longPress)
            }
        }
    }
    
    /// 已添加的长按手势
    private lazy var longPress: UILongPressGestureRecognizer = {
        return UILongPressGestureRecognizer(target: self, action: #selector(onLongPress(_:)))
    }()
    
    private weak var existedPan: UIPanGestureRecognizer?
    
    /// 添加拖动手势
    open func addPanGesture() {
        guard existedPan == nil else {
            return
        }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.delegate = self
        // 必须加在图片容器上，否则长图下拉不能触发
        scrollView.addGestureRecognizer(pan)
        existedPan = pan
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        scrollView.setZoomScale(1.0, animated: false)
        let size = computeImageLayoutSize(for: imageView.image, in: scrollView)
        let origin = computeImageLayoutOrigin(for: size, in: scrollView)
        imageView.frame = CGRect(origin: origin, size: size)
        scrollView.setZoomScale(1.0, animated: false)
    }
    
    open func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    open func scrollViewDidZoom(_ scrollView: UIScrollView) {
        imageView.center = computeImageLayoutCenter(in: scrollView)
    }
    
    open func computeImageLayoutSize(for image: UIImage?, in scrollView: UIScrollView) -> CGSize {
        guard let imageSize = image?.size, imageSize.width > 0 && imageSize.height > 0 else {
            return .zero
        }
        var width: CGFloat
        var height: CGFloat
        let containerSize = scrollView.bounds.size
        if scrollDirection == .horizontal {
            // 横竖屏判断
            if containerSize.width < containerSize.height {
                width = containerSize.width
                height = imageSize.height / imageSize.width * width
            } else {
                height = containerSize.height
                width = imageSize.width / imageSize.height * height
                if width > containerSize.width {
                    width = containerSize.width
                    height = imageSize.height / imageSize.width * width
                }
            }
        } else {
            width = containerSize.width
            height = imageSize.height / imageSize.width * width
            if height > containerSize.height {
                height = containerSize.height
                width = imageSize.width / imageSize.height * height
            }
        }
        
        return CGSize(width: width, height: height)
    }
    
    open func computeImageLayoutOrigin(for imageSize: CGSize, in scrollView: UIScrollView) -> CGPoint {
        let containerSize = scrollView.bounds.size
        var y = (containerSize.height - imageSize.height) * 0.5
        y = max(0, y)
        var x = (containerSize.width - imageSize.width) * 0.5
        x = max(0, x)
        return CGPoint(x: x, y: y)
    }
    
    open func computeImageLayoutCenter(in scrollView: UIScrollView) -> CGPoint {
        var x = scrollView.contentSize.width * 0.5
        var y = scrollView.contentSize.height * 0.5
        let offsetX = (bounds.width - scrollView.contentSize.width) * 0.5
        if offsetX > 0 {
            x += offsetX
        }
        let offsetY = (bounds.height - scrollView.contentSize.height) * 0.5
        if offsetY > 0 {
            y += offsetY
        }
        return CGPoint(x: x, y: y)
    }
    
    /// 单击
    @objc open func onSingleTap(_ tap: UITapGestureRecognizer) {
        photoBrowser?.dismiss()
    }
    
    /// 双击
    @objc open func onDoubleTap(_ tap: UITapGestureRecognizer) {
        // 如果当前没有任何缩放，则放大到目标比例，否则重置到原比例
        if scrollView.zoomScale < 1.1 {
            // 以点击的位置为中心，放大
            let pointInView = tap.location(in: imageView)
            let width = scrollView.bounds.size.width / scrollView.maximumZoomScale
            let height = scrollView.bounds.size.height / scrollView.maximumZoomScale
            let x = pointInView.x - (width / 2.0)
            let y = pointInView.y - (height / 2.0)
            scrollView.zoom(to: CGRect(x: x, y: y, width: width, height: height), animated: true)
        } else {
            scrollView.setZoomScale(1.0, animated: true)
        }
    }
    
    /// 长按
    @objc open func onLongPress(_ press: UILongPressGestureRecognizer) {
        if press.state == .began {
            longPressedAction?(self, press)
        }
    }
    
    /// 记录pan手势开始时imageView的位置
    private var beganFrame = CGRect.zero
    
    /// 记录pan手势开始时，手势位置
    private var beganTouch = CGPoint.zero
    
    /// 响应拖动
    @objc open func onPan(_ pan: UIPanGestureRecognizer) {
        guard imageView.image != nil, let browser = photoBrowser else { return }
        let total = browser.numberOfItems()
        let isSingle = total <= 1
        let velocity = pan.velocity(in: self)
        let translation = pan.translation(in: self)
        let absX = abs(velocity.x), absY = abs(velocity.y)
        let isHorizontal = absX > absY
        let isVertical = absY > absX
        let offsetX = scrollView.contentOffset.x
        let pageIndex = browser.pageIndex
        let itemCount = browser.numberOfItems()
        let atLeft = pageIndex == 0
        let atRight = pageIndex == itemCount - 1
        let offsetY = scrollView.contentOffset.y
        let maxOffsetY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let atTop = offsetY <= 0
        let atBottom = abs(offsetY - maxOffsetY) < 1e-2
        // 只允许主方向的边界滑动
        let allowDown = (isSingle || (isVertical && atTop && velocity.y > 0))
        let allowUp = (isSingle || (isVertical && atBottom && velocity.y < 0))
        let allowRight = (isSingle || (isHorizontal && atLeft && velocity.x > 0))
        let allowLeft = (isSingle || (isHorizontal && atRight && velocity.x < 0))
        guard allowDown || allowUp || allowRight || allowLeft else { return }
        switch pan.state {
        case .began:
            beganFrame = imageView.frame
            beganTouch = pan.location(in: scrollView)
        case .changed:
            let result = panResult(pan, isHorizontal: isHorizontal)
            imageView.frame = result.frame
            browser.maskView.alpha = result.scale * result.scale
            browser.pageIndicator?.isHidden = result.scale < 0.99
        case .ended, .cancelled:
            imageView.frame = panResult(pan, isHorizontal: isHorizontal).frame
            let isDown = isVertical && atTop && velocity.y > 0
            let isUp = isVertical && atBottom && velocity.y < 0
            let isRight = isHorizontal && atLeft && velocity.x > 0
            let isLeft = isHorizontal && atRight && velocity.x < 0
            if isDown || isUp || isRight || isLeft {
                browser.dismiss()
            } else {
                browser.maskView.alpha = 1.0
                browser.pageIndicator?.isHidden = false
                resetImageViewPosition()
            }
        default:
            resetImageViewPosition()
        }
    }
    
    /// 计算拖动时图片应调整的frame和scale值，横向/纵向缩放一致
    private func panResult(_ pan: UIPanGestureRecognizer, isHorizontal: Bool) -> (frame: CGRect, scale: CGFloat) {
        let translation = pan.translation(in: self)
        let mainDelta = isHorizontal ? translation.x : translation.y
        let scale = min(1.0, max(0.3, 1 - abs(mainDelta) / bounds.width))
        let width = beganFrame.size.width * scale
        let height = beganFrame.size.height * scale
        let xRate = (beganTouch.x - beganFrame.origin.x) / beganFrame.size.width
        let currentTouch = pan.location(in: scrollView)
        let currentTouchDeltaX = xRate * width
        let x = currentTouch.x - currentTouchDeltaX
        let yRate = (beganTouch.y - beganFrame.origin.y) / beganFrame.size.height
        let currentTouchDeltaY = yRate * height
        let y = currentTouch.y - currentTouchDeltaY
        return (CGRect(x: x.isNaN ? 0 : x, y: y.isNaN ? 0 : y, width: width, height: height), scale)
    }
    
    /// 复位ImageView
    private func resetImageViewPosition() {
        // 如果图片当前显示的size小于原size，则重置为原size
        let size = computeImageLayoutSize(for: imageView.image, in: scrollView)
        let needResetSize = imageView.bounds.size.width < size.width || imageView.bounds.size.height < size.height
        UIView.animate(withDuration: 0.25) {
            self.imageView.center = self.computeImageLayoutCenter(in: self.scrollView)
            if needResetSize {
                self.imageView.bounds.size = size
            }
        }
    }
    
    /// 手势识别是否允许开始
    open override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let browser = photoBrowser else { return true }
        let total = browser.numberOfItems()
        let isSingle = total <= 1
        if isSingle { return true }
        let velocity = pan.velocity(in: self)
        let absX = abs(velocity.x), absY = abs(velocity.y)
        let isHorizontal = absX > absY
        let isVertical = absY > absX
        let pageIndex = browser.pageIndex
        let itemCount = browser.numberOfItems()
        let atLeft = pageIndex == 0
        let atRight = pageIndex == itemCount - 1
        let offsetY = scrollView.contentOffset.y
        let maxOffsetY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let atTop = offsetY <= 0
        let atBottom = abs(offsetY - maxOffsetY) < 1e-2
        if (isVertical && atTop && velocity.y > 0) || (isVertical && atBottom && velocity.y < 0) || (isHorizontal && atLeft && velocity.x > 0) || (isHorizontal && atRight && velocity.x < 0) {
            return true
        }
        return false
    }
    
    open var showContentView: UIView {
        return imageView
    }
}
