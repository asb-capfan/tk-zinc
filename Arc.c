/*
 * Arc.c -- Implementation of Arc item.
 *
 * Authors		: Patrick Lecoanet.
 * Creation date	: Wed Mar 30 16:24:09 1994
 *
 * $Id: Arc.c,v 1.49 2003/10/02 07:41:59 lecoanet Exp $
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
#include "tkZinc.h"


static const char rcsid[] = "$Id: Arc.c,v 1.49 2003/10/02 07:41:59 lecoanet Exp $";
static const char compile_id[]="$Compile: " __FILE__ " " __DATE__ " " __TIME__ " $";


/*
 * Bit offset of flags.
 */
#define FILLED_BIT	1<<0	/* If the arc is filled with color/pattern */
#define CLOSED_BIT	1<<1	/* If the arc outline is closed */
#define PIE_SLICE_BIT	1<<2	/* If the arc is closed as a pie slice or a chord */

#define FIRST_END_OK	1<<3
#define LAST_END_OK	1<<4
#define USING_POLY_BIT	1<<5


static double Pick(ZnItem item, ZnPick ps);


/*
 **********************************************************************************
 *
 * Specific Arc item record.
 *
 **********************************************************************************
 */
typedef struct _ArcItemStruct {
  ZnItemStruct	header;
  
  /* Public data */
  ZnPoint	coords[2];
  int		start_angle;
  int		angle_extent;
  ZnImage	line_pattern;
  ZnGradient	*fill_color;
  ZnGradient	*line_color;
  ZnDim		line_width;
  ZnLineStyle	line_style;
  ZnLineEnd	first_end;
  ZnLineEnd	last_end;
  ZnImage	tile;
  unsigned short flags;

  /* Private data */
  ZnPoint	orig;
  ZnPoint	corner;
  ZnPoint	center1;
  ZnPoint	center2;
  ZnList	render_shape;
  ZnPoint	*grad_geo;
} ArcItemStruct, *ArcItem;


static ZnAttrConfig	arc_attrs[] = {
  { ZN_CONFIG_BOOL, "-closed", NULL,
    Tk_Offset(ArcItemStruct, flags), CLOSED_BIT, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_BOOL, "-composealpha", NULL,
    Tk_Offset(ArcItemStruct, header.flags), ZN_COMPOSE_ALPHA_BIT,
    ZN_DRAW_FLAG, False },
  { ZN_CONFIG_BOOL, "-composerotation", NULL,
    Tk_Offset(ArcItemStruct, header.flags), ZN_COMPOSE_ROTATION_BIT,
    ZN_COORDS_FLAG, False },
  { ZN_CONFIG_BOOL, "-composescale", NULL,
    Tk_Offset(ArcItemStruct, header.flags), ZN_COMPOSE_SCALE_BIT,
    ZN_COORDS_FLAG, False },
  { ZN_CONFIG_ANGLE, "-extent", NULL,
    Tk_Offset(ArcItemStruct, angle_extent), 0, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_GRADIENT, "-fillcolor", NULL,
    Tk_Offset(ArcItemStruct, fill_color), 0, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_BOOL, "-filled", NULL,
    Tk_Offset(ArcItemStruct, flags), FILLED_BIT, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_BITMAP, "-fillpattern", NULL,
    Tk_Offset(ArcItemStruct, tile), 0, ZN_DRAW_FLAG, False },
  { ZN_CONFIG_LINE_END, "-firstend", NULL,
    Tk_Offset(ArcItemStruct, first_end), 0, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_LINE_END, "-lastend", NULL,
    Tk_Offset(ArcItemStruct, last_end), 0, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_GRADIENT, "-linecolor", NULL,
    Tk_Offset(ArcItemStruct, line_color), 0,
    ZN_DRAW_FLAG|ZN_BORDER_FLAG, False },
  { ZN_CONFIG_BITMAP, "-linepattern", NULL,
    Tk_Offset(ArcItemStruct, line_pattern), 0, ZN_DRAW_FLAG, False },
  { ZN_CONFIG_LINE_STYLE, "-linestyle", NULL,
    Tk_Offset(ArcItemStruct, line_style), 0, ZN_DRAW_FLAG, False },
  { ZN_CONFIG_DIM, "-linewidth", NULL,
    Tk_Offset(ArcItemStruct, line_width), 0, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_BOOL, "-pieslice", NULL,
    Tk_Offset(ArcItemStruct, flags), PIE_SLICE_BIT, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_PRI, "-priority", NULL,
    Tk_Offset(ArcItemStruct, header.priority), 0,
    ZN_DRAW_FLAG|ZN_REPICK_FLAG, False },
  { ZN_CONFIG_BOOL, "-sensitive", NULL,
    Tk_Offset(ArcItemStruct, header.flags), ZN_SENSITIVE_BIT,
    ZN_REPICK_FLAG, False },
  { ZN_CONFIG_ANGLE, "-startangle", NULL,
    Tk_Offset(ArcItemStruct, start_angle), 0, ZN_COORDS_FLAG, False },
  { ZN_CONFIG_TAG_LIST, "-tags", NULL,
    Tk_Offset(ArcItemStruct, header.tags), 0, 0, False },
  { ZN_CONFIG_IMAGE, "-tile", NULL,
    Tk_Offset(ArcItemStruct, tile), 0, ZN_DRAW_FLAG, False },
  { ZN_CONFIG_BOOL, "-visible", NULL,
    Tk_Offset(ArcItemStruct, header.flags), ZN_VISIBLE_BIT,
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
  ArcItem	arc = (ArcItem) item;
  unsigned int	num_points;
  ZnPoint	*points;

  /* Init attributes */
  SET(item->flags, ZN_VISIBLE_BIT);
  SET(item->flags, ZN_SENSITIVE_BIT);
  SET(item->flags, ZN_COMPOSE_ALPHA_BIT);
  SET(item->flags, ZN_COMPOSE_ROTATION_BIT);
  SET(item->flags, ZN_COMPOSE_SCALE_BIT);
  item->priority = 1;

  arc->start_angle = 0;
  arc->angle_extent = 360;
  CLEAR(arc->flags, FILLED_BIT);
  CLEAR(arc->flags, CLOSED_BIT);
  CLEAR(arc->flags, PIE_SLICE_BIT);
  CLEAR(arc->flags, USING_POLY_BIT);
  arc->line_pattern = ZnUnspecifiedImage;
  arc->tile = ZnUnspecifiedImage;
  arc->line_style = ZN_LINE_SIMPLE;
  arc->line_width = 1;
  arc->first_end = arc->last_end = NULL;
  arc->render_shape = NULL;
  arc->grad_geo = NULL;
  
  if (*argc < 1) {
    Tcl_AppendResult(wi->interp, " arc coords expected", NULL);
    return TCL_ERROR;
  }
  if (ZnParseCoordList(wi, (*args)[0], &points,
		       NULL, &num_points, NULL) == TCL_ERROR) {
    return TCL_ERROR;
  }
  if (num_points != 2) {
    Tcl_AppendResult(wi->interp, " malformed arc coords", NULL);
    return TCL_ERROR;
  };
  arc->coords[0] = points[0];
  arc->coords[1] = points[1];
  (*args)++;
  (*argc)--;

  arc->fill_color = ZnGetGradientByValue(wi->fore_color);
  arc->line_color = ZnGetGradientByValue(wi->fore_color);
  
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
  ArcItem	arc = (ArcItem) item;

  if (arc->tile != ZnUnspecifiedImage) {
    arc->tile = ZnGetImageByValue(arc->tile, ZnUpdateItemImage, item);
  }
  if (arc->first_end) {
    ZnLineEndDuplicate(arc->first_end);
  }
  if (arc->last_end) {
    ZnLineEndDuplicate(arc->last_end);
  }
  if (arc->line_pattern != ZnUnspecifiedImage) {
    arc->line_pattern = ZnGetImageByValue(arc->line_pattern, NULL, NULL);
  }
  arc->line_color = ZnGetGradientByValue(arc->line_color);
  arc->fill_color = ZnGetGradientByValue(arc->fill_color);
  arc->grad_geo = NULL;
  if (arc->render_shape) {
    arc->render_shape = ZnListDuplicate(arc->render_shape);
  }
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
  ArcItem	arc = (ArcItem) item;

  if (arc->render_shape) {
    ZnListFree(arc->render_shape);
  }
  if (arc->first_end) {
    ZnLineEndDelete(arc->first_end);
  }
  if (arc->last_end) {
    ZnLineEndDelete(arc->last_end);
  }
  if (arc->tile != ZnUnspecifiedImage) {
    ZnFreeImage(arc->tile, ZnUpdateItemImage, item);
    arc->tile = ZnUnspecifiedImage;
  }
  if (arc->line_pattern != ZnUnspecifiedImage) {
    ZnFreeImage(arc->line_pattern, NULL, NULL);
    arc->line_pattern = ZnUnspecifiedImage;
  }
  if (arc->grad_geo) {
    ZnFree(arc->grad_geo);
  }
  ZnFreeGradient(arc->fill_color);
  ZnFreeGradient(arc->line_color);
}


/*
 **********************************************************************************
 *
 * Setup flags to control the precedence between the
 * graphical attributes.
 *
 **********************************************************************************
 */
static void
SetRenderFlags(ArcItem	arc)
{
  ASSIGN(arc->flags, FIRST_END_OK,
	 (arc->first_end != NULL) && ISCLEAR(arc->flags, CLOSED_BIT) &&
	 ISCLEAR(arc->flags, FILLED_BIT) && arc->line_width
	 /*&& ISCLEAR(arc->flags, RELIEF_OK)*/);

  ASSIGN(arc->flags, LAST_END_OK,
	 (arc->last_end != NULL) && ISCLEAR(arc->flags, CLOSED_BIT) &&
	 ISCLEAR(arc->flags, FILLED_BIT) && arc->line_width
	 /*&& ISCLEAR(arc->flags, RELIEF_OK)*/);
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
  ArcItem	arc = (ArcItem) item;
  int		status = TCL_OK;

  status = ZnConfigureAttributes(item->wi, item, item, arc_attrs, argc, argv, flags);
  if (arc->start_angle < 0) {
    arc->start_angle = 360 + arc->start_angle;
  }

  SetRenderFlags(arc);
  
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
  if (ZnQueryAttribute(item->wi, item, arc_attrs, argv[0]) == TCL_ERROR) {
    return TCL_ERROR;
  }  

  return TCL_OK;
}


/*
 * Tangent --
 *	Compute a point describing the arc tangent at the first/last
 *	end of the arc. The point is on the tangent segment next to
 *	the arc (ie: it is suitable for drawing arrows).
 */
static void
Tangent(ArcItem	arc,
	ZnBool	first,
	ZnPoint	*p)
{
  double	a2, b2, w_2, h_2;
  double	angle;
  ZnPoint	p1, center;

  if (first) {
    angle = ZnDegRad(arc->start_angle);
  }
  else {
    angle = ZnDegRad(arc->start_angle + arc->angle_extent);
  }
  p1.x = cos(angle);
  p1.y = sin(angle);
  w_2 = (arc->corner.x - arc->orig.x) / 2.0;
  h_2 = (arc->corner.y - arc->orig.y) / 2.0;
  center.x = (arc->orig.x + arc->corner.x) / 2.0;
  center.y = (arc->orig.y + arc->corner.y) / 2.0;

  /*
   * Slope of the initial segment.
   *
   * a1 = (center->y - p1.y) / (center->x - p1.x);
   * a2 = -1/a1;
   */
  a2 = - p1.x / p1.y;
  b2 = p1.y - a2*p1.x;

  if (p1.y == 0.0) {
    p->x = p1.x;
    if (!first) {
      p->y = p1.y - 10.0;
    }
    else {
      p->y = p1.y + 10.0;
    }
  }
  else {
    if ((!first && (p1.y < 0.0)) || (first && (p1.y > 0.0))) {
      p->x = p1.x - 10.0;
    }
    else {
      p->x = p1.x + 10.0;
    }
    p->y = a2*p->x + b2;
  }
  p->x = center.x + ZnNearestInt(p->x*w_2);
  p->y = center.y + ZnNearestInt(p->y*h_2);
}


/*
 **********************************************************************************
 *
 * ComputeCoordinates --
 *
 **********************************************************************************
 */
static void
UpdateRenderShape(ArcItem	arc)
{
  ZnPoint	*p_list, p, p2, o, o2;
  ZnReal	width, height, d;
  int		num_p, i, quality;
  ZnTransfo	*t = ((ZnItem) arc)->wi->current_transfo;
  
  if (!arc->render_shape) {
    arc->render_shape = ZnListNew(8, sizeof(ZnPoint));
  }
  o.x = (arc->coords[1].x + arc->coords[0].x)/2.0;
  o.y = (arc->coords[1].y + arc->coords[0].y)/2.0;
  width = (arc->coords[1].x - arc->coords[0].x)/2.0;
  height = (arc->coords[1].y - arc->coords[0].y)/2.0;
  d = MAX(width, height);
  quality = ZN_CIRCLE_COARSE;
  p_list = ZnGetCirclePoints(ISCLEAR(arc->flags, PIE_SLICE_BIT) ? 1 : 2,
			     quality,
			     ZnDegRad(arc->start_angle),
			     ZnDegRad(arc->angle_extent),
			     &num_p,
			     arc->render_shape);

  /*
   * Adapt the number of arc circles to the radius of the arc.
   */
  p.x = o.x + p_list->x*d;
  p.y = o.y + p_list->y*d;
  ZnTransformPoint(t, &o, &o2);
  ZnTransformPoint(t, &p, &p2);
  d = hypot(o2.x-p2.x, o2.y-p2.y);
  if (d > 100.0) {
    quality = ZN_CIRCLE_FINER;
  }
  else if (d > 30.0) {
    quality = ZN_CIRCLE_FINE;
  }
  else if (d > 9.0) {
    quality = ZN_CIRCLE_MEDIUM;
  }
  if (quality != ZN_CIRCLE_COARSE) {
    p_list = ZnGetCirclePoints(ISCLEAR(arc->flags, PIE_SLICE_BIT) ? 1 : 2,
			       quality,
			       ZnDegRad(arc->start_angle),
			       ZnDegRad(arc->angle_extent),
			       &num_p,
			       arc->render_shape);
  }
    
  for (i = 0; i < num_p; i++, p_list++) {
    p.x = o.x + p_list->x*width;
    p.y = o.y + p_list->y*height;
    ZnTransformPoint(t, &p, p_list);
  }
}

static void
ComputeCoordinates(ZnItem	item,
		   ZnBool	force __unused)
{
  ZnWInfo	*wi = item->wi;
  ArcItem	arc = (ArcItem) item;
  ZnReal	angle, sin1, cos1, sin2, cos2;
  ZnReal	tmp, w_2, h_2, center_x, center_y;
  unsigned int	num_p;
  ZnPoint	*p_list, p;
  ZnPoint	end_points[ZN_LINE_END_POINTS];
  
  ZnResetBBox(&item->item_bounding_box);
  /*
   * If it is neither filled nor outlined, then nothing to show.
   */
  if (!arc->line_width && ISCLEAR(arc->flags, FILLED_BIT)) {
    return;
  }

  /*
   * Special case for ellipse rotation and gradient.
   */
  if (!wi->render) {
    ZnTransfoDecompose(wi->current_transfo, NULL, NULL, &angle, NULL);
  }
  if (wi->render || (angle >= PRECISION_LIMIT)) {
    SET(arc->flags, USING_POLY_BIT);

    UpdateRenderShape(arc);
    p_list = ZnListArray(arc->render_shape);
    num_p = ZnListSize(arc->render_shape);
    ZnAddPointsToBBox(&item->item_bounding_box, p_list, num_p);

    tmp = (arc->line_width + 1.0) / 2.0 + 1.0;
    item->item_bounding_box.orig.x -= tmp;
    item->item_bounding_box.orig.y -= tmp;
    item->item_bounding_box.corner.x += tmp;
    item->item_bounding_box.corner.y += tmp;
    
    /*
     * Add the arrows if any.
     */
    if (ISSET(arc->flags, FIRST_END_OK)) {
      ZnGetLineEnd(p_list, p_list+1, arc->line_width, CapRound,
		   arc->first_end, end_points);
      ZnAddPointsToBBox(&item->item_bounding_box, end_points, ZN_LINE_END_POINTS);
    }
    if (ISSET(arc->flags, LAST_END_OK)) {
      ZnGetLineEnd(&p_list[num_p-1], &p_list[num_p-2], arc->line_width, CapRound,
		   arc->last_end, end_points);
      ZnAddPointsToBBox(&item->item_bounding_box, end_points, ZN_LINE_END_POINTS);
    }

#ifdef GL
    if (!ZnGradientFlat(arc->fill_color)) {
      ZnPoly  shape;
      ZnPoint p[4];
      
      if (!arc->grad_geo) {
	arc->grad_geo = ZnMalloc(6*sizeof(ZnPoint));
      }
      if (arc->fill_color->type == ZN_AXIAL_GRADIENT) {
	p[0] = arc->coords[0];
	p[2] = arc->coords[1];
	p[1].x = p[2].x;
	p[1].y = p[0].y;
	p[3].x = p[0].x;
	p[3].y = p[2].y;
	ZnPolyContour1(&shape, p, 4, False);
      }
      else {
	ZnPolyContour1(&shape, arc->coords, 2, False);
      }
      ZnComputeGradient(arc->fill_color, wi, &shape, arc->grad_geo);
    }
    else {
      if (arc->grad_geo) {
	ZnFree(arc->grad_geo);
	arc->grad_geo = NULL;
      }
    }
#endif 
    return;
  }

  /*
   *******		********			**********
   * This part is for X drawn arcs: not rotated.
   *******		********			**********
   */
  CLEAR(arc->flags, USING_POLY_BIT);
  ZnTransformPoint(wi->current_transfo, &arc->coords[0], &arc->orig);
  ZnTransformPoint(wi->current_transfo, &arc->coords[1], &arc->corner);

  if (arc->orig.x > arc->corner.x) {
    tmp = arc->orig.x;
    arc->orig.x = arc->corner.x;
    arc->corner.x = tmp;
  }
  if (arc->orig.y > arc->corner.y) {
    tmp = arc->orig.y;
    arc->orig.y = arc->corner.y;
    arc->corner.y = tmp;
  }

  /*
   * now compute the two points at the centers of the ends of the arc.
   * We first compute the position for a unit circle and then scale
   * to fit the shape.
   * Angles are running clockwise and y coordinates are inverted.
   */
  angle = ZnDegRad(arc->start_angle);
  sin1 = sin(angle);
  cos1 = cos(angle);
  angle += ZnDegRad(arc->angle_extent);
  sin2 = sin(angle);
  cos2 = cos(angle);
  
  w_2 = (arc->corner.x - arc->orig.x) / 2;
  h_2 = (arc->corner.y - arc->orig.y) / 2;
  center_x = (arc->corner.x + arc->orig.x) / 2;
  center_y = (arc->corner.y + arc->orig.y) / 2;

  arc->center1.x = center_x + ZnNearestInt(cos1*w_2);
  arc->center1.y = center_y + ZnNearestInt(sin1*h_2);
  arc->center2.x = center_x + ZnNearestInt(cos2*w_2);
  arc->center2.y = center_y + ZnNearestInt(sin2*h_2);
  
  /*
   * Add the ends centers to the bbox.
   */
  ZnAddPointToBBox(&item->item_bounding_box, arc->center1.x, arc->center1.y);
  ZnAddPointToBBox(&item->item_bounding_box, arc->center2.x, arc->center2.y);
  
  /*
   * If the arc is filled or if the outline is closed in pie slice,
   * add the center of the arc.
   */
  if ((ISSET(arc->flags, FILLED_BIT) || ISSET(arc->flags, CLOSED_BIT)) &&
      ISSET(arc->flags, PIE_SLICE_BIT)) {
    ZnAddPointToBBox(&item->item_bounding_box, center_x, center_y);
  }
  
  /*
   * Then add the 3-o'clock, 6-o'clock, 9-o'clock, 12-o'clock position
   * as required.
   */
  tmp = -arc->start_angle;
  if (tmp < 0) {
    tmp += 360;
  }
  if ((tmp < arc->angle_extent) || ((tmp - 360) > arc->angle_extent)) {
    ZnAddPointToBBox(&item->item_bounding_box, arc->corner.x, center_y);
  }

  tmp = 180 - arc->start_angle;
  if (tmp < 0) {
    tmp += 360;
  }
  if ((tmp < arc->angle_extent) || ((tmp - 360) > arc->angle_extent)) {
    ZnAddPointToBBox(&item->item_bounding_box, arc->orig.x, center_y);
  }
  
  tmp = 90 - arc->start_angle;
  if (tmp < 0) {
    tmp += 360;
  }
  if ((tmp < arc->angle_extent) || ((tmp - 360) > arc->angle_extent)) {
    ZnAddPointToBBox(&item->item_bounding_box, center_x, arc->corner.y);
  }

  tmp = 270 - arc->start_angle;
  if (tmp < 0) {
    tmp += 360;
  }
  if ((tmp < arc->angle_extent) || ((tmp - 360) > arc->angle_extent)) {
    ZnAddPointToBBox(&item->item_bounding_box, center_x, arc->orig.y);
  }
  
  /*
   * Now take care of the arc outline width plus one pixel of margin.
   */
  tmp = (arc->line_width + 1.0) / 2.0 + 1.0;
  item->item_bounding_box.orig.x -= tmp;
  item->item_bounding_box.orig.y -= tmp;
  item->item_bounding_box.corner.x += tmp;
  item->item_bounding_box.corner.y += tmp;

  /*
   * Then add the arrows if any.
   */
  if (ISSET(arc->flags, FIRST_END_OK)) {
    Tangent(arc, True, &p);
    ZnGetLineEnd(&arc->center1, &p, arc->line_width, CapRound,
		 arc->first_end, end_points);
    ZnAddPointsToBBox(&item->item_bounding_box, end_points, ZN_LINE_END_POINTS);
  }
  if (ISSET(arc->flags, LAST_END_OK)) {
    Tangent(arc, False, &p);
    ZnGetLineEnd(&arc->center2, &p, arc->line_width, CapRound,
		 arc->last_end, end_points);
    ZnAddPointsToBBox(&item->item_bounding_box, end_points, ZN_LINE_END_POINTS);
  }
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
  ArcItem	arc = (ArcItem) item;
  ZnPoint	*points;
  ZnPoint	pts[20]; /* Should be at least ZN_LINE_END_POINTS large */
  ZnPoint	center, tang;
  ZnBBox	t_area, *area = ta->area;
  unsigned int	num_points;
  int		result=-1, result2;
  ZnReal	lw = arc->line_width;
  ZnReal	rx, ry, angle, tmp;
  ZnBool	inside, new_inside;
  ZnPickStruct	ps;

  if (ISSET(arc->flags, USING_POLY_BIT) &&
      (ISSET(arc->flags, FILLED_BIT) || (arc->line_width))) {
    points = ZnListArray(arc->render_shape);
    num_points = ZnListSize(arc->render_shape);

    if (ISSET(arc->flags, FILLED_BIT)) {
      result = ZnPolygonInBBox(points, num_points, area, NULL);
      if (result == 0) {
	return 0;
      }
    }
    if (arc->line_width > 0) {
      result2 = ZnPolylineInBBox(points, num_points, arc->line_width,
				 CapRound, JoinRound, area);
      if (ISCLEAR(arc->flags, FILLED_BIT)) {
	if (result2 == 0) {
	  return 0;
	}
	result = result2;
      }
      else if (result2 != result) {
	return 0;
      }
      if (ISSET(arc->flags, CLOSED_BIT) && ISSET(arc->flags, PIE_SLICE_BIT)) {
	pts[0] = points[num_points-1];
	pts[1] = points[0];
	if (ZnPolylineInBBox(pts, 2, arc->line_width,
			     CapRound, JoinRound, area) != result) {
	  return 0;
	}
      }
      /*
       * Check line ends.
       */
      if (ISSET(arc->flags, FIRST_END_OK)) {
	ZnGetLineEnd(&points[0], &points[1], arc->line_width, CapRound,
		     arc->first_end, pts);
	if (ZnPolygonInBBox(pts, ZN_LINE_END_POINTS, area, NULL) != result) {
	  return 0;
	}
      }
      if (ISSET(arc->flags, LAST_END_OK)) {
	ZnGetLineEnd(&points[num_points-1], &points[num_points-2], arc->line_width,
		     CapRound, arc->last_end, pts);
	if (ZnPolygonInBBox(pts, ZN_LINE_END_POINTS, area, NULL) != result) {
	  return 0;
	}
      }
    }
    return result;
  }

  /*
   *******		********			**********
   * The rest of this code deal with non rotated arcs.           *
   * It has been stolen from tkCanvArc.c			 *
   *******		********			**********
   */
  /*
   * Transform both the arc and the rectangle so that the arc's oval
   * is centered on the origin.
   */
  center.x = (arc->orig.x + arc->corner.x)/2.0;
  center.y = (arc->orig.y + arc->corner.y)/2.0;
  t_area.orig.x = area->orig.x - center.x;
  t_area.orig.y = area->orig.y - center.y;
  t_area.corner.x = area->corner.x - center.x;
  t_area.corner.y = area->corner.y - center.y;
  rx = arc->corner.x - center.x + lw/2.0;
  ry = arc->corner.y - center.y + lw/2.0;

  /*
   * Find the extreme points of the arc and see whether these are all
   * inside the rectangle (in which case we're done), partly in and
   * partly out (in which case we're done), or all outside (in which
   * case we have more work to do).  The extreme points include the
   * following, which are checked in order:
   *
   * 1. The outside points of the arc, corresponding to start and
   *	  extent.
   * 2. The center of the arc (but only in pie-slice mode).
   * 3. The 12, 3, 6, and 9-o'clock positions (but only if the arc
   *    includes those angles).
   */
  points = pts;
  angle = ZnDegRad(arc->start_angle);
  points->x = rx*cos(angle);
  points->y = ry*sin(angle);
  angle += ZnDegRad(arc->angle_extent);
  points[1].x = rx*cos(angle);
  points[1].y = ry*sin(angle);
  num_points = 2;
  points += 2;

  if (ISSET(arc->flags, PIE_SLICE_BIT) && (arc->angle_extent < 180.0)) {
    points->x = 0.0;
    points->y = 0.0;
    num_points++;
    points++;
  }

  tmp = -arc->start_angle;
  if (tmp < 0) {
    tmp += 360.0;
  }
  if ((tmp < arc->angle_extent) || ((tmp-360) > arc->angle_extent)) {
    points->x = rx;
    points->y = 0.0;
    num_points++;
    points++;
  }
  tmp = 180.0 - arc->start_angle;
  if (tmp < 0) {
    tmp += 360.0;
  }
  if ((tmp < arc->angle_extent) || ((tmp-360) > arc->angle_extent)) {
    points->x = 0.0;
    points->y = ry;
    num_points++;
    points++;
  }
  tmp = 90.0 - arc->start_angle;
  if (tmp < 0) {
    tmp += 360.0;
  }
  if ((tmp < arc->angle_extent) || ((tmp-360) > arc->angle_extent)) {
    points->x = -rx;
    points->y = 0.0;
    num_points++;
    points++;
  }
  tmp = 270.0 - arc->start_angle;
  if (tmp < 0) {
    tmp += 360.0;
  }
  if ((tmp < arc->angle_extent) || ((tmp-360) > arc->angle_extent)) {
    points->x = 0.0;
    points->y = -ry;
    num_points++;
  }

  /*
   * Now that we've located the extreme points, loop through them all
   * to see which are inside the rectangle.
   */
  inside = ZnPointInBBox(&t_area, pts->x, pts->y);
  for (points = pts+1; num_points > 1; points++, num_points--) {
    new_inside = ZnPointInBBox(&t_area, points->x, points->y);
    if (new_inside != inside) {
      return 0;
    }
  }
  result = inside ? 1 : -1;
  
  /*
   * So far, oval appears to be outside rectangle, but can't yet tell
   * for sure.  Next, test each of the four sides of the rectangle
   * against the bounding region for the arc.  If any intersections
   * are found, then return "overlapping".  First, test against the
   * polygon(s) forming the sides of a chord or pie-slice.
   */
  if ((lw >= 1.0) && (ISSET(arc->flags, CLOSED_BIT))) {
    if (ISSET(arc->flags, PIE_SLICE_BIT)) {
      pts[0] = arc->center1;
      pts[1] = center;
      pts[2] = arc->center2;
      num_points = 3;
    }
    else {
      pts[0] = arc->center1;
      pts[1] = arc->center2;
      num_points = 2;
    }
    if (ZnPolylineInBBox(pts, num_points, lw, CapRound, JoinRound, area) != result) {
      return 0;
    }
  }
  else if (ISSET(arc->flags, FILLED_BIT)) {
    if (ISSET(arc->flags, PIE_SLICE_BIT)) {
      if ((ZnLineInBBox(&center, &arc->center1, area) != result) ||
	  (ZnLineInBBox(&center, &arc->center2, area) != result)) {
	return 0;
      }
    }
    else {
      if (ZnLineInBBox(&arc->center1, &arc->center2, area) != result) {
	return 0;
      }
    }
  }

  /*
   * Check line ends.
   */
  if (ISSET(arc->flags, FIRST_END_OK)) {
    Tangent(arc, True, &tang);
    ZnGetLineEnd(&arc->center1, &tang, arc->line_width, CapRound,
		 arc->first_end, pts);
    if (ZnPolygonInBBox(pts, ZN_LINE_END_POINTS, area, NULL) != result) {
      return 0;
    }
  }
  if (ISSET(arc->flags, LAST_END_OK)) {
    Tangent(arc, False, &tang);
    ZnGetLineEnd(&arc->center2, &tang, arc->line_width, CapRound,
		 arc->last_end, pts);
    if (ZnPolygonInBBox(pts, ZN_LINE_END_POINTS, area, NULL) != result) {
      return 0;
    }
  }
  if (result == 1) {
    return result;
  }
  
  /*
   * Next check for overlap between each of the four sides and the
   * outer perimiter of the arc.  If the arc isn't filled, then also
   * check the inner perimeter of the arc.
   */
  if (ZnHorizLineToArc(t_area.orig.x, t_area.corner.x, t_area.orig.y,
		       rx, ry, arc->start_angle, arc->angle_extent) ||
      ZnHorizLineToArc(t_area.orig.x, t_area.corner.x, t_area.corner.y,
		       rx, ry, arc->start_angle, arc->angle_extent) ||
      ZnVertLineToArc(t_area.orig.x, t_area.orig.y, t_area.corner.y,
		      rx, ry, arc->start_angle, arc->angle_extent) ||
      ZnVertLineToArc(t_area.corner.x, t_area.orig.y, t_area.corner.y,
		      rx, ry, arc->start_angle, arc->angle_extent)) {
    return 0;
  }
  if ((lw > 1.0) && ISCLEAR(arc->flags, FILLED_BIT)) {
    rx -= lw;
    ry -= lw;
    if (ZnHorizLineToArc(t_area.orig.x, t_area.corner.x, t_area.orig.y,
			 rx, ry, arc->start_angle, arc->angle_extent) ||
	ZnHorizLineToArc(t_area.orig.x, t_area.corner.x, t_area.corner.y,
			 rx, ry, arc->start_angle, arc->angle_extent) ||
	ZnVertLineToArc(t_area.orig.x, t_area.orig.y, t_area.corner.y,
			rx, ry, arc->start_angle, arc->angle_extent) ||
	ZnVertLineToArc(t_area.corner.x, t_area.orig.y, t_area.corner.y,
			rx, ry, arc->start_angle, arc->angle_extent)) {
      return 0;
    }
  }
  
  /*
   * The arc still appears to be totally disjoint from the rectangle,
   * but it's also possible that the rectangle is totally inside the arc.
   * Do one last check, which is to check one point of the rectangle
   * to see if it's inside the arc.  If it is, we've got overlap.  If
   * it isn't, the arc's really outside the rectangle.
   */
  ps.point = &area->orig;
  if (Pick(item, &ps) == 0.0) {
    return 0;
  }

  return -1;
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
  ArcItem	arc = (ArcItem) item;
  XGCValues  	values;
  unsigned int	width=0, height=0;
  ZnPoint	*p=NULL;
  XPoint	*xp=NULL;
  unsigned int	num_points=0, i;
  
  if (ISSET(arc->flags, USING_POLY_BIT) &&
      (ISSET(arc->flags, FILLED_BIT) || (arc->line_width))) {
    p = ZnListArray(arc->render_shape);
    num_points = ZnListSize(arc->render_shape);
    ZnListAssertSize(wi->work_xpts, num_points);
    xp = ZnListArray(wi->work_xpts);
    for (i = 0; i < num_points; i++, p++) {
      xp[i].x = (short) p->x;
      xp[i].y = (short) p->y;
    }
    p = ZnListArray(arc->render_shape);
  }
  else {
    width = ((int) (arc->corner.x - arc->orig.x));
    height = ((int) (arc->corner.y - arc->orig.y));
  }
  
  /* Fill if requested */
  if (ISSET(arc->flags, FILLED_BIT)) {
    values.foreground = ZnGetGradientPixel(arc->fill_color, 0.0);
    values.arc_mode = ISSET(arc->flags, PIE_SLICE_BIT) ? ArcPieSlice : ArcChord;
    if (arc->tile != ZnUnspecifiedImage) {
      if (!ZnImageIsBitmap(arc->tile)) { /* Fill tiled */
	values.fill_style = FillTiled;
	values.tile = ZnImagePixmap(arc->tile);
	values.ts_x_origin = (int) item->item_bounding_box.orig.x;
	values.ts_y_origin = (int) item->item_bounding_box.orig.y;
	XChangeGC(wi->dpy, wi->gc,
		  GCTileStipXOrigin|GCTileStipYOrigin|GCFillStyle|GCTile|GCArcMode,
		  &values);
      }
      else { /* Fill stippled */
	values.fill_style = FillStippled;
	values.stipple = ZnImagePixmap(arc->tile);
	values.ts_x_origin = (int) item->item_bounding_box.orig.x;
	values.ts_y_origin = (int) item->item_bounding_box.orig.y;
	XChangeGC(wi->dpy, wi->gc,
		  GCTileStipXOrigin|GCTileStipYOrigin|GCFillStyle|GCStipple|GCForeground|GCArcMode,
		  &values);
      }
    }
    else { /* Fill solid */
      values.fill_style = FillSolid;
      XChangeGC(wi->dpy, wi->gc, GCForeground|GCFillStyle|GCArcMode, &values);
    }
    if (ISSET(arc->flags, USING_POLY_BIT)) {
      XFillPolygon(wi->dpy, wi->draw_buffer, wi->gc,
		   xp, (int) num_points, Nonconvex, CoordModeOrigin);
    }
    else {
      XFillArc(wi->dpy, wi->draw_buffer, wi->gc,
	       (int) arc->orig.x,
	       (int) arc->orig.y,
	       (unsigned int) width,
	       (unsigned int) height,
	       -arc->start_angle*64, -arc->angle_extent*64);
    }
  }

  /*
   * Draw the arc.
   */
  if (arc->line_width) {
    ZnPoint  end_points[ZN_LINE_END_POINTS];
    XPoint      xap[ZN_LINE_END_POINTS];
    ZnPoint	tang;
      
    ZnSetLineStyle(wi, arc->line_style);
    values.foreground = ZnGetGradientPixel(arc->line_color, 0.0);
    values.line_width = (arc->line_width == 1) ? 0 : (int) arc->line_width;
    values.cap_style = CapRound;
    values.join_style = JoinRound;
    if (arc->line_pattern == ZnUnspecifiedImage) {
      values.fill_style = FillSolid;
      XChangeGC(wi->dpy, wi->gc,
		GCFillStyle|GCLineWidth|GCCapStyle|GCJoinStyle|GCForeground, &values);
    }
    else {
      values.fill_style = FillStippled;
      values.stipple = ZnImagePixmap(arc->line_pattern);
      XChangeGC(wi->dpy, wi->gc,
		GCFillStyle|GCStipple|GCLineWidth|GCCapStyle|GCJoinStyle|GCForeground,
		&values);
    }
    if (ISSET(arc->flags, USING_POLY_BIT)) {
      if (ISCLEAR(arc->flags, CLOSED_BIT) && arc->angle_extent != 360) {
	num_points--;
	if (ISSET(arc->flags, PIE_SLICE_BIT)) {
	  num_points--;
	}
      }
      XDrawLines(wi->dpy, wi->draw_buffer, wi->gc,
		 xp, (int) num_points, CoordModeOrigin);
      if (ISSET(arc->flags, FIRST_END_OK)) {
	p = (ZnPoint *) ZnListArray(arc->render_shape);
	ZnGetLineEnd(p, p+1, arc->line_width, CapRound,
		     arc->first_end, end_points);
	for (i = 0; i < ZN_LINE_END_POINTS; i++) {
	  xap[i].x = (short) end_points[i].x;
	  xap[i].y = (short) end_points[i].y;
	}
	XFillPolygon(wi->dpy, wi->draw_buffer, wi->gc, xap, ZN_LINE_END_POINTS,
		     Nonconvex, CoordModeOrigin);
      }
      if (ISSET(arc->flags, LAST_END_OK)) {
	p = (ZnPoint *) ZnListArray(arc->render_shape);
	num_points = ZnListSize(arc->render_shape);
	ZnGetLineEnd(&p[num_points-1], &p[num_points-2], arc->line_width,
		     CapRound, arc->last_end, end_points);
	for (i = 0; i < ZN_LINE_END_POINTS; i++) {
	  xap[i].x = (short) end_points[i].x;
	  xap[i].y = (short) end_points[i].y;
	}
	XFillPolygon(wi->dpy, wi->draw_buffer, wi->gc, xap, ZN_LINE_END_POINTS,
		     Nonconvex, CoordModeOrigin);
      }
    }
    else {
      XDrawArc(wi->dpy, wi->draw_buffer, wi->gc,
	       (int) arc->orig.x,
	       (int) arc->orig.y,
	       (unsigned int) width,
	       (unsigned int) height,
	       -arc->start_angle*64, -arc->angle_extent*64);
      /*
       * If the outline is closed, draw the closure.
       */
      if (ISSET(arc->flags, CLOSED_BIT)) {
	if (ISSET(arc->flags, PIE_SLICE_BIT)) {
	  XPoint	points[3];
	  
	  points[0].x = (short) arc->center1.x;
	  points[0].y = (short) arc->center1.y;
	  points[1].x = (short) ((arc->corner.x + arc->orig.x) / 2);
	  points[1].y = (short) ((arc->corner.y + arc->orig.y) / 2);
	  points[2].x = (short) arc->center2.x;
	  points[2].y = (short) arc->center2.y;
	  XDrawLines(wi->dpy, wi->draw_buffer, wi->gc, points, 3,
		     CoordModeOrigin);
	}
	else {
	  XDrawLine(wi->dpy, wi->draw_buffer, wi->gc,
		    (int) arc->center1.x,
		    (int) arc->center1.y,
		    (int) arc->center2.x,
		    (int) arc->center2.y);
	}
      }
      if (ISSET(arc->flags, FIRST_END_OK)) {
	Tangent(arc, True, &tang);
	ZnGetLineEnd(&arc->center1, &tang, arc->line_width, CapRound,
		     arc->first_end, end_points);
	for (i = 0; i < ZN_LINE_END_POINTS; i++) {
	  xap[i].x = (short) end_points[i].x;
	  xap[i].y = (short) end_points[i].y;
	}
	XFillPolygon(wi->dpy, wi->draw_buffer, wi->gc, xap, ZN_LINE_END_POINTS,
		     Nonconvex, CoordModeOrigin);
      }
      if (ISSET(arc->flags, LAST_END_OK)) {
	Tangent(arc, False, &tang);
	ZnGetLineEnd(&arc->center2, &tang, arc->line_width, CapRound,
		     arc->last_end, end_points);
	for (i = 0; i < ZN_LINE_END_POINTS; i++) {
	  xap[i].x = (short) end_points[i].x;
	  xap[i].y = (short) end_points[i].y;
	}
	XFillPolygon(wi->dpy, wi->draw_buffer, wi->gc, xap, ZN_LINE_END_POINTS,
		     Nonconvex, CoordModeOrigin);
      }
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
ArcRenderCB(void *closure)
{
  ZnItem	item = (ZnItem) closure;
  ArcItem	arc = (ArcItem) item;
  int		num_points=0, i;
  ZnPoint	*p=NULL;
  ZnPoint	center;

  center.x = (item->item_bounding_box.corner.x + item->item_bounding_box.orig.x) / 2.0;
  center.y = (item->item_bounding_box.corner.y + item->item_bounding_box.orig.y) / 2.0;
  p = ZnListArray(arc->render_shape);
  num_points = ZnListSize(arc->render_shape);
  glBegin(GL_TRIANGLE_FAN);
  glVertex2d(center.x, center.y);
  for (i = 0; i < num_points; i++) {
    glVertex2d(p[i].x, p[i].y);
  }
  glEnd();
}
#endif

#ifdef GL
static void
Render(ZnItem	item)
{
  ZnWInfo	*wi = item->wi;
  ArcItem	arc = (ArcItem) item;
  unsigned int	num_points=0;
  ZnPoint	*p=NULL;
  
  if (ISCLEAR(arc->flags, FILLED_BIT) && !arc->line_width) {
    return;
  }
  
#ifdef GL_LIST
  if (!item->gl_list) {
    item->gl_list = glGenLists(1);
    glNewList(item->gl_list, GL_COMPILE);
#endif
    /* Fill if requested */
    if (ISSET(arc->flags, FILLED_BIT)) {
      glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
      
      if (!ZnGradientFlat(arc->fill_color)) {
	ZnPoly poly;
	
	ZnPolyContour1(&poly, ZnListArray(arc->render_shape),
		       ZnListSize(arc->render_shape), False);
	ZnRenderGradient(wi, arc->fill_color, ArcRenderCB, arc,
			 arc->grad_geo, &poly);
      }
      else if (arc->tile != ZnUnspecifiedImage) { /* Fill tiled/stippled */
	ZnRenderTile(wi, arc->tile, arc->fill_color, ArcRenderCB, arc,
		     (ZnPoint *) &item->item_bounding_box);
      }
      else {
	unsigned short alpha;
	XColor *color = ZnGetGradientColor(arc->fill_color, 0.0, &alpha);
	alpha = ZnComposeAlpha(alpha, wi->alpha);
	glColor4us(color->red, color->green, color->blue, alpha);
	ArcRenderCB(arc);
      }
    }
    
    /*
     * Draw the arc.
     */
    if (arc->line_width) {
      ZnLineEnd	first = ISSET(arc->flags, FIRST_END_OK) ? arc->first_end : NULL;
      ZnLineEnd	last = ISSET(arc->flags, LAST_END_OK) ? arc->last_end : NULL;
      ZnBool	closed = ISSET(arc->flags, CLOSED_BIT);
      
      p = ZnListArray(arc->render_shape);
      num_points = ZnListSize(arc->render_shape);
      if (!closed) {
	if (arc->angle_extent != 360) {
	  num_points--;
	  if (ISSET(arc->flags, PIE_SLICE_BIT)) {
	    num_points--;
	  }
	}
      }
      ZnRenderPolyline(wi, p, num_points, arc->line_width,
		       arc->line_style, CapRound, JoinRound, first, last,
		       arc->line_color);
    }
#ifdef GL_LIST
    glEndList();
  }
  
  glCallList(item->gl_list);
#endif
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
static ZnReal
Pick(ZnItem	item,
     ZnPick	ps)
{
  ArcItem	arc = (ArcItem) item;
  double	dist = 1e40, new_dist;
  ZnBool	point_in_angle, filled, closed;
  ZnBool	in_triangle, acute_angle;
  ZnPoint	p1, center, tang;
  ZnPoint	*points, *p = ps->point;
  ZnPoint	end_points[ZN_LINE_END_POINTS];
  unsigned int	num_points;
  ZnDim		width, height;
  ZnDim		lw = arc->line_width;
  
  if (ISSET(arc->flags, USING_POLY_BIT) &&
      (ISSET(arc->flags, FILLED_BIT) || (arc->line_width))) {
    points = ZnListArray(arc->render_shape);
    num_points = ZnListSize(arc->render_shape);

    if (ISSET(arc->flags, FILLED_BIT)) {
      dist = ZnPolygonToPointDist(points, num_points, p);
      if (dist <= 0.0) {
	return 0.0;
      }
    }
    if (arc->line_width > 0) {
      if (ISCLEAR(arc->flags, CLOSED_BIT) && arc->angle_extent != 360) {
	num_points--;
	if (ISSET(arc->flags, PIE_SLICE_BIT)) {
	  num_points--;
	}
      }
      new_dist = ZnPolylineToPointDist(points, num_points, arc->line_width,
				       CapRound, JoinRound, p);
      if (new_dist < dist) {
	dist = new_dist;
      }
      if (dist <= 0.0) {
	return 0.0;
      }

      /*
       * Check line ends.
       */
      if (ISSET(arc->flags, FIRST_END_OK)) {
	ZnGetLineEnd(&points[0], &points[1], arc->line_width, CapRound,
		     arc->first_end, end_points);
	new_dist = ZnPolygonToPointDist(end_points, ZN_LINE_END_POINTS, p);
	if (new_dist < dist) {
	  dist = new_dist;
	}
	if (dist <= 0.0) {
	  return 0.0;
	}
      }
      if (ISSET(arc->flags, LAST_END_OK)) {
	ZnGetLineEnd(&points[num_points-1], &points[num_points-2], arc->line_width,
		     CapRound, arc->last_end, end_points);
	new_dist = ZnPolygonToPointDist(end_points, ZN_LINE_END_POINTS, p);
	if (new_dist < dist) {
	  dist = new_dist;
	}
	if (dist <= 0.0) {
	  return 0.0;
	}
      }
    }
    return dist;
  }

  /*
   *******		********			**********
   * The rest of this code deal with non rotated or relief arcs. *
   *******		********			**********
   */
  center.x = (arc->corner.x + arc->orig.x) / 2;
  center.y = (arc->corner.y + arc->orig.y) / 2;
  width = arc->corner.x - arc->orig.x;
  height = arc->corner.y - arc->orig.y;
  
  /*
   * Let see if the point is in the angular range. First
   * transform the coordinates so that the oval is circular.
   */
  p1.y = (p->y - center.y) / height;
  p1.x = (p->x - center.x) / width;
  point_in_angle = ZnPointInAngle(arc->start_angle, arc->angle_extent, &p1);

  /*
   * Now try to compute the distance dealing with the
   * many possible configurations.
   */
  filled = !ISCLEAR(arc->flags, FILLED_BIT);
  closed = !ISCLEAR(arc->flags, CLOSED_BIT);

  /*
   * First the case of an arc not filled, not closed. We suppose
   * here that the outline is drawn since we cannot get here without
   * filling or outlining.
   */
  if (!filled && !closed) {
    if (point_in_angle) {
      dist = ZnOvalToPointDist(&center, width, height, lw, p);
      if (dist < 0.0) {
	dist = -dist;
      }
    }
    else {
      dist = hypot((p->x - arc->center1.x), (p->y - arc->center1.y));
    }
    new_dist = hypot((p->x - arc->center2.x), (p->y - arc->center2.y));
    if (new_dist < dist) {
      dist = new_dist;
    }
    /* Take into account CapRounded path. */
    if (lw > 1) {
      dist -= lw/2;
      if (dist < 0.0) {
	dist = 0.0;
      }
    }
    if (dist == 0.0) {
      return 0.0;
    }

    /*
     * Check line ends.
     */
    if (ISSET(arc->flags, FIRST_END_OK)) {
      Tangent(arc, True, &tang);
      ZnGetLineEnd(&arc->center1, &tang, arc->line_width, CapRound,
		   arc->first_end, end_points);
      new_dist = ZnPolygonToPointDist(end_points, ZN_LINE_END_POINTS, p);
      if (new_dist < dist) {
	dist = new_dist;
      }
      if (dist <= 0.0) {
	return 0.0;
      }
    }
    if (ISSET(arc->flags, LAST_END_OK)) {
      Tangent(arc, False, &tang);
      ZnGetLineEnd(&arc->center2, &tang, arc->line_width,
		   CapRound, arc->last_end, end_points);
      new_dist = ZnPolygonToPointDist(end_points, ZN_LINE_END_POINTS, p);
      if (new_dist < dist) {
	dist = new_dist;
      }
      if (dist <= 0.0) {
	return 0.0;
      }
    }
    return dist;
  }
  
  /*
   * Try to deal with filled and/or outline-closed arcs (not having full
   * angular extent).
   */
  if (ISSET(arc->flags, PIE_SLICE_BIT)) {
    dist = ZnLineToPointDist(&center, &arc->center1, p);
    new_dist = ZnLineToPointDist(&center, &arc->center2, p);
    if (new_dist < dist) {
      dist = new_dist;
    }
    if (arc->line_width > 1) {
      if (closed) {
	dist -= arc->line_width/2;
      }
      /*
       * The arc outline is CapRounded so if it is not
       * full extent, includes the caps.
       */
      else {
	new_dist = hypot(p->x - arc->center1.x, p->y - arc->center1.y) - lw/2;
	if (new_dist < dist) {
	  dist = new_dist;
	}
	new_dist = hypot(p->x - arc->center2.x, p->y - arc->center2.y) - lw/2;
	if (new_dist < dist) {
	  dist = new_dist;
	}
      }
    }
    if (dist <= 0.0) {
      return 0.0;
    }
    if (point_in_angle) {
      new_dist = ZnOvalToPointDist(&center, width, height, lw, p);
      if (new_dist < dist) {
	dist = new_dist;
      }
      if (dist < 0.0) {
	dist = filled ? 0.0 : -dist;
      }
    }
    return dist;
  }

  /*
   * This is a chord closed oval.
   */    
  dist = ZnLineToPointDist(&arc->center1, &arc->center2, p);
  if (arc->line_width > 1) {
    if (closed) {
      dist -= arc->line_width/2;
    }
    /*
     * The arc outline is CapRounded so if it is not
     * full extent, includes the caps.
     */
    else {
      new_dist = hypot(p->x - arc->center1.x, p->y - arc->center1.y) - lw/2;
      if (new_dist < dist) {
	dist = new_dist;
      }
      new_dist = hypot(p->x - arc->center2.x, p->y - arc->center2.y) - lw/2;
      if (new_dist < dist) {
	dist = new_dist;
      }
    }
  }
  if (dist <= 0.0) {
    return 0.0;
  }
  
  /*
   * Need to check the point against the triangle formed
   * by the difference between Chord mode and PieSlice mode.
   * This triangle needs to be included if extend is more than
   * 180 degrees and excluded otherwise. We try to see if
   * the center of the arc and the point are both on the same
   * side of the chord. If they are, the point is in the triangle
   */
  if (arc->center1.x == arc->center2.x) {
    in_triangle = ((center.x <= arc->center1.x) && (p->x <= arc->center1.x)) ||
      ((center.x > arc->center1.x) && (p->x > arc->center1.x));
  }
  else {
    double	a, b;
    
    a = ((double) (arc->center2.y - arc->center1.y)) /
      ((double) (arc->center2.x - arc->center1.x));
    b = arc->center1.y - a*arc->center1.x;
    in_triangle = (((a*center.x + b - center.y) >= 0.0) ==
		   ((a*p->x + b - p->y) >= 0.0));
  }
  
  acute_angle = ((arc->angle_extent > -180) && (arc->angle_extent < 180));
  if (!point_in_angle && !acute_angle && filled && in_triangle) {
    return 0.0;
  }
  
  if (point_in_angle && (!acute_angle || !in_triangle)) {
    new_dist = ZnOvalToPointDist(&center, width, height, lw, p);
    if (new_dist < dist) {
      dist = new_dist;
    }
    if (dist < 0.0) {
      dist = filled ? 0.0 : -dist;
    }
    if (dist == 0.0) {
      return 0.0;
    }
  }

  return dist;
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
static void
UpdateRenderShapeX(ArcItem	arc)
{
  ZnReal	ox, oy, width_2, height_2;
  int		i, num_p;
  ZnPoint	*p_list;
  
  if (!arc->render_shape) {
    arc->render_shape = ZnListNew(8, sizeof(ZnPoint));
  }
  p_list = ZnGetCirclePoints(ISCLEAR(arc->flags, PIE_SLICE_BIT) ? 1 : 2,
			     ZN_CIRCLE_FINE,
			     ZnDegRad(arc->start_angle),
			     ZnDegRad(arc->angle_extent),
			     &num_p, arc->render_shape);
  ox = (arc->corner.x + arc->orig.x) / 2.0;
  oy = (arc->corner.y + arc->orig.y) / 2.0;
  width_2 = (arc->corner.x - arc->orig.x) / 2.0;
  height_2 = (arc->corner.y - arc->orig.y) / 2.0;
  for (i = 0; i < num_p; i++, p_list++) {
    p_list->x = ox + p_list->x*width_2;
    p_list->y = oy + p_list->y*height_2;
  }
}

static ZnBool
GetClipVertices(ZnItem		item,
		ZnTriStrip	*tristrip)
{
  ArcItem	arc = (ArcItem) item;
  ZnPoint	center;

  if (ISCLEAR(arc->flags, USING_POLY_BIT) || !arc->render_shape) {
    UpdateRenderShapeX(arc);
    SET(arc->flags, USING_POLY_BIT);
  }

  
  center.x = (item->item_bounding_box.corner.x + item->item_bounding_box.orig.x) / 2.0;
  center.y = (item->item_bounding_box.corner.y + item->item_bounding_box.orig.y) / 2.0;
  ZnListEmpty(item->wi->work_pts);
  ZnListAdd(item->wi->work_pts, &center, ZnListTail);
  ZnListAppend(item->wi->work_pts, arc->render_shape);
  ZnTriStrip1(tristrip, ZnListArray(item->wi->work_pts),
	      ZnListSize(item->wi->work_pts), True);
  
  return False;
}


/*
 **********************************************************************************
 *
 * GetContours --
 *	Get the external contour(s).
 *	Never ever call ZnPolyFree on the tristrip returned by GetContours.
 *
 **********************************************************************************
 */
static ZnBool
GetContours(ZnItem	item,
	    ZnPoly	*poly)
{
  ArcItem	arc = (ArcItem) item;
  
  if (ISCLEAR(arc->flags, USING_POLY_BIT) || !arc->render_shape) {
    UpdateRenderShapeX(arc);
  }

  ZnPolyContour1(poly, ZnListArray(arc->render_shape),
		 ZnListSize(arc->render_shape), True);
  poly->contour1.controls = NULL;

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
  ArcItem	arc = (ArcItem) item;

  if ((cmd == ZN_COORDS_ADD) || (cmd == ZN_COORDS_ADD_LAST) || (cmd == ZN_COORDS_REMOVE)) {
    Tcl_AppendResult(item->wi->interp,
		     " arcs can't add or remove vertices", NULL);
    return TCL_ERROR;
  }
  else if (cmd == ZN_COORDS_REPLACE_ALL) {
    if (*num_pts != 2) {
      Tcl_AppendResult(item->wi->interp,
		       " coords command need 2 points on arcs", NULL);
      return TCL_ERROR;
    }
    arc->coords[0] = (*pts)[0];
    arc->coords[1] = (*pts)[1];
    ZnITEM.Invalidate(item, ZN_COORDS_FLAG);
  }
  else if (cmd == ZN_COORDS_REPLACE) {
    if (*num_pts < 1) {
      Tcl_AppendResult(item->wi->interp,
		       " coords command need at least 1 point", NULL);
      return TCL_ERROR;
    }
    if (index < 0) {
      index += 2;
    }
    if ((index < 0) || (index > 1)) {
    range_err:
      Tcl_AppendResult(item->wi->interp,
		       " incorrect coord index, should be between -2 and 1", NULL);
      return TCL_ERROR;
    }
    arc->coords[index] = (*pts)[0];
    ZnITEM.Invalidate(item, ZN_COORDS_FLAG);
  }
  else if (cmd == ZN_COORDS_READ_ALL) {
    *num_pts = 2;
    *pts = arc->coords;
  }
  else if (cmd == ZN_COORDS_READ) {
    if (index < 0) {
      index += 2;
    }
    if ((index < 0) || (index > 1)) {
      goto range_err;
    }
    *num_pts = 1;
    *pts = &arc->coords[index];
  }

  return TCL_OK;
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
  ZnBBox *bbox = &item->item_bounding_box;

  ZnOrigin2Anchor(&bbox->orig,
		  bbox->corner.x - bbox->orig.x,
		  bbox->corner.y - bbox->orig.y,
		  anchor, p);
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
 * Exported functions struct --
 *
 **********************************************************************************
 */
static ZnItemClassStruct ARC_ITEM_CLASS = {
  sizeof(ArcItemStruct),
  0,			/* num_parts */
  False,		/* has_anchors */
  "arc",
  arc_attrs,
  Init,
  Clone,
  Destroy,
  Configure,
  Query,
  NULL,			/* GetFieldSet */
  GetAnchor,
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
  NULL,			/* PickVertex */
  PostScript
};

ZnItemClassId ZnArc = (ZnItemClassId) &ARC_ITEM_CLASS;
