/*
 * Image.h -- Image support routines.
 *
 * Authors		: Patrick LECOANET
 * Creation date	: Wed Dec  8 11:04:44 1999
 *
 * $Id: Image.h,v 1.11 2003/04/16 09:49:22 lecoanet Exp $
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
ZnGetImage(struct _ZnWInfo *wi, Tk_Uid image_name);
ZnImage
ZnGetImageByValue(ZnImage image);
ZnImage
ZnGetBitmap(struct _ZnWInfo *wi, Tk_Uid bitmap_name);
void
ZnFreeImage(ZnImage image);
char *
ZnNameOfImage(ZnImage image);
void
ZnSizeOfImage(ZnImage image, int *width, int *height);
Pixmap
ZnImagePixmap(ZnImage image);
ZnBool
ZnImageIsBitmap(ZnImage image);
char *
ZnImageMask(ZnImage image, int *stride);
TkRegion
ZnImageRegion(ZnImage image);
#ifdef GL
GLuint
ZnImageTex(ZnImage image, ZnReal *t, ZnReal *s);

typedef struct _ZnTexGlyphVertexInfo {
  GLfloat t0[2];
  GLshort v0[2];
  GLfloat t1[2];
  GLshort v1[2];
  GLfloat t2[2];
  GLshort v2[2];
  GLfloat t3[2];
  GLshort v3[2];
  GLfloat advance;
} ZnTexGVI;


typedef void	*ZnTexFontInfo;

ZnTexFontInfo
ZnGetTexFont(struct _ZnWInfo *wi, Tk_Font font);
void
ZnFreeTexFont(ZnTexFontInfo tfi);
ZnBool
ZnCharInTexFont(ZnTexFontInfo tfi, unsigned int c);
ZnTexGVI *
ZnTexFontGVI(ZnTexFontInfo tfi, unsigned int c);
GLuint
ZnTexFontTex(ZnTexFontInfo tfi);
#endif

#endif	/* _Image_h */
