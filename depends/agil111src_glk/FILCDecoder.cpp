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

#include "flic.h"

static CFDataRef CreateGIFFromFile(flic::FileInterface *file) CF_RETURNS_RETAINED;
static CFDataRef CreateGIFFromFileCrunch(flic::FileInterface *file) CF_RETURNS_RETAINED;
static CFDataRef createColorDataFromFrame(const flic::Frame& header) CF_RETURNS_RETAINED;
static CFDataRef createDataFromBuffer(const flic::Frame &frame, const flic::Header &header) CF_RETURNS_RETAINED;
static CGImageRef createImageFromData(CFDataRef dat, const flic::Frame &frame, const flic::Header &header) CF_RETURNS_RETAINED;
static CFArrayRef createImageAndInfoFromDataAndTime(CFDataRef src1, const flic::Frame &frame, const flic::Header &header, CFTimeInterval interval) CF_RETURNS_RETAINED;
static CGImageRef createImageFromBuffer(const flic::Frame &frame, const flic::Header &header) CF_RETURNS_RETAINED;

class CFDataFileInterface final : public flic::FileInterface {
public:
  
  CFDataFileInterface(CFDataRef data);
  ~CFDataFileInterface();
  /// Returns \c true if we can read/write bytes from/into the file
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
  CFDataRef fileData;
  size_t position;
};

CFDataFileInterface::CFDataFileInterface(CFDataRef data) : fileData((CFDataRef)CFRetain(data)), position(0)
{ }

CFDataFileInterface::~CFDataFileInterface()
{
  CFRelease(fileData);
}

bool CFDataFileInterface::ok() const {
  return position < CFDataGetLength(fileData);
}

void CFDataFileInterface::seek(size_t absPos)
{
  position = std::min<size_t>(absPos, CFDataGetLength(fileData));
}

uint8_t CFDataFileInterface::read8()
{
  uint8_t simpleBuffer;
  CFDataGetBytes(fileData, CFRangeMake(position, 1), &simpleBuffer);
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

static CFDataRef createColorDataFromFrame(const flic::Frame& header)
{
  CFMutableDataRef toRet = CFDataCreateMutable(kCFAllocatorDefault, flic::Colormap::SIZE * 3);
  for (int i = 0; i < flic::Colormap::SIZE; i++) {
    const flic::Color &fliColor = header.colormap[i];
    UInt8 bytes[] = {fliColor.r, fliColor.g, fliColor.b};
    CFDataAppendBytes(toRet, bytes, 3);
  }
  return toRet;
}

static CFDataRef createDataFromBuffer(const flic::Frame &frame, const flic::Header &header)
{
  CFMutableDataRef src1 = CFDataCreateMutable(kCFAllocatorDefault, header.width * header.height * 3);
  for (int i = 0; i < header.width * header.height; i++) {
    uint8_t colorIdx = frame.pixels[i];
    const flic::Color &fliColor = frame.colormap[colorIdx];
    UInt8 bytes[] = {fliColor.r, fliColor.g, fliColor.b};
    CFDataAppendBytes(src1, bytes, 3);
  }
  return src1;
}

static CGImageRef createImageFromData(CFDataRef src1, const flic::Frame &frame, const flic::Header &header)
{
  CGDataProviderRef src = CGDataProviderCreateWithCFData(src1);
  CGColorSpaceRef clrSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);

  CGImageRef toRet = CGImageCreate(header.width, header.height, 8, 24, header.width * 3, clrSpace, (CGBitmapInfo)kCGImageAlphaNone | kCGBitmapByteOrderDefault, src, NULL, false, kCGRenderingIntentDefault);
  CGColorSpaceRelease(clrSpace);
  CGDataProviderRelease(src);
  return toRet;
}

static CGImageRef createImageFromBuffer(const flic::Frame &frame, const flic::Header &header)
{
  CFDataRef src1 = createDataFromBuffer(frame, header);
  CGImageRef toRet = createImageFromData(src1, frame, header);
  CFRelease(src1);
  return toRet;
}

CFDataRef CreateGIFFromFLICData(CFDataRef fliDat, bool crunch)
{
  CFDataFileInterface file(fliDat);
  if (crunch) {
    return CreateGIFFromFileCrunch(&file);
  } else {
    return CreateGIFFromFile(&file);
  }
}

CFDataRef CreateGIFFromFLICPath(const char *fliDat, bool crunch)
{
  CFDataRef toRet;
  FILE *file1 = fopen(fliDat, "rb");
  flic::StdioFileInterface file(file1);
  if (crunch) {
    toRet = CreateGIFFromFileCrunch(&file);
  } else {
    toRet = CreateGIFFromFile(&file);
  }
  fclose(file1);
  return toRet;
}

CFDataRef CreateGIFFromFile(flic::FileInterface *file)
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
  CFMutableDataRef mutDat = CFDataCreateMutable(kCFAllocatorDefault, 0);
  CGImageDestinationRef dst = CGImageDestinationCreateWithData(mutDat, kUTTypeGIF, header.frames, NULL);
  CFTimeInterval delayTime = header.speed / 1000.0;
  CFNumberRef delayTimeCF = CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &delayTime);

  for (int i=0; i<header.frames; ++i) {
    if (!decoder.readFrame(frame)) {
      CFRelease(dst);
      CFRelease(mutDat);
      CFRelease(delayTimeCF);
      return NULL;
    }
    CFDictionaryRef imgDictionary = NULL;
    {
      CFDataRef colors = createColorDataFromFrame(frame);
      CFStringRef keys[] = {kCGImagePropertyGIFImageColorMap, kCGImagePropertyGIFUnclampedDelayTime};
      CFTypeRef values[] = {colors, delayTimeCF};
      
      CFDictionaryRef gifDictionary = ::CFDictionaryCreate(kCFAllocatorDefault, (const void **)keys, (const void **)values, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
      CFRelease(colors);
      
      imgDictionary = ::CFDictionaryCreate(kCFAllocatorDefault, (const void **)&kCGImagePropertyGIFDictionary, (const void **)&gifDictionary, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
      CFRelease(gifDictionary);
    }
    
    CGImageRef imageRef = createImageFromBuffer(frame, header);
    CGImageDestinationAddImage(dst, imageRef, imgDictionary);
    CFRelease(imgDictionary);
    CGImageRelease(imageRef);
  }
  
  CGImageDestinationFinalize(dst);
  CFRelease(dst);
  CFRelease(delayTimeCF);

  return mutDat;
}

CFArrayRef createImageAndInfoFromDataAndTime(CFDataRef src1, const flic::Frame &frame, const flic::Header &header, CFTimeInterval currentDelayTime)
{
  CFDictionaryRef imgDictionary = NULL;
  {
    CFDataRef colors = createColorDataFromFrame(frame);
    CFNumberRef delayTimeCF = CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &currentDelayTime);
    CFStringRef keys[] = {kCGImagePropertyGIFImageColorMap, kCGImagePropertyGIFUnclampedDelayTime};
    CFTypeRef values[] = {colors, delayTimeCF};
    
    CFDictionaryRef gifDictionary = ::CFDictionaryCreate(kCFAllocatorDefault, (const void **)keys, (const void **)values, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFRelease(colors);
    CFRelease(delayTimeCF);
    
    imgDictionary = ::CFDictionaryCreate(kCFAllocatorDefault, (const void **)&kCGImagePropertyGIFDictionary, (const void **)&gifDictionary, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFRelease(gifDictionary);
  }
  CGImageRef img = createImageFromData(src1, frame, header);
  CFTypeRef values[] = {img, imgDictionary};
  CFArrayRef imgVal = CFArrayCreate(kCFAllocatorDefault, (const void **)values, 2, &kCFTypeArrayCallBacks);
  CFRelease(imgDictionary);
  CGImageRelease(img);
  return imgVal;
}

CFDataRef CreateGIFFromFileCrunch(flic::FileInterface *file)
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
  CFMutableArrayRef imgArray = CFArrayCreateMutable(kCFAllocatorDefault, header.frames, &kCFTypeArrayCallBacks);
  const CFTimeInterval delayTime = header.speed / 1000.0;
  CFTimeInterval currentDelayTime = delayTime;
  CFDataRef lastImgData = NULL;
  
  // Error out if we have no frames (bad data?)
  if (header.frames <= 0) {
    CFRelease(imgArray);
    return NULL;
  }

  for (int i = 0; i < header.frames; i++) {
    if (!decoder.readFrame(frame)) {
      CFRelease(imgArray);
      if (lastImgData) {
        CFRelease(lastImgData);
      }
      return NULL;
    }
    
    CFDataRef imgData = createDataFromBuffer(frame, header);
    
    if (lastImgData) {
      if (CFEqual(imgData, lastImgData)) {
        currentDelayTime += delayTime;
        CFRelease(imgData);
        continue;
      } else {
        CFArrayRef imgVal = createImageAndInfoFromDataAndTime(lastImgData, frame, header, currentDelayTime);
        CFArrayAppendValue(imgArray, imgVal);
        CFRelease(imgVal);
        CFRelease(lastImgData);
        lastImgData = imgData;
        currentDelayTime = delayTime;
      }
    } else {
      lastImgData = imgData;
    }
  }
  //Final image
  {
    CFArrayRef imgVal = createImageAndInfoFromDataAndTime(lastImgData, frame, header, currentDelayTime);
    CFArrayAppendValue(imgArray, imgVal);
    CFRelease(imgVal);
    CFRelease(lastImgData);
    lastImgData = NULL;
  }
  
  const CFIndex count = CFArrayGetCount(imgArray);
  CFMutableDataRef mutDat = CFDataCreateMutable(kCFAllocatorDefault, 0);
  CGImageDestinationRef dst = CGImageDestinationCreateWithData(mutDat, kUTTypeGIF, count, NULL);
  for (CFIndex i = 0; i < count; i++) {
    CFArrayRef imgVal = (CFArrayRef)CFArrayGetValueAtIndex(imgArray, i);
    CGImageRef imageRef = (CGImageRef)CFArrayGetValueAtIndex(imgVal, 0);
    CFDictionaryRef imgDictionary = (CFDictionaryRef)CFArrayGetValueAtIndex(imgVal, 1);
    CGImageDestinationAddImage(dst, imageRef, imgDictionary);
  }
  
  CGImageDestinationFinalize(dst);
  CFRelease(dst);
  CFRelease(imgArray);

  return mutDat;
}
