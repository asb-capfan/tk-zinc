/*
 * tkZinc.h -- Header file for Tk zinc widget.
 *
 * Authors		: Patrick Lecoanet.
 * Creation date	: Mon Mar 15 14:02:03 1999
 *
 * $Id: tkZinc.h,v 1.13 2003/10/02 12:46:45 lecoanet Exp $
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
  long		id;		/* item id for searches by id */

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
