//
//  interface-zoom.c
//  agil
//
//  Created by C.W. Betts on 12/11/21.
//

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <errno.h>
#include <assert.h>

#include "agility.h"
#include "interp.h"
#include <GlkClient/cocoaglk.h>

static char *gamefile_name = "uh...";

#define DEBUG_BELLS_AND_WHISTLES

/* Warning for fontcmd, pictcmd, musiccmd:
  These all extract filenames from fontlist, pictlist, pixlist, songlist.
 Any of these are allowed to be NULL and this should be checked
 before accessing them.  */

#ifdef DEBUG_BELLS_AND_WHISTLES
void bnw_report(char *cmdstr,filename *list,int index)
{
  char logStr[1024];
  strcpy(logStr, "");
  strncat(logStr, ">** ", sizeof(logStr)-1);
  strncat(logStr, cmdstr, sizeof(logStr)-1);
  strncat(logStr, " ", sizeof(logStr)-1);
  if (list!=NULL) {
    strncat(logStr, list[index], sizeof(logStr)-1);
    strncat(logStr, " ", sizeof(logStr)-1);
  }
  strncat(logStr, "**<", sizeof(logStr)-1);
  cocoaglk_log_ex(logStr, 0);
}
#endif /* DEBUG_BELLS_AND_WHISTLES */

void fontcmd(int cmd,int font)
/* 0=Load font, name is fontlist[font]
   1=Restore original (pre-startup) font
   2=Set startup font. (<gamename>.FNT)
*/
{
#ifdef DEBUG_BELLS_AND_WHISTLES
  if (cmd==0) bnw_report("Loading Font",fontlist,font);
  else if (cmd==1) bnw_report("Restoring original font",NULL,0);
#endif
  return;
}

void pictcmd(int cmd,int pict)
/* 1=show global picture, name is pictlist[pict]
   2=show room picture, name is pixlist[pict]
   3=show startup picture <gamename>.P..
  */
{
  filename pictname;
  if (cmd == 1) {
    pictname = pictlist[pict];
  } else if (cmd == 2) {
    pictname = pixlist[pict];
  } else if (cmd == 3) {
    pictname = gamefile_name;
  }

#ifdef DEBUG_BELLS_AND_WHISTLES
  if (cmd==1) bnw_report("Showing picture",pictlist,pict);
  else if (cmd==2) bnw_report("Showing pix",pixlist,pict);
  agt_waitkey();
#endif
   return;
}



int musiccmd(int cmd,int song)
/* For cmd=1 or 2, the name of the song is songlist[song]
  The other commands don't take an additional argument.
   1=play song
   2=repeat song
   3=end repeat
   4=end song
   5=suspend song
   6=resume song
   7=clean-up
   8=turn sound on
   9=turn sound off
   -1=Is a song playing? (0=false, -1=true)
   -2=Is the sound on?  (0=false, -1=true)
*/
{
  if (cmd==8) sound_on=1;
  else if (cmd==9) sound_on=0;
#ifdef DEBUG_BELLS_AND_WHISTLES
  switch (cmd) {
     case 1:bnw_report("Play song",songlist,song);break;
     case 2:bnw_report("Repeat song",songlist,song);break;
     case 3:bnw_report("End repeat",NULL,0);break;
     case 4:bnw_report("End song",NULL,0);break;
     case 5:bnw_report("Suspend song",NULL,0);break;
     case 6:bnw_report("Resume song",NULL,0);break;
     case 7:bnw_report("Clean up",NULL,0);break;
     case 8:bnw_report("Sound On",NULL,0);break;
     case 9:bnw_report("Sound Off",NULL,0);break;
     case -1:return yesno("Is song playing?");
     case -2:return 1;
     }
#endif
  return 0;
}
