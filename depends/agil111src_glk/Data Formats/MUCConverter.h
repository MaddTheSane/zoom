//
//  MUCConverter.h
//  ZoomCocoa
//
//  Created by C.W. Betts on 10/15/24.
//

#ifndef MUCConverter_h
#define MUCConverter_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

extern NSData *_Nullable MUCToRiff(NSURL *_Nonnull theFile, NSError * _Nullable __autoreleasing* _Nullable outError);

#ifdef __cplusplus
}
#endif

#endif
