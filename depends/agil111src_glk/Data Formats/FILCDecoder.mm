//
//  FILCDecoder.cpp
//  agil
//
//  Created by C.W. Betts on 1/6/23.
//

#include "FILCDecoder.h"
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>
#include <CoreServices/CoreServices.h>
#import <Foundation/Foundation.h>

#include "flic.h"

#pragma GCC visibility push(hidden)

static NSData *CreateGIFFromFile(flic::FileInterface *file);
static NSData *CreateGIFFromFileCrunch(flic::FileInterface *file);
static NSData *createColorDataFromFrame(const flic::Frame& header);
static NSData *createDataFromBuffer(const flic::Frame &frame, const flic::Header &header);
static CGImageRef createImageFromData(NSData *dat, const flic::Header &header) CF_RETURNS_RETAINED;
static NSArray *createImageAndInfoFromDataAndTime(NSData *src1, const flic::Frame &frame, const flic::Header &header, NSTimeInterval interval);
static CGImageRef createImageFromBuffer(const flic::Frame &frame, const flic::Header &header) CF_RETURNS_RETAINED;

class CFDataFileInterface final : public flic::FileInterface {
public:
	
	CFDataFileInterface(NSData* data);
	~CFDataFileInterface() = default;
	/// Returns `true` if we can read/write bytes from/into the file
	virtual bool ok() const;
	
	/// Current position in the file
	virtual size_t tell()
	{
		return position;
	}
	
	/// Jump to the given position in the file
	virtual void seek(size_t absPos);
	
	/// Returns the next byte in the file or 0 if ok() = false
	virtual uint8_t read8();
	
	/// Writes one byte in the file (or do nothing if ok() = false)
	virtual void write8(uint8_t value)
	{
		// We just read, so...
		//
		// do nothing!
	}
	
private:
	NSData *fileData;
	size_t position;
};

CFDataFileInterface::CFDataFileInterface(NSData *data) : fileData(data), position(0)
{ }

bool CFDataFileInterface::ok() const {
	return position < fileData.length;
}

void CFDataFileInterface::seek(size_t absPos) {
	position = std::min<size_t>(absPos, fileData.length);
}

uint8_t CFDataFileInterface::read8()
{
	if (position >= fileData.length) {
		return 0;
	}
	uint8_t simpleBuffer;
	[fileData getBytes:&simpleBuffer length:1];
	position += 1;
	return simpleBuffer;
}

#pragma mark -

//static CFArrayRef createColorsFromFrame(const flic::Frame& header)
//{
//  CFMutableArrayRef toRet = CFArrayCreateMutable(kCFAllocatorDefault, flic::Colormap::SIZE, &kCFTypeArrayCallBacks);
//  for (int i = 0; i < flic::Colormap::SIZE; i++) {
//    const flic::Color &fliColor = header.colormap[i];
//    CGColorRef theColor = CGColorCreateSRGB(fliColor.r / 255.0, fliColor.g / 255.0, fliColor.b / 255.0, 1);
//    CFArrayAppendValue(toRet, theColor);
//    CGColorRelease(theColor);
//  }
//  return toRet;
//}

static NSData *createColorDataFromFrame(const flic::Frame& header)
{
	NSMutableData *toRet = [[NSMutableData alloc] initWithCapacity: flic::Colormap::SIZE * 3];
	for (int i = 0; i < flic::Colormap::SIZE; i++) {
		const flic::Color &fliColor = header.colormap[i];
		UInt8 bytes[] = {fliColor.r, fliColor.g, fliColor.b};
		[toRet appendBytes:bytes length:3];
	}
	return toRet;
}

#pragma GCC visibility pop

static NSData *createDataFromBuffer(const flic::Frame &frame, const flic::Header &header)
{
	NSMutableData *src1 = [[NSMutableData alloc] initWithCapacity: header.width * header.height * 3];
	for (int i = 0; i < header.width * header.height; i++) {
		uint8_t colorIdx = frame.pixels[i];
		const flic::Color &fliColor = frame.colormap[colorIdx];
		UInt8 bytes[] = {fliColor.r, fliColor.g, fliColor.b};
		[src1 appendBytes:bytes length:3];
	}
	return src1;
}

static CGImageRef createImageFromData(NSData *src1, const flic::Header &header)
{
	CGDataProviderRef src = CGDataProviderCreateWithCFData((__bridge CFDataRef)src1);
	CGColorSpaceRef clrSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	
	CGImageRef toRet = CGImageCreate(header.width, header.height, 8, 24, header.width * 3, clrSpace, (CGBitmapInfo)kCGImageAlphaNone | kCGBitmapByteOrderDefault, src, NULL, false, kCGRenderingIntentDefault);
	CGColorSpaceRelease(clrSpace);
	CGDataProviderRelease(src);
	return toRet;
}

static CGImageRef createImageFromBuffer(const flic::Frame &frame, const flic::Header &header)
{
	NSData *src1 = createDataFromBuffer(frame, header);
	CGImageRef toRet = createImageFromData(src1, header);
	return toRet;
}

CFDataRef CreateGIFFromFLICData(CFDataRef fliDat, bool crunch)
{
	@autoreleasepool {
	CFDataFileInterface file((__bridge NSData*)fliDat);
	if (crunch) {
		return (CFDataRef)CFBridgingRetain(CreateGIFFromFileCrunch(&file));
	} else {
		return (CFDataRef)CFBridgingRetain(CreateGIFFromFile(&file));
	}
	}
}

CFDataRef CreateGIFFromFLICFileURL(CFURLRef fliDat, bool crunch)
{
	NSURL *fliNSURL = (__bridge NSURL*)fliDat;
	const char *path = fliNSURL.fileSystemRepresentation;
	if (!path) {
		return NULL;
	}
	return CreateGIFFromFLICPath(path, crunch);
}

CFDataRef CreateGIFFromFLICPath(const char *fliDat, bool crunch)
{
	@autoreleasepool {
	CFDataRef toRet;
	FILE *file1 = fopen(fliDat, "rb");
	flic::StdioFileInterface file(file1);
	if (crunch) {
		toRet = (CFDataRef)CFBridgingRetain(CreateGIFFromFileCrunch(&file));
	} else {
		toRet = (CFDataRef)CFBridgingRetain(CreateGIFFromFile(&file));
	}
	fclose(file1);
	return toRet;
	}
}

NSData *CreateGIFFromFile(flic::FileInterface *file)
{
	flic::Decoder decoder(file);
	flic::Header header;
	
	if (!decoder.readHeader(header)) {
		return NULL;
	}
	
	std::vector<uint8_t> buffer(header.width * header.height);
	flic::Frame frame;
	frame.pixels = &buffer[0];
	frame.rowstride = header.width;
	NSMutableData *mutDat = [NSMutableData data];
	CGImageDestinationRef dst = CGImageDestinationCreateWithData((CFMutableDataRef)mutDat, kUTTypeGIF, header.frames, NULL);
	const NSTimeInterval delayTime = header.speed / 1000.0;
	
	for (int i=0; i<header.frames; ++i) {
		if (!decoder.readFrame(frame)) {
			CFRelease(dst);
			return NULL;
		}
		NSData *colors = createColorDataFromFrame(frame);
		
		NSDictionary *gifDictionary = @{(NSString*)kCGImagePropertyGIFImageColorMap: colors,
										(NSString*)kCGImagePropertyGIFUnclampedDelayTime: @(delayTime)};
		
		NSDictionary *imgDictionary = @{(NSString*)kCGImagePropertyGIFDictionary: gifDictionary};
		
		CGImageRef imageRef = createImageFromBuffer(frame, header);
		CGImageDestinationAddImage(dst, imageRef, (CFDictionaryRef)imgDictionary);
		CGImageRelease(imageRef);
	}
	
	CGImageDestinationFinalize(dst);
	CFRelease(dst);
	
	return mutDat;
}

NSArray *createImageAndInfoFromDataAndTime(NSData *src1, const flic::Frame &frame, const flic::Header &header, NSTimeInterval currentDelayTime)
{
	NSData *colors = createColorDataFromFrame(frame);
	NSDictionary *gifDictionary = @{(NSString*)kCGImagePropertyGIFImageColorMap: colors,
									(NSString*)kCGImagePropertyGIFUnclampedDelayTime: @(currentDelayTime)};
	
	NSDictionary *imgDictionary = @{(NSString*)kCGImagePropertyGIFDictionary: gifDictionary};
	CGImageRef img = createImageFromData(src1, header);
	NSArray *imgVal = @[CFBridgingRelease(img), imgDictionary];
	return imgVal;
}

NSData *CreateGIFFromFileCrunch(flic::FileInterface *file)
{
	flic::Decoder decoder(file);
	flic::Header header;
	
	if (!decoder.readHeader(header)) {
		return nil;
	}
	
	std::vector<uint8_t> buffer(header.width * header.height);
	flic::Frame frame;
	frame.pixels = &buffer[0];
	frame.rowstride = header.width;
	NSMutableArray *imgArray = [[NSMutableArray alloc] initWithCapacity:header.frames];
	const NSTimeInterval delayTime = header.speed / 1000.0;
	NSTimeInterval currentDelayTime = delayTime;
	NSData *lastImgData = NULL;
	
	// Error out if we have no frames (bad data?)
	if (header.frames <= 0) {
		return nil;
	}
	
	for (int i = 0; i < header.frames; i++) {
		if (!decoder.readFrame(frame)) {
			return nil;
		}
		
		NSData *imgData = createDataFromBuffer(frame, header);
		
		if (lastImgData) {
			if ([imgData isEqual:lastImgData]) {
				currentDelayTime += delayTime;
				continue;
			} else {
				NSArray *imgVal = createImageAndInfoFromDataAndTime(lastImgData, frame, header, currentDelayTime);
				[imgArray addObject:imgVal];
				lastImgData = imgData;
				currentDelayTime = delayTime;
			}
		} else {
			lastImgData = imgData;
		}
	}
	//Final image
	{
		NSArray *imgVal = createImageAndInfoFromDataAndTime(lastImgData, frame, header, currentDelayTime);
		[imgArray addObject: imgVal];
		lastImgData = nil;
	}
	
	NSMutableData *mutDat = [NSMutableData data];
	CGImageDestinationRef dst = CGImageDestinationCreateWithData((CFMutableDataRef)mutDat, kUTTypeGIF, imgArray.count, NULL);
	for (NSArray *imgVal in imgArray) {
		CGImageRef imageRef = (__bridge CGImageRef)[imgVal objectAtIndex:0];
		NSDictionary *imgDictionary = imgVal[1];
		CGImageDestinationAddImage(dst, imageRef, (CFDictionaryRef)imgDictionary);
	}
	
	CGImageDestinationFinalize(dst);
	CFRelease(dst);
	
	return mutDat;
}
