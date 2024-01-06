//
//  ZoomCursor.swift
//  ZoomView
//
//  Created by C.W. Betts on 12/23/21.
//

import Cocoa

private let BlinkInterval: TimeInterval = 0.6

@objcMembers public
class ZoomCursor: NSObject {
	private var cursorRectI: NSRect
	var blink: Bool
	
	var cursorPos: NSPoint = .zero
	var lastVisible: Bool = false
	var lastActive: Bool = false
	
	private var flasher: Timer?
	
	public override init() {
		isBlinking = false
		isShown    = true
		isActive   = true
		isFirst    = true
		
		blink      = true
		
		cursorRectI = .zero
		delegate = nil
		flasher = nil
		
		super.init()
		
		lastVisible = self.isVisible
		lastActive = self.activeStyle
	}
	
	// MARK: Drawing
	public func draw() {
		guard isVisible else {
			return
		}
		
		// Cursor colour
		NSColor.controlAccentColor.withAlphaComponent(0.6).set()
		
		if activeStyle {
			NSBezierPath.stroke(cursorRectI)
			NSBezierPath.fill(cursorRectI)
		} else {
			NSBezierPath.stroke(cursorRectI)
		}
	}
	
	@objc(visible) public var isVisible: Bool {
		@objc(isVisible) get {
			return isShown && (!isBlinking || blink)
		}
	}
	
	public class var keyPathsForValuesAffectingVisible: Set<String> {
		return Set<String>(["shown", "blinking", "blink"])
	}
	
	public var activeStyle: Bool {
		return isActive && isFirst
	}
	
	public class var keyPathsForValuesAffectingActiveStyle: Set<String> {
		return Set<String>(["active", "first"])
	}
	
	// MARK: Positioning
	
	private func size(of font: NSFont) -> NSSize {
		// Hack: require a layout manager for OS X 10.6, but we don't have the entire text system to fall back on
		let layoutManager = NSLayoutManager()
		
		// Width is one 'en'
		let width = "n".size(withAttributes: [.font: font]).width
		
		// Height is decided by the layout manager
		let height = layoutManager.defaultLineHeight(for: font)
		
		return NSSize(width: width, height: height)
	}
	
	/// Cause the delegate to undraw any previous cursor
	@objc(positionAtPoint:withFont:)
	public func position(at pt: NSPoint, with font: NSFont) {
		let wasShown = isShown
		isShown = false
		ZCblunk()
		
		// Move the cursor
		let fontSize = size(of: font)
		
		cursorRectI = NSRect(origin: pt, size: fontSize)
		
		cursorRectI.origin.x = floor(cursorRectI.origin.x + 0.5) + 0.5
		cursorRectI.origin.y = floor(cursorRectI.origin.y + 0.5) + 0.5
		cursorRectI.size.width = floor(cursorRectI.size.width + 0.5)
		cursorRectI.size.height = floor(cursorRectI.size.height + 0.5)
		
		// Redraw
		isShown = wasShown
		ZCblunk()
		
		cursorPos = pt
	}
	
	/// Cause the delegate to undraw any previous cursor
	@objc(positionInString:withAttributes:atCharacterIndex:)
	public func position(in string: String, with attributes: [NSAttributedString.Key: Any], atCharacterIndex index: Int) {
		let wasShown = isShown
		isShown = false
		ZCblunk()
		
		let font = attributes[.font] as! NSFont
		
		// Move the cursor
		let fontSize = size(of: font)
		let strstartIdx = NSMakeRange(0, index)
		let strIdx = Range(strstartIdx, in: string)!
		let offset = String(string[strIdx]).size(withAttributes: attributes).width
		
		cursorRectI = NSRect(origin: CGPoint(x: cursorPos.x+offset, y: cursorPos.y), size: fontSize)
		
		// Redraw
		isShown = wasShown
		blink = true
		ZCblunk()
	}
	
	/// Cursor has, uh, blunked
	private func ZCblunk() {
		// Only send the message if our visibility has changed
		let nowVisible = self.isVisible
		let nowActive = self.activeStyle
		if nowActive == lastActive,
		   nowVisible == lastVisible {
			return
		}
		
		lastVisible = nowVisible
		lastActive = nowActive
		
		// Notify the delegate that we have blinked
		delegate?.blink?(self)
	}
	
	func ZCblinky(_ timer: Timer) {
		if activeStyle {
			blink = !blink
		} else {
			blink = true
		}
		ZCblunk()
	}
	
	public var cursorRect: NSRect {
		return cursorRectI.insetBy(dx: -2, dy: -2)
	}
	
	// MARK: Display status
	
	/// Cursor blinks on/off
	@objc(blinking) public var isBlinking: Bool {
		didSet {
			if isBlinking == false {
				blink = true
				ZCblunk()
				
				if let flasher {
					flasher.invalidate()
					self.flasher = nil
				}
			} else {
				if flasher == nil {
					flasher = Timer(timeInterval: BlinkInterval, target: self, selector: #selector(self.ZCblinky(_:)), userInfo: nil, repeats: true)
					RunLoop.current.add(flasher!, forMode: .default)
				}
			}
		}
	}
	
	/// Cursor shown/hidden
	@objc(shown) public var isShown: Bool {
		didSet {
			guard oldValue != isShown else {
				return
			}
			ZCblunk()
		}
	}
	
	/// Whether or not the cursor is 'active' (ie the window has focus)
	@objc(active) public var isActive: Bool {
		didSet {
			guard oldValue != isActive else {
				return
			}
			
			if isActive {
				blink = true
			}
			
			ZCblunk()
		}
	}
	
	/// Whether or not the cursor's view is the first responder
	@objc(first) public var isFirst: Bool {
		didSet {
			guard isFirst != oldValue else {
				return
			}
			
			if !isFirst {
				blink = true
			}
			
			ZCblunk()
		}
	}
	
	/// Delegate
	public weak var delegate: ZoomCursorDelegate?
}
