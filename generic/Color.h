/*
 * Color.h -- Header for color routines.
 *
 * Authors		: Patrick Lecoanet.
 * Creation date	: Thu Dec 16 15:41:04 1999
 *
 * $Id: Color.h,v 1.13 2003/06/16 14:56:43 lecoanet Exp $
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


#ifndef _Color_h
#define _Color_h


#include "Types.h"
#include "Geo.h"


/*
 * Types of gradients.
 */
#define ZN_AXIAL_GRADIENT	0
#define ZN_RADIAL_GRADIENT	1
#define ZN_PATH_GRADIENT	2
#define ZN_CONICAL_GRADIENT	3

typedef struct _ZnGradientColor {
  unsigned char	position;	/* Color starting position along the gradient axis.
				 * This is in percent of the gradient total size. */
  unsigned char	control;	/* Middle-shade position in percent of this color
				 * size along the gradient axis. */
  unsigned char	alpha;		/* The color alpha channel in percent */
  unsigned char	mid_alpha;
  XColor	*rgb;		/* The actual color description */
  XColor	*mid_rgb;
} ZnGradientColor;

typedef struct _ZnGradient {
  int		ref_count;
  Tcl_HashEntry	*hash;
  char		type;		/* Either ZN_AXIAL_GRADIENT, ZN_RADIAL_GRADIENT or
				 * ZN_PATH_GRADIENT. */
  int		angle;		/* Angle for an axial gradient (Degrees). */
  ZnPoint	p;		/* Start for an axial/radial/path gradiant. In
				 * percent of the bbox. */
  ZnPoint	e;		/* End of the axial/radial gradiant in percent
				 * of bbox. */
  unsigned int	num_actual_colors;/* Number of adjusted colors */
  ZnGradientColor *actual_colors;/* Actual adjusted gradient color spec. May
				  * be the same array as color_spec. */
  unsigned int	num_colors_in;	/* Number of colors in gradient spec. */
  ZnGradientColor colors_in[1];	/* Gradient color spec */
} ZnGradient;


#define ZnGetGradientPixel(gradient, position) \
  ZnPixel(ZnGetGradientColor(gradient, position, NULL))

ZnGradient *ZnGetGradient(Tcl_Interp *interp, Tk_Window tkwin,
			  Tk_Uid name);
ZnGradient *ZnGetGradientByValue(ZnGradient *gradient);
ZnGradient *ZnGetReliefGradient(Tcl_Interp *interp, Tk_Window tkwin,
				Tk_Uid name, unsigned short alpha);
ZnBool ZnGradientFlat(ZnGradient *grad);
XColor *ZnGetGradientColor(ZnGradient *gradient, ZnReal position,
			   unsigned short *alpha);
void ZnInterpGradientColor(ZnGradient *gradient, ZnReal position,
			   XColor *color, unsigned short *alpha);
char *ZnNameOfGradient(ZnGradient *gradient);
void ZnFreeGradient(ZnGradient *gradient);
void ZnDeleteGradientName(char *name);
ZnBool ZnGradientNameExists(char *name);
ZnBool ZnNameGradient(Tcl_Interp *interp, Tk_Window tkwin,
		      char *grad_descr, char *name);
int ZnComposeAlpha(unsigned short alpha1, unsigned short alpha2);

#endif /* _Color_h */
