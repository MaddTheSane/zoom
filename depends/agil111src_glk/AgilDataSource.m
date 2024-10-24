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
#include "FILCDecoder.h"
#include "VOCConverter.h"
#import "MUCConverter.h"
#include "glk.h"
#import <GlkClient/cocoaglk.h>

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
static const char *const gfxext[GFX_EXT_CNT]={".pcx",
          ".p06", /* 640x200x2 */
          ".p40",".p41",".p42",".p43", /* 320x200x4 */
          ".p13", /* 320x200x16 */
          ".p19", /* 320x200x256 */
          ".p14",".p16", /* 640x200x16, 640x350x16   */
          ".p18", /* 640x480x16 */
          ".gif",".png",".bmp",".jpg",
          ".fli",".flc"};

#define SND_EXT_CNT 4
// FIXME: Are there more possible formats?
static const char *const sndext[SND_EXT_CNT]={".muc",
          ".voc",
          ".mid",
          ".cmf"};

static int decodeImageFormat(glui32 image, int *cmd)
{
  if (image == 0) {
    *cmd = 3;
    return 0;
  }
  if (image > maxpict + 1) {
    *cmd = 2;
    return (int)(image - maxpict - 1);
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
    pictname = hold_fc->gamename;
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
  NSString *fileName = [@(pictname) stringByAppendingPathExtension:@(gfxext[gmode])];
  NSURL *urlPath = [gameDir URLByAppendingPathComponent:fileName];

  if (gmode <= 11 && gmode >= 14) {
    // NSImage can be used to load these files!
    return [NSData dataWithContentsOfURL:urlPath];
  } else if (gmode > 11) {
    NSError *tmpError;
    //Load PCX
    PCXDecoder *pcxData = [[PCXDecoder alloc] initWithFileAtURL:urlPath error:&tmpError];
    if (!pcxData) {
      cocoaglk_NSWarning([NSString stringWithFormat:@"Unable to open %@: PCX conversion failed: %@", urlPath.path, tmpError.localizedDescription]);

      return nil;
    }
    //Decode PCX
    //Write data
    return [pcxData dataRepresentation];
  } else {
    CFDataRef cfDat = CreateGIFFromFLICPath(urlPath.fileSystemRepresentation, false);
    return [CFBridgingRelease(cfDat) copy];
  }
  
  return nil;
}

- (bycopy nullable NSData *)dataForSoundResource:(glui32)sound {
  filename sndname = songlist[sound];
  FILE *sndfile = NULL;
  int smode;
  for(smode=SND_EXT_CNT-1;smode>=0;smode--) {
    sndfile=linopen(sndname,sndext[smode]);
    if (sndfile!=NULL) break;
  }
  if (sndfile==NULL) return nil;
  fclose(sndfile);
  
  NSURL *gameDir = [NSURL fileURLWithFileSystemRepresentation:hold_fc->path isDirectory:YES relativeToURL:nil];
  NSString *fileName = [@(sndname) stringByAppendingPathExtension:@(sndext[smode])];
  NSURL *urlPath = [gameDir URLByAppendingPathComponent:fileName];

  switch (smode) {
    case 0: //.muc
      /*
       Songs are stored in the MUC file format:
         The file format includes no header, but is a collection of
       six-byte records. Each record consists of three unsigned 16-bit
       numbers (stored little-endian like all numbers under AGT: the least
       significant byte comes first): the frequency (in Hertz); the length of
       time of the tone (in milliseconds); and a delay between tones (also in
       milliseconds).
       */
    {
      NSError *err = nil;
      NSData *toRet = MUCToRiff(urlPath, &err);
      if (!toRet) {
        cocoaglk_NSWarning([NSString stringWithFormat:@"Unable to open %@: .MUC coversion failed with error: %@", urlPath.path, err.localizedDescription]);
        return nil;
      }
      return toRet;
    }
      break;
      
    case 1: //.voc
      //TODO: read/convert Creative Voice files.
    {
      NSError *tmpErr;
      NSData *toRet = convertVOCToRIFF(urlPath, &tmpErr);
      if (!toRet) {
        cocoaglk_NSWarning([NSString stringWithFormat:@"Unable to open %@: Creative Voice conversion failed: %@", urlPath.path, tmpErr.localizedDescription]);
      }
      return toRet;
    }
      break;
      
    case 2: //.mid
      // SFBAudioEngine can at least handle MIDI files.
      return [NSData dataWithContentsOfURL:urlPath];
      break;
      
    case 3: //.cmf
      //TODO: read/convert Creative Music Format?
      cocoaglk_NSWarning([NSString stringWithFormat:@"Unable to open %@: No known way to read/convert .cmf files right now!", urlPath.path]);
      return nil;
      break;
      
    default:
      return nil;
      break;
  }

  return nil;
}

@end
