/*
 * PostScript.h -- Header to access PostScript driver.
 *
 * Authors		: Patrick Lecoanet.
 * Creation date	: Wed Jan  4 11:30:00 1995
 *
 * $Id: PostScript.h,v 1.4 2004/02/13 10:37:43 lecoanet Exp $
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


#ifndef _PostScript_h
#define _PostScript_h


#include "List.h"
#include "Types.h"
#include "Geo.h"

#include <stdio.h>
#include <X11/Xlib.h>


struct _ZnWInfo;


int ZnPostScriptCmd(struct _ZnWInfo *wi, int argc, Tcl_Obj *CONST *args);


#endif	/* _PostScript_h */
