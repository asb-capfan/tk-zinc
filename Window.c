/*
 * Window.c -- Implementation of Window item.
 *
 * Authors		: Patrick LECOANET
 * Creation date	: Fri May 12 11:25:53 2000
 */

/*
 *  Copyright (c) 1993 - 2000 CENA, Patrick Lecoanet --
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
#include "Types.h"
#include "WidgetInfo.h"


static const char rcsid[] = "$Id: Window.c,v 1.13 2004/03/03 10:16:24 lecoanet Exp $";
static const char compile_id[] = "$Compile: " __FILE__ " " __DATE__ " " __TIME__ " $";

/*
 **********************************************************************************
 *
 * Specific Window item record
 *
 **********************************************************************************
 */
typedef struct _WindowItemStruct {
  ZnItemStruct	header;

  /* Public data */
  ZnPoint	pos;
  Tk_Anchor	anchor;
  Tk_Anchor	connection_anchor;
  Tk_Window	win;
  int		width;
  int		height;
  
  /* Private data */
  ZnPoint	pos_dev;
  int		real_width;
  int		real_height;
} WindowItemStruct, *WindowItem;


static ZnAttrConfig	wind_attrs[] = {
  { ZN_CONFIG_ANCHOR, "-anchor", NULL,
    Tk_Offset(WindowItemStruct, anchor), 0, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_BOOL, "-composealpha", NULL,
    Tk_Offset(WindowItemStruct, header.flags), ZN_COMPOSE_ALPHA_BIT,
    ZN_DRAW_FLAG, False },
  { ZN_CONFIG_BOOL, "-composerotation", NULL,
    Tk_Offset(WindowItemStruct, header.flags), ZN_COMPOSE_ROTATION_BIT,
    ZN_COORDS_FLAG, False },
  { ZN_CONFIG_BOOL, "-composescale", NULL,
    Tk_Offset(WindowItemStruct, header.flags), ZN_COMPOSE_SCALE_BIT,
    ZN_COORDS_FLAG, False },
  { ZN_CONFIG_ITEM, "-connecteditem", NULL,
    Tk_Offset(WindowItemStruct, header.connected_item), 0,
    ZN_COORDS_FLAG|ZN_ITEM_FLAG, False },
  { ZN_CONFIG_ANCHOR, "-connectionanchor", NULL,
    Tk_Offset(WindowItemStruct, connection_anchor), 0, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_INT, "-height", NULL,
    Tk_Offset(WindowItemStruct, height), 0, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_POINT, "-position", NULL, Tk_Offset(WindowItemStruct, pos), 0,
    ZN_COORDS_FLAG, False},
  { ZN_CONFIG_PRI, "-priority", NULL,
    Tk_Offset(WindowItemStruct, header.priority), 0,
    ZN_DRAW_FLAG|ZN_REPICK_FLAG, False },
  { ZN_CONFIG_BOOL, "-sensitive", NULL,
    Tk_Offset(WindowItemStruct, header.flags), ZN_SENSITIVE_BIT,
    ZN_REPICK_FLAG, False },
  { ZN_CONFIG_TAG_LIST, "-tags", NULL,
    Tk_Offset(WindowItemStruct, header.tags), 0, 0, False },
  { ZN_CONFIG_BOOL, "-visible", NULL,
    Tk_Offset(WindowItemStruct, header.flags), ZN_VISIBLE_BIT,
    ZN_DRAW_FLAG|ZN_REPICK_FLAG|ZN_VIS_FLAG, False },
  { ZN_CONFIG_INT, "-width", NULL,
    Tk_Offset(WindowItemStruct, width), 0, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_WINDOW, "-window", NULL,
    Tk_Offset(WindowItemStruct, win), 0,
    ZN_COORDS_FLAG|ZN_WINDOW_FLAG, False },
  
  { ZN_CONFIG_END, NULL, NULL, 0, 0, 0, False }
};


/*
 **********************************************************************************
 *
 * WindowDeleted --
 *
 *	Do the bookeeping after a managed window deletion.
 *
 **********************************************************************************
 */
static void
WindowDeleted(ClientData	client_data,
	      XEvent		*event)
{
  WindowItem wind = (WindowItem) client_data;

  if (event->type == DestroyNotify) {
    wind->win = NULL;
  }
}


/*
 **********************************************************************************
 *
 * Window item geometry manager --
 *
 **********************************************************************************
 */

/*
 * A managed window changes requested dimensions.
 */
static void
WindowItemRequest(ClientData	client_data,
		  Tk_Window	win __unused)
{
  WindowItem wind = (WindowItem) client_data;

  ZnITEM.Invalidate((ZnItem) wind, ZN_COORDS_FLAG);
}

/*
 * A managed window turns control over
 * to another geometry manager.
 */
static void
WindowItemLostSlave(ClientData	client_data,
		    Tk_Window	win __unused)
{
  WindowItem wind = (WindowItem) client_data;
  ZnWInfo *wi = ((ZnItem) wind)->wi;
  
  Tk_DeleteEventHandler(wi->win, StructureNotifyMask, WindowDeleted,
			(ClientData) wind);
  if (wi->win != Tk_Parent(wind->win)) {
    Tk_UnmaintainGeometry(wind->win, wi->win);
  }
  Tk_UnmapWindow(wind->win);
  wind->win = NULL;
}

static Tk_GeomMgr wind_geom_type = {
    "zincwindow",		/* name */
    WindowItemRequest,		/* requestProc */
    WindowItemLostSlave,	/* lostSlaveProc */
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
  WindowItem	wind = (WindowItem) item;

  /* Init attributes */
  SET(item->flags, ZN_VISIBLE_BIT);
  SET(item->flags, ZN_SENSITIVE_BIT);
  SET(item->flags, ZN_COMPOSE_ALPHA_BIT); /* N.A */
  SET(item->flags, ZN_COMPOSE_ROTATION_BIT);
  SET(item->flags, ZN_COMPOSE_SCALE_BIT);
  item->priority = 0;

  wind->pos.x = wind->pos.y = 0.0;
  wind->width = wind->height = 0;
  wind->anchor = TK_ANCHOR_NW;
  wind->connection_anchor = TK_ANCHOR_SW;
  wind->win = NULL;
  
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
  WindowItem	wind = (WindowItem) item;

  /*
   * The same Tk widget can't be shared by to Window items.
   */
  wind->win = NULL;
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
  ZnWInfo	*wi = item->wi;
  WindowItem	wind = (WindowItem) item;

  /*
   * Unmanage the widget.
   */
  if (wind->win) {
    Tk_DeleteEventHandler(wind->win, StructureNotifyMask, WindowDeleted,
			  (ClientData) item);
    Tk_ManageGeometry(wind->win, (Tk_GeomMgr *) NULL, (ClientData) NULL);
    if (wi->win != Tk_Parent(wind->win)) {
      Tk_UnmaintainGeometry(wind->win, wi->win);
    }
    Tk_UnmapWindow(wind->win);
  }
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
  WindowItem	wind = (WindowItem) item;
  ZnWInfo	*wi = item->wi;
  ZnItem	old_connected;
  Tk_Window	old_win;
  
  old_connected = item->connected_item;
  old_win = wind->win;
  if (ZnConfigureAttributes(wi, item, item, wind_attrs, argc, argv, flags) == TCL_ERROR) {
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

  if (ISSET(*flags, ZN_WINDOW_FLAG)) {
    if (old_win != NULL) {
      Tk_DeleteEventHandler(old_win, StructureNotifyMask,
			    WindowDeleted, (ClientData) item);
      Tk_ManageGeometry(old_win, (Tk_GeomMgr *) NULL, (ClientData) NULL);
      Tk_UnmaintainGeometry(old_win, wi->win);
      Tk_UnmapWindow(old_win);
    }
    if (wind->win != NULL) {
      Tk_CreateEventHandler(wind->win, StructureNotifyMask,
			    WindowDeleted, (ClientData) item);
      Tk_ManageGeometry(wind->win, &wind_geom_type, (ClientData) item);
    }
  }
  
  if ((wind->win != NULL) &&
      ISSET(*flags, ZN_VIS_FLAG) &&
      ISCLEAR(item->flags, ZN_VISIBLE_BIT)) {
    Tk_UnmapWindow(wind->win);
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
  if (ZnQueryAttribute(item->wi, item, wind_attrs, argv[0]) == TCL_ERROR) {
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
  WindowItem	wind = (WindowItem) item;

  ZnResetBBox(&item->item_bounding_box);
  
  if (wind->win == NULL) {
    return;
  }

  wind->real_width = wind->width;
  if (wind->real_width <= 0) {
    wind->real_width = Tk_ReqWidth(wind->win);
    if (wind->real_width <= 0) {
      wind->real_width = 1;
    }
  }
  wind->real_height = wind->height;
  if (wind->real_height <= 0) {
    wind->real_height = Tk_ReqHeight(wind->win);
    if (wind->real_height <= 0) {
      wind->real_height = 1;
    }
  }

  /*
   * The connected item support anchors, this is checked by
   * configure.
   */
  if (item->connected_item != ZN_NO_ITEM) {
    item->connected_item->class->GetAnchor(item->connected_item,
					   wind->connection_anchor,
					   &wind->pos_dev);
  }
  else {
    ZnPoint pos;
    pos.x = pos.y = 0.0;
    ZnTransformPoint(wi->current_transfo, &pos, &wind->pos_dev);
  }
  
  ZnAnchor2Origin(&wind->pos_dev, (ZnReal) wind->real_width, (ZnReal) wind->real_height,
		  wind->anchor, &wind->pos_dev);
  wind->pos_dev.x = ZnNearestInt(wind->pos_dev.x);
  wind->pos_dev.y = ZnNearestInt(wind->pos_dev.y);

  /*
   * Compute the bounding box.
   */
  ZnAddPointToBBox(&item->item_bounding_box, wind->pos_dev.x, wind->pos_dev.y);
  ZnAddPointToBBox(&item->item_bounding_box, wind->pos_dev.x+wind->real_width,
		   wind->pos_dev.y+wind->real_height);
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
  WindowItem	wind = (WindowItem) item;
  ZnBBox	box;
  int		w=0, h=0;
  
  box.orig = wind->pos_dev;
  if (wind->win != NULL) {
    w = wind->real_width;
    h = wind->real_height;
  }
  box.corner.x = box.orig.x + w;
  box.corner.y = box.orig.y + h;
  
  return ZnBBoxInBBox(&box, ta->area);
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
  WindowItem	wind = (WindowItem) item;

  if (wind->win == NULL) {
    return;
  }

  /*
   * If the window is outside the visible area, unmap it.
   */
  if ((item->item_bounding_box.corner.x <= 0) ||
      (item->item_bounding_box.corner.y <= 0) ||
      (item->item_bounding_box.orig.x >= wi->width) ||
      (item->item_bounding_box.orig.y >= wi->height)) {
    if (wi->win == Tk_Parent(wind->win)) {
      Tk_UnmapWindow(wind->win);
    }
    else {
      Tk_UnmaintainGeometry(wind->win, wi->win);
    }
    return;
  }

  /*
   * Position and map the window.
   */
  if (wi->win == Tk_Parent(wind->win)) {
    if ((wind->pos_dev.x != Tk_X(wind->win)) ||
	(wind->pos_dev.y != Tk_Y(wind->win)) ||
	(wind->real_width != Tk_Width(wind->win)) ||
	(wind->real_height != Tk_Height(wind->win))) {
      Tk_MoveResizeWindow(wind->win,
			  (int) wind->pos_dev.x, (int) wind->pos_dev.y,
			  wind->real_width, wind->real_height);
    }
    Tk_MapWindow(wind->win);
  }
  else {
    Tk_MaintainGeometry(wind->win, wi->win,
			(int) wind->pos_dev.x, (int) wind->pos_dev.y,
			wind->real_width, wind->real_height);
  }
  
}


/*
 **********************************************************************************
 *
 * IsSensitive --
 *
 **********************************************************************************
 */
static ZnBool
IsSensitive(ZnItem	item __unused,
	    int		item_part __unused)
{
  /*
   * Sensitivity can't be controlled.
   */
  return True;
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
  WindowItem	wind = (WindowItem) item;
  ZnBBox	box;
  ZnReal	dist = 1e40;
  ZnPoint	*p = ps->point;

  box.orig = wind->pos_dev;
  if (wind->win != NULL) {
    box.corner.x = box.orig.x + wind->real_width;
    box.corner.y = box.orig.y + wind->real_height;
    dist = ZnRectangleToPointDist(&box, p);
    if (dist <= 0.0) {
      dist = 0.0;
    }
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
PostScript(ZnItem	item __unused,
	   ZnBool	prepass __unused)
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
  WindowItem	wind = (WindowItem) item;
  
  if (wind->win != NULL) {
    ZnOrigin2Anchor(&wind->pos_dev, (ZnReal) wind->real_width,
		    (ZnReal) wind->real_height, anchor, p);
  }
  else {
    p->x = p->y = 0.0;
  }
}


/*
 **********************************************************************************
 *
 * GetClipVertices --
 *	Get the clipping shape.
 *
 **********************************************************************************
 */
static ZnBool
GetClipVertices(ZnItem		item,
		ZnTriStrip	*tristrip)
{
  WindowItem	wind = (WindowItem) item;
  int		w=0, h=0;
  ZnPoint	*points;
  
  ZnListAssertSize(item->wi->work_pts, 2);
  if (wind->win != NULL) {
    w = wind->real_width;
    h = wind->real_height;    
  }
  points = ZnListArray(item->wi->work_pts);
  ZnTriStrip1(tristrip, points, 2, False);
  points[0] = wind->pos_dev;
  points[1].x = points[0].x + w;
  points[1].y = points[0].y + h;

  return True;
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
  WindowItem	wind = (WindowItem) item;
  
  if ((cmd == ZN_COORDS_ADD) || (cmd == ZN_COORDS_ADD_LAST) || (cmd == ZN_COORDS_REMOVE)) {
    Tcl_AppendResult(item->wi->interp,
		     " windows can't add or remove vertices", NULL);
    return TCL_ERROR;
  }
  else if ((cmd == ZN_COORDS_REPLACE) || (cmd == ZN_COORDS_REPLACE_ALL)) {
    if (*num_pts == 0) {
      Tcl_AppendResult(item->wi->interp,
		       " coords command need 1 point on windows", NULL);
      return TCL_ERROR;
    }
    wind->pos = (*pts)[0];
    ZnITEM.Invalidate(item, ZN_COORDS_FLAG);
  }
  else if ((cmd == ZN_COORDS_READ) || (cmd == ZN_COORDS_READ_ALL)) {
    *num_pts = 1;
    *pts = &wind->pos;
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
static ZnItemClassStruct WINDOW_ITEM_CLASS = {
  sizeof(WindowItemStruct),
  0,			/* num_parts */
  True,			/* has_anchors */
  "window",
  wind_attrs,
  Tk_Offset(WindowItemStruct, pos),
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
  Draw,			/* Render use the same code as Draw. */
  IsSensitive,
  Pick,
  NULL,			/* PickVertex */
  PostScript
};

ZnItemClassId ZnWindow = (ZnItemClassId) &WINDOW_ITEM_CLASS;
