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
		NSColor(patternImage: fade).set()
		NSGraphicsContext.current?.patternPhase = convert(.zero, to: nil)
		dirtyRect.fill()
	}
}
