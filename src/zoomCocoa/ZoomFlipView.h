//
//  ZoomFlipView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 23/09/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

typedef NS_ENUM(NSInteger, ZoomViewAnimationStyle) {
	ZoomAnimateLeft,
	ZoomAnimateRight,
	ZoomAnimateFade,
	
	ZoomCubeDown,
	ZoomCubeUp
};

///
/// NSView subclass that allows us to flip between several views using Core Animation.
///
@interface ZoomFlipView : NSView <CALayerDelegate, CALayoutManager, CAAnimationDelegate> {
	// The start and the end of the animation
	NSImage* startImage;
	NSImage* endImage;
	
	// Animation settings
	NSTimeInterval animationTime;
	ZoomViewAnimationStyle animationStyle;
	
	// Leopard property dictionary
	NSMutableDictionary* props;
	
	// Information used while animating
	NSTimer* animationTimer;
	NSRect originalFrame;
	NSView* originalView;
	NSView* originalSuperview;
	NSDate* whenStarted;	
}

// Animating
- (void) setAnimationTime: (NSTimeInterval) animationTime;			// Changes the animation time
- (NSTimeInterval) animationTime;									// The animation time
- (void) prepareToAnimateView: (NSView*) view;						// Prepares to animate, using the specified view as a template
- (void) animateTo: (NSView*) view									// Begins animating the specified view so that transitions from the state set in prepareToAnimateView to the new state
			 style: (ZoomViewAnimationStyle) style;
- (void) finishAnimation;											// Abandons any running animation
- (NSMutableDictionary*) propertyDictionary;						// Property dictionary used for the leopard extensions

@end

@interface NSObject(ZoomViewAnimation)

- (void) removeTrackingRects;										// Optional method implemented by views that is a request from the animation view to remove any applicable tracking rectangles
- (void) setTrackingRects;											// Optional method implemented by views that is a request from the animation view to add any tracking rectangles back again

@end
