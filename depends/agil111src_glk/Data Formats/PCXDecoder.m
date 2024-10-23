//
//  PCXDecoder.m
//  agil
//
//  Created by C.W. Betts on 1/6/23.
//
// contains code scrounged around the internet, including from UberPaint and NetPBM.
//

#import "PCXDecoder.h"
#import <AppKit/AppKit.h>

NSErrorDomain const PCXDecoderErrorDomain = @"com.github.MaddTheSane.AGT.PCXErrors";

#define PCXVGAPaletteMagic 12

//! PCX Version
typedef NS_ENUM(uint8_t, PCXVersion) {
	//! PC Paintbrush 2.5
	PCXVersionFixedEGA = 0,
	//! PC Paintbrush 2.8 w/palette
	PCXVersionModifiableEGA = 2,
	//! PC Paintbrush 2.8 w/out palette
	PCXVersionNoPalette,
	//! PC Paintbrush for Windows
	PCXVersionWindows,
	//! PC Paintbrush 3.0, IV, IV Plus,
	//! and Publishers Paintbrush
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

typedef struct PCXHeader {
	//! Zsoft ID byte
	uint8_t magic; // = 0x0A
	//! Version, see \c PCXVersion for values.
	PCXVersion version;
	//! Encoding (PCX run-length encoding)
	PCXEncoding encoding;
	//! Bits/pixel (each plane)
	uint8_t bitsPerPlane;
	//! Image dimension Xmin
	uint16_t xMin;
	//! Image dimension Ymin
	uint16_t yMin;
	//! Image dimension Xmax
	uint16_t xMax;
	//! Image dimensions Ymax
	uint16_t yMax;
	//! Horizontal Res.
	uint16_t horizDPI;
	//! Vertical Res.
	uint16_t vertDPI;
	//! Header palette
	uint8_t egaPalette[48];
	//! unused, for future use?
	char reserved;
	//! number of planes
	uint8_t colorPlanes;
	//! bytes/line (memory needed for one plane of each horizontal line)
	uint16_t colorPlaneBytes;
	//! Header interpretation
	PCXPaletteInfo paletteMode;
	//! Video screen size (Horizontal)
	uint16_t horizRes;
	//! Video screen size (Vertical)
	uint16_t vertRes;
	//! unused, for future use?
	char reserved2[54];
} PCXHeader;

static_assert(sizeof(PCXHeader) == 128, "Check alignment!");

@implementation PCXDecoder {
	NSFileHandle *fileHandle;
	NSURL *fileURL;
	PCXHeader pcxHeader;
	NSBitmapImageRep *imageRep;
}

+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[NSError setUserInfoValueProviderForDomain:PCXDecoderErrorDomain provider:^id _Nullable(NSError * _Nonnull err, NSErrorUserInfoKey  _Nonnull userInfoKey) {
			switch ((PCXDecoderErrors)err.code) {
				case PCXDecoderInvalidMagic:
					if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return @"File is not PCX, magic number invalid.";
					}
					break;
					
				case PCXDecoderUnknownVersion:
					if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return @"Unknown PCX version number.";
					}
					break;
					
				case PCXDecoderBadEncoding:
					if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return @"Unknown PCX version encoding.";
					}
					break;
					
				case PCXDecoderUnknownPalette:
					if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return @"Unknown PCX palette value.";
					}
					break;
					
				case PCXDecoderUnexpectedEOF:
					if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return @"Unexpected end of file, possibly truncaded?";
					}
					break;
					
				case PCXDecoderNoVGAPalette:
					if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return @"The VGA palette was not found.";
					}
					break;
			}
			return nil;
		}];
	});
}

- (BOOL)verifyHeaderWithError:(NSError **)outErr
{
	if (pcxHeader.magic != 0x0A) {
		if (outErr) {
			*outErr = [NSError errorWithDomain: PCXDecoderErrorDomain code: PCXDecoderInvalidMagic userInfo: @{NSURLErrorKey: fileURL}];
		}
		return NO;
	}
	if (pcxHeader.version != PCXVersionFixedEGA && pcxHeader.version != PCXVersionModifiableEGA && pcxHeader.version != PCXVersionNoPalette && pcxHeader.version != PCXVersionWindows && pcxHeader.version != PCXVersionLaterWindows) {
		if (outErr) {
			*outErr = [NSError errorWithDomain: PCXDecoderErrorDomain code: PCXDecoderUnknownVersion userInfo: @{NSURLErrorKey: fileURL}];
		}
		return NO;
	}
	if (pcxHeader.encoding != PCXEncodingNone && pcxHeader.encoding != PCXEncodingRLE) {
		if (outErr) {
			*outErr = [NSError errorWithDomain: PCXDecoderErrorDomain code: PCXDecoderBadEncoding userInfo: @{NSURLErrorKey: fileURL}];
		}
		return NO;
	}
	
	// Some PCX files don't honor this...
//	if (pcxHeader.paletteMode != PCXPaletteInfoColorBW && pcxHeader.paletteMode != PCXPaletteInfoGrayscale) {
//		if (outErr) {
//			*outErr = [NSError errorWithDomain: PCXDecoderErrorDomain code: PCXDecoderBadEncoding userInfo: @{NSURLErrorKey: fileURL}];
//		}
//		return NO;
//	}
	
	return YES;
}

- (instancetype)initWithFileAtURL:(NSURL*)url error:(NSError**)outErr
{
	if (self = [super init]) {
		fileURL = url;
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
		
		if (![self verifyHeaderWithError:outErr]) {
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
		} else if (pcxHeader.colorPlanes == 4 && pcxHeader.bitsPerPlane == 1 && pcxHeader.version != PCXVersionNoPalette) {
			if (![self readEGAPCXWithFixedPalette:NO error:outErr]) {
				return nil;
			}
		} else if (pcxHeader.colorPlanes == 4 && pcxHeader.bitsPerPlane == 1 && pcxHeader.version == PCXVersionNoPalette) {
			if (![self readEGAPCXWithFixedPalette:YES error:outErr]) {
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

//! Convert packed pixel format in bitplanes[] into 1 pixel per byte
//! in pixels[].
static void
pcxUnpackPixels(unsigned char * const pixels,
				const unsigned char * const bitplanes,
				unsigned int    const bytesperline,
				unsigned int    const planes,
				unsigned int    const bitsperpixel)
{
	unsigned int i;
	
	if (planes != 1) {
//		pm_error("can't handle packed pixels with more than 1 plane" );
	}
	
	for (i = 0; i < bytesperline; ++i) {
		unsigned int const bits = bitplanes[i];
		
		switch (bitsperpixel) {
			case 4:
				pixels[2*i + 0] = (bits >> 4) & 0x0f;
				pixels[2*i + 1] = (bits     ) & 0x0f;
				break;
			case 2:
				pixels[i*4 + 0] = (bits >> 6) & 0x03;
				pixels[i*4 + 1] = (bits >> 4) & 0x03;
				pixels[i*4 + 2] = (bits >> 2) & 0x03;
				pixels[i*4 + 3] = (bits     ) & 0x03;
				break;
			case 1:
				pixels[i*8 + 0]  = ((bits & 0x80) != 0);
				pixels[i*8 + 1]  = ((bits & 0x40) != 0);
				pixels[i*8 + 2]  = ((bits & 0x20) != 0);
				pixels[i*8 + 3]  = ((bits & 0x10) != 0);
				pixels[i*8 + 4]  = ((bits & 0x08) != 0);
				pixels[i*8 + 5]  = ((bits & 0x04) != 0);
				pixels[i*8 + 6]  = ((bits & 0x02) != 0);
				pixels[i*8 + 7]  = ((bits & 0x01) != 0);
				break;
			default:
//				pm_error("pcxUnpackPixels - can't handle %u bits per pixel",
//						 bitsperpixel);
				break;
		}
	}
}

//! Convert multi-plane format into 1 pixel per byte.
static void
pcxPlanesToPixels(unsigned char * const pixels,
				  const unsigned char * const bitPlanes,
				  unsigned int    const bytesPerLine,
				  unsigned int    const planes,
				  unsigned int    const bitsPerPixel)
{
	unsigned int const pixelCt = bytesPerLine * 8;
	
	unsigned int bitPlanesIdx;
	/* Index into 'bitPlanes' of next byte to unpack */
	
	unsigned int  i;
	
	if (planes > 4) {
//		pm_error("can't handle more than 4 planes");
	}
	if (bitsPerPixel != 1) {
//		pm_error("can't handle more than 1 bit per pixel");
	}
	
	/* Clear the pixel buffer - initial value */
	for (i = 0; i < pixelCt; ++i) {
		pixels[i] = 0;
	}
	
	bitPlanesIdx = 0;  /* initial value */
	
	for (i = 0; i < planes; ++i) {
		unsigned int const pixbit = (1 << i);
		
		unsigned int pixelIdx;
		/* Index into 'pixels' of next pixel to output */
		
		unsigned int j;
		
		for (j = 0, pixelIdx = 0; j < bytesPerLine; ++j) {
			unsigned int const bits = bitPlanes[bitPlanesIdx++];
			
			unsigned int mask;
			
			for (mask = 0x80; mask != 0; mask >>= 1) {
				if (bits & mask) {
					pixels[pixelIdx] |= pixbit;
				}
				++pixelIdx;
			}
		}
	}
}

- (BOOL)readEGAPCXWithFixedPalette:(BOOL)fixed error:(NSError**)outError
{
	uint8_t thePalette[48];
	if (fixed) {
		memcpy(thePalette, PCX_defaultPalette, sizeof(PCX_defaultPalette));
	} else {
		memcpy(thePalette, pcxHeader.egaPalette, sizeof(PCX_defaultPalette));
	}
	int xFull, yFull;
	NSData *dat = [self readRawDataReturningXFull:&xFull yFull:&yFull];
	uint8_t *bufr = malloc(xFull * yFull);
	if (pcxHeader.colorPlanes == 1) {
		for (int i = 0; i < yFull; i++) {
			pcxUnpackPixels(&bufr[xFull * i], dat.bytes + pcxHeader.colorPlanes * pcxHeader.colorPlaneBytes * i, pcxHeader.colorPlaneBytes, pcxHeader.colorPlanes, pcxHeader.bitsPerPlane);
		}
	} else {
		for (int i = 0; i < yFull; i++) {
			pcxPlanesToPixels(&bufr[xFull * i], &dat.bytes[pcxHeader.colorPlanes * pcxHeader.colorPlaneBytes * i], pcxHeader.colorPlaneBytes, pcxHeader.colorPlanes, pcxHeader.bitsPerPlane);
		}
	}
	
	{
		NSMutableData *imageNSDat = [[NSMutableData alloc] initWithLength:3 * yFull * xFull];
		unsigned char *imageDat = imageNSDat.mutableBytes;
		int pcx_pos, image_pos;
		pcx_pos = image_pos = 0;
		for (int y = 0; y < yFull; y++) {
			for (int x = 0; x < xFull; x++) {
				imageDat[image_pos * 3 + 0] = thePalette[bufr[pcx_pos] * 3 + 0];
				imageDat[image_pos * 3 + 1] = thePalette[bufr[pcx_pos] * 3 + 1];
				imageDat[image_pos * 3 + 2] = thePalette[bufr[pcx_pos] * 3 + 2];
				image_pos++;
				pcx_pos++;
			}
		}
		dat = nil;
		free(bufr);
		imageDat = NULL;
		CGDataProviderRef imgProvider = CGDataProviderCreateWithCFData((__bridge CFDataRef)imageNSDat);
		imageNSDat = nil;
		CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
		CGImageRef img = CGImageCreate(xFull, yFull, 8, 24, xFull*3, colorSpace, kCGBitmapByteOrderDefault | kCGImageAlphaNone, imgProvider, NULL, false, kCGRenderingIntentDefault);
		CGDataProviderRelease(imgProvider);
		CGColorSpaceRelease(colorSpace);
		imageRep = [[NSBitmapImageRep alloc] initWithCGImage:img];
		CGImageRelease(img);
	}
	
	return YES;
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
			*outError = [NSError errorWithDomain:PCXDecoderErrorDomain code:PCXDecoderNoVGAPalette userInfo:@{NSURLErrorKey: fileURL}];
		}
		return NO;
	}
	data = [fileHandle readDataUpToLength:768 error:outError];
	if (!data) {
		return NO;
	}
	if (data.length != 768) {
		if (outError) {
			*outError = [NSError errorWithDomain:PCXDecoderErrorDomain code:PCXDecoderUnexpectedEOF userInfo:@{NSURLErrorKey: fileURL}];
		}
		return NO;
	}
	int yFull, xFull;
	NSData *rawPCX = [self readRawDataReturningXFull:&xFull yFull:&yFull];
	const unsigned char *bufr = rawPCX.bytes;
	{
		const unsigned char *palette = data.bytes;
		NSMutableData *imageNSDat = [[NSMutableData alloc] initWithLength:3 * yFull * xFull];
		unsigned char *imageDat = imageNSDat.mutableBytes;
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
		imageDat = NULL;
		bufr = NULL;
		rawPCX = nil;
		CGDataProviderRef imgProvider = CGDataProviderCreateWithCFData((__bridge CFDataRef)imageNSDat);
		imageNSDat = nil;
		CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
		CGImageRef img = CGImageCreate(xFull, yFull, 8, 24, xFull*3, colorSpace, kCGBitmapByteOrderDefault | kCGImageAlphaNone, imgProvider, NULL, false, kCGRenderingIntentDefault);
		CGDataProviderRelease(imgProvider);
		CGColorSpaceRelease(colorSpace);
		imageRep = [[NSBitmapImageRep alloc] initWithCGImage:img];
		CGImageRelease(img);
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
								* ...but is it muxed weird to our benefit?
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
