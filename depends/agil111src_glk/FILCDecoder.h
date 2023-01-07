//
//  FILCDecoder.hpp
//  agil
//
//  Created by C.W. Betts on 1/6/23.
//

#ifndef FILCDecoder_hpp
#define FILCDecoder_hpp

#include <CoreFoundation/CoreFoundation.h>

#ifdef __cplusplus
extern "C" {
#endif

extern CFDataRef CreateGIFFromFLICData(CFDataRef fliDat) CF_RETURNS_RETAINED;

#ifdef __cplusplus
}
#endif

#endif /* FILCDecoder_hpp */
