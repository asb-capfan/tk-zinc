/*
 * Image.c -- Image support routines.
 *
 * Authors		: Patrick LECOANET
 * Creation date	: Wed Dec  8 11:04:44 1999
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


#include "Types.h"
#include "Image.h"
#include "WidgetInfo.h"
#include "Geo.h"
#include "Draw.h"
#include "perfos.h"

#include <memory.h>
#include <ctype.h>
#ifdef GL
#include <stdlib.h>
#endif


static const char rcsid[] = "$Id: Image.c,v 1.33 2003/11/28 13:27:34 lecoanet Exp $";
static const char compile_id[] = "$Compile: " __FILE__ " " __DATE__ " " __TIME__ " $";


static int		images_inited = 0;
static Tcl_HashTable	images;
#ifdef GL
static Tcl_HashTable	font_textures;
#endif

typedef struct _ClientStruct {
  void	(*inv_proc)(void *cd);
  void	*client_data;
} ClientStruct;

typedef struct _ImageStruct {
  union {
    Pixmap	pixmap;
#ifdef GL
    GLuint	texobj;
#endif
  } i;
  struct _ZnWInfo   *wi;
  struct _ImageBits *bits;

  /* Bookkeeping */

  ZnBool	for_gl;
  int		refcount;
  ZnList	clients;
  struct _ImageStruct	*next;
} ImageStruct, *Image;


typedef struct _ImageBits {
  unsigned char	*bpixels;  /* Needed for bitmaps. Set to NULL if the image
			    * is not a bitmap. */
  int		rowstride;
#ifdef GL
  ZnReal	t;	   /* Texture parameters for the image. */
  ZnReal	s;
  int		t_width;   /* Texture size used for this image. */
  int		t_height;
  unsigned char	*t_bits;   /* Can be NULL if texture is not used (no GL
			    * rendering active on this image). */
#endif

  /* Bookeeping */
  struct _ZnWInfo *wi;	  /* The widget that created the tkimage below (the first
			   * to use this image). */
  Tk_Image	tkimage;  /* Keep this handle to be informed of changes */ 
  Tk_PhotoHandle tkphoto;
  TkRegion	valid_region;
  int		width;
  int		height;
  Tcl_HashEntry	*hash;	  /* From this it is easy to get the image/bitmap
			   * name. */
  Image		images;   /* Linked list of widget/display dependant
			   * specializations of this image. If NULL, the
			   * image has no specialization and can be freed. */
} ImageBits;


char *ZnNameOfImage(ZnImage image);

#ifdef GL

static int
To2Power(int a)
{
  int result = 1;

  while (result < a) {
    result *= 2;
  }
  return result;
}
#endif
     

/*
 **********************************************************************************
 *
 * ZnGetImage --
 *
 **********************************************************************************
 */
static void
InvalidateImage(ClientData	client_data,
		int		x __unused,
		int		y __unused,
		int		width __unused,
		int		height __unused,
		int		image_width __unused,
		int		image_height __unused)
{
  ImageBits    *bits = (ImageBits *) client_data;
  Image	       this;
  int	       num_cs, count, i;
  ClientStruct *cs;

  if (ZnImageIsBitmap(bits->images)) {
    /* This is a bitmap nothing to update
     * (This should not happen) */
    return;
  }

#ifdef GL
  if (bits->t_bits) {
    ZnFree(bits->t_bits);
    bits->t_bits = NULL;
  }
#endif
  if (bits->valid_region) {
    TkDestroyRegion(bits->valid_region);
    bits->valid_region = NULL;
  }

  count = 0;
  this = bits->images;
  while (this) {
    if (bits->tkphoto) {
      Tk_PhotoGetSize(bits->tkphoto, &bits->width, &bits->height);
    }
    else {
      Tk_SizeOfImage(bits->tkimage, &bits->width, &bits->height);
    }
#ifdef GL
    if (this->for_gl) {
      if (this->i.texobj) {
	ZnGLMakeCurrent(this->wi);
	glDeleteTextures(1, &this->i.texobj);
	ZnGLRelease(this->wi);
	this->i.texobj = 0;
      }
    }
    else {
#endif
      if (this->i.pixmap != None) {
	Tk_FreePixmap(this->wi->dpy, this->i.pixmap);
	this->i.pixmap = None;    
      }
#ifdef GL
    }
#endif
	  
    num_cs = ZnListSize(this->clients);
    cs = ZnListArray(this->clients);
    for (i = 0; i < num_cs; i++, cs++) {
      if (cs->inv_proc) {
	(*cs->inv_proc)(cs->client_data);
      }
    }
    count += num_cs;
    this = this->next;
  }
  /*printf("Invalidate on image %s with %d clients\n",
    Tcl_GetHashKey(&images, bits->hash), count);*/

}

ZnImage
ZnGetImage(ZnWInfo	*wi,
	   Tk_Uid	image_name,
	   void		(*inv_proc)(void *cd),
	   void		*client_data)
{
  Tcl_HashEntry	*entry;
  int		new, num_cs, i;
  ImageBits	*bits;
  ZnBool	for_gl = wi->render>0;
  Image		image;
  Tk_ImageType	*type;
  ClientStruct	cs, *cs_ptr;

  /*printf("ZnGetImage: %s\n", image_name);*/
  if (!images_inited) {
    Tcl_InitHashTable(&images, TCL_STRING_KEYS);
    images_inited = 1;
  }
  image_name = Tk_GetUid(image_name);
  entry = Tcl_FindHashEntry(&images, image_name);
  if (entry != NULL) {
    /*printf("Image %s d�j� connue\n", image_name);*/
    bits = (ImageBits *) Tcl_GetHashValue(entry);
  }
  else {
    /*printf("Nouvelle Image %s\n", image_name);*/
    if (strcmp(image_name, "") == 0) {
      return ZnUnspecifiedImage;
    }

    bits = ZnMalloc(sizeof(ImageBits));
    bits->wi = wi;
#ifdef GL
    bits->t_bits = NULL;
#endif
    bits->images = NULL;
    bits->bpixels = NULL;
    bits->valid_region = NULL;
    bits->tkimage = NULL;
    bits->tkphoto = NULL;

    if (!Tk_GetImageMasterData(wi->interp, image_name, &type)) {
      /*
       * This doesn't seem to be a Tk image, try to load
       * a Tk bitmap.
       */
      Pixmap	pmap;
      XImage	*mask;
      int	x, y;
      unsigned char *line;
      
      pmap = Tk_GetBitmap(wi->interp, wi->win, image_name);
      if (pmap == None) {
	ZnWarning("unknown bitmap/image \"");
	goto im_error;
      }
      
      Tk_SizeOfBitmap(wi->dpy, pmap, &bits->width, &bits->height);    
      mask = XGetImage(wi->dpy, pmap, 0, 0, (unsigned int) bits->width,
		       (unsigned int) bits->height, 1L, XYPixmap);
      bits->rowstride = mask->bytes_per_line;
      bits->bpixels = ZnMalloc((unsigned int) (bits->height * bits->rowstride));
      memset(bits->bpixels, 0, (unsigned int) (bits->height * bits->rowstride));
      line = bits->bpixels;
      for (y = 0; y < bits->height; y++) {
	for (x = 0; x < bits->width; x++) {
	  if (XGetPixel(mask, x, y)) {
	    line[x >> 3] |= 0x80 >> (x & 7);
	  }
	}
	line += bits->rowstride;
      }
      XDestroyImage(mask);
      Tk_FreeBitmap(wi->dpy, pmap);
    }
    
    else if (strcmp(type->name, "photo") == 0) {
      /* Processing will yield an image photo */
      bits->tkphoto = Tk_FindPhoto(wi->interp, image_name);
      Tk_PhotoGetSize(bits->tkphoto, &bits->width, &bits->height);
      if ((bits->width == 0) || (bits->height == 0)) {
	ZnWarning("bogus photo image \"");
	goto im_error;
      }
      bits->tkimage = Tk_GetImage(wi->interp, wi->win, image_name,
				  InvalidateImage, (ClientData) bits);
    }
    else { /* Other image types */
      bits->tkimage = Tk_GetImage(wi->interp, wi->win, image_name,
				  InvalidateImage, (ClientData) bits);
      Tk_SizeOfImage(bits->tkimage, &bits->width, &bits->height);
      if ((bits->width == 0) || (bits->height == 0)) {
	ZnWarning("bogus ");
	ZnWarning(type->name);
	ZnWarning(" image \"");
      im_error:
	ZnWarning(image_name);
	ZnWarning("\"\n");
	ZnFree(bits);
	return ZnUnspecifiedImage;      
      }
    }

    entry = Tcl_CreateHashEntry(&images, image_name, &new);
    bits->hash = entry;
    Tcl_SetHashValue(entry, (ClientData) bits);
  }

  /*
   * Try to find an image instance that fits this widget/display.
   */
  for (image = bits->images; image != NULL; image = image->next) {
    if (image->for_gl == for_gl) {
      if ((for_gl && (image->wi == wi)) ||
	  (!for_gl && (image->wi->screen == wi->screen))) {
	if (!ZnImageIsBitmap(image)) {
	  cs_ptr = ZnListArray(image->clients);
	  num_cs = ZnListSize(image->clients);
	  for (i = 0; i < num_cs; i++, cs_ptr++) {
	    if ((cs_ptr->inv_proc == inv_proc) &&
		(cs_ptr->client_data == client_data)) {
	      return image;
	    }
	  }
	  /* Add a new client reference to call back.
	   */
	  cs.inv_proc = inv_proc;
	  cs.client_data = client_data;
	  ZnListAdd(image->clients, &cs, ZnListTail);
	}
	image->refcount++;
	return image;
      }
    }
  }

  /*
   * Create a new instance for this case.
   */
  image = ZnMalloc(sizeof(ImageStruct));
  image->bits = bits;
  image->refcount = 1;
  image->for_gl = for_gl;
  image->wi = wi;

  if (!ZnImageIsBitmap(image)) {
    image->clients = ZnListNew(1, sizeof(ClientStruct));
    cs.inv_proc = inv_proc;
    cs.client_data = client_data;
    ZnListAdd(image->clients, &cs, ZnListTail);
  }

  /* Init the real resource and let the client load it
   * on demand */
  if (image->for_gl) {
#ifdef GL
    image->i.texobj = 0;
#endif
  }
  else {
    image->i.pixmap = None;
    /*    image->i.pixmap = Tk_GetBitmap(wi->interp, wi->win, image_name);
	  printf("pmap: %d\n", image->i.pixmap);*/
  }
  image->next = bits->images;
  bits->images = image;

  return image;
}


/*
 **********************************************************************************
 *
 * ZnGetImageByValue --
 *
 **********************************************************************************
 */
ZnImage
ZnGetImageByValue(ZnImage	image,
		  void		(*inv_proc)(void *cd),
		  void		*client_data)
{
  Image		this = (Image) image;
  ClientStruct	cs, *cs_ptr;
  int		i, num_cs;

  /*printf("ZnGetImageByValue: %s\n", ZnNameOfImage(image));*/
  if (!ZnImageIsBitmap(image)) {
    cs_ptr = ZnListArray(this->clients);
    num_cs = ZnListSize(this->clients);
    for (i = 0; i < num_cs; i++, cs_ptr++) {
      if ((cs_ptr->inv_proc == inv_proc) &&
	  (cs_ptr->client_data == client_data)) {
	return image;
      }
    }
    cs.inv_proc = inv_proc;
    cs.client_data = client_data;
    ZnListAdd(this->clients, &cs, ZnListTail);
  }

  this->refcount++;
  return image;
}

/*
 **********************************************************************************
 *
 * ZnImageIsBitmap --
 *
 **********************************************************************************
 */
ZnBool
ZnImageIsBitmap(ZnImage	image)
{
  return (((Image) image)->bits->bpixels != NULL);
}

/*
 **********************************************************************************
 *
 * ZnFreeImage --
 *
 **********************************************************************************
 */
void
ZnFreeImage(ZnImage	image,
	    void	(*inv_proc)(void *cd),
	    void	*client_data)
{
  Image		prev, scan, this = ((Image) image);
  ImageBits	*bits = this->bits;
  ClientStruct	*cs_ptr;
  int		i, num_cs;

  /*printf("ZnFreeImage: %s\n", ZnNameOfImage(image));*/
  /*
   * Search the instance in the list.
   */
  for (prev=NULL, scan=bits->images; (scan!=NULL)&&(scan!=this);
       prev=scan, scan=scan->next);
  if (scan != this) {
    return; /* Not found ? */
  }

  if (!ZnImageIsBitmap(image)) {
    cs_ptr = ZnListArray(this->clients);
    num_cs = ZnListSize(this->clients);
    for (i = 0; i < num_cs; i++, cs_ptr++) {
      if ((cs_ptr->inv_proc == inv_proc) &&
	  (cs_ptr->client_data == client_data)) {
	ZnListDelete(this->clients, i);
	this->refcount--;
	break;
      }
    }
  }
  else {
    this->refcount--;
  }
  if (this->refcount != 0) {
    return;
  }

  /*
   * Unlink the deleted image instance.
   */
  if (prev == NULL) {
    bits->images = this->next;
  }
  else {
    prev->next = this->next;
  }
  if (this->for_gl) {
#ifdef GL
    ZnWInfo *wi = this->wi;
    if (this->i.texobj && wi->win) {
      ZnGLMakeCurrent(wi);
      glDeleteTextures(1, &this->i.texobj);
      ZnGLRelease(wi);
    }
#endif
  }
  else if (bits->tkimage) {
    /*
     * This is an image, we need to free the instances.
     */
    if (this->i.pixmap != None) {
      Tk_FreePixmap(this->wi->dpy, this->i.pixmap);
    }
  }
  else {
    /*
     * This is a bitmap ask Tk to free the resource.
     */
    if (this->i.pixmap != None) {
      Tk_FreeBitmap(this->wi->dpy, this->i.pixmap);
    }
  }
  ZnFree(this);

  /*
   * No clients for this image, it can be freed.
   */
  if (bits->images == NULL) {
    /*printf("destruction compl�te de l'image %s\n", ZnNameOfImage(this));*/
#ifdef GL
    if (bits->t_bits) {
      ZnFree(bits->t_bits);
    }
#endif
    if (bits->bpixels) {
      ZnFree(bits->bpixels);
    }
    if (bits->tkimage) {
      Tk_FreeImage(bits->tkimage);
    }
    if (bits->valid_region) {
      TkDestroyRegion(bits->valid_region);
    }
    Tcl_DeleteHashEntry(bits->hash);
    ZnFree(bits);
  }
}


/*
 **********************************************************************************
 *
 * ZnNameOfImage --
 *
 **********************************************************************************
 */
char *
ZnNameOfImage(ZnImage	image)
{
  return Tcl_GetHashKey(&images, ((Image) image)->bits->hash);
}


/*
 **********************************************************************************
 *
 * ZnSizeOfImage --
 *
 **********************************************************************************
 */
void
ZnSizeOfImage(ZnImage	image,
	      int	*width,
	      int	*height)
{
  Image		this = (Image) image;

  *width = this->bits->width;
  *height = this->bits->height;
}


/*
 **********************************************************************************
 *
 * ZnImagePixmap --
 *
 **********************************************************************************
 */
Pixmap
ZnImagePixmap(ZnImage	image)
{
  Image		this = (Image) image;
  ImageBits	*bits = this->bits;
  ZnWInfo	*wi = bits->wi;

  /*printf("ZnImagePixmap: %s\n", ZnNameOfImage(image));*/
  if (this->for_gl) {
    fprintf(stderr,
	    "Bogus use of an image, it was created for GL and used in an X11 context\n");
    return None;
  }
  
  if (this->i.pixmap == None) {
    if (ZnImageIsBitmap(image)) {
      this->i.pixmap = Tk_GetBitmap(wi->interp, wi->win, Tk_GetUid(ZnNameOfImage(image)));
    }
    else {
      Tk_Image tkimage;
      
      if (bits->wi == wi) {
	tkimage = bits->tkimage;
      }
      else {
	/* Create a temporary tkimage to draw the pixmap. */
	tkimage = Tk_GetImage(wi->interp, wi->win, ZnNameOfImage(image), NULL, NULL);
      }
      
      this->i.pixmap = Tk_GetPixmap(wi->dpy, Tk_WindowId(wi->win),
				    bits->width, bits->height, Tk_Depth(wi->win));
      Tk_RedrawImage(tkimage, 0, 0, bits->width, bits->height, this->i.pixmap, 0, 0);
      
      if (tkimage != bits->tkimage) {
	Tk_FreeImage(tkimage);
      }
    }
  }

  return this->i.pixmap;
}


/*
 **********************************************************************************
 *
 * ZnPointInImage --
 *
 *	Return whether the given point is inside the image.
 *
 **********************************************************************************
 */
ZnBool
ZnPointInImage(ZnImage	image,
	       int	x,
	       int	y)
{
  if (ZnImageIsBitmap(image)) {
    ImageBits *bits = ((Image) image)->bits;
    if ((x < 0) || (y < 0) ||
	(x >= bits->width) || (y >= bits->height)) {
      return False;
    }
    return ZnGetBitmapPixel(bits->bpixels, bits->rowstride, x, y);
  }
  else {
    return ZnPointInRegion(ZnImageRegion(image), x, y);
  }
}


/*
 **********************************************************************************
 *
 * ZnImageRegion --
 *
 *	Only defined for Tk images (including Tk images defined from bitmaps).
 *
 **********************************************************************************
 */
static void
BuildImageRegion(ImageBits *bits)
{
  ZnWInfo	*wi = bits->wi;
  Pixmap	pmap;
  int		x, y, end;
  GC		gc;
  XImage	*im1, *im2;
  XRectangle	rect;

  /*printf("BuildImageRegion: %s\n", ZnNameOfImage(bits->images));*/
  pmap = Tk_GetPixmap(wi->dpy, Tk_WindowId(wi->win),
		      bits->width, bits->height, Tk_Depth(wi->win));
  gc = XCreateGC(wi->dpy, pmap, 0, NULL);
  XSetForeground(wi->dpy, gc, 0);
  XFillRectangle(wi->dpy, pmap, gc, 0, 0, bits->width, bits->height);
  Tk_RedrawImage(bits->tkimage, 0, 0, bits->width, bits->height, pmap, 0, 0);
  im1 = XGetImage(wi->dpy, pmap, 0, 0, bits->width, bits->height, ~0L, ZPixmap);
  
  XSetForeground(wi->dpy, gc, 1);
  XFillRectangle(wi->dpy, pmap, gc, 0, 0, bits->width, bits->height);
  Tk_RedrawImage(bits->tkimage, 0, 0, bits->width, bits->height, pmap, 0, 0);
  im2 = XGetImage(wi->dpy, pmap, 0, 0, bits->width, bits->height, ~0L, ZPixmap);
  Tk_FreePixmap(wi->dpy, pmap);
  XFreeGC(wi->dpy, gc);

  bits->valid_region = TkCreateRegion();

  for (y = 0; y < bits->height; y++) {
    x = 0;
    while (x < bits->width) {
      while ((x < bits->width) &&
	     (XGetPixel(im1, x, y) != XGetPixel(im2, x, y))) {
	/* Search the first non-transparent pixel */
	x++;
      }
      end = x;
      while ((end < bits->width) &&
	     (XGetPixel(im1, end, y) == XGetPixel(im2, end, y))) {
	/* Search the first transparent pixel */
	end++;
      }
      if (end > x) {
	rect.x = x;
	rect.y = y;
	rect.width = end - x;
	rect.height = 1;
	TkUnionRectWithRegion(&rect, bits->valid_region, bits->valid_region);
      }
      x = end;
    }
  }
  
  XDestroyImage(im1);
  XDestroyImage(im2);
}

TkRegion
ZnImageRegion(ZnImage	image)
{
  if (ZnImageIsBitmap(image)) {
    return NULL;
  }
  else {
    ImageBits	*bits = ((Image) image)->bits;
#ifdef PTK
    if (!bits->valid_region) {
      BuildImageRegion(bits);
    }
    return bits->valid_region;
#else
    if (bits->tkphoto) {
      return TkPhotoGetValidRegion(bits->tkphoto);
    }
    else {
      if (!bits->valid_region) {
	BuildImageRegion(bits);
      }
      return bits->valid_region;
    }
#endif
  }
}


/*
 **********************************************************************************
 *
 * ZnImageTex --
 *
 **********************************************************************************
 */
#ifdef GL
/*
 * Working only for 16 bits displays with 5r6g5b mask,
 * and 24/32 bits displays. Byte ordering ok on Intel
 * plateform only.
 */
static void
From5r6g5b(unsigned char *data,
	   int		 width,
	   int		 height,
	   int		 bytes_per_line,
	   unsigned char *t_bits,
	   int		 t_width,
	   int		 t_height,
	   TkRegion	 valid_region)
{
  int		x, y;
  int		rowstride = t_width * 4;
  unsigned char	*obptr;
  unsigned char	*bptr, *bp2;
  unsigned char	alpha;
  unsigned short temp;

  bptr = t_bits;
  
  for (y = 0; y < height; y++) {
    bp2 = bptr;
    obptr = data;
    for (x = 0; x < width; x++) {
      /*
       * Configure the alpha value.
       */
      alpha = ZnPointInRegion(valid_region, x, y) ? 255 : 0;

      /*
       * Dispatch the 3 color components.
       */
      temp = ((unsigned short *)obptr)[0];
      *bp2 = (temp >> 8) & 0xf8; /* r */
      bp2++;
      *bp2 = (temp >> 3) & 0xfc; /* v */
      bp2++;
      *bp2 = (temp << 3);	 /* b */
      bp2++;
      *bp2 = alpha;
      bp2++;
      obptr += 2;
    }
    for (x = width; x < t_width; x++) {
      *bp2 = 0;
      bp2++;
      *bp2 = 0;
      bp2++;
      *bp2 = 0;
      bp2++;
      *bp2 = 0;
      bp2++;
    }
    bptr += rowstride;
    data += bytes_per_line;
  }
  for (y = height; y < t_height; y++) {
    memset(bptr, 0, rowstride);
    bptr += rowstride;
  }
}

static void
From8r8g8b(unsigned char *data,
	   int		 width,
	   int		 height,
	   int		 bytes_per_line,
	   unsigned char *t_bits,
	   int		 t_width,
	   int		 t_height,
	   TkRegion	 valid_region)
{
  int		x, y;
  int		rowstride = t_width * 4;
  unsigned char	*obptr;
  unsigned char	*bptr, *bp2;
  unsigned char	alpha;

  bptr = t_bits;
  
  for (y = 0; y < height; y++) {
    bp2 = bptr;
    obptr = data;
    for (x = 0; x < width; x++) {
      /*
       * Configure the alpha value.
       */
      alpha = ZnPointInRegion(valid_region, x, y) ? 255 : 0;

      /*
       * Dispatch the 3 color components.
       * Be careful the Red and Blue are swapped it works on an Intel
       * plateform but may need some more tests to be fully generic.
       */
      *bp2++ = obptr[2]; /* r */
      *bp2++ = obptr[1]; /* v */
      *bp2++ = obptr[0]; /* b */
      obptr += 4;
      *bp2++ = alpha;
    }
    for (x = width; x < t_width; x++) {
      *bp2 = 0;
      bp2++;
      *bp2 = 0;
      bp2++;
      *bp2 = 0;
      bp2++;
      *bp2 = 0;
      bp2++;
    }
    bptr += rowstride;
    data += bytes_per_line;
  }
  for (y = height; y < t_height; y++) {
    memset(bptr, 0, rowstride);
    bptr += rowstride;
  }
}

static void
GatherImageTexels(ImageBits	*bits)
{
  Pixmap	pmap;
  XImage	*im;
  TkRegion	valid_region;
  int		t_size, depth;
  ZnWInfo	*wi = bits->wi;

  /*printf("GatherImageTexels: %s\n", ZnNameOfImage(bits->images));*/
  valid_region = ZnImageRegion(bits->images);

  t_size = bits->t_width * 4 * bits->t_height;
  bits->t_bits = ZnMalloc(t_size);  
  depth = Tk_Depth(wi->win);

  pmap = Tk_GetPixmap(wi->dpy, Tk_WindowId(wi->win),
		      bits->width, bits->height, depth);
  Tk_RedrawImage(bits->tkimage, 0, 0, bits->width, bits->height, pmap, 0, 0);
  im = XGetImage(wi->dpy, pmap, 0, 0, bits->width, bits->height, ~0L, ZPixmap);
  Tk_FreePixmap(wi->dpy, pmap);

  if (depth == 16) {
    From5r6g5b(im->data, bits->width, bits->height, im->bytes_per_line,
	       bits->t_bits, bits->t_width, bits->t_height, valid_region);
  }
  else if ((depth == 24) || (depth == 32)) {
    From8r8g8b(im->data, bits->width, bits->height, im->bytes_per_line,
	       bits->t_bits, bits->t_width, bits->t_height, valid_region);
  }

  XDestroyImage(im);
}

GLuint
ZnImageTex(ZnImage	image,
	   ZnReal	*t,
	   ZnReal	*s)
{
  Image		this = (Image) image;
  ImageBits	*bits = this->bits;
  ZnBool	is_bmap = ZnImageIsBitmap(image);
  unsigned int	t_size, width, height;

  if (!this->for_gl) {
    printf("Bogus use of an image, it was created for X11 and used in a GL context\n");
    return 0;
  }
  ZnSizeOfImage(image, &width, &height);
  if (!bits->t_bits) {
    /*printf("chargement texture pour image %s\n", ZnNameOfImage(this));*/
    bits->t_width = To2Power((int) width);
    bits->t_height = To2Power((int) height);
    bits->s = width / (ZnReal) bits->t_width;
    bits->t = height / (ZnReal) bits->t_height;

    /*
     * This is a bitmap: use the pixels stored in bpixels.
     */
    if (is_bmap) {
      unsigned int  i, j;
      unsigned char *ostart, *dstart, *d, *o;

      t_size = bits->t_width * bits->t_height;
      bits->t_bits = ZnMalloc(t_size);
      memset(bits->t_bits, 0, t_size);
      ostart = bits->bpixels;
      dstart = bits->t_bits;
      for (i = 0; i < height; i++) {
	d = dstart;
	o = ostart;
	for (j = 0; j < width; j++) {
	  *d++ = ZnGetBitmapPixel(bits->bpixels, bits->rowstride, j, i) ? 255 : 0;
	}
	ostart += bits->rowstride;
	dstart += bits->t_width;
      }
    }

    /*
     * This is a photo: use the photo API, it is simple.
     */
    else if (bits->tkphoto) {
      unsigned int	 x, y, t_stride;
      unsigned char	 *obptr, *bptr, *bp2, *pixels;
      int		 green_off, blue_off, alpha_off;
      Tk_PhotoImageBlock block;

      t_stride = bits->t_width * 4;
      t_size = t_stride * bits->t_height;
      bits->t_bits = ZnMalloc(t_size);
      Tk_PhotoGetImage(bits->tkphoto, &block);
      green_off = block.offset[1] - block.offset[0];
      blue_off = block.offset[2] - block.offset[0];
#ifdef PTK
      alpha_off = 3;
#else
      alpha_off = block.offset[3] - block.offset[0];
#endif
      /*printf("width %d, height: %d redoff: %d, greenoff: %d, blueoff: %d, alphaoff: %d\n",
	     block.width, block.height, block.offset[0], green_off,
	     blue_off, alpha_off);*/
      pixels = block.pixelPtr;
      bptr = bits->t_bits;
  
      for (y = 0; y < height; y++) {
	bp2 = bptr;
	obptr = pixels;
	for (x = 0; x < width; x++) {
	  *bp2++ = obptr[0];	     /* r */
	  *bp2++ = obptr[green_off]; /* g */
	  *bp2++ = obptr[blue_off];  /* b */
	  *bp2++ = obptr[alpha_off]; /* alpha */
	  obptr += block.pixelSize;
	}
	/*for (x = width; x < t_width; x++) {
	  *bp2 = 0; bp2++;
	  *bp2 = 0; bp2++;
	  *bp2 = 0; bp2++;
	  *bp2 = 0; bp2++;
	  }*/
	bptr += t_stride;
	pixels += block.pitch;
      }
      /*for (y = height; y < t_height; y++) {
	memset(bptr, 0, t_stride);
	bptr += t_stride;
	}*/
    }

    /*
     * This is another image format (not a photo): try to
     * guess the pixels and the transparency (on or off)
     * from a locally drawn pixmap.
     */
    else {
      GatherImageTexels(bits);
    }
  }

  if (!this->i.texobj) {
    glGenTextures(1, &this->i.texobj);
    /*printf("creation texture %d pour image %s\n",
      this->i.texobj, ZnNameOfImage(this));*/
    glBindTexture(GL_TEXTURE_2D, this->i.texobj);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glGetError();
    if (is_bmap) {
      glTexImage2D(GL_TEXTURE_2D, 0, GL_INTENSITY4,
		   this->bits->t_width, this->bits->t_height,
		   0, GL_LUMINANCE, GL_UNSIGNED_BYTE, this->bits->t_bits);
    }
    else {
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,
		   this->bits->t_width, this->bits->t_height,
		   0, GL_RGBA, GL_UNSIGNED_BYTE, this->bits->t_bits);
    }
    if (glGetError() != GL_NO_ERROR) {
      ZnWarning("Can't allocate the texture for image ");
      ZnWarning(ZnNameOfImage(image));
      ZnWarning("\n");
    }
    glBindTexture(GL_TEXTURE_2D, 0);
  }

  *t = this->bits->t;
  *s = this->bits->s;
  return this->i.texobj;
}
#endif


#ifdef GL
/* This code is adapted from a work Copyright (c) Mark J. Kilgard, 1997. */

/* This program is freely distributable without licensing fees  and is
   provided without guarantee or warrantee expressed or  implied. This
   program is -not- in the public domain. */

#define MAX_CHAR 255
#define MIN_CHAR 32
#define MAX_GLYPHS_PER_GRAB 256

typedef struct {
  unsigned char c;
  char		dummy;	/* Space holder for alignment reasons. */
  short		width;
  short		 height;
  short		xoffset;
  short		yoffset;
  short		advance;
  short		x;
  short		y;
} TexGlyphInfo;

typedef struct _TexFontInfo {
  GLuint	texobj;
  struct _TexFont *txf;
  ZnWInfo	*wi;
  unsigned int	refcount;
  struct _TexFontInfo *next;
} TexFontInfo;

typedef struct _TexFont {
  TexFontInfo	*tfi;
  Tk_Font	tkfont;
  int		tex_width;
  int		tex_height;
  int		ascent;
  int		descent;
  unsigned int	num_glyphs;
  unsigned int	min_glyph;
  unsigned int	range;
  unsigned char *teximage;
  TexGlyphInfo	*tgi;
  ZnTexGVI	*tgvi;
  ZnTexGVI	**lut;
  Tcl_HashEntry	*hash;
} TexFont;

typedef struct {
  short		width;
  short		height;
  short		xoffset;
  short		yoffset;
  short		advance;
  unsigned char	*bitmap;
} PerGlyphInfo, *PerGlyphInfoPtr;

typedef struct {
  int		min_char;
  int		max_char;
  int		ascent;
  int		descent;
  unsigned int	num_glyphs;
  PerGlyphInfo	glyph[1];
} FontInfo, *FontInfoPtr;

static FontInfoPtr	fontinfo;

void
getMetric(FontInfoPtr	font,
	  int		c,
	  TexGlyphInfo	*tgi)
{
  PerGlyphInfoPtr	glyph;
  unsigned char		*bitmapData;

  tgi->c = c;
  if ((c < font->min_char) || (c > font->max_char)) {
    tgi->width = 0;
    tgi->height = 0;
    tgi->xoffset = 0;
    tgi->yoffset = 0;
    tgi->dummy = 0;
    tgi->advance = 0;
    return;
  }
  glyph = &font->glyph[c - font->min_char];
  bitmapData = glyph->bitmap;
  if (bitmapData) {
    tgi->width = glyph->width;
    tgi->height = glyph->height;
    tgi->xoffset = glyph->xoffset;
    tgi->yoffset = glyph->yoffset;
  }
  else {
    tgi->width = 0;
    tgi->height = 0;
    tgi->xoffset = 0;
    tgi->yoffset = 0;
  }
  tgi->dummy = 0;
  /*printf("\'%c\' %X %d\n", c, c, glyph->advance);*/
  tgi->advance = glyph->advance;
}

int
glyphCompare(const void	*a,
	     const void	*b)
{
  unsigned char *c1 = (unsigned char *) a;
  unsigned char	*c2 = (unsigned char *) b;
  TexGlyphInfo	tgi1;
  TexGlyphInfo	tgi2;

  getMetric(fontinfo, *c1, &tgi1);
  getMetric(fontinfo, *c2, &tgi2);
  return tgi2.height - tgi1.height;
}

void
placeGlyph(FontInfoPtr	font,
	   int		c,
	   unsigned char *texarea,
	   unsigned int	stride,
	   int		x,
	   int		y)
{
  PerGlyphInfoPtr	glyph;
  unsigned char		*bitmapData;
  int			width, height, spanLength;
  int			i, j;

  /*printf("x: %d, y: %d, c: %d, texarea: 0x%X, stride: %d\n",
    x, y, c, texarea, stride);*/
  if ((c < font->min_char) || (c > font->max_char)) {
    return;
  }
  glyph = &font->glyph[c - font->min_char];
  bitmapData = glyph->bitmap;
  if (bitmapData) {
    width = glyph->width;
    spanLength = (width + 7) / 8;
    height = glyph->height;
    for (i = 0; i < height; i++) {
      for (j = 0; j < width; j++) {
	texarea[stride * (y+i) + x + j] = (bitmapData[i*spanLength + j/8] & (1<<(j&7))) ? 255 : 0;
      }
    }
  }
}

FontInfoPtr
SuckGlyphsFromServer(ZnWInfo	*wi,
		     Tk_Font	font)
{
  Pixmap	offscreen = 0;
  XImage	*image = NULL;
  GC		xgc = 0;
  XGCValues	values;
  unsigned int	width, height, length, pixwidth;
  unsigned int	i, j;
  char		str[] = " ";
  unsigned char	*bitmapData = NULL;
  unsigned int	x, y;
  int		num_chars, spanLength=0;
  unsigned int	charWidth=0, maxSpanLength;
  int		grabList[MAX_GLYPHS_PER_GRAB];
  unsigned int	glyphsPerGrab = MAX_GLYPHS_PER_GRAB;
  unsigned int	numToGrab, thisglyph;
  FontInfoPtr	myfontinfo = NULL;
  Tk_FontMetrics fm;

  Tk_GetFontMetrics(font, &fm);
  num_chars = (MAX_CHAR-MIN_CHAR)+1;
  myfontinfo = ZnMalloc(sizeof(FontInfo) + num_chars * sizeof(PerGlyphInfo));
  if (!myfontinfo) {
    ZnWarning("Out of memory, ");
    return NULL;
  }

  myfontinfo->min_char = MIN_CHAR;
  myfontinfo->max_char = MAX_CHAR;
  myfontinfo->num_glyphs = num_chars;
  myfontinfo->ascent = fm.ascent;
  myfontinfo->descent = fm.descent;

  /*
   * Compute the max character size in the font. This may be
   * a bit heavy hammer style but it avoid guessing on characters
   * not available in the font.
   */
  width = 0;
  for (i = 0; i < myfontinfo->num_glyphs; i++) {
    *str = i + myfontinfo->min_char;
    Tk_MeasureChars(font, str, 1, 0, TK_AT_LEAST_ONE, &length);
    width = MAX(width, length);
  }

  if (width == 0) {
    /*
     * Something weird with the font, abort!
     */
    ZnWarning("NULL character width, ");
    goto FreeFontInfoAndReturn;
  }
  height = myfontinfo->ascent + myfontinfo->descent;

  maxSpanLength = (width + 7) / 8;
  /* Be careful determining the width of the pixmap; the X protocol allows
     pixmaps of width 2^16-1 (unsigned short size) but drawing coordinates
     max out at 2^15-1 (signed short size).  If the width is too large, we
     need to limit the glyphs per grab.  */
  if ((glyphsPerGrab * 8 * maxSpanLength) >= (1 << 15)) {
    glyphsPerGrab = (1 << 15) / (8 * maxSpanLength);
  }
  pixwidth = glyphsPerGrab * 8 * maxSpanLength;
  offscreen = Tk_GetPixmap(wi->dpy, RootWindowOfScreen(wi->screen),
			   (int) pixwidth, (int) height, 1);
  
  values.background = WhitePixelOfScreen(wi->screen);
  values.foreground = WhitePixelOfScreen(wi->screen);
  values.font = Tk_FontId(font);
  xgc = XCreateGC(wi->dpy, offscreen, GCBackground|GCForeground|GCFont, &values);
  XFillRectangle(wi->dpy, offscreen, xgc, 0, 0, pixwidth, height);
  values.foreground = BlackPixelOfScreen(wi->screen);
  XChangeGC(wi->dpy, xgc, GCForeground, &values);

  numToGrab = 0;
  for (i = 0; i < myfontinfo->num_glyphs; i++) {
    *str = i + myfontinfo->min_char;
    Tk_MeasureChars(font, str, 1, 0, TK_AT_LEAST_ONE, &charWidth);

    myfontinfo->glyph[i].width = charWidth;
    myfontinfo->glyph[i].height = height;
    myfontinfo->glyph[i].xoffset = 0;
    myfontinfo->glyph[i].yoffset = myfontinfo->descent;
    myfontinfo->glyph[i].advance = charWidth;
    myfontinfo->glyph[i].bitmap = NULL;
    if (charWidth != 0) {
      Tk_DrawChars(wi->dpy, offscreen, xgc, font, str, 1, 
		   (int) (8*maxSpanLength*numToGrab), myfontinfo->ascent);
      grabList[numToGrab] = i;    
      numToGrab++;
    }

    if ((numToGrab >= glyphsPerGrab) || (i == myfontinfo->num_glyphs - 1)) {
      image = XGetImage(wi->dpy, offscreen, 0, 0, pixwidth, height, 1, XYPixmap);

      for (j = 0; j < numToGrab; j++) {
	thisglyph = grabList[j];
	charWidth = myfontinfo->glyph[thisglyph].width;
	spanLength = (charWidth + 7) / 8;
	bitmapData = ZnMalloc(height * spanLength * sizeof(char));
	if (bitmapData == NULL) {
	  ZnWarning("Out of memory, ");
	  goto FreeFontAndReturn;
	}
	memset(bitmapData, 0, height * spanLength * sizeof(char));
	myfontinfo->glyph[thisglyph].bitmap = bitmapData;
	for (y = 0; y < height; y++) {
	  for (x = 0; x < charWidth; x++) {
	    /* XXX The algorithm used to suck across the font ensures that
	       each glyph begins on a byte boundary.  In theory this would
	       make it convienent to copy the glyph into a byte oriented
	       bitmap.  We actually use the XGetPixel function to extract
	       each pixel from the image which is not that efficient.  We
	       could either do tighter packing in the pixmap or more
	       efficient extraction from the image.  Oh well.  */
	    if (XGetPixel(image, (int) (j*maxSpanLength*8) + x, y) == BlackPixelOfScreen(wi->screen)) {
	      bitmapData[y * spanLength + x / 8] |= (1 << (x & 7));
	    }
	  }
	}
      }
      XDestroyImage(image);
      numToGrab = 0;
      /* do we need to clear the offscreen pixmap to get more? */
      if (i < myfontinfo->num_glyphs - 1) {
	values.foreground = WhitePixelOfScreen(wi->screen);
	XChangeGC(wi->dpy, xgc, GCForeground, &values);
	XFillRectangle(wi->dpy, offscreen, xgc, 0, 0,
		       8 * maxSpanLength * glyphsPerGrab, height);
	values.foreground = BlackPixelOfScreen(wi->screen);
	XChangeGC(wi->dpy, xgc, GCForeground, &values);
      }
    }
  }

  XFreeGC(wi->dpy, xgc);
  Tk_FreePixmap(wi->dpy, offscreen);
  return myfontinfo;

 FreeFontAndReturn:
  XDestroyImage(image);
  XFreeGC(wi->dpy, xgc);
  Tk_FreePixmap(wi->dpy, offscreen);
  for (i = 0; i < myfontinfo->num_glyphs; i++) {
    if (myfontinfo->glyph[i].bitmap)
      ZnFree(myfontinfo->glyph[i].bitmap);
  }
 FreeFontInfoAndReturn:
  ZnFree(myfontinfo);
  return NULL;
}

/*
 **********************************************************************************
 *
 * ZnGetTexFont --
 *
 **********************************************************************************
 */
ZnTexFontInfo
ZnGetTexFont(ZnWInfo	*wi,
	     Tk_Font	font)
{
  TexFont	*txf;
  TexFontInfo	*tfi;
  static int	inited = 0;
  Tcl_HashEntry	*entry;
  int		new;
  unsigned char *glist=NULL, *glist2=NULL;
  TexGlyphInfo	*tgi;
  unsigned int	i, j;
  int		min_glyph, max_glyph;
  int		gap = 1; /* gap between glyphs */
  int		px, py, maxheight;
  int		width, height;
  unsigned int	texw, texh;
  GLfloat	xstep, ystep;

  if (!inited) {
    Tcl_InitHashTable(&font_textures, TCL_ONE_WORD_KEYS);
    inited = 1;
  }

  entry = Tcl_FindHashEntry(&font_textures, (char *) font);
  if (entry != NULL) {
    txf = (TexFont *) Tcl_GetHashValue(entry);
  }
  else {
    /*printf("Loading a new texture font for %s\n", Tk_NameOfFont(font));*/
    txf = ZnMalloc(sizeof(TexFont));
    if (txf == NULL) {
      return NULL;
    }
    txf->tfi = NULL;
    txf->tgi = NULL;
    txf->tgvi = NULL;
    txf->lut = NULL;
    /* Get a local reference to the font, it will be deallocated
     * when no further references on this TexFont exist. */
    txf->tkfont = Tk_GetFont(wi->interp, wi->win, Tk_NameOfFont(font));

    /*printf("Chargement de la texture pour la fonte %s\n",
      ZnNameOfTexFont(tfi));*/
    fontinfo = SuckGlyphsFromServer(wi, txf->tkfont);
    if (fontinfo == NULL) {
      goto error;
    }
    txf->ascent = fontinfo->ascent;
    txf->descent = fontinfo->descent;
    /*
     * Try to use all glyphs in a font except the first 32
     * control chars.
     */
    txf->num_glyphs = MAX_CHAR-MIN_CHAR+1;

    /*
     * Initial size of texture.
     */
    texw = wi->max_tex_size;
    texh = 64;
    while (texh < (unsigned int) (txf->ascent+txf->descent)) {
      texh *= 2;
    }
    /*printf("Taille r�elle de texture utilis�e: %d\n", wi->max_tex_size);*/
    /*
     * This is temporarily disabled until we find out
     * how to reliably get max_tex_size up front without
     * waiting for the window mapping.
     */
    if (texh > wi->max_tex_size) {
      goto error;
    }
    xstep = 0/*0.5 / texw*/;
    ystep = 0/*0.5 / texh*/;
    
    txf->teximage = ZnMalloc(texw * texh * sizeof(unsigned char));
    if (txf->teximage == NULL) {
      goto error;
    }

    txf->tgi = ZnMalloc(txf->num_glyphs * sizeof(TexGlyphInfo));
    if (txf->tgi == NULL) {
      goto error;
    }
    txf->tgvi = ZnMalloc(txf->num_glyphs * sizeof(ZnTexGVI));
    if (txf->tgvi == NULL) {
      goto error;
    }
    
    glist = ZnMalloc((txf->num_glyphs+1) * sizeof(unsigned char));
    for (i = 0; i < txf->num_glyphs; i++) {
      glist[i] = i+MIN_CHAR;
    }
    glist[txf->num_glyphs] = 0;
    qsort(glist, txf->num_glyphs, sizeof(unsigned char), glyphCompare);
    /*
     * Keep a cache a the sorted list in case we need to
     * restart the allocation process.
     */
    glist2 = ZnMalloc((txf->num_glyphs+1) * sizeof(unsigned char));
    strcpy(glist2, glist);

  restart:
    px = gap;
    py = gap;
    maxheight = 0;
    for (i = 0; i < txf->num_glyphs; i++) {
      if (glist[i] != 0) {  /* If not already processed... */
	int foundWidthFit = 0;
	int c;
	
	/* Try to find a character from the glist that will fit on the
	   remaining space on the current row. */
	tgi = &txf->tgi[i];
	getMetric(fontinfo, glist[i], tgi);
	width = tgi->width;
	height = tgi->height;

	if ((height > 0) && (width > 0)) {
	  for (j = i; j < txf->num_glyphs;) {
	    if ((height > 0) && (width > 0)) {
	      if ((unsigned int) (px + width + gap) < texw) {
		foundWidthFit = 1;
		if (j != i) {
		  i--;  /* Step back so i loop increment leaves us at same character. */
		}
		break;
	      }
	    }
	    do {
	      j++;
	    } while (glist[j] == 0);
	    if (j < txf->num_glyphs) {
	      tgi = &txf->tgi[j];
	      getMetric(fontinfo, glist[j], tgi);
	      width = tgi->width;
	      height = tgi->height;
	    }
	  }
	  
	  /* If a fit was found, use that character; otherwise
	   * advance a line in the texture. */
	  if (foundWidthFit) {
	    if (height > maxheight) {
	      maxheight = height;
	    }
	    c = j;
	  }
	  else {
	    tgi = &txf->tgi[i];
	    getMetric(fontinfo, glist[i], tgi);
	    width = tgi->width;
	    height = tgi->height;
	    
	    py += maxheight + gap;
	    px = gap;
	    maxheight = height;
	    if ((unsigned int) (py + height + gap) >= texh) {
	      if (texh*2 < wi->max_tex_size) {
		texh *= 2;
		ZnFree(txf->teximage);
		txf->teximage = ZnMalloc(texw * texh * sizeof(unsigned char));
		strcpy(glist, glist2);
		goto restart;
	      }
	      else if (texw*2 < wi->max_tex_size) {
		texw *= 2;
		ZnFree(txf->teximage);
		txf->teximage = ZnMalloc(texw * texh * sizeof(unsigned char));
		strcpy(glist, glist2);
		goto restart;
	      }
	      else {
		/* Overflowed texture space */
		goto error;
	      }
	    }
	    c = i;
	  }
	  
	  /* Place the glyph in the texture image. */
	  placeGlyph(fontinfo, glist[c], txf->teximage, texw, px, py);
	  
	  /* Assign glyph's texture coordinate. */
	  tgi->x = px;
	  tgi->y = py;

	  /* Advance by glyph width, remaining in the current line. */
	  px += width + gap;
	}
	else {
	  /* No texture image; assign invalid bogus texture coordinates. */
	  tgi->x = -1;
	  tgi->y = -1;
	  c = i;
	}
	glist[c] = 0;     /* Mark processed; don't process again. */
	txf->tgvi[c].t0[0] = tgi->x / ((GLfloat) texw) + xstep;
	txf->tgvi[c].t0[1] = tgi->y / ((GLfloat) texh) + ystep;
	txf->tgvi[c].v0[0] = tgi->xoffset;
	txf->tgvi[c].v0[1] = tgi->yoffset - tgi->height;
	txf->tgvi[c].t1[0] = (tgi->x + tgi->width) / ((GLfloat) texw) + xstep;
	txf->tgvi[c].t1[1] = tgi->y / ((GLfloat) texh) + ystep;
	txf->tgvi[c].v1[0] = (tgi->xoffset + tgi->width);
	txf->tgvi[c].v1[1] = tgi->yoffset - tgi->height;
	txf->tgvi[c].t2[0] = (tgi->x + tgi->width) / ((GLfloat) texw) + xstep;
	txf->tgvi[c].t2[1] = (tgi->y + tgi->height) / ((GLfloat) texh) + ystep;
	txf->tgvi[c].v2[0] = (tgi->xoffset + tgi->width);
	txf->tgvi[c].v2[1] = tgi->yoffset;
	txf->tgvi[c].t3[0] = tgi->x / ((GLfloat) texw) + xstep;
	txf->tgvi[c].t3[1] = (tgi->y + tgi->height) / ((GLfloat) texh) + ystep;
	txf->tgvi[c].v3[0] = tgi->xoffset;
	txf->tgvi[c].v3[1] = tgi->yoffset;
	txf->tgvi[c].advance = tgi->advance;
      }
    }
    
    min_glyph = txf->tgi[0].c;
    max_glyph = txf->tgi[0].c;
    for (i = 1; i < txf->num_glyphs; i++) {
      if (txf->tgi[i].c < min_glyph) {
	min_glyph = txf->tgi[i].c;
      }
      if (txf->tgi[i].c > max_glyph) {
	max_glyph = txf->tgi[i].c;
      }
    }
    txf->tex_width = texw;
    txf->tex_height = texh;
    /*printf("texture width: %g, texture height: %g\n", texw, texh);
    printf("min glyph: (%d) \"%c\", max glyph: (%d) \"%c\"\n",
    min_glyph, min_glyph, max_glyph, max_glyph);*/
    txf->min_glyph = min_glyph;
    txf->range = max_glyph - min_glyph + 1;
    
    txf->lut = ZnMalloc(txf->range * sizeof(ZnTexGVI *));
    if (txf->lut == NULL) {
    error:
      if (glist) {
	ZnFree(glist);
      }
      if (glist2) {
	ZnFree(glist2);
      }
      if (fontinfo) {
	for (i = 0; i < fontinfo->num_glyphs; i++) {
	  if (fontinfo->glyph[i].bitmap)
	    ZnFree(fontinfo->glyph[i].bitmap);
	}
	ZnFree(fontinfo);
      }
      if (txf->tgi) {
	ZnFree(txf->tgi);
	txf->tgi = NULL;
      }
      if (txf->tgvi) {
	ZnFree(txf->tgvi);
	txf->tgvi = NULL;
      }
      if (txf->lut) {
	ZnFree(txf->lut);
	txf->lut = NULL;
      }
      if (txf->teximage) {
	ZnFree(txf->teximage);
	txf->teximage = NULL;
      }
      ZnFree(txf);
      ZnWarning("Cannot load font texture for font ");
      ZnWarning(Tk_NameOfFont(font));
      ZnWarning("\n");
      return 0;
    }

    memset(txf->lut, 0, txf->range * sizeof(ZnTexGVI *));
    for (i = 0; i < txf->num_glyphs; i++) {
      txf->lut[txf->tgi[i].c - txf->min_glyph] = &txf->tgvi[i];
    }

    for (i = 0; i < fontinfo->num_glyphs; i++) {
      if (fontinfo->glyph[i].bitmap)
	ZnFree(fontinfo->glyph[i].bitmap);
    }
    ZnFree(fontinfo);
    ZnFree(glist);
    ZnFree(glist2);

    entry = Tcl_CreateHashEntry(&font_textures, (char *) font, &new);
    Tcl_SetHashValue(entry, (ClientData) txf);
    txf->hash = entry;
  }
      
  /*
   * Now locate the texture obj in the texture list for this widget.
   */
  for (tfi = txf->tfi; tfi != NULL; tfi = tfi->next) {
    if (tfi->wi == wi) {
      tfi->refcount++;
      return tfi;
    }
  }
  /*
   * Not found allocate a new texture object.
   */
  tfi = ZnMalloc(sizeof(TexFontInfo));
  if (tfi == NULL) {
    ZnFree(txf);
    return NULL;
  }
  tfi->refcount = 1;
  tfi->texobj = 0;
  tfi->wi = wi;
  tfi->txf = txf;
  tfi->next = txf->tfi;
  txf->tfi = tfi;

  return tfi;
}


/*
 **********************************************************************************
 *
 * ZnNameOfTexFont --
 *
 **********************************************************************************
 */
char const *
ZnNameOfTexFont(ZnTexFontInfo	tfi)
{
  return Tk_NameOfFont(((TexFontInfo *) tfi)->txf->tkfont);
}

/*
 **********************************************************************************
 *
 * ZnTexFontTex --
 *
 **********************************************************************************
 */
GLuint
ZnTexFontTex(ZnTexFontInfo	tfi)
{
  TexFontInfo	*this = (TexFontInfo *) tfi;
  TexFont	*txf = this->txf;

  if (!this->texobj) {
    glGenTextures(1, &this->texobj);
    /*printf("%d creation texture %d pour la fonte %s\n",
      this->wi, this->texobj, ZnNameOfTexFont(tfi));*/
    glBindTexture(GL_TEXTURE_2D, this->texobj);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glGetError();
    /*printf("Demande texture de %d x %d\n", txf->tex_width, txf->tex_height);*/
    glTexImage2D(GL_TEXTURE_2D, 0, GL_INTENSITY4, txf->tex_width,
		 txf->tex_height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE,
		 txf->teximage);
    if (glGetError() != GL_NO_ERROR) {
      ZnWarning("Can't allocate the texture for font ");
      ZnWarning(ZnNameOfTexFont(tfi));
      ZnWarning("\n");
    }
    glBindTexture(GL_TEXTURE_2D, 0);
  }

  /*printf("%d utilisation de la texture %d\n", this->wi, this->texobj);*/
  return this->texobj;
}


/*
 **********************************************************************************
 *
 * ZnFreeTexFont --
 *
 **********************************************************************************
 */
void
ZnFreeTexFont(ZnTexFontInfo	tfi)
{
  TexFontInfo	*this = ((TexFontInfo *) tfi);
  ZnWInfo	*wi = this->wi;
  TexFont	*txf = this->txf;
  TexFontInfo	*prev, *scan;

  for (prev=NULL, scan=this->txf->tfi; (scan!=NULL)&&(scan != this);
       prev=scan, scan=scan->next);
  if (scan != this) {
    return;
  }

  /*
   * Decrement tex font object refcount.
   */
  this->refcount--;
  if (this->refcount != 0) {
    return;
  }

  /*
   * Unlink the deleted tex font info.
   */
  if (prev == NULL) {
    txf->tfi = this->next;
  }
  else {
    prev->next = this->next;
  }
  if (this->texobj && wi->win) {
    /*printf("%d Lib�ration de la texture %d pour la fonte %s\n",
      wi, this->texobj, ZnNameOfTexFont(tfi));*/
    ZnGLMakeCurrent(wi);
    glDeleteTextures(1, &this->texobj);
    ZnGLRelease(wi);
  }

  /*
   * There is no more client for this font
   * deallocate the structures.
   */
  if (txf->tfi == NULL) {
    /*printf("%d destruction compl�te du txf pour %s\n", this, ZnNameOfTexFont(tfi));*/
    Tk_FreeFont(txf->tkfont);
    ZnFree(txf->tgi);
    ZnFree(txf->tgvi);
    ZnFree(txf->lut);
    ZnFree(txf->teximage);
    Tcl_DeleteHashEntry(txf->hash);
    ZnFree(txf);
  }

  ZnFree(this);
}

/*
 **********************************************************************************
 *
 * ZnCharInTexFont --
 *
 **********************************************************************************
 */
ZnBool
ZnCharInTexFont(ZnTexFontInfo	tfi,
		unsigned int	c)
{
  TexFont *txf = ((TexFontInfo *) tfi)->txf;

  if ((c >= txf->min_glyph) && (c < txf->min_glyph + txf->range)) {
    if (txf->lut[c - txf->min_glyph]) {
      return True;
    }
  }
  return False;
}

/*
 **********************************************************************************
 *
 * ZnTexFontGVI --
 *
 **********************************************************************************
 */
ZnTexGVI *
ZnTexFontGVI(ZnTexFontInfo tfi,
	     unsigned int  c)
{
  TexFont	*txf = ((TexFontInfo *) tfi)->txf;
  ZnTexGVI	*tgvi;

  /* Automatically substitute uppercase letters with lowercase if not
     uppercase available (and vice versa). */
  if ((c >= txf->min_glyph) && (c < txf->min_glyph + txf->range)) {
    tgvi = txf->lut[c - txf->min_glyph];
    if (tgvi) {
      return tgvi;
    }
    if (islower(c)) {
      c = toupper(c);
      if ((c >= txf->min_glyph) && (c < txf->min_glyph + txf->range)) {
        return txf->lut[c - txf->min_glyph];
      }
    }
    if (isupper(c)) {
      c = tolower(c);
      if ((c >= txf->min_glyph) && (c < txf->min_glyph + txf->range)) {
        return txf->lut[c - txf->min_glyph];
      }
    }
  }
  fprintf(stderr,
	  "Tried to access unavailable texture font character '%c'(\\0%o)\n",
	  c, c);
  return txf->lut[(int)'!' - txf->min_glyph];
}

#endif