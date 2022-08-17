//
//  StyleCollectionView.swift
//  Stylized
//
//  Created by Edward Wei on 13/7/2022.
//

import UIKit

class StyleCollectionView: UICollectionView, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet var styleLabel: UILabel! // Can just create IBOutlet by typing it out and adding a label
    @IBOutlet var alphaSlider: UISlider!
    @IBOutlet var saveButton: UIButton!
    @IBOutlet var stylizeButton: UIButton!
    
    let styleImages: [String] = [
        "1.png",
        "2.png",
        "3.png",
        "4.png",
        "5.png",
        "6.png",
//        "7.png",
//        "8.png",
//        "9.png",
//        "10.png",
    ]
    
    static var selectedImages = [String]()
    
    // Adjust size depending StyleCollectionView size which depends on device size
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let height = self.frame.size.height
        let width = self.frame.size.width
        
        return CGSize(width: (width-50)/3, height: (height-50)/3)
    }
    
    // UICollectionViewDelegate required functions
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return styleImages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "styleCell", for: indexPath) as! StyleCollectionViewCell
        cell.styleImageDisplay.image = UIImage(named: styleImages[indexPath.row])
        cell.imageName = styleImages[indexPath.row]
        return cell
    }
    
    // Selection Functions
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return collectionView.indexPathsForSelectedItems!.count <=  1
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if let cell = collectionView.cellForItem(at: indexPath) as? StyleCollectionViewCell {
            if StyleCollectionView.selectedImages.count == 0 {
                cell.tickIcon.image = UIImage(named: "one")
                styleLabel.text = "Select another style to combine"
                stylizeButton.isUserInteractionEnabled = true
                stylizeButton.layer.shadowRadius = 2
                stylizeButton.layer.shadowOpacity = 1.0
            } else if StyleCollectionView.selectedImages.count == 1 {
                cell.tickIcon.image = UIImage(named: "two")
                styleLabel.isHidden = true
                
            }
            cell.styleImageDisplay.alpha = 0.75
            StyleCollectionView.selectedImages.append(cell.imageName!)
        }
        
        if StyleCollectionView.selectedImages.count == 2 {
            alphaSlider.isHidden = false
            for indexPath in collectionView.indexPathsForVisibleItems {
                if let cell = collectionView.cellForItem(at: indexPath) as? StyleCollectionViewCell {
                    cell.styleImageDisplay.alpha = 0.75
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        
        if let cell = collectionView.cellForItem(at: indexPath) as? StyleCollectionViewCell {
            cell.tickIcon.image = nil
            cell.styleImageDisplay.alpha = 1
            StyleCollectionView.selectedImages = StyleCollectionView.selectedImages.filter({$0 != cell.imageName})
        }
        if StyleCollectionView.selectedImages.count == 1 {
            for indexPath in collectionView.indexPathsForVisibleItems {
                if let cell = collectionView.cellForItem(at: indexPath) as? StyleCollectionViewCell {
                    if cell.tickIcon.image == nil {
                        cell.styleImageDisplay.alpha = 1
                    } else {
                        cell.tickIcon.image = UIImage(named: "one")
                    }
                }
            }
        }
        if StyleCollectionView.selectedImages.count == 0 {
            styleLabel.text = "Select a style"
            stylizeButton.isUserInteractionEnabled = false
            stylizeButton.layer.shadowRadius = 0
            stylizeButton.layer.shadowOpacity = 0.0
        } else if StyleCollectionView.selectedImages.count == 1 {
            styleLabel.isHidden = false
            alphaSlider.isHidden = true
        }
    }
}
