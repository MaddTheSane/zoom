//
//  AgilDataSource.h
//  agil
//
//  Created by C.W. Betts on 1/5/23.
//

#import <Foundation/Foundation.h>
#import <GlkView/glk.h>
#import <GlkView/GlkImageSourceProtocol.h>
#import <GlkView/GlkSoundSourceProtocol.h>

NS_ASSUME_NONNULL_BEGIN

@interface AgilDataSource : NSObject <GlkImageSource, GlkSoundSource>

@end

NS_ASSUME_NONNULL_END
