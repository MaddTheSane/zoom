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

extern NSData *MUCToRiff(NSURL *theFile, NSError *__autoreleasing*outError);

#ifdef __cplusplus
}
#endif

#endif
