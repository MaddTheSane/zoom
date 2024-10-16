//
//  ZoomLeopard.swift
//  Zoom
//
//  Created by C.W. Betts on 11/13/22.
//

import Cocoa
import QuartzCore

///
/// Implementation of the ZoomLeopard protocol
///
class ZoomLeopard: NSObject, ZoomLeopardProtocol, CAAnimationDelegate {
	
	private var willFinish = [(animation: CAAnimation, callback: () -> Void)]()
	
	func prepareToAnimate(_ view: NSView, in layer: CALayer?) {
		for subview in view.subviews {
			prepareToAnimate(subview, in: nil)
		}
		
		if view.wantsLayer == false {
			view.wantsLayer = true
		}
		
		if view.layer == nil, let layer {
			view.layer = layer
		}
		
		view.layer?.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
	}
	
	func prepareToAnimate(_ view: NSView) {
		let viewLayer = CALayer()
		viewLayer.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
		
		prepareToAnimate(view, in: viewLayer)
	}
	
	func pop(_ view: NSView, duration seconds: TimeInterval, finished: (()->Void)?) {
		// Set up the layers for this view
		prepareToAnimate(view)
		
		// Create a pop-up animation
		let popAnimation = CABasicAnimation()
		
		let startScaling = CATransform3DScale(CATransform3DIdentity, 0.2, 0.2, 0.2)
		let finalScaling = CATransform3DIdentity
		let popScaling   = CATransform3DScale(CATransform3DIdentity, 1.1, 1.1, 1.1)

		popAnimation.keyPath		= "transform"
		popAnimation.fromValue		= NSValue(caTransform3D: startScaling)
		popAnimation.toValue		= NSValue(caTransform3D: popScaling)
		popAnimation.duration		= seconds * 0.8
		popAnimation.beginTime		= CACurrentMediaTime()
		popAnimation.repeatCount	= 1
		popAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
		
		let popBackAnimation = CABasicAnimation()
		
		popBackAnimation.keyPath		= "transform"
		popBackAnimation.fromValue		= NSValue(caTransform3D: popScaling)
		popBackAnimation.toValue		= NSValue(caTransform3D: finalScaling)
		popBackAnimation.duration		= seconds * 0.2
		popBackAnimation.beginTime		= CACurrentMediaTime() + seconds * 0.8
		popBackAnimation.repeatCount	= 1;
		popBackAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

		// Create a fade-in animation
		let fadeAnimation = CABasicAnimation()
		
		fadeAnimation.keyPath		= "opacity"
		fadeAnimation.fromValue		= 0.0 as NSNumber
		fadeAnimation.toValue		= 1.0 as NSNumber
		fadeAnimation.repeatCount	= 1;
		fadeAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
		fadeAnimation.duration		= seconds * 0.5
		fadeAnimation.fillMode		= .both
		
		popBackAnimation.delegate = self;

		
		// Animate the view's layer
		view.layer?.opacity = 1
		view.layer?.removeAllAnimations()
		view.layer?.add(popAnimation, forKey: "PopView")
		view.layer?.add(popBackAnimation, forKey: "PopBackView")
		view.layer?.add(fadeAnimation, forKey: "FadeView")
		
		// Set up the finished event handler
		if let finished {
			willFinish.append((view.layer!.animation(forKey: "PopBackView")!, finished))
		}
	}

	func popOutView(_ view: NSView, duration seconds: TimeInterval, finished: (()->Void)?) {
		// Set up the layers for this view
		prepareToAnimate(view)
		
		// Create a pop-up animation
		let popAnimation = CABasicAnimation()
		
		let startScaling = CATransform3DScale(CATransform3DIdentity, 0.2, 0.2, 0.2)
		let finalScaling = CATransform3DIdentity
		let popScaling   = CATransform3DScale(CATransform3DIdentity, 1.1, 1.1, 1.1)
		
		popAnimation.keyPath		= "transform";
		popAnimation.fromValue		= NSValue(caTransform3D: finalScaling)
		popAnimation.toValue		= NSValue(caTransform3D: popScaling)
		popAnimation.duration		= seconds * 0.2
		popAnimation.beginTime		= CACurrentMediaTime()
		popAnimation.repeatCount	= 1
		popAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
		popAnimation.fillMode		= .both
		
		let popBackAnimation = CABasicAnimation()
		
		popBackAnimation.keyPath		= "transform";
		popBackAnimation.fromValue		= NSValue(caTransform3D: popScaling)
		popBackAnimation.toValue		= NSValue(caTransform3D: startScaling)
		popBackAnimation.duration		= seconds * 0.8
		popBackAnimation.beginTime		= CACurrentMediaTime() + seconds * 0.2
		popBackAnimation.repeatCount	= 1
		popBackAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
		popBackAnimation.fillMode		= .both
		
		// Create a fade-in animation
		let fadeAnimation = CABasicAnimation()
		
		fadeAnimation.keyPath		= "opacity";
		fadeAnimation.fromValue		= 1.0 as NSNumber;
		fadeAnimation.toValue		= 0.0 as NSNumber
		fadeAnimation.repeatCount	= 1
		fadeAnimation.timingFunction = CAMediaTimingFunction(name:  .easeInEaseOut)
		fadeAnimation.duration		= seconds
		fadeAnimation.fillMode		= .both

		fadeAnimation.delegate = self

		// Animate the view's layer
		view.layer?.opacity = 0
		view.layer?.removeAllAnimations()
		view.layer?.add(popAnimation, forKey: "PopView")
		view.layer?.add(popBackAnimation, forKey: "PopBackView")
		view.layer?.add(fadeAnimation, forKey: "FadeView")
		
		// Set up the finished event handler
		if let finished {
			willFinish.append((view.layer!.animation(forKey: "FadeView")!, finished))
		}
	}
	
	func clearLayers(for view: NSView) {
		if view.wantsLayer {
			view.wantsLayer = false
		}
		
		for subview in view.subviews {
			// Scrollers on modern macOS systems are expected to be layered.
			// Let's respect that, okay.
			if subview.isKind(of: NSScroller.self) {
				continue
			}
			clearLayers(for: subview)
		}
	}
	
	func removeLayer(for view: NSView) {
		view.wantsLayer = false
	}
	
	// MARK: - Animation delegate functions
	
	func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
		var index = willFinish.firstIndex { (anim1, _) in
			return anim1 === anim
		}
		
		while let index2 = index {
			let invocation = willFinish.remove(at: index2)
			invocation.callback()
			
			index = willFinish.firstIndex { (anim1, _) in
				return anim1 === anim
			}
		}
	}
}
