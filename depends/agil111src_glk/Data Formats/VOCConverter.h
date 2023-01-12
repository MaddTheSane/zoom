//
//  VOCConverter.h
//  agil
//
//  Created by C.W. Betts on 1/12/23.
//

#ifndef VOCConverter_h
#define VOCConverter_h

#include <Foundation/Foundation.h>

CF_ASSUME_NONNULL_BEGIN

extern const NSErrorDomain VOCConverterErrorDomain;

typedef NS_ERROR_ENUM(VOCConverterErrorDomain, VOCConverterErrors) {
	VOCConverterErrorBadMagic,
	VOCConverterErrorUnexpectedEOF
};

extern NSData * _Nullable convertVOCToRIFF(NSURL *filePath, NSError *_Nullable __autoreleasing* _Nullable error) __attribute__((swift_error(null_result)));

CF_ASSUME_NONNULL_END

#endif /* VOCConverter_h */
