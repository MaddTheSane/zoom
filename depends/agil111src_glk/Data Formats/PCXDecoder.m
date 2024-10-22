//
//  PCXDecoder.m
//  agil
//
//  Created by C.W. Betts on 1/6/23.
//
// contains code scrounged around the internet, including from UberPaint.
//

#import "PCXDecoder.h"
#import <AppKit/AppKit.h>

NSErrorDomain const PCXDecoderErrorDomain = @"com.github.MaddTheSane.AGT.PCXErrors";

#define PCXVGAPaletteMagic 12

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
	PCXPaletteInfoInvalid = 0,
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
	
	// Some PCX files don't honor this...
//	if (header->paletteMode != PCXPaletteInfoColorBW && header->paletteMode != PCXPaletteInfoGrayscale) {
//		if (outErr) {
//			*outErr = [NSError errorWithDomain: PCXDecoderErrorDomain code: PCXDecoderBadEncoding userInfo: nil];
//		}
//		return NO;
//	}
	
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
		
		// Handle 24-bit images
		if (pcxHeader.version == PCXVersionLaterWindows && pcxHeader.colorPlanes == 3) {
			if (![self readTrueColorPCXWithError:outErr]) {
				return nil;
			}
		} else if (pcxHeader.colorPlanes == 1 && pcxHeader.bitsPerPlane == 8) {
			if (![self readVGAPCXWithError:outErr]) {
				return nil;
			}
		} else {
			if (outErr) {
				*outErr = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:@{NSURLErrorKey: url, NSLocalizedFailureReasonErrorKey: @"Unsupported PCX format."}];
			}
			return nil;
		}
		[fileHandle closeFile];
		fileHandle = nil;
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

- (NSData*)readRawDataReturningXFull:(int*)xFull yFull:(int*)yFull
{
	*yFull = 1 + pcxHeader.yMax - pcxHeader.yMin;
	*xFull = 1 + pcxHeader.xMax - pcxHeader.xMin;
	const size_t planeLength = pcxHeader.colorPlaneBytes * (*xFull);
	NSMutableData *data = [[NSMutableData alloc] initWithLength:pcxHeader.colorPlanes * planeLength];
	{
		[fileHandle seekToFileOffset:128];
		int ourFd = fileHandle.fileDescriptor;
		// Read data
		unsigned char *bpos = data.mutableBytes;
		int chr, cnt;
		const size_t bufrSize = pcxHeader.colorPlanes * planeLength;
		for (size_t l = 0; l < bufrSize; ) {  /* increment by cnt below */
			if (EOF == encgetc(&chr, &cnt, ourFd)) {
				break;
			}
			
			for (int i = 0; i < cnt; i++) {
				*bpos++ = chr;
			}
			
			l += cnt;
		}
	}

	return [data copy];
}

- (BOOL)readVGAPCXWithError:(NSError**)outError
{
	/* first seek to the end of the file -769 */
	unsigned long long offset = 0;
	if (![fileHandle seekToEndReturningOffset:&offset error:outError]) {
		return NO;
	}
	if (![fileHandle seekToOffset:offset-769 error:outError]) {
		return NO;
	}
	NSData *data = [fileHandle readDataUpToLength:1 error:outError];
	if (!data) {
		return NO;
	}
	if (data.length != 1) {
		if (outError) {
			*outError = [NSError errorWithDomain:PCXDecoderErrorDomain code:PCXDecoderUnexpectedEOF userInfo:nil];
		}
		return NO;
	}
	int checkbyte = *((uint8_t*)data.bytes);
	if (checkbyte != PCXVGAPaletteMagic) {
		if (outError) {
			*outError = [NSError errorWithDomain:PCXDecoderErrorDomain code:PCXDecoderNoVGAPalette userInfo:nil];
		}
		return NO;
	}
	data = [fileHandle readDataUpToLength:768 error:outError];
	if (!data) {
		return NO;
	}
	if (data.length != 768) {
		if (outError) {
			*outError = [NSError errorWithDomain:PCXDecoderErrorDomain code:PCXDecoderUnexpectedEOF userInfo:nil];
		}
		return NO;
	}
	int yFull, xFull;
	NSData *rawPCX = [self readRawDataReturningXFull:&xFull yFull:&yFull];
	const unsigned char *bufr = rawPCX.bytes;
	{
		const unsigned char *palette = data.bytes;
		unsigned char *imageDat = malloc(3 * yFull * xFull);
		int pcx_pos, image_pos;
		pcx_pos = image_pos = 0;
		for (int y = 0; y < yFull; y++) {
			for (int x = 0; x < pcxHeader.colorPlaneBytes; x++) {
				/* the width might be different than 'bytesPerLine */
				if (x < xFull) {
					imageDat[image_pos * 3 + 0] = palette[bufr[pcx_pos] * 3 + 0];
					imageDat[image_pos * 3 + 1] = palette[bufr[pcx_pos] * 3 + 1];
					imageDat[image_pos * 3 + 2] = palette[bufr[pcx_pos] * 3 + 2];
					image_pos++;
				}
				pcx_pos++;
			}
		}
		imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&imageDat pixelsWide:xFull pixelsHigh:yFull bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:xFull*3 bitsPerPixel:0];
		free(imageDat);
	}
	
	return YES;
}

- (BOOL)readTrueColorPCXWithError:(NSError**)outError
{
	unsigned char *planes[5] = {NULL};
	int yFull, xFull;
	NSData *rawPCX = [self readRawDataReturningXFull:&xFull yFull:&yFull];
	const unsigned char *bufr = rawPCX.bytes;
	const size_t planeLength = pcxHeader.colorPlaneBytes * xFull;
	planes[0] = malloc(planeLength);
	planes[1] = malloc(planeLength);
	planes[2] = malloc(planeLength);

	/* set up data */
	int set_aside, image_pos;
	int pcx_pos = image_pos = 0;
	for (int y = 0; y < yFull; y++) {
		set_aside = image_pos; /* since they're muxed weird
								* TODO: ...but is it muxed weird to our benefit?
								* .. turns out no :( */
		for (int p = 0; p < pcxHeader.colorPlanes ; p++) {
			image_pos = set_aside;
			for (int x = 0; x < pcxHeader.colorPlaneBytes; x++) {
				planes[p][image_pos] = bufr[pcx_pos];
				
				image_pos++;
				pcx_pos++;
			}
		}
	}
	
	imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:planes pixelsWide:xFull pixelsHigh:yFull bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:YES colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:pcxHeader.colorPlaneBytes bitsPerPixel:0];
	// free memory
	free(planes[0]); planes[0] = NULL;
	free(planes[1]); planes[1] = NULL;
	free(planes[2]); planes[2] = NULL;
	
	return YES;
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
