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

class ObjectDetectionService {
    var mlModel = try! VNCoreMLModel(for: YOLOv3Int8LUT().model)
    
    lazy var coreMLRequest: VNCoreMLRequest = {
        return VNCoreMLRequest(model: mlModel,
                               completionHandler: self.coreMlRequestHandler)
    }()
    
    private var completion: ((Result<Response, Error>) -> Void)?
    
    func detect(on request: Request, completion: @escaping (Result<Response, Error>) -> Void) {
        self.completion = completion
        
        let orientation = CGImagePropertyOrientation(rawValue:  UIDevice.current.exifOrientation) ?? .up
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: request.pixelBuffer,
                                                        orientation: orientation)
        
        do {
            try imageRequestHandler.perform([coreMLRequest])
        } catch {
            self.complete(.failure(error))
            return
        }
    }
}

private extension ObjectDetectionService {
    func coreMlRequestHandler(_ request: VNRequest?, error: Error?) {
        if let error = error {
            complete(.failure(error))
            return
        }
        
        guard let request = request, let results = request.results as? [VNRecognizedObjectObservation] else {
            complete(.failure(RecognitionError.resultIsEmpty))
            return
        }
        
        guard let result = results.first(where: { $0.confidence > 0.8 }),
            let classification = result.labels.first else {
                complete(.failure(RecognitionError.lowConfidence))
                return
        }
        
        let response = Response(boundingBox: result.boundingBox,
                                classification: classification.identifier)
        
        complete(.success(response))
    }
    
    func complete(_ result: Result<Response, Error>) {
        DispatchQueue.main.async {
            self.completion?(result)
            self.completion = nil
        }
    }
}

enum RecognitionError: Error {
    case unableToInitializeCoreMLModel
    case resultIsEmpty
    case lowConfidence
}

extension ObjectDetectionService {
    struct Request {
        let pixelBuffer: CVPixelBuffer
    }
    
    struct Response {
        let boundingBox: CGRect
        let classification: String
    }
}
