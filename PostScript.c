/*
 * PostScript.c -- Implementation of PostScript driver.
 *
 * Authors		: Patrick Lecoanet.
 * Creation date	: Tue Jan 3 13:17:17 1995
 *
 * $Id: PostScript.c,v 1.13 2003/04/16 09:49:22 lecoanet Exp $
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


/*
 **********************************************************************************
 *
 * Included files
 *
 **********************************************************************************
 */

#ifndef _WIN32

#ifndef _WIN32
#include <unistd.h>
#include <pwd.h>
#endif
#include <stdio.h>
#include <sys/types.h>
#include <time.h>

#include "Item.h"
#include "Group.h"
#include "PostScript.h"
#include "WidgetInfo.h"
#include "Geo.h"


/*
 **********************************************************************************
 *
 * Constants.
 * 
 **********************************************************************************
 */

static	const char rcsid[] = "$Id: PostScript.c,v 1.13 2003/04/16 09:49:22 lecoanet Exp $";
static const char compile_id[]="$Compile: " __FILE__ " " __DATE__ " " __TIME__ " $";


#define PROLOG_VERSION	1.0
#define PROLOG_REVISION	0

static	char	ps_prolog[] = "";


/*
 **********************************************************************************
 *
 * SetPostScriptFont --
 *
 **********************************************************************************
 */
static void
SetPostScriptFont(ZnWInfo		*wi __unused,
		  ZnPostScriptInfo	ps_info __unused,
		  XFontStruct		*fs __unused)
{
}


/*
 **********************************************************************************
 *
 * EmitPostScript --
 *
 **********************************************************************************
 */
static void
EmitPostScript(ZnWInfo	*wi,
	       FILE	*file,
	       char	*title,
	       ZnBool	landscape,
	       int	color_mode,
	       int	x_world,
	       int	y_world,
	       int	world_width,
	       int	world_height,
	       int	bbox_ox,
	       int	bbox_oy,
	       int	bbox_cx,
	       int	bbox_cy)
{
  ZnPostScriptInfo	ps_info;
  /*  double		scale;*/
  ZnBBox		damaged_area, bbox;
  ZnItem		current_item;
  struct passwd		*pwd_info;
  time_t		now;
  char			*s;
  XFontStruct		*fs;
  int			i;

  ps_info = (ZnPostScriptInfo) ZnMalloc(sizeof(ZnPostScriptStruct));
  ps_info->file = file;
  ps_info->title = title;
  ps_info->landscape = landscape;
  ps_info->color_mode = color_mode;
  ps_info->x_world = x_world;
  ps_info->y_world = y_world;
  ps_info->world_width = world_width;
  ps_info->world_height = world_height;
  ps_info->page_bbox.orig.x = bbox_ox;
  ps_info->page_bbox.orig.y = bbox_oy;
  ps_info->page_bbox.corner.x = bbox_cx;
  ps_info->page_bbox.corner.y = bbox_cy;
  ps_info->fonts = ZnListNew(8, sizeof(XFontStruct *));

  /*
   * Setup the new transform.
   */
  /*  scale = wi->scale;
  damaged_area = wi->damaged_area;
  wi->scale = ps_info->world_width /
    (ps_info->page_bbox.orig.x - ps_info->page_bbox.corner.x);
    ITEM_P.InvalidateItems(wi, ZnAny);*/

  /*
   * Emit Encapsulated PostScript Header.
   */
  fprintf(ps_info->file, "%%!PS-Adobe-3.0 EPSF-3.0\n");
  fprintf(ps_info->file, "%%%%Creator: Zn Widget\n");
  pwd_info = getpwuid(getuid());
  fprintf(ps_info->file, "%%%%For: %s\n", pwd_info ? pwd_info->pw_gecos : "Unknown");
  fprintf(ps_info->file, "%%%%Title: (%s)\n", ps_info->title);
  time(&now);
  fprintf(ps_info->file, "%%%%CreationDate: %s\n", ctime(&now));
  if (ps_info->landscape) {
    fprintf(ps_info->file, "%%%%BoundingBox: %d %d %d %d\n", 1, 1, 1, 1);
  }
  else {
    fprintf(ps_info->file, "%%%%BoundingBox: %d %d %d %d\n", 1, 1, 1, 1);
  }
  fprintf(ps_info->file, "%%%%Pages: 1\n");
  fprintf(ps_info->file, "%%%%DocumentData: Clean7Bit\n");
  fprintf(ps_info->file, "%%%%Orientation: %s\n",
	  ps_info->landscape ? "Landscape" : "Portrait");
  fprintf(ps_info->file, "%%%%LanguageLevel: 1\n");
  fprintf(ps_info->file, "%%%%DocumentNeededResources: (atend)\n");
  fprintf(ps_info->file,
	  "%%%%DocumentSuppliedResources: procset Zinc-Widget-Prolog %f %d\n",
	  PROLOG_VERSION, PROLOG_REVISION);
  fprintf(ps_info->file, "%%%%EndComments\n\n\n");

  /*
   * Emit the prolog.
   */
  fprintf(ps_info->file, "%%%%BeginProlog\n");
  fprintf(ps_info->file, "%%%%BeginResource: procset Zinc-Widget-Prolog %f %d\n",
	  PROLOG_VERSION, PROLOG_REVISION);
  fwrite(ps_prolog, 1, sizeof(ps_prolog), ps_info->file);
  fprintf(ps_info->file, "%%%%EndResource\n");
  fprintf(ps_info->file, "%%%%EndProlog\n");

  /*
   * Emit the document setup.
   */
  fprintf(ps_info->file, "%%%%BeginSetup\n");
  fprintf(ps_info->file, "%%%%EndSetup\n");

  /*
   * Emit the page setup.
   */
  fprintf(ps_info->file, "%%%%Page: 0 1\n");
  fprintf(ps_info->file, "%%%%BeginPageSetup\n");
  fprintf(ps_info->file, "%%%%EndPageSetup\n");

  /*
   * Iterate through all items emitting PostScript for each.
   */
  current_item = ZnGroupTail(wi->top_group);
  while (current_item != ZN_NO_ITEM) {
    if (ISSET(current_item->flags, ZN_VISIBLE_BIT)) {
      ZnIntersectBBox(&ps_info->page_bbox, &current_item->item_bounding_box, &bbox);
      if (!ZnIsEmptyBBox(&bbox)) {
	current_item->class->PostScript(current_item, ps_info);
      }
    }
    current_item = current_item->previous;
  }

  /*
   * Emit the page trailer.
   */
  fprintf(ps_info->file, "%%%%PageTrailer\n");

  /*
   * Emit the document trailer.
   */
  fprintf(ps_info->file, "%%%%Trailer\n");
  s = "%%DocumentNeededResources: font ";
  for (fs = (XFontStruct *) ZnListArray(ps_info->fonts),
	 i = ZnListSize(ps_info->fonts); i > 0; i--, fs++) {
    fprintf(ps_info->file, "%s", s);
    s = "%%+ font";
  }
  fprintf(ps_info->file, "%%%%EOF\n");

  /*
   * Restore the original transform.
   */
  /*wi->scale = scale;
    ITEM_P.InvalidateItems(wi, ZnAny);*/
  wi->damaged_area = damaged_area;


  ZnListFree(ps_info->fonts);
  ZnFree(ps_info);
}


/*
 **********************************************************************************
 *
 * Exported functions struct --
 *
 **********************************************************************************
 */

struct _ZnPOSTSCRIPT ZnPOSTSCRIPT = {
  EmitPostScript,
  SetPostScriptFont
};
#endif /* _WIN32 */
