//
//  MBProgressHUD.swift
//  MBProgressHUDForSwift
//
//  Created by hzs on 15/7/14.
//  Copyright (c) 2015年 powfulhong. All rights reserved.
//

import UIKit
import Dispatch

//MARK: - Extension UIView
extension UIView {
    func updateUI() {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.setNeedsLayout()
            self.setNeedsDisplay()
        }
    }
}

//MARK: - MBProgressHUDDelegate
@objc protocol MBProgressHUDDelegate {
    optional func hudWasHidden(hud: MBProgressHUD)
}

//MARK: - ENUM
enum MBProgressHUDMode: Int {
    case Indeterminate = 0
    case AnnularIndeterminate   //
    case Determinate
    case DeterminateHorizontalBar
    case AnnularDeterminate
    case CustomView
    case Text
}

enum MBProgressHUDAnimation: Int {
    case Fade = 0
    case Zoom
    case ZoomOut
    case ZoomIn
}

//MARK: - Global var and func
typealias MBProgressHUDCompletionBlock = () -> Void
typealias MBProgressHUDExecutionClosures = () -> Void

let kPadding: CGFloat = 4.0
let kLabelFontSize: CGFloat = 16.0
let kDetailsLabelFontSize: CGFloat = 12.0

func MB_TEXTSIZE(text: String?, font: UIFont) -> CGSize {
    guard let textTemp = text where textTemp.characters.count > 0 else {
        return CGSizeZero
    }
    
    return (textTemp as NSString).sizeWithAttributes([NSFontAttributeName: font])
}

func MB_MULTILINE_TEXTSIZE(text: String?, font: UIFont, maxSize: CGSize, mode: NSLineBreakMode) -> CGSize {
    guard let textTemp = text where textTemp.characters.count > 0 else {
        return CGSizeZero
    }
    
    return (textTemp as NSString).boundingRectWithSize(maxSize, options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: [NSFontAttributeName: font], context: nil).size
}

//MARK: - MBProgressHUD
class MBProgressHUD: UIView {
    private var useAnimation: Bool = true
//    private var methodForExecution: Selector?
//    private var targetForExecution: AnyObject?
//    private var objectForExecution: AnyObject?
    private var closureForExecution: MBProgressHUDExecutionClosures?
    private var label: UILabel?
    private var detailsLabel: UILabel?
    private var rotationTransform: CGAffineTransform = CGAffineTransformIdentity
    
    private var indicator: UIView?
    private var graceTimer: NSTimer?
    private var minShowTimer: NSTimer?
    private var showStarted: NSDate?
    
    var customView: UIView? {
        didSet {
            self.updateIndicators()
            self.updateUI()
        }
    }
    
    var animationType = MBProgressHUDAnimation.Fade
    var mode = MBProgressHUDMode.Indeterminate {
        didSet {
            self.updateIndicators()
            self.updateUI()
        }
    }
    var labelText: String? {
        didSet {
            label!.text = labelText
            self.updateUI()
        }
    }
    var detailsLabelText: String? {
        didSet {
            detailsLabel!.text = detailsLabelText
            self.updateUI()
        }
    }
    var opacity = 0.8
    var color: UIColor?
    var labelFont = UIFont.boldSystemFontOfSize(kLabelFontSize) {
        didSet {
            label!.font = labelFont
            self.updateUI()
        }
    }
    var labelColor = UIColor.whiteColor() {
        didSet {
            label!.textColor = labelColor
            self.updateUI()
        }
    }
    var detailsLabelFont = UIFont.boldSystemFontOfSize(kDetailsLabelFontSize) {
        didSet {
            detailsLabel!.font = detailsLabelFont
            self.updateUI()
        }
    }
    var detailsLabelColor = UIColor.whiteColor() {
        didSet {
            detailsLabel!.textColor = detailsLabelColor
            self.updateUI()
        }
    }
    var activityIndicatorColor = UIColor.whiteColor() {
        didSet {
            self.updateIndicators()
            self.updateUI()
        }
    }
    var xOffset = 0.0
    var yOffset = 0.0
    var dimBackground = false
    var margin = 20.0
    var cornerRadius = 10.0
    var graceTime = 0.0
    var minShowTime = 0.0
    var removeFromSuperViewOnHide = false
    var minSize: CGSize = CGSizeZero
    var square = false
    var size: CGSize = CGSizeZero
    
    var taskInprogress = false
    
    var progress: Float = 0.0 {
        didSet {
            indicator?.setValue(progress, forKey: "progress")
        }
    }
    
    var completionBlock: MBProgressHUDCompletionBlock?
    
    var delegate: MBProgressHUDDelegate?
    
    // MARK: - Lifecycle
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.contentMode = UIViewContentMode.Center
        self.autoresizingMask = [UIViewAutoresizing.FlexibleTopMargin, UIViewAutoresizing.FlexibleBottomMargin, UIViewAutoresizing.FlexibleLeftMargin, UIViewAutoresizing.FlexibleRightMargin]
        self.opaque = false
        self.backgroundColor = UIColor.clearColor()
        self.alpha = 0.0
        
        self.setupLabels()
        self.updateIndicators()
    }
    
    convenience init(view: UIView?) {
        assert(view != nil, "View must not be nil.")
        
        self.init(frame: view!.bounds)
    }
    
    convenience init(window: UIWindow) {
        self.init(view: window)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.unregisterFromNotifications()
    }
    
    // MARK: - Show & Hide
    func show(animated: Bool) {
        assert(NSThread.isMainThread(), "MBProgressHUD needs to be accessed on the main thread.")
        useAnimation = animated
        if graceTime > 0.0 {
            let newGraceTimer: NSTimer = NSTimer(timeInterval: graceTime, target: self, selector: "handleGraceTimer:", userInfo: nil, repeats: false)
            NSRunLoop.currentRunLoop().addTimer(newGraceTimer, forMode: NSRunLoopCommonModes)
            graceTimer = newGraceTimer
        }
        // ... otherwise show the HUD imediately
        else {
            self.showUsingAnimation(useAnimation)
        }
    }
    
    func hide(animated: Bool) {
        assert(NSThread.isMainThread(), "MBProgressHUD needs to be accessed on the main thread.")
        useAnimation = animated
        // If the minShow time is set, calculate how long the hud was shown,
        // and pospone the hiding operation if necessary
        if minShowTime > 0.0 && showStarted != nil {
            let interv: NSTimeInterval = NSDate().timeIntervalSinceDate(showStarted!)
            if interv < minShowTime {
                minShowTimer = NSTimer(timeInterval: minShowTime - interv, target: self, selector: "handleMinShowTimer:", userInfo: nil, repeats: false)
                return
            }
        }
        // ... otherwise hide the HUD immediately
        self.hideUsingAnimation(useAnimation)
    }
    
    func hide(animated: Bool, afterDelay delay: NSTimeInterval) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
            self.hideDelayed(animated)
        }
    }
    
    func hideDelayed(animated: Bool) {
        self.hide(animated)
    }
    
    // MARK: - Timer callbacks
    private func handleGraceTimer(theTimer: NSTimer) {
        // Show the HUD only if the task is still running
        if taskInprogress {
            self.showUsingAnimation(useAnimation)
        }
    }
    
    private func handleMinShowTimer(theTimer: NSTimer) {
        self.hideUsingAnimation(useAnimation)
    }
    
    // MARK: - View Hierrarchy
    override func didMoveToSuperview() {
        self.updateForCurrentOrientationAnimaged(false)
    }
    
    // MARK: -  Internal show & hide operations
    private func showUsingAnimation(animated: Bool) {
        // Cancel any scheduled hideDelayed: calls
        NSObject.cancelPreviousPerformRequestsWithTarget(self)
        self.setNeedsDisplay()
        
        if animated && animationType == .ZoomIn {
            self.transform = CGAffineTransformConcat(rotationTransform, CGAffineTransformMakeScale(0.5, 0.5))
        } else if animated && animationType == .ZoomOut {
            self.transform = CGAffineTransformConcat(rotationTransform, CGAffineTransformMakeScale(1.5, 1.5))
        }
        self.showStarted = NSDate()
        //Fade in
        if animated {
            UIView.beginAnimations(nil, context:nil)
            UIView.setAnimationDuration(0.30)
            self.alpha = 1.0
            if animationType == .ZoomIn || animationType == .ZoomOut {
                self.transform = rotationTransform
            }
            UIView.commitAnimations()
        } else {
            self.alpha = 1.0
        }
    }
    
    private func hideUsingAnimation(animated: Bool) {
        // Fade out
        if animated && showStarted != nil {
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationDuration(0.30)
            UIView.setAnimationDelegate(self)
            UIView.setAnimationDidStopSelector(Selector("animationFinished:finished:context:"))
            // 0.02 prevents the hud from passing through touches during the animation the hud will get completely hidden
            // in the done method
            if animationType == .ZoomIn {
                self.transform = CGAffineTransformConcat(rotationTransform, CGAffineTransformMakeScale(1.5, 1.5))
            } else if animationType == .ZoomOut {
                self.transform = CGAffineTransformConcat(rotationTransform, CGAffineTransformMakeScale(0.5, 0.5))
            }
            
            self.alpha = 0.02
            UIView.commitAnimations()
        } else {
            self.alpha = 0.0
            self.done()
        }
        self.showStarted = nil
    }
    
    func animationFinished(animationID: String?, finished: Bool, context: UnsafeMutablePointer<Void>) {
        self.done()
    }
    
    private func done() {
        NSObject.cancelPreviousPerformRequestsWithTarget(self)
        
//        isFinished = true
        self.alpha = 0.0
        if removeFromSuperViewOnHide {
            self.removeFromSuperview()
        }
        
        if completionBlock != nil {
            self.completionBlock!()
            self.completionBlock = nil
        }
        
        delegate?.hudWasHidden?(self)
    }
    
    // MARK: - Threading
    func showWhileExecuting(method: Selector, onTarget target: AnyObject, withObject object: AnyObject?, animated: Bool) {
//        methodForExecution = method
//        targetForExecution = target
//        objectForExecution = object
        // Launch execution in new thread
        taskInprogress = true
        NSThread.detachNewThreadSelector("launchExecution", toTarget: self, withObject: nil)
        // Show HUD view
        self.show(animated)
    }
    
    func showWhileExecuting(closures: MBProgressHUDExecutionClosures, animated: Bool) {
        // Launch execution in new thread
        taskInprogress = true
        closureForExecution = closures
        
        NSThread.detachNewThreadSelector("launchExecution_closures", toTarget: self, withObject: nil)
        
        
        // Show HUD view
        self.show(animated)
    }
    
    func showAnimated(animated: Bool, whileExecutingBlock block: dispatch_block_t) {
        self.showAnimated(animated, whileExecutingBlock: block, onQueue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), completionBlock: nil)
    }
    
    func showAnimated(animated: Bool, whileExecutingBlock block: dispatch_block_t, completionBlock completion: MBProgressHUDCompletionBlock?) {
        self.showAnimated(animated, whileExecutingBlock: block, onQueue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), completionBlock: completion)
    }
    
    func showAnimated(animated: Bool, whileExecutingBlock block: dispatch_block_t, onQueue queue: dispatch_queue_t) {
        self.showAnimated(animated, whileExecutingBlock: block, onQueue: queue, completionBlock: nil)
    }
    
    func showAnimated(animated: Bool, whileExecutingBlock block: dispatch_block_t, onQueue queue: dispatch_queue_t, completionBlock completion: MBProgressHUDCompletionBlock?) {
        taskInprogress = true
        self.completionBlock = completion
        dispatch_async(queue, { () -> Void in
            block()
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.cleanUp()
            })
        })
        self.show(animated)
    }
    
    func launchExecution() {
        autoreleasepool {
//            (targetForExecution as! NSObject).swift_performSelector(methodForExecution!, withObject: objectForExecution)
//            self.swift_performSelectorOnMainThread(Selector("cleanUp"), withObject: nil, waitUntilDone: false)
        }
    }
    
    func launchExecution_closures() {
        autoreleasepool { () -> () in
            closureForExecution!()
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.cleanUp()
            })
        }
    }
    
    func cleanUp() {
        taskInprogress = false
//        targetForExecution = nil
//        objectForExecution = nil
//        methodForExecution = nil
        closureForExecution = nil
        
        self.hide(useAnimation)
    }
    
    // MARK: - UI
    private func setupLabels() {
        label = UILabel(frame: self.bounds)
        label!.adjustsFontSizeToFitWidth = false
        label!.textAlignment = NSTextAlignment.Center
        label!.opaque = false
        label!.backgroundColor = UIColor.clearColor()
        label!.textColor = labelColor
        label!.font = labelFont
        label!.text = labelText
        self.addSubview(label!)
        
        detailsLabel = UILabel(frame: self.bounds)
        detailsLabel!.font = detailsLabelFont
        detailsLabel!.adjustsFontSizeToFitWidth = false
        detailsLabel!.textAlignment = NSTextAlignment.Center
        detailsLabel!.opaque = false
        detailsLabel!.backgroundColor = UIColor.clearColor()
        detailsLabel!.textColor = detailsLabelColor
        detailsLabel!.numberOfLines = 0
        detailsLabel!.font = detailsLabelFont
        detailsLabel!.text = detailsLabelText
        self.addSubview(detailsLabel!)
    }
    
    private func updateIndicators() {
        let isActivityIndicator: Bool = indicator is UIActivityIndicatorView
        let isRoundIndicator: Bool = indicator is MBRoundProgressView
        let isIndeterminatedRoundIndicator: Bool = indicator is MBIndeterminatedRoundProgressView
        
        if mode == MBProgressHUDMode.Indeterminate {
            if !isActivityIndicator {
                indicator?.removeFromSuperview()
                indicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.WhiteLarge)
                (indicator as! UIActivityIndicatorView).startAnimating()
                self.addSubview(indicator!)
            }
            (indicator as! UIActivityIndicatorView).color = activityIndicatorColor
        } else if mode == MBProgressHUDMode.AnnularIndeterminate {
            if !isIndeterminatedRoundIndicator {
                indicator?.removeFromSuperview()
                indicator = MBIndeterminatedRoundProgressView()
                self.addSubview(indicator!)
            }
        } else if mode == MBProgressHUDMode.DeterminateHorizontalBar {
            indicator?.removeFromSuperview()
            indicator = MBBarProgressView()
            self.addSubview(indicator!)
        } else if mode == MBProgressHUDMode.Determinate || mode == MBProgressHUDMode.AnnularDeterminate {
            if !isRoundIndicator {
                indicator?.removeFromSuperview()
                indicator = MBRoundProgressView()
                self.addSubview(indicator!)
            }
            if mode == MBProgressHUDMode.AnnularDeterminate {
                (indicator as! MBRoundProgressView).annular = true
            }
        } else if mode == MBProgressHUDMode.CustomView && customView != indicator {
            indicator?.removeFromSuperview()
            self.indicator = customView
            self.addSubview(indicator!)
        } else if mode == MBProgressHUDMode.Text {
            indicator?.removeFromSuperview()
            indicator = nil
        }
    }
    
    // MARK: - Notificaiton
    private func registerForNotifications() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "statusBarOrientationDidChange:", name: UIApplicationDidChangeStatusBarOrientationNotification, object: nil)
    }
    
    private func unregisterFromNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIApplicationDidChangeStatusBarOrientationNotification, object: nil)
    }
    
    private func statusBarOrientationDidChange(notification: NSNotification) {
        if let _ = self.superview {
            self.updateForCurrentOrientationAnimaged(true)
        }
    }
    
    private func updateForCurrentOrientationAnimaged(animated: Bool) {
        // Stay in sync with the superview in any case
        if self.superview != nil {
            self.bounds = self.superview!.bounds
            self.setNeedsDisplay()
        }
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Entirely cover the parent view
        if let parent = self.superview {
            self.frame = parent.bounds
        }
        let bounds: CGRect = self.bounds;
        
        // Determine the total widt and height needed
        let maxWidth: CGFloat = bounds.size.width - 4 * CGFloat(margin)
        var totalSize: CGSize = CGSizeZero
        
        
        var indicatorF: CGRect = ((indicator != nil) ? indicator!.bounds : CGRectZero)
        indicatorF.size.width = min(indicatorF.size.width, maxWidth)
        totalSize.width = max(totalSize.width, indicatorF.size.width)
        totalSize.height += indicatorF.size.height
        
        var labelSize: CGSize = MB_TEXTSIZE(label!.text, font: label!.font)
        labelSize.width = min(labelSize.width, maxWidth)
        totalSize.width = max(totalSize.width, labelSize.width)
        totalSize.height += labelSize.height
        if labelSize.height > 0.0 && indicatorF.size.height > 0.0 {
            totalSize.height += kPadding
        }
        
        let remainingHeight: CGFloat = bounds.size.height - totalSize.height - kPadding - 4 * CGFloat(margin)
        let maxSize: CGSize = CGSizeMake(maxWidth, remainingHeight)
        let detailsLabelSize: CGSize = MB_MULTILINE_TEXTSIZE(detailsLabel!.text, font: detailsLabel!.font, maxSize: maxSize, mode: detailsLabel!.lineBreakMode)
        totalSize.width = max(totalSize.width, detailsLabelSize.width)
        totalSize.height += detailsLabelSize.height
        if detailsLabelSize.height > 0.0 && (indicatorF.size.height > 0.0 || labelSize.height > 0.0) {
            totalSize.height += kPadding
        }
        
        totalSize.width += 2 * CGFloat(margin)
        totalSize.height += 2 * CGFloat(margin)
        
        // Position elements
        var yPos: CGFloat = round(((bounds.size.height - totalSize.height) / 2)) + CGFloat(margin) + CGFloat(yOffset)
        let xPos: CGFloat = CGFloat(xOffset)
        indicatorF.origin.y = yPos
        indicatorF.origin.x = round((bounds.size.width - indicatorF.size.width) / 2) + xPos
        indicator?.frame = indicatorF
        yPos += indicatorF.size.height
        
        if labelSize.height > 0.0 && indicatorF.size.height > 0.0 {
            yPos += kPadding
        }
        var labelF: CGRect = CGRectZero
        labelF.origin.y = yPos
        labelF.origin.x = round((bounds.size.width - labelSize.width) / 2) + xPos
        labelF.size = labelSize
        label!.frame = labelF
        yPos += labelF.size.height
        
        if detailsLabelSize.height > 0.0 && (indicatorF.size.height > 0.0 || labelSize.height > 0.0) {
            yPos += kPadding
        }
        var detailsLabelF: CGRect = CGRectZero
        detailsLabelF.origin.y = yPos
        detailsLabelF.origin.x = round((bounds.size.width - detailsLabelSize.width) / 2) + xPos
        detailsLabelF.size = detailsLabelSize
        detailsLabel!.frame = detailsLabelF
        
        // Enforce minsize and quare rules
        if square {
            let maxWH: CGFloat = max(totalSize.width, totalSize.height);
            if maxWH <= bounds.size.width - 2 * CGFloat(margin) {
                totalSize.width = maxWH
            }
            if maxWH <= bounds.size.height - 2 * CGFloat(margin) {
                totalSize.height = maxWH
            }
        }
        if totalSize.width < minSize.width {
            totalSize.width = minSize.width
        } 
        if totalSize.height < minSize.height {
            totalSize.height = minSize.height
        }
        
        size = totalSize
    }
    
    // MARK: - BG Drawing
    override func drawRect(rect: CGRect) {
        let context: CGContextRef = UIGraphicsGetCurrentContext()!
        UIGraphicsPushContext(context)
        
        if self.dimBackground {
            //Gradient colours
            let gradLocationsNum: size_t = 2
            let gradLocations: [CGFloat] = [0.0, 1.0]
            let gradColors: [CGFloat] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.75]
            let colorSpace: CGColorSpaceRef = CGColorSpaceCreateDeviceRGB()!
            let gradient: CGGradientRef = CGGradientCreateWithColorComponents(colorSpace, gradColors, gradLocations, gradLocationsNum)!
            //Gradient center
            let gradCenter: CGPoint = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2)
            //Gradient radius
            let gradRadius: CGFloat = min(self.bounds.size.width , self.bounds.size.height)
            //Gradient draw
            CGContextDrawRadialGradient(context, gradient, gradCenter, 0, gradCenter, gradRadius,CGGradientDrawingOptions.DrawsAfterEndLocation)
        }
        
        // Set background rect color
        if self.color != nil {
            CGContextSetFillColorWithColor(context, self.color!.CGColor)
        } else {
            CGContextSetGrayFillColor(context, 0.0, CGFloat(opacity))
        }
        
        
        // Center HUD
        let allRect: CGRect = self.bounds
        // Draw rounded HUD backgroud rect
        let boxRect: CGRect = CGRectMake(round((allRect.size.width - size.width) / 2) + CGFloat(self.xOffset), round((allRect.size.height - size.height) / 2) + CGFloat(self.yOffset), size.width, size.height)
        let radius = cornerRadius
        CGContextBeginPath(context)
        CGContextMoveToPoint(context, CGRectGetMinX(boxRect) + CGFloat(radius), CGRectGetMinY(boxRect))
        CGContextAddArc(context, CGRectGetMaxX(boxRect) - CGFloat(radius), CGRectGetMinY(boxRect) + CGFloat(radius), CGFloat(radius), 3 * CGFloat(M_PI) / 2, 0, 0)
        CGContextAddArc(context, CGRectGetMaxX(boxRect) - CGFloat(radius), CGRectGetMaxY(boxRect) - CGFloat(radius), CGFloat(radius), 0, CGFloat(M_PI) / 2, 0)
        CGContextAddArc(context, CGRectGetMinX(boxRect) + CGFloat(radius), CGRectGetMaxY(boxRect) - CGFloat(radius), CGFloat(radius), CGFloat(M_PI) / 2, CGFloat(M_PI), 0)
        CGContextAddArc(context, CGRectGetMinX(boxRect) + CGFloat(radius), CGRectGetMinY(boxRect) + CGFloat(radius), CGFloat(radius), CGFloat(M_PI), 3 * CGFloat(M_PI) / 2, 0)
        CGContextClosePath(context)
        CGContextFillPath(context)
        
        UIGraphicsPopContext()
    }
}

// MARK: - Class methods
extension MBProgressHUD {
    
    class func showHUDAddedTo(view: UIView, animated: Bool) -> MBProgressHUD {
        let hud: MBProgressHUD = MBProgressHUD(view: view)
        hud.removeFromSuperViewOnHide = true
        view.addSubview(hud)
        hud.show(animated)
        
        return hud
    }
    
    class func hideHUDForView(view: UIView, animated: Bool) -> Bool {
        let hud: MBProgressHUD? = self.HUDForView(view)
        if hud != nil {
            hud!.removeFromSuperViewOnHide = true
            hud!.hide(animated)
            
            return true
        }
        
        return false
    }
    
    class func hideAllHUDsForView(view: UIView, animated: Bool) -> Int {
        let huds = MBProgressHUD.allHUDsForView(view)
        for hud in huds {
            hud.removeFromSuperViewOnHide = true
            hud.hide(animated)
        }
        
        return huds.count
    }
    
    class func HUDForView(view: UIView) -> MBProgressHUD? {
        for subview in Array(view.subviews.reverse()) {
            if subview is MBProgressHUD {
                return subview as? MBProgressHUD
            }
        }
        
        return nil
    }
    
    class func allHUDsForView(view: UIView) -> [MBProgressHUD] {
        var huds: [MBProgressHUD] = []
        for aView in view.subviews {
            if aView is MBProgressHUD {
                huds.append(aView as! MBProgressHUD)
            }
        }
        
        return huds
    }
}

// MARK: - MBRoundProgressView
class MBRoundProgressView: UIView {
    var progress: Float = 0.0 {
        didSet {
//            self.swift_performSelectorOnMainThread("setNeedsDisplay", withObject: nil, waitUntilDone: false)
            self.updateUI()
        }
    }
    
    var progressTintColor: UIColor? {
        didSet {
//            self.swift_performSelectorOnMainThread("setNeedsDisplay", withObject: nil, waitUntilDone: false)
            self.updateUI()
        }
    }
    
    var backgroundTintColor: UIColor? {
        didSet {
//            self.swift_performSelectorOnMainThread("setNeedsDisplay", withObject: nil, waitUntilDone: false)
            self.updateUI()
        }
    }
    
    var annular: Bool = false {
        didSet {
//            self.swift_performSelectorOnMainThread("setNeedsDisplay", withObject: nil, waitUntilDone: false)
            self.updateUI()
        }
    }
    
    convenience init() {
        self.init(frame: CGRectMake(0.0, 0.0, 37.0, 37.0))
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clearColor()
        self.opaque = false
        
        progressTintColor = UIColor(white: 1.0, alpha: 1.0)
        backgroundTintColor = UIColor(white: 1.0, alpha: 0.1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawRect(rect: CGRect) {
        let allRect: CGRect = self.bounds
        let circleRect: CGRect = CGRectInset(allRect, 2.0, 2.0)
        let context: CGContextRef = UIGraphicsGetCurrentContext()!
        
        if annular {
            // Draw background
            let lineWidth: CGFloat = 2.0
            let processBackgroundPath: UIBezierPath = UIBezierPath()
            
            processBackgroundPath.lineWidth = lineWidth
            processBackgroundPath.lineCapStyle = CGLineCap.Butt
            
            let center: CGPoint = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2)
            let radius: CGFloat = (self.bounds.size.width - lineWidth) / 2
            let startAngle: CGFloat = -(CGFloat(M_PI) / 2)
            var endAngle: CGFloat = (2 * CGFloat(M_PI)) + startAngle
            processBackgroundPath.addArcWithCenter(center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            backgroundTintColor!.set()
            processBackgroundPath.stroke()
            
            // Draw progress
            let processPath: UIBezierPath = UIBezierPath()
            processPath.lineCapStyle = CGLineCap.Square
            processPath.lineWidth = lineWidth
            endAngle = CGFloat(progress) * 2 * CGFloat(M_PI) + startAngle
            processPath.addArcWithCenter(center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            progressTintColor!.set()
            processPath.stroke()
        } else {
            // Draw background
            progressTintColor!.setStroke()
            backgroundTintColor!.setFill()
            CGContextSetLineWidth(context, 2.0)
            CGContextFillEllipseInRect(context, circleRect)
            CGContextStrokeEllipseInRect(context, circleRect)
            
            // Draw progress
            let center: CGPoint = CGPointMake(allRect.size.width / 2, allRect.size.height / 2)
            let radius: CGFloat = (allRect.size.width - 4) / 2
            let startAngle: CGFloat = -(CGFloat(M_PI) / 2)
            let endAngle: CGFloat = CGFloat(progress) * 2 * CGFloat(M_PI) + startAngle
            progressTintColor!.setFill()
            CGContextMoveToPoint(context, center.x, center.y)
            CGContextAddArc(context, center.x, center.y, radius, startAngle, endAngle, 0)
            CGContextClosePath(context)
            CGContextFillPath(context)
        }
    }
}


// MARK: - MBBarProgressView
class MBBarProgressView: UIView {
    var progress: Float = 0.0 {
        didSet {
            self.updateUI()
        }
    }
    
    var lineColor: UIColor? {
        didSet {
            self.updateUI()
        }
    }
    
    var progressRemainingColor: UIColor? {
        didSet {
            self.updateUI()
        }
    }
    
    var progressColor: UIColor? {
        didSet {
            self.updateUI()
        }
    }
    
    convenience init() {
        self.init(frame: CGRectMake(0.0, 0.0, 120.0, 20.0))
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        progress = 0.0
        lineColor = UIColor.whiteColor()
        progressColor = UIColor.whiteColor()
        progressRemainingColor = UIColor.clearColor()
        
        self.backgroundColor = UIColor.clearColor()
        self.opaque = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawRect(rect: CGRect) {
        let context: CGContextRef = UIGraphicsGetCurrentContext()!
        
        CGContextSetLineWidth(context, 2)
        CGContextSetStrokeColorWithColor(context, lineColor!.CGColor)
        CGContextSetFillColorWithColor(context, progressRemainingColor!.CGColor)
        
        // Draw background
        var radius: CGFloat = (rect.size.height / 2) - 2
        CGContextMoveToPoint(context, 2, rect.size.height / 2)
        CGContextAddArcToPoint(context, 2, 2, radius + 2, 2, radius)
        CGContextAddLineToPoint(context, rect.size.width - radius - 2, 2)
        CGContextAddArcToPoint(context, rect.size.width - 2, 2, rect.size.width - 2, rect.size.height / 2, radius)
        CGContextAddArcToPoint(context, rect.size.width - 2, rect.size.height - 2, rect.size.width - radius - 2, rect.size.height - 2, radius)
        CGContextAddLineToPoint(context, radius + 2, rect.size.height - 2)
        CGContextAddArcToPoint(context, 2, rect.size.height - 2, 2, rect.size.height / 2, radius)
        CGContextFillPath(context)
        
        // Draw border
        CGContextMoveToPoint(context, 2, rect.size.height / 2)
        CGContextAddArcToPoint(context, 2, 2, radius + 2, 2, radius)
        CGContextAddLineToPoint(context, rect.size.width - radius - 2, 2)
        CGContextAddArcToPoint(context, rect.size.width - 2, 2, rect.size.width - 2, rect.size.height / 2, radius)
        CGContextAddArcToPoint(context, rect.size.width - 2, rect.size.height - 2, rect.size.width - radius - 2, rect.size.height - 2, radius)
        CGContextAddLineToPoint(context, radius + 2, rect.size.height - 2)
        CGContextAddArcToPoint(context, 2, rect.size.height - 2, 2, rect.size.height / 2, radius)
        CGContextStrokePath(context)
        
        CGContextSetFillColorWithColor(context, progressColor!.CGColor)
        radius = radius - 2
        let amount: CGFloat = CGFloat(progress) * rect.size.width
        
        // Progress in the middle area
        if amount >= radius + 4 && amount <= (rect.size.width - radius - 4) {
            CGContextMoveToPoint(context, 4, rect.size.height / 2)
            CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius)
            CGContextAddLineToPoint(context, amount, 4)
            CGContextAddLineToPoint(context, amount, radius + 4)
            
            CGContextMoveToPoint(context, 4, rect.size.height / 2)
            CGContextAddArcToPoint(context, 4, rect.size.height - 4, radius + 4, rect.size.height - 4, radius)
            CGContextAddLineToPoint(context, amount, rect.size.height - 4)
            CGContextAddLineToPoint(context, amount, radius + 4)
            
            CGContextFillPath(context)
        }
        
            // Progress in the right arc
        else if (amount > radius + 4) {
            let x: CGFloat = amount - (rect.size.width - radius - 4)
            
            CGContextMoveToPoint(context, 4, rect.size.height / 2)
            CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius)
            CGContextAddLineToPoint(context, rect.size.width - radius - 4, 4)
            var angle: CGFloat = -acos(x / radius)
            if isnan(angle) {   angle = 0   }
            CGContextAddArc(context, rect.size.width - radius - 4, rect.size.height / 2, radius, CGFloat(M_PI), angle, 0)
            CGContextAddLineToPoint(context, amount, rect.size.height / 2)
            
            CGContextMoveToPoint(context, 4, rect.size.height/2)
            CGContextAddArcToPoint(context, 4, rect.size.height - 4, radius + 4, rect.size.height - 4, radius)
            CGContextAddLineToPoint(context, rect.size.width - radius - 4, rect.size.height - 4)
            angle = acos(x/radius)
            if (isnan(angle)) { angle = 0 }
            CGContextAddArc(context, rect.size.width - radius - 4, rect.size.height / 2, radius, CGFloat(-M_PI), angle, 1)
            CGContextAddLineToPoint(context, amount, rect.size.height / 2)
            
            CGContextFillPath(context)
        }
            
            // Progress is in the left arc
        else if amount < radius + 4 && amount > 0 {
            CGContextMoveToPoint(context, 4, rect.size.height / 2)
            CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius)
            CGContextAddLineToPoint(context, radius + 4, rect.size.height / 2)
            
            CGContextMoveToPoint(context, 4, rect.size.height / 2)
            CGContextAddArcToPoint(context, 4, rect.size.height - 4, radius + 4, rect.size.height - 4, radius)
            CGContextAddLineToPoint(context, radius + 4, rect.size.height / 2)
            
            CGContextFillPath(context)
        }
    }
}

// MARK: - MBIndeterminatedRoundProgressView
class MBIndeterminatedRoundProgressView: UIView {
    private let circleLayer: CAShapeLayer = CAShapeLayer()
    
    var lineColor: UIColor = UIColor.whiteColor() {
        didSet {
            self.updateUI()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = UIColor.clearColor()
        self.opaque = false
        
        setupAndStartRotatingCircle()
    }
    
    convenience init() {
        self.init(frame: CGRectMake(0.0, 0.0, 37.0, 37.0))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupAndStartRotatingCircle() {
        let circlePath = UIBezierPath(roundedRect: self.bounds, cornerRadius: self.bounds.size.width / 2)
        circleLayer.frame = self.bounds
        circleLayer.path = circlePath.CGPath
        circleLayer.strokeColor = lineColor.CGColor
        circleLayer.lineWidth = 2.0
        circleLayer.fillColor = UIColor.clearColor().CGColor
        circleLayer.lineCap = kCALineCapRound
        
        self.layer.addSublayer(circleLayer)
        
        startRotatingCircle()
    }
    
    private func startRotatingCircle() {
        let animationForStrokeEnd = CABasicAnimation(keyPath: "strokeEnd")
        animationForStrokeEnd.fromValue = 0.0
        animationForStrokeEnd.toValue = 1.0
        animationForStrokeEnd.duration = 0.4
        animationForStrokeEnd.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        
        let animationForStrokeStart = CABasicAnimation(keyPath: "strokeStart")
        animationForStrokeStart.fromValue = 0.0
        animationForStrokeStart.toValue = 1.0
        animationForStrokeStart.duration = 0.4
        animationForStrokeStart.beginTime = 0.5
        animationForStrokeStart.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
        
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [animationForStrokeEnd, animationForStrokeStart]
        animationGroup.duration = 0.9
        animationGroup.repeatCount = MAXFLOAT
        
        circleLayer.addAnimation(animationGroup, forKey: nil)
    }
}
