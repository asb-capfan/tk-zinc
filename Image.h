/*
 * Image.h -- Image support routines.
 *
 * Authors		: Patrick LECOANET
 * Creation date	: Wed Dec  8 11:04:44 1999
 *
 * $Id: Image.h,v 1.17 2004/05/10 15:42:26 lecoanet Exp $
 */

/*
 *  Copyright (c) 1999 CENA, Patrick Lecoanet --
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


#ifndef _Image_h
#define _Image_h

#include "Types.h"

struct _ZnWInfo;


typedef void	*ZnImage;

#define ZnGetBitmapPixel(bits, stride, x, y)\
  (((bits)[(y)*(stride)+((x)>>3)]<<((x)&7))&0x80)

ZnImage
ZnGetImage(struct _ZnWInfo *wi, Tk_Uid image_name,
	   void (*inv_proc)(void *cd), void *cd);
ZnImage
ZnGetImageByValue(ZnImage image, void (*inv_proc)(void *cd), void *cd);
void
ZnFreeImage(ZnImage image, void (*inv_proc)(void *cd), void *cd);
char *
ZnNameOfImage(ZnImage image);
void
ZnSizeOfImage(ZnImage image, int *width, int *height);
Pixmap
ZnImagePixmap(ZnImage image, Tk_Window win);
ZnBool
ZnImageIsBitmap(ZnImage image);
TkRegion
ZnImageRegion(ZnImage image);
ZnBool
ZnPointInImage(ZnImage image, int x, int y);
#ifdef GL
GLuint
ZnImageTex(ZnImage image, ZnReal *t, ZnReal *s);

typedef struct _ZnTexGlyphVertexInfo {
  GLfloat	t0x;
  GLfloat	t0y;
  GLshort	v0x;
  GLshort	v0y;
  GLfloat	t1x;
  GLfloat	t1y;
  GLshort	v1x;
  GLshort	v1y;
  GLfloat	advance;
  int		code;
} ZnTexGVI;


typedef void	*ZnTexFontInfo;

ZnTexFontInfo ZnGetTexFont(struct _ZnWInfo *wi, Tk_Font font);
void ZnFreeTexFont(ZnTexFontInfo tfi);
ZnTexGVI *ZnTexFontGVI(ZnTexFontInfo tfi, int c);
int ZnGetFontIndex(ZnTexFontInfo tfi, int c);
GLuint ZnTexFontTex(ZnTexFontInfo tfi);
void ZnGetDeferredGLGlyphs(void);
#endif

#endif	/* _Image_h */
