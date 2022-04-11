//
//  ZoomCursor.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jun 25 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


NS_ASSUME_NONNULL_BEGIN

@class ZoomCursor;

@protocol ZoomCursorDelegate <NSObject>
@optional

- (void) blinkCursor: (ZoomCursor*) sender;

@end

NS_ASSUME_NONNULL_END
