//
//  ZoomLeopard.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 28/10/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/CAAnimation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(ZoomLeopardProtocol)
@protocol ZoomLeopard <NSObject>

// = Animations =

/// Causes a view to do a 'pop up' animation
- (void) popView: (NSView*) view
		duration: (NSTimeInterval) seconds
		finished: (void (^ _Nullable)(void)) finished;
/// Causes a view to do a 'pop out' animation
- (void) popOutView: (NSView*) view
		   duration: (NSTimeInterval) seconds
		   finished: (void (^ _Nullable)(void)) finished;
/// Removes the layers for the specified view
- (void) clearLayersForView: (NSView*) view;

/// Animates a view to full screen
- (void) fullScreenView: (NSView*) view
			  fromFrame: (NSRect) oldWindowFrame
				toFrame: (NSRect) newWindowFrame;
@end

NS_ASSUME_NONNULL_END
