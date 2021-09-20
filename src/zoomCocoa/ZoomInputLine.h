//
//  ZoomInputLine.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Jun 26 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomView/ZoomCursor.h>

@protocol ZoomInputLineDelegate;

@interface ZoomInputLine : NSObject {
	ZoomCursor* cursor;
	
	__weak id<ZoomInputLineDelegate> delegate;
	
	NSMutableString* lineString;
	NSMutableDictionary<NSAttributedStringKey, id>* attributes;
	NSInteger		 insertionPos;
}

- (id) initWithCursor: (ZoomCursor*) cursor
		   attributes: (NSDictionary<NSAttributedStringKey, id>*) attr;

- (void) drawAtPoint: (NSPoint) point;
@property (readonly) NSSize size;
- (NSRect) rectForPoint: (NSPoint) point;

- (void) keyDown: (NSEvent*) evt;

- (NSString*) inputLine;

@property (weak) id<ZoomInputLineDelegate> delegate;

- (NSString*) lastHistoryItem;
- (NSString*) nextHistoryItem;

- (void) updateCursor;

@end

@protocol ZoomInputLineDelegate <NSObject>
@optional

- (void) inputLineHasChanged: (ZoomInputLine*) sender;
- (void) endOfLineReached: (ZoomInputLine*) sender;

- (NSString*) lastHistoryItem;
- (NSString*) nextHistoryItem;

@end
