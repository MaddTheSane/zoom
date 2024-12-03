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

CF_ASSUME_NONNULL_BEGIN

extern CFDataRef _Nullable CreateGIFFromFLICData(CFDataRef fliDat, bool crunch) CF_RETURNS_RETAINED;
extern CFDataRef _Nullable CreateGIFFromFLICPath(const char *fliDat, bool crunch) CF_RETURNS_RETAINED;
extern CFDataRef _Nullable CreateGIFFromFLICFileURL(CFURLRef fliDat, bool crunch) CF_RETURNS_RETAINED;

CF_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif

#endif /* FILCDecoder_hpp */
