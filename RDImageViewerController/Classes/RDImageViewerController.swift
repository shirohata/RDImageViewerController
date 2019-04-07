//
//  RDImageViewerController.swift
//  Pods-RDImageViewerController
//
//  Created by Akira Matsuda on 2019/04/07.
//

import UIKit

protocol RDImageViewerControllerDelegate {
    func imageViewController(viewController: RDImageViewerController, willChangeIndexTo index: Int)
    func contentViewWillAppear(view: UIView, pageIndex: Int)
}

class RDImageViewerController: UIViewController {

    private enum ViewTag : Int {
        case mainScrollView = 1
        case pageScrollView = 2
        case currentPageLabel = 3
    }

    var delegate: RDImageViewerControllerDelegate?
    var preloadCount: Int {
        set {
            pagingView.preloadCount = newValue
        }
        get {
            return pagingView.preloadCount
        }
    }
    var currentPageIndex: Int {
        set {
            updateSliderValue()
            currentPageHudLabel.text = "\(newValue + 1)/\(numberOfPages)"
            pagingView.scroll(at: newValue)
        }
        get {
            return pagingView.currentPageIndex
        }
    }
    
    var numberOfPages: Int {
        get {
            return contents.count
        }
    }

    var isPagingEnabled: Bool {
        set {
            pagingView.isPagingEnabled = newValue
        }
        get {
            return pagingView.isPagingEnabled
        }
    }
    
    private var _showSlider: Bool = false
    var showSlider: Bool {
        set {
            _showSlider = newValue
            var toolbarPositionY = view.frame.height
            if let toolbarItems = toolbarItems, toolbarItems.count > 0 {
                toolbarPositionY = navigationController?.toolbar.frame.minY ?? 0
            }
            updateHudHorizontalPosition(position: toolbarPositionY)
            applySliderTintColor()
        }
        get {
            return _showSlider
        }
    }
    
    var automaticBarsHiddenDuration: TimeInterval = 0
    var restoreBarState: Bool = true
    private var _showPageNumberHud: Bool = false
    var showPageNumberHud: Bool {
        set {
            _showPageNumberHud = newValue
            if _showPageNumberHud == true {
                view.addSubview(currentPageHud)
            }
            else {
                currentPageHud.removeFromSuperview()
            }
        }
        get {
            return _showPageNumberHud
        }
    }
    var contents: [RDPageContentData] = []
    
    private var previousPageIndex: Int = 0
    private var _statusBarHidden: Bool = false
    private var statusBarHidden: Bool {
        set {
            _statusBarHidden = newValue
            setNeedsStatusBarAppearanceUpdate()
        }
        get {
            return _statusBarHidden
        }
    }
    private var feedbackGenerator = UISelectionFeedbackGenerator()
    private var pagingView: RDPagingView
    private var pageSlider: UISlider
    private var currentPageHud: UIView
    private var currentPageHudLabel: UILabel
    private var pageSliderMaximumTrackTintColor: UIColor?
    private var pageSliderMinimumTrackTintColor: UIColor?
    static private let PageHudLabelFontSize: CGFloat = 17
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        pagingView.startRotation()
        let sizeClass = traitCollection.verticalSizeClass
        coordinator.animate(alongsideTransition: { [unowned self] (context) in
            if self.traitCollection.verticalSizeClass != sizeClass {
                let duration = context.transitionDuration
                self.pagingView.resize(with: CGRect(x: 0, y: 0, width: size.width, height: size.height), duration: duration)
            }
            var toolbarPosition = self.view.frame.height
            if let toolbarItems = self.toolbarItems, toolbarItems.count > 0 {
                toolbarPosition = self.navigationController?.toolbar.frame.minY ?? self.view.frame.height
            }
            self.updateHudHorizontalPosition(position: toolbarPosition)
        }) { [unowned self] (context) in
            self.pagingView.endRotation()
        }
    }
    
    init(contents: [RDPageContentData], direction: RDPagingView.ForwardDirection) {
        self.feedbackGenerator.prepare()
        self.contents = contents
        self.pagingView = RDPagingView(frame: CGRect.zero, numberOfPages: self.contents.count, forwardDirection: direction)
        self.currentPageHud = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        self.currentPageHudLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: RDImageViewerController.PageHudLabelFontSize))
        self.pageSlider = UISlider(frame: CGRect.zero)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pagingView.frame = view.bounds
        pagingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pagingView.backgroundColor = UIColor.black
        pagingView.pagingDelegate = self
        pagingView.pagingDataSource = self
        pagingView.isDirectionalLockEnabled = true
        pagingView.tag = ViewTag.pageScrollView.rawValue
        pagingView.showsHorizontalScrollIndicator = false
        pagingView.showsVerticalScrollIndicator = false
        pagingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(setBarHiddenByTapGesture)))
        
        pageSlider.frame = CGRect(x: 0, y: 0, width: view.frame.width - 30, height: 31)
        pageSlider.autoresizingMask = [.flexibleWidth]
        pageSlider.addTarget(self, action: #selector(sliderValueDidChange(slider:)), for: .valueChanged)
        pageSlider.addTarget(self, action: #selector(sliderDidTouchUpInside(slider:)), for: .touchUpInside)
        toolbarItems = [UIBarButtonItem(customView: pageSlider)]
        updateSliderValue()
        applySliderTintColor()
        
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurView.frame = self.currentPageHud.bounds
        currentPageHud.addSubview(blurView)
        currentPageHud.clipsToBounds = true
        currentPageHud.layer.cornerRadius = 15
        currentPageHud.layer.borderColor = UIColor.white.cgColor
        currentPageHud.layer.borderWidth = 1
        currentPageHud.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin]
        
        let x = view.center.x - currentPageHud.frame.width / 2.0
        var y = view.frame.height - currentPageHud.frame.height - 10
        if let toolbarItems = toolbarItems {
            if toolbarItems.count > 0 {
                y -= 50
            }
        }
        currentPageHud.frame = CGRect(x: x, y: y, width: currentPageHud.frame.width, height: currentPageHud.frame.height)
        currentPageHud.alpha = 0
        
        currentPageHudLabel.backgroundColor = UIColor.clear
        currentPageHudLabel.font = UIFont.systemFont(ofSize: RDImageViewerController.PageHudLabelFontSize)
        currentPageHudLabel.textColor = UIColor.white
        currentPageHudLabel.textAlignment = .center
        currentPageHudLabel.center = CGPoint(x: currentPageHud.bounds.width / 2, y: currentPageHud.bounds.height / 2)
        currentPageHudLabel.tag = ViewTag.currentPageLabel.rawValue
        currentPageHud.addSubview(currentPageHudLabel)
        automaticallyAdjustsScrollViewInsets = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        pagingView.frame = view.bounds
        
        if restoreBarState == false {
            setBarsHidden(hidden: false, animated: animated)
            setHudHidden(hidden: false, animated: animated)
        }
        
        if pagingView.superview == nil {
            view.addSubview(pagingView)
            pagingView.scroll(at: pagingView.currentPageIndex)
        }
        
        if contents.count > 0 {
            if showSlider == true, pagingView.direction.isVertical() {
                if showPageNumberHud {
                    refreshPageHud()
                    view.addSubview(currentPageHud)
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        pagingView.pagingDelegate = self
        if automaticBarsHiddenDuration > 0 {
            perform(#selector(hideBars), with: self, afterDelay: automaticBarsHiddenDuration)
            automaticBarsHiddenDuration = 0
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelAutoBarHidden()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pagingView.pagingDelegate = nil
    }
    
    private func updateSliderValue() {
        if pagingView.direction.isVertical() {
            if pagingView.direction == .right {
                pageSlider.value = Float(pagingView.currentPageIndex) / Float(pagingView.numberOfPages - 1)
            }
            else {
                pageSlider.value = 1.0 - Float(pagingView.currentPageIndex) / Float(pagingView.numberOfPages - 1)
            }
        }
    }
    
    @objc private func setBarHiddenByTapGesture() {
        cancelAutoBarHidden()
        setBarsHidden(hidden: !statusBarHidden, animated: true)
    }
    
    @objc private func sliderValueDidChange(slider: UISlider) {
        cancelAutoBarHidden()
        let trueValue = pagingView.direction == .right ? slider.value : 1.0 - slider.value
        let page = Int(trueValue * Float(pagingView.numberOfPages - 1))
        if currentPageIndex != page {
            feedbackGenerator.selectionChanged()
        }
        pagingView.scroll(at: page)
    }
    
    @objc private func sliderDidTouchUpInside(slider: UISlider) {
        let value = Float(pagingView.currentPageIndex / (pagingView.numberOfPages - 1))
        let trueValue = pagingView.direction == .right ? value : 1 - value
        slider.setValue(trueValue, animated: true)
    }
    
    func reloadView(at index: Int) {
        if contents.count < index {
            let data = contents[index]
            data.reload()
            refreshView(at: index)
        }
    }
    
    func refreshView(at index: Int) {
        if contents.count < index {
            let data = contents[index]
            if let view = pagingView.view(for: index) {
                data.configure(view: view)
            }
        }
    }

    func refreshPageHud() {
        currentPageIndex = pagingView.currentPageIndex
    }
    
    @objc func hideBars() {
        setBarsHidden(hidden: true, animated: true)
    }
    
    func setBarsHidden(hidden: Bool, animated: Bool) {
        if let toolbarItems = toolbarItems, toolbarItems.count > 0 {
            if showSlider, pagingView.direction.isVertical() {
                navigationController?.setToolbarHidden(hidden, animated: animated)
            }
        }
        
        navigationController?.setNavigationBarHidden(hidden, animated: animated)
        setHudHidden(hidden: hidden, animated: animated)
        statusBarHidden = hidden
    }
    
    func setHudHidden(hidden: Bool, animated: Bool) {
        var duration: CGFloat = 0
        if animated {
            duration = UINavigationController.hideShowBarDuration
        }
        UIView.animate(withDuration: TimeInterval(duration), animations: { [unowned self] in
            var toolbarPositionY = self.view.frame.height
            if let toolbarItems = self.toolbarItems, toolbarItems.count > 0 {
                toolbarPositionY = self.navigationController?.toolbar.frame.minY ?? self.view.frame.height
            }
            self.updateHudHorizontalPosition(position: toolbarPositionY)
            self.currentPageHud.alpha = hidden == true ? 0 : 1.0
        }, completion: nil)
    }
    
    private func updateHudHorizontalPosition(position: CGFloat) {
        currentPageHud.frame = CGRect(x: view.center.x - currentPageHud.frame.width / 2.0, y: position - currentPageHud.frame.height - 10, width: currentPageHud.frame.width, height: currentPageHud.frame.height)
    }
    
    private func cancelAutoBarHidden() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideBars), object: self)
    }
    
    private func applySliderTintColor() {
        var maximumTintColor = UIColor(red: 0, green: (122.0 / 255.0), blue: 1, alpha: 1)
        if let tintColor = pageSliderMaximumTrackTintColor {
            maximumTintColor = tintColor
        }
        
        var minimumTintColor = UIColor.white
        if let tintColor = pageSliderMinimumTrackTintColor {
            minimumTintColor = tintColor
        }
        
        pageSlider.maximumTrackTintColor = pagingView.direction == .left ? maximumTintColor : minimumTintColor
        pageSlider.minimumTrackTintColor = pagingView.direction == .left ? minimumTintColor : maximumTintColor
    }
}

extension RDImageViewerController
{
    override var prefersStatusBarHidden: Bool {
        return statusBarHidden
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portraitUpsideDown
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
}


extension RDImageViewerController: RDPagingViewDelegate
{
    @objc func pagingView(pagingView: RDPagingView, willChangeViewSize size: CGSize, duration: TimeInterval, visibleViews: [UIView]) {
        for v in visibleViews {
            if v.pageIndex != pagingView.currentPageIndex {
                v.isHidden = true
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    v.isHidden = false
                }
            }
            
            if pagingView.direction.isVertical() {
                let x = pagingView.direction == .right ? CGFloat(v.pageIndex) : (CGFloat(pagingView.numberOfPages - v.pageIndex - 1) * size.width)
                v.frame = CGRect(x: x, y: 0, width: size.width, height: size.height)
            }
            else {
                let y = pagingView.direction == .right ? CGFloat(v.pageIndex) : (CGFloat(pagingView.numberOfPages - v.pageIndex - 1) * size.height)
                v.frame = CGRect(x: 0, y: y, width: size.width, height: size.height)
            }
            
            if v.isKind(of: UIScrollView.self) {
                let scrollView = v as! UIScrollView
                scrollView.zoomScale = 1.0
                if scrollView.isKind(of: RDImageScrollView.self) {
                    let imageScrollView = scrollView as! RDImageScrollView
                    imageScrollView.adjustContentAspect()
                }
            }
        }
    }

    @objc func pagingView(pagingView: RDPagingView, willViewEnqueue view: UIView) {
        let data = contents[view.pageIndex]
        data.stopPreload()
    }
    
    @objc func pagingView(pagingView: RDPagingView, willChangeIndexTo index: Int) {
        if let delegate = delegate {
            delegate.imageViewController(viewController: self, willChangeIndexTo: index)
        }
    }
    
    @objc func pagingView(pagingView: RDPagingView, didScrollToPosition position: CGFloat) {
        if pageSlider.state == .normal {
            let p = pagingView.numberOfPages - 1
            pageSlider.value = Float(position / CGFloat(p))
        }
        refreshPageHud()
    }

    @objc func pagingViewWillBeginDragging(pagingView: RDPagingView) {
        if pagingView.isDragging == false {
            previousPageIndex = currentPageIndex
        }
    }
    
    @objc func pagingViewDidEndDecelerating(pagingView: RDPagingView) {
        let page = currentPageIndex
        for view in pagingView.subviews {
            if view.isKind(of: UIScrollView.self) {
                let scrollView = view as! UIScrollView
                if pagingView.isPagingEnabled == true, page != previousPageIndex {
                    scrollView.zoomScale = 1.0
                }
                else if previousPageIndex == pagingView.currentPageIndex - 2 || previousPageIndex == pagingView.currentPageIndex + 2 {
                    scrollView.zoomScale = 1.0
                }
            }
        }
    }
}

extension RDImageViewerController: RDPagingViewDataSource
{
    func pagingView(pagingView: RDPagingView, viewForIndex index: Int) -> UIView {
        let data = contents[index]
        let frame = CGRect(x: 0, y: 0, width: pagingView.bounds.width, height: pagingView.bounds.height)
        let view = data.contentView(frame: frame)
        if data.preloadable() {
            data.preload()
        }
        data.configure(view: view)
        
        if view.isKind(of: RDImageScrollView.self) {
            let imageScrollView = view as! RDImageScrollView
            pagingView.gestureRecognizers?.forEach({ (gesture) in
                if gesture is UITapGestureRecognizer {
                    imageScrollView.addGestureRecognizerPriorityHigherThanZoomGestureRecogniser(gesture: gesture)
                }
            })
        }
        if let delegate = delegate {
            delegate.contentViewWillAppear(view: view, pageIndex: index)
        }
        
        return view
    }
    
    func pagingView(pagingView: RDPagingView, reuseIdentifierForIndex index: Int) -> String {
        if contents.count < index {
            let data = contents[index]
            return String(describing: type(of: data))
        }
        
        return ""
    }
}