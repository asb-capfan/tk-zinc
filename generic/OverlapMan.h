/*
 * OverlapMan.h -- Track label overlap avoidance manager header file
 *
 * Authors		:
 * Creation date	:
 *
 * $Id: OverlapMan.h,v 1.11 2002/03/15 13:49:37 lecoanet Exp $
 */

/*
 *  Copyright (c) 1993 - 1999 CENA --
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


#ifndef _OverlapMan_h
#define _OverlapMan_h


#include <string.h>
#include <math.h>

/*
 * Init code.
 */
void
OmInit();

/*
 * This is the interface with the zinc widget. To substitute
 * a different overlap manager, it is necessary to conform to
 * this API.
 */
void
OmRegister(void	*w,
	   void	*(*_fnext_track)(void *ptr,
				 void *item,
				 int *x, int *y,
				 int *sv_dx, int *sv_dy,
				 /* Fri Oct 13 15:16:13 2000
				 int *label_x, int *label_y,
				 int *label_width, int *label_height,
				 */
				 int *rho, int *theta,
				 int *visibility,
				 int *locked ,
				 int *preferred_angle  ,
				 int *convergence_style),
	   void	(*_fset_label_angle)(void *ptr, void *item, int rho, int theta),
	   void	(*_fquery_label_pos)(void *ptr, void *item, int theta,
				     int *x, int *y, int *w, int *h));
void
OmUnregister(void	*w);
void
OmProcessOverlap(void	*zinc,
		 int	width,
		 int	height,
		 double	scale);


/* 
 * Parameter data type which ease exchange of parameters between
 * Radar Image toolkit and Om library
 */
#define OM_PARAM_END       0
#define OM_PARAM_INT       1
#define OM_PARAM_FLOAT     2
#define OM_PARAM_DOUBLE    3
#define OM_PARAM_STRING    4


typedef struct {
  int  type     ;  /* should be among OM_PARAM_ */
  char name[50] ;
} OmParam ;


/*
 * These are the generic overlap manager public functions used
 * to set/get any parameters that the Om library allow to modify
 * dynamically (tunable parameters)
 */

/* OmSetNParam
   return 1 if ok , anythingelse if nok (non existing parameters ,
   wrong type) */
int
OmSetNParam(char *name, /* parameter's name */
			void *value);
/* OmGetNParam
   return 1 if ok , anythingelse if nok (non existing parameters ,
   wrong type)
 */
int
OmGetNParam(char *name, /* parameter's name */
			void *ptvalue);

/* OmGetNParamList
   return 1 and next index if remains to read, the current param
   being written in current_param
   return 0 if end of list and no param */
int 
OmGetNParamList(OmParam *current_param, int *idx_next);


#endif	/* _OverlapMan_h */
