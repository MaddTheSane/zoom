//
//  ZoomSound.m
//  ZoomView
//
//  Created by C.W. Betts on 4/10/22.
//

#import "ZoomSound.h"
#import "ZoomSoundChannelSound.h"
#import "ZoomSoundChannelMIDI.h"

@implementation ZoomSound {
	@private
	NSDictionary<NSNumber*, ZoomSoundChannel*> *channelMap;
}

- (instancetype) init {
	if (self = [super init]) {
		channelMap = [[NSDictionary alloc] init];
	}
	return self;
}

- (void) playAIFFOnChannel: (int) channel
				  withFile: (id<ZFile>) file
				  atOffset: (int) offset
				 andLength: (int) length {
	
}

- (void) playMODOnChannel: (int) channel
				 withFile: (id<ZFile>) file
				 atOffset: (int) offset
				andLength: (int) length {
	
}

- (void) stopSoundChannel: (int) chan {
	
}

- (void) setUpSoundChannel: (int) chan
				  atVolume: (int) vol
				   repeats: (int) repeatCount {
	
}

@end
