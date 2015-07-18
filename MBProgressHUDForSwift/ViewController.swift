//
//  ViewController.swift
//  MBProgressHUDForSwift
//
//  Created by hzs on 15/7/14.
//  Copyright (c) 2015年 powfulhong. All rights reserved.
//

import UIKit

class ViewController: UIViewController, MBProgressHUDDelegate {
    
    var HUD: MBProgressHUD?
    var expectedLength: Int64 = 0
    var currentLength: Int64 = 0
    
    @IBOutlet var buttons: [UIButton]!

    // MARK: - Lifecycle methods
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
//        let content: UIView = self.view.subviews.first as! UIView
        (buttons as NSArray).setValue(10.0, forKeyPath: "layer.cornerRadius")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func showSimple(sender: UIButton) {
        // The hud will dispable all input on the view (use the higest view possible in the view hierarchy)
        HUD = MBProgressHUD(view: self.navigationController!.view)
        self.navigationController!.view.addSubview(HUD!)
        
        // Register for HUD callbacks so we can remove it from the window at the right time
        HUD!.delegate = self
        
        // Show the HUD while the provide method  executes in a new thread
        HUD!.showWhileExecuting(Selector("myTask"), onTarget: self, withObject: nil, animated: true)
    }

    @IBAction func showWithLabel(sender: UIButton) {
        HUD = MBProgressHUD(view: self.navigationController!.view)
        self.navigationController!.view.addSubview(HUD!)
        
        HUD!.delegate = self
        HUD!.labelText = "Loading"
        
        HUD!.showWhileExecuting("myTask", onTarget: self, withObject: nil, animated: true)
    }
    
    @IBAction func showWithDetailsLabel(sender: UIButton) {
        HUD = MBProgressHUD(view: self.navigationController!.view)
        self.navigationController!.view.addSubview(HUD!)
        
        HUD!.delegate = self
        HUD!.labelText = "Loading"
        HUD!.detailsLabelText = "updating data"
        HUD!.square = true
        
        HUD!.showWhileExecuting("myTask", onTarget: self, withObject: nil, animated: true)
    }
    
    @IBAction func showWithLabelDeterminate(sender: UIButton) {
        HUD = MBProgressHUD(view: self.navigationController!.view)
        self.navigationController!.view.addSubview(HUD!)
        
        // Set determinate mode
        HUD!.mode = MBProgressHUDMode.Determinate
        
        HUD!.delegate = self
        HUD!.labelText = "Loading"
        
        // myProgressTask uses the HUD instance to update progress
        HUD!.showWhileExecuting("myProgressTask", onTarget: self, withObject: nil, animated: true)
    }
    
    @IBAction func showWithLabelAnnularDeterminate(sender: UIButton) {
        HUD = MBProgressHUD(view: self.navigationController!.view)
        self.navigationController!.view.addSubview(HUD!)
        
        HUD!.mode = MBProgressHUDMode.AnnularDeterminate
        
        HUD!.delegate = self
        HUD!.labelText = "Loading"
        
        // myProgressTask uses the HUD instance to update progress
        HUD!.showWhileExecuting("myProgressTask", onTarget: self, withObject: nil, animated: true)
    }
    
    @IBAction func showWithLabelDeterminateHorizontalBar(sender: UIButton) {
        HUD = MBProgressHUD(view: self.navigationController!.view)
        self.navigationController!.view.addSubview(HUD!)
        
        // Set determinate bar mode
        HUD!.mode = .DeterminateHorizontalBar;
        
        HUD!.delegate = self;
        
        // myProgressTask uses the HUD instance to update progress
        HUD!.showWhileExecuting("myProgressTask", onTarget: self, withObject: nil, animated: true)
    }
    
    @IBAction func showWithCustomView(sender: UIButton) {
        HUD = MBProgressHUD(view: self.navigationController!.view)
        self.navigationController!.view.addSubview(HUD!)
        
        // The sample image is based on the work by http://www.pixelpressicons.com, http://creativecommons.org/licenses/by/2.5/ca/
        // Make the customViews 37 by 37 pixels for best results (those are the bounds of the build-in progress indicators)
        HUD!.customView = UIImageView(image: UIImage(named: "37x-Checkmark.png"))
        
        // Set custom view mode
        HUD!.mode = .CustomView;
        
        HUD!.delegate = self;
        HUD!.labelText = "Completed";
        
        HUD!.show(true)
        HUD!.hide(true, afterDelay:3)
    }
    
    @IBAction func showWithLabelMixed(sender: UIButton) {
        HUD = MBProgressHUD(view: self.navigationController!.view)
        self.navigationController!.view.addSubview(HUD!)
        
        HUD!.delegate = self
        HUD!.labelText = "Connecting"
        HUD!.minSize = CGSizeMake(135.0, 135.0)
        HUD!.showWhileExecuting("myMixedTask", onTarget: self, withObject: nil, animated: true)
    }
    
    @IBAction func showUsingBlocks(sender: UIButton) {
        let hud: MBProgressHUD = MBProgressHUD(view: self.navigationController!.view)
        self.navigationController!.view.addSubview(hud)
        
        hud.labelText = "With a block";
        
        hud.showAnimated(true, whileExecutingBlock: { () -> Void in
            self.myTask()
        }) { () -> Void in
            hud.removeFromSuperview()
        }
    }
    
    @IBAction func showOnWindow(sender: UIButton) {
        HUD = MBProgressHUD(view: self.view.window!)
        self.view.window!.addSubview(HUD!)
        
        HUD!.delegate = self
        HUD!.labelText = "Loading"
        
        HUD!.showWhileExecuting("myTask", onTarget: self, withObject: nil, animated: true)
    }
    
    @IBAction func showURL(sender: UIButton) {
        let URL: NSURL? = NSURL(string: "http://a1408.g.akamai.net/5/1408/1388/2005110403/1a1a1ad948be278cff2d96046ad90768d848b41947aa1986/sample_iPod.m4v.zip")
        let request: NSURLRequest = NSURLRequest(URL: URL!)
        
        let connection: NSURLConnection? = NSURLConnection(request: request, delegate: self)
        connection!.start()
        
        HUD = MBProgressHUD.showHUDAddedTo(self.navigationController!.view, animated: true)
        HUD!.delegate = self
    }
    
    @IBAction func showWithGradient(sender: UIButton) {
        HUD = MBProgressHUD(view: self.navigationController!.view)
        self.navigationController!.view.addSubview(HUD!)
        
        HUD!.dimBackground = true
        
        // Regiser for HUD callbacks so we can remove it from the window at the right time
        HUD!.delegate = self;
        HUD!.showWhileExecuting("myTask", onTarget: self, withObject: nil, animated: true)
    }
    
    @IBAction func showTextOnly(sender: UIButton) {
        let hud: MBProgressHUD = MBProgressHUD.showHUDAddedTo(self.navigationController!.view, animated: true)
        
        // Configure for text only and offset down
        hud.mode = .Text
        hud.labelText = "Some message..."
        hud.margin = 10.0
        hud.removeFromSuperViewOnHide = true
        
        hud.hide(true, afterDelay: 3)
    }
    
    @IBAction func showWithColor(sender: UIButton) {
        HUD = MBProgressHUD(view: self.navigationController!.view)
        self.navigationController!.view.addSubview(HUD!)
        
        // Set the hud to display with a color
        HUD!.color = UIColor(red: 0.23, green: 0.50, blue: 0.82, alpha: 0.90)
        HUD!.delegate = self;
        
        HUD!.showWhileExecuting("myTask", onTarget: self, withObject: nil, animated: true)
    }
    
    // MARK: - Execution code
    func myTask() {
        // Do something useful in here instead of sleeping...
        sleep(3)
    }
    
    func myProgressTask() {
        // This just incresses the progress indicator in a loop
        var progress: Float = 0.0
        while progress < 1.0 {
            progress += 0.01
            HUD!.progress = progress
            usleep(50000)
        }
    }
    
    func myMixedTask() {
        // Indeterminate mode
        sleep(2)
        // Switch to determinate mode
        HUD!.mode = .Determinate
        HUD!.labelText = "Progress"
        var progress: Float = 0.0
        while progress < 1.0 {
            progress += 0.01
            HUD!.progress = progress
            usleep(50000)
        }
        // Back to indeterminate mode
        HUD!.mode = .Indeterminate
        HUD!.labelText = "Cleaning up"
        sleep(2)
        // UIImageView is a UIKit class, we have to initialize it on the main thread
        var imageView: UIImageView?;
        dispatch_sync(dispatch_get_main_queue()) {
            let image: UIImage? = UIImage(named: "37x-Checkmark.png")
            imageView = UIImageView(image: image)
        }
        HUD!.customView = imageView
        HUD!.mode = .CustomView
        HUD!.labelText = "Completed"
        sleep(2)
    }
    
    // MARK: - NSURLConnectionDelegate
    func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        expectedLength = max(response.expectedContentLength, 1)
        currentLength = 0
        HUD!.mode = MBProgressHUDMode.Determinate
    }
    
    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        currentLength += data.length
        HUD!.progress = Float(currentLength) / Float(expectedLength)
    }
    
    func connectionDidFinishLoading(connection: NSURLConnection) {
        HUD!.customView = UIImageView(image: UIImage(named: "37x-Checkmark.png"))
        HUD!.mode = .CustomView
        HUD!.hide(true, afterDelay: 2)
    }
    
    func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        HUD!.hide(true)
    }
    
    // MARK: - MBProgressHUDDelegate
    func hudWasHidden(hud: MBProgressHUD) {
        HUD!.removeFromSuperview()
        HUD = nil
    }
    
}

