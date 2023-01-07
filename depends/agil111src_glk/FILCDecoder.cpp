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

static CGImageRef createImageFromBuffer(const flic::Frame &frame, const flic::Header &header)
{
  CFMutableDataRef src1 = CFDataCreateMutable(kCFAllocatorDefault, 0);
  for (int i = 0; i < header.width * header.height; i++) {
    uint8_t colorIdx = frame.pixels[i];
    const flic::Color &fliColor = frame.colormap[colorIdx];
    UInt8 bytes[] = {fliColor.r, fliColor.g, fliColor.b};
    CFDataAppendBytes(src1, bytes, 3);
  }
  CGDataProviderRef src = CGDataProviderCreateWithCFData(src1);
  CFRelease(src1);
  CGColorSpaceRef clrSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);

  CGImageRef toRet = CGImageCreate(header.width, header.height, 8, 24, header.width * 3, clrSpace, kCGImageAlphaNone | kCGBitmapByteOrderDefault, src, NULL, false, kCGRenderingIntentDefault);
  CGColorSpaceRelease(clrSpace);
  CGDataProviderRelease(src);
  return toRet;
}

CFDataRef CreateGIFFromFLICData(CFDataRef fliDat)
{
  CFDataFileInterface file(fliDat);
  flic::Decoder decoder(&file);
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
    CFDataRef colors = createColorDataFromFrame(frame);
    CFDictionaryRef imgDictionary = NULL;
    {
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
