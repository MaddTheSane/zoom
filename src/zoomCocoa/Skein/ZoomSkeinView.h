//
//  ZoomSkeinView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Jul 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

#import <ZoomView/ZoomSkein.h>
#import <ZoomView/ZoomSkeinItem.h>
#import <ZoomView/ZoomSkeinLayout.h>

@protocol ZoomSkeinViewDelegate;

extern NSPasteboardType const ZoomSkeinItemPboardType NS_SWIFT_NAME(zoomSkeinItem);

@interface ZoomSkeinView : NSView <NSTextViewDelegate, NSDraggingDestination>  {
	ZoomSkein* skein;
	
	BOOL skeinNeedsLayout;
	
	// Layout
	ZoomSkeinLayout* layout;
	
	// Cursor flags
	BOOL overWindow;
	BOOL overItem;
	
	NSMutableArray* trackingRects;
	NSMutableArray* trackingItems;
	ZoomSkeinItem* trackedItem;
	ZoomSkeinItem* clickedItem;
	
	// Dragging items
	BOOL    dragCanMove;

	// Drag scrolling
	BOOL    dragScrolling;
	NSPoint dragOrigin;
	NSRect  dragInitialVisible;
	
	// Clicking buttons
	NSInteger activeButton;
	NSInteger lastButton;
	
	// Annoyingly poor support for tracking rects band-aid
	NSRect lastVisibleRect;
	
	// Editing things
	ZoomSkeinItem* itemToEdit;
	ZoomSkeinItem* mostRecentItem;
	NSScrollView* fieldScroller;
	NSTextView* fieldEditor;
	NSTextStorage* fieldStorage;
	
	BOOL editingAnnotation;
	
	CGFloat itemWidth;
	CGFloat itemHeight;
	
	// The delegate
	__weak id<ZoomSkeinViewDelegate> delegate;
	
	// Context menu
	ZoomSkeinItem* contextItem;
}

// Setting/getting the source
@property (nonatomic, strong) ZoomSkein* skein;

// Laying things out
- (void) skeinNeedsLayout;

@property (nonatomic) CGFloat itemWidth;
@property (nonatomic) CGFloat itemHeight;

// The delegate
@property (weak) id<ZoomSkeinViewDelegate> delegate;

// Affecting the display
- (void) scrollToItem: (ZoomSkeinItem*) item;

- (void) editItem: (ZoomSkeinItem*) skeinItem;
- (void) editItemAnnotation: (ZoomSkeinItem*) skeinItem;
@property (retain) ZoomSkeinItem *selectedItem;

- (void) highlightSkeinLine: (ZoomSkeinItem*) itemOnLine;

- (void) layoutSkein;

- (void)updateSkein:(id)sender;

@end

// = Using with the web kit =
#import <WebKit/WebDocument.h>

@interface ZoomSkeinView(ZoomSkeinViewWeb)<WebDocumentView>

@end

// = Delegate =
@protocol ZoomSkeinViewDelegate <NSObject>
@optional

// Playing the game
- (void) restartGame;
- (void) playToPoint: (ZoomSkeinItem*) point
		   fromPoint: (ZoomSkeinItem*) currentPoint;

// The transcript
- (void) transcriptToPoint: (ZoomSkeinItem*) point;

// Various types of possible error
- (void) cantDeleteActiveBranch;										//!< User attempted to delete an item on the active skein branch (which can't be done)
- (void) cantEditRootItem;												//!< User attemptted to edit the root skein item

@end
