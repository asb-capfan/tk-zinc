/*
 * Triangles.c -- Implementation of Triangle fan/strips  item.
 *
 * Authors		: Patrick Lecoanet.
 * Creation date	: Tue Dec 11 10:52:01 2001
 *
 * $Id: Triangles.c,v 1.12 2003/06/16 14:44:01 lecoanet Exp $
 */

/*
 *  Copyright (c) 1993 - 2001 CENA, Patrick Lecoanet --
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


#include "Draw.h"
#include "Item.h"
#include "Geo.h"
#include "Types.h"
#include "WidgetInfo.h"
#include "tkZinc.h"
#include "Image.h"
#include "Color.h"

#include <ctype.h>


static const char rcsid[] = "$Id";
static const char compile_id[]="$Compile: " __FILE__ " " __DATE__ " " __TIME__ " $";


/*
 * Bit offset of flags.
 */
#define FAN_BIT		1<<0	/* Tell if the triangles are arranged in fan or strips. */


/*
 **********************************************************************************
 *
 * Specific Triangles item record
 *
 **********************************************************************************
 */
typedef struct _TrianglesItemStruct {
  ZnItemStruct	header;

  /* Public data */
  ZnList	points;
  unsigned short flags;
  ZnList	colors;
  
  /* Private data */
  ZnTriStrip	dev_points;
} TrianglesItemStruct, *TrianglesItem;


static ZnAttrConfig	tr_attrs[] = {
  { ZN_CONFIG_GRADIENT_LIST, "-colors", NULL,
    Tk_Offset(TrianglesItemStruct, colors), 0, ZN_DRAW_FLAG, False },
  { ZN_CONFIG_BOOL, "-composealpha", NULL,
    Tk_Offset(TrianglesItemStruct, header.flags), ZN_COMPOSE_ALPHA_BIT,
    ZN_DRAW_FLAG, False },
  { ZN_CONFIG_BOOL, "-composerotation", NULL,
    Tk_Offset(TrianglesItemStruct, header.flags), ZN_COMPOSE_ROTATION_BIT,
    ZN_COORDS_FLAG, False },
  { ZN_CONFIG_BOOL, "-composescale", NULL,
    Tk_Offset(TrianglesItemStruct, header.flags), ZN_COMPOSE_SCALE_BIT,
    ZN_COORDS_FLAG, False },
  { ZN_CONFIG_BOOL, "-fan", NULL,
    Tk_Offset(TrianglesItemStruct, flags), FAN_BIT, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_PRI, "-priority", NULL,
    Tk_Offset(TrianglesItemStruct, header.priority), 0,
    ZN_DRAW_FLAG|ZN_REPICK_FLAG, False },
  { ZN_CONFIG_BOOL, "-sensitive", NULL,
    Tk_Offset(TrianglesItemStruct, header.flags), ZN_SENSITIVE_BIT,
    ZN_REPICK_FLAG, False },
  { ZN_CONFIG_TAG_LIST, "-tags", NULL,
    Tk_Offset(TrianglesItemStruct, header.tags), 0, 0, False },
  { ZN_CONFIG_BOOL, "-visible", NULL,
    Tk_Offset(TrianglesItemStruct, header.flags), ZN_VISIBLE_BIT,
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
     int		*argc,
     Tcl_Obj *CONST	*args[])
{
  ZnWInfo	*wi = item->wi;
  TrianglesItem	tr = (TrianglesItem) item;
  unsigned int	num_points;
  ZnPoint	*points;
  ZnList	l;
  ZnGradient	**grads;
  
  tr->dev_points.num_strips = 0;

  /* Init attributes */
  SET(item->flags, ZN_VISIBLE_BIT);
  SET(item->flags, ZN_SENSITIVE_BIT);
  SET(item->flags, ZN_COMPOSE_ALPHA_BIT);
  SET(item->flags, ZN_COMPOSE_ROTATION_BIT);
  SET(item->flags, ZN_COMPOSE_SCALE_BIT);
  item->priority = 1;
  tr->points = NULL;

  if (*argc < 1) {
    Tcl_AppendResult(wi->interp, " triangles coords expected", NULL);
    return TCL_ERROR;
  }
  if (ZnParseCoordList(wi, (*args)[0], &points,
		       NULL, &num_points, NULL) == TCL_ERROR) {
    return TCL_ERROR;
  }
  if (num_points < 3) {
    Tcl_AppendResult(wi->interp, " malformed triangles coords, need at least 3 points", NULL);
    return TCL_ERROR;
  }

  tr->points = ZnListNew(num_points, sizeof(ZnPoint));
  l = ZnListFromArray(points, num_points, sizeof(ZnPoint));
  ZnListAppend(tr->points, l);
  ZnListFree(l);
  (*args)++;
  (*argc)--;
 
  CLEAR(tr->flags, FAN_BIT);
  tr->colors = ZnListNew(1, sizeof(ZnGradient *));
  ZnListAssertSize(tr->colors, 1);
  grads = ZnListArray(tr->colors);
  *grads = ZnGetGradientByValue(wi->fore_color);
  
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
  TrianglesItem	tr = (TrianglesItem) item;

  if (tr->colors) {
    int		i, num_grads;
    ZnGradient	**grads;

    tr->colors = ZnListDuplicate(tr->colors);
    num_grads = ZnListSize(tr->colors);
    grads = ZnListArray(tr->colors);
    for (i = 0; i < num_grads; i++, grads++) {
      *grads = ZnGetGradientByValue(*grads);
    }
  }

  tr->dev_points.num_strips = 0;
  tr->points = ZnListDuplicate(tr->points);
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
  TrianglesItem	tr = (TrianglesItem) item;

  ZnListFree(tr->points);
  if (tr->dev_points.num_strips) {
    ZnFree(tr->dev_points.strips->points);
  }
  if (tr->colors) {
    int		i, num_grads;
    ZnGradient	**grads;

    num_grads = ZnListSize(tr->colors);
    grads = ZnListArray(tr->colors);
    for (i = 0; i < num_grads; i++, grads++) {
      ZnFreeGradient(*grads);
    }
    ZnListFree(tr->colors);
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
  int		status = TCL_OK;
  
  status = ZnConfigureAttributes(item->wi, item, tr_attrs, argc, argv, flags);

  return status;
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
  if (ZnQueryAttribute(item->wi, item, tr_attrs, argv[0]) == TCL_ERROR) {
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
  TrianglesItem	tr = (TrianglesItem) item;
  ZnPoint	*points;
  ZnPoint	*dev_points;
  unsigned int	num_points;
  
  ZnResetBBox(&item->item_bounding_box);

  points = (ZnPoint *) ZnListArray(tr->points);
  num_points = ZnListSize(tr->points);

  /*
   * Allocate space for devices coordinates
   */
  if (tr->dev_points.num_strips == 0) {
    dev_points = ZnMalloc(num_points * sizeof(ZnPoint));
  }
  else {
    dev_points = tr->dev_points.strips->points;
    if (tr->dev_points.strips->num_points < num_points) {
      dev_points = ZnRealloc(dev_points, num_points * sizeof(ZnPoint));
    }
  }
  ZnTriStrip1(&tr->dev_points, dev_points, num_points,
	      ISSET(tr->flags, FAN_BIT));

  /*
   * Compute device coordinates.
   */
  ZnTransformPoints(wi->current_transfo, points, dev_points, num_points);

  /*
   * Compute the bounding box. 
   */
  ZnAddPointsToBBox(&item->item_bounding_box, dev_points, num_points);
  
  /*
   * Expand the bounding box by one pixel in all
   * directions to take care of rounding errors.
   */
  item->item_bounding_box.orig.x -= 1;
  item->item_bounding_box.orig.y -= 1;
  item->item_bounding_box.corner.x += 1;
  item->item_bounding_box.corner.y += 1;
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
  TrianglesItem	tr = (TrianglesItem) item;
  ZnPoint	*points;
  unsigned int	i, num_points;
  int		 result=-1, result2;
  ZnBBox	*area = ta->area;

  if (tr->dev_points.num_strips == 0) {
    return -1;
  }

  points = tr->dev_points.strips->points;
  num_points = tr->dev_points.strips->num_points;

  if (ISCLEAR(tr->flags, FAN_BIT)) {
    result = ZnPolygonInBBox(points, 3, area, NULL);
    if (result == 0) {
      return 0;
    }
    points++;
    for (i = 0; i < num_points-3; i++, points++) {
      result2 = ZnPolygonInBBox(points, 3, area, NULL);
      if (result2 != result) {
	return 0;
      }
    }
  }
  else {
    ZnPoint	tri[3];

    tri[0] = points[0];
    tri[1] = points[1];
    tri[2] = points[2];
    result = ZnPolygonInBBox(points, num_points, area, NULL);
    if (result == 0) {
      return 0;
    }
    points += 3;
    for (i = 0; i < num_points-3; i++, points++) {
      tri[1] = tri[2];
      tri[2] = *points;
      result2 = ZnPolygonInBBox(points, num_points, area, NULL);
      if (result2 != result) {
	return 0;
      }   
    }
  }

  return result;
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
  TrianglesItem	tr = (TrianglesItem) item;
  unsigned int	i, num_points, last_color_index;
  ZnPoint	*points;
  ZnGradient	**grads;
  
  if (tr->dev_points.num_strips == 0) {
    return;
  }

  points = tr->dev_points.strips->points;
  num_points = tr->dev_points.strips->num_points;

  grads = ZnListArray(tr->colors);
  last_color_index = ZnListSize(tr->colors)-1;
  XSetFillStyle(wi->dpy, wi->gc, FillSolid);  
  
  if (ISCLEAR(tr->flags, FAN_BIT)) {
    XPoint	*xpoints;
    ZnListAssertSize(wi->work_xpts, num_points);
    xpoints = ZnListArray(wi->work_xpts);
    for (i = 0; i < num_points; i++) {
      xpoints[i].x = ZnNearestInt(points[i].x);
      xpoints[i].y = ZnNearestInt(points[i].y);
    }
    for (i = 0; i < num_points-2; i++, xpoints++) {
      if (i <= last_color_index) {
	XSetForeground(wi->dpy, wi->gc, ZnGetGradientPixel(grads[i], 0.0));
      }
      XFillPolygon(wi->dpy, wi->draw_buffer, wi->gc,
		   xpoints, 3, Convex, CoordModeOrigin);
    }
  }
  else {
    XPoint	tri[3];

    tri[0].x = ZnNearestInt(points[0].x);
    tri[0].y = ZnNearestInt(points[0].y);
    tri[1].x = ZnNearestInt(points[1].x);
    tri[1].y = ZnNearestInt(points[1].y);
    tri[2].x = ZnNearestInt(points[2].x);
    tri[2].y = ZnNearestInt(points[2].y);
    points += 3;
    for (i = 0; i < num_points-2; i++, points++) {
      if (i <= last_color_index) {
	XSetForeground(wi->dpy, wi->gc, ZnGetGradientPixel(grads[i], 0.0));
      }
      XFillPolygon(wi->dpy, wi->draw_buffer, wi->gc,
		   tri, 3, Convex, CoordModeOrigin);
      tri[1] = tri[2];
      tri[2].x = ZnNearestInt(points->x);
      tri[2].y = ZnNearestInt(points->y);
    }
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
  TrianglesItem	tr = (TrianglesItem) item;
  int		i, num_points, last_color_index;
  ZnPoint	*points;
  ZnGradient	**grads;
  unsigned short alpha;
  XColor	*color;

  if (tr->dev_points.num_strips == 0) {
    return;
  }

  points = tr->dev_points.strips->points;
  num_points = tr->dev_points.strips->num_points;

  grads = ZnListArray(tr->colors);
  last_color_index = ZnListSize(tr->colors)-1;

  glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
  if (ISCLEAR(tr->flags, FAN_BIT)) {
    glBegin(GL_TRIANGLE_STRIP);
  }
  else {
    glBegin(GL_TRIANGLE_FAN);
  }

  for (i = 0; i < num_points; i++, points++) {
    if (i <= last_color_index) {
      color = ZnGetGradientColor(grads[i], 0.0, &alpha);
      alpha = ZnComposeAlpha(alpha, wi->alpha);
      glColor4us(color->red, color->green, color->blue, alpha);
    }
    glVertex2d(points->x, points->y);
  }
  glEnd();
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
  TrianglesItem	tr = (TrianglesItem) item;
  double	dist=1.0e40, new_dist;
  ZnPoint	*points, *p = ps->point;
  int		i, num_points;

  if (tr->dev_points.num_strips == 0) {
    return dist;
  }
  
  points = tr->dev_points.strips->points;
  num_points = tr->dev_points.strips->num_points;

  if (ISCLEAR(tr->flags, FAN_BIT)) {
    for (i = 0; i < num_points-2; i++, points++) {
      new_dist = ZnPolygonToPointDist(points, 3, p);
      if (new_dist <= 0.0) {
	return 0.0;
      }
      if (new_dist < dist) {
	dist = new_dist;
      }
    }
  }
  else {
    ZnPoint	tri[3];

    tri[0] = points[0];
    tri[1] = points[1];
    tri[2] = points[2];
    for (i = 0; i < num_points-2; i++, points++) {
      new_dist = ZnPolygonToPointDist(tri, 3, p);
      if (new_dist <= 0.0) {
	return 0.0;
      }
      if (new_dist < dist) {
	dist = new_dist;
      }
      tri[1] = tri[2];
      tri[2] = *points;
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
PostScript(ZnItem		item __unused,
	   ZnPostScriptInfo	ps_info __unused)
{
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
  TrianglesItem	tr = (TrianglesItem) item;

  if (tr->dev_points.num_strips == 0) {
    tristrip->num_strips = 0;
    return True;
  }

  ZnTriStrip1(tristrip, tr->dev_points.strips->points,
	      tr->dev_points.strips->num_points,
	      tr->dev_points.strips[0].fan);
  return False;
}


/*
 **********************************************************************************
 *
 * GetContours --
 *	Get the external contour(s).
 *	Never ever call ZnPolyFree on the poly returned by GetContours.
 *
 **********************************************************************************
 */
static ZnBool
GetContours(ZnItem	item,
	   ZnPoly	*poly)
{
  TrianglesItem	tr = (TrianglesItem) item;
  ZnWInfo	*wi = item->wi;
  ZnPoint	*points;
  unsigned int	k, j, num_points;
  int		i;

  if (tr->dev_points.num_strips == 0) {
    poly->num_contours = 0;
    return True;
  }

  num_points = tr->dev_points.strips->num_points;

  if (ISCLEAR(tr->flags, FAN_BIT)) {
    ZnListAssertSize(wi->work_pts, num_points);
    points = ZnListArray(wi->work_pts);
    
    for (k = 1, j = 0; k < num_points; k += 2, j++) {
      points[j] = tr->dev_points.strips->points[k];
    }
    i = num_points - 1;
    if (num_points % 2 == 0) {
      i--;
    }
    for ( ; i >= 0; i -= 2, j++) {
      points[j] = tr->dev_points.strips->points[i];
    }
    ZnPolyContour1(poly, points, num_points, False);
  }
  else {
    ZnPolyContour1(poly, tr->dev_points.strips->points, num_points, False);
  }
  poly->contours[0].cw = !ZnTestCCW(poly->contours[0].points, poly->contours[0].num_points);
  poly->contours[0].controls = NULL;
  return False;
}


/*
 **********************************************************************************
 *
 * Coords --
 *	Return or edit the item vertices.
 *
 **********************************************************************************
 */
static int
Coords(ZnItem		item,
       int		contour __unused,
       int		index,
       int		cmd,
       ZnPoint		**pts,
       char		**controls __unused,
       unsigned int	*num_pts)
{
  TrianglesItem	tr = (TrianglesItem) item;
  unsigned int	num_points, i;
  ZnPoint	*points;

  if ((cmd == ZN_COORDS_REPLACE) || (cmd == ZN_COORDS_REPLACE_ALL)) {
    if (cmd == ZN_COORDS_REPLACE_ALL) {
      ZnList	tmp;
      if (*num_pts == 0) {
	Tcl_AppendResult(item->wi->interp,
			 " coords command need at least 3 points on triangles", NULL);
	return TCL_ERROR;
      }
      tmp = ZnListFromArray(*pts, *num_pts, sizeof(ZnPoint));
      ZnListEmpty(tr->points);
      ZnListAppend(tr->points, tmp);
      ZnListFree(tmp);
    }
    else {
      if (*num_pts == 0) {
	Tcl_AppendResult(item->wi->interp,
			 " coords command need at least 1 point on triangles", NULL);
	return TCL_ERROR;
      }
      points = ZnListArray(tr->points);
      num_points = ZnListSize(tr->points);
      if (index < 0) {
	index += num_points;
      }
      if ((index < 0) || ((unsigned int) index >= num_points)) {
      range_err:
	Tcl_AppendResult(item->wi->interp, " coord index out of range", NULL);
	return TCL_ERROR;
      }
      points[index] = (*pts)[0];
    }
    ZnITEM.Invalidate(item, ZN_COORDS_FLAG);
  }
  else if ((cmd == ZN_COORDS_READ) || (cmd == ZN_COORDS_READ_ALL)) {
    points = ZnListArray(tr->points);
    num_points = ZnListSize(tr->points);
    if (cmd == ZN_COORDS_READ_ALL) {
      *num_pts = num_points;
      *pts = points;
    }
    else {
      if (index < 0) {
	index += num_points;
      }
      if ((index < 0) || ((unsigned int)index >= num_points)) {
	goto range_err;
      }
      *num_pts = 1;
      *pts = &points[index];
    }
  }
  else if ((cmd == ZN_COORDS_ADD) || (cmd == ZN_COORDS_ADD_LAST)) {
    if (cmd == ZN_COORDS_ADD) {
      num_points = ZnListSize(tr->points);
      if (index < 0) {
	index += num_points;
      }
      if ((index < 0) || ((unsigned int)index >= num_points)) {
	goto range_err;
      }
      for (i = 0; i < *num_pts; i++, index++) {
	ZnListAdd(tr->points, &(*pts)[i], (unsigned int) index);
      }
    }
    else {
      ZnList	tmp;
      tmp = ZnListFromArray(*pts, *num_pts, sizeof(ZnPoint));
      ZnListAppend(tr->points, tmp);
      ZnListFree(tmp);
    }
    ZnITEM.Invalidate(item, ZN_COORDS_FLAG);
  }
  else if (cmd == ZN_COORDS_REMOVE) {
    if (ZnListSize(tr->points) < 4) {
      Tcl_AppendResult(item->wi->interp,
		       " triangles should keep at least 3 points", NULL);
      return TCL_ERROR;
    }
    points = ZnListArray(tr->points);
    num_points = ZnListSize(tr->points);
    if (index < 0) {
      index += num_points;
    }
    if ((index < 0) || ((unsigned int)index >= num_points)) {
      goto range_err;
    }
    ZnListDelete(tr->points, (unsigned int) index);
    ZnITEM.Invalidate(item, ZN_COORDS_FLAG);
  }
  
  return TCL_OK;
}


/*
 **********************************************************************************
 *
 * PickVertex --
 *	Return in 'vertex' the vertex closest to p and in 'o_vertex' the
 *	opposite vertex on the closest edge, if such an edge exists or -1
 *	in the other case.
 *
 **********************************************************************************
 */
static void
PickVertex(ZnItem	item,
	   ZnPoint	*p,
	   int		*contour,
	   int		*vertex,
	   int		*o_vertex)
{
  TrianglesItem	tr = (TrianglesItem) item;
  int		i, k, num_points;
  ZnPoint	*points;
  ZnReal	dist=1.0e40, new_dist, dist2;

  *contour = *vertex = *o_vertex = -1;
  
  points = tr->dev_points.strips->points;
  num_points = tr->dev_points.strips->num_points;
  for (i = 0; i < num_points; i++) {
    new_dist = hypot(points[i].x - p->x, points[i].y - p->y);
    if (new_dist < dist) {
      dist = new_dist;
      *contour = 0;
      *vertex = i;
    }
  }
  /*
   * Update the opposite vertex.
   */
  i = (*vertex+1) % num_points;
  new_dist = ZnLineToPointDist(&points[*vertex], &points[i], p);
  k = ((unsigned)(*vertex-1)) % num_points;
  dist2 = ZnLineToPointDist(&points[*vertex], &points[k], p);
  if (dist2 < new_dist) {
    *o_vertex = k;
  }
  else {
    *o_vertex = i;
  }
}


/*
 **********************************************************************************
 *
 * Exported functions struct --
 *
 **********************************************************************************
 */
static ZnItemClassStruct TRIANGLES_ITEM_CLASS = {
  sizeof(TrianglesItemStruct),
  0,			/* num_parts */
  False,		/* has_anchors */
  "triangles",
  tr_attrs,
  Init,
  Clone,
  Destroy,
  Configure,
  Query,
  NULL,
  NULL,
  GetClipVertices,
  GetContours,
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
  PickVertex,		/* PickVertex */
  PostScript
};

ZnItemClassId ZnTriangles = (ZnItemClassId) &TRIANGLES_ITEM_CLASS;
