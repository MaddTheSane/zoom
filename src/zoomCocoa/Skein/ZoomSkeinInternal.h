//
//  ZoomSkeinInternal.h
//  ZoomView
//
//  Created by C.W. Betts on 11/2/21.
//

#ifndef ZoomViewInternal_h
#define ZoomViewInternal_h

#import <Foundation/Foundation.h>
#import "ZoomSkein.h"

@interface ZoomSkein() {
	@private
	ZoomSkeinItem* rootItem;
	
	/// Web data
	NSMutableData* webData;
}

@end

#pragma GCC visibility push(hidden)

extern NSDictionary<NSAttributedStringKey,id>* itemTextAttributes;
extern NSDictionary<NSAttributedStringKey,id>* labelTextAttributes;

#pragma GCC visibility pop

#endif /* ZoomViewInternal_h */
