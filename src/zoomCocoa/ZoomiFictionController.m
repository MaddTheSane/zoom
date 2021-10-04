//
//  ZoomiFictionController.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jan 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

// Incorporates changes contributed by Collin Pieper

#import <objc/objc-runtime.h>
#include <tgmath.h>

#import "ZoomiFictionController.h"
#import "ZoomiFictionController+OldWebKit.h"
#import "ZoomStoryOrganiser.h"
#import <ZoomPlugIns/ZoomStory.h>
#import <ZoomPlugIns/ZoomStoryID.h>
#import "ZoomAppDelegate.h"
#import <ZoomPlugIns/ZoomGameInfoController.h>
#import <ZoomPlugIns/ZoomNotesController.h>
#import "ZoomClient.h"
#import <ZoomPlugIns/ZoomPlugInManager.h>
#import <ZoomPlugIns/ZoomPlugInController.h>
#import <ZoomPlugIns/ZoomPlugIn.h>
#import "ZoomWindowThatIsKey.h"
@import ZoomPlugIns.Swift;
#import "ZoomSignPost.h"
#import "Zoom-Swift.h"

#import <ZoomPlugIns/ifmetabase.h>

@interface ZoomiFictionController()

- (NSString*) queryEncode: (NSString*) string;
- (void) installSignpostPluginFrom: (NSData*) signpostXml;
- (void) installPluginFrom: (ZoomDownload*) downloadedPlugin;
- (void) updateBackForwardButtons;

@end

@implementation ZoomiFictionController

static ZoomiFictionController* sharedController = nil;

static NSString*const addDirectory = @"ZoomiFictionControllerDefaultDirectory";
static NSString*const sortGroup    = @"ZoomiFictionControllerSortGroup";

static NSString*const ZoomFieldAttribute = @"ZoomFieldAttribute";
static NSString*const ZoomRowAttribute = @"ZoomRowAttribute";
static NSString*const ZoomStoryAttribute = @"ZoomStoryAttribute";

enum {
	ZoomNoField,
	ZoomTitleField,
	ZoomYearField,
	ZoomDescriptionField,

	ZoomTitleNewlineField,
	ZoomYearNewlineField,
	ZoomDescriptionNewlineField
};

// = Setup/initialisation =

+ (ZoomiFictionController*) sharediFictionController {
	if (!sharedController) {
		NSString* nibName = @"iFiction";
		sharedController = [[ZoomiFictionController alloc] initWithWindowNibName: nibName];
	}
	
	return sharedController;
}

+ (void) initialize {
	// Create user defaults
	NSURL* docDir = [[NSFileManager defaultManager] URLForDirectory: NSDocumentDirectory inDomain: NSUserDomainMask appropriateForURL:nil create: NO error: NULL];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
		docDir, addDirectory, @"group", sortGroup, nil]];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (NSView*) createMetalTitleForTable: (NSTableView*) theTable {
	// Jeremy Dronfield suggested this on Cocoa-dev
	
	NSRect superRect = [[theTable headerView] frame];
	NSRect cornerRect = [[theTable cornerView] frame];
	
	// Allocate the header view
	NSTableHeaderView* myHeader = [[NSTableHeaderView alloc] initWithFrame:superRect];
	[myHeader setAutoresizesSubviews:YES];
	
	// Shadow creates an engraved look
	NSShadow *shadow = [[NSShadow alloc] init];
	[shadow setShadowOffset:NSMakeSize(1.1, -1.5)];
	[shadow setShadowBlurRadius:0.2];
	[shadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.6]];
		
	// The title text
	NSMutableAttributedString *headerString = [[NSMutableAttributedString alloc] initWithString:@"Title"];
	NSRange range = NSMakeRange(0, [headerString length]);
	[headerString addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:11.0] range:range];
	[headerString addAttribute:NSShadowAttributeName value:shadow range:range];
	[headerString setAlignment:NSTextAlignmentCenter range:range];
	
	// The background image
	NSImageView *imageView = [[NSImageView alloc] initWithFrame:superRect];
	[imageView setImageFrameStyle:NSImageFrameNone];
	[imageView setImageAlignment:NSImageAlignCenter];
	[imageView setImageScaling:NSImageScaleAxesIndependently];
	[imageView setImage:[NSImage imageNamed:@"Metal-Title"]];
	[imageView setAutoresizingMask:NSViewWidthSizable];
	
	// Set the corner view image
	NSImageView *cornerImage = [[NSImageView alloc] initWithFrame:cornerRect];
	[cornerImage setImageFrameStyle:NSImageFrameNone];
	[cornerImage setImageAlignment:NSImageAlignCenter];
	[cornerImage setImageScaling:NSImageScaleAxesIndependently];
	[cornerImage setImage:[NSImage imageNamed:@"Metal-Title"]];
	
	// The header label
	NSTextField *headerText = [[NSTextField alloc] initWithFrame:superRect];
	[headerText setAutoresizingMask:NSViewWidthSizable];
	[headerText setDrawsBackground:NO];
	[headerText setBordered:NO];
	[headerText setEditable:NO];
	[headerText setAttributedStringValue:headerString];
	
	[myHeader addSubview:imageView];
	[myHeader addSubview:headerText];
	[theTable setHeaderView:myHeader];
	[theTable setCornerView:cornerImage];
	
	// The menu
	[myHeader setMenu: [theTable menu]];
	[headerText setMenu: [theTable menu]];
	[imageView setMenu: [theTable menu]];
	
	return myHeader;
}

- (void) setTitle: (NSString*) title
		 forTable: (NSTableView*) table {
	// Can't use the traditional methods, as our table header view draws all over the normal
	// column header
		NSTableHeaderView* theHeader = [table headerView];
		NSEnumerator* viewEnum = [[theHeader subviews] objectEnumerator];

		// Shadow creates an engraved look
		NSShadow* shadow = [[NSShadow alloc] init];
		[shadow setShadowOffset:NSMakeSize(1.1, -1.5)];
		[shadow setShadowBlurRadius:0.2];
		[shadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.6]];
		
		// The title text
		NSMutableAttributedString *headerString = [[NSMutableAttributedString alloc] initWithString: title];
		NSRange range = NSMakeRange(0, [headerString length]);
		[headerString addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:11.0] range:range];
		[headerString addAttribute:NSShadowAttributeName value:shadow range:range];
		[headerString setAlignment:NSTextAlignmentCenter range:range];
		
		for (NSTextField* titleView in viewEnum) {
			if ([titleView isKindOfClass: [NSTextField class]]) {
				[titleView setAttributedStringValue: headerString];
			}
		}
}

- (void) flipTo: (NSView*) view {
	NSRect viewFrame = [topPanelView bounds];
	viewFrame.origin = NSMakePoint(0,0);
	
	[view setFrame: viewFrame];
	
	[flipView prepareToAnimateView: topPanelView];
	[flipView animateTo: view
				  style: ZoomAnimateFade];
	
	if (view == filterView) {
		[flipButtonMatrix selectCellWithTag: 2];		
	} else if (view == infoView) {
		[flipButtonMatrix selectCellWithTag: 1];
	} else if (view == saveGameView) {
		[flipButtonMatrix selectCellWithTag: 0];
	}
	
	topPanelView = view;
	[flipButtonMatrix setNextKeyView: view];
	[view setNextKeyView: mainTableView];
}

- (void) positionDownloadWindow {
	if (![downloadWindow isVisible]) return;
	
	NSRect mainWindowFrame = [[self window] frame];
	NSRect downloadFrame = [downloadWindow frame];
	
	downloadFrame.origin.x = NSMaxX(mainWindowFrame) - downloadFrame.size.width - 9;
	downloadFrame.origin.y = NSMinY(mainWindowFrame) + 42;
	
	[downloadWindow setFrameOrigin: downloadFrame.origin];
}

- (void) windowDidLoad {
	[ifdbView setFrameLoadDelegate: self];
	[ifdbView setPolicyDelegate: self];

#ifdef DEVELOPMENT_BUILD
	[ifdbView setCustomUserAgent: @"Mozilla/5.0 (Macintosh; U; Mac OS X; en-us) AppleWebKit (KHTML like Gecko) uk.org.logicalshift.zoom/1.1.2/development"];
#else
	[ifdbView setCustomUserAgent: @"Mozilla/5.0 (Macintosh; U; Mac OS X; en-us) AppleWebKit (KHTML like Gecko) uk.org.logicalshift.zoom/1.1.2/release"];
#endif	
	
	NSURL* loadingPage = [NSURL fileURLWithPath: [[NSBundle mainBundle] pathForResource: @"ifdb-loading"
																				 ofType: @"html"]];
	[[ifdbView mainFrame] loadRequest: [NSURLRequest requestWithURL: loadingPage]];
	
	NSView* clearView = [[ClearView alloc] init];
	downloadView = [[DownloadView alloc] initWithFrame: NSMakeRect(0,0,276,78)];
	downloadWindow = [[ZoomWindowThatIsKey alloc] initWithContentRect: NSMakeRect(0,0,276,78)
															styleMask: NSWindowStyleMaskBorderless
															  backing: NSBackingStoreBuffered
																defer: NO];
	[downloadWindow setOpaque: NO];
	[downloadWindow setAlphaValue: 0];
	[downloadWindow setContentView: clearView];
	[downloadView setFrame: [clearView frame]];
	[clearView addSubview: downloadView];
	
	[continueButton setEnabled: NO];
	[newgameButton setEnabled: NO];
	
	[[self window] setFrameUsingName: @"iFiction"];
	[[self window] setExcludedFromWindowsMenu: YES];

	[gameDetailView setTextContainerInset: NSMakeSize(6.0, 6.0)];
	[[gameDetailView textStorage] setDelegate: self];
	[self setupSplitView];
		
	// Set up the filter table headers
		// We have NSShadow - go ahead
		
		// Note (and FIXME): a retained view is not released here
		// (Being lazy: this doesn't matter, as the iFiction window is persistent)
		[self createMetalTitleForTable: filterTable1];
		[self createMetalTitleForTable: filterTable2];
		
		[self setTitle: @"Group"
			  forTable: filterTable1];
		[self setTitle: @"Author"
			  forTable: filterTable2];


	showDrawer = YES;
	needsUpdating = YES;
	
	sortColumn = [[[NSUserDefaults standardUserDefaults] objectForKey: sortGroup] copy];
	[mainTableView setHighlightedTableColumn:[mainTableView tableColumnWithIdentifier:sortColumn]];
	
	[mainTableView setAllowsColumnSelection: NO];
	
	// Add a 'ratings' column to the main table
	NSTableColumn* newColumn = [[NSTableColumn alloc] initWithIdentifier: @"rating"];
	
	NSLevelIndicatorCell *cell = [[NSLevelIndicatorCell alloc] initWithLevelIndicatorStyle:NSLevelIndicatorStyleRating];
	cell.maxValue = 10;
	
	[newColumn setDataCell: cell];
	[newColumn setMinWidth: 120];
	[newColumn setMaxWidth: 120];
	[newColumn setEditable: YES];
	[[newColumn headerCell] setStringValue: @"Rating"];
	
	[mainTableView addTableColumn: newColumn];
	
	// Turn on autosaving
	[mainTableView setAutosaveName: @"ZoomStoryTable"];
	[mainTableView setAutosaveTableColumns: YES];
	
	// Update the table when the story list changes
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(storyListChanged:)
												 name: ZoomStoryOrganiserChangedNotification
											   object: [ZoomStoryOrganiser sharedStoryOrganiser]];
	
	// Deal with progress indicator notifications
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(storyProgressChanged:)
												 name: ZoomStoryOrganiserProgressNotification
											   object: [ZoomStoryOrganiser sharedStoryOrganiser]];
	
	[self configureFromMainTableSelection];
	[mainTableView reloadData];
	
	[mainTableView registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
				   
	[mainTableView setDoubleAction:@selector(startNewGame:)];

	[self flipTo: filterView];
}

- (void) close {
	[[self window] orderOut: self];
	[[self window] saveFrameUsingName: @"iFiction"];
}

- (void)windowDidMove:(NSNotification *)aNotification {
	[[self window] saveFrameUsingName: @"iFiction"];
}

- (void) setBrowserFontSize {
	NSRect viewFrame = [browserView frame];
	BOOL shouldUseSmallFonts = NO;
	
	if (viewFrame.size.width < 900 || viewFrame.size.height < 400) {
		shouldUseSmallFonts = YES;
	}
	
	if (shouldUseSmallFonts != smallBrowser) {
		smallBrowser = shouldUseSmallFonts;
		
		[ifdbView setTextSizeMultiplier: shouldUseSmallFonts?0.7:1.0];
	}
}

- (void)windowDidResize:(NSNotification *)notification {
	[[self window] saveFrameUsingName: @"iFiction"];

	if (browserOn) [self setBrowserFontSize];
	[self positionDownloadWindow];
}

// = Useful functions for getting info about the table =

- (ZoomStoryID*) selectedStoryID {
	if (needsUpdating) [self reloadTableData];
	
	if ([mainTableView numberOfSelectedRows] == 1) {
		ZoomStoryID* ident = [storyList objectAtIndex: [mainTableView selectedRow]];
		
		return ident;
	}
	
	return nil;
}

- (ZoomStory*) selectedStory {
	ZoomStoryID* ident = [self selectedStoryID];
	
	if (ident != nil) {
		return [self storyForID: ident];
	}
	
	return nil;
}

- (NSString*) selectedFilename {
	ZoomStoryID* ident = [self selectedStoryID];
	
	if (ident != nil) {
		return [[ZoomStoryOrganiser sharedStoryOrganiser] filenameForIdent: ident];
	}
	
	return nil;
}

- (ZoomStory*) createStoryCopy: (ZoomStory*) theStory {
	if (theStory == nil) {
		return nil;
	}
	
	[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] copyStory: theStory];
	return [[(ZoomAppDelegate*)[NSApp delegate] userMetadata] findOrCreateStory: [theStory storyID]];
}

// = Panel actions =

#ifndef __MAC_11_0
#define __MAC_11_0          110000
#endif

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= __MAC_11_0
static NSArray<NSString*> * const ZComFileTypes = @[@"z3", @"z4", @"z5", @"z6", @"z7", @"z8", @"blorb", @"zblorb", @"blb", @"zlb"];
static NSArray<NSString*> * const blorbFileTypes = @[@"blorb", @"zblorb", @"blb", @"zlb", @"gblorb", @"glb"];
#else
static NSArray<NSString*>* ZComFileTypes;
static NSArray<NSString*>* blorbFileTypes;
static dispatch_once_t onceTypesToken;
static dispatch_block_t onceTypesBlock = ^{
	ZComFileTypes = @[@"z3", @"z4", @"z5", @"z6", @"z7", @"z8", @"blorb", @"zblorb", @"blb", @"zlb"];
	blorbFileTypes = @[@"blorb", @"zblorb", @"blb", @"zlb", @"gblorb", @"glb"];
};

#endif

- (void) addURLs: (NSArray<NSURL*> *)filenames {
#if __MAC_OS_X_VERSION_MIN_REQUIRED < __MAC_11_0
	dispatch_once(&onceTypesToken, onceTypesBlock);
#endif

	// Add all the files we can
	NSMutableArray<NSURL*>* selectedFiles = [filenames mutableCopy];
	
	while([selectedFiles count] > 0) @autoreleasepool {
		BOOL isDir;
		
		NSURL *filename = [selectedFiles objectAtIndex:0];
		NSString *path = filename.path;

		isDir = NO;
		[[NSFileManager defaultManager] fileExistsAtPath: path
											 isDirectory: &isDir];
		
		NSString* fileType = [filename pathExtension];
		Class plugin;
		
		if (isDir) {
			NSArray<NSURL*>* dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL: filename includingPropertiesForKeys:nil options: NSDirectoryEnumerationSkipsSubdirectoryDescendants error: NULL];
			
			[selectedFiles addObjectsFromArray: dirContents];
		} else if ([ZComFileTypes containsObject: fileType]) {
			ZoomStoryID* fileID = [[ZoomStoryID alloc] initWithZCodeFile: path];
			
			if (fileID != nil) {
				[[ZoomStoryOrganiser sharedStoryOrganiser] addStoryAtURL: filename
															withIdentity: fileID
																organise: [[ZoomPreferences globalPreferences] keepGamesOrganised]
																   error: NULL];
				
			}
		} else if ([blorbFileTypes containsObject: fileType]) {
			ZoomStoryID* fileID = [[ZoomStoryID alloc] initWithGlulxFile: path];
			
			if (fileID != nil) {
				[[ZoomStoryOrganiser sharedStoryOrganiser] addStoryAtURL: filename
															withIdentity: fileID
																organise: [[ZoomPreferences globalPreferences] keepGamesOrganised]
																   error: NULL];
				
			}
		} else if ((plugin = [[ZoomPlugInManager sharedPlugInManager] plugInForFile: path])) {
			ZoomPlugIn* instance = [[plugin alloc] initWithFilename: path];
			ZoomStoryID* fileID = [instance idForStory];
			
			if (fileID != nil) {
				[[ZoomStoryOrganiser sharedStoryOrganiser] addStoryAtURL: filename
															withIdentity: fileID
																organise: [[ZoomPreferences globalPreferences] keepGamesOrganised]
																   error: NULL];
			}
		}

		[selectedFiles removeObjectAtIndex:0];
	}
}

- (void) addFiles: (NSArray *)filenames {
#if __MAC_OS_X_VERSION_MIN_REQUIRED < __MAC_11_0
	dispatch_once(&onceTypesToken, onceTypesBlock);
#endif

	// Add all the files we can
	NSMutableArray* selectedFiles = [filenames mutableCopy];
	
	while( [selectedFiles count] > 0 ) 
	@autoreleasepool {
		BOOL isDir;
		
		NSString *filename = [selectedFiles objectAtIndex:0];

		isDir = NO;
		[[NSFileManager defaultManager] fileExistsAtPath: filename
											 isDirectory: &isDir];
		
		NSString* fileType = [filename pathExtension];
		Class plugin;
		
		if (isDir) {
			NSArray* dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: filename error:NULL];
			
			for (NSString* dirComponent in dirContents)
			{
				[selectedFiles addObject: [filename stringByAppendingPathComponent: dirComponent]];
			}
		} else if ([ZComFileTypes containsObject: fileType]) {
			ZoomStoryID* fileID = [[ZoomStoryID alloc] initWithZCodeFile: filename];
			
			if (fileID != nil) 
			{
				[[ZoomStoryOrganiser sharedStoryOrganiser] addStory: filename
														  withIdent: fileID
														   organise: [[ZoomPreferences globalPreferences] keepGamesOrganised]];
				
			}
		} else if ([blorbFileTypes containsObject: fileType]) {
			ZoomStoryID* fileID = [[ZoomStoryID alloc] initWithGlulxFile: filename];
			
			if (fileID != nil)
			{
				[[ZoomStoryOrganiser sharedStoryOrganiser] addStory: filename
														  withIdent: fileID
														   organise: [[ZoomPreferences globalPreferences] keepGamesOrganised]];
				
			}
		} else if ((plugin = [[ZoomPlugInManager sharedPlugInManager] plugInForFile: filename])) {
			ZoomPlugIn* instance = [[plugin alloc] initWithFilename: filename];
			ZoomStoryID* fileID = [instance idForStory];
			
			if (fileID != nil) {
				[[ZoomStoryOrganiser sharedStoryOrganiser] addStory: filename
														  withIdent: fileID
														   organise: [[ZoomPreferences globalPreferences] keepGamesOrganised]];				
			}
		}

		[selectedFiles removeObjectAtIndex:0];
	}
}

// = IB actions =

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url {
	BOOL exists;
	BOOL isDirectory;
	NSString *filename = [url path];
	
	exists = [[NSFileManager defaultManager] fileExistsAtPath: filename
												  isDirectory: &isDirectory];
	if (!exists) return NO;
	
	// Show directories that are not packages
	if (isDirectory) {
		if ([[NSWorkspace sharedWorkspace] isFilePackageAtPath: filename]) {
			return NO;
		} else {
			return YES;
		}
	}
	
	// Don't show non-readable files
	if (![[NSFileManager defaultManager] isReadableFileAtPath: filename]) {
		return NO;
	}
	
	// Show files that have a valid plugin
	Class pluginClass = [[ZoomPlugInManager sharedPlugInManager] plugInForFile: [url path]];
	
	if (pluginClass != nil) {
		return YES;
	}
	
	NSString *urlUTI;
	if (![url getResourceValue:&urlUTI forKey:NSURLTypeIdentifierKey error:NULL]) {
		urlUTI = CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)url.pathExtension, isDirectory ? kUTTypeDirectory : kUTTypeData));
	}
	
	// Show files that we can open with the ZoomClient document type
	NSString* type = @"public.zcode";
	if ([urlUTI isEqualToString:type]) return YES;
	
	type = @"public.blorb.zcode";
	if ([urlUTI isEqualToString:type]) return YES;
	
	type = @"public.blorb.glulx";
	if ([urlUTI isEqualToString:type]) return YES;
	
	type = @"public.blorb";
	if ([urlUTI isEqualToString:type]) return YES;
	
	return NO;
}

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError * _Nullable *)outError {
	if (![self panel: sender shouldEnableURL: url]) {
		return NO;
	}
	
	BOOL exists;
	BOOL isDirectory;
	
	exists = [[NSFileManager defaultManager] fileExistsAtPath: [url path]
												  isDirectory: &isDirectory];
	
	if (!exists) return NO;
	if (isDirectory) return YES;
	
	return YES;
}

- (IBAction) addButtonPressed: (id) sender {
	// Create an open panel
	NSOpenPanel* storiesToAdd;
	NSArray* fileTypes = @[@"public.zcode", @"public.blorb.glulx", @"public.blorb.zcode", @"public.blorb"];
	
	storiesToAdd = [NSOpenPanel openPanel];
	
	[storiesToAdd setAllowsMultipleSelection: YES];
	[storiesToAdd setCanChooseDirectories: YES];
	[storiesToAdd setCanChooseFiles: YES];
	[storiesToAdd setDelegate: self];
	storiesToAdd.allowedFileTypes = fileTypes;
	
	NSURL* path = [[NSUserDefaults standardUserDefaults] URLForKey: addDirectory];
	storiesToAdd.directoryURL = path;
	
	[storiesToAdd beginSheetModalForWindow: self.window completionHandler: ^(NSModalResponse result) {
		if (result != NSModalResponseOK) {
			return;
		}
		
		// Store the defaults
		[[NSUserDefaults standardUserDefaults] setURL: [storiesToAdd directoryURL]
											   forKey: addDirectory];
		
		NSArray<NSURL*> * fileURLs = [storiesToAdd URLs];
		[self addURLs:fileURLs];
	}];
}

- (void) autosaveAlertFinished: (NSWindow *)alert 
					returnCode: (NSModalResponse)returnCode {
	if (returnCode == NSAlertSecondButtonReturn) {
		NSString* filename = [self selectedFilename];
		
		if (![[NSFileManager defaultManager] fileExistsAtPath: filename]) {
			NSLog(@"Couldn't find anything at %@ (looking for IFID: %@)", filename, [self selectedStoryID]);
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = @"Zoom cannot find this story";
			alert.informativeText = [NSString stringWithFormat:@"Zoom was expecting to find the story file for %@ at %@, but it is no longer there. You will need to locate the story in the Finder and load it manually.",
									 [[self selectedStory] title], filename];
			[alert addButtonWithTitle:@"Cancel"];
			[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
				// do nothing
			}];
			return;
		}
		
		// FIXME: multiple selections?
		if (filename) {
			[[NSApp delegate] application: NSApp
								 openFile: filename];
			/*
			[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile: filename
																					display: YES];
		*/
			 
			[self configureFromMainTableSelection];
		}
	}
}

- (IBAction) startNewGame: (id) sender {
	ZoomStoryID* ident = [self selectedStoryID];
	
	if( ident == NULL )
		return;
		
	// If an autosave file exists, query the user
	NSString* autosaveDir = [[ZoomStoryOrganiser sharedStoryOrganiser] directoryForIdent: ident
																				  create: NO];
	NSString* autosaveFile = [autosaveDir stringByAppendingPathComponent: @"autosave.zoomauto"];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath: autosaveFile]) {
		// Autosave file exists - show alert sheet
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = @"An autosave file exists for this game";
		alert.informativeText = @"This game has an autosave file associated with it. Starting a new game will cause this file to be overwritten.";
		[alert addButtonWithTitle:@"Don't start new game"];
		NSButton *desButton = [alert addButtonWithTitle:@"Start new game"];
		if (@available(macOS 11.0, *)) {
			desButton.hasDestructiveAction = YES;
		}
		[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
			[self autosaveAlertFinished:alert.window returnCode:returnCode];
		}];
	} else {
		// Fake alert sheet OK
		[self autosaveAlertFinished: nil
						 returnCode: NSAlertFirstButtonReturn];
	}
}

- (IBAction) restoreAutosave: (id) sender {
	NSString* filename = [self selectedFilename];
	
	// FIXME: multiple selections?, actually save/restore autosaves
	if (filename) {
		[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:filename] display:NO completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
			ZoomClient* newDoc = (id)document;
			
			if ([[newDoc windowControllers] count] == 0) {
				[newDoc makeWindowControllers];
				[newDoc loadDefaultAutosave];
			}
			
			[[[newDoc windowControllers] objectAtIndex: 0] showWindow: self];
			
			[self configureFromMainTableSelection];
		}];
	}
}

- (IBAction) searchFieldChanged: (id) sender {
	if (browserOn) {
		
	} else {
		[self reloadTableData]; [mainTableView reloadData];		
	}
}

- (IBAction) changeFilter1: (id) sender {
	NSString* filterName = [ZoomStory keyForTag: [sender tag]];
	
	NSString* filterTitle = [ZoomStory nameForKey: filterName];
	
	if (!filterName || !filterTitle) {
		return;
	}
	
	NSTableColumn* filterColumn = [[filterTable1 tableColumns] objectAtIndex: 0];

	[filterColumn setIdentifier: filterName];
	[self setTitle: filterTitle
		  forTable: filterTable1];
	//[[filterColumn headerCell] setStringValue: filterTitle];
	
	[filterTable1 selectRowIndexes: [NSIndexSet indexSetWithIndex: 0] byExtendingSelection: NO];
	[filterTable2 selectRowIndexes: [NSIndexSet indexSetWithIndex: 0] byExtendingSelection: NO];
	
	[self reloadTableData]; [mainTableView reloadData];
}

- (IBAction) changeFilter2: (id) sender {
	NSString* filterName = [ZoomStory keyForTag: [sender tag]];
	
	NSString* filterTitle = [ZoomStory nameForKey: filterName];
	
	if (!filterName || !filterTitle) {
		return;
	}
	
	NSTableColumn* filterColumn = [[filterTable2 tableColumns] objectAtIndex: 0];
	
	[filterColumn setIdentifier: filterName];
	[self setTitle: filterTitle
		  forTable: filterTable2];
	//[[filterColumn headerCell] setStringValue: filterTitle];
	
	[filterTable2 selectRowIndexes: [NSIndexSet indexSetWithIndex: 0] byExtendingSelection: NO];
	
	[self reloadTableData]; [mainTableView reloadData];
}

// = Notifications =

- (void) queueStoryUpdate {
	// Queues an update to run next time through the run loop
	if (!queuedUpdate) {
		[[NSRunLoop currentRunLoop] performSelector: @selector(finishUpdatingStoryList:)
											 target: self
										   argument: self
											  order: 128
											  modes: [NSArray arrayWithObjects: NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil]];
		queuedUpdate = YES;
	}	
}

- (void) finishUpdatingStoryList: (id) sender {
	queuedUpdate = NO;
	
	[mainTableView reloadData];
	[self configureFromMainTableSelection];	
}

- (void) storyListChanged: (NSNotification*) not {
	needsUpdating = YES;
	
	[self queueStoryUpdate];
	//[self finishUpdatingStoryList: self];
}

- (void) storyProgressChanged: (NSNotification*) not {
	NSDictionary* userInfo = [not userInfo];
	BOOL activated = [[userInfo objectForKey: @"ActionStarting"] boolValue];
	
	if (activated) {
		indicatorCount++;
	} else {
		indicatorCount--;
	}
		
	if (indicatorCount <= 0) {
		indicatorCount = 0;
		[progressIndicator stopAnimation: self];
	} else {
		[progressIndicator startAnimation: self];
	}
}

- (void)windowDidBecomeMain:(NSNotification *)aNotification {
	[[ZoomGameInfoController sharedGameInfoController] setInfoOwner: self];
	[[ZoomNotesController sharedNotesController] setInfoOwner: self];
	[self configureFromMainTableSelection];
}

- (void)windowDidResignMain:(NSNotification *)aNotification {
	if ([[ZoomGameInfoController sharedGameInfoController] infoOwner] == self) {
		[[ZoomGameInfoController sharedGameInfoController] setGameInfo: nil];
		[[ZoomGameInfoController sharedGameInfoController] setInfoOwner: nil];
	}

	if ([[ZoomNotesController sharedNotesController] infoOwner] == self) {
		[[ZoomNotesController sharedNotesController] setGameInfo: nil];
		[[ZoomNotesController sharedNotesController] setInfoOwner: nil];
	}
}

// = Our life as a data source =
- (ZoomStory*) storyForID: (ZoomStoryID*) ident {
	ZoomStoryOrganiser* org = [ZoomStoryOrganiser sharedStoryOrganiser];
	
	NSString* filename = [org filenameForIdent: ident];
	ZoomStory* story = [(ZoomAppDelegate*)[NSApp delegate] findStory: ident];
	
	if (filename == nil) {
		filename = @"No filename";
	}
	
	if (story == nil) {
		Class pluginClass = [[ZoomPlugInManager sharedPlugInManager] plugInForFile: filename];
		ZoomPlugIn* pluginInstance = pluginClass?[[pluginClass alloc] initWithFilename: filename]:nil;
		
		if (pluginInstance) {
			story = [pluginInstance defaultMetadata];
		} else {
			story = [ZoomStory defaultMetadataForFile: filename];
		}
		
		// Store this in the user metadata for later
		NSLog(@"Failed to find story for ID: %@", ident);
		if (story != nil) {
			[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] copyStory: story];
			[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
			
			story = [[(ZoomAppDelegate*)[NSApp delegate] userMetadata] findOrCreateStory: [story storyID]];
		}
	}
	
	return story;
}

- (void) sortTableData {
	if (sortColumn != nil) {
		[storyList sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
			ZoomStory* sA = [self storyForID: obj1];
			ZoomStory* sB = [self storyForID: obj2];
			
			NSString* cA = [sA objectForKey: sortColumn];
			NSString* cB = [sB objectForKey: sortColumn];

			if ([cA length] != [cB length]) {
				if ([cA length] == 0) {
					return NSOrderedDescending;
				} else if ([cB length] == 0) {
					return NSOrderedAscending;
				}
			}
			
			NSComparisonResult res = [cA caseInsensitiveCompare: cB];
			
			if (res == NSOrderedSame) {
				return [[sA title] caseInsensitiveCompare: [sB title]];
			} else {
				return res;
			}
		}];
	}
}

- (BOOL) filterTableDataPass1 {
	// Filter using the selection from the first filter table
	NSString* filterKey = [[[filterTable1 tableColumns] objectAtIndex: 0] identifier];
	
	// Get the selected items from the first filter table
	NSMutableSet* filterFor = [NSMutableSet set];
	NSIndexSet* selEnum = [filterTable1 selectedRowIndexes];
	
	{
		NSInteger selRow = selEnum.firstIndex;
		while (selRow != NSNotFound) {
			if (selRow == 0) {
				// All selected - no filtering
				[filterTable1 selectRowIndexes: [NSIndexSet indexSetWithIndex: 0] byExtendingSelection: NO];
				return NO;
			}
			
			[filterFor addObject: [filterSet1 objectAtIndex: selRow-1]];
			selRow = [selEnum indexGreaterThanIndex:selRow];
		}
	}
	
	// Remove anything that doesn't match the filter
	NSInteger num;
	
	for (num = 0; num < [storyList count]; num++) {
		ZoomStoryID* ident = [storyList objectAtIndex: num];
		
		ZoomStory* thisStory = [self storyForID: ident];
		NSString* storyKey = [thisStory objectForKey: filterKey];
		
		if (![filterFor containsObject: storyKey]) {
			[storyList removeObjectAtIndex: num];
			num--;
		}
	}
	
	return YES;
}

- (BOOL) filterTableDataPass2 {
	// Filter using the selection from the second filter table
	NSString* filterKey = [[[filterTable2 tableColumns] objectAtIndex: 0] identifier];
	
	// Get the selected items from the first filter table
	NSMutableSet* filterFor = [NSMutableSet set];
	NSIndexSet* selEnum = [filterTable2 selectedRowIndexes];
	
	BOOL tableFilter;
	
	{
		NSInteger selRow = selEnum.firstIndex;
		tableFilter = YES;
		while (selRow != NSNotFound) {
			if (selRow == 0) {
				// All selected - no filtering
				[filterTable2 selectRowIndexes: [NSIndexSet indexSetWithIndex:0] byExtendingSelection: NO];
				tableFilter = NO;
				break;
			}
			
			[filterFor addObject: [filterSet2 objectAtIndex: selRow-1]];
			selRow = [selEnum indexGreaterThanIndex:selRow];
		}
	}
	
	// Remove anything that doesn't match the filter (second filter table *or* the search field)
	NSInteger num;
	NSString* searchText = [searchField stringValue];
	
	if (!tableFilter && [searchText length] <= 0) return NO; // Nothing to do
		
	for (num = 0; num < [storyList count]; num++) {
		ZoomStoryID* ident = [storyList objectAtIndex: num];
		
		ZoomStory* thisStory = [self storyForID: ident];
		
		// Filter table
		NSString* storyKey = [thisStory objectForKey: filterKey];
		
		if (tableFilter && ![filterFor containsObject: storyKey]) {
			[storyList removeObjectAtIndex: num];
			num--;
			continue;
		}
		
		// Search field
		if ([searchText length] > 0) {
			if (![thisStory containsText: searchText]) {
				[storyList removeObjectAtIndex: num];
				num--;
				continue;				
			}
		}
	}
	
	return tableFilter;
}

- (void) filterTableData {
	[self filterTableDataPass1];
	[self filterTableDataPass2];
}

- (void) reloadTableData {
	ZoomStoryOrganiser* org = [ZoomStoryOrganiser sharedStoryOrganiser];
	
	needsUpdating = NO;
	
	// Store the previous list of selected IDs
	NSMutableArray* previousIDs = [NSMutableArray array];
	NSIndexSet *selRowIdxs = [mainTableView selectedRowIndexes];
	
	{
		NSInteger currentIdx = selRowIdxs.firstIndex;
		while (currentIdx != NSNotFound) {
			[previousIDs addObject: [storyList objectAtIndex: currentIdx]];
			currentIdx = [selRowIdxs indexGreaterThanIndex:currentIdx];
		}
	}

	// Free up the previous table data
	storyList = [[NSMutableArray alloc] init];
	
	filterSet1 = [[NSMutableArray alloc] init];
	filterSet2 = [[NSMutableArray alloc] init];
	
	// Repopulate the table
	NSString* filterKey1 = [[[filterTable1 tableColumns] objectAtIndex: 0] identifier];
	NSString* filterKey2 = [[[filterTable2 tableColumns] objectAtIndex: 0] identifier];
	
	for (ZoomStoryID* ident in org.storyIdents) {
		ZoomStory* thisStory = [self storyForID: ident];
		
		[storyList addObject: ident];
		
		NSString* filterItem1 = [thisStory objectForKey: filterKey1];
		
		if ([filterItem1 length] != 0 && [filterSet1 indexOfObject: filterItem1] == NSNotFound) [filterSet1 addObject: filterItem1];
	}
	
	// Sort the first filter set
	[filterSet1 sortUsingSelector: @selector(caseInsensitiveCompare:)];
	[filterTable1 reloadData];
	
	// Filter the table as required
	BOOL wasFiltered = isFiltered;
	isFiltered = NO;
	isFiltered = [self filterTableDataPass1] || isFiltered;
	
	// Generate + sort the second filter set
	for (ZoomStoryID* ident in storyList) {
		ZoomStory* thisStory = [self storyForID: ident];
		NSString* filterItem2 = [thisStory objectForKey: filterKey2];		
		if ([filterItem2 length] != 0 && [filterSet2 indexOfObject: filterItem2] == NSNotFound) [filterSet2 addObject: filterItem2];
	}
	
	[filterSet2 sortUsingSelector: @selector(caseInsensitiveCompare:)];
	[filterTable2 reloadData];	

	// Continue filtering
	isFiltered = [self filterTableDataPass2] || isFiltered;

	// Sort the table as required
	[self sortTableData];

	// Joogle the selection
	{
		NSMutableIndexSet *rowIdxs = [NSMutableIndexSet indexSet];
		
		for (ZoomStoryID* selID in previousIDs) {
			NSUInteger index = [storyList indexOfObject: selID];
			
			if (index != NSNotFound) {
				[rowIdxs addIndex:index];
			}
		}
		[mainTableView selectRowIndexes: rowIdxs
				   byExtendingSelection: NO];
	}

	
	// Highlight the 'filter' button if some filtering has occurred
	if (isFiltered != wasFiltered) {
		// Prepare to animate to the new style of filtering
		ZoomFlipView* matrixAnimation = [[ZoomFlipView alloc] init];
		[matrixAnimation prepareToAnimateView: flipButtonMatrix];
		
		// Get the cell containing the 'filter' button
		NSButtonCell* filterButtonCell = [flipButtonMatrix cellWithTag: 2];
		
		// Set its text colour to dark red if filtered
		NSColor* filterColour;
		
		if (isFiltered) {
			filterColour = [NSColor colorWithDeviceRed: 0.7 green: 0 blue: 0 alpha: 1.0];
		} else {
			filterColour = [NSColor blackColor];
		}
		
		NSMutableAttributedString* filterButtonTitle = [[filterButtonCell attributedTitle] mutableCopy];
		[filterButtonTitle addAttributes: [NSDictionary dictionaryWithObjectsAndKeys: filterColour, NSForegroundColorAttributeName, nil]
								   range: NSMakeRange(0, [filterButtonTitle length])];
		
		[filterButtonCell setAttributedTitle: filterButtonTitle];
		
		// Finish the animation
		[matrixAnimation animateTo: flipButtonMatrix
							 style: ZoomAnimateFade];
	}
	
	// Tidy up (prevents a dumb infinite loop possibility)
	[[NSRunLoop currentRunLoop] cancelPerformSelectorsWithTarget: self];	
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
	if (needsUpdating) [self reloadTableData];
	
	if (aTableView == mainTableView) {
		return [storyList count];
	} else if (aTableView == filterTable1) {
		return [filterSet1 count]+1;
	} else if (aTableView == filterTable2) {
		return [filterSet2 count]+1;
	} else {
		return 0; // Unknown table view
	}
}

- (id)				tableView: (NSTableView *) aTableView 
	objectValueForTableColumn: (NSTableColumn *) aTableColumn 
						  row: (NSInteger) rowIndex {
		
	// if (needsUpdating) [self reloadTableData];

	if (aTableView == mainTableView) {
		// Retrieve row details
		NSString* rowID = [aTableColumn identifier];
		
		ZoomStoryID* ident = [storyList objectAtIndex: rowIndex];
		ZoomStory* story = [self storyForID: ident];		
				
		// Return the value of the appropriate field
		if ([rowID isEqualToString: @"rating"]) {
			return @([story rating]);
		} else {
			return [story objectForKey: rowID];
		}
	} else if (aTableView == filterTable1) {
		if (rowIndex == 0) return [NSString stringWithFormat: @"All (%lu items)", (unsigned long)[filterSet1 count]];
		return [filterSet1 objectAtIndex: rowIndex-1];
	} else if (aTableView == filterTable2) {
		if (rowIndex == 0) return [NSString stringWithFormat: @"All (%lu items)", (unsigned long)[filterSet2 count]];
		return [filterSet2 objectAtIndex: rowIndex-1];
	} else {
		return nil; // Unknown table view
	}
}

- (void)				tableView:(NSTableView *)tableView 
   mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn {
	if (tableView == mainTableView) {
		NSString* columnID = [tableColumn identifier];
		
		if (sortColumn == nil || ![sortColumn isEqualToString: columnID]) {
			[mainTableView setHighlightedTableColumn: tableColumn];
			sortColumn = [columnID copy];

			[[NSUserDefaults standardUserDefaults] setObject: sortColumn
													  forKey: sortGroup];

			//[self sortTableData];
			[self reloadTableData];
			[mainTableView reloadData];
		}
	}
}

- (void) updateButtons {
	if (browserOn) {
		// None of the lower row of buttons work when the IFDB browser is displayed
		[continueButton setEnabled: NO];
		[newgameButton setEnabled: NO];
		[addButton setEnabled: NO];
		[infoButton setEnabled: NO];
	} else {
		// The add and info buttons always work
		[addButton setEnabled: YES];
		[infoButton setEnabled: YES];		

		// The other buttons depend on the current selection
		NSIndexSet* rowEnum = [mainTableView selectedRowIndexes];
		NSInteger numSelected = 0;
		
		NSInteger row = rowEnum.firstIndex;
		
		[continueButton setEnabled: NO];
		[newgameButton setEnabled: NO];
		
		while (row != NSNotFound) {
			numSelected++;
			
			ZoomStoryID* ident = [storyList objectAtIndex: row];
			NSString* filename = [[ZoomStoryOrganiser sharedStoryOrganiser] filenameForIdent: ident];
			
			if ([[NSDocumentController sharedDocumentController] documentForURL: [NSURL fileURLWithPath:filename]] != nil) {
				[continueButton setEnabled: YES];
			} else {
				[newgameButton setEnabled: YES];
				
				NSString* autosaveDir = [[ZoomStoryOrganiser sharedStoryOrganiser] directoryForIdent: ident
																							  create: NO];
				NSString* autosaveFile = [autosaveDir stringByAppendingPathComponent: @"autosave.zoomauto"];
				
				if ([[NSFileManager defaultManager] fileExistsAtPath: autosaveFile]) {
					// Can restore an autosave
					[continueButton setEnabled: YES];
				}
			}
			row = [rowEnum indexGreaterThanIndex:row];
		}
	}
}

- (void) configureFromMainTableSelection {
	ZoomStoryOrganiser* org = [ZoomStoryOrganiser sharedStoryOrganiser];

	if (needsUpdating) [self reloadTableData];
	[self updateButtons];
	NSInteger numSelected = [mainTableView numberOfSelectedRows];
	
	NSImage* coverPicture = nil;
	
	NSString* comment;
	NSString* teaser;
	NSString* description;
	
	if (numSelected == 1) {
		ZoomStoryID* ident = [storyList objectAtIndex: [mainTableView selectedRow]];
		ZoomStory* story = [self storyForID: ident];

		if ([[self window] isMainWindow] && [[ZoomGameInfoController sharedGameInfoController] infoOwner] == self) {
			[[ZoomGameInfoController sharedGameInfoController] setGameInfo: story];
		}

		if ([[self window] isMainWindow] && [[ZoomNotesController sharedNotesController] infoOwner] == self) {
			[[ZoomNotesController sharedNotesController] setGameInfo: story];
		}
		
		// Set up the comment, teaser and description views
		comment = [story comment];
		teaser = [story teaser];
		description = [story description];
		
		// Set up the save preview view
		NSString* dir = [[ZoomStoryOrganiser sharedStoryOrganiser] directoryForIdent: ident 
																			  create: NO];
		[previewView setDirectoryToUse: [dir stringByAppendingPathComponent: @"Saves"]];
		
		if ([previewView saveGamesAvailable] != saveGamesAvailable) {
			// Set the 'saves' tab to dark blue if save games are available
			saveGamesAvailable = [previewView saveGamesAvailable];

			// Prepare to animate to the 'saves available' button
			ZoomFlipView* matrixAnimation = [[ZoomFlipView alloc] init];
			[matrixAnimation prepareToAnimateView: flipButtonMatrix];
			
			// Get the cell containing the 'save' button
			NSButtonCell* filterButtonCell = [flipButtonMatrix cellWithTag: 0];
			
			// Set its text colour
			NSColor* filterColour;
			
			if (saveGamesAvailable) {
				filterColour = [NSColor colorWithDeviceRed: 0.7 green: 0 blue: 0.3 alpha: 1.0];
			} else {
				filterColour = [NSColor blackColor];
			}
			
			NSMutableAttributedString* filterButtonTitle = [[filterButtonCell attributedTitle] mutableCopy];
			[filterButtonTitle addAttributes: [NSDictionary dictionaryWithObjectsAndKeys: filterColour, NSForegroundColorAttributeName, nil]
									   range: NSMakeRange(0, [filterButtonTitle length])];
			
			[filterButtonCell setAttributedTitle: filterButtonTitle];
			
			// Finish the animation
			[matrixAnimation animateTo: flipButtonMatrix
								 style: ZoomAnimateFade];
		} 
		
		// Set up the extra blorb resources display
		[resourceDrop setDroppedFilename: [story objectForKey: @"ResourceFilename"]];
		[resourceDrop setEnabled: YES];
		
		// Set up the cover picture
		NSString* filename = [org filenameForIdent: ident];
		ZoomPlugIn* plugin = [[ZoomPlugInManager sharedPlugInManager] instanceForFile: filename];
		if (plugin == nil) {
			// If there's no plugin, try loading the file as a blorb
			int coverPictureNumber = [story coverPicture];
			
			ZoomBlorbFile* decodedFile = [[ZoomBlorbFile alloc] initWithContentsOfFile: filename];
			
			// Try to retrieve the frontispiece tag (overrides metadata if present)
			NSData* front = [decodedFile dataForChunkWithType: @"Fspc"];
			if (front != nil && [front length] >= 4) {
				const unsigned char* fpc = [front bytes];
				
				coverPictureNumber = (((int)fpc[0])<<24)|(((int)fpc[1])<<16)|(((int)fpc[2])<<8)|(((int)fpc[3])<<0);
			}
			
			if (coverPictureNumber >= 0) {			
				// Attempt to retrieve the cover picture image
				if (decodedFile != nil) {
					NSData* coverPictureData = [decodedFile imageDataWithNumber: coverPictureNumber];
					
					if (coverPictureData) {
						coverPicture = [[NSImage alloc] initWithData: coverPictureData];
						
						// Sometimes the image size and pixel size do not match up
						NSImageRep* coverRep = [[coverPicture representations] objectAtIndex: 0];
						NSSize pixSize = NSMakeSize([coverRep pixelsWide], [coverRep pixelsHigh]);
						
						if (!NSEqualSizes(pixSize, [coverPicture size])) {
							[coverPicture setSize: pixSize];
						}
					}
				}
			}
		} else {
			coverPicture = [plugin coverImage];
		}
	} else {
		if ([[self window] isMainWindow] && [[ZoomGameInfoController sharedGameInfoController] infoOwner] == self) {
			[[ZoomGameInfoController sharedGameInfoController] setGameInfo: nil];
		}
		
		if ([[self window] isMainWindow] && [[ZoomNotesController sharedNotesController] infoOwner] == self) {
			[[ZoomNotesController sharedNotesController] setGameInfo: nil];
		}
		
		comment = @"";
		teaser = @"";
		description = @"";

		[previewView setDirectoryToUse: nil];
		
		[resourceDrop setDroppedFilename: nil];
		[resourceDrop setEnabled: NO];
	}
	
	if (comment == nil) comment = @"";
	if (teaser == nil) teaser = @"";
	if (description == nil) description = @"";
	
	// Set the game details
	BOOL flipToDescription = NO;
	NSMutableAttributedString* gameDetails = [[NSMutableAttributedString alloc] init];
	
	NSFont* titleFont = [NSFont boldSystemFontOfSize: 14];
	NSFont* yearFont = [NSFont systemFontOfSize: 10];
	NSFont* descFont = [NSFont systemFontOfSize: 11];
	
	if (numSelected >= 1) {
		// Get the story and ident
		NSIndexSet* rowEnum = [mainTableView selectedRowIndexes];
		NSInteger row = rowEnum.firstIndex;
		BOOL extraNewline = NO;
		NSAttributedString* newlineString = [[NSAttributedString alloc] initWithString: @"\n"
																			 attributes: [NSDictionary dictionaryWithObjectsAndKeys:
																				 @(ZoomNoField), ZoomFieldAttribute,
																				 @0, ZoomRowAttribute,
																				 nil]];
		
		while (row != NSNotFound) {
			ZoomStoryID* ident = [storyList objectAtIndex: row];
			ZoomStory* story = [self storyForID: ident];
			
			// Append the title
			NSString* title = [story title];
			//NSString* extraText;
			if (title == nil) title = @"Untitled";
			if (extraNewline) {
				[gameDetails appendAttributedString: newlineString];
				[gameDetails appendAttributedString: newlineString];
			}
			[gameDetails appendAttributedString: [[NSAttributedString alloc] initWithString: title
																				  attributes: [NSDictionary dictionaryWithObjectsAndKeys:
																					  titleFont, NSFontAttributeName, 
																					  @(ZoomTitleField), ZoomFieldAttribute,
																					  @(row), ZoomRowAttribute,
																					  story, ZoomStoryAttribute,
																					  nil]]];
			[gameDetails appendAttributedString: [[NSAttributedString alloc] initWithString: @"\n"
																				  attributes: [NSDictionary dictionaryWithObjectsAndKeys:
																					  @(ZoomTitleNewlineField), ZoomFieldAttribute,
																					  @(row), ZoomRowAttribute,
																					  story, ZoomStoryAttribute,
																					  nil]]];
				
			// Append the year of publication
			int year = [story year];
			if (year > 0) {
				NSString* yearText = [NSString stringWithFormat: @"%i", year];
				[gameDetails appendAttributedString: [[NSAttributedString alloc] initWithString: yearText
																					  attributes: [NSDictionary dictionaryWithObjectsAndKeys: 
																						  yearFont, NSFontAttributeName, 
																						  @(ZoomYearField), ZoomFieldAttribute,
																						  @(row), ZoomRowAttribute,
																						  story, ZoomStoryAttribute,
																						  nil]]];
				[gameDetails appendAttributedString: [[NSAttributedString alloc] initWithString: @"\n"
																					  attributes: [NSDictionary dictionaryWithObjectsAndKeys:
																						  @(ZoomYearNewlineField), ZoomFieldAttribute,
																						  @(row), ZoomRowAttribute,
																						  story, ZoomStoryAttribute,
																						  nil]]];
			}
			
			// Append the description
			NSString* descText = [story description];
			if (descText == nil) descText = [story teaser];
			if (descText == nil || [descText length] == 0) descText = @"";
			if (descText != nil) {
				[gameDetails appendAttributedString: newlineString];
				[gameDetails appendAttributedString: [[NSAttributedString alloc] initWithString: descText
																					  attributes: [NSDictionary dictionaryWithObjectsAndKeys: 
																						  descFont, NSFontAttributeName, 
																						  @(ZoomDescriptionField), ZoomFieldAttribute,
																						  @(row), ZoomRowAttribute,
																						  story, ZoomStoryAttribute,
																						  nil]]];
				
				if ([descText length] > 0) flipToDescription = YES;
			}
			extraNewline = YES;
			
			// Always flip if the description view is already displayed
			if (topPanelView == infoView) flipToDescription = YES;
			row = [rowEnum indexGreaterThanIndex:row];
		}
	} else {
		// Note that there are multiple or no games selected
		NSString* desc = @"Multiple games selected";
		if (numSelected == 0) desc = @"No game selected";
		[gameDetails appendAttributedString: [[NSAttributedString alloc] initWithString: desc
																			  attributes: [NSDictionary dictionaryWithObjectsAndKeys: descFont, NSFontAttributeName, nil]]];
	}
	
	if (![[gameDetailView string] isEqualToString: [gameDetails string]]) {
		if (flipToDescription) [flipView prepareToAnimateView: topPanelView];
		[[gameDetailView textStorage] setDelegate: nil];
		[[gameDetailView textStorage] setAttributedString: gameDetails];
		[[gameDetailView textStorage] setDelegate: self];
	} else {
		flipToDescription = NO;
	}
	
	if (coverPicture == nil) {
		// TODO: set this to a suitable picture for the game format
		coverPicture = [NSImage imageNamed: @"zoom-app"];
	}
	
	// Set the cover picture
	if (coverPicture) {
		[gameImageView setImage: coverPicture];
		
		// Setup the picture preview window
		[picturePreviewView setImage: coverPicture];
		
		NSSize previewSize = [coverPicture size];
		NSSize screenSize = [[picturePreview screen] frame].size;
		
		if (previewSize.width > screenSize.width-128.0) {
			CGFloat ratio = (screenSize.width-128.0)/previewSize.width;

			previewSize.width = floor(previewSize.width*ratio);
			previewSize.height = floor(previewSize.height*ratio);
		}
		
		if (previewSize.height > screenSize.height-128.0) {
			CGFloat ratio = (screenSize.height-128.0)/previewSize.height;
			
			previewSize.width = floor(previewSize.width*ratio);
			previewSize.height = floor(previewSize.height*ratio);
		}
		
		[picturePreview setContentSize: previewSize];
	} else {
		[gameImageView setImage: nil];
		
		[picturePreview orderOut: self];
	}
	
	// Do no flipping if the iFiction window is not active (prevents apparently mysterious behaviour)
	if (flipToDescription && ![[self window] isKeyWindow]) flipToDescription = NO;
	
	// Flip any views that need flipping
	if (flipToDescription) {
		[[gameDetailView layoutManager] setBackgroundLayoutEnabled: NO];
		[infoView setFrame: [topPanelView frame]];
		[flipView animateTo: infoView
					  style: ZoomAnimateFade];
		[flipButtonMatrix selectCellWithTag: 1];
		topPanelView = infoView;
		[[gameDetailView layoutManager] setBackgroundLayoutEnabled: YES];
	}
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	NSTableView* tableView = [aNotification object];
	
	if (tableView == mainTableView) {
		[self configureFromMainTableSelection];
	} else if (tableView == filterTable1 || tableView == filterTable2) {
		if (tableView == filterTable1) {
			[filterTable2 selectRowIndexes: [NSIndexSet indexSetWithIndex:0] byExtendingSelection: NO];
		}
		
		[self reloadTableData]; [mainTableView reloadData];
	} else {
		// Zzzz
	}
}

- (void)tableView:(NSTableView *)tableView 
   setObjectValue:(id)anObject 
   forTableColumn:(NSTableColumn*)aTableColumn 
			  row:(NSInteger)rowIndex {
	//if (needsUpdating) [self reloadTableData];

	if (tableView == mainTableView) {		
		ZoomStoryID* ident = [storyList objectAtIndex: rowIndex];
		ZoomStory* story = [self storyForID: ident];
		
		story = [self createStoryCopy: story];
		
		[story setObject: anObject
				  forKey: [aTableColumn identifier]];
	}

	[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
}

-(id<NSPasteboardWriting>)tableView:(NSTableView *)tv pasteboardWriterForRow:(NSInteger)row
{
	if(tv != mainTableView )
		return nil;
	
	if( ![[ZoomPreferences globalPreferences] keepGamesOrganised] )
		return nil;

	[mainTableView cancelEditTimer];

	ZoomStoryID* ident = [storyList objectAtIndex:row];
	NSString* gamedir = [[ZoomStoryOrganiser sharedStoryOrganiser] directoryForIdent: ident create: NO];
	if( gamedir != NULL )
	{
		return [NSURL fileURLWithPath: gamedir];
	}

	return nil;
}

- (NSDragOperation)tableView:(NSTableView *)tv
                validateDrop:(id <NSDraggingInfo>)sender
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)op {
    NSPasteboard * pasteboard = [sender draggingPasteboard];
    NSArray * types = [pasteboard types];
	
	if( op == NSTableViewDropOn ) 
	{
		[tv setDropRow:row dropOperation:NSTableViewDropAbove];
	}
	
	if( [sender draggingSource] == mainTableView )
	{
		return NSDragOperationNone;
	}
	
	if( [types containsObject:NSPasteboardTypeFileURL] )
	{
		return NSDragOperationCopy;
	}
	else
	{
		return NSDragOperationNone;
	}
}

- (BOOL)tableView:(NSTableView *)tv 
	   acceptDrop:(id <NSDraggingInfo>)sender
			  row:(NSInteger)row
	dropOperation:(NSTableViewDropOperation)op {
    NSPasteboard * pasteboard = [sender draggingPasteboard];
	NSArray<NSURL*> * fileURLs = [pasteboard readObjectsForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
	[self addURLs:fileURLs];

	return YES;
}


#pragma mark -
/////////////////////////////////////////////////////////////////////////////
// split view 
//

// setupSplitView
//
//

- (void) setupSplitView {
	NSNumber * split_view_percent_number = [[NSUserDefaults standardUserDefaults] objectForKey:@"iFictionSplitViewPercentage"];
	NSNumber * split_view_collapsed_number = [[NSUserDefaults standardUserDefaults] objectForKey:@"iFictionSplitViewCollapsed"];
	
	if( split_view_percent_number && split_view_collapsed_number )
	{
		splitViewPercentage = [split_view_percent_number floatValue];
		splitViewCollapsed = [split_view_collapsed_number boolValue];
		
		if( splitViewCollapsed )
		{
			[splitView resizeSubviewsToPercentage:0.0];
		}
		else
		{
			[splitView resizeSubviewsToPercentage:splitViewPercentage];
		}
	}
	else
	{
		splitViewPercentage = [splitView getSplitPercentage];
		splitViewCollapsed = NO;
	}
}

// splitViewDidResizeSubviews
//
//

- (void)splitViewDidResizeSubviews:(NSNotification *)notification {
	CGFloat pos = [splitView getSplitPercentage];
	
	if( pos == 0.0 )
	{
		[self collapseSplitView];
	}
}

// splitViewMouseDownProcessed
//
//

- (void)splitViewMouseDownProcessed:(NSSplitView *)aSplitView 
{
    CGFloat pos = [splitView getSplitPercentage];
	
	if( pos > 0.0 ) 
	{
		splitViewPercentage = pos;
		splitViewCollapsed = NO;
	
		[[NSUserDefaults standardUserDefaults] setFloat: splitViewPercentage forKey:@"iFictionSplitViewPercentage"];
		[[NSUserDefaults standardUserDefaults] setBool: splitViewCollapsed forKey:@"iFictionSplitViewCollapsed"];
	}
}

// splitViewDoubleClickedOnDivider
//
//

- (void)splitViewDoubleClickedOnDivider:(NSSplitView *)aSplitView {
    CGFloat pos = [splitView getSplitPercentage];
	
    if (pos == 0.0) 
	{
        [splitView resizeSubviewsToPercentage:splitViewPercentage];
    } 
	else 
	{
		[splitView resizeSubviewsToPercentage:0.0];
		[self collapseSplitView];
    }
}

// collapseSplitView
//
//

- (void)collapseSplitView {
	splitViewCollapsed = YES;

	[[NSUserDefaults standardUserDefaults] setFloat: splitViewPercentage forKey:@"iFictionSplitViewPercentage"];
	[[NSUserDefaults standardUserDefaults] setBool: splitViewCollapsed forKey:@"iFictionSplitViewCollapsed"];
		
	// reset browser selection, since the browser is getting hidden
	[filterTable2 selectRowIndexes: [NSIndexSet indexSetWithIndex:0] byExtendingSelection: NO];
	[filterTable1 selectRowIndexes: [NSIndexSet indexSetWithIndex:0] byExtendingSelection: NO];
		
	[self reloadTableData]; [mainTableView reloadData];
}

#pragma mark -

- (IBAction) updateGameInfo: (id) sender {
	[self configureFromMainTableSelection];
}

// = GameInfo window actions =

- (IBAction) infoNameChanged: (id) sender {
	if ([self selectedStory] == nil) return;
	
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setTitle: [[ZoomGameInfoController sharedGameInfoController] title]];
	[self reloadTableData]; [mainTableView reloadData];
	[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoHeadlineChanged: (id) sender {
	if ([self selectedStory] == nil) return;
	
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setHeadline: [[ZoomGameInfoController sharedGameInfoController] headline]];
	[self reloadTableData]; [mainTableView reloadData];
	[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoAuthorChanged: (id) sender {
	if ([self selectedStory] == nil) return;
	
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setAuthor: [[ZoomGameInfoController sharedGameInfoController] author]];
	[self reloadTableData]; [mainTableView reloadData];
	[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoGenreChanged: (id) sender {
	if ([self selectedStory] == nil) return;
	
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setGenre: [[ZoomGameInfoController sharedGameInfoController] genre]];
	[self reloadTableData]; [mainTableView reloadData];
	[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoYearChanged: (id) sender {
	if ([self selectedStory] == nil) return;
	
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setYear: [[ZoomGameInfoController sharedGameInfoController] year]];
	[self reloadTableData]; [mainTableView reloadData];
	[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoGroupChanged: (id) sender {
	if ([self selectedStory] == nil) return;
	
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setGroup: [[ZoomGameInfoController sharedGameInfoController] group]];
	[self reloadTableData]; [mainTableView reloadData];
	[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoCommentsChanged: (id) sender {
	if ([self selectedStory] == nil) return;
	
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setComment: [[ZoomGameInfoController sharedGameInfoController] comments]];
	[self reloadTableData]; [mainTableView reloadData];
	[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoTeaserChanged: (id) sender {
	if ([self selectedStory] == nil) return;
	
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setTeaser: [[ZoomGameInfoController sharedGameInfoController] teaser]];
	[self reloadTableData]; [mainTableView reloadData];
	[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoResourceChanged: (id) sender {
	if ([self selectedStory] == nil) return;
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	
	// Update the resource path
	[story setObject: [[ZoomGameInfoController sharedGameInfoController] resourceFilename]
				 forKey: @"ResourceFilename"];
	[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
	
	// Perform organisation
	if ([[ZoomPreferences globalPreferences] keepGamesOrganised]) {
		[[ZoomStoryOrganiser sharedStoryOrganiser] organiseStory: [self selectedStory]];
	}
}

- (IBAction) infoZarfRatingChanged: (id) sender {
	if ([self selectedStory] == nil) return;
	
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setZarfian: [[ZoomGameInfoController sharedGameInfoController] zarfRating]];
	[self reloadTableData]; [mainTableView reloadData];
	[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
}

- (IBAction) infoMyRatingChanged: (id) sender {
	if ([self selectedStory] == nil) return;
	
	ZoomStory* story = [self createStoryCopy: [self selectedStory]];
	[story setRating: [[ZoomGameInfoController sharedGameInfoController] rating]];
	[self reloadTableData]; [mainTableView reloadData];
	[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
}

// = NSText delegate =

- (BOOL)    	textView:(NSTextView *)aTextView
 shouldChangeTextInRange:(NSRange)affectedCharRange
	   replacementString:(NSString *)replacementString {
	if (aTextView == gameDetailView) {
		// If there are no selected stories, then do not allow any editing
		if ([mainTableView numberOfSelectedRows] <= 0) return NO;
		
		// If we're editing only one row, and we're at the very end of the text, then we're editing the decription, and that's OK
		if ([mainTableView numberOfSelectedRows] == 1) {
			if (affectedCharRange.location == [[aTextView textStorage] length]) return YES;
		}
		
		// If we're inserting, then move the affected character range appropriately
		BOOL newlineEditsValid = NO;
		if (affectedCharRange.length == 0) {
			newlineEditsValid = YES;
			if (affectedCharRange.location > 0
				&& (affectedCharRange.location == [[aTextView textStorage] length]
					|| [[[aTextView textStorage] string] characterAtIndex: affectedCharRange.location] == '\n')) {
				affectedCharRange.location--;
			}
			affectedCharRange.length = 1;
		}
		
		// Only allow editing if the row and field are consistent across the range
		NSRange effectiveRange;
		NSNumber* initialRow = [[[aTextView textStorage] attributesAtIndex: affectedCharRange.location
															effectiveRange: &effectiveRange] objectForKey: ZoomRowAttribute];
		NSNumber* initialField = [[[aTextView textStorage] attributesAtIndex: affectedCharRange.location
															  effectiveRange: &effectiveRange] objectForKey: ZoomFieldAttribute];
		NSNumber* finalRow = [[[aTextView textStorage] attributesAtIndex: affectedCharRange.location+affectedCharRange.length-1
														  effectiveRange: &effectiveRange] objectForKey: ZoomRowAttribute];
		NSNumber* finalField = [[[aTextView textStorage] attributesAtIndex: affectedCharRange.location+affectedCharRange.length-1
															effectiveRange: &effectiveRange] objectForKey: ZoomFieldAttribute];
		
		if (initialRow != finalRow
			|| initialField != finalField) {
			return NO;
		}
		
		// The field being edited must not be NoField
		int field = [initialField intValue];
		if (field == ZoomNoField) return NO;
		
		// Can't edit newlines
		if (!newlineEditsValid
			&& (field == ZoomTitleNewlineField
				|| field == ZoomYearNewlineField
				|| field == ZoomDescriptionNewlineField)) {
			return NO;
		}
		
		// Newlines are only allowed in the descrption, not the title or year
		if (field != ZoomDescriptionField) {
			int x;
			for (x=0; x<[replacementString length]; x++) {
				unichar thisChar = [replacementString characterAtIndex: x];
				if (thisChar == '\n' || thisChar == '\r')
					return NO;
			}
		}
		
		// Only numbers are allowed in the year
		if (field == ZoomYearField) {
			int x;
			for (x=0; x<[replacementString length]; x++) {
				unichar thisChar = [replacementString characterAtIndex: x];
				if (thisChar < '0' || thisChar > '9') return NO;
			}
		}
	}
	
	// Default to allowing editing
	return YES;
}

- (void) updateStoriesFromDetailView {
	// We assume that the attributes are contiguous.
	NSTextStorage* storage = [gameDetailView textStorage];
	NSInteger pos = 0;

	ZoomStory* lastStory = nil;
	NSString* title = nil;
	NSString* year = nil;
	NSString* description = nil;
	
	while (pos < [storage length]) {
		NSRange attributeRange;
		ZoomStory* story;
		NSNumber* field;
		
		// Retrieve the story at this position
		story = [storage attribute: ZoomStoryAttribute
						   atIndex: pos
			 longestEffectiveRange: &attributeRange
						   inRange: NSMakeRange(pos, [storage length]-pos)];
		
		// Retrieve the field at this position
		field = [storage attribute: ZoomFieldAttribute
						   atIndex: pos
			 longestEffectiveRange: &attributeRange
						   inRange: NSMakeRange(pos, [storage length]-pos)];
		
		// Move pos on to the next position
		pos = attributeRange.location + attributeRange.length;
		
		// Nothing to do if there's no story or field here
		if (story == nil || field == nil || [field intValue] == ZoomNoField) {
			continue;
		}
		
		// Get the new attribute value
		NSString* newAttributeValue = [[storage string] substringWithRange: attributeRange];
		
		// Update the story (we perform all updates at once, to prevent copying causing only the last change to take effect)
		if (story != lastStory && lastStory != nil) {
			lastStory = [self createStoryCopy: lastStory];
			if (title) [lastStory setTitle: title];
			if (year) [lastStory setYear: [year intValue]];
			if (description) [lastStory setDescription: description];
			
			title = year = description = nil;
			lastStory = nil;
		}
		lastStory = story;
		
		switch ([field intValue]) {
			case ZoomTitleField:
				title = newAttributeValue;
				break;
				
			case ZoomYearField:
				year = newAttributeValue;
				break;
			
			case ZoomDescriptionField:
				description = newAttributeValue;
				break;
		}
	}
	
	// Update the final story
	if (lastStory) {
		lastStory = [self createStoryCopy: lastStory];
		if (title) [lastStory setTitle: title];
		if (year) [lastStory setYear: [year intValue]];
		if (description) [lastStory setDescription: description];
	}
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification {
	NSControl* textView = [aNotification object];
	
	if (textView == searchField) {
		// Perform a search based on the text in the ifdb field
		if (browserOn && [[searchField stringValue] length] > 0) {
			NSString* ifdbUrl = [[[NSBundle mainBundle] infoDictionary] objectForKey: @"ZoomIfdbUrl"];
			if (!ifdbUrl) {
				ifdbUrl = @"http://ifdb.tads.org/";
			}
			
			NSString* searchUrl = [NSString stringWithFormat: @"%@search?searchfor=%@",
				ifdbUrl, [self queryEncode: [searchField stringValue]]];
			[[ifdbView mainFrame] loadRequest: [NSURLRequest requestWithURL: [NSURL URLWithString: searchUrl]]];
		}
	}
}

- (void)textDidEndEditing:(NSNotification *)aNotification {
	NSControl* textView = [aNotification object];
	
	if (textView == (NSControl*)gameDetailView) {
		// Update each of the stories in the game detail view
		[self updateStoriesFromDetailView];
		[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
	} else if (textView == searchField) {
		[self controlTextDidEndEditing: aNotification];
	} else {
		// Mysterious text view of DOOOOM
		NSLog(@"Unknown text view");
	}

	[self queueStoryUpdate];
}

-(void)textStorage:(NSTextStorage *)storage willProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta
{
	if (storage == [gameDetailView textStorage]) {
		// Get the edited range
		NSRange edited = editedRange;
		NSRange affectedCharRange = NSMakeRange(edited.location + edited.length, 0);

		// Work out the effective row/field/story at this position
		if (affectedCharRange.location >= [storage length]) affectedCharRange.location--;
		
		NSRange effectiveRange;
		NSNumber* row = [[storage attributesAtIndex: affectedCharRange.location
									 effectiveRange: &effectiveRange] objectForKey: ZoomRowAttribute];
		NSNumber* field = [[storage attributesAtIndex: affectedCharRange.location
									   effectiveRange: &effectiveRange] objectForKey: ZoomFieldAttribute];
		ZoomStory* story = [[storage attributesAtIndex: affectedCharRange.location
										effectiveRange: &effectiveRange] objectForKey: ZoomStoryAttribute];
		
		// If field is nil, and we're at the end, then act as if we're editing the description
		if ([field intValue] == ZoomNoField
			&& edited.location + edited.length == [storage length]
			&& [mainTableView numberOfSelectedRows] == 1) {
			row = @([mainTableView selectedRow]);
			field = @(ZoomDescriptionField);
			story = [self selectedStory];
		}
		
		// If we've got any nil values, then give up
		if (row == nil || field == nil || story == nil || [field intValue] == ZoomNoField) {
			return;
		}
		
		// Set the attributes appropriately
		NSFont* titleFont = [NSFont boldSystemFontOfSize: 14];
		NSFont* yearFont = [NSFont systemFontOfSize: 10];
		NSFont* descFont = [NSFont systemFontOfSize: 11];

		NSFont* font;
		switch ([field intValue]) {
			case ZoomTitleNewlineField:
				field = @(ZoomTitleField);
			case ZoomTitleField:
				font = titleFont;
				break;
			case ZoomYearNewlineField:
				field = @(ZoomYearField);
			case ZoomYearField:
				font = yearFont;
				break;
			case ZoomDescriptionNewlineField:
				field = @(ZoomDescriptionField);
			default:
				font = descFont;
				break;
		}
		
		NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:
			font, NSFontAttributeName,
			row, ZoomRowAttribute,
			field, ZoomFieldAttribute,
			story, ZoomStoryAttribute,
			nil];
		
		[storage addAttributes: attributes
						 range: edited];
	}
}

// = Various menus =

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem {
	SEL sel = [menuItem action];
	
	if (sel == @selector(delete:)) {
		// Allow only if at least one game is selected
		return [mainTableView numberOfSelectedRows] > 0;
	} else if (sel == @selector(revealInFinder:)) {
		return [mainTableView numberOfSelectedRows] == 1;
	} else if (sel == @selector(deleteSavegame:)) {
		// Allow only if at least one savegame is selected
		NSLog(@"%@", [previewView selectedSaveGame]);
		return [previewView selectedSaveGame] != nil;
	} else if (sel == @selector(saveMetadata:)) {
		return [mainTableView numberOfSelectedRows] > 0;
	}
	
	return YES;
}

- (IBAction) deleteSavegame: (id) sender {
	NSBeep();
}

- (IBAction) delete: (id) sender {
	// Ask for confirmation
	if ([mainTableView numberOfSelectedRows] <= 0) return;
	
	NSString* request = @"Are you sure you want to destroy the spoons?";
	
	if ([mainTableView numberOfSelectedRows] == 1) {
		request = @"Are you sure you want to delete this game?";
	} else {
		request = @"Are you sure you want to delete these games?";
	}
	
	// Maybe FIXME: we can display this as a sheet, but we can't display the 'delete save game?'
	// dialog that way (it appears as a sheet in the drawer. You'd expect a drawer to be a child
	// window, but it isn't, so there doesn't seem to be a way of retrieving the window to display
	// under. Well, I can think of a couple of ways around this, but they all feel like ugly hacks)
	NSIndexSet* rowEnum = [mainTableView selectedRowIndexes];
	
	NSArray *storiesToDelete = [storyList objectsAtIndexes:rowEnum];
	
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = @"Are you sure?";
	alert.informativeText = request;
	NSButton *delButton = [alert addButtonWithTitle:@"Delete"];
	if (@available(macOS 11.0, *)) {
		delButton.hasDestructiveAction = YES;
	}
	[alert addButtonWithTitle:@"Keep"].keyEquivalent = @"\1B";
	[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
		if (returnCode != NSAlertFirstButtonReturn) return;
		
		// Delete the selected games from the organiser
		NSEnumerator* rowEnum = [storiesToDelete objectEnumerator];
		
		for (ZoomStoryID* ident in rowEnum) {
			[[ZoomStoryOrganiser sharedStoryOrganiser] removeStoryWithIdent: ident
														 deleteFromMetadata: YES];
		}
		
		if ([[ZoomPreferences globalPreferences] keepGamesOrganised]) {
			NSEnumerator* rowEnum = [storiesToDelete objectEnumerator];
			NSMutableArray *delURLs = [[NSMutableArray alloc] initWithCapacity: storiesToDelete.count];
			
			for (ZoomStoryID* ident in rowEnum) {
				NSString* filename = [[ZoomStoryOrganiser sharedStoryOrganiser] directoryForIdent: ident
																						   create: NO];
				if (filename != nil) {
					[delURLs addObject:[NSURL fileURLWithPath:filename]];
					
					// (make sure it's gone from the organiser)
					[[ZoomStoryOrganiser sharedStoryOrganiser] removeStoryWithIdent: ident
																 deleteFromMetadata: YES];
				}
			}
			[[NSWorkspace sharedWorkspace] recycleURLs: delURLs completionHandler: ^(NSDictionary<NSURL *,NSURL *> * _Nonnull newURLs, NSError * _Nullable error) {
				// Do Nothing.
			}];
		}
	}];
}

- (IBAction) revealInFinder: (id) sender {
	if ([self selectedFilename] != nil) {
		NSString* dir = [[self selectedFilename] stringByDeletingLastPathComponent];
		BOOL isDir;
		
		if ([[NSFileManager defaultManager] fileExistsAtPath: dir
												 isDirectory: &isDir]) {
			if (isDir) {
				[[NSWorkspace sharedWorkspace] selectFile: [self selectedFilename] inFileViewerRootedAtPath: dir];
			}
		}
	}
}

// = windowWillClose, etc =

- (void) windowWillClose: (NSNotification*) notification {
}

- (BOOL) windowShouldClose: (NSNotification*) notification {
	return YES;
}

// = Loading iFiction data =

- (NSArray*) mergeiFictionFromMetabase: (ZoomMetadata*) newData {
	// Show our window
	[[self window] makeKeyAndOrderFront: self];
	
	if (newData == nil) {
		// Doh!
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = @"Unable to load metadata";
		alert.informativeText = @"Zoom encountered an error while trying to load an iFiction file.";
		[alert addButtonWithTitle:@"Cancel"];
		[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
			// do nothing
		}];
		return nil;
	}
	
	if ([[newData errors] count] > 0) {
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = @"Unable to load metadata";
		alert.informativeText = [NSString stringWithFormat:@"Zoom encountered an error (%@) while trying to load an iFiction file.",
								 [[newData errors] objectAtIndex: 0]];
		[alert addButtonWithTitle:@"Cancel"];
		[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
			// do nothing
		}];
		return nil;
	}
	
	// Merge any new descriptions found there
	NSMutableArray* replacements = [NSMutableArray array];
	
	for (ZoomStory* story in [newData stories]) {
		// Find if the story already exists in our index
		ZoomStory* oldStory = nil;
		
		for (ZoomStoryID* ident in [story storyIDs]) {
			oldStory = [(ZoomAppDelegate*)[NSApp delegate] findStory: ident];
			if (oldStory != nil) break;
		}
		
		if (oldStory != nil) {
			// Add this story to the list of stories to query about replacing
			[replacements addObject: story];
		}
		
		// Add this story to the userMetadata
		[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] copyStory: story];
	}
	
	// Store and reflect any changes
	[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
	
	[self reloadTableData];
	[self configureFromMainTableSelection];
	
	// The return value is the set of things that would be replaced
	return replacements;
}

- (void) mergeiFictionFromFile: (NSString*) filename {
	// Read the file
	ZoomMetadata* newData = [[ZoomMetadata alloc] initWithContentsOfFile: filename];
	
	if (newData == nil) return;
	
	// Perform the merge
	NSArray<ZoomStory*>* replacements = [self mergeiFictionFromMetabase: newData];
	
	// If there's anything to query about, ask!
	if ([replacements count] > 0) {
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = @"Some story descriptions are already in the database";
		alert.informativeText = @"This metadata file contains descriptions for some story files that already exist in the database. Do you want to keep using the old descriptions or switch to the new ones?";
		[alert addButtonWithTitle:@"Use new"];
		[alert addButtonWithTitle:@"Keep new"];
		[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
			if (returnCode != NSAlertFirstButtonReturn) return;
			
			for (ZoomStory* story in replacements) {
				[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] copyStory: story];
			}
			
			// Store and reflect any changes
			[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
			
			[self reloadTableData];
			[self configureFromMainTableSelection];
		}];
	}
}

// = Saving iFiction data =

- (IBAction) saveMetadata: (id) sender {
	NSSavePanel* panel = [NSSavePanel savePanel];
	
	panel.allowedFileTypes = @[@"iFiction"];
	NSURL* directory = [[NSUserDefaults standardUserDefaults] URLForKey: @"ZoomiFictionSavePath"];
	if (directory) {
		panel.directoryURL = directory;
	}
	[panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
		if (result != NSModalResponseOK) return;
		
		// Generate the data to save
		ZoomMetadata* newMetadata = [[ZoomMetadata alloc] init];
		
		NSIndexSet* selEnum = [self->mainTableView selectedRowIndexes];
		NSInteger selRow = selEnum.firstIndex;
		
		while (selRow != NSNotFound) {
			ZoomStoryID* ident = [self->storyList objectAtIndex: selRow];
			ZoomStory* story = [(ZoomAppDelegate*)[NSApp delegate] findStory: ident];
			
			if (story != nil) {
				[newMetadata copyStory: story];
			}
			selRow = [selEnum indexGreaterThanIndex:selRow];
		}
		
		// Save it!
		[newMetadata writeToFile: [panel URL].path
					  atomically: YES];
		
		// Store any preference changes
		[[NSUserDefaults standardUserDefaults] setURL: [panel directoryURL]
											   forKey: @"ZoomiFictionSavePath"];
	}];
}

- (IBAction) flipToFilter: (id) sender {
	[self flipTo: filterView];
}

- (IBAction) flipToInfo: (id) sender {
	[self flipTo: infoView];
}

- (IBAction) flipToSaves: (id) sender {
	[self flipTo: saveGameView];	
}

// = ResourceDrop delegate =

- (void) resourceDropFilenameChanged: (ZoomResourceDrop*) drop {
	ZoomStoryOrganiser* org = [ZoomStoryOrganiser sharedStoryOrganiser];
	ZoomStory* selectedStory = [self selectedStory];
	
	if (selectedStory != nil) {
		[selectedStory setObject: [drop droppedFilename]
						  forKey: @"ResourceFilename"];
		
		if ([[ZoomPreferences globalPreferences] keepGamesOrganised]) {
			[org organiseStory: selectedStory];
		}
	}
}

// = Handling downloads =

- (BOOL) canPlayFile: (NSString*) filename {
	NSArray* fileTypes = [NSArray arrayWithObjects: @"z3", @"z4", @"z5", @"z6", @"z7", @"z8", @"blorb", @"zblorb", @"blb", @"zlb", @"signpost", nil];
	NSString* extn = [[filename pathExtension] lowercaseString];
	
	if ([fileTypes containsObject: extn]) {
		return YES;
	} else if ([[ZoomPlugInManager sharedPlugInManager] plugInForFile: filename]) {
		return YES;
	}
	
	if ([extn isEqualToString: @"xml"] && [[[[filename stringByDeletingPathExtension] pathExtension] lowercaseString] isEqualToString: @"signpost"]) {
		return YES;
	}
	
	return NO;
}

- (void) addFilesFromDirectory: (NSString*) directory
					 groupName: (NSString*) groupName {
	ZoomIsSpotlightIndexing = NO;
	// Work out the group to use to store the files that we've added
	if (groupName == nil || [groupName length] == 0) groupName = @"Downloaded";
	
	// Iterate through the directory and organise any files that we find
	NSMutableArray<ZoomStoryID*>* addedFiles = [NSMutableArray array];
	NSDirectoryEnumerator<NSString *>* dirEnum = [[NSFileManager defaultManager] enumeratorAtPath: directory];
	NSString* signpostFile = nil;
	for (__strong NSString* path in dirEnum) {
		path = [directory stringByAppendingPathComponent: path];
		path = [path stringByStandardizingPath];
		
		// Must exist
		BOOL isDir;
		if (![[NSFileManager defaultManager] fileExistsAtPath: path
												  isDirectory: &isDir]) {
			continue;
		}
		
		// Must be a file
		if (isDir) continue;
		
		// Must be playable
		if (![self canPlayFile: path]) continue;
		
		// Could be a signpost
		if ([[[path pathExtension] lowercaseString] isEqualToString: @"signpost"]) {
			signpostFile = path;
			continue;
		} else if ([[[path pathExtension] lowercaseString] isEqualToString: @"xml"] && [[[[path stringByDeletingPathExtension] pathExtension] lowercaseString] isEqualToString: @"signpost"]) {
			signpostFile = path;
			continue;
		}
		
		// Must have an ID
		ZoomStoryID* storyId = [ZoomStoryID idForFile: path];
		if (!storyId) continue;
		
		// Organise this file
		[[ZoomStoryOrganiser sharedStoryOrganiser] addStory: path
												  withIdent: storyId
												   organise: YES];
		[addedFiles addObject: storyId];
	}
	
	// Either catalogue the files as a group, or load the game that was downloaded if there's only one
	if ([addedFiles count] == 0) {
		if (signpostFile != nil) {
			// Play a signpost file
			[self openSignPost: [NSData dataWithContentsOfFile: signpostFile]
				 forceDownload: YES];
			return;
		}
		
		// Oops: couldn't find any games to add
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = @"The download did not contain any story files";
		alert.informativeText = @"Zoom successfully downloaded the file, but was unable to find any story files that can be played by the currently installed plugins.";
		[alert addButtonWithTitle:@"Cancel"];
		[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
			// do nothing
		}];
	} else if ([addedFiles count] == 1) {
		// Play one story
		ZoomStoryID* storyToPlay = [addedFiles lastObject];
		NSString* filename = [[ZoomStoryOrganiser sharedStoryOrganiser] filenameForIdent: storyToPlay];
		
		if (filename) {
			[[NSApp delegate] application: NSApp
								 openFile: filename];			
		}
		
		// Select the story in the main table
		[mainTableView deselectAll: self];
		NSUInteger storyRow = [storyList indexOfObject: storyToPlay];
		if (storyRow != NSNotFound) {
			[mainTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:storyRow]
					   byExtendingSelection: NO];
			[mainTableView scrollRowToVisible: storyRow];
		}

		// Switch back to the browser view
		if (browserOn) [self showLocalGames: self];
	} else {
		// Set the group of all the stories
		for (ZoomStoryID* storyId in addedFiles) {
			ZoomStory* story = [self storyForID: storyId];
			
			story = [self createStoryCopy: story];
			[story setGroup: groupName];

			/*
			[[ZoomStoryOrganiser sharedStoryOrganiser] addStory: [[ZoomStoryOrganiser sharedStoryOrganiser] filenameForIdent: storyId]
													  withIdent: storyId
													   organise: YES];
			 */
		}
		
		// Set the filters to filter by group
		[mainTableView deselectAll: self];
		[filterTable1 selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
				  byExtendingSelection: NO];
		[filterTable2 selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
				  byExtendingSelection: NO];

		NSTableColumn* filterColumn = [[filterTable1 tableColumns] objectAtIndex: 0];
		
		[filterColumn setIdentifier: @"group"];
		[self setTitle: @"Group"
			  forTable: filterTable1];
		
		[self reloadTableData]; [mainTableView reloadData];
		
		// Filter by the group we just added
		NSUInteger filterRow = [filterSet1 indexOfObject: groupName];
		if (filterRow != NSNotFound) {
			[filterTable1 selectRowIndexes: [NSIndexSet indexSetWithIndex:filterRow+1]
			   byExtendingSelection: NO];
		}
		
		// If there's a signpost ID and we have that file, then open it
		if (signpostId) {
			NSString* storyFilename = [[ZoomStoryOrganiser sharedStoryOrganiser] filenameForIdent: signpostId];
			if (storyFilename) {
				[[NSApp delegate] application: NSApp
									 openFile: storyFilename];			
			}
		}
		
		// Switch back to the browser view
		if (browserOn) [self showLocalGames: self];		
	}

	// Write any new metadata
	[[(ZoomAppDelegate*)[NSApp delegate] userMetadata] writeToDefaultFile];
	
	signpostId = nil;
}

- (void) cancelFadeTimer {
	if (!downloadFadeTimer) return;
	
	[downloadFadeTimer invalidate];
	downloadFadeTimer = nil;
}

- (void) finishPopDownload {
	[[(ZoomAppDelegate*)[NSApp delegate] leopard] clearLayersForView: downloadView];
	[[downloadView progress] startAnimation: self];
}

- (void) finishPopOutDownload {
	[self cancelFadeTimer];
	[[self window] removeChildWindow: downloadWindow];
	[downloadWindow orderOut: self];
}

- (void) showDownloadWindow {
	if ([downloadWindow isVisible]) return;
	
	// Display the window
	[[self window] addChildWindow: downloadWindow
						  ordered: NSWindowAbove];
	[downloadWindow orderFront: self];
	[self positionDownloadWindow];
	
	// Start the timer to fade the window in
	[self cancelFadeTimer];
	
	if ([(ZoomAppDelegate*)[NSApp delegate] leopard]) {
		// Fanicify the animation under leopard
		NSInvocation* finished = [NSInvocation invocationWithMethodSignature: [self methodSignatureForSelector: @selector(finishPopDownload)]];
		[finished setTarget: self];
		[finished setSelector: @selector(finishPopDownload)];
		
		[[(ZoomAppDelegate*)[NSApp delegate] leopard] popView: downloadView
								   duration: 0.5
								   finished: finished];
		[downloadWindow setAlphaValue: 1.0];
	} else {
		// Use a more prosaic animation on Tiger
		initialDownloadOpacity = [downloadWindow alphaValue];
		downloadFadeStart = [NSDate date];
		downloadFadeTimer = [NSTimer timerWithTimeInterval: 0.02
													target: self
												  selector: @selector(fadeDownloadIn)
												  userInfo: nil
												   repeats: YES];
		[[NSRunLoop currentRunLoop] addTimer: downloadFadeTimer
									 forMode: NSDefaultRunLoopMode];
	}
}

- (void) hideDownloadWindow: (double) duration {
	if (![downloadWindow isVisible]) return;

	// Start the timer to fade the window out
	[self cancelFadeTimer];

	if ([(ZoomAppDelegate*)[NSApp delegate] leopard]) {
		// Fanicify the animation under leopard
		[[downloadView progress] stopAnimation: self];
		[[downloadView progress] setDoubleValue: 0];

		NSInvocation* finished = [NSInvocation invocationWithMethodSignature: [self methodSignatureForSelector: @selector(finishPopOutDownload)]];
		[finished setTarget: self];
		[finished setSelector: @selector(finishPopOutDownload)];
		
		[[(ZoomAppDelegate*)[NSApp delegate] leopard] popOutView: downloadView
									  duration: duration
									  finished: finished];
		[downloadWindow setAlphaValue: 1.0];
	} else {		
		// Tiger animation
		initialDownloadOpacity = [downloadWindow alphaValue];
		downloadFadeStart = [NSDate date];
		downloadFadeTimer = [NSTimer timerWithTimeInterval: 0.02
													target: self
												  selector: @selector(fadeDownloadOut)
												  userInfo: nil
												   repeats: YES];
		[[NSRunLoop currentRunLoop] addTimer: downloadFadeTimer
									 forMode: NSDefaultRunLoopMode];
	}
}

- (void) fadeDownloadIn {
	NSTimeInterval runTime = [[NSDate date] timeIntervalSinceDate: downloadFadeStart];
	double done = runTime / 0.5;
	
	if (done < 0) done = 0;
	if (done > 1) done = 1;
	
	done = -2.0*done*done*done + 3.0*done*done;
	[downloadWindow setAlphaValue: done];
	
	if (done >= 0.999) {
		[self cancelFadeTimer];
	}
}

- (void) fadeDownloadOut {
	NSTimeInterval runTime = [[NSDate date] timeIntervalSinceDate: downloadFadeStart];
	double done = runTime / 0.5;

	if (done < 0) done = 0;
	if (done > 1) done = 1;
	
	done = -2.0*done*done*done + 3.0*done*done;
	[downloadWindow setAlphaValue: 1-done];

	if (done >= 0.999) {
		[self cancelFadeTimer];
		[[self window] removeChildWindow: downloadWindow];
		[downloadWindow orderOut: self];
	}
}

- (void) downloadStarting: (ZoomDownload*) download {
	if (download != activeDownload) return;
	[self showDownloadWindow];
	
	[[downloadView progress] setIndeterminate: YES];
	[[downloadView progress] setMinValue: 0];
	[[downloadView progress] setMaxValue: 100.0];
	if (![(ZoomAppDelegate*)[NSApp delegate] leopard]) [[downloadView progress] startAnimation: self];
}

- (void) downloadComplete: (ZoomDownload*) download {
	if (download != activeDownload) return;
	
	if (downloadUpdateList) {
		// We've downloaded a list of plugins, and we want to pick one to install as part of a signpost file
		downloadUpdateList = NO;
		NSString* xmlFile=nil;
		NSString* extension = [[activeDownload suggestedFilename] pathExtension];
		
		NSEnumerator* dirEnum = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath: [activeDownload downloadDirectory] error: NULL] objectEnumerator];
		for (NSString* path in dirEnum) {
			if ([[path pathExtension] isEqualToString: extension]) {
				xmlFile = [[activeDownload downloadDirectory] stringByAppendingPathComponent: path];
			}
		}
		
		if (xmlFile) {
			[self installSignpostPluginFrom: [NSData dataWithContentsOfFile: xmlFile]];
		} else {
			// Butterfingers
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = @"Could not download the plug-in";
			alert.informativeText = @"Zoom succesfully downloaded a plugin update file, but was unable to locate it after the download had completed.";
			[alert addButtonWithTitle:@"Cancel"];
			[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
				// do nothing
			}];
		}
	} else if (downloadPlugin) {
		// We've downloaded a plugin and need to install it
		[self installPluginFrom: activeDownload];
	} else {
		// Default: add story files
		[self addFilesFromDirectory: [download downloadDirectory]
						  groupName: [[[download suggestedFilename] lastPathComponent] stringByDeletingPathExtension]];		
	}
	
	if (download == activeDownload) {
		[activeDownload setDelegate: nil];
		activeDownload = nil;
		[[downloadView progress] stopAnimation: self];
		
		[self hideDownloadWindow: 0.5];
	}
}

- (void) downloadFailed: (ZoomDownload*) download 
				 reason: (NSString*) reason {
	if (download != activeDownload) return;

	[activeDownload setDelegate: nil];
	activeDownload = nil;
	[[downloadView progress] stopAnimation: self];

	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = @"Could not complete the download.";
	alert.informativeText = [NSString stringWithFormat:@"An error was encountered while trying to download the requested file%@%@.",
							 reason?@".\n\n":@"", reason];
	[alert addButtonWithTitle:@"Cancel"];
	[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
		// do nothing
	}];
	
	[self hideDownloadWindow: 0.25];
}

- (void) downloadUnarchiving: (ZoomDownload*) download {
	if (download != activeDownload) return;
	
	[[downloadView progress] setIndeterminate: YES];
}

- (void) download: (ZoomDownload*) download
		completed: (float) complete {
	if (download != activeDownload) return;

	[[downloadView progress] setIndeterminate: NO];
	[[downloadView progress] setDoubleValue: complete * 100.0];
}

- (void)					webView: (WebView *)sender 
	decidePolicyForNavigationAction: (NSDictionary *)actionInformation 
							request:(NSURLRequest *)request 
							  frame:(WebFrame *)frame 
				   decisionListener:(id<WebPolicyDecisionListener>)listener {
	NSArray* archiveFiles = [NSArray arrayWithObjects: @"zip", @"tar", @"tgz", @"gz", @"bz2", @"z", nil];

	if ([[actionInformation objectForKey: WebActionNavigationTypeKey] intValue] == 0) {
#ifdef DEVELOPMENT_BUILD
		NSLog(@"Deciding policy for %@", [request URL]);
		NSLog(@"User-agent is %@", [ifdbView userAgentForURL: [request URL]]);
		NSLog(@"(Custom agent is %@)", [ifdbView customUserAgent]);
		NSLog(@"Header fields are %@", [request allHTTPHeaderFields]);
#endif
		
		// Get the URL to download
		NSURL* url = [request URL];
		
		NSString* fakeFile = [[NSTemporaryDirectory() stringByAppendingPathComponent: @"FakeDirectory"] 
								stringByAppendingPathComponent: [[url path] lastPathComponent]];
		if ([self canPlayFile: fakeFile] || [archiveFiles containsObject: [[fakeFile pathExtension] lowercaseString]]) {
			// Use mirror.ifarchive.org, not www.ifarchive.org
			NSString* host = [url host];
			if ([host isEqualToString: @"www.ifarchive.org"]) {
				NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:YES];
				components.host = @"mirror.ifarchive.org";
				url = components.URL;
			}
			
			// Download the specified file
			[activeDownload setDelegate: nil];
			activeDownload = nil;

			signpostId = nil;
			downloadUpdateList = NO;
			downloadPlugin = NO;
			
			activeDownload = [[ZoomDownload alloc] initWithUrl: url];
			[activeDownload setDelegate: self];
			[activeDownload startDownload];
			
			// Ignore the request
			[listener ignore];
			return;
		}
	}
	
	// Default is to use the request
	if ([NSURLConnection canHandleRequest: request]) {
		[listener use];		
	} else {
		[listener ignore];
	}
}

- (void)           webView:(WebView *)sender
   decidePolicyForMIMEType:(NSString *)type
				   request:(NSURLRequest *)request 
					 frame:(WebFrame *)frame 
		  decisionListener:(id<WebPolicyDecisionListener>)listener {
	if (![WebView canShowMIMEType: type]) {
		[listener ignore];

		NSBeginAlertSheet(@"Zoom cannot download this type of file", @"Cancel", nil,
						  nil, [self window], nil, nil,
						  nil,nil,
						  @"You have clicked on a download link that goes to a type of file that Zoom does not know how to handle. This could be because the file is a compressed file in a format that Zoom does not understand, or it could be because you have not installed the plug-in for this file type.\n\nYou can check for new plugins by using the 'Check for Updates' option in the Zoom menu.\n\nType \"%@\"", type);
	} else {
		[listener use];
	}
}

// = Browsing the IFDB =

- (void) updateBackForwardButtons {
	if ([ifdbView canGoForward]) {
		[forwardButton setEnabled: YES];
	} else {
		[forwardButton setEnabled: NO];		
	}
	if ([ifdbView canGoBack]) {
		[backButton setEnabled: YES];
	} else {
		[backButton setEnabled: NO];		
	}
}

- (NSString*) queryEncode: (NSString*) string {
	NSString* result = [string stringByAddingPercentEncodingWithAllowedCharacters: NSCharacterSet.URLQueryAllowedCharacterSet];
	return result;
}

- (IBAction) showIfDb: (id) sender {
	ZoomFlipView* fv = [[ZoomFlipView alloc] init];
	[fv setAnimationTime: 0.35];

	NSRect viewFrame = [mainView frame];
	[fv setFrame: viewFrame];
	[browserView setFrame: viewFrame];
	[self setBrowserFontSize];
	
	[fv prepareToAnimateView: mainView];
	[fv animateTo: browserView
			style: ZoomAnimateRight];
	
	NSString* ifdbUrl = [[[NSBundle mainBundle] infoDictionary] objectForKey: @"ZoomIfdbUrl"];
	if (!ifdbUrl) {
		ifdbUrl = @"http://ifdb.tads.org/";
	}
	
	// If the user has a single game selected, then open it in the browser
	BOOL findMore = NO;
	
	if ([mainTableView numberOfSelectedRows] == 1) {
		ZoomStoryID* ident = [storyList objectAtIndex: [mainTableView selectedRow]];
		if (ident) {
			NSString* identString = [ident description];
			ZoomStory* story = [self storyForID: ident];
			if ([identString hasPrefix: @"UUID://"]) {
				identString = [identString substringFromIndex: 7];
				identString = [identString substringToIndex: [identString length]-2];
			}
			
			ifdbUrl = [NSString stringWithFormat: @"%@viewgame?ifid=%@&findmore", 
				ifdbUrl, [self queryEncode: identString]];
			if (story != nil) {
				ifdbUrl = [ifdbUrl stringByAppendingFormat: @"&title=%@", [self queryEncode: [story title]]];
			}
			findMore = YES;
		}
	}
	
	// Reload the main page if the user has strayed off the main ifdb site
	NSURL* ifdb = [NSURL URLWithString: ifdbUrl];
	if (findMore || !usedBrowser || [[[[[[ifdbView mainFrame] dataSource] request] URL] host] caseInsensitiveCompare: [ifdb host]] != 0) {
		if (!usedBrowser) {
			// Hacky way of clearing the history
			[[ifdbView backForwardList] setCapacity: 0];
			[[ifdbView backForwardList] setCapacity: 256];
		}
		if (![[[[[ifdbView mainFrame] dataSource] request] URL] isEqualTo: ifdb]) {
			[[ifdbView mainFrame] loadRequest: [NSURLRequest requestWithURL: ifdb]];			
		}
	}
	
	if (!browserOn && [(ZoomAppDelegate*)[NSApp delegate] leopard]) {
		[[(ZoomAppDelegate*)[NSApp delegate] leopard] popOutView: continueButton
									  duration: 0.25
									  finished: nil];
		[[(ZoomAppDelegate*)[NSApp delegate] leopard] popOutView: newgameButton
									  duration: 0.20
									  finished: nil];
		[[(ZoomAppDelegate*)[NSApp delegate] leopard] popOutView: addButton
									  duration: 0.15
									  finished: nil];
		[[(ZoomAppDelegate*)[NSApp delegate] leopard] popOutView: infoButton
									  duration: 0.20
									  finished: nil];
	}
		
	[searchField setStringValue: @""];
	usedBrowser = YES;
	browserOn = YES; 
	[self updateButtons];
}

- (IBAction) showLocalGames: (id) sender {
	ZoomFlipView* fv = [[ZoomFlipView alloc] init];
	[fv setAnimationTime: 0.35];

	NSRect viewFrame = [browserView frame];
	[fv setFrame: viewFrame];
	[mainView setFrame: viewFrame];
	
	[searchField setStringValue: @""];
	[fv prepareToAnimateView: browserView];
	[fv animateTo: mainView
			style: ZoomAnimateLeft];
	browserOn = NO;
	[self updateButtons];
	
	if (!browserOn && [(ZoomAppDelegate*)[NSApp delegate] leopard]) {
		[[(ZoomAppDelegate*)[NSApp delegate] leopard] popView: continueButton
									  duration: 0.15
									  finished: nil];
		[[(ZoomAppDelegate*)[NSApp delegate] leopard] popView: newgameButton
									  duration: 0.25
									  finished: nil];
		[[(ZoomAppDelegate*)[NSApp delegate] leopard] popView: addButton
									  duration: 0.35
									  finished: nil];
		[[(ZoomAppDelegate*)[NSApp delegate] leopard] popView: infoButton
									  duration: 0.25
									  finished: nil];
	}
}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame {
	[self updateBackForwardButtons];
	
	if (frame == [ifdbView mainFrame]) {
		NSString* url = [[[[frame dataSource] request] URL] absoluteString];
		if (url) [currentUrl setStringValue: url];
		
		[progressIndicator startAnimation: self];
	}
}

- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame {
	[self updateBackForwardButtons];

	if (frame == [ifdbView mainFrame]) {
		NSString* url = [[[[frame dataSource] request] URL] absoluteString];
		if (url) [currentUrl setStringValue: url];
		
		[progressIndicator startAnimation: self];
		
		// Cancel any running download
		if (activeDownload != nil && ![[[[frame dataSource] request] URL] isFileURL]) {
			[activeDownload setDelegate: nil];
			activeDownload = nil;
			[self hideDownloadWindow: 0.25];
		}
	}
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
	[self updateBackForwardButtons];

	if (frame == [ifdbView mainFrame]) {
		NSString* url = [[[[frame dataSource] request] URL] absoluteString];
		if (url) [currentUrl setStringValue: url];

		[progressIndicator stopAnimation: self];
	}	
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame {
	[self updateBackForwardButtons];
	
	if (frame == [ifdbView mainFrame]) {
		NSString* url = [[[[frame dataSource] request] URL] absoluteString];
		if (url) [currentUrl setStringValue: url];
		
		[progressIndicator stopAnimation: self];
		
		if (lastError == nil) lastError = [[ZoomJSError alloc] init];
		[lastError setLastError: [error localizedDescription]];
		
		switch ([error code]) {
			case 102:
				// Ignore these errors
				break;
				
			default:
				// Open the error page
				[[ifdbView mainFrame] loadRequest: [NSURLRequest requestWithURL: [NSURL fileURLWithPath: [[NSBundle mainBundle] pathForResource: @"ifdb-failed"
																																		 ofType: @"html"]]]];
				break;
		}
	}	
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame {
	[self updateBackForwardButtons];
	
	if (frame == [ifdbView mainFrame]) {
		NSString* url = [[[[frame dataSource] request] URL] absoluteString];
		if (url) [currentUrl setStringValue: url];
		
		[progressIndicator stopAnimation: self];
		
		if (lastError == nil) lastError = [[ZoomJSError alloc] init];
		[lastError setLastError: [error localizedDescription]];
		
		switch ([error code]) {
			case 102:
				// Ignore these errors
				break;
			
			default:
				// Open the error page
				[[ifdbView mainFrame] loadRequest: [NSURLRequest requestWithURL: [NSURL fileURLWithPath: [[NSBundle mainBundle] pathForResource: @"ifdb-failed"
																																		 ofType: @"html"]]]];
				break;
		}
	}	
}

- (void)webView:(WebView *)sender windowScriptObjectAvailable:(WebScriptObject *)windowScriptObject {
	// Attach the error object
	if (lastError == nil) {
		lastError = [[ZoomJSError alloc] init];
	}
	
	[[sender windowScriptObject] setValue: lastError
								   forKey: @"Errors"];
}

- (IBAction) goBack: (id) sender {
	[ifdbView goBack];
}

- (IBAction) goForward: (id) sender {
	[ifdbView goForward];	
}

- (IBAction) goHome: (id) sender; {
	NSString* ifdbUrl = [[[NSBundle mainBundle] infoDictionary] objectForKey: @"ZoomIfdbUrl"];
	if (!ifdbUrl) {
		ifdbUrl = @"https://ifdb.tads.org/";
	}
	[[ifdbView mainFrame] loadRequest: [NSURLRequest requestWithURL: [NSURL URLWithString: ifdbUrl]]];	
}

- (IBAction) playIfdbGame: (id) sender {
	
}

// = Dealing with signposts =

- (void) openSignPost: (NSData*) signpostFile
		forceDownload: (BOOL) forceDownload {
	// Ensure that the window is displayed
	[self showWindow: self];
	
	// Parse the property list
	ZoomSignPost* signpost = [[ZoomSignPost alloc] initWithData: signpostFile];
	
	if (signpost == nil) {
		// Not a valid signpost
		return;
	}
	
	if ([signpost errorMessage]) {
		// Signpost is OK but just contains an error message
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = @"IFDB has reported a problem with this game";
		alert.informativeText = [signpost errorMessage];
		[alert addButtonWithTitle:@"Cancel"];
		[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
			// do nothing
		}];
		return;
	}
	
	// Check for an installed plugin with the interpreter ID
	NSString* interpreter = [signpost interpreterDisplayName];
	if (interpreter && [interpreter isKindOfClass: [NSString class]]) {
		BOOL haveInterpreter = NO;
		
		NSEnumerator* pluginEnum = [[[ZoomPlugInManager sharedPlugInManager] pluginBundles] objectEnumerator];
		for (NSBundle* pluginBundle in pluginEnum) {
			NSString* pluginName = [[ZoomPlugInManager sharedPlugInManager] nameForBundle: [pluginBundle bundlePath]];
			if ([pluginName isEqualToString: interpreter]) {
				haveInterpreter = YES;
				break;
			}
		}
		
		if ([interpreter isEqualToString: @"Z-Code"]) {
			haveInterpreter = YES;
		}
		
		if (!haveInterpreter) {
			// Download the update file, then the interpreter
			NSString* updateUrl = [[signpost interpreterURL] absoluteString];
			if (!updateUrl || ![updateUrl isKindOfClass: [NSString class]]) {
				return;
			}
			
			[activeDownload setDelegate: nil];
			activeDownload = nil;
			
			signpostId = nil;
			activeSignpost = signpost;
			
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = @"Zoom needs to download a new plug-in in order play this story";
			alert.informativeText = @"In order to play the story file you have selected, Zoom needs to download and install a new plug-in. If you choose to install this plug-in, Zoom will need to restart before the story can be played.\n\n"
			"Plug-ins contain interpreter programs necessary to run certain interactive fiction. Zoom comes with support for Z-Code, HUGO, TADS and Glulx formats but is capable of playing new formats by adding new plug-ins.";
			[alert addButtonWithTitle:@"Install plugin"];
			[alert addButtonWithTitle:@"Cancel"];
			[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
				if (self->activeSignpost && returnCode == NSAlertFirstButtonReturn) {
					// Get the update URL
					NSURL* updateUrl = [self->activeSignpost interpreterURL];
					if (!updateUrl) {
						return;
					}
					
					// Use mirror.ifarchive.org, not www.ifarchive.org
					NSString* host = [updateUrl host];
					if ([host isEqualToString: @"www.ifarchive.org"]) {
						NSURLComponents *components = [[NSURLComponents alloc] initWithURL:updateUrl resolvingAgainstBaseURL:YES];
						components.host = @"mirror.ifarchive.org";
						updateUrl = components.URL;
					}
					
					// Download the update XML file
					[self->activeDownload setDelegate: nil];
					self->activeDownload = nil;
					
					self->signpostId = nil;
					
					self->downloadUpdateList = YES;
					self->downloadPlugin = NO;
					
					self->activeDownload = [[ZoomDownload alloc] initWithUrl: updateUrl];
					[self->activeDownload setDelegate: self];
					[self->activeDownload startDownload];
				}
			}];
			return;
		}
	}
	
	// See if the game is already present
	ZoomStoryID* downloadId = nil;
	for (ZoomStoryID* downloadId in [signpost ifids]) {
		// If we're not forcing a download, open the existing file
		if (downloadId && !forceDownload) {
			NSString* storyFilename = [[ZoomStoryOrganiser sharedStoryOrganiser] filenameForIdent: downloadId];
			if (storyFilename) {
				[[NSApp delegate] application: NSApp
									 openFile: storyFilename];
				return;
			}
		}
	}
	if ([[signpost ifids] count] > 0) downloadId = [[signpost ifids] objectAtIndex: 0];
	
	// Download the game
	NSURL* url = [signpost downloadURL];
	if (url) {
		[activeDownload setDelegate: nil];
		activeDownload = nil;

		signpostId = downloadId;

		downloadUpdateList = NO;
		downloadPlugin = NO;
		
		// Use mirror.ifarchive.org, not www.ifarchive.org
		NSString* host = [url host];
		if ([host isEqualToString: @"www.ifarchive.org"]) {
			NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:YES];
			components.host = @"mirror.ifarchive.org";
			url = components.URL;
		}
		
		activeDownload = [[ZoomDownload alloc] initWithUrl: url];
		[activeDownload setDelegate: self];
		[activeDownload startDownload];		
	}
}

- (void) failedToInstallPlugin: (NSString*) reason {
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = @"Could not install the plug-in";
	alert.informativeText = reason;
	[alert addButtonWithTitle:@"Cancel"];
	[alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
		//do nothing
	}];
}

static unsigned int ValueForHexChar(int hex) {
	if (hex >= '0' && hex <= '9') return hex - '0';
	if (hex >= 'a' && hex <= 'f') return hex - 'a' + 10;
	if (hex >= 'A' && hex <= 'F') return hex - 'A' + 10;
	return 0;
}

- (void) installSignpostPluginFrom: (NSData*) signpostXml {
	// Parse the property list
	NSDictionary* update = [NSPropertyListSerialization propertyListWithData: signpostXml
																	 options: NSPropertyListImmutable
																	  format: nil
																	   error: nil];
	
	if (update == nil || ![update isKindOfClass: [NSDictionary class]]) {
		// Not a valid update file
		[self failedToInstallPlugin: @"The plugin update file that was download does not appear to contain a valid property list."];
		return;
	}
	
	// Find a plugin that matches the signpost
	NSString* interpreter = [activeSignpost interpreterDisplayName];
	if (!interpreter || ![interpreter isKindOfClass: [NSString class]]) {
		[self failedToInstallPlugin: @"Oops, Zoom forgot which interpreter it was trying to install."];
		return;		
	}
	
	NSEnumerator* pluginEnum = [[update allValues] objectEnumerator];
	NSDictionary* pluginToInstall = nil;
	for (NSDictionary* plugInDetails in pluginEnum) {
		if (![plugInDetails isKindOfClass: [NSDictionary class]]) {
			continue;
		}
		
		NSString* displayName = [plugInDetails objectForKey: @"DisplayName"];
		if (!displayName || ![displayName isKindOfClass: [NSString class]]) {
			continue;
		}
		
		if ([displayName isEqualToString: interpreter]) {
			pluginToInstall = plugInDetails;
			break;
		}
	}
	
	if (!pluginToInstall) {
		[self failedToInstallPlugin: [NSString stringWithFormat: @"Zoom could not find a plugin for %@ at the specified site.", interpreter]];
		return;
	}
	
	// Get the URL and MD5 for the plugin
	NSString* urlString = [pluginToInstall objectForKey: @"URL"];
	NSString* md5raw = [pluginToInstall objectForKey: @"MD5"];
	
	if (!urlString || !md5raw || ![urlString isKindOfClass: [NSString class]] || ![md5raw isKindOfClass: [NSString class]]) {
		[self failedToInstallPlugin: [NSString stringWithFormat: @"Zoom found a plugin for %@ at the specified site, but could not establish a URL to download it from.", interpreter]];
		return;		
	}
	
	// Build a digest from string values
	unsigned char digest[16];
	for (int x=0; x<16; x++) {
		int pos = x*2;
		if (pos+1 >= [md5raw length]) break;
		
		unichar firstChar = [md5raw characterAtIndex: pos];
		unichar secondChar = [md5raw characterAtIndex: pos+1];
		
		digest[x] = (ValueForHexChar(firstChar)<<4)|ValueForHexChar(secondChar);
	}
	
	NSData* md5 = [[NSData alloc] initWithBytes: digest
										 length: 16];
	
	// Download the plugin
	[activeDownload setDelegate: nil];
	activeDownload = nil;
	
	signpostId = nil;
	
	downloadUpdateList = NO;
	downloadPlugin = YES;
	
	activeDownload = [[ZoomDownload alloc] initWithUrl: [NSURL URLWithString: urlString]];
	[activeDownload setDelegate: self];
	[activeDownload setExpectedMD5: md5];
	[activeDownload startDownload];
}

- (void) installPluginFrom: (ZoomDownload*) downloadedPlugin {
	NSEnumerator* downloadDirEnum = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath: [downloadedPlugin downloadDirectory] error: NULL] objectEnumerator];
	NSString* path;
	BOOL installed = NO;
	
	while (!installed && (path = [downloadDirEnum nextObject])) {
		NSString* extension = [[path pathExtension] lowercaseString];
		
		// Only install plugins
		if (![extension isEqualToString: @"plugin"] && ![extension isEqualToString: @"zoomplugin"]) {
			continue;
		}
		
		// We only install one plugin
		installed = YES;
		
		if (![[ZoomPlugInManager sharedPlugInManager] installPlugIn: [[downloadedPlugin downloadDirectory] stringByAppendingPathComponent: path]]) {
			[self failedToInstallPlugin: @"The plugin was successfully downloaded, but did not install correctly. This usually occurs because you do not have permission to modify the Zoom application."];
			return;
		}
	}
	
	if (!installed) {
		[self failedToInstallPlugin: @"No plugins were found in the file that was downloaded."];		
	}
	
	// Restart if necessary
	if ([[ZoomPlugInManager sharedPlugInManager] restartRequired]) {
		// Write out a startup signpost file
		NSString* startupSignpost = [[(ZoomAppDelegate*)[NSApp delegate] zoomConfigDirectory] stringByAppendingPathComponent: @"launch.signpost"];
		NSData* signpostData = [activeSignpost data];
		
		[signpostData writeToFile: startupSignpost
					   atomically: YES];
		
		// Restart Zoom
		[[ZoomPlugInController sharedPlugInController] restartZoom];
	} else {
		// Retry the signpost
		[self openSignPost: [activeSignpost data]
			 forceDownload: YES];
	}
}

@end
