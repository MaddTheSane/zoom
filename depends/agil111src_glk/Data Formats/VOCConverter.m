//
//  VOCConverter.c
//  agil
//
//  Created by C.W. Betts on 1/12/23.
//

#include "VOCConverter.h"


const NSErrorDomain VOCConverterErrorDomain = @"com.github.MaddTheSane.AGT.VOCErrors";
static const unsigned char ff_voc_magic[21] = "Creative Voice File\x1A";


typedef NS_ENUM(uint8_t, VOCBlockType) {
	kVOCTerminator = 0,
	kVOCSoundData = 1,
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
	kVOCFormatU8 = 0,
	kVOCFormatCreativeADPCM4_8 = 1,
	kVOCFormatCreativeADPCM3_8 = 2,
	kVOCFormatCreativeADPCM2_8 = 3,
	kVOCFormatS16 = 4,
	kVOCFormatAlaw = 6,
	kVOCFormatUlaw = 7,
	kVOCFormatCreativeADPCM4_16 = 0x200,
};


NSData * _Nullable convertVOCToRIFF(NSURL *filePath, NSError *_Nullable __autoreleasing*  _Nullable error)
{
	if (error) {
		*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:nil];
	}
	return nil;
}
