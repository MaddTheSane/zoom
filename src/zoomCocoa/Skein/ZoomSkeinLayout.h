//
//  ZoomSkeinLayout.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Jul 21 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomView/ZoomSkein.h>
#import <ZoomView/ZoomSkeinLayoutItem.h>

typedef NS_ENUM(int, IFSkeinPackingStyle) {
	IFSkeinPackLoose NS_SWIFT_NAME(loose),
	IFSkeinPackTight NS_SWIFT_NAME(tight)
};

@interface ZoomSkeinLayout : NSObject {
	ZoomSkeinItem* rootItem;

	// Item mapping
	NSMutableDictionary* itemForItem;
	
	// The layout
	ZoomSkeinLayoutItem* tree;
	NSMutableArray* levels;
	CGFloat globalOffset, globalWidth;
	
	CGFloat itemWidth;
	CGFloat itemHeight;
	IFSkeinPackingStyle packingStyle;
	
	// Highlighted skein line
	ZoomSkeinItem* highlightedLineItem;
	NSMutableSet*  highlightedSet;
	
	// Some extra status
	ZoomSkeinItem* activeItem;
	ZoomSkeinItem* selectedItem;
}

// Initialisation
- (id) initWithRootItem: (ZoomSkeinItem*) item;

// Setting skein data
- (void) setItemWidth: (CGFloat) itemWidth;
- (void) setItemHeight: (CGFloat) itemHeight;
- (void) setPackingStyle: (int) packingStyle;

@property (retain) ZoomSkeinItem *rootItem;
@property (nonatomic, retain) ZoomSkeinItem *activeItem;
@property (retain) ZoomSkeinItem *selectedItem;
- (void) highlightSkeinLine: (ZoomSkeinItem*) itemOnLine;

// Performing the layout
- (void) layoutSkein;
- (void) layoutSkeinLoose;
- (void) layoutSkeinTight;

// Getting layout data
@property (readonly) NSInteger levels;
- (NSArray<ZoomSkeinItem*>*) itemsOnLevel: (NSInteger) level;
- (NSArray*) dataForLevel: (NSInteger) level;

- (ZoomSkeinLayoutItem*) dataForItem: (ZoomSkeinItem*) item;

// General item data
- (CGFloat)  xposForItem:      (ZoomSkeinItem*) item;
- (int)      levelForItem:     (ZoomSkeinItem*) item;
- (CGFloat)  widthForItem:     (ZoomSkeinItem*) item;
- (CGFloat)  fullWidthForItem: (ZoomSkeinItem*) item;

// Item positioning data
@property (readonly) NSSize size;

- (NSRect) activeAreaForItem: (ZoomSkeinItem*) itemData;
- (NSRect) textAreaForItem: (ZoomSkeinItem*) itemData;
- (NSRect) activeAreaForData: (ZoomSkeinLayoutItem*) itemData;
- (NSRect) textAreaForData: (ZoomSkeinLayoutItem*) itemData;
- (ZoomSkeinItem*) itemAtPoint: (NSPoint) point;

// Drawing
- (void) drawInRect: (NSRect) rect;
- (void) drawItem: (ZoomSkeinItem*) item
		  atPoint: (NSPoint) point;
- (NSImage*) imageForItem: (ZoomSkeinItem*) item;
- (NSImage*) image;

@end
