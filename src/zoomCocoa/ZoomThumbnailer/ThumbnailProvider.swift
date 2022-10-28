//
//  ThumbnailProvider.swift
//  ZoomThumbnailer
//
//  Created by C.W. Betts on 10/20/22.
//

import QuickLookThumbnailing
import ZoomPlugIns.ZoomBabel

class ThumbnailProvider: QLThumbnailProvider {
	override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
		let url = request.fileURL
		// Try to get the image via babel for this file
		guard url.isFileURL else {
			handler(nil, CocoaError(.fileReadUnsupportedScheme, userInfo: [NSURLErrorKey: url]))
			return
		}
		let babel = ZoomBabel(url: url)
		guard let image = babel.coverImage() else {
			handler(nil, QLThumbnailError(.requestInvalid, userInfo: [NSURLErrorKey: url]))
			return
		}
		
		let theMaxImageSize = request.maximumSize
		var newSize = theMaxImageSize

		if image.size.width > theMaxImageSize.width || image.size.height > theMaxImageSize.height {
			if (newSize.width < newSize.height) {
				newSize.height = newSize.width
			} else {
				newSize.width = newSize.height
			}
			
			newSize.height = newSize.width * image.size.height / image.size.width
		}

		let reply = QLThumbnailReply(contextSize: newSize) {
			image.draw(in: NSRect(origin: .zero, size: newSize))
			
			return true
		}
		
		handler(reply, nil)
	}
}
