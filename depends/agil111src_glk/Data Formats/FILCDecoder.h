//
//  FILCDecoder.hpp
//  agil
//
//  Created by C.W. Betts on 1/6/23.
//

#ifndef FILCDecoder_hpp
#define FILCDecoder_hpp

#include <stdbool.h>
#include <CoreFoundation/CoreFoundation.h>

#ifdef __cplusplus
extern "C" {
#endif

extern CFDataRef CreateGIFFromFLICData(CFDataRef fliDat, bool crunch) CF_RETURNS_RETAINED;
extern CFDataRef CreateGIFFromFLICPath(const char *fliDat, bool crunch) CF_RETURNS_RETAINED;

#ifdef __cplusplus
}
#endif

#endif /* FILCDecoder_hpp */
