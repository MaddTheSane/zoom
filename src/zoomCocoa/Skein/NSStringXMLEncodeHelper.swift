//
//  NSStringXMLEncodeHelper.swift
//  ZoomView
//
//  Created by C.W. Betts on 10/5/21.
//

import Foundation

extension String {
	func byEscapingXMLCharacters() -> String {
		let charArray = self.map { theChar -> String? in
			switch theChar {
			case "\n":
				return "\n"
				
			case "&":
				return "&amp;"
				
			case "<":
				return "&lt;"
				
			case ">":
				return "&gt;"
				
			case "\"":
				return "&quot;"
				
			case "'":
				return "&apos;"
				
			case "\0" ..< "\u{20}":
				// Ignore (expat can't parse these)
				return nil
				
			default:
				return String(theChar)
			}
		}.compactMap({$0})
		
		return charArray.joined()
	}
}
