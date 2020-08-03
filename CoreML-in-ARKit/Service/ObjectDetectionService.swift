//
//  ObjectDetectionService.swift
//  CoreML-in-ARKit
//
//  Created by Yehor Chernenko on 01.08.2020.
//  Copyright © 2020 Yehor Chernenko. All rights reserved.
//

import UIKit
import CoreML
import Vision
import SceneKit

protocol ObjectRecognitionServiceType {
    func detect(on request: ObjectRecognitionService.Request, completion: @escaping (Result<ObjectRecognitionService.Response, Error>) -> Void)
}

class ObjectRecognitionService: ObjectRecognitionServiceType {
    var mlModel = try? VNCoreMLModel(for: YOLOv3Int8LUT().model)
    
    lazy var coreMLRequest: VNCoreMLRequest = {
        guard let model = mlModel else {
            completion?(.failure(RecognitionError.unableToInitializeCoreMLModel))
            fatalError()
        }
        
        return VNCoreMLRequest(model: model,
                               completionHandler: self.coreMlRequestHandler)
    }()
    
    private var completion: ((Result<Response, Error>) -> Void)?
    private var request: Request?
    
    func detect(on request: Request, completion: @escaping (Result<Response, Error>) -> Void) {
        self.completion = completion
        self.request = request
        
        performRecognition(request: coreMLRequest, image: request.pixelBuffer, orientation: .up)
    }
}

private extension ObjectRecognitionService {
    
    func performRecognition(request: VNRequest, image: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image,
                                                        orientation: CGImagePropertyOrientation(rawValue:  UIDevice.current.exifOrientation) ?? .up)
        
        do {
            try imageRequestHandler.perform([request])
        } catch {
            self.completion?(.failure(error))
            return
        }
    }
    
    func coreMlRequestHandler(_ request: VNRequest?, error: Error?) {
        if let error = error {
            completion?(.failure(error))
            return
        }
        
        guard let request = request, let results = request.results as? [VNRecognizedObjectObservation] else {
            completion?(.failure(RecognitionError.resultIsEmpty))
            return
        }
        
        let highConfidenceResult = results
            .first { $0.confidence > 0.8 }
        
        complete(highConfidenceResult)
    }
    
    func complete(_ result: VNRecognizedObjectObservation?) {
        guard let result = result,
            let classification = result.labels.first else {
                completion?(.failure(RecognitionError.lowConfidence))
                return
        }
        
        let response = Response(boundingBox: result.boundingBox,
                                classification: classification.identifier)
        
        DispatchQueue.main.async {
            self.completion?(.success(response))
            self.completion = nil
            self.request = nil
        }
    }
}

enum RecognitionError: Error {
    case unableToInitializeCoreMLModel
    case resultIsEmpty
    case lowConfidence
}

extension ObjectRecognitionService {
    struct Request {
        let pixelBuffer: CVPixelBuffer
    }
    
    struct Response {
        let boundingBox: CGRect
        let classification: String
    }
}
