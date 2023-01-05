//
//  ZoomClientController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <ZoomView/ZoomView.h>
#import <ZoomView/ZoomSkeinView.h>
#import "ZoomClient.h"


@interface ZoomClientController : NSWindowController <NSWindowDelegate, ZoomViewDelegate, ZoomSkeinViewDelegate> {
	BOOL finished;
	BOOL closeConfirmed;
	BOOL shownOnce;
	
	NSSize oldZoomViewSize;

	NSTimeInterval fadeTime;
	NSTimeInterval waitTime;
	NSDate* fadeStart;
	NSTimer* fadeTimer;
	NSWindow* logoWindow;
}

- (IBAction) recordGameInfo: (id) sender;
- (IBAction) updateGameInfo: (id) sender;

- (IBAction) playInFullScreen: (id) sender;

@property (strong) IBOutlet ZoomView *zoomView;
- (void) showLogoWindow;

@end
