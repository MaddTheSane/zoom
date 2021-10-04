//
//  Misc.swift
//  Zoom
//
//  Created by C.W. Betts on 10/4/21.
//

import Foundation

func fileExists(_ url: URL, needsToBeDirectory: Bool) -> Bool {
	if !((try? url.checkResourceIsReachable()) ?? false) {
		return false
	}
	
	do {
		let resVals = try url.resourceValues(forKeys: [.isDirectoryKey])
		if (resVals.isDirectory!) != needsToBeDirectory {
			return false
		}
		return true
	} catch {
		return false
	}
}
