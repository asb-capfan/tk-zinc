/*
 * Transfo.h -- Header for common geometric routines.
 *
 * Authors		: Patrick Lecoanet.
 * Creation date	:
 *
 * $Id: Transfo.h,v 1.3 2003/04/16 09:49:22 lecoanet Exp $
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


#ifndef _Transfo_h
#define _Transfo_h


#include "Types.h"

#include <math.h>
#include <limits.h>


/*
 * First subscript is matrix row, second is matrix column.
 * So a[0][1] is upper right corner of matrix a and a[2][0]
 * is lower left corner.
 */
typedef struct  _ZnTransfo {
  ZnReal	_[3][2];
} ZnTransfo;


ZnTransfo *
ZnTransfoNew(void);
ZnTransfo *
ZnTransfoDuplicate(ZnTransfo *t);
void
ZnTransfoFree(ZnTransfo	*t);
void
ZnPrintTransfo(ZnTransfo	*t);
void
ZnTransfoSetIdentity(ZnTransfo	*t);
ZnBool
ZnTransfoIsIdentity(ZnTransfo	*t);
ZnTransfo *
ZnTransfoCompose(ZnTransfo	*res,
		 ZnTransfo	*t1,
		 ZnTransfo	*t2);
ZnTransfo *
ZnTransfoInvert(ZnTransfo	*t,
		ZnTransfo	*inv);
void
ZnTransfoDecompose(ZnTransfo	*t,
		   ZnPoint	*scale,
		   ZnPoint	*trans,
		   ZnReal	*rotation,
		   ZnReal	*shearxy);
ZnBool
ZnTransfoEqual(ZnTransfo	*t1,
	       ZnTransfo	*t2,
	       ZnBool		include_translation);
ZnBool
ZnTransfoHasShear(ZnTransfo	*t);
ZnBool
ZnTransfoIsTranslation(ZnTransfo	*t);
ZnPoint *
ZnTransformPoint(ZnTransfo	*t,
		 ZnPoint	*p,
		 ZnPoint	*xp);
void
ZnTransformPoints(ZnTransfo	*t,
		  ZnPoint	*p,
		  ZnPoint	*xp,
		  unsigned int	num);
ZnTransfo *
ZnTranslate(ZnTransfo	*t,
	    ZnReal	delta_x,
	    ZnReal	delta_y);
ZnTransfo *
ZnSetTranslation(ZnTransfo	*t,
		 ZnReal		delta_x,
		 ZnReal		delta_y);
ZnTransfo *
ZnScale(ZnTransfo	*t,
	ZnReal		scale_x,
	ZnReal		scale_y);
ZnTransfo *
ZnRotateRad(ZnTransfo	*t,
	    ZnReal	angle);
ZnTransfo *
ZnRotateDeg(ZnTransfo	*t,
	    ZnReal	angle);


#endif	/* _Transfo_h */
