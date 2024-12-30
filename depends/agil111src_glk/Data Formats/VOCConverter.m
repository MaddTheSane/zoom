//
//  VOCConverter.c
//  agil
//
//  Created by C.W. Betts on 1/12/23.
//

#include "VOCConverter.h"


const NSErrorDomain VOCConverterErrorDomain = @"com.github.MaddTheSane.AGT.VOCErrors";
static const unsigned char ff_voc_magic[20] = "Creative Voice File\x1A";

// More Info: https://moddingwiki.shikadi.net/wiki/VOC_Format

typedef NS_ENUM(uint8_t, VOCBlockType) {
	kVOCTerminator = 0,
	kVOCSoundData = 1,
	/// This block uses the same codec as last set by block type 1.
	kVOCSoundDataContinuation = 2,
	kVOCSilence = 3,
	kVOCMarker = 4,
	kVOCText = 5,
	kVOCRepeatStart = 6,
	kVOCRepeatEnd = 7,
	kVOCExtendedInfo = 8,
	kVOCSoundDataNew = 9
};

typedef NS_ENUM(uint16_t, VOCFormat) {
	/// 8 bits unsigned PCM
	kVOCFormatU8 = 0,
	/// 4 bits to 8 bits Creative ADPCM
	kVOCFormatCreativeADPCM4_8 = 1,
	/// 3 bits to 8 bits Creative ADPCM (AKA 2.6 bits)
	kVOCFormatCreativeADPCM3_8 = 2,
	/// 2 bits to 8 bits Creative ADPCM
	kVOCFormatCreativeADPCM2_8 = 3,
	/// 16 bits signed PCM
	kVOCFormatS16 = 4,
	/// aLaw
	kVOCFormatAlaw = 6,
	/// uLaw
	kVOCFormatUlaw = 7,
	/// 4 bits to 16 bits Creative ADPCM. Only valid in block type 9
	kVOCFormatCreativeADPCM4_16 = 0x200,
};

typedef struct VOCHeader {
	unsigned char signature[20];
	uint16_t size;
	uint16_t version;
	uint16_t checksum;
} VOCHeader;
static_assert(sizeof(VOCHeader) == 26, "Check packing of VOCHeader");

typedef struct VOCDataBlock {
	VOCBlockType type: 8;
	uint32_t size: 24;
} VOCDataBlock;
static_assert(sizeof(VOCDataBlock) == 4, "Check packing of VOCDataBlock");

typedef struct VOCOldData {
	/// Sample rate = 1000000 / (256 - frequency divisor)
	uint8_t frequencyDivisor;
	uint8_t codec;
	// Data follows
} VOCOldData;

typedef struct VOCSilence {
	/// Length of silence - 1, in samples
	uint16_t length;
	/// Sample rate = 1000000 / (256 - frequency divisor)
	uint8_t frequencyDivisor;
} VOCSilence;

/// This marker can be picked up by the playback application to synchronize the sound file with an external animation, or to otherwise perform some action when the marker point has been reached.
typedef struct VOCMarker {
	uint16_t value;
} VOCMarker;

typedef struct VOCExtra {
	/// Sample rate = 256000000 / ((numChannels + 1) * (65536 - frequency divisor))
	uint16_t frequency;
	
	uint8_t codec;
	/// Channel count minus one (0=mono, 1=stereo)
	uint8_t channels;
} VOCExtra;

typedef struct VOCNewData {
	uint32_t sampleRate;
	/// Bits per sample (e.g. 8 or 16)
	uint8_t bitsPerSample;
	/// Channel count (1 is mono, 2 is stereo)
	uint8_t channelCount;
	VOCFormat codec;
	uint32_t reserved;
	// Data follows
} VOCNewData;


NSData * _Nullable convertVOCToRIFF(NSURL *filePath, NSError *_Nullable __autoreleasing*  _Nullable error)
{
	NSFileHandle *handle = [NSFileHandle fileHandleForReadingFromURL:filePath error:error];
	if (!handle) {
		return nil;
	}
	NSData *fileData = [handle readDataOfLength:sizeof(VOCHeader)];
	const VOCHeader* vH = fileData.bytes;
	if (memcmp(vH->signature, ff_voc_magic, sizeof(ff_voc_magic)) == 0) {
		if (error) {
			*error = [NSError errorWithDomain:VOCConverterErrorDomain code:VOCConverterErrorBadMagic userInfo:@{NSURLErrorKey: filePath}];
		}
		return nil;
	}
	{
		uint16_t version = OSSwapLittleToHostInt16(vH->version);
		uint16_t checksum = OSSwapLittleToHostInt16(vH->checksum);

		if (~version + 0x1234 != checksum) {
			if (error) {
				*error = [NSError errorWithDomain:VOCConverterErrorDomain code:VOCConverterErrorBadMagic userInfo:@{NSURLErrorKey: filePath}];
			}
			return nil;
		}
	}
	
	if (error) {
		*error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:@{NSURLErrorKey: filePath}];
	}
	return nil;
}
