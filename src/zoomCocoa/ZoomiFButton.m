//
//  ZoomiFButton.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jan 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomiFButton.h"


@implementation ZoomiFButton

/*
static NSImage* disabledImage;

+ (void) initialize {
	disabledImage = [[NSImage imageNamed: @"disabledButton"] retain];
}
*/

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
		pushedImage = nil;
    }
    return self;
}

@synthesize pushedImage;
- (void) setPushedImage: (NSImage*) newPushedImage {
	pushedImage = newPushedImage;
	
	// Generate a greyed-out image
	NSRect imgRect = NSMakeRect(0,0,0,0);
	imgRect.size = [[self image] size];
	
	disabledImage = [[self image] copy];
	
	NSImage* tempImage = [[NSImage alloc] initWithSize: [[self image] size]];
	[tempImage lockFocus];
	[[NSColor whiteColor] set];
	NSRectFill(imgRect);
	[tempImage unlockFocus];
	
	[disabledImage lockFocus];
	[tempImage drawInRect: imgRect
				 fromRect: imgRect
				operation: NSCompositingOperationSourceAtop
				 fraction: 0.4];
	[disabledImage unlockFocus];
}

- (void) mouseDown: (NSEvent*) theEvent {
	if (![self isEnabled]) return;
	
	if (!unpushedImage) {
		unpushedImage = [self image];
		[self setImage: pushedImage];
		
		inside = YES;
		theTrackingRect = [self addTrackingRect: [self bounds]
										  owner: self 
									   userData: nil
								   assumeInside: YES];
	}
}

- (void) mouseEntered: (NSEvent*) theEvent {
	if (![self isEnabled]) return;

	if (unpushedImage) {
		[self setImage: pushedImage];
		inside = YES;
	}
}

- (void) mouseExited: (NSEvent*) theEvent {	
	if (![self isEnabled]) return;

	if (unpushedImage) {
		[self setImage: unpushedImage];
		inside = NO;
	}
}

- (void) mouseUp: (NSEvent *) theEvent {
	if (![self isEnabled]) return;

	if (unpushedImage) {
		[self setImage: unpushedImage];
		unpushedImage = nil;
		
		[self removeTrackingRect: theTrackingRect];
		
		if (inside) {
			[self sendAction: [self action] 
						  to: [self target]];
		}
	}
}

- (void) mouseDragged: (NSEvent*) theEvent {
	if (![self isEnabled]) return;
	
	// If the mouse has moved outside, then unpush ourselves
	// If the mouse has moved inside, then push ourselves
	NSPoint where = [self convertPoint: [theEvent locationInWindow] fromView: nil];
	
	if (NSPointInRect(where, [self bounds])) {
		if (unpushedImage) {
			[self setImage: pushedImage];
			inside = YES;
		}
	} else {
		if (unpushedImage) {
			[self setImage: unpushedImage];
			inside = NO;
		}
	}
}

- (void) setEnabled: (BOOL) enabled {
	if (!enabled) {
		if (!unpushedImage) {
			unpushedImage = [self image];
			[self setImage: disabledImage];
		}
	} else {
		if (unpushedImage) {
			[self setImage: unpushedImage];
			unpushedImage = nil;
		}
	}
	
	[super setEnabled: enabled];
}

- (BOOL) acceptsFirstMouse: (NSEvent*) evt {
	return YES;
}

@end
