//
//  ScareResourceHandler.h
//  scare
//
//  Created by C.W. Betts on 12/22/21.
//

#import <Foundation/Foundation.h>
#import <GlkView/GlkImageSourceProtocol.h>
#import <GlkView/GlkSoundSourceProtocol.h>

NS_ASSUME_NONNULL_BEGIN

@interface ScareResourceHandler : NSObject <GlkImageSource, GlkSoundSource>

@end

NS_ASSUME_NONNULL_END
