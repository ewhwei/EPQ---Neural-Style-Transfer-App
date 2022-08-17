//
//  ViewController.swift
//  Stylized
//
//  Created by Edward Wei on 11/7/2022.
//

// All AI stuff
// Saving
// Turn all cells grey once enough has been picked + change text

import UIKit
import Photos
import PhotosUI

class ViewController: UIViewController, PHPickerViewControllerDelegate {
    
    private var cpuImageTransformNetwork: ImageTransformNetwork?
    
    @IBOutlet weak var ContentCollectionView: UICollectionView!
    @IBOutlet weak var pageView: UIPageControl!
    @IBOutlet weak var saveButton: UIButton!
    
    private var page: Int = 0
    private var alpha: Float = 0.5
    
    var outputImages = [UIImage]()
    var images = [UIImage]()
    private var vcPHPicker: PHPickerViewController?
    @IBOutlet weak var alphaSlider: UISlider!
    @IBOutlet weak var stylizeButton: UIButton!
    
    private var styleImages = [UIImage]()
    @IBOutlet weak var StyleCollectionViewWidget: StyleCollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // PHPicker view on load
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 16
        vcPHPicker = PHPickerViewController(configuration: configuration)
        vcPHPicker!.delegate = self
        present(vcPHPicker!, animated: true)
        
        // Style Collection View configuration
        StyleCollectionViewWidget.dataSource = StyleCollectionViewWidget
        StyleCollectionViewWidget.delegate = StyleCollectionViewWidget
        StyleCollectionViewWidget.allowsMultipleSelection = true
        
        //Slider configuration
        alphaSlider.isContinuous = false
        alphaSlider.isHidden = true
        alpha = alphaSlider.value
        
        // Save button configuration
        saveButton.isHidden = true
        
        // Stylize button configuration
        stylizeButton.isUserInteractionEnabled = false
        stylizeButton.layer.shadowColor = #colorLiteral(red: 1, green: 0.9183266163, blue: 0.7566742301, alpha: 1)
    }
    
    //Return to PHPicker view
    @IBAction func returnNavigationButton(_ sender: UIButton) {
        self.saveButton.isHidden = true
        self.images = []
        present(vcPHPicker!, animated: true)
    }
    
    // Stylize button
    @IBAction func stylizeButtonPressed(_ sender: UIButton) {
        guard self.cpuImageTransformNetwork != nil else {
            sendAlert(text: "Sorry, the model has failed to load.")
            return
        }
        
        guard StyleCollectionView.selectedImages.count != 0 else {
            sendAlert(text: "Please select a style image")
            return
        }
        
        let ylabel1 = StyleCollectionView.selectedImages[0]
        var ylabel2 = "none"
        if StyleCollectionView.selectedImages.count == 2 {
            ylabel2 = StyleCollectionView.selectedImages[1]
        }

        let group = DispatchGroup()
        self.outputImages = []
        for image in self.images {
            group.enter()
            
            let croppedImage = image.cropCenter()!
            cpuImageTransformNetwork?.runStyleTransfer(image: croppedImage, ylabel1: ylabel1, ylabel2: ylabel2, alpha: self.alpha, completion: { result in
                defer {
                    group.leave()
                }
                switch result {
                case .success(let styleTransferResult):
                    self.outputImages.append(styleTransferResult.resultImage)
                    print(self.outputImages)
                case .error(let wrappedError):
                    self.sendAlert(text: "Sorry, \(wrappedError)")
                }
            })
        }
        group.notify(queue: .main) {
            self.saveButton.isHidden = false
            self.images = self.outputImages
            self.ContentCollectionView.reloadData()
        }
    }
    
    
    //Saves images
    @IBAction func saveNavigationButton(_ sender: UIButton) {
        let imageSaver = ImageSaver()
        for image in self.images {
            imageSaver.writeToPhotoAlbum(image: image)
        }
        sendAlert(text: "Save Completed")
    }
    
    @IBAction func alphaSliderChanged(_ sender: UISlider) {
        self.alpha = sender.value
    }
    
    
    //Handles user selected image
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        
        // initialize Model
        if self.cpuImageTransformNetwork == nil {
            ImageTransformNetwork.newCPUStyleTransferer { result in
                switch result {
                case .success(let imageTransformer):
                    self.cpuImageTransformNetwork = imageTransformer
                case .error(let wrappedError):
                    self.sendAlert(text: "Sorry, \(wrappedError)")
                }
            }
        }
        
        let group = DispatchGroup()
        results.forEach { result in
            group.enter()
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] reading, error in
                defer {
                    group.leave()
                }
                guard let image = reading as? UIImage, error == nil else {
                    return
                }
                // If styleimage array not empty send images to model directly
                self?.images.append(image)
            }
        }
        group.notify(queue: .main) {
            self.pageView.numberOfPages = self.images.count
            self.ContentCollectionView.reloadData()
        }
    }
}

// Content View Controller methods
extension ViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "contentCell", for: indexPath) as! ContentCollectionViewCell
        
        cell.contentImageDisplay.image = images[indexPath.row]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let height = ContentCollectionView.frame.height
        let width = ContentCollectionView.frame.width
        
        return CGSize(width: width, height: height-16)
    }
}

// Scroll view updater
extension ViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        pageView.currentPage = Int(scrollView.contentOffset.x) / Int(scrollView.frame.width)
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        pageView.currentPage = Int(scrollView.contentOffset.x) / Int(scrollView.frame.width)
    }
}

// Alert
extension ViewController {
    func sendAlert(text: String) {
        let alert = UIAlertController(title: text, message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
