//
//  MUCConverter.m
//  agil
//
//  Created by C.W. Betts on 10/15/24.
//

#import "MUCConverter.h"
#import <AVFAudio/AVFAudio.h>
#include <AudioToolbox/AudioToolbox.h>


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

static NSURL *tempAIFFURL(void)
{
	const char template[] = "/tmp/myfileXXXXXX.aiff";
	char fname[PATH_MAX];
	strcpy(fname, template);		/* Copy template */
	int fd = mkstemp(fname);		/* Create and open temp file */
	close(fd);						/* We only need the name
									 * This might not be secure, but it'll work for now */
	
	return [NSURL fileURLWithFileSystemRepresentation:fname isDirectory:NO relativeToURL:nil];
}

NSData *MUCToRiff(NSURL *theFile, NSError *__autoreleasing*outError) {
	// Get file path for temporary file first!
	NSURL *theURL = tempAIFFURL();
	
	//Part 1: audio generation
	{
	NSArray<AGILMUCEntry*> *entries = mucDecode(theFile, outError);
	if (!entries) {
		return nil;
	}
	static const double sampleRate = 8000;
	static const float amplitude = 0.5;
	AVAudioFormat *format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:sampleRate channels:1 interleaved:NO];

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
		float *const  *channelsData = buffer.floatChannelData;
		float *theChannelData = *channelsData;
		
		NSInteger currentSample = 0;
		for (AGILMUCEntry *entry in entries) {
			float angularFrequency = entry.frequency * 2 * M_PI;
			NSInteger endSample = currentSample + ((int)(entry.toneTime) * sampleRate / 1000);
			// Generate and store the sequential samples representing the sine wave of the tone
			for (NSInteger i = currentSample; i < endSample; currentSample++)  {
				float waveComponent = sinf(i * angularFrequency / sampleRate);
				theChannelData[i] = waveComponent * amplitude;
			}
			currentSample += (((int)(entry.toneTime) + entry.toneDelay) * (int)(sampleRate)) / 1000;
		}
		
		// It doesn't look like AVFAudio has a way to create an audio format in memory:
		// it has to be saved to a file first.
		AVAudioFile *outFile = [[AVAudioFile alloc]
								initForWriting:theURL
								settings:@{AVAudioFileTypeKey: @(kAudioFileAIFCType),
										   AVLinearPCMBitDepthKey: @16,
										   AVLinearPCMIsFloatKey: @NO,
										   AVFormatIDKey: @(kAudioFormatLinearPCM),
										   AVSampleRateKey: @8000,
										   AVNumberOfChannelsKey: @1}
								error:outError];
		if (!outFile) {
			return nil;
		}
		if (![outFile writeFromBuffer:buffer error:outError]) {
			return nil;
		}
		// Close the file.
		if (@available(macOS 15.0, *)) {
			[outFile close];
		}
		// Deallocating outFile should close it on earlier versions of macOS.
		outFile = nil;
	}
	
	// Part 2: read the created file
	NSData *aiffData = [[NSData alloc] initWithContentsOfURL:theURL options:0 error:outError];
	if (!aiffData) {
		[[NSFileManager defaultManager] removeItemAtURL:theURL error:NULL];
		return nil;
	}
	[[NSFileManager defaultManager] removeItemAtURL:theURL error:NULL];
	return aiffData;
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
