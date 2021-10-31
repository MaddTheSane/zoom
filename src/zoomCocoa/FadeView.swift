//
//  FadeView.swift
//  Zoom
//
//  Created by C.W. Betts on 10/2/21.
//

import Cocoa

class FadeView: NSView {
	
	override func draw(_ dirtyRect: NSRect) {
		let grad = NSGradient(starting: NSColor.windowBackgroundColor, ending: NSColor.textBackgroundColor)
		grad?.draw(in: bounds, angle: 270)
	}
}
