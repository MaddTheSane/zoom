//
//  ZoomSkeinLayoutItem.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 08/01/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "ZoomSkeinLayoutItem.h"


@implementation ZoomSkeinLayoutItem

// = Initialisation =

- (id) init {
	return [self initWithItem: nil
						width: 0
					fullWidth: 0
						level: 0];
}

- (id) initWithItem: (ZoomSkeinItem*) newItem
			  width: (CGFloat) newWidth
		  fullWidth: (CGFloat) newFullWidth
			  level: (int) newLevel {
	self = [super init];
	
	if (self) {
		item = [newItem retain];
		width = newWidth;
		fullWidth = newFullWidth;
		level = newLevel;
		depth = 0;
	}
	
	return self;
}

- (void) dealloc {
	if (item) [item release];
	if (children) [children release];
	
	[super dealloc];
}

// = Getting properties =

@synthesize item;
@synthesize width;
@synthesize fullWidth;
@synthesize position;
@synthesize children;
@synthesize level;
@synthesize onSkeinLine;
@synthesize depth;
@synthesize recentlyPlayed;

// = Setting properties =

- (void) setChildren: (NSArray*) newChildren {
	if (children) [children release];
	children = [newChildren retain];
	
	NSInteger maxDepth = -1;
	
	for (ZoomSkeinLayoutItem* child in children) {
		if ([child depth] > maxDepth) maxDepth = [child depth];
	}
	
	depth = maxDepth+1;
}

- (void) findItemsOnLevel: (int) findLevel
				   result: (NSMutableArray*) result {
	if (findLevel < level) return;
	
	if (findLevel == level) {
		[result addObject: self];
		return;
	} else if (findLevel == level-1) {
		if (children) [result addObjectsFromArray: children];
		return;
	} else if (children) {
		NSEnumerator* childEnum = [children objectEnumerator];
		ZoomSkeinLayoutItem* child;
		
		while (child = [childEnum nextObject]) {
			[child findItemsOnLevel: findLevel
							 result: result];
		}
	}
}

- (NSArray*) itemsOnLevel: (int) findLevel {
	NSMutableArray* result = [NSMutableArray array];
	
	[self findItemsOnLevel: findLevel
					result: result];
	
	return result;
}

@end
