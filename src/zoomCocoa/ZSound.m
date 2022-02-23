//
//  ZSound.m
//  ZoomServer
//
//  Created by C.W. Betts on 2/23/22.
//

#import "ZoomProtocol.h"
#import "ZoomZMachine.h"
#import "ZoomServer.h"

#include "sound.h"


void sound_initialise(void)
{
    if ([mainMachine.display respondsToSelector:@selector(setUpSound)]) {
        [mainMachine.display setUpSound];
    } else {
        NSLog(@"Function not implemented: %s %s:%i", __FUNCTION__, __FILE__, __LINE__);
    }
}

void sound_finalise(void)
{
    if ([mainMachine.display respondsToSelector:@selector(finalizeSound)]) {
        [mainMachine.display finalizeSound];
    } else {
        NSLog(@"Function not implemented: %s %s:%i", __FUNCTION__, __FILE__, __LINE__);
    }
}

void sound_play_aiff(int    channel,
                     ZFile* file,
                     int    offset,
                     int    len)
{
    if ([mainMachine.display respondsToSelector:@selector(playAIFFOnChannel:withFile:atOffset:andLength:)]) {
        [mainMachine.display playAIFFOnChannel: channel
                                      withFile: file->theFile
                                      atOffset: offset
                                     andLength: len];
    } else {
        NSLog(@"Function not implemented: %s %s:%i", __FUNCTION__, __FILE__, __LINE__);
    }
}

void sound_play_mod(int    channel,
                    ZFile* file,
                    int    offset,
                    int    len)
{
    if ([mainMachine.display respondsToSelector:@selector(playMODOnChannel:withFile:atOffset:andLength:)]) {
        [mainMachine.display playMODOnChannel: channel
                                     withFile: file->theFile
                                     atOffset: offset
                                    andLength: len];
    } else {
        NSLog(@"Function not implemented: %s %s:%i", __FUNCTION__, __FILE__, __LINE__);
    }
}

void sound_stop_channel(int channel)
{
    if ([mainMachine.display respondsToSelector:@selector(stopSoundChannel:)]) {
        [mainMachine.display stopSoundChannel: channel];
    } else {
        NSLog(@"Function not implemented: %s %s:%i", __FUNCTION__, __FILE__, __LINE__);
    }
}

void sound_setup_channel(int channel,
                         int volume,
                         int repeat)
{
    if ([mainMachine.display respondsToSelector:@selector(setUpSoundChannel:atVolume:repeats:)]) {
        [mainMachine.display setUpSoundChannel: channel
                                      atVolume: volume
                                       repeats: repeat];
    } else {
        NSLog(@"Function not implemented: %s %s:%i", __FUNCTION__, __FILE__, __LINE__);
    }
}
