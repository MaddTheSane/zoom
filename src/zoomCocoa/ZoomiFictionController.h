//
//  ZoomiFictionController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jan 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import <ZoomPlugIns/ZoomStory.h>
@class CollapsableView;
@class SavePreviewView;
@class FadeView;
#import "ZoomCollapsingSplitView.h"
#import <ZoomPlugIns/ZoomResourceDrop.h>
#import "ZoomStoryTableView.h"
#import <ZoomPlugIns/ZoomMetadata.h>
#import "ZoomFlipView.h"
@class DownloadView;
#import <ZoomPlugIns/ZoomDownload.h>
#import "ZoomJSError.h"
#import "ZoomSignPost.h"

@interface ZoomiFictionController : NSWindowController <NSTextStorageDelegate, ZoomDownloadDelegate, NSTableViewDataSource, NSOpenSavePanelDelegate, NSControlTextEditingDelegate, NSMenuItemValidation, NSTabViewDelegate>
{
	IBOutlet NSButton* addButton;
	IBOutlet NSButton* newgameButton;
	IBOutlet NSButton* continueButton;
	IBOutlet NSButton* infoButton;
	
	//IBOutlet CollapsableView* collapseView;
	
	IBOutlet ZoomFlipView* flipView;
	IBOutlet NSTabView* topPanelView;
	IBOutlet NSButton *savesFlipButton;
	IBOutlet NSButton *infoFlipButton;
	IBOutlet NSButton *filtersFlipButton;
	IBOutlet FadeView *fadeView;
	
	IBOutlet NSView* mainView;
	IBOutlet NSView* browserView;
	
	IBOutlet NSTextField* currentUrl;
	IBOutlet NSButton* playButton;
	IBOutlet NSButton* forwardButton;
	IBOutlet NSButton* backButton;
	IBOutlet NSButton* homeButton;
	NSWindow* downloadWindow;
	DownloadView* downloadView;
	
	IBOutlet NSWindow* picturePreview;
	IBOutlet NSImageView* picturePreviewView;
	
	IBOutlet NSProgressIndicator* progressIndicator;
	int indicatorCount;
	
	IBOutlet NSTextView* gameDetailView;
	IBOutlet NSImageView* gameImageView;
	
	IBOutlet ZoomCollapsingSplitView* splitView;
	
	CGFloat splitViewPercentage;
	BOOL splitViewCollapsed;
	
	IBOutlet ZoomStoryTableView* mainTableView;
	IBOutlet NSTableView* filterTable1;
	IBOutlet NSTableView* filterTable2;
	
	IBOutlet NSTextField* searchField;
	
	IBOutlet NSMenu* storyMenu;
	IBOutlet NSMenu* saveMenu;
	
	BOOL showDrawer;
	
	BOOL needsUpdating;
	
	BOOL queuedUpdate;
	BOOL isFiltered;
	BOOL saveGamesAvailable;
	
	// Save game previews
	IBOutlet SavePreviewView* previewView;
	
	// Resource drop zone
	ZoomResourceDrop* resourceDrop;
	
	// Data source information
	NSMutableArray* filterSet1;
	NSMutableArray* filterSet2;
	
	NSMutableArray<ZoomStoryID*>* storyList;
	NSString*       sortColumn;
	
	// The browser
	/// \c YES if the browser has been used
	BOOL usedBrowser;
	/// \c YES if the browser is being displayed
	BOOL browserOn;
	/// \c YES if we've turned on small fonts in the browser
	BOOL smallBrowser;
	
	/// The currently active download
	ZoomDownload* activeDownload;
	/// The fade in/out timer for the download window
	NSTimer* downloadFadeTimer;
	/// The time the current fade operation started
	NSDate* downloadFadeStart;
	/// The opacity when the last fade operation started
	double initialDownloadOpacity;
	
	/// Story to open after the download has completed
	ZoomStoryID* signpostId;
	/// The name of the plugin to install
	NSString* installPlugin;
	/// The active signpost file
	ZoomSignPost* activeSignpost;
	/// \c YES if we're trying to download an update list
	BOOL downloadUpdateList;
	/// \c YES if we're trying to download a .zoomplugin file
	BOOL downloadPlugin;
	
	/// The last error to occur
	ZoomJSError* lastError;
}

@property (class, readonly, strong) ZoomiFictionController *sharediFictionController NS_SWIFT_NAME(shared);

- (IBAction) addButtonPressed: (id) sender;
- (IBAction) startNewGame: (id) sender;
- (IBAction) restoreAutosave: (id) sender;
- (IBAction) searchFieldChanged: (id) sender;
- (IBAction) changeFilter1: (id) sender;
- (IBAction) changeFilter2: (id) sender;
- (IBAction) delete: (id) sender;
- (IBAction) deleteSavegame: (id) sender;

- (IBAction) flipToFilter: (id) sender;
- (IBAction) flipToInfo: (id) sender;
- (IBAction) flipToSaves: (id) sender;

- (IBAction) showIfDb: (id) sender;
- (IBAction) showLocalGames: (id) sender;
- (IBAction) goBack: (id) sender;
- (IBAction) goForward: (id) sender;
- (IBAction) goHome: (id) sender;
- (IBAction) playIfdbGame: (id) sender;

- (ZoomStory*) storyForID: (ZoomStoryID*) ident;
- (void) configureFromMainTableSelection;
- (void) reloadTableData;

- (void) mergeiFictionFromFile: (NSString*) filename;
- (BOOL) mergeiFictionFromURL: (NSURL*) filename error: (NSError**) outError;
- (NSArray<ZoomStory*>*) mergeiFictionFromMetabase: (ZoomMetadata*) newData;

- (void) addFiles: (NSArray<NSString*> *)filenames DEPRECATED_MSG_ATTRIBUTE("use -addURLs: instead");
- (void) addURLs: (NSArray<NSURL*> *)filenames;

- (void) setupSplitView;
- (void) collapseSplitView;

- (void) openSignPost: (NSData*) signpostFile
		forceDownload: (BOOL) download;

@end
