/*
 * Icon.c -- Implementation of Icon item.
 *
 * Authors		: Patrick LECOANET
 * Creation date	: Sat Mar 25 13:53:39 1995
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


#include "Item.h"
#include "Geo.h"
#include "Draw.h"
#include "Types.h"
#include "Image.h"
#include "WidgetInfo.h"


static const char rcsid[] = "$Id: Icon.c,v 1.30 2003/06/16 14:44:53 lecoanet Exp $";
static const char compile_id[] = "$Compile: " __FILE__ " " __DATE__ " " __TIME__ " $";


/*
 **********************************************************************************
 *
 * Specific Icon item record
 *
 **********************************************************************************
 */
typedef struct _IconItemStruct {
  ZnItemStruct	header;

  /* Public data */
  ZnPoint	pos;
  ZnImage	image;
  Tk_Anchor	anchor;
  Tk_Anchor	connection_anchor;
  ZnGradient	*color; /* Used only if the image is a bitmap (in GL alpha part
			 * is always meaningful). */
  
  /* Private data */
  ZnPoint	dev[4];
} IconItemStruct, *IconItem;


static ZnAttrConfig	icon_attrs[] = {
  { ZN_CONFIG_ANCHOR, "-anchor", NULL,
    Tk_Offset(IconItemStruct, anchor), 0, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_GRADIENT, "-color", NULL,
    Tk_Offset(IconItemStruct, color), 0, ZN_DRAW_FLAG, False },
  { ZN_CONFIG_BOOL, "-composealpha", NULL,
    Tk_Offset(IconItemStruct, header.flags), ZN_COMPOSE_ALPHA_BIT,
    ZN_DRAW_FLAG, False },
  { ZN_CONFIG_BOOL, "-composerotation", NULL,
    Tk_Offset(IconItemStruct, header.flags), ZN_COMPOSE_ROTATION_BIT,
    ZN_COORDS_FLAG, False },
  { ZN_CONFIG_BOOL, "-composescale", NULL,
    Tk_Offset(IconItemStruct, header.flags), ZN_COMPOSE_SCALE_BIT,
    ZN_COORDS_FLAG, False },
  { ZN_CONFIG_ITEM, "-connecteditem", NULL,
    Tk_Offset(IconItemStruct, header.connected_item), 0,
    ZN_COORDS_FLAG|ZN_ITEM_FLAG, False },
  { ZN_CONFIG_ANCHOR, "-connectionanchor", NULL,
    Tk_Offset(IconItemStruct, connection_anchor), 0, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_IMAGE, "-image", NULL,
    Tk_Offset(IconItemStruct, image), 0, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_BITMAP, "-mask", NULL,
    Tk_Offset(IconItemStruct, image), 0, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_POINT, "-position", NULL, Tk_Offset(IconItemStruct, pos), 0,
    ZN_COORDS_FLAG, False},
  { ZN_CONFIG_PRI, "-priority", NULL,
    Tk_Offset(IconItemStruct, header.priority), 0,
    ZN_DRAW_FLAG|ZN_REPICK_FLAG, False },
  { ZN_CONFIG_BOOL, "-sensitive", NULL,
    Tk_Offset(IconItemStruct, header.flags), ZN_SENSITIVE_BIT,
    ZN_REPICK_FLAG, False },
  { ZN_CONFIG_TAG_LIST, "-tags", NULL,
    Tk_Offset(IconItemStruct, header.tags), 0, 0, False },
  { ZN_CONFIG_BOOL, "-visible", NULL,
    Tk_Offset(IconItemStruct, header.flags), ZN_VISIBLE_BIT,
    ZN_DRAW_FLAG|ZN_REPICK_FLAG|ZN_VIS_FLAG, False },
  
  { ZN_CONFIG_END, NULL, NULL, 0, 0, 0, False }
};



/*
 **********************************************************************************
 *
 * Init --
 *
 **********************************************************************************
 */
static int
Init(ZnItem		item,
     int		*argc __unused,
     Tcl_Obj *CONST	*args[] __unused)
{
  ZnWInfo	*wi = item->wi;
  IconItem	icon = (IconItem) item;

  /* Init attributes */
  SET(item->flags, ZN_VISIBLE_BIT);
  SET(item->flags, ZN_SENSITIVE_BIT);
  SET(item->flags, ZN_COMPOSE_ALPHA_BIT);
  SET(item->flags, ZN_COMPOSE_ROTATION_BIT);
  SET(item->flags, ZN_COMPOSE_SCALE_BIT);
  item->priority = 1;

  icon->pos.x = icon->pos.y = 0.0;
  icon->image = ZnUnspecifiedImage;
  icon->anchor = TK_ANCHOR_NW;
  icon->connection_anchor = TK_ANCHOR_SW;
  icon->color = ZnGetGradientByValue(wi->fore_color);
  
  return TCL_OK;
}


/*
 **********************************************************************************
 *
 * Clone --
 *
 **********************************************************************************
 */
static void
Clone(ZnItem	item)
{
  IconItem	icon = (IconItem) item;
  
  if (icon->image != ZnUnspecifiedImage) {
    icon->image = ZnGetImageByValue(icon->image);
  }
  icon->color = ZnGetGradientByValue(icon->color);
}


/*
 **********************************************************************************
 *
 * Destroy --
 *
 **********************************************************************************
 */
static void
Destroy(ZnItem	item)
{
  IconItem	icon = (IconItem) item;

  if (icon->image != ZnUnspecifiedImage) {
    ZnFreeImage(icon->image);
    icon->image = ZnUnspecifiedImage;
  }
  ZnFreeGradient(icon->color);
}


/*
 **********************************************************************************
 *
 * Configure --
 *
 **********************************************************************************
 */
static int
Configure(ZnItem	item,
	  int		argc,
	  Tcl_Obj *CONST argv[],
	  int		*flags)
{
  ZnItem	old_connected;

  old_connected = item->connected_item;
  if (ZnConfigureAttributes(item->wi, item, icon_attrs,
			    argc, argv, flags) == TCL_ERROR) {
    return TCL_ERROR;
  }  

  if (ISSET(*flags, ZN_ITEM_FLAG)) {
    /*
     * If the new connected item is not appropriate back up
     * to the old one.
     */
    if ((item->connected_item == ZN_NO_ITEM) ||
	(item->connected_item->class->has_anchors &&
	 (item->parent == item->connected_item->parent))) {
      ZnITEM.UpdateItemDependency(item, old_connected);
    }
    else {
      item->connected_item = old_connected;
    }
  }  

  return TCL_OK;
}


/*
 **********************************************************************************
 *
 * Query --
 *
 **********************************************************************************
 */
static int
Query(ZnItem		item,
      int		argc __unused,
      Tcl_Obj *CONST	argv[])
{
  if (ZnQueryAttribute(item->wi, item, icon_attrs, argv[0]) == TCL_ERROR) {
    return TCL_ERROR;
  }  

  return TCL_OK;
}


/*
 **********************************************************************************
 *
 * ComputeCoordinates --
 *
 **********************************************************************************
 */
static void
ComputeCoordinates(ZnItem	item,
		   ZnBool	force __unused)
{
  ZnWInfo	*wi = item->wi;
  IconItem	icon = (IconItem) item;
  int		width, height;
  
  ZnResetBBox(&item->item_bounding_box);

  /*
   * If there is no image then nothing to show.
   */
  if (icon->image == ZnUnspecifiedImage) {
    return;
  }
    
  if (icon->image != ZnUnspecifiedImage) {
    ZnSizeOfImage(icon->image, &width, &height);
  }

  if (wi->render) {
    ZnPoint	pos, quad[4];
    int		i;

    /*
     * The connected item support anchors, this is checked by
     * configure.
     */
    if (item->connected_item != ZN_NO_ITEM) {
      ZnTransfo t;
      
      item->connected_item->class->GetAnchor(item->connected_item,
					     icon->connection_anchor, quad);
      ZnTransfoInvert(wi->current_transfo, &t);
      ZnTransformPoint(&t, quad, &pos);
    }
    else {
      pos = icon->pos;
    }
    ZnAnchor2Origin(&pos, (ZnReal) width, (ZnReal) height, icon->anchor, quad);
    quad[1].x = quad[0].x;
    quad[1].y = quad[0].y + height;
    quad[2].x = quad[0].x + width;
    quad[2].y = quad[1].y;
    quad[3].x = quad[2].x;
    quad[3].y = quad[0].y;
    ZnTransformPoints(wi->current_transfo, quad, icon->dev, 4);
    
    for (i = 0; i < 4; i++) {
      icon->dev[i].x = ZnNearestInt(icon->dev[i].x);
      icon->dev[i].y = ZnNearestInt(icon->dev[i].y);
    }

    /*
     * Compute the bounding box.
     */
    ZnAddPointsToBBox(&item->item_bounding_box, icon->dev, 4);
  }
  else {
    if (item->connected_item != ZN_NO_ITEM) {
      item->connected_item->class->GetAnchor(item->connected_item,
					     icon->connection_anchor,
					     icon->dev);
    }
    else {
      ZnTransformPoint(wi->current_transfo, &icon->pos, icon->dev);
    }
    
    ZnAnchor2Origin(icon->dev, (ZnReal) width, (ZnReal) height, icon->anchor, icon->dev);
    icon->dev->x = ZnNearestInt(icon->dev->x);
    icon->dev->y = ZnNearestInt(icon->dev->y);
    
    /*
     * Compute the bounding box.
     */
    ZnAddPointToBBox(&item->item_bounding_box, icon->dev->x, icon->dev->y);
    ZnAddPointToBBox(&item->item_bounding_box, icon->dev->x+width,
		     icon->dev->y+height);
  }

  item->item_bounding_box.orig.x -= 1.0;
  item->item_bounding_box.orig.y -= 1.0;
  item->item_bounding_box.corner.x += 1.0;
  item->item_bounding_box.corner.y += 1.0;

  /*
   * Update connected items.
   */
  SET(item->flags, ZN_UPDATE_DEPENDENT_BIT);
}


/*
 **********************************************************************************
 *
 * ToArea --
 *	Tell if the object is entirely outside (-1),
 *	entirely inside (1) or in between (0).
 *
 **********************************************************************************
 */
static int
ToArea(ZnItem	item,
       ZnToArea	ta)
{
  IconItem	icon = (IconItem) item;
  ZnBBox	box, *area = ta->area;
  
  if (icon->image == ZnUnspecifiedImage) {
    return -1;
  }
  if (item->wi->render) {
    return ZnPolygonInBBox(icon->dev, 4, ta->area, NULL);
  }
  else {
    int	w, h;
   
    box.orig = *icon->dev;
    ZnSizeOfImage(icon->image, &w, &h);
    box.corner.x = box.orig.x + w;
    box.corner.y = box.orig.y + h;
    
    return ZnBBoxInBBox(&box, area);
  }
}


/*
 **********************************************************************************
 *
 * Draw --
 *
 **********************************************************************************
 */
static void
Draw(ZnItem	item)
{
  ZnWInfo	*wi = item->wi;
  IconItem	icon = (IconItem) item;
  XGCValues  	values;
  unsigned int	gc_mask = 0;
  int		w, h;
  ZnBBox	box, inter, *clip_box;
  TkRegion	clip_region, photo_region, clip;
  ZnBool	simple;
  Pixmap	pixmap;
  
  if (icon->image == ZnUnspecifiedImage) {
    return;
  }

  ZnSizeOfImage(icon->image, &w, &h);
  box.orig = *icon->dev;
  box.corner.x = icon->dev->x + w;
  box.corner.y = icon->dev->y + h;
  if (!ZnImageIsBitmap(icon->image)) {
    /*
     * The code below does not use of Tk_RedrawImage to be
     * able to clip with the current clip region.
     */
    ZnIntersectBBox(&box, &wi->damaged_area, &inter);
    box = inter;
    ZnCurrentClip(wi, &clip_region, NULL, &simple);
    pixmap = ZnImagePixmap(icon->image);
    photo_region = ZnImageRegion(icon->image);
    clip = TkCreateRegion();
    /*
     * ZnImageRegion may fail: perl/Tk 800.24 doesn't support
     * some internal TkPhoto functions.
     * This is a workaround using a rectangular region based
     * on the image size.
     */
    if (photo_region == NULL) {
      XRectangle rect;
      rect.x = rect.y = 0;
      rect.width = w;
      rect.height = h;
      TkUnionRectWithRegion(&rect, clip, clip);
    }
    else {
      ZnUnionRegion(clip, photo_region, clip);
    }
    ZnOffsetRegion(clip, (int) icon->dev->x, (int) icon->dev->y);
    TkIntersectRegion(clip_region, clip, clip);
    TkSetRegion(wi->dpy, wi->gc, clip);
    XCopyArea(wi->dpy, pixmap, wi->draw_buffer, wi->gc,
	      (int) (box.orig.x-icon->dev->x),
	      (int) (box.orig.y-icon->dev->y),
	      (unsigned int) (box.corner.x-box.orig.x),
	      (unsigned int) (box.corner.y-box.orig.y),
	      (int) box.orig.x,
	      (int) box.orig.y);
    values.clip_x_origin = values.clip_y_origin = 0;
    XChangeGC(wi->dpy, wi->gc, GCClipXOrigin|GCClipYOrigin, &values);
    TkSetRegion(wi->dpy, wi->gc, clip_region);
    TkDestroyRegion(clip);
  }
  else {
    pixmap = ZnImagePixmap(icon->image);
    ZnCurrentClip(wi, NULL, &clip_box, &simple);
    if (simple) {
      ZnIntersectBBox(&box, clip_box, &inter);
      box = inter;
    }
    values.fill_style = FillStippled;
    values.stipple = pixmap;
    values.ts_x_origin = (int) icon->dev->x;
    values.ts_y_origin = (int) icon->dev->y;
    values.foreground = ZnGetGradientPixel(icon->color, 0.0);
    gc_mask |= GCFillStyle | GCStipple | GCTileStipXOrigin | GCTileStipYOrigin | GCForeground;
    XChangeGC(wi->dpy, wi->gc, gc_mask, &values);
    XFillRectangle(wi->dpy, wi->draw_buffer, wi->gc,
		   (int) box.orig.x,
		   (int) box.orig.y,
		   (unsigned int) (box.corner.x-box.orig.x),
		   (unsigned int) (box.corner.y-box.orig.y));
  }
}


/*
 **********************************************************************************
 *
 * Render --
 *
 **********************************************************************************
 */
#ifdef GL
static void
Render(ZnItem	item)
{
  ZnWInfo	*wi = item->wi;
  IconItem	icon = (IconItem) item;
  
  if (icon->image != ZnUnspecifiedImage) {
    ZnRenderImage(wi, icon->image, icon->color, icon->dev,
		  ZnImageIsBitmap(icon->image));
  }
}
#else
static void
Render(ZnItem	item __unused)
{
}
#endif


/*
 **********************************************************************************
 *
 * IsSensitive --
 *
 **********************************************************************************
 */
static ZnBool
IsSensitive(ZnItem	item,
	    int		item_part __unused)
{
  return (ISSET(item->flags, ZN_SENSITIVE_BIT) &&
	  item->parent->class->IsSensitive(item->parent, ZN_NO_PART));
}


/*
 **********************************************************************************
 *
 * Pick --
 *
 **********************************************************************************
 */
static double
Pick(ZnItem	item,
     ZnPick	ps)
{
  IconItem	icon = (IconItem) item;
  ZnWInfo	*wi = item->wi;
  double	dist;
  double	off_dist = MAX(1, wi->pick_aperture+1);
  ZnPoint	*p = ps->point;

  dist = ZnRectangleToPointDist(&item->item_bounding_box, p);
  /*
   * If inside the icon rectangle, try to see if the point
   * is actually on the image or not. If it lies in an
   * area that is between pick_aperture+1 around the external
   * rectangle and the actual shape, the distance will be reported
   * as pick_aperture+1. Inside the actual shape it will be
   * reported as 0. This is a kludge, there is currently
   * no means to compute the real distance in the icon's
   * vicinity.
   */
  if (dist <= 0.0) {    
    ZnPoint	dp;
    int		x, y, w, h, stride;
    char	*bpixels;
    
    dist = 0.0;
    dp.x = p->x - icon->dev->x;
    dp.y = p->y - icon->dev->y;    
    if (icon->image != ZnUnspecifiedImage) {
      ZnSizeOfImage(icon->image, &w, &h);
      bpixels = ZnImageMask(icon->image, &stride);
      if (!bpixels) {
	/*
	 * The image has no bitmap pattern
	 * (i.e, it is rectangular and not a bitmap).
	 */
	return dist;
      }
      else if ((dp.x >= w) || (dp.y >= h)) {
	return off_dist;
      }
    }
    else {
      return dist;
    }
    /* BUG: when images can be scaled/rotated (openGL) this doesn't.
     * work. We must compute the invert transform and find the point
     * coordinate in the image space.
     */
    x = (int) dp.x;
    y = (int) dp.y;
    if (! ZnGetBitmapPixel(bpixels, stride, x, y)) {
      dist = off_dist;
    }
  }
  else if (dist < off_dist) {
    dist = off_dist;
  }

  return dist;
}


/*
 **********************************************************************************
 *
 * PostScript --
 *
 **********************************************************************************
 */
static void
PostScript(ZnItem		item __unused,
	   ZnPostScriptInfo	ps_info __unused)
{
}


/*
 **********************************************************************************
 *
 * GetAnchor --
 *
 **********************************************************************************
 */
static void
GetAnchor(ZnItem	item,
	  Tk_Anchor	anchor,
	  ZnPoint	*p)
{
  IconItem	icon = (IconItem) item;
  
  if (icon->image == ZnUnspecifiedImage) {
    *p = *icon->dev;
  }
  else {
    ZnBBox *bbox = &item->item_bounding_box;
    ZnOrigin2Anchor(&bbox->orig,
		    bbox->corner.x - bbox->orig.x,
		    bbox->corner.y - bbox->orig.y,
		    anchor, p);
  }
}


/*
 **********************************************************************************
 *
 * GetClipVertices --
 *	Get the clipping shape.
 *	Never ever call ZnTriFree on the tristrip returned by GetClipVertices.
 *
 **********************************************************************************
 */
static ZnBool
GetClipVertices(ZnItem		item,
		ZnTriStrip	*tristrip)
{
  IconItem	icon = (IconItem) item;
  int		w=0, h=0;
  ZnPoint	*points;
  
  if (item->wi->render) {
    ZnTriStrip1(tristrip, icon->dev, 4, False);
    
    return False;
  }
  else {
    ZnListAssertSize(item->wi->work_pts, 2);
    if (icon->image != ZnUnspecifiedImage) {
      ZnSizeOfImage(icon->image, &w, &h);
    }
    points = ZnListArray(item->wi->work_pts);
    ZnTriStrip1(tristrip, points, 2, False);
    points[0] = *icon->dev;
    points[1].x = points[0].x + w;
    points[1].y = points[0].y + h;

    return True;
  }
}


/*
 **********************************************************************************
 *
 * Coords --
 *	Return or edit the item origin. This doesn't take care of
 *	the possible attachment. The change will be effective at the
 *	end of the attachment.
 *
 **********************************************************************************
 */
static int
Coords(ZnItem		item,
       int		contour __unused,
       int		index __unused,
       int		cmd,
       ZnPoint		**pts,
       char		**controls __unused,
       unsigned int	*num_pts)
{
  IconItem	icon = (IconItem) item;
  
  if ((cmd == ZN_COORDS_ADD) || (cmd == ZN_COORDS_ADD_LAST) || (cmd == ZN_COORDS_REMOVE)) {
    Tcl_AppendResult(item->wi->interp,
		     " icons can't add or remove vertices", NULL);
    return TCL_ERROR;
  }
  else if ((cmd == ZN_COORDS_REPLACE) || (cmd == ZN_COORDS_REPLACE_ALL)) {
    if (*num_pts == 0) {
      Tcl_AppendResult(item->wi->interp,
		       " coords command need 1 point on icons", NULL);
      return TCL_ERROR;
    }
    icon->pos = (*pts)[0];
    ZnITEM.Invalidate(item, ZN_COORDS_FLAG);
  }
  else if ((cmd == ZN_COORDS_READ) || (cmd == ZN_COORDS_READ_ALL)) {
    *num_pts = 1;
    *pts = &icon->pos;
  }
  return TCL_OK;
}


/*
 **********************************************************************************
 *
 * Exported functions struct --
 *
 **********************************************************************************
 */
static ZnItemClassStruct ICON_ITEM_CLASS = {
  sizeof(IconItemStruct),
  0,			/* num_parts */
  True,			/* has_anchors */
  "icon",
  icon_attrs,
  Init,
  Clone,
  Destroy,
  Configure,
  Query,
  NULL,			/* GetFieldSet */
  GetAnchor,
  GetClipVertices,
  NULL,			/* GetContours */
  Coords,
  NULL,			/* InsertChars */
  NULL,			/* DeleteChars */
  NULL,			/* Cursor */
  NULL,			/* Index */
  NULL,			/* Part */
  NULL,			/* Selection */
  NULL,			/* Contour */
  ComputeCoordinates,
  ToArea,
  Draw,
  Render,
  IsSensitive,
  Pick,
  NULL,			/* PickVertex */
  PostScript
};

ZnItemClassId ZnIcon = (ZnItemClassId) &ICON_ITEM_CLASS;
