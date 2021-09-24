//
//  ZoomDownloadView.swift
//  Zoom
//
//  Created by C.W. Betts on 9/24/21.
//

import Cocoa

class ZoomDownloadView : NSView {
	/// The background image
	private let downloadImage = NSImage(named: "IFDB-downloading")!
	/// The download progress indicator
	@objc let progress: NSProgressIndicator
	
	override init(frame: NSRect) {
		// Set up the progress indicator
		progress = NSProgressIndicator(frame: NSRect(x: NSMinX(frame)+37, y: NSMinY(frame) + 24, width: frame.size.width-74, height: 16))
		progress.autoresizingMask = [.width, .maxYMargin]
		progress.usesThreadedAnimation = false
		super.init(frame: frame)
		
		addSubview(progress)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func draw(_ dirtyRect: NSRect) {
		let imageSize = downloadImage.size
		let bounds = self.bounds

		NSColor.clear.set()
		bounds.fill()
		
		var downloadRect = NSRect()
		downloadRect.origin.x = bounds.minX + (bounds.size.width - imageSize.width) / 2
		downloadRect.origin.y = bounds.minY + (bounds.size.height - imageSize.height) / 2
		downloadRect.size = imageSize
		downloadImage.draw(in: downloadRect, from: NSRect(origin: .zero, size: imageSize), operation: .sourceOver, fraction: 10)
	}
	
	override var isOpaque: Bool {
		return false
	}
}
