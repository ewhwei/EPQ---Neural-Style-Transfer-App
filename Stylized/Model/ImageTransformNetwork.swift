//
//  ImageTransformNetwork.swift
//  Stylized
//
//  Created by Edward Wei on 17/7/2022.
//

import UIKit
import TensorFlowLite

class ImageTransformNetwork {
    private var imageTransformInterpreter: Interpreter
    private let tfLiteQueue: DispatchQueue
    
    static func newCPUStyleTransferer(
        completion: @escaping ((Result<ImageTransformNetwork>) -> Void)
      ) -> () {
        return ImageTransformNetwork.newInstance(imageTransformNetwork: "modelFinal15500",
                                           completion: completion)
      }
    
    static func newInstance(imageTransformNetwork: String, completion: @escaping ((Result<ImageTransformNetwork>) -> Void)) {
        
        let tfLiteQueue = DispatchQueue(label:"initialize")
        
        // Create dispatch queue so UI components don't freeze
        tfLiteQueue.async {
            
            // Grab model path
            guard let imageTransformModelPath = Bundle.main.path(
                forResource: imageTransformNetwork, ofType: Constants.modelFileExtension
            ) else {
                completion(.error(InitializationError.invalidModel("The model could not be loaded")))
                return
            }
        
            // Create options for CPU
            var options = Interpreter.Options()
            options.threadCount = ProcessInfo.processInfo.processorCount >= 2 ? 2 : 1
            
            // Create interpreter object
            do {
                let imageTransformInterpreter = try Interpreter(
                    modelPath: imageTransformModelPath,
                    options: options
                )
                
                // Allocate memory
                try imageTransformInterpreter.allocateTensors()
                
                // Return instantiation of this class
                let imageTransformNetwork = ImageTransformNetwork(
                    tfLiteQueue: tfLiteQueue,
                    imageTransformInterpreter: imageTransformInterpreter
                )
                DispatchQueue.main.async {
                    completion(.success(imageTransformNetwork))
                }
            } catch let error {
                DispatchQueue.main.async {
                   completion(.error(InitializationError.internalError(error)))
                 }
                 return
            }
        }
    }
    
    fileprivate init(
        tfLiteQueue: DispatchQueue,
        imageTransformInterpreter: Interpreter
    ) {
        self.imageTransformInterpreter = imageTransformInterpreter
        self.tfLiteQueue = tfLiteQueue
    }
    
    func runStyleTransfer(image: UIImage, ylabel1: String, ylabel2: String, alpha: Float, completion: @escaping((Result<StyleTransferResult>) -> Void)) {
        tfLiteQueue.async {
            var alphaValue = 1-alpha
            let outputTensor: Tensor
            var yArray1 = [Float32](repeating: 0, count: styleImageKey.count)
            var yArray2 = [Float32](repeating: 0, count: styleImageKey.count)
            yArray1[styleImageKey[ylabel1]!] = 1
            if ylabel2 == "none" {
                alphaValue = 1
            } else {
                yArray2[styleImageKey[ylabel2]!] = 1
            }
            let yBuffer1: UnsafeMutableBufferPointer<Float32> = UnsafeMutableBufferPointer(start: &yArray1, count: styleImageKey.count)
            let yBuffer2: UnsafeMutableBufferPointer<Float32> = UnsafeMutableBufferPointer(start: &yArray2, count: styleImageKey.count)
            let alphaBuffer: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(start: &alphaValue, count: 1)

            do {
                guard let inputRGBData = image.scaledData(
                    with: Constants.inputImageSize,
                    isQuantized: false
                ) else {
                    DispatchQueue.main.async {
                        completion(.error(StyleTransferError.invalidImage))
                    }
                    return
                }
                try self.imageTransformInterpreter.copy(inputRGBData, toInputAt: 0)
                try self.imageTransformInterpreter.copy(Data(buffer: yBuffer1), toInputAt: 3)
                try self.imageTransformInterpreter.copy(Data(buffer: yBuffer2), toInputAt: 2)
                try self.imageTransformInterpreter.copy(Data(buffer: alphaBuffer), toInputAt: 1)
                try self.imageTransformInterpreter.invoke()
                outputTensor = try self.imageTransformInterpreter.output(at: 0)
        
            } catch let error {
                DispatchQueue.main.async {
                    completion(.error(StyleTransferError.internalError(error)))
                }
                return
            }
            
            guard let cgImage = self.postprocessImageData(data: outputTensor.data, size: Constants.inputImageSize) else {
                DispatchQueue.main.async {
                    completion(.error(StyleTransferError.resultVisualizationError))
                }
                return
            }
            
            let outputImage = UIImage(cgImage: cgImage)
            
            DispatchQueue.main.async {
                completion(.success(StyleTransferResult(resultImage: outputImage)))
            }
        }
    }
    
    private func postprocessImageData(data: Data, size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        let floats = data.toArray(type: Float32.self)
        
        let bufferCapacity = width * height * 4
        let unsafePointer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferCapacity)
        let unsafeBuffer = UnsafeMutableBufferPointer<UInt8>(start: unsafePointer,
                                                             count: bufferCapacity)
        defer {
          unsafePointer.deallocate()
        }

        for x in 0 ..< width {
          for y in 0 ..< height {
            let floatIndex = (y * width + x) * 3
            let index = (y * width + x) * 4
            let red = UInt8(floats[floatIndex] * 255)
            let green = UInt8(floats[floatIndex + 1] * 255)
            let blue = UInt8(floats[floatIndex + 2] * 255)

            unsafeBuffer[index] = red
            unsafeBuffer[index + 1] = green
            unsafeBuffer[index + 2] = blue
            unsafeBuffer[index + 3] = 0
          }
        }

        let outData = Data(buffer: unsafeBuffer)
        // Construct image from output tensor data
        let alphaInfo = CGImageAlphaInfo.noneSkipLast
        let bitmapInfo = CGBitmapInfo(rawValue: alphaInfo.rawValue)
            .union(.byteOrder32Big)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard
          let imageDataProvider = CGDataProvider(data: outData as CFData),
          let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: MemoryLayout<UInt8>.size * 4 * width,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: imageDataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
          )
          else {
            return nil
        }
        return cgImage
    }
}

struct StyleTransferResult {
  /// The resulting image from the style transfer.
  let resultImage: UIImage
}

enum InitializationError: Error {
  // Invalid TF Lite model
  case invalidModel(String)

  // Invalid label list
  case invalidLabelList(String)

  // TF Lite Internal Error when initializing
  case internalError(Error)
}

/// Define errors that could happen when running style transfer
enum StyleTransferError: Error {
  // Invalid input image
  case invalidImage

  // TF Lite Internal Error when initializing
  case internalError(Error)

  // Invalid input image
  case resultVisualizationError
}

enum Result<T> {
  case success(T)
  case error(Error)
}

let styleImageKey: [String: Int] = ["1.png": 0,
                                    "2.png": 1,
                                    "3.png": 2,
                                    "4.png": 3,
                                    "5.png": 4,
                                    "6.png": 5,
                                    "7.png": 6,
                                    "8.png": 7,
                                    "9.png": 8,
                                    "10.png": 9]

// MARK: - Constants
private enum Constants {
  static let modelFileExtension = "tflite"

  static let inputImageSize = CGSize(width: 256, height: 256)
}
