/*
 * Types.h -- Some types and macros used by the Zinc widget.
 *
 * Authors		: Patrick Lecoanet.
 * Creation date	: Mon Feb  1 12:13:24 1999
 *
 * $Id: Types.h,v 1.36 2003/04/24 14:08:57 lecoanet Exp $
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


#ifndef _Types_h
#define _Types_h


#ifdef _WIN32
#  define WIN32_LEAN_AND_MEAN
#  include <windows.h>
#  undef WIN32_LEAN_AND_MEAN
#  if defined(_MSC_VER)
#    define DllEntryPoint DllMain
#  endif
#endif

#ifdef GL
#  ifdef _WIN32
#    include <GL/gl.h>
#  else
#    include <GL/glx.h>
#  endif
#endif

#include "private.h"

#define NEED_REAL_STDIO

#include <tk.h>
#include <tkInt.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#ifdef PTK
#  include <tkPort.h>
#  include <tkImgPhoto.h>
#  include <tkVMacro.h>
#else
#  include <tkIntDecls.h>
#endif
#include <stdio.h>


/* This EXTERN declaration is needed for Tcl < 8.0.3 */
#ifndef EXTERN
# ifdef __cplusplus
#  define EXTERN extern "C"
# else
#  define EXTERN extern
# endif
#endif

#ifdef TCL_STORAGE_CLASS
#  undef TCL_STORAGE_CLASS
#endif
#ifdef BUILD_Tkzinc
#  define TCL_STORAGE_CLASS DLLEXPORT
#else
#  define TCL_STORAGE_CLASS DLLIMPORT
#endif


#ifdef __CPLUSPLUS__
extern "C" {
#endif


typedef double	ZnReal;	/* Keep it a double for GL. */
typedef int	ZnBool;	/* Keep it an int to keep Tk happy */
typedef ZnReal	ZnPos;
typedef ZnReal	ZnDim;
typedef void	*ZnPtr;



#define ZnPixel(color)		((color)->pixel)
#define ZnMalloc(size)		((void *)ckalloc(size))
#define ZnFree(ptr)		(ckfree((char *)(ptr)))
#define ZnRealloc(ptr, size)	((void *)ckrealloc((void *)(ptr), size))
#define ZnWarning(msg)		(fprintf(stderr, "%s", (msg)))
  
#define ZnUnspecifiedImage	None
#define ZnUnspecifiedColor	NULL

#ifndef TCL_INTEGER_SPACE
#  define TCL_INTEGER_SPACE	24
#endif

#ifdef PTK
/*
 * Macros for Tk8.4/perl/Tk utf compatibility
 */
#define Tcl_NumUtfChars(str, len) ((len)<0?strlen(str):(len))
#define Tcl_UtfAtIndex(str, index) (&(str)[(index)])
#define Tcl_GetString(str) (Tcl_GetStringFromObj(str, NULL))

#define Tk_GetScrollInfoObj(interp, argc, args, fract, count) \
  Tk_GetScrollInfo(interp, argc, (Tcl_Obj **) args, fract, count)
#endif

/*
 * Macros for Windows compatibility
 */
#ifdef _WIN32
#  ifndef _MSC_VER
#    undef EXTERN
#    define EXTERN
#  endif
#  include <tkWinInt.h>
#undef XFillRectangle
EXTERN void XFillRectangle(Display* display, Drawable d, GC gc,
			   int x, int y, unsigned int width,
			   unsigned int height);
#undef XFillRectangles
EXTERN void XFillRectangles(Display*display, Drawable d, GC gc,
			    XRectangle *rectangles, int nrectangles);
#undef XFillArc
EXTERN void XFillArc(Display* display, Drawable d, GC gc,
		     int x, int y, unsigned int width,
		     unsigned int height, int start, int extent);
#undef XFillPolygon
EXTERN void XFillPolygon(Display* display, Drawable d, GC gc,
			 XPoint* points, int npoints, int shape,
			 int mode);
#undef XDrawRectangle
EXTERN void XDrawRectangle(Display* display, Drawable d, GC gc,
			   int x, int y, unsigned int width,
			   unsigned int height);
#undef XDrawArc
EXTERN void XDrawArc(Display* display, Drawable d, GC gc,
		     int x, int y, unsigned int width,
		     unsigned int height, int start, int extent);
#undef XDrawLine
EXTERN void XDrawLine(Display* display, Drawable d, GC gc,
		      int x1, int y1, int x2, int y2);
#undef XDrawLines
EXTERN void XDrawLines(Display* display, Drawable d, GC gc,
		       XPoint* points, int npoints, int mode);

EXTERN void ZnUnionRegion(TkRegion sra, TkRegion srb, 
			  TkRegion dr_return);
EXTERN void ZnOffsetRegion(TkRegion reg, int dx, int dy);
EXTERN TkRegion ZnPolygonRegion(XPoint *points, int n,
				int fill_rule);
#  ifdef GL
#    define ZnGLContext HGLRC
#    define ZnGLMakeCurrent(wi)  \
{			     \
  wi->hdc = GetDC(wi->hwnd); \
  wglMakeCurrent(wi->hdc, wi->gl_context); \
}
#    define ZnGLRelease(wi) \
  ReleaseDC(wi->hwnd, wi->hdc);
#    define ZnGLDestroyContext(wi) \
  wglDeleteContext(wi->gl_context)
#    define ZnGLSwapBuffers(wi) \
  SwapBuffers(wi->hdc)
#    define ZnGLWaitGL()
#    define ZN_GL_LINE_WIDTH_RANGE GL_LINE_WIDTH_RANGE
#    define ZN_GL_POINT_SIZE_RANGE GL_POINT_SIZE_RANGE
#  endif
#else /* !_WIN32 */
#  define ZnPolygonRegion(points, npoints, fillrule) \
  ((TkRegion) XPolygonRegion(points, npoints, fillrule))
#  define ZnUnionRegion(sra, srb, rreturn) \
  XUnionRegion((Region) sra, (Region) srb, (Region) rreturn)
#  define ZnOffsetRegion(reg, dx, dy) \
  XOffsetRegion((Region) reg, dx, dy)
#  ifdef GL
#    define ZnGLContext GLXContext
#    define ZnGLMakeCurrent(wi) \
  glXMakeCurrent(wi->dpy, Tk_WindowId(wi->win), wi->gl_context);
#    define ZnGLRelease(wi)
#    define ZnGLDestroyContext(wi) \
  glXDestroyContext(wi->dpy, wi->gl_context);
#    define ZnGLSwapBuffers(wi) \
  glXSwapBuffers(wi->dpy, Tk_WindowId(wi->win))
#    define ZnGLWaitGL() \
  glXWaitGL()
#    define ZN_GL_LINE_WIDTH_RANGE GL_SMOOTH_LINE_WIDTH_RANGE
#    define ZN_GL_POINT_SIZE_RANGE GL_SMOOTH_POINT_SIZE_RANGE
#  endif
#endif

#ifdef __CPLUSPLUS__
}
#endif

#endif /* _Types_h */
