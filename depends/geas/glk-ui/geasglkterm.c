/*$Id: //depot/prj/geas/master/code/geasglkterm.c#4 $
  geasglkterm.c

  Bridge file between Geas and GlkTerm.  Only needed if using GlkTerm.

  Copyright (C) 2006 David Jones.  Distribution or modification in any
  form permitted.

  Unix specific (see the call to close()).
*/

#include <stddef.h>

#include <unistd.h>

#include "glk.h"
#include "glkstart.h"

const char *storyfilename;

glkunix_argumentlist_t glkunix_arguments[] = {
    { "", glkunix_arg_ValueFollows, "filename: The game file to load."},
    { NULL, glkunix_arg_End, NULL }
};

int
glkunix_startup_code(glkunix_startup_t *data)
{
  storyfilename = data->argv[1];

  if (storyfilename) {
    /* We close stderr because the Geas core prints a lot of debug stuff
     * to stderr.  This corrupts the curses based display unless
     * redirected.
     */
    close(2);
    return 1;
  }
  return 0;
}
