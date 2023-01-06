//
//  AgilDataSource.m
//  agil
//
//  Created by C.W. Betts on 1/5/23.
//

#import "AgilDataSource.h"
#include "agility.h"
#include "interp.h"

typedef NS_ENUM(uint8_t, PCXVersion) {
  PCXVersionFixedEGA = 0,
  PCXVersionModifiableEGA = 2,
  PCXVersionNoPalette,
  PCXVersionWindows,
  PCXVersionTrueColor
};

typedef NS_ENUM(uint8_t, PCXEncoding) {
  PCXEncodingNone = 0,
  PCXEncodingRLE = 1
};

typedef NS_ENUM(uint16_t, PCXPaletteInfo) {
  PCXPaletteInfoColorBW = 1,
  PCXPaletteInfoGrayscale = 2
};

struct PCXHeader {
  uint8_t magic; // = 0x0A
  PCXVersion version;
  PCXEncoding encoding;
  uint8_t bitsPerPlane;
  uint16_t xMin;
  uint16_t yMin;
  uint16_t xMax;
  uint16_t yMax;
  uint16_t horizDPI;
  uint16_t vertDPI;
  uint8_t egaPalette[48];
  char reserved;
  uint8_t colorPlanes;
  uint16_t colorPlaneBytes;
  PCXPaletteInfo paletteMode;
  uint16_t horizRes;
  uint16_t vertRes;
  char reserved2[54];
};

static_assert(sizeof(struct PCXHeader) == 128, "Check alignment!");

static FILE *linopen(const char *name, const char *ext)
{
  FILE *f;
  char *fname;

  fname=assemble_filename(hold_fc->path,name,ext);
  f=fopen(fname,"rb");
  rfree(fname);
  return f;
}

#define GFX_EXT_CNT 17
/* The extension indicates the video mode the picture was intended
   to be viewed in. */
static const char *gfxext[GFX_EXT_CNT]={".pcx",
          ".p06", /* 640x200x2 */
          ".p40",".p41",".p42",".p43", /* 320x200x4 */
          ".p13", /* 320x200x16 */
          ".p19", /* 320x200x256 */
          ".p14",".p16", /* 640x200x16, 640x350x16   */
          ".p18", /* 640x480x16 */
          ".gif",".png",".bmp",".jpg",
          ".fli",".flc"};

static char *gamefile_name = "uh...";

static int decodeImageFormat(glui32 image, int *cmd)
{
  if (image == 0) {
    *cmd = 3;
    return 0;
  }
  if (image > maxpict + 1) {
    *cmd = 2;
    return image - maxpict - 1;
  } else {
    *cmd = 1;
    return image - 1;
  }
  return 0;
}

@implementation AgilDataSource

- (instancetype)initWithFileSystemRepresentation:(const char*)fsrep
{
  if (self = [super init]) {
    
  }
  return self;
}


- (bycopy nullable NSData *)dataForImageResource:(glui32)image {
  filename pictname;
  int gmode;
  FILE *pcxfile = NULL;
  int cmd;
  int pict;
  pict = decodeImageFormat(image, &cmd);

  if (cmd == 1) {
    pictname = pictlist[pict];
  } else if (cmd == 2) {
    pictname = pixlist[pict];
  } else if (cmd == 3) {
    pictname = gamefile_name;
  } else {
    return nil;
  }
  
  /* Find graphics file; determine mode from extension... */
  for(gmode=GFX_EXT_CNT-1;gmode>=0;gmode--) {
    pcxfile=linopen(pictname,gfxext[gmode]);
    if (pcxfile!=NULL) break;
  }
  if (pcxfile==NULL) return nil;
  fclose(pcxfile);

  if (gmode <= 11 && gmode >= 14) {
    // NSImage can be used to load these files!
    char *fname = assemble_filename(hold_fc->path, pictname, gfxext[gmode]);
    NSURL *urlPath = [NSURL fileURLWithFileSystemRepresentation:fname isDirectory:NO relativeToURL:nil];
    rfree(fname);
    return [NSData dataWithContentsOfURL:urlPath];
  } else if (gmode > 11) {
    //Load PCX
    //Decode PCX
    //Write data
  } else {
    //TODO: look up .fli/.flc files
  }
  
  return nil;
}

- (bycopy nullable NSData *)dataForSoundResource:(glui32)sound { 
  return nil;
}

@end
