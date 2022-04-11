//
//  ZoomSound.h
//  ZoomView
//
//  Created by C.W. Betts on 4/10/22.
//

#import <Foundation/Foundation.h>
#import <ZoomView/ZoomProtocol.h>
#import "ZoomSoundChannel.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZoomSound : NSObject

- (instancetype) init;

- (void) playAIFFOnChannel: (int) channel
				  withFile: (id<ZFile>) file
				  atOffset: (int) offset
				 andLength: (int) length;

- (void) playMODOnChannel: (int) channel
				 withFile: (id<ZFile>) file
				 atOffset: (int) offset
				andLength: (int) length;

- (void) stopSoundChannel: (int) chan;

- (void) setUpSoundChannel: (int) chan
				  atVolume: (int) vol
				   repeats: (int) repeatCount;

@end

NS_ASSUME_NONNULL_END
