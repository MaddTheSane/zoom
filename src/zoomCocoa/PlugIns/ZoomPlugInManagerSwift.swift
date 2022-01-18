//
//  ZoomPlugInManagerSwift.swift
//  ZoomPlugIns
//
//  Created by C.W. Betts on 1/18/22.
//

import Foundation
import ZoomPlugIns.ZoomPlugInManager
import ZoomPlugIns.ZoomPlugIn

extension ZoomPlugInManager {
	/// Gets the plugin for the specified URL
	open func plugIn(for fileName: URL) -> ZoomPlugIn.Type? {
		return __plugIn(for: fileName) as? ZoomPlugIn.Type
	}
}
