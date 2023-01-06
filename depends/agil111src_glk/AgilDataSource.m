//
//  AgilDataSource.m
//  agil
//
//  Created by C.W. Betts on 1/5/23.
//

#import "AgilDataSource.h"
#include "agility.h"
#include "interp.h"
#import "PCXDecoder.h"

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
  NSURL *gameDir = [NSURL fileURLWithFileSystemRepresentation:hold_fc->path isDirectory:YES relativeToURL:nil];
  NSURL *urlPath = [gameDir URLByAppendingPathComponent:@(pictname)];
  urlPath = [urlPath URLByAppendingPathExtension:@(gfxext[gmode])];

  if (gmode <= 11 && gmode >= 14) {
    // NSImage can be used to load these files!
    return [NSData dataWithContentsOfURL:urlPath];
  } else if (gmode > 11) {
    NSError *tmpError;
    //Load PCX
    PCXDecoder *pcxData = [[PCXDecoder alloc] initWithFileAtURL:urlPath error:&tmpError];
    //Decode PCX
    //Write data
  } else {
    // Found! https://en.wikipedia.org/wiki/FLIC_(file_format)
    // TODO: Parse and re-encode file (GIF? APNG?).
  }
  
  return nil;
}

- (bycopy nullable NSData *)dataForSoundResource:(glui32)sound { 
  return nil;
}

@end
