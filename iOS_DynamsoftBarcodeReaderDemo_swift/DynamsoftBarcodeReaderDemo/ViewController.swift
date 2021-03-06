//
//  ScanViewController.swift
//  DynamsoftBarcodeReaderDemo
//
//  Created by Dynamsoft on 08/07/2018.
//  Copyright © 2018 Dynamsoft. All rights reserved.
//

import UIKit
import AVFoundation

//you can init DynamsoftBarcodeReader with a license or licenseKey
let kLicense = "Put your license here"
let kLicenseKey = "Put your license key here"

class ViewController: UIViewController {
    @IBOutlet var rectLayerImage: UIImageView!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var detectDescLabel: UILabel!
    
    var cameraPreview: UIView?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var dbrManager: DbrManager?
    var isFlashOn:Bool!
    var addOrCut_:Int!
    var line_image:UIImageView!
    var animation_timer:Timer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        UIApplication.shared.isIdleTimerDisabled = true;
        //register notification for UIApplicationDidBecomeActiveNotification
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil);
        
        //init DbrManager with Dynamsoft Barcode Reader mobile license
        let isInitWithLicenseKey = false;//Choose an initialization method
        if(!isInitWithLicenseKey)
        {
            dbrManager = DbrManager(license:kLicense);
        }
        else
        {
            dbrManager = DbrManager(serverURL: "", licenseKey: kLicenseKey);
            dbrManager?.setServerLicenseVerificationCallback(sender: self, callBack: #selector(onVerificationCallBack(isSuccess:error:)));
        }
            
        dbrManager?.setRecognitionCallback(sender: self, callBack: #selector(onReadImageBufferComplete));
        dbrManager?.setVideoSession();
        if(!isInitWithLicenseKey)
        {
            dbrManager?.startVideoSession();
        }
        self.configInterface();
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self);
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        dbrManager?.isPauseFramesComing = false;
        self.turnFlashOn(on: isFlashOn);
        animation_timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(startAnimation), userInfo: nil, repeats: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated);
        self.stopAnimation()
    }

    @objc func controllerWillPopHandler() {
        if(dbrManager != nil)
        {
            dbrManager = nil;
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if(segue.identifier == "showBarcodeTypes"){
            let newBackButton = UIBarButtonItem.init(title: "", style: UIBarButtonItemStyle.plain, target: nil, action: nil);
            self.navigationItem.backBarButtonItem = newBackButton;
            self.navigationController?.navigationBar.tintColor = UIColor.white;
            let destViewController = segue.destination as! BarcodeTypesTableViewController;
            destViewController.mainView = self;
            
            self.turnFlashOn(on: false);
            dbrManager?.isPauseFramesComing = true;
        }
    }
    
    @objc func onVerificationCallBack(isSuccess:NSNumber, error:NSError?)
    {
        if(isSuccess.boolValue)
        {
            self.dbrManager?.startVideoSession();
        }
        else
        {
            var msg:String? = nil;
            if(error != nil)
            {
                msg = error!.userInfo[NSLocalizedDescriptionKey] as? String;
                if(msg == nil)
                {
                    msg = error?.localizedDescription;
                }
            }
            let ac = UIAlertController(title: "Server license verify failed", message: msg,preferredStyle: .alert)
            self.customizeAC(ac:ac);
            let okButton = UIAlertAction(title: "Try again", style: .default, handler: {
                action in
                self.dbrManager?.connectServerAfterInit(serverURL: "", licenseKey: kLicenseKey)
            })
            ac.addAction(okButton)
            let cancelButton = UIAlertAction(title: "Cancel with local License", style: .cancel, handler: {
                action in
                self.dbrManager?.startVideoSession()
            })
            ac.addAction(cancelButton)
            self.present(ac, animated: false, completion: nil)
        }
    }
    
    @objc func onReadImageBufferComplete(readResult:NSArray)
    {
        if(readResult.count == 0 || dbrManager?.isPauseFramesComing == true)
        {
            dbrManager?.isCurrentFrameDecodeFinished = true
            return
        }
        let timeInterval = (dbrManager?.startRecognitionDate?.timeIntervalSinceNow)! * -1
        var msgText:String = ""
        if(readResult.count == 0){
            dbrManager?.isCurrentFrameDecodeFinished = true
            return
        }else{
            for item in readResult
            {
                if (item as! (iTextResult)).barcodeFormat_2.rawValue != 0 {
                    msgText = msgText + String(format:"\nType: %@\nValue: %@\n", (item as! (iTextResult)).barcodeFormatString_2!, (item as! (iTextResult)).barcodeText ?? "noResuslt")
                }else{
                    msgText = msgText + String(format:"\nType: %@\nValue: %@\n", (item as! (iTextResult)).barcodeFormatString!, (item as! (iTextResult)).barcodeText ?? "noResuslt")
                }
            }
            
            let ac = UIAlertController(title: "Result", message: msgText+String(format:"\nInterval: %.03f seconds",timeInterval), preferredStyle: .alert)
            self.customizeAC(ac:ac);
            let okButton = UIAlertAction(title: "OK", style: .default, handler: {
                action in
                self.dbrManager?.isCurrentFrameDecodeFinished = true;
                self.dbrManager?.startVidioStreamDate! = NSDate();
            })
            ac.addAction(okButton)
            self.present(ac, animated: false, completion: nil)
            
        }
    }
    
    @objc func didBecomeActive(notification:NSNotification) {
        if(dbrManager?.isPauseFramesComing == false)
        {
            self.turnFlashOn(on: isFlashOn);
        }
    }
    
    func configInterface()
    {
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false;
        let w = UIScreen.main.bounds.size.width;
        let h = UIScreen.main.bounds.size.height;
        var mainScreenLandscapeBoundary = CGRect.zero;
        mainScreenLandscapeBoundary.size.width = min(w, h);
        mainScreenLandscapeBoundary.size.height = max(w, h);
        rectLayerImage?.frame = mainScreenLandscapeBoundary;
        rectLayerImage?.contentMode = UIViewContentMode.topLeft;
        self.createRectBorderAndAlignControls();
        //init vars and controls
        isFlashOn = false;
        flashButton.layer.zPosition = 1;
        detectDescLabel.layer.zPosition = 1;
        flashButton.setTitle(" Flash off", for: UIControlState.normal);
        //show vedio capture
        let captureSession = dbrManager?.getVideoSession();
        if(captureSession == nil)
        {
            return;
        }
        previewLayer = AVCaptureVideoPreviewLayer(session:captureSession!);
        previewLayer!.videoGravity = AVLayerVideoGravity.resizeAspectFill;
        previewLayer!.frame = mainScreenLandscapeBoundary;
        cameraPreview = UIView();
        cameraPreview!.layer.addSublayer(previewLayer!);
        self.view.insertSubview(cameraPreview!, at: 0);
        //scan line
        line_image = UIImageView(image: UIImage(named: "line.png"))
        self.view.addSubview(line_image)
        line_image.frame = CGRect(x: rectLayerImage.bounds.size.width*0.1, y: rectLayerImage.bounds.size.height*0.275, width: rectLayerImage.bounds.size.width*0.8, height: 5)
    }
    
    func createRectBorderAndAlignControls()
    {
        let width = rectLayerImage.bounds.size.width;
        let height = rectLayerImage.bounds.size.height;
        let widthMargin = width * 0.1;
        let heightMargin = (height - width + 2 * widthMargin) / 2;
        UIGraphicsBeginImageContext(self.rectLayerImage.bounds.size);
        let ctx = UIGraphicsGetCurrentContext();
        //1. draw gray rect
        UIColor.black.setFill();
        ctx!.fill(CGRect(x: 0, y: 0, width: widthMargin, height: height))
        ctx!.fill(CGRect(x: 0, y: 0, width: width, height: heightMargin))
        ctx!.fill(CGRect(x: width - widthMargin, y: 0, width: widthMargin, height: height))
        ctx!.fill(CGRect(x: 0, y: height - heightMargin, width: width, height: heightMargin))
        //2. draw red line
        var points = [CGPoint](repeating:CGPoint.zero, count: 2);
        //3. draw white rect
        UIColor.white.setStroke();
        ctx!.setLineWidth(1.0);
        // draw left side;
        points[0] = CGPoint(x:widthMargin,y:heightMargin);
        points[1] = CGPoint(x:widthMargin,y:height - heightMargin);
        ctx!.strokeLineSegments(between: points);
        // draw right side
        points[0] = CGPoint(x:width - widthMargin,y:heightMargin);
        points[1] = CGPoint(x:width - widthMargin,y:height - heightMargin);
        ctx!.strokeLineSegments(between: points);
        // draw top side
        points[0] = CGPoint(x:widthMargin,y:heightMargin);
        points[1] = CGPoint(x:width - widthMargin,y:heightMargin);
        ctx!.strokeLineSegments(between: points);
        // draw bottom side
        points[0] = CGPoint(x:widthMargin,y:height - heightMargin);
        points[1] = CGPoint(x:width - widthMargin,y:height - heightMargin);
        ctx!.strokeLineSegments(between: points);
        //4. draw orange corners
        UIColor.orange.setStroke();
        ctx!.setLineWidth(2.0);
        // draw left up corner
        points[0] = CGPoint(x:widthMargin - 2,y:heightMargin - 2);
        points[1] = CGPoint(x:widthMargin + 18,y:heightMargin - 2);
        ctx!.strokeLineSegments(between: points);
        points[0] = CGPoint(x:widthMargin - 2,y:heightMargin - 2);
        points[1] = CGPoint(x:widthMargin - 2,y:heightMargin + 18);
        ctx!.strokeLineSegments(between: points);
        // draw left bottom corner
        points[0] = CGPoint(x:widthMargin - 2,y:height - heightMargin + 2);
        points[1] = CGPoint(x:widthMargin + 18,y:height - heightMargin + 2);
        ctx!.strokeLineSegments(between: points);
        points[0] = CGPoint(x:widthMargin - 2,y:height - heightMargin + 2);
        points[1] = CGPoint(x:widthMargin - 2,y:height - heightMargin - 18);
        ctx!.strokeLineSegments(between: points);
        // draw right up corner
        points[0] = CGPoint(x:width - widthMargin + 2,y:heightMargin - 2);
        points[1] = CGPoint(x:width - widthMargin - 18,y:heightMargin - 2);
        ctx!.strokeLineSegments(between: points);
        points[0] = CGPoint(x:width - widthMargin + 2,y:heightMargin - 2);
        points[1] = CGPoint(x:width - widthMargin + 2,y:heightMargin + 18);
        ctx!.strokeLineSegments(between: points);
        // draw right bottom corner
        points[0] = CGPoint(x:width - widthMargin + 2,y:height - heightMargin + 2);
        points[1] = CGPoint(x:width - widthMargin - 18,y:height - heightMargin + 2);
        ctx!.strokeLineSegments(between: points);
        points[0] = CGPoint(x:width - widthMargin + 2,y:height - heightMargin + 2);
        points[1] = CGPoint(x:width - widthMargin + 2,y:height - heightMargin - 18);
        ctx!.strokeLineSegments(between: points);
        //5. set image
        rectLayerImage.image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        //6. align detectDescLabel horizontal center
        var tempFrame = detectDescLabel.frame;
        tempFrame.origin.x = (width - detectDescLabel.bounds.size.width) / 2;
        tempFrame.origin.y = heightMargin * 0.6;
        detectDescLabel.frame = tempFrame;
        //7. align flashButton horizontal center
        tempFrame = flashButton.frame;
        tempFrame.origin.x = (width - flashButton.bounds.size.width) / 2;
        tempFrame.origin.y = (heightMargin + (width - widthMargin * 2) + height) * 0.5 - flashButton.bounds.size.height * 0.5;
        flashButton.frame = tempFrame;
        return;
    }
    
    func turnFlashOn(on: Bool){
        do
        {
            let captureDeviceClass = NSClassFromString("AVCaptureDevice");
            if (captureDeviceClass != nil) {
                let device = AVCaptureDevice.default(for: AVMediaType.video);
                if (device != nil && device!.hasTorch && device!.hasFlash){
                    try device!.lockForConfiguration();
                    if (on == true) {
                        device!.torchMode = AVCaptureDevice.TorchMode.on;
                        device!.flashMode = AVCaptureDevice.FlashMode.on;
                        flashButton.setImage(UIImage(named: "flash_on"), for: UIControlState.normal);
                        flashButton.setTitle(" Flash on", for: UIControlState.normal);
                    } else {
                        device?.torchMode = AVCaptureDevice.TorchMode.off;
                        device?.flashMode = AVCaptureDevice.FlashMode.off;
                        flashButton.setImage(UIImage(named: "flash_off"), for: UIControlState.normal);
                        flashButton.setTitle(" Flash off", for: UIControlState.normal);
                    }
                    device?.unlockForConfiguration();
                }
            }
        }
        catch{
            print(error);
        }
    }
    
    @objc func startAnimation(){
        if (self.line_image.frame.origin.y >= self.rectLayerImage.frame.size.height*0.72) {
            self.addOrCut_ = -1
        }
        else if (self.line_image.frame.origin.y <= self.rectLayerImage.frame.size.height*0.275)
        {
            self.addOrCut_ = 1
        }
        self.line_image.frame = CGRect(x: self.line_image.frame.origin.x, y: self.line_image.frame.origin.y + CGFloat(self.addOrCut_), width: self.line_image.frame.size.width , height: self.line_image.frame.size.height)
    }
    
    func stopAnimation(){
        animation_timer.invalidate()
    }
    
    func customizeAC(ac: UIAlertController){
        
        let subView1 = ac.view.subviews[0] as UIView;
        let subView2 = subView1.subviews[0] as UIView;
        let subView3 = subView2.subviews[0] as UIView;
        let subView4 = subView3.subviews[0] as UIView;
        let subView5 = subView4.subviews[0] as UIView;
        
        for i in 0 ..< subView5.subviews.count
        {
            if(subView5.subviews[i].isKind(of: UILabel.self))
            {
                let label = subView5.subviews[i] as! UILabel;
                label.textAlignment = NSTextAlignment.left;
            }
        }
    }
    
    @IBAction func onFlashButtonClick(_ sender: Any) {
        isFlashOn = isFlashOn == true ? false : true;
        self.turnFlashOn(on: isFlashOn);
    }
    
    @IBAction func onAboutInfoClick(_ sender: Any) {
        dbrManager?.isPauseFramesComing = true;
        let ac = UIAlertController(title: "About", message: "\nDynamsoft Barcode Reader Mobile App Demo(Dynamsoft Barcode Reader SDK)\n\n© 2019 Dynamsoft. All rights reserved. \n\nIntegrate Barcode Reader Functionality into Your own Mobile App? \n\nClick 'Overview' button for further info.\n\n",preferredStyle: .alert)
        self.customizeAC(ac:ac);
        let linkAction = UIAlertAction(title: "Overview", style: .default, handler: {
            action in
            let urlString = "http://www.dynamsoft.com/Products/barcode-scanner-sdk-iOS.aspx";
            let url = NSURL(string: urlString );
            if(UIApplication.shared.canOpenURL(url! as URL))
            {
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url! as URL)
                } else {
                    UIApplication.shared.openURL(url! as URL);
                };
            }
            self.dbrManager?.isPauseFramesComing = false;
        })
        ac.addAction(linkAction);
        
        let yesButton = UIAlertAction(title: "OK", style: .default, handler: {
            action in
            self.dbrManager?.isPauseFramesComing = false;
        })
        ac.addAction(yesButton);
        self.present(ac, animated: true, completion: nil)
    }
}
