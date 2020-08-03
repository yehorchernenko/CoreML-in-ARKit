//
//  BubbleNode.swift
//  CoreML-in-ARKit
//
//  Created by Yehor Chernenko on 01.08.2020.
//  Copyright © 2020 Yehor Chernenko. All rights reserved.
//

import SceneKit

class BubbleNode: SCNNode {
    static let name = String(describing: BubbleNode.self)
    
    let bubbleDepth: CGFloat = 0.1
    let hiddenGeometry = SCNSphere(radius: 0.15)
    
    init(text: String) {
        super.init()
        
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        
        // BUBBLE-TEXT
        let bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))
        let font = UIFont(name: "Futura", size: 0.15)
        bubble.font = font
        bubble.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        bubble.firstMaterial?.diffuse.contents = UIColor.orange
        bubble.firstMaterial?.specular.contents = UIColor.white
        bubble.firstMaterial?.isDoubleSided = true
        // bubble.flatness // setting this too low can cause crashes.
        bubble.chamferRadius = CGFloat(bubbleDepth)
        
        // BUBBLE NODE
        let (minBound, maxBound) = bubble.boundingBox
        let bubbleNode = SCNNode(geometry: bubble)
        // Centre Node - to Centre-Bottom point
        bubbleNode.pivot = SCNMatrix4MakeTranslation((maxBound.x - minBound.x) / 2,
                                                     minBound.y,
                                                     Float(bubbleDepth) / 2)
        // Reduce default text size
        bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
        // CENTRE POINT NODE
        let sphere = SCNSphere(radius: 0.005)
        sphere.firstMaterial?.diffuse.contents = UIColor.cyan
        let sphereNode = SCNNode(geometry: sphere)
        
        let searchNode = SCNNode(geometry: hiddenGeometry)
        searchNode.name = Self.name
        searchNode.eulerAngles.x = -90
        searchNode.geometry?.materials.first?.transparency = 0
        
        // BUBBLE PARENT NODE
        addChildNode(bubbleNode)
        addChildNode(sphereNode)
        addChildNode(searchNode)
        bubbleNode.constraints = [billboardConstraint]
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
