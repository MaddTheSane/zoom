//
//  ZoomSkeinController.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sun Jul 04 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

#import "ZoomSkein.h"
#import "ZoomSkeinView.h"

@interface ZoomSkeinController : NSWindowController <ZoomSkeinViewDelegate> {
	IBOutlet ZoomSkeinView* skeinView;
}

@property (class, readonly, strong) ZoomSkeinController *sharedSkeinController;

- (void) setSkein: (ZoomSkein*) skein;
- (ZoomSkein*) skein;
@property (nonatomic, strong) ZoomSkein *skein;

@end
