

#import "ZoomSkein.h"
#import "ZoomSkeinView.h"
#import <WebKit/WebKit.h>


// Note: Deprecations! WebDocumentRepresentation needs to be replaced.
// = WebKit interface (b0rked: webkit doesn't really support this) =

@interface ZoomSkein(ZoomSkeinWebDocRepresentation)<WebDocumentRepresentation>
@end

//// Using with the web kit
@interface ZoomSkeinView(ZoomSkeinViewWeb)<WebDocumentView>

@end
