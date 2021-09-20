//
//  ZoomSkeinItem.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jul 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Commentary comparison results
typedef NS_ENUM(NSInteger, ZoomSkeinComparison) {
	//! One side of the comparison doesn't exist (eg, no commentary for an item)
	ZoomSkeinNoResult,
	//! Sides are identical
	ZoomSkeinIdentical,
	//! Sides are different, but only in terms of whitespace
	ZoomSkeinDiffersOnlyByWhitespace,
	//! Sides are different
	ZoomSkeinDifferent,
	
	//! (Placeholder: sides have not been compared)
	ZoomSkeinNotCompared
};

// Skein item notifications
//! One skein item is being replaced by another
extern NSNotificationName const ZoomSkeinItemIsBeingReplaced;
//! A skein item is being removed from the tree (may be associated with the previous)
extern NSNotificationName const ZoomSkeinItemHasBeenRemovedFromTree;
//! A skein item has been changed in some way
extern NSNotificationName const ZoomSkeinItemHasChanged;
//! A skein item has gained a new child item
extern NSNotificationName const ZoomSkeinItemHasNewChild;

// Skein item notification dictionary keys
//! Item the operation applies to
extern NSString* const ZoomSIItem;
//! Previous item, if there is one
extern NSString* const ZoomSIOldItem;
//! Parent item of an item that's been removed
extern NSString* const ZoomSIOldParent;
//! Child item (if relevant)
extern NSString* const ZoomSIChild;

//!
//! Represents a single 'knot' in the skein
//!
@interface ZoomSkeinItem : NSObject<NSSecureCoding> {
	__weak ZoomSkeinItem* parent;
	NSMutableSet<ZoomSkeinItem*>* children;
	
	NSString*     command;
	NSString*     result;
	
	BOOL temporary;
	int  tempScore;
	
	BOOL played, changed;
	
	NSString* annotation;
	NSString* commentary;
	
	// Cached layout items (text measuring is slow)
	BOOL   commandSizeDidChange;
	NSSize commandSize;
	
	BOOL   annotationSizeDidChange;
	NSSize annotationSize;
	
	// Results of comparing the result to the commentary
	ZoomSkeinComparison commentaryComparison;
}

// Initialisation
+ (instancetype) skeinItemWithCommand: (NSString*) command;

- (instancetype) initWithCommand: (NSString*) command;

// Data accessors

// Skein tree
@property (readonly, weak) ZoomSkeinItem* parent;
- (NSSet<ZoomSkeinItem*>*)children;
- (ZoomSkeinItem*) childWithCommand: (NSString*) command;

- (ZoomSkeinItem*) addChild: (ZoomSkeinItem*) childItem;
- (void)		   removeChild: (ZoomSkeinItem*) childItem;
- (void)		   removeFromParent;

- (BOOL)           hasChild: (ZoomSkeinItem*) child; // Recursive
- (BOOL)           hasChildWithCommand: (NSString*) command; // Not recursive

// Item data
@property (nonatomic, copy) NSString *command; // Command input
@property (nonatomic, copy) NSString *result;  // Command result

// Item state
//! Whether or not this item has been made permanent by saving
@property (nonatomic) BOOL temporary;
//! Lower values are more likely to be removed
@property int temporaryScore;
//! Whether or not this item has actually been played
@property (nonatomic) BOOL played;
//! Whether or not this item's result has changed since this was last played
//! (Automagically updated by setResult:)
@property (nonatomic) BOOL changed;

- (void) setBranchTemporary: (BOOL) isTemporary;
- (void) increaseTemporaryScore;

// Annotation

//! Allows the player to designate certain areas of the skein as having specific annotations and colours
//! (So, for example an area can be called 'solution to the maximum mouse melee puzzle')
//! Each 'annotation' colours a new area of the skein.
@property (nonatomic, copy) NSString *annotation;

// Commentary

//! Could be used by an IDE to store commentary or perhaps the 'ideal' text the game should be
//! producing for this item
@property (nonatomic, copy) NSString *commentary;
- (ZoomSkeinComparison) commentaryComparison;
//! Finds the first item following this one that has a difference
- (ZoomSkeinItem*) nextDiff;

// Drawing/sizing
@property (readonly) NSSize commandSize;
- (void) drawCommandAtPosition: (NSPoint) position;
@property (readonly) NSSize annotationSize;
- (void) drawAnnotationAtPosition: (NSPoint) position;

@end
