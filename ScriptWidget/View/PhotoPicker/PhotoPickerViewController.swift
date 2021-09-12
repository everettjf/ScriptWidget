//
//  PhotoPickerViewController.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/11/5.
//

import UIKit

class PhotoPickerViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, CropViewControllerDelegate{
    private var image: UIImage?
    private var croppedRect = CGRect.zero
    private var croppedAngle = 0
    
    private var imageId = ""
    
    @IBOutlet weak var labelImageId: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var constraintImageWidth: NSLayoutConstraint!
    @IBOutlet weak var constraintImageHeight: NSLayoutConstraint!
    
    private var curWidgetSizeType: Int = 0
        
    // public
    public var popAction: (() -> Void)?
    public static let newSaveNotification = Notification.Name("PhotoPickerNewSaveNotification")
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.imageView.layer.cornerRadius = 10
        self.imageView.layer.masksToBounds = true
        
        updateImageName(name: "image\(sharedImageManager.imageCount())")
    }
    
    func updateImageName(name: String) {
        self.imageId = name
        
        self.labelImageId.text = "Image ID: \(self.imageId)"
    }
    
    @IBAction func pickSmallButtonTapped(_ sender: Any) {
        startPick(widgetSizeType: 0)
    }
    @IBAction func pickMediumButtonTapped(_ sender: Any) {
        startPick(widgetSizeType: 1)
    }
    @IBAction func pickLargeButtonTapped(_ sender: Any) {
        startPick(widgetSizeType: 2)
    }
    
    @IBAction func saveImageButtonTapped(_ sender: Any) {
        
        guard let image = imageView.image else { return }
        
        let result = sharedImageManager.saveImage(image: image, imageId: self.imageId, widgetSizeType: self.curWidgetSizeType)
        if !result {
            self.alert("Oops, save image failed, try again")
            return
        }
        
        // notify new save
        NotificationCenter.default.post(name: PhotoPickerViewController.newSaveNotification, object: nil)
        
        self.popAction?()
    }
    
    
    func alert(_ message : String) {
        let dialogMessage = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        let ok = UIAlertAction(title: "OK", style: .default, handler: { (action) -> Void in
            print("Ok button tapped")
        })
        dialogMessage.addAction(ok)
        self.present(dialogMessage, animated: true, completion: nil)
    }
    /*
     0 - Small
     1 - Medium
     2 - Large
     */
    func startPick(widgetSizeType: Int) {
        self.curWidgetSizeType = widgetSizeType
        
        let imageSize = WidgetSizeHelper.size(Int32(self.curWidgetSizeType))
        
        self.constraintImageWidth.constant = imageSize.width
        self.constraintImageHeight.constant = imageSize.height
        
        
        DispatchQueue.main.async {
            self.runPicker()
        }
    }
    
    func runPicker() {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = false
        imagePicker.delegate = self
        self.present(imagePicker, animated: true) {}
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = (info[UIImagePickerController.InfoKey.originalImage] as? UIImage) else { return }
        
        let cropController = CropViewController(croppingStyle: .default, image: image)
        cropController.modalPresentationStyle = .automatic
        cropController.delegate = self
        cropController.title = "Crop"
        cropController.rotateButtonsHidden = true
        cropController.aspectRatioPickerButtonHidden = true
        cropController.rotateClockwiseButtonHidden = true
        cropController.aspectRatioLockEnabled = true
        cropController.resetAspectRatioEnabled = false
        
        switch self.curWidgetSizeType {
        case 0: cropController.aspectRatioPreset = .small
        case 1: cropController.aspectRatioPreset = .medium
        case 2: cropController.aspectRatioPreset = .large
        default: cropController.aspectRatioPreset = .original
        }
    
        cropController.doneButtonTitle = "Done"
        cropController.cancelButtonTitle = "Cancel"
        
        self.image = image
        
        picker.dismiss(animated: true, completion: {
            self.present(cropController, animated: true, completion: nil)
        })
    }
    
    public func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        self.croppedRect = cropRect
        self.croppedAngle = angle
        updateImageViewWithImage(image, fromCropViewController: cropViewController)
    }
    
    public func cropViewController(_ cropViewController: CropViewController, didCropToCircularImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        self.croppedRect = cropRect
        self.croppedAngle = angle
        updateImageViewWithImage(image, fromCropViewController: cropViewController)
    }
    
    public func updateImageViewWithImage(_ image: UIImage, fromCropViewController cropViewController: CropViewController) {
        
        imageView.image = self.resizeImage(image: image, widgetSizeType: self.curWidgetSizeType)
        
        cropViewController.dismiss(animated: true, completion: nil)
        
    }
    
    func resizeImage(image: UIImage, widgetSizeType: Int) -> UIImage {
        
        var targetSize = CGSize(width: 50, height: 100)
        switch widgetSizeType {
        case 0: targetSize = WidgetSizeHelper.small()
        case 1: targetSize = WidgetSizeHelper.medium()
        case 2: targetSize = WidgetSizeHelper.large()
        default: break
        }
        
        UIGraphicsBeginImageContext(targetSize);
        image.draw(in: CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return scaledImage!
    }
    
    
    @IBAction func buttonCancelTapped(_ sender: Any) {
        self.popAction?()
    }
    
}
