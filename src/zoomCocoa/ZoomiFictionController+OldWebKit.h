//
//  ZoomiFictionController+OldWebKit.h
//  ZoomCocoa
//
//  Created by C.W. Betts on 10/3/21.
//

#ifndef ZoomiFictionController_OldWebKit_h
#define ZoomiFictionController_OldWebKit_h

#import "ZoomiFictionController.h"
#import <WebKit/WebKit.h>

@interface ZoomiFictionController () <WebFrameLoadDelegate, WebPolicyDelegate> {
	IBOutlet WebView* ifdbView;
}

@end

#endif /* ZoomiFictionController_OldWebKit_h */
