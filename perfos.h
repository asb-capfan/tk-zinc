/*
 * perfos.h -- Header for perf module.
 *
 * Authors		: Patrick Lecoanet.
 * Creation date	:
 *
 * $Id: perfos.h,v 1.4 2003/04/16 09:49:22 lecoanet Exp $
 */

/*
 *  Copyright (c) 1996 2000 CENA, Patrick Lecoanet --
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


#ifndef _perfos_h
#define _perfos_h

#ifdef __CPLUSPLUS__
extern "C" {
#endif

#ifndef _WIN32

#include <stdio.h>
#include <math.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/times.h>
#include <X11/Xlib.h>

  typedef struct
  {
    long   current_correction;
    long   current_delay;
    long   total_delay;
    int    actions;
    char   *message;
  } ZnChronoRec, *ZnChrono;
  
  
  void ZnXStartChrono(ZnChrono /*chrono*/, Display */*dpy*/, Drawable /*win*/);
  void ZnXStopChrono(ZnChrono /*chrono*/, Display */*dpy*/, Drawable /*win*/);
  void ZnStartChrono(ZnChrono /*chrono*/);
  void ZnStopChrono(ZnChrono /*chrono*/);
  void ZnStartUCChrono(ZnChrono /*chrono*/);
  void ZnStopUCChrono(ZnChrono /*chrono*/);
  ZnChrono ZnNewChrono(char */*message*/);
  void ZnFreeChrono(ZnChrono /*chrono*/);
  void ZnPrintChronos(void);
  void ZnGetChrono(ZnChrono /*chrono*/, long */*time*/, int */*actions*/);
  void ZnResetChronos(ZnChrono /*chrono*/);

#endif /* _WIN32 */

#ifdef __CPLUSPLUS__
}
#endif

#endif  /* _perfos_h */
