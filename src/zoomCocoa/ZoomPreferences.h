//
//  ZoomPreferences.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sun Dec 21 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const ZoomPreferencesHaveChangedNotification;

typedef NS_ENUM(NSInteger, GlulxInterpreter) {
	GlulxGit		= 0,
	GlulxGlulxe		= 1
};

@class ZoomPreferences;

NS_ASSUME_NONNULL_END
