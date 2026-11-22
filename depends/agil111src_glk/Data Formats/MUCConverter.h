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

/// Converts the MUC file to M4A/AAC
/// - parameter inFile: The location of the MUC file.
/// - parameter outFile: The location that the m4a will be saved to. May be `nil`, in which cas a random location will be used instead.
/// - parameter outError: Will be filled if an error occurs.
/// - returns: The location of the written AAC file, or `nil` on failure.
extern NSURL *_Nullable MUCToURL(NSURL *_Nonnull inFile, NSURL *_Nullable outFile, NSError * _Nullable __autoreleasing* _Nullable outError);
/// Converts the MUC file to M4A/AAC and loads it into memory.
/// - parameter theFile: The location of the MUC file.
/// - parameter outError: Will be filled if an error occurs.
/// - returns: The AAC data, or `nil` on failure.
extern NSData *_Nullable MUCToRiff(NSURL *_Nonnull theFile, NSError * _Nullable __autoreleasing* _Nullable outError);

#ifdef __cplusplus
}
#endif

#endif
