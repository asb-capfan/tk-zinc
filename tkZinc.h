/*
 * tkZinc.h -- Header file for Tk zinc widget.
 *
 * Authors		: Patrick Lecoanet.
 * Creation date	: Mon Mar 15 14:02:03 1999
 *
 * $Id: tkZinc.h,v 1.17 2004/05/10 15:55:40 lecoanet Exp $
 */

/*
 *  Copyright (c) 1993 - 1999 CENA, Patrick Lecoanet --
 *
 * This code is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This code is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this code; if not, write to the Free
 * Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 */


#ifndef _tkZinc_h
#define _tkZinc_h

#include "WidgetInfo.h"
#include "Item.h"
#include "List.h"
#include "MapInfo.h"
#include "glu.h"

typedef struct _ZnTagSearch {
  ZnWInfo	*wi;
  ZnItem	current;	/* Pointer to last item returned. */
  ZnItem	previous;	/* The item right before the current
				 * is tracked so if the current is
				 * deleted we don't have to start from the
				 * beginning. */
  ZnBool	over;		/* Non-zero means NextItem should always
				 * return NULL. */
  int		type;		/* search type */
  unsigned int	id;		/* item id for searches by id */

  Tk_Uid	tag;		/* tag expression string */
  int		tag_index;	/* current position in string scan */
  int		tag_len;	/* length of tag expression string */

  char		*rewrite_buf;	/* tag string (after removing escapes) */
  unsigned int	rewrite_buf_alloc;	/* available space for rewrites */

  struct _TagSearchExpr *expr;	/* compiled tag expression */
  ZnItem	group;
  ZnBool	recursive;
  ZnList	item_stack;
} ZnTagSearch;

/*
 * Structure used by the tesselator.
 */
typedef struct _ZnCombineData {
  ZnReal		v[2];
  struct _ZnCombineData	*next;
} ZnCombineData;

typedef struct _ZnTess {
  GLUtesselator	*tess;
  ZnCombineData	*combine_list;
  int		type;
} ZnTess;

ZnList	   ZnWorkPoints;
ZnList	   ZnWorkXPoints;
ZnList	   ZnWorkStrings;
ZnTess	   ZnTesselator;

#ifdef GL
typedef struct _ZnGLContextEntry {
  ZnGLContext	context;
  Display	*dpy;
  ZnReal	max_line_width;
  ZnReal	max_point_width;
  unsigned int	max_tex_size;
  ZnList	widgets;
#ifdef _WIN32
  PIXELFORMATDESCRIPTOR pfd;
  int		ipixel;
  HWND		hwnd;	/* Temporary storage between MakeCurrent and Release */
  HDC		hdc;
#else
  XVisualInfo	*visual; /* Should these two be managed by screen ? */
  Colormap	colormap;
#endif
  struct _ZnGLContextEntry *next;
} ZnGLContextEntry;

ZnGLContextEntry *ZnGetGLContext(Display *dpy);
ZnGLContextEntry *ZnGLMakeCurrent(Display *dpy, ZnWInfo *wi);
void ZnGLReleaseContext(ZnGLContextEntry *ce);
#endif

int ZnParseCoordList(ZnWInfo *wi, Tcl_Obj *arg, ZnPoint **pts,
		     char **controls, unsigned int *num_pts, ZnBool *old_format);
int ZnItemWithTagOrId(ZnWInfo *wi, Tcl_Obj *tag_or_id,
		      ZnItem *item, ZnTagSearch **search_var);
void ZnTagSearchDestroy(ZnTagSearch *search);
void ZnDoItem(Tcl_Interp *interp, ZnItem item, int part, Tk_Uid tag_uid);
void ZnNeedRedisplay(ZnWInfo *wi);
void ZnDamage(ZnWInfo *wi, ZnBBox *damage);
void ZnDamageAll(ZnWInfo *wi);


#endif /* _tkZinc_h */
