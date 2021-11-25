//
//  ZoomSkeinXML.swift
//  Zoom
//
//  Created by C.W. Betts on 10/10/21.
//

import Foundation

@discardableResult
private func addAttribute(_ element: XMLElement, name attributeName: String, value: String) -> XMLNode {
	let attributeNode = XMLNode(kind: .attribute, options: .nodePrettyPrint)
	attributeNode.name = attributeName
	attributeNode.stringValue = value
	element.addAttribute(attributeNode)
	
	return attributeNode
}

private func elementWithName(_ elementName: String, attributeName: String, attributeValue: String) -> XMLElement {
	let root = XMLElement(kind: .element, options: .nodePrettyPrint)
	root.name = elementName
	addAttribute(root, name: attributeName, value: attributeValue)
	
	return root
}

private func elementWithName(_ elementName: String, value: String, preserveWhitespace: Bool) -> XMLElement {
	var options: XMLNode.Options = .nodePrettyPrint
	if preserveWhitespace {
		options.formUnion(.nodePreserveWhitespace)
	}
	let root = XMLElement(kind: .element, options: options)
	if preserveWhitespace {
		addAttribute(root, name: "xml:space", value: "preserve")
	}
	root.name = elementName
	root.stringValue = value
	
	return root
}

extension ZoomSkein {
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

		let root = elementWithName("Skein", attributeName: "rootNode", attributeValue: rootItem.nodeIdentifier.uuidString)
		do {
			let nameNode = XMLNode(kind: .namespace, options: .nodePrettyPrint)
			nameNode.name = ""
			nameNode.stringValue = "http://www.logicalshift.org.uk/IF/Skein"
			root.addNamespace(nameNode)
		}
		let xmlDoc = XMLDocument(kind: .document, options: [.documentTidyXML, .nodePrettyPrint])
		xmlDoc.version = "1.0"
		xmlDoc.characterEncoding = "UTF-8"
		xmlDoc.setRootElement(root)
		
		root.addChild(elementWithName("generator", value: "Zoom", preserveWhitespace: false))
		
		// Write items
		var itemStack = [rootItem]
		
		while itemStack.count > 0 {
			// Pop from the stack
			let node = itemStack.removeLast()

			// Push any children of this node
			itemStack.append(contentsOf: node.children)
			
			// Generate the XML for this node
			let item = elementWithName("item", attributeName: "nodeId", attributeValue: node.nodeIdentifier.uuidString)
			
			if let command = node.command {
				item.addChild(elementWithName("command", value: command, preserveWhitespace: true))
			}
			if let result2 = node.result {
				item.addChild(elementWithName("result", value: result2, preserveWhitespace: true))
			}
			if let annotation = node.annotation {
				item.addChild(elementWithName("annotation", value: annotation, preserveWhitespace: true))
			}
			if let commentary = node.commentary {
				item.addChild(elementWithName("commentary", value: commentary, preserveWhitespace: true))
			}
			item.addChild(elementWithName("played", value: node.played ? "YES" : "NO", preserveWhitespace: false))
			item.addChild(elementWithName("changed", value: node.changed ? "YES" : "NO", preserveWhitespace: false))
			
			do {
				let score = elementWithName("temporary", value: node.isTemporary ? "YES" : "NO", preserveWhitespace: false)
				addAttribute(score, name: "score", value: String(node.temporaryScore))
				item.addChild(score)
			}
			
			root.addChild(item)
			
			if node.children.count > 0 {
				let children = elementWithName("children", value: "", preserveWhitespace: false)
				item.addChild(children)

				for childNode in node.children {
					children.addChild(elementWithName("child", attributeName: "nodeId", attributeValue: childNode.nodeIdentifier.uuidString))
				}
			}
		}
		
		return xmlDoc.xmlString(options: [.nodePrettyPrint, .nodeCompactEmptyElement])
	}
}
