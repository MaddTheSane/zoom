//
//  PCXDecoder.h
//  agil
//
//  Created by C.W. Betts on 1/6/23.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const PCXDecoderErrorDomain;
typedef NS_ERROR_ENUM(PCXDecoderErrorDomain, PCXDecoderErrors) {
	PCXDecoderInvalidMagic,
	PCXDecoderUnknownVersion,
	PCXDecoderBadEncoding,
	PCXDecoderUnknownPalette,
	PCXDecoderUnexpectedEOF,
	PCXDecoderNoVGAPalette
};


@interface PCXDecoder : NSObject

- (nullable instancetype)initWithFileAtURL:(NSURL*)url error:(NSError**)outErr;

- (nullable NSData*)TIFFRepresentation;

@end

NS_ASSUME_NONNULL_END
