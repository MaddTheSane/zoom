//
//  FadeView.swift
//  Zoom
//
//  Created by C.W. Betts on 10/2/21.
//

import Cocoa

private let fade = NSImage(named: "top-shading")!

class FadeView: NSView {
	
	override func draw(_ dirtyRect: NSRect) {
		fade.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
	}
}
