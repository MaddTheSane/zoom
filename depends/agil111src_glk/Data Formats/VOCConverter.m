//
//  VOCConverter.c
//  agil
//
//  Created by C.W. Betts on 1/12/23.
//

#include "VOCConverter.h"


const NSErrorDomain VOCConverterErrorDomain = @"com.github.MaddTheSane.AGT.VOCErrors";


NSData * _Nullable convertVOCToRIFF(NSURL *filePath, NSError *_Nullable __autoreleasing*  _Nullable error)
{
	if (error) {
		*error = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:nil];
	}
	return nil;
}
