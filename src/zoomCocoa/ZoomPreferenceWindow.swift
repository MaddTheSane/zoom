//
//  ZoomPreferenceWindow.swift
//  Zoom
//
//  Created by C.W. Betts on 12/12/21.
//

import Cocoa
import ZoomView
import ZoomView.ZoomPreferences
import ZoomView.Swift

private let generalSettingsItemName = NSToolbarItem.Identifier("generalSettings")
private let gameSettingsItemName = NSToolbarItem.Identifier("gameSettings")
private let displaySettingsItemName = NSToolbarItem.Identifier("displaySettings")
private let fontSettingsItemName = NSToolbarItem.Identifier("fontSettings")
private let colourSettingsItemName = NSToolbarItem.Identifier("colourSettings")
private let typographicSettingsItemName = NSToolbarItem.Identifier("typographicSettings")
private let generalSettingsItem: NSToolbarItem = {
	let toRet = NSToolbarItem(itemIdentifier: generalSettingsItemName)
	toRet.label = NSLocalizedString("Preferences: General", comment: "General")
	toRet.image = NSImage(named: "Settings/general")
	toRet.action = #selector(ZoomPreferenceWindow.switchToPane(_:))
	return toRet
}()
private let gameSettingsItem: NSToolbarItem = {
	let toRet = NSToolbarItem(itemIdentifier: gameSettingsItemName)
	toRet.label = NSLocalizedString("Preferences: Game", comment: "Game")
	toRet.image = NSImage(named: "Settings/game")
	toRet.action = #selector(ZoomPreferenceWindow.switchToPane(_:))
	return toRet
}()
private let displaySettingsItem: NSToolbarItem = {
	let toRet = NSToolbarItem(itemIdentifier: displaySettingsItemName)
	toRet.label = NSLocalizedString("Preferences: Display", comment: "Display")
	toRet.image = NSImage(named: "Settings/display")
	toRet.action = #selector(ZoomPreferenceWindow.switchToPane(_:))
	return toRet
}()
private let fontSettingsItem: NSToolbarItem = {
	let toRet = NSToolbarItem(itemIdentifier: fontSettingsItemName)
	toRet.label = NSLocalizedString("Preferences: Fonts", comment: "Fonts")
	toRet.image = NSImage(named: "Settings/font")
	toRet.action = #selector(ZoomPreferenceWindow.switchToPane(_:))
	return toRet
}()
private let colourSettingsItem: NSToolbarItem = {
	let toRet = NSToolbarItem(itemIdentifier: colourSettingsItemName)
	toRet.label = NSLocalizedString("Preferences: Colour", comment: "Colour")
	toRet.image = NSImage(named: NSImage.colorPanelName)
	toRet.action = #selector(ZoomPreferenceWindow.switchToPane(_:))
	return toRet
}()
private let typographicSettingsItem: NSToolbarItem = {
	let toRet = NSToolbarItem(itemIdentifier: typographicSettingsItemName)
	toRet.label = NSLocalizedString("Preferences: Typography", comment: "Typography")
	toRet.image = NSImage(named: "Settings/typographic")
	toRet.action = #selector(ZoomPreferenceWindow.switchToPane(_:))
	return toRet
}()


private
let itemDictionary = [generalSettingsItemName: generalSettingsItem,
						 gameSettingsItemName: gameSettingsItem,
					  displaySettingsItemName: displaySettingsItem,
						 fontSettingsItemName: fontSettingsItem,
					   colourSettingsItemName: colourSettingsItem,
				  typographicSettingsItemName: typographicSettingsItem]

/// Constructs a menu of fonts
///
/// (Apple want us to use the font selection panel, but it feels clunky for the 'simple' view: there's no good way to associate
/// it with the style we're selecting. Plus we want to select families, not individual fonts)
private func fontMenu(fixed: Bool) -> NSMenu {
	let mgr = NSFontManager.shared
	
	let result = NSMenu()
	
	let families = mgr.availableFontFamilies
	
	// Iterate through the available font families and create menu items
	var mItems = families.compactMap { family -> NSMenuItem? in
		// Get the font
		guard let sampleFont = mgr.font(withFamily: family, traits: [], weight: 5, size: NSFont.systemFontSize) else {
			return nil
		}
		
		if fixed && !sampleFont.isFixedPitch {
			return nil
		}
		// Construct the item
		let fontItem = NSMenuItem()
		fontItem.attributedTitle = NSAttributedString(string: family, attributes: [.font: sampleFont])
		return fontItem
	}
	
	mItems.sort { a, b in
		return a.title.caseInsensitiveCompare(b.title) == .orderedAscending
	}
	
	result.items = mItems
	
	// Return the result
	return result
}

class ZoomPreferenceWindow: NSWindowController, NSToolbarDelegate, NSTableViewDataSource, NSTableViewDelegate {
	// The various views
	@IBOutlet weak var generalSettingsView: NSView!
	@IBOutlet weak var gameSettingsView: NSView!
	@IBOutlet weak var fontSettingsView: NSView!
	@IBOutlet weak var colourSettingsView: NSView!
	@IBOutlet weak var typographicalSettingsView: NSView!
	@IBOutlet weak var displaySettingsView: NSView!
	
	// The settings controls themselves
	@IBOutlet weak var displayWarnings: NSButton!
	@IBOutlet weak var fatalWarnings: NSButton!
	@IBOutlet weak var speakGameText: NSButton!
	@IBOutlet weak var scrollbackLength: NSSlider!
	@IBOutlet weak var autosaveGames: NSButton!
	@IBOutlet weak var keepGamesOrganised: NSButton!
	@IBOutlet weak var confirmGameClose: NSButton!
	@IBOutlet weak var transparencySlider: NSSlider!
	
	@IBOutlet weak var proportionalFont: NSPopUpButton!
	@IBOutlet weak var fixedFont: NSPopUpButton!
	@IBOutlet weak var symbolicFont: NSPopUpButton!
	@IBOutlet weak var fontSizeSlider: NSSlider!
	@IBOutlet weak var fontSizeDisplay: NSTextField!
	@IBOutlet weak var fontPreview: NSTextField!
		
	@IBOutlet weak var glulxInterpreter: NSPopUpButton!
	@IBOutlet weak var interpreter: NSPopUpButton!
	@IBOutlet weak var revision: NSTextField!
	@IBOutlet weak var reorganiseGames: NSButton!
	@IBOutlet weak var organiserIndicator: NSProgressIndicator!
	private var indicatorCount: Int = 0
	
	@IBOutlet weak var organiseDir: NSTextView!
	
	@IBOutlet weak var fonts: NSTableView!
	@IBOutlet weak var colours: NSTableView!
	
	@IBOutlet weak var showMargins: NSButton!
	@IBOutlet weak var marginWidth: NSSlider!
	@IBOutlet weak var useScreenFonts: NSButton!
	@IBOutlet weak var useHyphenation: NSButton!
	@IBOutlet weak var kerning: NSButton!
	@IBOutlet weak var ligatures: NSButton!
	
	@IBOutlet weak var foregroundColour: NSPopUpButton!
	@IBOutlet weak var backgroundColour: NSPopUpButton!
	@IBOutlet weak var zoomBorders: NSButton!
	@IBOutlet weak var showCoverPicture: NSButton!
	
	private var toolbar: NSToolbar!
	
	@objc var preferences: ZoomPreferences = ZoomPreferences(defaultPreferences: ()) {
		didSet {
			displayWarnings.state = preferences.displayWarnings ? .on : .off
			fatalWarnings.state = preferences.fatalWarnings ? .on : .off
			speakGameText.state = preferences.speakGameText ? .on : .off
			scrollbackLength.doubleValue = preferences.scrollbackLength
			keepGamesOrganised.state = preferences.keepGamesOrganised ? .on : .off
			autosaveGames.state = preferences.autosaveGames ? .on : .off
			reorganiseGames.isEnabled = preferences.keepGamesOrganised
			confirmGameClose.state = preferences.confirmGameClose ? .on : .off
			glulxInterpreter.selectItem(withTag: preferences.glulxInterpreter.rawValue)
			
			// a kind of chessy way to get the current alpha setting
			let color = preferences.userColours![0]
			transparencySlider.doubleValue = color.alphaComponent * 100
			
			interpreter.selectItem(at: Int(preferences.interpreter - 1))
			revision.stringValue = String(format: "%c", preferences.revision)
			
			setSimpleFonts()
			
			organiseDir.string = preferences.organiserDirectory
			
			showMargins.state = preferences.textMargin > 0 ? .on : .off
			useScreenFonts.state = preferences.useScreenFonts ? .on : .off
			useHyphenation.state = preferences.useHyphenation ? .on : .off
			kerning.state = preferences.useKerning ? .on : .off
			ligatures.state = preferences.useLigatures ? .on : .off
			
			marginWidth.isEnabled = preferences.textMargin > 0
			if preferences.textMargin > 0 {
				marginWidth.doubleValue = preferences.textMargin
			}
			
			zoomBorders.state = preferences.showBorders ? .on : .off
			showCoverPicture.state = preferences.showCoverPicture ? .on : .off
			updateColourMenus()
		}
	}
	
	@objc class var keyPathsForValuesAffectingCustomColors: Set<String> {
		return ["preferences"]
	}
	
	@objc dynamic public var customColors: Bool {
		get {
			return preferences.useUserColours
		}
		set {
			preferences.useUserColours = newValue
		}
	}
	
	convenience init() {
		self.init(windowNibName: "Preferences")
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
		
		// Set the toolbar
		toolbar = NSToolbar(identifier: "preferencesToolbar2")
		toolbar.delegate = self
		toolbar.displayMode = .iconAndLabel
		toolbar.allowsUserCustomization = false
		window?.toolbar = toolbar
		if #available(macOS 11.0, *) {
			window?.toolbarStyle = .preference
		}
		
		window?.setContentSize(generalSettingsView.frame.size)
		self.window?.contentView = generalSettingsView

		toolbar.selectedItemIdentifier = generalSettingsItemName
		
		fonts.dataSource = self
		fonts.delegate = self
		colours.dataSource = self
		colours.delegate = self
		
		// Set up the various font menus
		let proportionalMenu = fontMenu(fixed: false)
		let fixedMenu = fontMenu(fixed: true)
		let symbolMenu = proportionalMenu.copy() as! NSMenu

		proportionalFont.menu = proportionalMenu
		fixedFont.menu = fixedMenu
		symbolicFont.menu = symbolMenu

		NotificationCenter.default.addObserver(self, selector: #selector(self.storyProgressChanged(_:)), name: ZoomStoryOrganiser.progressNotification, object: ZoomStoryOrganiser.shared)
	}
	
	/// Setting the pane that's being displayed
	@objc fileprivate func switchToPane(_ sender: NSToolbarItem) {

		let itemToViewDictionary = [generalSettingsItem: generalSettingsView,
									   gameSettingsItem: gameSettingsView,
									displaySettingsItem: displaySettingsView,
									   fontSettingsItem: fontSettingsView,
									 colourSettingsItem: colourSettingsView,
								typographicSettingsItem: typographicalSettingsView]

		let preferencePane = itemToViewDictionary[sender]!!
		guard window?.contentView != preferencePane else {
			return
		}
		
		// Work out the various frame sizes
		var windowFrame = window!.frame
		let frameForContent = window!.frameRect(forContentRect: preferencePane.frame)
		windowFrame.origin.y -= frameForContent.height - window!.frame.height
		windowFrame.size.height = frameForContent.height

		window?.contentView = preferencePane
		window?.setFrame(windowFrame, display: true, animate: true)
		window?.initialFirstResponder = preferencePane
	}
	
	// MARK: - Toolbar delegate functions
	
	func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		return itemDictionary[itemIdentifier]
	}
	
	func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		[generalSettingsItemName, gameSettingsItemName, displaySettingsItemName, fontSettingsItemName, typographicSettingsItemName, colourSettingsItemName, .flexibleSpace]
	}
	
	func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [.flexibleSpace, generalSettingsItemName, gameSettingsItemName, displaySettingsItemName, fontSettingsItemName, typographicSettingsItemName, colourSettingsItemName, .flexibleSpace]
	}
	
	func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [generalSettingsItemName, gameSettingsItemName, displaySettingsItemName, fontSettingsItemName, colourSettingsItemName, typographicSettingsItemName]
	}

	// MARK: - Setting the preferences that we're editing
	
	private func setButton(_ button: NSPopUpButton, toFontFamily family: String) {
		var familyItem: NSMenuItem? = nil
		
		for curItem in button.menu!.items {
			if curItem.title.caseInsensitiveCompare(family) == .orderedSame {
				familyItem = curItem
				break
			}
		}
		
		if let familyItem = familyItem {
			button.select(familyItem)
		}
	}
	
	/// Sets our display from the 'simple' fonts the user has selected
	private func setSimpleFonts() {
		// Select the fonts
		setButton(proportionalFont, toFontFamily: preferences.proportionalFontFamily!)
		setButton(fixedFont, toFontFamily: preferences.fixedFontFamily!)
		setButton(symbolicFont, toFontFamily: preferences.symbolicFontFamily!)
		
		// Set the size display
		let fontSize = preferences.fontSize
		fontSizeSlider.doubleValue = fontSize
		fontSizeDisplay.stringValue = String(format: "%.1fpt", fontSize)
		
		// Set the font preview
		fontPreview.font = preferences.fonts[0]
	}
	
	private func colorName(at index: Int) -> String {
		switch index {
		case 0:
			return NSLocalizedString("Color Black", comment: "Black");
		case 1:
			return NSLocalizedString("Color Red", comment: "Red");
		case 2:
			return NSLocalizedString("Color Green", comment: "Green");
		case 3:
			return NSLocalizedString("Color Yellow", comment: "Yellow");
		case 4:
			return NSLocalizedString("Color Blue", comment: "Blue");
		case 5:
			return NSLocalizedString("Color Magenta", comment: "Magenta");
		case 6:
			return NSLocalizedString("Color Cyan", comment: "Cyan");
		case 7:
			return NSLocalizedString("Color White", comment: "White");
		case 8:
			return NSLocalizedString("Color Light grey", comment: "Light grey");
		case 9:
			return NSLocalizedString("Color Medium grey", comment: "Medium grey");
		case 10:
			return NSLocalizedString("Color Dark grey", comment: "Dark grey");
		default:
			return NSLocalizedString("Color Unused colour", comment: "Unused colour")
		}
	}
	
	private func updateColourMenus() {
		let swatchSize = NSSize(width: 16, height: 12)
		let newColorMenu = NSMenu()
		
		for (col, actual) in preferences.colours!.enumerated() {
			// Build the image showing a preview of this colour
			let sampleImage = NSImage(size: swatchSize)
			
			sampleImage.lockFocus()
			actual.set()
			NSRect(origin: .zero, size: swatchSize).fill()
			sampleImage.unlockFocus()
			
			let colourItem = NSMenuItem(title: colorName(at: col), action: nil, keyEquivalent: "")
			colourItem.tag = col
			colourItem.image = sampleImage
			
			newColorMenu.addItem(colourItem)
		}
		
		// Set the menu as the menu for both the popup buttons
		foregroundColour.menu = newColorMenu
		backgroundColour.menu = (newColorMenu.copy() as! NSMenu)
		
		foregroundColour.selectItem(withTag: Int(preferences.foregroundColour))
		backgroundColour.selectItem(withTag: Int(preferences.backgroundColour))
	}
	
	// MARK: - Table data source
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		if tableView === fonts {
			return preferences.fonts.count
		}
		if tableView === colours {
			return preferences.userColours!.count
		}
		
		return 0
	}
	
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		if tableView === fonts {
			let fontArray = preferences.fonts
			
			if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Style") {
				var name = ""
				name.reserveCapacity(20)
				
				if (row & 1) != 0 {
					appendStyle(&name, "bold")
				}
				if (row & 2) != 0 {
					appendStyle(&name, "italic")
				}
				if (row & 4) != 0 {
					appendStyle(&name, "fixed")
				}
				if (row & 8) != 0 {
					appendStyle(&name, "symbolic")
				}
				
				if name.isEmpty {
					name = "roman"
				}
				
				return name
			} else if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Font") {
				let font = fontArray[row]
				
				let fontName = String(format: "%@ (%.2gpt)", font.fontName, font.pointSize)
				
				return NSAttributedString(string: fontName, attributes: [.font: font])
			}
			
			// Unknown column
			return " -- "
		} else if tableView === colours {
			if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Colour name") {
				return colorName(at: row)
			} else if tableColumn?.identifier == NSUserInterfaceItemIdentifier("Colour") {
				let theColour = preferences.userColours![row]
				return NSAttributedString(string: "Sample",
										  attributes: [.foregroundColor: theColour,
													   .backgroundColor: theColour])
			}
			
			return " -- ";
		}
		
		return " -- "
	}
	
	// MARK: - Table delegate
	
	func tableViewSelectionDidChange(_ notification: Notification) {
		if (notification.object as AnyObject?) === fonts {
			let selFont = fonts.selectedRow
			
			guard selFont >= 0 else {
				return
			}
			
			let font = preferences.fonts[selFont]
			
			// Display font panel
			NSFontPanel.shared.setPanelFont(font, isMultiple: false)
			NSFontPanel.shared.isEnabled = true
			NSFontPanel.shared.accessoryView = nil
			NSFontPanel.shared.orderFront(self)
			NSFontPanel.shared.reloadDefaultFontFamilies()
		} else if (notification.object as AnyObject?) === colours {
			let selColour = colours.selectedRow
			
			guard selColour >= 0 else {
				return
			}
			
			let colour = preferences.userColours![selColour]
			
			// Display colours
			NSColorPanel.shared.color = colour
			NSColorPanel.shared.accessoryView = nil
			NSColorPanel.shared.orderFront(self)
		}
	}
	
	// MARK: - Font panel delegate
	
	@IBAction func changeFont(_ sender: Any?) {
		// Change the selected font in the font table
		let selFont = fonts.selectedRow
		
		guard selFont >= 0 else {
			return
		}
		
		var prefFont = preferences.fonts
		if let newFont: NSFont = (sender as? NSFontManager)?.convert(prefFont[selFont]) {
			prefFont[selFont] = newFont
			preferences.fonts = prefFont
			
			fonts.reloadData()
		}
		
		setSimpleFonts()
	}
	
	@IBAction func changeColor(_ sender: Any?) {
		let selColour = colours.selectedRow
		
		guard selColour >= 0 else {
			return
		}
		
		let selected_colour = NSColorPanel.shared.color
		let colour = selected_colour.withAlphaComponent(transparencySlider.doubleValue / 100)
		
		var cols = preferences.userColours!
		
		cols[selColour] = colour
		preferences.userColours = cols
		
		colours.reloadData()
		updateColourMenus()
	}

	@IBAction func changeTransparency(_ sender: Any?) {
		var cols = preferences.userColours!
		
		cols = cols.map { col -> NSColor in
			return col.withAlphaComponent(transparencySlider.doubleValue / 100)
		}
		
		preferences.userColours = cols
		
		colours.reloadData()
	}

	// MARK: - Various actions

	@IBAction func interpreterChanged(_ sender: Any?) {
		preferences.interpreter = Int32(interpreter.indexOfSelectedItem + 1)
	}

	@IBAction func glulxInterpreterChanged(_ sender: Any?) {
		preferences.glulxInterpreter = GlulxInterpreter(rawValue: glulxInterpreter.selectedItem!.tag) ?? .git
	}

	@IBAction func revisionChanged(_ sender: Any?) {
		if let ascii = revision.stringValue.first?.asciiValue {
			preferences.revision = ascii
		}
	}

	@IBAction func displayWarningsChanged(_ sender: Any?) {
		preferences.displayWarnings = (sender as? NSButton)?.state == .on
	}

	@IBAction func fatalWarningsChanged(_ sender: Any?) {
		preferences.fatalWarnings = (sender as? NSButton)?.state == .on
	}

	@IBAction func speakGameTextChanged(_ sender: Any?) {
		preferences.speakGameText = (sender as? NSButton)?.state == .on
	}

	@IBAction func scrollbackChanged(_ sender: Any?) {
		if let sender = sender as? NSSlider {
			preferences.scrollbackLength = sender.doubleValue
		}
	}

	@IBAction func keepOrganisedChanged(_ sender: Any?) {
		guard let state: NSControl.StateValue = (sender as AnyObject?)?.state else {
			return
		}
		preferences.keepGamesOrganised = state == .on
		reorganiseGames.isEnabled = state == .on
		if state == .off {
			autosaveGames.state = .off
			preferences.autosaveGames = false
		}
	}

	@IBAction func autosaveChanged(_ sender: Any?) {
		preferences.autosaveGames = (sender as? NSButton)?.state == .on
	}

	@IBAction func confirmGameCloseChanged(_ sender: Any?) {
		preferences.confirmGameClose = (sender as? NSButton)?.state == .on
	}
	
	@IBAction func simpleFontsChanged(_ sender: Any?) {
		// This action applies to all the font controls
		
		// Set the size, if it has changed
		let newSize: CGFloat = floor(fontSizeSlider.doubleValue)
		if newSize != preferences.fontSize {
			preferences.fontSize = newSize
		}
		
		// Set the families, if they've changed
		let propFamily = proportionalFont.selectedItem!.title
		let fixedFamily = fixedFont.selectedItem!.title
		let symbolicFamily = symbolicFont.selectedItem!.title
		
		if propFamily != preferences.proportionalFontFamily {
			preferences.proportionalFontFamily = propFamily
		}
		if fixedFamily != preferences.fixedFontFamily {
			preferences.fixedFontFamily = fixedFamily
		}
		if symbolicFamily != preferences.symbolicFontFamily {
			preferences.symbolicFontFamily = symbolicFamily
		}
		
		// Update the display
		setSimpleFonts()
	}

	
	@IBAction func changeOrganiseDir(_ sender: Any?) {
		let dirChooser = NSOpenPanel()
		dirChooser.allowsMultipleSelection = false
		dirChooser.canChooseDirectories = true
		dirChooser.canChooseFiles = false
		dirChooser.canCreateDirectories = true
		
		if let path = preferences.organiserDirectory {
			let pathURL = URL(fileURLWithPath: path)
			dirChooser.directoryURL = pathURL
		}
		
		dirChooser.beginSheetModal(for: window!) { [self] result in
			guard result == .OK else {
				return
			}
			
			ZoomStoryOrganiser.shared.reorganiseStories(to: dirChooser.url!)
			preferences.organiserDirectory = dirChooser.url!.path
			organiseDir.string = preferences.organiserDirectory
		}
	}

	@IBAction func resetOrganiseDir(_ sender: Any?) {
		if preferences.keepGamesOrganised {
			ZoomStoryOrganiser.shared.reorganiseStories(to: ZoomPreferences.defaultOrganiserDirectoryURL)
		}
		
		preferences.organiserDirectory = nil
		organiseDir.string = preferences.organiserDirectory
	}
	
	// MARK: - Typographical changes
	
	@IBAction func marginsChanged(_ sender: Any?) {
		let oldSize = preferences.textMargin
		var newSize: CGFloat = 0
		// Work out the new margin size

		if showMargins.state == .off {
			newSize = 0
			marginWidth.isEnabled = false
		} else if showMargins.state == .on, oldSize <= 0 {
			newSize = 10
			marginWidth.isEnabled = true
		} else {
			newSize = floor(marginWidth.doubleValue)
			marginWidth.isEnabled = true
		}
		
		if newSize != oldSize {
			preferences.textMargin = newSize
		}
	}

	@IBAction func screenFontsChanged(_ sender: Any?) {
		let newState = useScreenFonts.state == .on
		
		if newState != preferences.useScreenFonts {
			preferences.useScreenFonts = newState
		}
	}

	@IBAction func hyphenationChanged(_ sender: Any?) {
		let newState = useHyphenation.state == .on
		
		if newState != preferences.useHyphenation {
			preferences.useHyphenation = newState
		}
	}

	@IBAction func ligaturesChanged(_ sender: Any?) {
		let newState = ligatures.state == .on
		
		if newState != preferences.useLigatures {
			preferences.useLigatures = newState
		}
	}

	@IBAction func kerningChanged(_ sender: Any?) {
		let newState = kerning.state == .on
		
		if newState != preferences.useKerning {
			preferences.useKerning = newState
		}
	}

	// MARK: - Story progress meter
	
	@objc private func storyProgressChanged(_ noti: Notification) {
		let userInfo = noti.userInfo
		guard let activated = userInfo?["ActionStarting"] as? Bool else {
			//should not happen
			return
		}
		
		if activated {
			indicatorCount += 1
		} else {
			indicatorCount -= 1
		}
		
		if indicatorCount <= 0 {
			indicatorCount = 0
			organiserIndicator.stopAnimation(self)
		} else {
			organiserIndicator.startAnimation(self)
		}
	}
	
	@IBAction func reorganiseGames(_ sender: Any?) {
		// Can't use this if keepGamesOrganised is off
		guard preferences.keepGamesOrganised else {
			return
		}
		
		// Reorganise all the stories
		ZoomStoryOrganiser.shared.organiseAllStories()
	}
	
	// MARK: - Display pane
	
	@IBAction func bordersChanged(_ sender: Any?) {
		let newState = (sender as AnyObject?)?.state == .on
		let oldState = preferences.showBorders
		
		if newState != oldState {
			preferences.showBorders = newState
			preferences.showGlkBorders = newState
		}
	}

	@IBAction func showCoverPictureChanged(_ sender: Any?) {
		let newState = (sender as AnyObject?)?.state == .on
		
		if newState != preferences.showCoverPicture {
			preferences.showCoverPicture = newState
		}
	}

	@IBAction func colourChanged(_ sender: Any?) {
		guard let newValue = (sender as AnyObject?)?.selectedTag() else {
			return
		}
		let oldValue = (sender as AnyObject?) === foregroundColour ? preferences.foregroundColour : preferences.backgroundColour
		
		if newValue != oldValue {
			if (sender as AnyObject?) === foregroundColour {
				preferences.foregroundColour = Int32(newValue)
			} else {
				preferences.backgroundColour = Int32(newValue)
			}
		}
	}
}

private func appendStyle(_ styleName: inout String, _ newStyle: String) {
	if styleName.isEmpty {
		styleName.append(newStyle)
	} else {
		styleName.append("-")
		styleName.append(newStyle)
	}
}
