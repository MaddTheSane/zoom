//
//  PCXDecoder.m
//  agil
//
//  Created by C.W. Betts on 1/6/23.
//

#import "PCXDecoder.h"
#import <AppKit/AppKit.h>

NSErrorDomain const PCXDecoderErrorDomain = @"com.github.MaddTheSane.AGT.PCXErrors";

typedef NS_ENUM(uint8_t, PCXVersion) {
  PCXVersionFixedEGA = 0,
  PCXVersionModifiableEGA = 2,
  PCXVersionNoPalette,
  PCXVersionWindows,
	PCXVersionLaterWindows
};

typedef NS_ENUM(uint8_t, PCXEncoding) {
  PCXEncodingNone = 0,
  PCXEncodingRLE = 1
};

typedef NS_ENUM(uint16_t, PCXPaletteInfo) {
  PCXPaletteInfoColorBW = 1,
  PCXPaletteInfoGrayscale = 2
};

/*! This procedure reads one encoded block from the image file and stores a
count and data byte.

 \return result:  0 = valid data stored, \c EOF = out of data in file
 \param pbyt where to place data
 \param pcnt where to place count
 \param fid image file handle
 */
static int encgetc(int *pbyt, int *pcnt, int fid);

static const uint8_t PCX_defaultPalette[48] = {
	0x00, 0x00, 0x00,    0x00, 0x00, 0x80,    0x00, 0x80, 0x00,
	0x00, 0x80, 0x80,    0x80, 0x00, 0x00,    0x80, 0x00, 0x80,
	0x80, 0x80, 0x00,    0x80, 0x80, 0x80,    0xc0, 0xc0, 0xc0,
	0x00, 0x00, 0xff,    0x00, 0xff, 0x00,    0x00, 0xff, 0xff,
	0xff, 0x00, 0x00,    0xff, 0x00, 0xff,    0xff, 0xff, 0x00,
	0xff, 0xff, 0xff
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
      *outErr = [NSError errorWithDomain: PCXDecoderErrorDomain code: PCXDecoderInvalidMagic userInfo: nil];
    }
    return NO;
  }
  if (header->version != PCXVersionFixedEGA && header->version != PCXVersionModifiableEGA && header->version != PCXVersionNoPalette && header->version != PCXVersionWindows && header->version != PCXVersionLaterWindows) {
    if (outErr) {
      *outErr = [NSError errorWithDomain: PCXDecoderErrorDomain code: PCXDecoderUnknownVersion userInfo: nil];
    }
    return NO;
  }
  if (header->encoding != PCXEncodingNone && header->encoding != PCXEncodingRLE) {
    if (outErr) {
      *outErr = [NSError errorWithDomain: PCXDecoderErrorDomain code: PCXDecoderBadEncoding userInfo: nil];
    }
    return NO;
  }
  
  if (header->paletteMode != PCXPaletteInfoColorBW && header->paletteMode != PCXPaletteInfoGrayscale) {
    if (outErr) {
      *outErr = [NSError errorWithDomain: PCXDecoderErrorDomain code: PCXDecoderBadEncoding userInfo: nil];
    }
    return NO;
  }


  
  return YES;
}

@implementation PCXDecoder {
  NSFileHandle *fileHandle;
  struct PCXHeader pcxHeader;
	NSBitmapImageRep *imageRep;
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
		  *outErr = [NSError errorWithDomain: PCXDecoderErrorDomain code: PCXDecoderUnexpectedEOF userInfo: @{NSURLErrorKey: url}];
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

- (BOOL)readEGAPCXWithFixedPalette:(BOOL)fixed error:(NSError**)outError
{
	uint8_t thePalette[48];
	if (fixed) {
		memcpy(thePalette, PCX_defaultPalette, sizeof(PCX_defaultPalette));
	} else {
		memcpy(thePalette, pcxHeader.egaPalette, sizeof(PCX_defaultPalette));
	}
	return NO;
}

- (BOOL)readTrueColorPCXWithError:(NSError**)outError
{
	return NO;
	unsigned char *planes[5] = {NULL};
	
	imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:planes pixelsWide:pcxHeader.yMax pixelsHigh:pcxHeader.xMax bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:YES colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
}

- (NSData *)TIFFRepresentation
{
	return [imageRep TIFFRepresentation];
}

@end

int encgetc(int *pbyt, int *pcnt, int fid)
{
	int i;
	uint8_t val;
	*pcnt = 1;        /* assume a "run" length of one */
	ssize_t readSize = read(fid, &val, sizeof(val));
	if (readSize <= 0) {
		return EOF;
	}
	i = val;
	if (0xC0 == (0xC0 & i)) {
		*pcnt = 0x3F & i;
		readSize = read(fid, &val, sizeof(val));
		if (readSize <= 0) {
			return EOF;
		}
		i = val;
	}
	*pbyt = i;
	return 0;
}
