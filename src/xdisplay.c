/*
 *  A Z-Machine
 *  Copyright (C) 2000 Andrew Hunter
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 * Display for X-Windows
 */

#include "../config.h"

#if WINDOW_SYSTEM == 1

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

#include "xdisplay.h"
#include "xfont.h"

#include "zmachine.h"
#include "display.h"
#include "rc.h"

#include "image.h"
#include "image_ximage.h"

#include "format.h"

#ifdef HAVE_XRENDER
# include <X11/extensions/Xrender.h>
#endif

#ifdef HAVE_XFT
# include <X11/Xft/Xft.h>
#endif

#ifdef HAVE_XDBE
# include <X11/extensions/Xdbe.h>
#endif

/* #define DEBUG */

/* Globals */
Display*     x_display;
int          x_screen = 0;

Window       x_mainwin;
GC           x_wingc, x_caretgc;
Drawable     x_drawable = None;

Pixmap       x_pixmap = None;
GC           x_pixgc;

#ifdef HAVE_XRENDER
XRenderPictFormat* x_picformat = NULL;
Picture            x_winpic = None;
Picture            x_pixpic = None;

static int pix_w, pix_h;
#endif

#ifdef HAVE_XDBE
XdbeBackBuffer x_backbuffer = None;
#endif

static Region dregion = None;
static int    resetregion = 0;

static int scroll_pos    = 20;
static int scroll_range  = 500;
static int scroll_height = 100;
static int scroll_top    = 0;
int scrollpos = 0;

/* (Used by a scroll in progress) */
static int scroll_start  = 0;
static int scroll_offset = 0;
static int scroll_state  = 0;
static int scrolling     = 0;

static int win_left, win_top;
static int win_width, win_height;
static int click_x, click_y;

static Atom x_prot[5];
static Atom wmprots;

#define SCROLLBAR_SIZE 15
#undef  BORDER_PLAIN

#ifndef BORDER_PLAIN
# define BORDER_3D
# define BORDER_SIZE 4
#else
# define BORDER_SIZE 1
#endif

#define N_COLS 18
XColor   x_colour[N_COLS] =
{ { 0, 0xbb00,0xbb00,0xbb00, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0x6600,0x6600,0x6600, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0xff00,0xff00,0xff00, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0xee00,0xee00,0xee00, DoRed|DoGreen|DoBlue, 0 },

  /* Scrollbar colours */
  { 0, 0x0080,0x9900,0xee00, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0x00bb,0xdd00,0xff00, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0x0020,0x6600,0xaa00, DoRed|DoGreen|DoBlue, 0 },

  /* ZMachine colours start here */
  { 0, 0x0000,0x0000,0x0000, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0xff00,0x0000,0x0000, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0x0000,0xff00,0x0000, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0xff00,0xff00,0x0000, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0x0000,0x0000,0xff00, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0xff00,0x0000,0xff00, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0x0000,0xff00,0xff00, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0xff00,0xff00,0xcc00, DoRed|DoGreen|DoBlue, 0 },
  
  { 0, 0xbb00,0xbb00,0xbb00, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0x8800,0x8800,0x8800, DoRed|DoGreen|DoBlue, 0 },
  { 0, 0x4400,0x4400,0x4400, DoRed|DoGreen|DoBlue, 0 }};

#ifdef HAVE_XFT
XftColor xft_colour[N_COLS];
XftDraw* xft_drawable;
XftDraw* xft_maindraw = NULL;
#endif

#define DEFAULT_FORE 0
#define DEFAULT_BACK 7
#define FIRST_ZCOLOUR 7

static unsigned char terminating[256] =
{
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0
};

/* === Misc functions === */

static inline int istrlen(const int* string)
{
  int x = 0;

  while (string[x] != 0) x++;
  return x;
}
static inline void istrcpy(int* dest, const int* src)
{
  int x;

  for (x=0; src[x] != 0; x++)
    {
      dest[x] = src[x];
    }
  dest[x] = 0;
}

/* === Functions specific to this display style === */

#ifdef HAVE_XFT
static void alloc_xft_colours(void)
{
  int x;

  for (x=0; x<N_COLS; x++)
    {
      XRenderColor fcolour;

      fcolour.red   = x_colour[x].red;
      fcolour.green = x_colour[x].green;
      fcolour.blue  = x_colour[x].blue;
      fcolour.alpha = 0xffff;

      if (!XftColorAllocValue(x_display, DefaultVisual(x_display, x_screen), 
			      DefaultColormap(x_display, x_screen),
			      &fcolour, 
			      &xft_colour[x]))
	{
	  fprintf(stderr, "Unable to allocate colour for Xft\n");
	}
    }
}
#endif

static void reset_clip(void)
{
  if (resetregion)
    {
      XRectangle clip;
      Region rgn;

      clip.x = clip.y = BORDER_SIZE;
      clip.width = win_x; clip.height = win_y;

      rgn = XCreateRegion();
      XUnionRectWithRegion(&clip, rgn, rgn);
      XSetRegion(x_display, x_wingc, rgn);
#ifdef HAVE_XFT
      if (xft_drawable != NULL)
	XftDrawSetClip(xft_drawable, rgn);
#endif

      resetregion = 0;
      XFree(rgn);
    }
}

static void invalidate_scrollbar(void)
{
  XRectangle thebar;

  if (dregion == None)
    dregion = XCreateRegion();
  
  thebar.x = win_x + BORDER_SIZE*2;
  thebar.y = 0;
  thebar.width = SCROLLBAR_SIZE;
  thebar.height = total_y;
  XUnionRectWithRegion(&thebar, dregion, dregion);
}

static void draw_caret(void)
{
  int ison;

  reset_clip();

  if (insert)
    XSetLineAttributes(x_display, x_caretgc, 2, LineSolid,
		       CapButt, JoinBevel);
  else
    XSetLineAttributes(x_display, x_caretgc, 4, LineSolid,
		       CapButt, JoinBevel);

  XSetForeground(x_display, x_caretgc,
		 x_colour[FIRST_ZCOLOUR+CURWIN.back].pixel ^
		 x_colour[4].pixel);

  ison = caret_on;
  if (more_on)
    ison = 0;

  if ((ison^caret_shown))
    {
      XDrawLine(x_display, x_mainwin, x_caretgc, 
		caret_x + BORDER_SIZE, caret_y + BORDER_SIZE,
		caret_x + BORDER_SIZE, caret_y + caret_height + BORDER_SIZE);

      caret_shown = !caret_shown;
    }
}

static void move_caret(void)
{ 
  int last_on = caret_on;

  caret_on = 0;
  draw_caret();

  if (CURWIN.overlay)
    {
      input_x = caret_x = xfont_x*CURWIN.xpos;
      input_y = caret_y = xfont_y*CURWIN.ypos;
      input_y += xfont_get_ascent(font[style_font[(CURSTYLE>>1)&15]]);
      caret_height = xfont_y;
    }
  else
    {
      if (CURWIN.lastline != NULL)
	{
	  input_x = caret_x = CURWIN.xpos;
	  input_y = caret_y = CURWIN.lastline->baseline-scrollpos;
	  caret_y -= CURWIN.lastline->ascent;
	  caret_height = CURWIN.lastline->ascent+CURWIN.lastline->descent-1;
	}
      else
	{
	  input_x = input_y = caret_x = caret_y = 0;
	  caret_height = xfont_y-1;
	}
    } 

  if (text_buf != NULL)
    {
      caret_x += xfont_get_text_width(font[style_font[(CURSTYLE>>1)&15]],
				      text_buf,
				      buf_offset);
    }

  caret_on = last_on;
  draw_caret();
}

static void show_caret(void)
{
  caret_on = 1;
  draw_caret();
}

static void hide_caret(void)
{
  caret_on = 0;
  draw_caret();
}

static void draw_input_text(void)
{
  int w;
  int on;
  int fg, bg;

  reset_clip();

  fg = CURWIN.fore;
  bg = CURWIN.back;

  if (CURWIN.style&1)
    {
      fg = CURWIN.back;
      bg = CURWIN.fore;
    }

  on = caret_on;
  hide_caret();

  if (CURWIN.overlay)
    {
      input_x = caret_x = xfont_x*CURWIN.xpos;
      input_y = caret_y = xfont_y*CURWIN.ypos;
      input_y += xfont_get_ascent(font[style_font[(CURSTYLE>>1)&15]]);
      caret_height = xfont_y;
    }
  else
    {
      if (CURWIN.lastline != NULL)
	{
	  input_x = caret_x = CURWIN.xpos;
	  input_y = caret_y = CURWIN.lastline->baseline-scrollpos;
	  caret_y -= CURWIN.lastline->ascent;
	  caret_height = CURWIN.lastline->ascent+CURWIN.lastline->descent-1;
	}
      else
	{
	  input_x = input_y = caret_x = caret_y = 0;
	  caret_height = xfont_y-1;
	}
    }

  if (text_buf != NULL)
    {
      w = xfont_get_text_width(font[style_font[(CURSTYLE>>1)&15]],
			       text_buf,
			       istrlen(text_buf));

      XSetForeground(x_display, x_wingc, x_colour[bg+FIRST_ZCOLOUR].pixel);
      XFillRectangle(x_display, x_mainwin, x_wingc,
		     input_x + BORDER_SIZE,
		     caret_y + BORDER_SIZE,
		     win_x - input_x,
		     xfont_get_height(font[style_font[(CURSTYLE>>1)&15]]));

      caret_x += xfont_get_text_width(font[style_font[(CURSTYLE>>1)&15]],
				      text_buf,
				      buf_offset);

      xfont_set_colours(fg+FIRST_ZCOLOUR, bg+FIRST_ZCOLOUR);
#ifdef HAVE_XFT
      { XftDraw* xft_lastdraw; /* Save the last drawable */
      if (xft_drawable != NULL && xft_maindraw != NULL)
	{
	  /* 
	   * Need to draw any XFT stuff on the main window, not the hidden
	   * buffer 
	   */
	  xft_lastdraw = xft_drawable;
	  xft_drawable = xft_maindraw;
	}
#endif
      xfont_plot_string(font[style_font[(CURSTYLE>>1)&15]],
			x_mainwin, x_wingc,
			input_x+BORDER_SIZE, input_y+BORDER_SIZE,
			text_buf,
			istrlen(text_buf));
#ifdef HAVE_XFT
      if (xft_drawable != NULL && xft_maindraw != NULL)
	{
	  xft_drawable = xft_lastdraw;
	}
      }
#endif
    }

  if (on)
    show_caret();
}

static void resize_window(void);
static void size_window(void)
{
  XSizeHints* hints;

  win_x = size_x*xfont_x;
  win_y = size_y*xfont_y;

  hints = XAllocSizeHints();
  hints->min_width  = 200;
  hints->min_height = 100;
  hints->width      = win_x+BORDER_SIZE*2;
  hints->height     = win_y+BORDER_SIZE*2;
  hints->flags      = PSize|PMinSize;  
  XSetWMNormalHints(x_display, x_mainwin, hints);
  XFree(hints);
  
  XResizeWindow(x_display, x_mainwin,
		total_x=(win_x+BORDER_SIZE*2+SCROLLBAR_SIZE),
		total_y=(win_y+BORDER_SIZE*2));
}

static void draw_scrollbar(int isselected)
{
  int pos, height;
  int x;

  int ca, cb;

  static XColor scroll_grade[8] = { { 0, 0,0,0, DoRed|DoGreen|DoBlue, 0 } };

#ifdef BORDER_3D
# define SG_FROM 0
# define SG_TO   3
#else
# define SG_FROM 2
# define SG_TO   0
#endif

  reset_clip();

  ca = 5; cb = 6;

  if (isselected)
    {
      ca = 6; cb = 5;
    }

  /* Allocate colours if necessary */
  if (scroll_grade[0].red == 0)
    {
      for (x=0; x<8; x++)
	{
	  scroll_grade[x].red = x_colour[SG_FROM].red + 
	    (((x_colour[SG_TO].red - x_colour[SG_FROM].red)*(x+1))/(8));
	  scroll_grade[x].green = x_colour[SG_FROM].green + 
	    (((x_colour[SG_TO].green - x_colour[SG_FROM].green)*(x+1))/8);
	  scroll_grade[x].blue = x_colour[SG_FROM].blue + 
	    (((x_colour[SG_TO].blue - x_colour[SG_FROM].blue)*(x+1))/8);

	  scroll_grade[x].flags = DoRed|DoGreen|DoBlue;
	  scroll_grade[x].pixel = 0;
	  scroll_grade[x].pad   = 0;

	  if (!XAllocColor(x_display, DefaultColormap(x_display, x_screen),
			   &scroll_grade[x]))
	    {
	      scroll_grade[x].pixel = BlackPixel(x_display, x_screen);
	    }
	}
    }

#ifdef HAVE_XFT
  alloc_xft_colours();
#endif

  /* Draw the scrollbar well */
  for (x=0; x<8; x++)
    {
      XSetForeground(x_display, x_wingc, scroll_grade[x].pixel);
      XFillRectangle(x_display, x_drawable, x_wingc,
		     win_x+BORDER_SIZE*2 + ((x*SCROLLBAR_SIZE)/8), 0,
		     SCROLLBAR_SIZE, total_y);
    }

  if (scroll_range == 0)
    return;

  /* Calculate the position and size of the scrollbar tab */
  pos = (scroll_pos*total_y)/scroll_range;
  height = (scroll_height*total_y)/scroll_range;

  if (height < 20)
    height = 20;

  if (pos > total_y)
    pos = total_y-height-1;
  if (pos + height >= total_y)
    {
      pos -= (pos+height)-total_y+1;
    }

  if (pos < 0 || (pos+height) >= total_y)
    return;

  /* Draw the scrollbar tab */
  XSetForeground(x_display, x_wingc, x_colour[4].pixel);
  XFillRectangle(x_display, x_drawable, x_wingc,
		 win_x+BORDER_SIZE*2, pos,
		 SCROLLBAR_SIZE, height);

  XSetForeground(x_display, x_wingc, x_colour[ca].pixel);
  XDrawLine(x_display, x_drawable, x_wingc,
	    win_x+BORDER_SIZE*2, pos,
	    win_x+BORDER_SIZE*2+SCROLLBAR_SIZE, pos);
  XDrawLine(x_display, x_drawable, x_wingc,
	    win_x+BORDER_SIZE*2, pos,
	    win_x+BORDER_SIZE*2, pos+height);

  XSetForeground(x_display, x_wingc, x_colour[cb].pixel);
  XDrawLine(x_display, x_drawable, x_wingc,
	    win_x+BORDER_SIZE*2, pos+height,
	    win_x+BORDER_SIZE*2+SCROLLBAR_SIZE, pos+height);
  XDrawLine(x_display, x_drawable, x_wingc,
	    win_x+BORDER_SIZE*2+SCROLLBAR_SIZE-1, pos,
	    win_x+BORDER_SIZE*2+SCROLLBAR_SIZE-1, pos+height);

  /* Draw the ridges */
  XSetForeground(x_display, x_wingc, x_colour[ca].pixel);
  for (x=0; x<3; x++)
    {
      int ypos;

      ypos = pos + (height/2) - 4 + x*4;
      XDrawLine(x_display, x_drawable, x_wingc,
		win_x+BORDER_SIZE*2+3, ypos,
		win_x+BORDER_SIZE*2+SCROLLBAR_SIZE-4, ypos);
    }

  XSetForeground(x_display, x_wingc, x_colour[cb].pixel);
  for (x=0; x<3; x++)
    {
      int ypos;

      ypos = pos + (height/2) - 3 + x*4;
      XDrawLine(x_display, x_drawable, x_wingc,
		win_x+BORDER_SIZE*2+3, ypos,
		win_x+BORDER_SIZE*2+SCROLLBAR_SIZE-4, ypos);
    }
}

static void draw_window()
{
  int top, left, bottom, right;
  int win;
  Region newregion;
  XRectangle clip;

  int more[] = { '[', 'M', 'O', 'R', 'E', ']' };
  int morew, moreh;

  hide_caret();

  resetregion = 0;

  top    = BORDER_SIZE;
  left   = BORDER_SIZE;
  bottom = top + win_y;
  right  = left + win_x;

  if (dregion == None)
    {
      XRectangle r;

      r.x = 0; r.y = 0;
      r.width = total_x; r.height = total_y;

      dregion = XCreateRegion();
      XUnionRectWithRegion(&r, dregion, dregion);
    }

  moreh = xfont_get_descent(font[style_font[2]]) + xfont_get_ascent(font[style_font[2]]);
  morew = xfont_get_text_width(font[style_font[2]], more, 6);

  clip.x = (win_x+BORDER_SIZE*2) - (morew + 2);
  clip.y = (win_y+BORDER_SIZE*2) - (moreh + 2);
  clip.width = morew+2; clip.height = moreh+2;
  XUnionRectWithRegion(&clip, dregion, dregion);

  XSetRegion(x_display, x_wingc, dregion);
#ifdef HAVE_XFT
  if (xft_drawable != NULL)
    XftDrawSetClip(xft_drawable, dregion);
#endif

  /* Draw border */
#ifndef BORDER_3D
  /* Plain white border */
  XSetForeground(x_display, x_wingc, x_colour[2].pixel);
  XFillRectangle(x_display, x_drawable, x_wingc, 
		 0, 0,
		 left, bottom);
  XFillRectangle(x_display, x_drawable, x_wingc, 
		 0, 0,
		 right, top);
  XFillRectangle(x_display, x_drawable, x_wingc, 
		 right, 0,
		 BORDER_SIZE, bottom);
  XFillRectangle(x_display, x_drawable, x_wingc, 
		 0, bottom,
		 right+BORDER_SIZE, BORDER_SIZE);
#else
  /* Inset 3D border */
  XSetForeground(x_display, x_wingc, x_colour[3].pixel);
  XFillRectangle(x_display, x_drawable, x_wingc, 
		 0, 0,
		 left, bottom);
  XFillRectangle(x_display, x_drawable, x_wingc, 
		 0, 0,
		 right, top);
  XFillRectangle(x_display, x_drawable, x_wingc, 
		 right, 0,
		 BORDER_SIZE, bottom);
  XFillRectangle(x_display, x_drawable, x_wingc, 
		 0, bottom,
		 right+BORDER_SIZE, BORDER_SIZE);

  XSetForeground(x_display, x_wingc, x_colour[0].pixel);
  XFillRectangle(x_display, x_drawable, x_wingc, 
		 0, 0,
		 left-3, bottom+BORDER_SIZE);
  XFillRectangle(x_display, x_drawable, x_wingc, 
		 0, 0,
		 right+BORDER_SIZE, top-3);
  XFillRectangle(x_display, x_drawable, x_wingc, 
		 right+3, 0,
		 BORDER_SIZE-3, bottom+BORDER_SIZE);
  XFillRectangle(x_display, x_drawable, x_wingc, 
		 0, bottom+3,
		 right+BORDER_SIZE, BORDER_SIZE-3);

  XSetLineAttributes(x_display, x_wingc, 1, LineSolid,
		     CapProjecting, JoinBevel);
  XSetForeground(x_display, x_wingc, x_colour[1].pixel);
  XDrawLine(x_display, x_drawable, x_wingc,
	    left-3, top-3, right+2, top-3);
  XDrawLine(x_display, x_drawable, x_wingc,
	    left-3, top-3, left-3, bottom+2);

  XSetForeground(x_display, x_wingc, x_colour[2].pixel);
  XDrawLine(x_display, x_drawable, x_wingc,
	    right+2, bottom+2, right+2, top-3);
  XDrawLine(x_display, x_drawable, x_wingc,
	    right+2, bottom+2, left-3, bottom+2);
#endif

  /* Scrollbar */
  draw_scrollbar(scroll_state);

  /* Reduce clip region */
  clip.x = BORDER_SIZE; clip.y = BORDER_SIZE;
  clip.width = win_x; clip.height = win_y;
  
  newregion = XCreateRegion();
  XUnionRectWithRegion(&clip, newregion, newregion);

  XIntersectRegion(dregion, newregion, newregion);
  
  XSetRegion(x_display, x_wingc, newregion);

  if (x_pixmap == None)
    {
#ifdef HAVE_XFT
      if (xft_drawable != NULL)
	XftDrawSetClip(xft_drawable, newregion);
#endif
      
      /* Text */
      for (win = 0; win<3; win++)
	{
	  if (text_win[win].overlay)
	    {
	      int x,y;
	      
	      x=0; y=0;
	      
	      for (y=text_win[win].winsy/xfont_y; y<size_y; y++)
		{
		  for (x=0; x<size_x; x++)
		    {
		      if (text_win[win].cline[y].cell[x] != ' ' ||
			  text_win[win].cline[y].bg[x]   != 255 ||
			  y*xfont_y < text_win[win].winly)
			{
			  int len;
			  int fn, fg, bg;
			  
			  len = 1;
			  fg = text_win[win].cline[y].fg[x];
			  bg = text_win[win].cline[y].bg[x];
			  fn = text_win[win].cline[y].font[x];
			  
			  while (text_win[win].cline[y].font[x+len] == fn &&
				 text_win[win].cline[y].fg[x+len]   == fg &&
				 text_win[win].cline[y].bg[x+len]   == bg &&
				 x+len < size_x &&
				 (bg != 255 ||
				  text_win[win].cline[y].cell[x+len] != ' ' ||
				  y*xfont_y<text_win[win].winly))
			    len++;
			  
			  if (bg == 255)
			    bg = fg;
			  
			  XSetForeground(x_display, x_wingc, x_colour[bg+FIRST_ZCOLOUR].pixel);
			  XFillRectangle(x_display, x_drawable, x_wingc,
					 x*xfont_x + BORDER_SIZE,
					 y*xfont_y + BORDER_SIZE,
					 len*xfont_x,
					 xfont_y);
			  
			  xfont_set_colours(fg+FIRST_ZCOLOUR, bg+FIRST_ZCOLOUR);
			  xfont_plot_string(font[fn],
					    x_drawable, x_wingc,
					    x*xfont_x+BORDER_SIZE,
					    y*xfont_y+BORDER_SIZE +
					    xfont_get_ascent(font[fn]),
					    &text_win[win].cline[y].cell[x],
					    len);
			  
			  x+=len-1;
			}
		    }
		}
	    }
	  else
	    {
	      struct line* line;
	      struct text* text;
	      XFONT_MEASURE lasty, width;
	      int offset;
	      
	      Region r;
	      XRectangle clip;
	      
	      int phase;
	      
	      r = XCreateRegion();
	      clip.x = 0; clip.y = BORDER_SIZE + text_win[win].winsy;
	      clip.width = total_x;
	      clip.height = text_win[win].winly - text_win[win].winsy;
	      XUnionRectWithRegion(&clip, r, r);
	      
	      XIntersectRegion(newregion, r, r);
	      
	      XSetRegion(x_display, x_wingc, r);
#ifdef HAVE_XFT
	      if (xft_drawable != NULL)
		XftDrawSetClip(xft_drawable, newregion);
#endif
	      XFree(r);
	      
	      line = text_win[win].line;
	      lasty = BORDER_SIZE;
	      
	      /* Free any lines that scrolled off ages ago */
	      if (line != NULL)
		{
		  while (line->baseline < -32768)
		    {
		      struct line* n;
		      
		      n = line->next;
		      if (n == NULL)
			break;
		      
		      if (text_win[win].topline == line)
			text_win[win].topline = NULL;
		      
		      if (n->start != line->start)
			{
			  struct text* nt;
			  
			  if (line->start != text_win[win].text)
			    zmachine_fatal("Programmer is a spoon");
			  text_win[win].text = n->start;
			  
			  text = line->start;
			  while (text != n->start)
			    {
			      if (text == NULL)
				zmachine_fatal("Programmer is a spoon");
			      nt = text->next;
			      free(text);
			      text = nt;
			    }
			}
		      
		      
		      free(line);
		      text_win[win].line = n;
		      
		      line = n;
		    }
		}
	      
	      /* Skip to the first visible line */
	      if (line != NULL)
		{
		  while (line->baseline + line->descent - scrollpos < text_win[win].winsy)
		    line = line->next;
		}
	      
	      /* Fill in to the start of the lines */
	      if (line != NULL)
		{
		  XSetForeground(x_display, x_wingc,
				 x_colour[text_win[win].winback+FIRST_ZCOLOUR].pixel);
		  if (line->baseline-line->ascent-scrollpos > text_win[win].winsy)
		    {
		      XFillRectangle(x_display, x_drawable, x_wingc,
				     BORDER_SIZE, text_win[win].winsy+BORDER_SIZE,
				     win_x, line->baseline-line->ascent-scrollpos);
		    }
		}
	      else
		lasty = text_win[win].winsy + BORDER_SIZE;
	      
	      /* Draw the lines */
	      while (line != NULL &&
		     line->baseline - line->ascent - scrollpos < text_win[win].winly)
		{
		  int x;
		  
		  for (phase=0; phase<2; phase++)
		    {
		      text = line->start;
		      width = 0;
		      offset = line->offset;
		      
		      /*
		       * Each line may span several text objects. We have to plot
		       * each one in turn.
		       */
		      for (x=0; x<line->n_chars;)
			{
			  int w;
			  int toprint;
			  
			  /* 
			   * Work out the amount of text to plot from the current 
			   * text object 
			   */
			  toprint = line->n_chars-x;
			  if (toprint > (text->len - offset))
			    toprint = text->len - offset;
			  
			  if (toprint > 0)
			    {
			      /* Plot the text */
			      if (text->text[toprint+offset-1] == 10)
				{
				  toprint--;
				  x++;
				}
			      
			      w = xfont_get_text_width(font[text->font],
						       text->text + offset,
						       toprint);
			      
			      if (phase == 0)
				{
				  XSetForeground(x_display, x_wingc,
						 x_colour[text->bg+FIRST_ZCOLOUR].pixel);
				  XFillRectangle(x_display, x_drawable, x_wingc,
						 width + BORDER_SIZE,
						 line->baseline + BORDER_SIZE - line->ascent - scrollpos,
						 w,
						 line->ascent + line->descent);
				}
			      else
				{
				  xfont_set_colours(text->fg+FIRST_ZCOLOUR, 
						    text->bg+FIRST_ZCOLOUR);
				  xfont_plot_string(font[text->font],
						    x_drawable, x_wingc,
						    width + BORDER_SIZE,
						    line->baseline + BORDER_SIZE - scrollpos,
						    text->text + offset,
						    toprint);
				}
			      
			      x      += toprint;
			      offset += toprint;
			      width  += w;
			    }
			  else
			    {
			      /* At the end of this object - move onto the next */
			      offset = 0;
			      text = text->next;
			    }
			}
		      
		      /* Fill in to the end of the line */
		      if (phase == 0)
			{
			  XSetForeground(x_display, x_wingc, x_colour[text_win[win].winback+FIRST_ZCOLOUR].pixel);
			  XFillRectangle(x_display, x_drawable, x_wingc,
					 width + BORDER_SIZE,
					 line->baseline - line->ascent + BORDER_SIZE - scrollpos,
					 win_x-width,
					 line->ascent + line->descent);
			}
		      
		      lasty = line->baseline + line->descent - scrollpos + BORDER_SIZE;
		    }
		  
		  /* Move on */
		  line = line->next;
		}
	      
	      /* Fill in to the bottom of the window */
	      XSetForeground(x_display, x_wingc, x_colour[text_win[win].winback+FIRST_ZCOLOUR].pixel);
	      if ((lasty-BORDER_SIZE) < win_y)
		{
		  XFillRectangle(x_display, x_drawable, x_wingc,
				 BORDER_SIZE,
				 lasty,
				 win_x,
				 win_y - (lasty-BORDER_SIZE));
		}
	      
	      XSetRegion(x_display, x_wingc, newregion);
	    }
	}
    }
  else
    {
      int xp, yp;

      xp = BORDER_SIZE + win_x/2-pix_w/2;
      yp = BORDER_SIZE + win_y/2-pix_h/2;

      XSetForeground(x_display, x_wingc, x_colour[3].pixel);
      XFillRectangle(x_display, x_drawable, x_wingc,
		     left, top,
		     xp-left, bottom-top);
      XFillRectangle(x_display, x_drawable, x_wingc,
		     left, top,
		     right-left, yp-top);
      XFillRectangle(x_display, x_drawable, x_wingc,
		     xp+pix_w, top,
		     right-xp-pix_w, bottom-top);
      XFillRectangle(x_display, x_drawable, x_wingc,
		     left, yp+pix_h,
		     right-left, bottom-yp-pix_h);

      XCopyArea(x_display, x_pixmap, x_drawable, x_wingc,
		0,0, pix_w, pix_h,
		xp, yp);
    }
  
  /* MORE */
  if (more_on)
    {
      clip.x = (win_x+BORDER_SIZE*2) - (morew + 2);
      clip.y = (win_y+BORDER_SIZE*2) - (moreh + 2);
      clip.width = morew+2; clip.height = moreh+2;

      XSetRegion(x_display, x_wingc, dregion);
#ifdef HAVE_XFT
      if (xft_drawable != NULL)
	XftDrawSetClip(xft_drawable, dregion);
#endif

      XSetForeground(x_display, x_wingc, x_colour[4].pixel);
      XFillRectangle(x_display, x_drawable, x_wingc,
		     clip.x, clip.y, morew+1, moreh+1);

      xfont_set_colours(0+FIRST_ZCOLOUR, 4);
      xfont_plot_string(font[style_font[2]],
			x_drawable, x_wingc,
			win_x+BORDER_SIZE*2-(morew+1), 
			win_y+BORDER_SIZE*2-(moreh) +
			xfont_get_ascent(font[style_font[2]]), 
			more, 6);

      XSetForeground(x_display, x_wingc, x_colour[6].pixel);
      XDrawLine(x_display, x_drawable, x_wingc,
		clip.x+morew+1, clip.y+moreh+1, clip.x, clip.y+moreh+1);
      XDrawLine(x_display, x_drawable, x_wingc,
		clip.x+morew+1, clip.y+moreh+1, clip.x+morew+1, clip.y);

      XSetForeground(x_display, x_wingc, x_colour[5].pixel);
      XDrawLine(x_display, x_drawable, x_wingc,
		clip.x, clip.y, clip.x+morew+1, clip.y);
      XDrawLine(x_display, x_drawable, x_wingc,
		clip.x, clip.y, clip.x, clip.y+moreh+1);
  }

  /* Free regions */
  XFree(newregion);
  XFree(dregion);
  dregion = None;

  resetregion = 1;

  /* Image test */
  if (machine.blorb != NULL)
    {
      image_data* img;
      XImage*     xim;
      XImage*     mask;
      
      img = image_load(machine.blorb_file,
		       machine.blorb->index.picture[20].file_offset,
		       machine.blorb->index.picture[20].file_len);

      if (img == NULL)
	zmachine_fatal("Unable to load image");

      image_resample(img, 3, 2);

#ifdef HAVE_XRENDER
      {
	Pixmap hum;
	Picture drum;
	XRenderPictFormat pf;
	XRenderPictFormat* format;
	GC mygc;

	pf.depth = 32;
	pf.type  = PictTypeDirect;
	
	format = XRenderFindFormat(x_display,
				   PictFormatType|PictFormatDepth,
				   &pf, 0);

	/* Verry dodgy test :-) */
	xim = image_to_ximage_render(img, x_display, DefaultVisual(x_display, 0));
	hum = XCreatePixmap(x_display, RootWindow(x_display, 0),
			    image_width(img), image_height(img),
			    format->depth);
	drum = XRenderCreatePicture(x_display, hum, format, 0, 0);

	mygc = XCreateGC(x_display, hum, 0, NULL);

	XPutImage(x_display, hum, 
		  mygc, xim, 0,0,0,0,
		  image_width(img), image_height(img));

	XRenderComposite(x_display, PictOpOver,
			 drum,
			 None,
			 x_winpic,
			 0,0,0,0,
			 0,0,
			 image_width(img), image_height(img));
      }
#else
      xim = image_to_ximage_truecolour(img,
				       x_display,
				       DefaultVisual(x_display, 0));
      mask = image_to_mask_truecolour(xim,
				      img,
				      x_display,
				      DefaultVisual(x_display, 0));
      
      XSetFunction(x_display, x_wingc, GXand);
      XPutImage(x_display, x_drawable,
		x_wingc, mask,
		0, 0, 0, 0,
		image_width(img), image_height(img));
      XSetFunction(x_display, x_wingc, GXor);
      XPutImage(x_display, x_drawable,
		x_wingc, xim,
		0, 0, 0, 0,
		image_width(img), image_height(img));
      XSetFunction(x_display, x_wingc, GXcopy);
#endif
    }

  /* Flip buffers */
#ifdef HAVE_XDBE
  if (x_backbuffer != None)
    {
      XdbeSwapInfo i;

      i.swap_window = x_mainwin;
      i.swap_action = XdbeCopied;
      XdbeSwapBuffers(x_display, &i, 1);
    }
#endif

  /* Caret */
  caret_shown = 0;
  if (!more_on)
    draw_input_text();
  draw_caret();
}

static void resize_window()
{
  int owin;
  int x,y,z;

  owin = cur_win;

  size_x = win_x/xfont_x;
  size_y = win_y/xfont_y;

  if (size_x == 0)
    size_x = 1;
  if (size_y == 0)
    size_y = 1;

  /* Resize and reformat the overlay windows */
  for (x=1; x<=2; x++)
    {
      cur_win = x;
      
      if (size_y > max_y)
	{
	  CURWIN.cline = realloc(CURWIN.cline, sizeof(struct cellline)*size_y);

	  /* Allocate new rows */
	  for (y=max_y; y<size_y; y++)
	    {
	      CURWIN.cline[y].cell = malloc(sizeof(int)*max_x);
	      CURWIN.cline[y].fg   = malloc(sizeof(char)*max_x);
	      CURWIN.cline[y].bg   = malloc(sizeof(char)*max_x);
	      CURWIN.cline[y].font = malloc(sizeof(char)*max_x);

	      for (z=0; z<max_x; z++)
		{
		  CURWIN.cline[y].cell[z] = ' ';
		  CURWIN.cline[y].fg[z]   = CURWIN.cline[max_y-1].fg[z];
		  CURWIN.cline[y].bg[z]   = CURWIN.cline[max_y-1].bg[z];
		  CURWIN.cline[y].font[z] = style_font[4];
		}
	    }
	}
      
      if (size_x > max_x)
	{
	  /* Allocate new columns */
	  for (y=0; y<(max_y>size_y?max_y:size_y); y++)
	    {
	      CURWIN.cline[y].cell = realloc(CURWIN.cline[y].cell,
					     sizeof(int)*size_x);
	      CURWIN.cline[y].fg   = realloc(CURWIN.cline[y].fg,
					     sizeof(char)*size_x);
	      CURWIN.cline[y].bg   = realloc(CURWIN.cline[y].bg,
					     sizeof(char)*size_x);
	      CURWIN.cline[y].font = realloc(CURWIN.cline[y].font,
					     sizeof(char)*size_x);
	      for (z=max_x; z<size_x; z++)
		{
		  CURWIN.cline[y].cell[z] = ' ';
		  CURWIN.cline[y].fg[z]   = CURWIN.cline[y].fg[max_x-1];
		  CURWIN.cline[y].bg[z]   = CURWIN.cline[y].bg[max_x-1];
		  CURWIN.cline[y].font[z] = style_font[4];
		}
	    }
	}
    }

  if (size_x > max_x)
    max_x = size_x;
  if (size_y > max_y)
    max_y = size_y;
  
  /* Resize and reformat the text window */
  cur_win = 0;
  
  CURWIN.winlx = win_x;
  CURWIN.winly = win_y;

  if (CURWIN.line != NULL)
    {
      struct line* line;
      struct line* next;

      CURWIN.topline = NULL;
      
      CURWIN.ypos = CURWIN.line->baseline - CURWIN.line->ascent;
      CURWIN.xpos = 0;

      line = CURWIN.line;
      while (line != NULL)
	{
	  next = line->next;
	  free(line);
	  line = next;
	}

      CURWIN.line = CURWIN.lastline = NULL;

      if (CURWIN.text != NULL)
	{
	  CURWIN.lasttext = CURWIN.text;
	  while (CURWIN.lasttext->next != NULL)
	    {
	      format_last_text(0);
	      CURWIN.lasttext = CURWIN.lasttext->next;
	    }
	  format_last_text(0);
	}
    }
  
  /* Scroll more text onto the screen if we can */
  cur_win = 0;
  if (CURWIN.lastline != NULL)
    {
      if (CURWIN.lastline->baseline+CURWIN.lastline->descent < win_y)
	{
	  /* Scroll everything down */
	  int down;
	  struct line* l;

	  down = win_y -
	    (CURWIN.lastline->baseline+CURWIN.lastline->descent);

	  l = CURWIN.line;
	  while (l != NULL)
	    {
	      l->baseline += down;

	      l = l->next;
	    }
	}

      if (CURWIN.line->baseline-CURWIN.line->ascent > start_y)
	{
	  /* Scroll everything up */
	  int up;
	  struct line* l;

	  up = (CURWIN.line->baseline-CURWIN.line->ascent) - start_y;

	  l = CURWIN.line;
	  while (l != NULL)
	    {
	      l->baseline -= up;

	      l = l->next;
	    }
	}
    }

  zmachine_resize_display(display_get_info());
  
  cur_win = owin;
}

static int process_events(long int to, int* buf, int buflen)
{
  struct timeval timeout, now;

  int connection_num;

  static int           bufsize = 0;
  static int           bufpos;
  static unsigned char keybuf[20];

  int x;
  KeySym ks;

  int exposing = 0;

  if (buf != NULL)
    {
      text_buf    = buf;
      max_buflen  = buflen;
      buf_offset  = istrlen(buf);
      history_pos = NULL;
      read_key    = -1;
    }
  else
    {
      text_buf   = NULL;
      buf_offset = 0;
      read_key   = -1;
    }


  /* Work out when the timeout occurs */
  gettimeofday(&now, NULL);
  timeout = now;
  timeout.tv_sec  += (to/1000);
  timeout.tv_usec += ((to%1000)*1000);
  timeout.tv_sec  += timeout.tv_usec/1000000;
  timeout.tv_usec %= 1000000;

  connection_num = ConnectionNumber(x_display);

  move_caret();
  show_caret();

  while (1)
    {
      XEvent ev;
      fd_set readfds;

      struct timeval tv;
      int isevent;
      int flash;

      static struct timeval next_flash = { 0, 0 };

      /* Get the current time */
      gettimeofday(&now, NULL);
      
      /* Create the selection set */
      FD_ZERO(&readfds);
      FD_SET(connection_num, &readfds);

      /* Calculate the time left to wait */
      tv = timeout;
      tv.tv_sec -= now.tv_sec;
      tv.tv_usec -= now.tv_usec;

      tv.tv_sec += tv.tv_usec/1000000;
      tv.tv_usec %= 1000000;

      if (tv.tv_usec < 0)
	{
	  tv.tv_usec += 1000000;
	  tv.tv_sec  -= 1;
	}
      
      if (tv.tv_sec < 0 && to != 0)
	return 0;

      /* Calculate the time left til we flash */
      if (next_flash.tv_sec == 0 &&
	  next_flash.tv_usec == 0)
	next_flash = now;

      if ((next_flash.tv_sec < now.tv_sec ||
	   (next_flash.tv_sec == now.tv_sec &&
	    next_flash.tv_usec <= now.tv_usec)))
	{
	  next_flash.tv_sec  = now.tv_sec;
	  next_flash.tv_usec = now.tv_usec + 400000;
	  next_flash.tv_sec  += next_flash.tv_usec/1000000;
	  next_flash.tv_usec %= 1000000;

	  caret_on = !caret_on;
	  draw_caret();
	}

      /* Timeout on flash if that's going to occur sooner */
      flash = 0;
      if (((tv.tv_sec > next_flash.tv_sec ||
	    (tv.tv_sec == next_flash.tv_sec &&
	     tv.tv_usec > next_flash.tv_usec))
	   || to == 0))
	{
	  tv.tv_sec  = next_flash.tv_sec - now.tv_sec;
	  tv.tv_usec = next_flash.tv_usec - now.tv_usec;

	  tv.tv_sec  += tv.tv_usec/1000000;
	  tv.tv_usec %= 1000000;

	  if (tv.tv_usec < 0)
	    {
	      tv.tv_usec += 1000000;
	      tv.tv_sec  -= 1;
	    }

	  flash = 1;
	}

      /* Update the display if necessary */
      if (dregion != None && 
	  exposing <= 0 &&
	  !XPending(x_display))
	{
	  draw_window();
	}

      /* Wait for something to happen */
      isevent = 0;
      if (XPending(x_display))
	isevent = 1;
      else if (select(connection_num+1, &readfds, NULL, NULL,
		      &tv))
	isevent = 1;

      if (!isevent && flash)
	continue;
	
      if (isevent)
	{
	  XNextEvent(x_display, &ev);

	  switch (ev.type)
	    {
	    case KeyPress:
	      display_set_scroll_position(0);

	      bufpos = 0;
	      bufsize = XLookupString(&ev.xkey, keybuf, 20, NULL, NULL);
	      
	      if (text_buf == NULL)
		{
		  x = 0;
		  for (ks=XKeycodeToKeysym(x_display, ev.xkey.keycode, x++);
		       ks != NoSymbol;
		       ks=XKeycodeToKeysym(x_display, ev.xkey.keycode, x++))
		    {
		      switch (ks)
			{
			case XK_Left:
			  keybuf[bufsize++] = 131;
			  goto gotkeysym;
			  
			case XK_Right:
			  keybuf[bufsize++] = 132;
			  goto gotkeysym;
			  
			case XK_Up:
			  keybuf[bufsize++] = 129;
			  goto gotkeysym;
			  
			case XK_Down:
			  keybuf[bufsize++] = 130;
			  goto gotkeysym;
			  
			case XK_Delete:
			  keybuf[bufsize++] = 8;
			  goto gotkeysym;

			case XK_F1:
			  keybuf[bufsize++] = 133;
			  goto gotkeysym;
			case XK_F2:
			  keybuf[bufsize++] = 134;
			  goto gotkeysym;
			case XK_F3:
			  keybuf[bufsize++] = 135;
			  goto gotkeysym;
			case XK_F4:
			  keybuf[bufsize++] = 136;
			  goto gotkeysym;
			case XK_F5:
			  keybuf[bufsize++] = 137;
			  goto gotkeysym;
			case XK_F6:
			  keybuf[bufsize++] = 138;
			  goto gotkeysym;
			case XK_F7:
			  keybuf[bufsize++] = 139;
			  goto gotkeysym;
			case XK_F8:
			  keybuf[bufsize++] = 140;
			  goto gotkeysym;
			case XK_F9:
			  keybuf[bufsize++] = 141;
			  goto gotkeysym;
			case XK_F10:
			  keybuf[bufsize++] = 142;
			  goto gotkeysym;
			case XK_F11:
			  keybuf[bufsize++] = 143;
			  goto gotkeysym;
			case XK_F12:
			  keybuf[bufsize++] = 144;
			  goto gotkeysym;
			}
		    }
		gotkeysym:
		  
		  if (bufsize > 0)
		    {
		      hide_caret();
		      bufsize--;
		      return keybuf[bufpos++];
		    }
		}
	      else
		{
		  int x, y;

		  x = 0;
		  for (ks=XKeycodeToKeysym(x_display, ev.xkey.keycode, x++);
		       ks != NoSymbol;
		       ks=XKeycodeToKeysym(x_display, ev.xkey.keycode, x++))
		    {
		      switch (ks)
			{
			case XK_Left:
			  if (terminating[131])
			    {
			      hide_caret();
			      return 131;
			    }
			  if (buf_offset>0)
			    buf_offset--;
			  goto gotkeysym2;

			case XK_Right:
			  if (terminating[132])
			    {
			      hide_caret();
			      return 132;
			    }
			  if (text_buf[buf_offset] != 0)
			    buf_offset++;
			  goto gotkeysym2;

			case XK_Up:
			  if (terminating[129])
			    {
			      hide_caret();
			      return 129;
			    }
			  else
			    {
			      if (history_pos == NULL)
				history_pos = last_string;
			      else
				if (history_pos->next != NULL)
				  history_pos = history_pos->next;
			      if (history_pos != NULL)
				{
				  if (istrlen(history_pos->string) < buflen)
				    istrcpy(text_buf, history_pos->string);
				  buf_offset = istrlen(text_buf);
				}
			    }
			  goto gotkeysym2;

			case XK_Down:
			  if (terminating[130])
			    {
			      hide_caret();
			      return 130;
			    }
			  if (history_pos != NULL)
			    {
			      history_pos = history_pos->last;
			      if (history_pos != NULL)
				{
				  if (istrlen(history_pos->string) < buflen)
				    istrcpy(text_buf, history_pos->string);
				  buf_offset = istrlen(text_buf);
				}
			      else
				{
				  text_buf[0] = 0;
				  buf_offset = 0;
				}
			    }
			  goto gotkeysym2;

			case XK_Home:
			  buf_offset = 0;
			  goto gotkeysym2;

			case XK_Insert:
			  insert = !insert;
			  goto gotkeysym2;

			case XK_End:
			  buf_offset = istrlen(text_buf);
			  goto gotkeysym2;

			case XK_BackSpace:
			case XK_Delete:
			  if (buf_offset == 0)
			    goto gotkeysym2;
			  
			  if (text_buf[buf_offset] == 0)
			    text_buf[--buf_offset] = 0;
			  else
			    {
			      for (y=buf_offset-1; text_buf[y] != 0; y++)
				text_buf[y] = text_buf[y+1];
			      buf_offset--;
			    }
			  goto gotkeysym2;

			case XK_Return:
			  {
			    history_item* newhist;

			    newhist = malloc(sizeof(history_item));
			    newhist->last = NULL;
			    newhist->next = last_string;
			    if (last_string)
			      last_string->last = newhist;
			    newhist->string = malloc(sizeof(int)*(istrlen(text_buf)+1));
			    istrcpy(newhist->string, text_buf);
			    last_string = newhist;
			  }
			  bufsize = 0;
			  
			  hide_caret();

			  return 10;

			case XK_F1:
			  if (terminating[133])
			    {
			      hide_caret();
			      return 133;
			    }
			  break;
			case XK_F2:
			  if (terminating[134])
			    {
			      hide_caret();
			      return 134;
			    }
			  break;
			case XK_F3:
			  if (terminating[135])
			    {
			      hide_caret();
			      return 135;
			    }
			  break;
			case XK_F4:
			  if (terminating[136])
			    {
			      hide_caret();
			      return 136;
			    }
			  break;
			case XK_F5:
			  if (terminating[137])
			    {
			      hide_caret();
			      return 137;
			    }
			  break;
			case XK_F6:
			  if (terminating[138])
			    {
			      hide_caret();
			      return 138;
			    }
			  break;
			case XK_F7:
			  if (terminating[139])
			    {
			      hide_caret();
			      return 139;
			    }
			  break;
			case XK_F8:
			  if (terminating[140])
			    {
			      hide_caret();
			      return 140;
			    }
			  break;
			case XK_F9:
			  if (terminating[141])
			    {
			      hide_caret();
			      return 141;
			    }
			  break;
			case XK_F10:
			  if (terminating[142])
			    {
			      hide_caret();
			      return 142;
			    }
			  break;
			case XK_F11:
			  if (terminating[143])
			    {
			      hide_caret();
			      return 143;
			    }
			  break;
			case XK_F12:
			  if (terminating[144])
			    {
			      hide_caret();
			      return 144;
			    }
			  break;
			}
		    }
		gotkeysym2:
		  
		  for (x=0; x<bufsize; x++)
		    {
		      if (istrlen(text_buf) >= buflen)
			break;
		      
		      if (keybuf[x]>31 && keybuf[x]<127)
			{
			  if (text_buf[buf_offset] == 0)
			    {
			      text_buf[buf_offset+1] = 0;
			      text_buf[buf_offset++] = keybuf[x];
			    }
			  else
			    {
			      if (insert)
				{
				  for (y=istrlen(text_buf)+1; y>buf_offset; y--)
				    {
				      text_buf[y] = text_buf[y-1];
				    }
				}
			      text_buf[buf_offset++] = keybuf[x];
			    }
			}
		    }
		  
		  bufsize = 0;

		  draw_input_text();
		}
	      break;

	    case ConfigureNotify:
#ifdef HAVE_XFT
	      if (xft_drawable != NULL &&
		  x_pixmap     == None)
		{
		  /*
		   * Sometimes the xft_drawable breaks when the window is 
		   * resized - in particular when we're using DBE.
		   * Recreating it fixes this... (Not necessary when
		   * using a pixmap for rendering)
		   */
		  XftDrawChange(xft_drawable, x_drawable);
		}
#endif

#ifdef HAVE_XRENDER
	      if (x_winpic != None)
		{
		  XRenderFreePicture(x_display, x_winpic);
		  x_winpic = XRenderCreatePicture(x_display, x_drawable, x_picformat, 0, NULL);
		}
#endif

	      if (ev.xconfigure.width != win_width ||
		  ev.xconfigure.height != win_height)
		{
		  win_width  = total_x = ev.xconfigure.width;
		  win_height = total_y = ev.xconfigure.height;
		  win_x      = total_x - (BORDER_SIZE*2) - SCROLLBAR_SIZE;
		  win_y      = total_y - (BORDER_SIZE*2);
		  
		  win_left   = BORDER_SIZE;
		  win_top    = BORDER_SIZE;
		  
		  /* Reformat window here */
		  resize_window();
		  move_caret();
		}
	      break;

	    case ButtonPress:
	      /* See if the click was within the scrollbar... */
	      click_x = ev.xbutton.x-win_left;
	      click_y = ev.xbutton.y-win_top;
	      
	      if (click_x >= win_x+BORDER_SIZE)
		{
		  int pos, height;

		  click_y += win_top;

		  /* Calculate the position and size of the scrollbar tab */
		  pos = (scroll_pos*total_y)/scroll_range;
		  height = (scroll_height*total_y)/scroll_range;
		  
		  if (height < 20)
		    height = 20;
		  
		  if (pos > total_y)
		    pos = total_y-10;
		  if (pos + height >= total_y)
		    {
		      pos -= (pos+height)-total_y-1;
		    }

		  if /* above */ (click_y < pos)
		    {
		      display_set_scroll_position((scroll_pos + scroll_top) - (scroll_height - xfont_y));
		    }
		  else if /* below */ (click_y > (pos+height))
		    {
		      display_set_scroll_position((scroll_pos + scroll_top) + (scroll_height - xfont_y));
		    }
		  else /* within - drag time */
		    {
		      /* Depress scrollbar */
		      scroll_state = 1;
		      invalidate_scrollbar();

		      /* Record some useful information */
		      scroll_start = scroll_pos;
		      scroll_offset = pos - click_y;
		      
		      /* Turn on motion events */
		      scrolling = 1;
		    }
		}
	      else if (terminating[254] || buf == NULL)
		{
		  return 254;
		}
	      break;

	    case ButtonRelease:
	      if (scrolling)
		{
		  scroll_state = 0;
		  scrolling = 0;
		  invalidate_scrollbar();
		}
	      break;

	    case MotionNotify:
	      if (scrolling)
		{
		  Window root, child;
		  int cx, cy;
		  unsigned int m;

		  XQueryPointer(x_display, x_mainwin, &root, &child,
				&cx, &cy,
				&click_x, &click_y,
				&m);

		  /* Only happens when we've dragged the scrollbar */
		  click_x -= win_left;
		  click_y -= win_top;
		  
		  if (click_x >= win_x+BORDER_SIZE - SCROLLBAR_SIZE && 
		      click_x <= total_x + SCROLLBAR_SIZE)
		    {
		      int pos, height, newpos;
		      XFONT_MEASURE sc;
		      
		      click_y += win_top;
		      
		      /* Calculate the position and size of the scrollbar tab */
		      pos = (scroll_pos*total_y)/scroll_range;
		      height = (scroll_height*total_y)/scroll_range;
		      
		      if (height < 20)
			height = 20;
		      
		      if (pos > total_y)
			pos = total_y-10;
		      if (pos + height >= total_y)
			{
			  pos -= (pos+height)-total_y-1;
			}
		      
		      newpos = scroll_offset + click_y;
		      sc = scroll_top + (newpos*scroll_range)/total_y;
		      
		      display_set_scroll_position(sc);
		    }
		  else
		    {
		      display_set_scroll_position(scroll_start);
		    }
		}
	      break;

	    case ClientMessage:
	      if (ev.xclient.message_type == wmprots)
		{
		  if (ev.xclient.data.l[0] == x_prot[0])
		    {
		      display_exit(0);
		    }
		}
	      break;

	    case Expose:
	      {
		XRectangle r;

		if (dregion == None)
		  dregion = XCreateRegion();
		exposing = ev.xexpose.count;

		r.x = ev.xexpose.x;
		r.y = ev.xexpose.y;
		r.width = ev.xexpose.width;
		r.height = ev.xexpose.height;
		XUnionRectWithRegion(&r, dregion, dregion);
	      }
	      break;
	    }
	}
    }

  hide_caret();
}

/* === Display functions === */

/* Debug/error functions */

void printf_debug(char* format, ...)
{
  va_list  ap;
  char     string[512];

  va_start(ap, format);
  vsprintf(string, format, ap);
  va_end(ap);

  fputs(string, stderr);
}

void printf_error(char* format, ...)
{
  va_list  ap;
  char     string[512];

  va_start(ap, format);
  vsprintf(string, format, ap);
  va_end(ap);

  fputs(string, stderr);
}
  
void printf_info(char* format, ...)
{
  va_list  ap;
  char     string[512];

  va_start(ap, format);
  vsprintf(string, format, ap);
  va_end(ap);

  fputs(string, stdout);
}

void printf_info_done(void) { }
void printf_error_done(void) { }

/* Output functions */

int display_check_char(int chr)
{
  return 1;
}

/* Input functions */

int display_readline(int* buf, int buflen, long int timeout)
{
  int result;

  displayed_text = 0;
  result = process_events(timeout, buf, buflen);
  display_prints(buf);
  display_printc(10);

  return result;
}

int display_readchar(long int timeout)
{
  int result;

  displayed_text = 0;
  result = process_events(timeout, NULL, 0);

  return result;
}

/* Display window management functions */

void display_update(void)
{
  display_update_region(0, 0, win_x, win_y);
}

void display_update_region(XFONT_MEASURE left,
			   XFONT_MEASURE top,
			   XFONT_MEASURE right,
			   XFONT_MEASURE bottom)
{
  XRectangle clip;

  if (dregion == None)
    dregion = XCreateRegion();

  clip.x = left + BORDER_SIZE; clip.y = top + BORDER_SIZE;
  clip.width = right - left; clip.height = bottom - top;
  XUnionRectWithRegion(&clip, dregion, dregion);
}

void display_set_scroll_range(XFONT_MEASURE top,
			      XFONT_MEASURE bottom)
{
  if (scroll_range == bottom-top && scroll_top == top)
    return;

  scroll_range = bottom-top;
  if (top != scroll_top)
    {
      scroll_pos += (scroll_top - top);
    }
  scroll_top = top;
  
  invalidate_scrollbar();
}

void display_set_scroll_region(XFONT_MEASURE size)
{
  if (scroll_height == size)
    return;

  scroll_height = size;

  invalidate_scrollbar();
}

void display_set_scroll_position(XFONT_MEASURE pos)
{
  int oldpos;

  if (scroll_height > scroll_range)
    return;

  oldpos = scroll_pos;
  scroll_pos = pos - scroll_top;

  if (scroll_pos+scroll_height > scroll_range)
    {
      scroll_pos = scroll_range - scroll_height;
    }
  if (scroll_pos < 0)
    scroll_pos = 0;

  if (scroll_pos == oldpos)
    return;

  invalidate_scrollbar();

  scrollpos = scroll_pos + scroll_top;
  display_update();
}

void display_set_title(const char* title)
{
  XTextProperty tprop;
  char *t;

  t = malloc(sizeof(char)*300);
  sprintf(t, "Zoom " VERSION " - %s", title);
    
  XStringListToTextProperty(&t, 1, &tprop);
  XSetWMName(x_display, x_mainwin, &tprop);
  XFree(tprop.value);

  free(t);
}

void display_terminating(unsigned char* table)
{
  int x;

  for (x=0; x<256; x++)
    terminating[x] = 0;

  if (table != NULL)
    {
      for (x=0; table[x] != 0; x++)
	{
	  terminating[table[x]] = 1;

	  if (table[x] == 255)
	    {
	      int y;

	      for (y=129; y<=154; y++)
		terminating[y] = 1;
	      for (y=252; y<255; y++)
		terminating[y] = 1;
	    }
	}
    }
}

int display_get_mouse_x(void)
{
  return click_x/xfont_x;
}

int display_get_mouse_y(void)
{
  return click_y/xfont_y;
}

void display_set_more(int window, int more)
{
}

void display_beep(void)
{
}

void display_set_scroll(int scroll)
{
}

/* Initialisation */

void display_initialise(void)
{
  XSetWindowAttributes win_attr;
  XWindowAttributes    attr;
  rc_font*             fonts;
  rc_colour*           cols;
  int                  num;
  
  int x,y;

  x_display = XOpenDisplay(NULL);
  x_screen  = DefaultScreen(x_display);

  fonts = rc_get_fonts(&num);
  n_fonts = 0;

  /* Start up the font system */
  xfont_initialise();
  
  win_attr.event_mask = ExposureMask|KeyPressMask|KeyReleaseMask|StructureNotifyMask|ButtonPressMask|ButtonReleaseMask|ButtonMotionMask;
  win_attr.background_pixel = None;

  /* Create the main window */
  x_mainwin = XCreateWindow(x_display,
			    RootWindow(x_display, x_screen),
			    100,100, 
			    total_x= ((win_x=(xfont_x*rc_get_xsize())) + BORDER_SIZE*2+SCROLLBAR_SIZE),
			    total_y=((win_y=(xfont_y*rc_get_ysize())) + BORDER_SIZE*2),
			    1, DefaultDepth(x_display, x_screen), InputOutput,
			    CopyFromParent,
			    CWEventMask|CWBackPixel,
			    &win_attr);

  /* Give it a back buffer, if the extension is available */
  x_drawable = x_mainwin;

#ifdef HAVE_XDBE
  x_backbuffer = None;
  if (XdbeQueryExtension(x_display, &x, &y))
    {
      if (x >= 1)
	{
	  x_backbuffer = XdbeAllocateBackBufferName(x_display, 
						    x_mainwin,
						    XdbeCopied);
	}
      if (x_backbuffer != None)
	x_drawable = x_backbuffer;
    }
#endif

#ifdef HAVE_XRENDER
  if (XRenderQueryExtension(x_display, &x, &y))
    {
      x_picformat = XRenderFindVisualFormat(x_display, DefaultVisual(x_display, DefaultScreen(x_display)));
      if (x_picformat != NULL)
	{
	  x_winpic = XRenderCreatePicture(x_display, x_drawable, x_picformat, 0, NULL);
	}
    }
#endif

#ifdef HAVE_XFT
  if (XftDefaultHasRender(x_display))
    {
      xft_drawable = XftDrawCreate(x_display, x_drawable,
				   DefaultVisual(x_display, x_screen), 
				   DefaultColormap(x_display, x_screen));

      if (x_drawable != x_mainwin)
	{
	  /* 
	   * Create a drawable on the main window (used for drawing the input 
	   * text)
	   */
	  xft_maindraw = XftDrawCreate(x_display, x_mainwin,
				       DefaultVisual(x_display, x_screen), 
				       DefaultColormap(x_display, x_screen));
	}
    }
  else
    {
      xft_drawable = NULL;
    }
#endif

  /* Allocate fonts */
  for (x=0; x<num; x++)
    {
      if (fonts[x].num <= 0)
	zmachine_fatal("Font numbers must be positive integers");
      if (fonts[x].num > n_fonts)
	{
	  n_fonts = fonts[x].num;
	  font = realloc(font, sizeof(xfont*)*n_fonts);
	}

      font[fonts[x].num-1] = xfont_load_font(fonts[x].name);

      for (y=0; y<fonts[x].n_attr; y++)
	{
	  style_font[fonts[x].attributes[y]] = fonts[x].num-1;
	}
    }
  
  for (y=0; y<16; y++)
    {
      if (style_font[y] == -1)
	{
	  style_font[y] = style_font[8];
	}
    }
    
  xfont_x = xfont_get_width(font[3]);
  xfont_y = xfont_get_height(font[3]);;

  cols = rc_get_colours(&num);
  if (num > 11)
    {
      num = 11;
      zmachine_warning("Maximum of 11 colours");
    }
  if (num < 8)
    zmachine_warning("Supplied colourmap doesn't defined all 8 'standard' colours");

  for (x=0; x<num; x++)
    {
      x_colour[x+FIRST_ZCOLOUR].red   = cols[x].r<<8;
      x_colour[x+FIRST_ZCOLOUR].green = cols[x].g<<8;
      x_colour[x+FIRST_ZCOLOUR].blue  = cols[x].b<<8;
    }

  /* Size the window */
  max_x = size_x = rc_get_xsize();
  max_y = size_y = rc_get_ysize();
  size_window();
  
  /* Show the window */
  XMapWindow(x_display, x_mainwin);

  /* Window properties */
  {
    XTextProperty tprop;
    XSizeHints*   hints;
    XWMHints*     wmhints;
    char*         title = "Zoom " VERSION;
    char*         icon  = "Zoom";
    
    XStringListToTextProperty(&title, 1, &tprop);
    XSetWMName(x_display, x_mainwin, &tprop);
    XFree(tprop.value);
    
    XStringListToTextProperty(&icon, 1, &tprop);
    XSetWMIconName(x_display, x_mainwin, &tprop);
    XFree(tprop.value);

    hints = XAllocSizeHints();
    hints->min_width  = 200;
    hints->min_height = 100;
    hints->width      = total_x;
    hints->height     = total_y;
    hints->width_inc  = 2;
    hints->height_inc = 2;
    hints->flags      = PSize|PMinSize|PResizeInc;

    XSetWMNormalHints(x_display, x_mainwin, hints);
    XFree(hints);

    wmhints = XAllocWMHints();
    wmhints->input = True;
    wmhints->flags = InputHint;
    
    XSetWMHints(x_display, x_mainwin, wmhints);
    XFree(wmhints);

    x_prot[0] = XInternAtom(x_display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(x_display, x_mainwin, x_prot, 1);
    wmprots = XInternAtom(x_display, "WM_PROTOCOLS", False);
  }
  
  /* Allocate colours */
  XGetWindowAttributes(x_display, x_mainwin, &attr);
  for (x=0; x<N_COLS; x++)
    {
      if (!XAllocColor(x_display,
		       DefaultColormap(x_display, x_screen),
		       &x_colour[x]))
	{
	  fprintf(stderr, "Warning: couldn't allocate colour #%i\n", x);
	  x_colour[x].pixel = BlackPixel(x_display, x_screen);
	}
    }

#ifdef HAVE_XFT
  if (XftDefaultHasRender(x_display) && xft_drawable != NULL)
    {
      alloc_xft_colours();
    }
#endif

  /* Create the display pixmap */
  x_wingc   = XCreateGC(x_display, x_drawable, 0, NULL);
  x_caretgc = XCreateGC(x_display, x_mainwin, 0, NULL);

  XSetForeground(x_display, x_caretgc,
		 x_colour[FIRST_ZCOLOUR+DEFAULT_FORE].pixel);
  XSetFunction(x_display, x_caretgc, GXxor);
  XSetLineAttributes(x_display, x_caretgc, 2, LineSolid, CapButt, JoinBevel);
  
  display_clear();
}

void display_reinitialise(void)
{
  rc_font*    fonts;
  rc_colour*  cols;
  int         num,x,y;

  /* Deallocate resources */
  for (x=0; x<n_fonts; x++)
    {
      xfont_release_font(font[x]);
    }
  for (x=0; x<N_COLS; x++)
    {
      XFreeColors(x_display, DefaultColormap(x_display, x_screen),
		  &x_colour[x].pixel, 1, 0);
    }

  xfont_shutdown();

  /* Reallocate fonts */
  xfont_initialise();
  
  fonts = rc_get_fonts(&num);
  n_fonts = 0;

  for (x=0; x<num; x++)
    {
      if (fonts[x].num <= 0)
	zmachine_fatal("Font numbers must be positive integers");
      if (fonts[x].num > n_fonts)
	{
	  n_fonts = fonts[x].num;
	  font = realloc(font, sizeof(xfont*)*n_fonts);
	}

      font[fonts[x].num-1] = xfont_load_font(fonts[x].name);

      for (y=0; y<fonts[x].n_attr; y++)
	{
	  style_font[fonts[x].attributes[y]] = fonts[x].num-1;
	}
    }
  
  for (y=0; y<16; y++)
    {
      if (style_font[y] == -1)
	{
	  style_font[y] = style_font[8];
	}
    }
	  
  xfont_x = xfont_get_width(font[3]);
  xfont_y = xfont_get_height(font[3]);

  max_x = size_x = rc_get_xsize();
  max_y = size_y = rc_get_ysize();

  /* Reallocate colours */
  cols = rc_get_colours(&num);
  if (num > 11)
    {
      num = 11;
      zmachine_warning("Maximum of 11 colours");
    }

  for (x=0; x<num; x++)
    {
      x_colour[x+FIRST_ZCOLOUR].red   = cols[x].r<<8;
      x_colour[x+FIRST_ZCOLOUR].green = cols[x].g<<8;
      x_colour[x+FIRST_ZCOLOUR].blue  = cols[x].b<<8;
    }
  for (x=0; x<N_COLS; x++)
    {
      if (!XAllocColor(x_display,
		       DefaultColormap(x_display, x_screen),
		       &x_colour[x]))
	{
	  fprintf(stderr, "Warning: couldn't allocate colour #%i\n", x);
	  x_colour[x].pixel = BlackPixel(x_display, x_screen);
	}
    }
  
  size_window();

  display_clear();
}

void display_finalise(void)
{
  /* Shut everything down */
  XDestroyWindow(x_display, x_mainwin);
  XCloseDisplay(x_display);
}

extern int zoom_main(int, char**);

int main(int argc, char** argv)
{
  /* Start everything rolling */
  return zoom_main(argc, argv);
}

void display_exit(int code)
{
  /* Die */
  exit(code);
}

ZDisplay* display_get_info(void)
{
  static ZDisplay dis;

  /* Return display capabilities */

  dis.status_line   = 1;
  dis.can_split     = 1;
  dis.variable_font = 1;
  dis.colours       = 1;
  dis.boldface      = 1;
  dis.italic        = 1;
  dis.fixed_space   = 1;
  dis.sound_effects = 0;
  dis.timed_input   = 1;
  dis.mouse         = 0;
  
  dis.lines         = size_y;
  dis.columns       = size_x;
  dis.width         = size_x;
  dis.height        = size_y;
  dis.font_width    = 1;
  dis.font_height   = 1;
  dis.pictures      = 0;
  dis.fore          = DEFAULT_FORE;
  dis.back          = DEFAULT_BACK;

  return &dis;
}

/***                           ----// 888 \\----                           ***/
/* Pixmap display */

static int pix_fore;
static int pix_back;

int display_init_pixmap(int width, int height)
{
  if (x_pixmap != None)
    {
      zmachine_fatal("Can't initialise a pixmap display twice in succession");
      return 0;
    }

  if (width < 0)
    {
      width = win_x; height = win_y;
    }
  pix_w = width; pix_h = height;
  x_pixmap = XCreatePixmap(x_display, x_drawable,
			   width, height,
			   DefaultDepth(x_display, x_screen));
  if (x_pixmap == None)
    return 0;

  x_pixgc = XCreateGC(x_display, x_pixmap, 0, NULL);

  XSetForeground(x_display, x_pixgc, x_colour[4].pixel);
  XFillRectangle(x_display, x_pixmap, x_pixgc, 0,0, width, height);

  XResizeWindow(x_display, x_mainwin,
		width+BORDER_SIZE*2+SCROLLBAR_SIZE,
		height+BORDER_SIZE*2);

#ifdef HAVE_XRENDER
  if (x_picformat != NULL)
    x_pixpic = XRenderCreatePicture(x_display, x_pixmap, x_picformat, 0, NULL);
#endif

#ifdef HAVE_XFT
  if (xft_drawable != NULL)
    {
      XftDrawChange(xft_drawable, x_pixmap);
    }
#endif

  return 1;
}

void display_pixmap_cols(int fore, int back)
{
  pix_fore = fore + FIRST_ZCOLOUR;
  pix_back = back + FIRST_ZCOLOUR;
  if (back == -1)
    pix_back = -1;
}

void display_plot_gtext(int* text,
			int  len,
			int  style,
			int  x,
			int  y)
{
  int fg, bg;
  int ft;

  fg = pix_fore; bg = pix_back;
  if (style&1)
    { fg = pix_back; bg = pix_fore; }
  if (fg < 0)
    fg = 0;

  ft = style_font[(style>>1)&15];

  xfont_set_colours(fg, bg);
  if (bg >= 0)
    {
      XSetForeground(x_display, x_pixgc,
		     x_colour[bg].pixel);
      XFillRectangle(x_display, x_pixmap, x_pixgc,
		     x, y-xfont_get_ascent(font[ft]),
		     xfont_get_text_width(font[ft],
					  text, len),
		     xfont_get_height(font[ft]));
    }
  xfont_plot_string(font[ft], x_pixmap, x_pixgc,
		    x, y,
		    text, len);
}

#endif
