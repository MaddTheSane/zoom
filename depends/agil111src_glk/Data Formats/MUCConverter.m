//
//  MUCConverter.m
//  agil
//
//  Created by C.W. Betts on 10/15/24.
//

#import "MUCConverter.h"
#import <AVFAudio/AVFAudio.h>


/*
 Songs are stored in the MUC file format:
   The file format includes no header, but is a collection of
 six-byte records. Each record consists of three unsigned 16-bit
 numbers (stored little-endian like all numbers under AGT: the least
 significant byte comes first): the frequency (in Hertz); the length of
 time of the tone (in milliseconds); and a delay between tones (also in
 milliseconds).
 */

typedef struct MUCEntry {
	//! the frequency (in Hertz).
	uint16_t frequency;
	//! the length of time of the tone (in milliseconds)
	uint16_t toneTime;
	//! and a delay between tones (also in milliseconds)
	uint16_t toneDelay;
} MUCEntry;

@interface AGILMUCEntry : NSObject
//! the frequency (in Hertz).
@property uint16_t frequency;
//! the length of time of the tone (in milliseconds)
@property uint16_t toneTime;
//! and a delay between tones (also in milliseconds)
@property uint16_t toneDelay;

-(instancetype)initWithEntry:(MUCEntry)theEntry;

@end


static NSArray<AGILMUCEntry*> *mucDecode(NSURL *theFile, NSError *__autoreleasing*outError) {
	NSMutableArray<AGILMUCEntry*> *toRetValues = [[NSMutableArray alloc] init];
	NSFileHandle *hand = [NSFileHandle fileHandleForReadingFromURL:theFile error:outError];
	if (hand == nil) {
		return nil;
	}
	uint64_t totalLen = 0;
	BOOL success = [hand seekToEndReturningOffset:&totalLen error:outError];
	if (!success) {
		return nil;
	}
	if (totalLen == 0) {
		if (outError) {
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:@{NSURLErrorKey: theFile}];
		}
		return nil;
	}
	success = [hand seekToOffset:0 error:outError];
	if (!success) {
		return nil;
	}
	while ([hand offsetInFile] < totalLen) {
		NSData *testDat = [hand readDataUpToLength:sizeof(MUCEntry) error:outError];
		MUCEntry entry;
		if (testDat.length != 6) {
			continue;
		}
		[testDat getBytes:&entry length:sizeof(entry)];
		[toRetValues addObject:[[AGILMUCEntry alloc] initWithEntry:entry]];
	}
	return toRetValues;
}

NSData *MUCToRiff(NSURL *theFile, NSError *__autoreleasing*outError) {
	NSArray<AGILMUCEntry*> *entries = mucDecode(theFile, outError);
	if (!entries) {
		return nil;
	}
	static const double sampleRate = 11025;
	AVAudioFormat *format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:sampleRate channels:1 interleaved:NO];

	NSTimeInterval estimated = 0;
	for (AGILMUCEntry* entry in entries) {
		estimated += entry.toneTime + entry.toneDelay;
	}
	
	AVAudioFrameCount numberOfSamples = ((estimated / 1000 * sampleRate));
	AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:numberOfSamples];
	if (!buffer) {
		if (outError) {
			*outError = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOMEM userInfo:nil];
		}
		return nil;
	}
	
	return nil;
}



@implementation AGILMUCEntry

-(instancetype)initWithEntry:(MUCEntry)theEntry
{
	if (self = [super init]) {
		self.frequency = theEntry.frequency;
		self.toneTime = theEntry.toneTime;
		self.toneDelay = theEntry.toneDelay;
	}
	return self;
}

@end
