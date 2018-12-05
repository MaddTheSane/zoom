//
//  ZoomLowerWindow.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Oct 08 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomProtocol.h"
#import "ZoomView.h"

@interface ZoomLowerWindow : NSObject<ZLowerWindow, NSCoding> {
    __unsafe_unretained ZoomView* zoomView;
	
	ZStyle* backgroundStyle;
	ZStyle* inputStyle;
}

- (instancetype) initWithZoomView: (ZoomView*) zoomView;

@property (readonly, retain) ZStyle *backgroundStyle;

@property (assign) ZoomView *zoomView;

@end
