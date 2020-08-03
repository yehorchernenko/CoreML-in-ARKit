//
//  ViewController.swift
//  CoreML-in-ARKit
//
//  Created by Yehor Chernenko on 01.08.2020.
//  Copyright © 2020 Yehor Chernenko. All rights reserved.
//

import UIKit
import Vision
import ARKit


class ViewController: UIViewController {
    var objectDetectionService: ObjectRecognitionServiceType = ObjectRecognitionService()
    let throttler = Throttler(minimumDelay: 1, queue: .global(qos: .userInteractive))
    var isLoopShouldContinue = true
    var lastLocation: SCNVector3?

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.scene = SCNScene()
        
        // Enable Default Lighting - makes the 3D text a bit poppier.
        sceneView.autoenablesDefaultLighting = true
        
//        // Debug
//        sceneView.showsStatistics = true
//        sceneView.debugOptions = [.showFeaturePoints]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        stopSession()
    }
    
    private func startSession() {
        guard ARWorldTrackingConfiguration.isSupported else {
            assertionFailure("ARKit is not supported")
            return
        }
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        sceneView.session.run(configuration)
    }
    
    private func stopSession() {
        sceneView.session.pause()
    }
    
    private func loopObjectDetection() {
        throttler.throttle { [weak self] in
            guard let self = self else { return }
            
            if self.isLoopShouldContinue {
                self.performDetection()
            }
            self.loopObjectDetection()
        }
    }
    
    private func performDetection() {
        guard let pixelBuffer = sceneView.session.currentFrame?.capturedImage else { return }
        
        objectDetectionService.detect(on: .init(pixelBuffer: pixelBuffer)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                let rectOfInterest = VNImageRectForNormalizedRect(
                    response.boundingBox,
                    Int(self.sceneView.bounds.width),
                    Int(self.sceneView.bounds.height))
                self.addAnnotation(rectOfInterest: rectOfInterest,
                                   text: response.classification)
            
            case .failure(let error):
                print(error)
            }
        }
    }
    
    private func addAnnotation(rectOfInterest rect: CGRect, text: String) {
        let point = CGPoint(x: rect.midX, y: rect.midY)
        let scnHitTestResults = sceneView.hitTest(point, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
        
        guard !scnHitTestResults.contains(where: { $0.node.name == BubbleNode.name }),
            let arHitTestResult = sceneView.hitTest(point, types: .existingPlane).last,
            let cameraPosition = sceneView.pointOfView?.position else { return }
        
        let position = SCNVector3(arHitTestResult.worldTransform.columns.3.x,
                                  arHitTestResult.worldTransform.columns.3.y,
                                  arHitTestResult.worldTransform.columns.3.z)

        let distance = (position - cameraPosition).length()
        
        guard distance <= 0.35 else { return }
        
        let bubbleNode = BubbleNode(text: text)
        bubbleNode.worldPosition = position
        
        sceneView.prepare([bubbleNode]) { [weak self] success in
            if success {
                self?.sceneView.scene.rootNode.addChildNode(bubbleNode)
            }
        }
    }

    private func onSessionUpdate(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        isLoopShouldContinue = false

        // Update the UI to provide feedback on the state of the AR experience.
        let message: String
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty:
            // No planes detected; provide instructions for this app's AR interactions.
            message = "Move the device around to detect horizontal and vertical surfaces."
            
        case .notAvailable:
            message = "Tracking unavailable."
            
        case .limited(.excessiveMotion):
            message = "Tracking limited - Move the device more slowly."
            
        case .limited(.insufficientFeatures):
            message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
            
        case .limited(.initializing):
            message = "Initializing AR session."
            
        default:
            // No feedback needed when tracking is normal and planes are visible.
            // (Nor when in unreachable limited-tracking states.)
            message = ""
            isLoopShouldContinue = true
            loopObjectDetection()
        }
        
        sessionInfoLabel.text = message
        sessionInfoLabel.isHidden = message.isEmpty
    }
}

extension ViewController: ARSCNViewDelegate {
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        guard let frame = session.currentFrame else { return }
        onSessionUpdate(for: frame, trackingState: camera.trackingState)
    }
    
    // MARK: - ARSessionObserver
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay.
        sessionInfoLabel.text = "Session was interrupted"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required.
        sessionInfoLabel.text = "Session interruption ended"
        startSession()
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        sessionInfoLabel.text = "Session error: \(error.localizedDescription)"
    }
}

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        onSessionUpdate(for: frame, trackingState: frame.camera.trackingState)
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        onSessionUpdate(for: frame, trackingState: frame.camera.trackingState)
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        ///Check speed of movement, if to fast - stops object detection loop
        let transform = SCNMatrix4(frame.camera.transform)
        let orientation = SCNVector3(-transform.m31, -transform.m32, transform.m33)
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        let currentPositionOfCamera = orientation + location
        
        if let lastLocation = lastLocation {
            let speed = (lastLocation - currentPositionOfCamera).length()
            isLoopShouldContinue = speed < 0.0025
            
        }
        lastLocation = currentPositionOfCamera
    }
}
