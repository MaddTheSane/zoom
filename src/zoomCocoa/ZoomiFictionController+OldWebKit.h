//
//  ZoomiFictionController+OldWebKit.h
//  ZoomCocoa
//
//  Created by C.W. Betts on 10/3/21.
//

#ifndef ZoomiFictionController_OldWebKit_h
#define ZoomiFictionController_OldWebKit_h

#import <Cocoa/Cocoa.h>
#import "ZoomiFictionController.h"
#import <WebKit/WebKit.h>

@interface ZoomiFictionController () {
	IBOutlet WebView* ifdbView;
}

- (BOOL) canPlayFile: (NSString*) filename;
- (void) updateBackForwardButtons;
- (void) hideDownloadWindow: (NSTimeInterval) duration;
@end

@interface ZoomiFictionController (OldWebKit) <WebFrameLoadDelegate, WebPolicyDelegate>

@end

#endif /* ZoomiFictionController_OldWebKit_h */
