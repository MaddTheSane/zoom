//
//  ZoomSoundChannel.h
//  ZoomView
//
//  Created by C.W. Betts on 4/10/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ZoomSound;

@interface ZoomSoundChannel : NSObject {
	int loop;
	int notify;
	int paused;

	int resid; /* for notifies */

	/* for volume fades */
	int volume_notify;
	int volume_timeout;
	float target_volume;
	float volume;
	float volume_delta;
	NSTimer *timer;
}



@property (weak) ZoomSound *soundManager;

@end

NS_ASSUME_NONNULL_END
