//
//  ZoomSkeinLayout.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Jul 21 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ZoomView/ZoomSkein.h>
#import <ZoomView/ZoomSkeinItem.h>
#import <ZoomView/ZoomSkeinLayoutItem.h>

typedef NS_ENUM(int, IFSkeinPackingStyle) {
	IFSkeinPackLoose NS_SWIFT_NAME(loose),
	IFSkeinPackTight NS_SWIFT_NAME(tight)
};

@interface ZoomSkeinLayout : NSObject

#pragma mark Initialisation
- (id) initWithRootItem: (ZoomSkeinItem*) item;

#pragma mark Setting skein data
@property (nonatomic) CGFloat itemWidth;
@property CGFloat itemHeight;
@property IFSkeinPackingStyle packingStyle;

@property (retain) ZoomSkeinItem *rootItem;
@property (nonatomic, retain) ZoomSkeinItem *activeItem;
@property (retain) ZoomSkeinItem *selectedItem;
- (void) highlightSkeinLine: (ZoomSkeinItem*) itemOnLine;

#pragma mark Performing the layout
- (void) layoutSkein;
- (void) layoutSkeinLoose;
- (void) layoutSkeinTight;

#pragma mark Getting layout data
@property (readonly) NSInteger levels;
- (NSArray<ZoomSkeinItem*>*) itemsOnLevel: (NSInteger) level;
- (NSArray<ZoomSkeinLayoutItem*>*) dataForLevel: (NSInteger) level;

- (ZoomSkeinLayoutItem*) dataForItem: (ZoomSkeinItem*) item;

#pragma mark General item data
- (CGFloat)  xposForItem:      (ZoomSkeinItem*) item;
- (int)      levelForItem:     (ZoomSkeinItem*) item;
- (CGFloat)  widthForItem:     (ZoomSkeinItem*) item;
- (CGFloat)  fullWidthForItem: (ZoomSkeinItem*) item;

#pragma mark Item positioning data
@property (readonly) NSSize size;

- (NSRect) activeAreaForItem: (ZoomSkeinItem*) itemData;
- (NSRect) textAreaForItem: (ZoomSkeinItem*) itemData;
- (NSRect) activeAreaForData: (ZoomSkeinLayoutItem*) itemData;
- (NSRect) textAreaForData: (ZoomSkeinLayoutItem*) itemData;
- (ZoomSkeinItem*) itemAtPoint: (NSPoint) point;

#pragma mark Drawing
- (void) drawInRect: (NSRect) rect;
- (void) drawItem: (ZoomSkeinItem*) item
		  atPoint: (NSPoint) point;
- (NSImage*) imageForItem: (ZoomSkeinItem*) item;
- (NSImage*) image;

@end
