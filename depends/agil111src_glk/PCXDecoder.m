//
//  PCXDecoder.m
//  agil
//
//  Created by C.W. Betts on 1/6/23.
//

#import "PCXDecoder.h"

NSErrorDomain const PCXDecoderErrorDomain = @"com.github.MaddTheSane.AGT.PCXErrors";

typedef NS_ENUM(uint8_t, PCXVersion) {
  PCXVersionFixedEGA = 0,
  PCXVersionModifiableEGA = 2,
  PCXVersionNoPalette,
  PCXVersionWindows,
  PCXVersionTrueColor
};

typedef NS_ENUM(uint8_t, PCXEncoding) {
  PCXEncodingNone = 0,
  PCXEncodingRLE = 1
};

typedef NS_ENUM(uint16_t, PCXPaletteInfo) {
  PCXPaletteInfoColorBW = 1,
  PCXPaletteInfoGrayscale = 2
};

struct PCXHeader {
  uint8_t magic; // = 0x0A
  PCXVersion version;
  PCXEncoding encoding;
  uint8_t bitsPerPlane;
  uint16_t xMin;
  uint16_t yMin;
  uint16_t xMax;
  uint16_t yMax;
  uint16_t horizDPI;
  uint16_t vertDPI;
  uint8_t egaPalette[48];
  char reserved;
  uint8_t colorPlanes;
  uint16_t colorPlaneBytes;
  PCXPaletteInfo paletteMode;
  uint16_t horizRes;
  uint16_t vertRes;
  char reserved2[54];
};

static_assert(sizeof(struct PCXHeader) == 128, "Check alignment!");

static BOOL verifyHeader(const struct PCXHeader *header, NSError **outErr)
{
  if (header->magic != 0x0A) {
    if (outErr) {
      *outErr = [NSError errorWithDomain:PCXDecoderErrorDomain code:PCXDecoderInvalidMagic userInfo:nil];
    }
    return NO;
  }
  if (header->version != PCXVersionFixedEGA && header->version != PCXVersionModifiableEGA && header->version != PCXVersionNoPalette && header->version != PCXVersionWindows && header->version != PCXVersionTrueColor) {
    if (outErr) {
      *outErr = [NSError errorWithDomain:PCXDecoderErrorDomain code:PCXDecoderUnknownVersion userInfo:nil];
    }
    return NO;
  }
  if (header->encoding != PCXEncodingNone && header->encoding != PCXEncodingRLE) {
    if (outErr) {
      *outErr = [NSError errorWithDomain:PCXDecoderErrorDomain code:PCXDecoderBadEncoding userInfo:nil];
    }
    return NO;
  }
  
  if (header->paletteMode != PCXPaletteInfoColorBW && header->paletteMode != PCXPaletteInfoGrayscale) {
    if (outErr) {
      *outErr = [NSError errorWithDomain:PCXDecoderErrorDomain code:PCXDecoderBadEncoding userInfo:nil];
    }
    return NO;
  }


  
  return YES;
}

@implementation PCXDecoder {
  NSFileHandle *fileHandle;
  struct PCXHeader pcxHeader;
}

- (instancetype)initWithFileAtURL:(NSURL*)url error:(NSError**)outErr
{
  if (self = [super init]) {
    fileHandle = [NSFileHandle fileHandleForReadingFromURL:url error:outErr];
    if (!fileHandle) {
      return nil;
    }
    NSData *hand = [fileHandle readDataUpToLength:sizeof(struct PCXHeader) error:outErr];
    if (!hand) {
      return nil;
    }
    if (hand.length != 128) {
      if (outErr) {
        *outErr = [NSError errorWithDomain: PCXDecoderErrorDomain code: PCXDecoderUnexpectedEOF userInfo: nil];
      }
      return nil;
    }
    // TODO: byte-swap? This assumes a Little Endian architecture.
    [hand getBytes:&pcxHeader length:sizeof(struct PCXHeader)];
    
    if (!verifyHeader(&pcxHeader, outErr)) {
      return nil;
    }
    
  }
  return self;
}

@end
