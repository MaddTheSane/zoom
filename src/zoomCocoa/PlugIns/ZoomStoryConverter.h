//
//  ZoomImporter.h
//  ZoomCocoa
//
//  Created by C.W. Betts on 10/23/24.
//

#ifndef __ZOOMPLUGINS_ZOOMIMPORTER_H__
#define __ZOOMPLUGINS_ZOOMIMPORTER_H__

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class UTType;

@protocol ZoomStoryConverter <NSObject>

/// Convert a file to a usable format.
/// \param url The file to import.
/// \param handler The handler.
+ (void)convertStoryFileAtURL:(NSURL*)url completionHandler:(void(^)(NSURL *__nullable newURL, NSError*__nullable error))handler;

/// \c YES if the specified file URL is one that the plugin can convert
+ (BOOL) canConvertURL: (NSURL*) path;

/// Return an array of file types that an \c NSOpenPanel can select from.
///
/// This may be UTIs, file extensions, or OSTypes (Created by \c NSFileTypeForHFSTypeCode or similar).
@property (class, readonly, copy) NSArray<NSString*> *supportedConverterFileTypes;

@optional

/// Return an array of content types that an \c NSOpenPanel can select from.
@property (class, readonly, copy) NSArray<UTType*> *supportedConverterContentTypes;

@end

NS_ASSUME_NONNULL_END

#endif
