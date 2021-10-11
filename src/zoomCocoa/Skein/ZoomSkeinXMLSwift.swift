//
//  ZoomSkeinXML.swift
//  Zoom
//
//  Created by C.W. Betts on 10/10/21.
//

import Foundation

/// Unique ID for this item (we use the pointer as the value, as it's guaranteed unique for a unique node).
private func idFor(_ item: ZoomSkeinItem) -> String {
	return String(format: "node-%p", item)
}

extension ZoomSkein {
	func preparseXMLData(_ data: Data) throws -> [AnyHashable: Any] {
		let parseDel = SkeinXMLParseDelegate()
		try parseDel.parseData(data)
		return [:]
	}
	
	/// Creates an XML representation of the Skein.
	@objc public func xmlData() -> String {
		// Structure summary (note to me: write this up properly later)
		
		// <Skein rootNode="<nodeID>" xmlns="http://www.logicalshift.org.uk/IF/Skein">
		//   <generator>Zoom</generator>
		//   <activeItem nodeId="<nodeID" />
		//   <item nodeId="<nodeID>">
		//     <command/>
		//     <result/>
		//     <annotation/>
		//	   <commentary/>
		//     <played>YES/NO</played>
		//     <changed>YES/NO</changed>
		//     <temporary score="score">YES/NO</temporary>
		//     <children>
		//       <child nodeId="<nodeID>"/>
		//     </children>
		//   </item>
		// </Skein>
		//
		// nodeIDs are string uniquely identifying a node: any format
		// A node must not be a child of more than one item
		// All item fields are optional.
		// Root item usually has the command '- start -'

		var result = ""
		result +=
#"""
<Skein rootNode="\#(idFor(rootItem))" xmlns="http://www.logicalshift.org.uk/IF/Skein">
   <generator>Zoom</generator>
   <activeNode nodeId="\#(idFor(activeItem))"/>
"""#
		
		var itemStack = [rootItem]
		
		while itemStack.count > 0 {
			// Pop from the stack
			let node = itemStack.removeLast()

			// Push any children of this node
			itemStack.append(contentsOf: node.children)
			
			// Generate the XML for this node
			result += #"  <item nodeId="\#(idFor(node))">\n"#

			if let command = node.command?.byEscapingXMLCharacters() {
				result += #"    <command xml:space="preserve">\#(command)</command>\n"#
			}
			if let result2 = node.result?.byEscapingXMLCharacters() {
				result += #"    <result xml:space="preserve">\#(result2)</result>\n"#
			}
			if let annotation = node.annotation?.byEscapingXMLCharacters() {
				result += #"    <annotation xml:space="preserve">\#(annotation)</annotation>\n"#
			}
			if let commentary = node.commentary?.byEscapingXMLCharacters() {
				result += #"    <commentary xml:space="preserve">\#(commentary)</commentary>\n"#
			}

			result += "    <played>\(node.played ? "YES" : "NO")</played>\n"
			result += "    <changed>\(node.changed ? "YES" : "NO")</changed>\n"
			result += #"    <temporary score="\#(node.temporaryScore)">\#(node.isTemporary ? "YES" : "NO")</temporary>\n"#
			
			if node.children.count > 0 {
				result += "    <children>\n"
				
				for childNode in node.children {
					result += #"      <child nodeId="\#(idFor(childNode))"/>\n"#
				}
				
				result += "    </children>\n"
			}
			
			result += "  </item>\n"
		}
		// Write footer
		result += "</Skein>\n"
		
		return result
	}
}

private let xmlAttributes = "xmlAttributes"
private let xmlName = "xmlName"
private let xmlChildren = "xmlChildren"
private let xmlType = "xmlType"
private let xmlChars = "xmlChars"

private let xmlElement = "xmlElement"
private let xmlCharData = "xmlCharData"


private class SkeinXMLParseDelegate: NSObject, XMLParserDelegate {
	
	func parseData(_ data: Data) throws {
		let parser = XMLParser()
		parser.delegate = self
		
		if !parser.parse() {
			if let err = parser.parserError {
				throw err
			}
		}
	}
}
