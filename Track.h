/*
 * Track.h -- 
 *
 * Authors		: Patrick Lecoanet.
 * Creation date	: Tue Jan 19 16:03:53 1999
 *
 * $Id: Track.h,v 1.5 2003/04/16 09:49:22 lecoanet Exp $
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


#ifndef _Track_h
#define _Track_h


#include "Item.h"


/*
 **********************************************************************************
 *
 * Functions defined in Track.c for internal use.
 *
 **********************************************************************************
 */

void *ZnSendTrackToOm(void *ptr, void *item, int *x, int *y,
		      int *sv_dx, int *sv_dy,
		      /* Fri Oct 13 15:18:11 2000
			 int *label_x, int *label_y,
			 int *label_width, int *label_height,*/
		      int *rho, int *theta, int *visibility, int *locked,
		      int *preferred_angle, int *convergence_style);
void ZnSetLabelAngleFromOm(void *ptr, void *item, int rho, int theta);
void ZnQueryLabelPosition(void *ptr, void *item, int theta,
			  int *x, int *y, int *w, int *h);  
void ZnSetHistoryVisibility(ZnItem item, int index, ZnBool visibility);
void ZnTruncHistory(ZnItem item);


#endif /* _Track_h */
