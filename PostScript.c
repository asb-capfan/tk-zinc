/*
 * PostScript.c -- Implementation of PostScript driver.
 *
 * Authors		: Patrick Lecoanet.
 * Creation date	: Tue Jan 3 13:17:17 1995
 *
 * $Id: PostScript.c,v 1.15 2004/04/30 14:31:31 lecoanet Exp $
 */

/*
 *  Copyright (c) 2004 CENA, Patrick Lecoanet --
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

/*
 * This code is based on tkCanvPs.c which is copyright:
 *
 * Copyright (c) 1991-1994 The Regents of the University of California.
 * Copyright (c) 1994-1997 Sun Microsystems, Inc.
 */

/*
 **********************************************************************************
 *
 * Included files
 *
 **********************************************************************************
 */

#if 0

#ifndef _WIN32
#include <unistd.h>
#include <pwd.h>
#endif
#include <stdio.h>
#include <sys/types.h>
#include <time.h>

#include "Item.h"
#include "Group.h"
#include "PostScript.h"
#include "WidgetInfo.h"
#include "Geo.h"


/*
 **********************************************************************************
 *
 * Constants.
 * 
 **********************************************************************************
 */

static	const char rcsid[] = "$Id: PostScript.c,v 1.15 2004/04/30 14:31:31 lecoanet Exp $";
static const char compile_id[]="$Compile: " __FILE__ " " __DATE__ " " __TIME__ " $";


#define PROLOG_VERSION	1.0
#define PROLOG_REVISION	0

static	char	ps_prolog[] = "";


typedef struct _ZnPostScriptInfo {
  ZnBBox	area;		/* Area to print, in device coordinates. */
  ZnReal	page_x;		/* PostScript coordinates of anchor on page */
  ZnReal	page_y;
  ZnReal	page_width;	/* Printed width and height of output area. */
  ZnReal	page_height;
  Tk_Anchor	page_anchor;	/* Area anchor on Postscript page. */
  ZnBool	landscape;	/* True means output is rotated ccw by 90 degrees
				 * (landscape mode). */
  char		*font_var;	/* If non-NULL, gives name of global variable
				 * containing font mapping information. Malloc'ed. */
  char		*color_var;	/* If non-NULL, give name of global variable
				 * containing color mapping information. Malloc'ed. */
  int		colormode;	/* Tell how color show be handled: 0 for mono,
				 * 1 for gray, 2 for color. */
  char		*filename;	/* Name of file in which to write PostScript; NULL
				 * means return Postscript info as result. Malloc'ed. */
  char		*channel_name;	/* If -channel is specified, the name of the channel
				 * to use. Malloc'ed */
  Tcl_Channel	chan;		/* Open channel corresponding to fileName. */
  Tcl_HashTable font_table;	/* Hash table containing names of all font families
				 * used in output. The table values are not used. */
  ZnBool	prepass;	/* True means that we're currently in
				 * the pre-pass that collects font information,
				 * so the PostScript generated isn't relevant. */
  ZnBool	prolog;		/* True means output should contain the file
				 * prolog.ps in the header. */
} ZnPostScriptInfo;


static int ZnPsDimParse _ANSI_ARGS_((ClientData client_data, Tcl_Interp *interp,
				     Tk_Window tkwin, Tcl_Obj *ovalue,
				     char *widget_rec, int offset));
static Tcl_Obj *ZnPsDimPrint _ANSI_ARGS_((ClientData client_data, Tk_Window tkwin,
					  char *widget_rec, int offset,
					  Tcl_FreeProc **free_proc));
static int ZnPsColorModeParse _ANSI_ARGS_((ClientData client_data, Tcl_Interp *interp,
					   Tk_Window tkwin, Tcl_Obj *ovalue,
					   char *widget_rec, int offset));
static Tcl_Obj *ZnPsColorModePrint _ANSI_ARGS_((ClientData client_data, Tk_Window tkwin,
						char *widget_rec, int offset,
						Tcl_FreeProc **free_proc));
static int ZnBBoxParse _ANSI_ARGS_((ClientData client_data, Tcl_Interp *interp,
				    Tk_Window tkwin, Tcl_Obj *ovalue,
				    char *widget_rec, int offset));
static	Tcl_Obj *ZnBBoxPrint _ANSI_ARGS_((ClientData client_data, Tk_Window tkwin,
					  char *widget_rec, int offset,
					  Tcl_FreeProc **free_proc));

static	Tk_CustomOption psDimOption = {
  (Tk_OptionParseProc *) ZnPsDimParse,
  (Tk_OptionPrintProc *) ZnPsDimPrint,
  NULL
};

static	Tk_CustomOption psColorModeOption = {
  (Tk_OptionParseProc *) ZnPsColorModeParse,
  (Tk_OptionPrintProc *) ZnPsColorModePrint,
  NULL
};

static	Tk_CustomOption bboxOption = {
  (Tk_OptionParseProc *) ZnBBoxParse,
  (Tk_OptionPrintProc *) ZnBBoxPrint,
  NULL
};

/*
 * Information used for argv parsing.
 */
static Tk_ConfigSpec config_specs[] = {
    {TK_CONFIG_CUSTOM, "-area", (char *) NULL, (char *) NULL,
	"", Tk_Offset(ZnPostScriptInfo, area), 0, &bboxOption},
    {TK_CONFIG_STRING, "-colormap", (char *) NULL, (char *) NULL,
	"", Tk_Offset(ZnPostScriptInfo, color_var), 0, NULL},
    {TK_CONFIG_CUSTOM, "-colormode", (char *) NULL, (char *) NULL,
	"", Tk_Offset(ZnPostScriptInfo, colormode), 0, &psColorModeOption},
    {TK_CONFIG_STRING, "-file", (char *) NULL, (char *) NULL,
	"", Tk_Offset(ZnPostScriptInfo, filename), 0, NULL},
    {TK_CONFIG_STRING, "-channel", (char *) NULL, (char *) NULL,
	"", Tk_Offset(ZnPostScriptInfo, channel_name), 0, NULL},
    {TK_CONFIG_STRING, "-fontmap", (char *) NULL, (char *) NULL,
	"", Tk_Offset(ZnPostScriptInfo, font_var), 0, NULL},
    {TK_CONFIG_BOOLEAN, "-landscape", (char *) NULL, (char *) NULL,
	"", Tk_Offset(ZnPostScriptInfo, landscape), 0, NULL},
    {TK_CONFIG_ANCHOR, "-pageanchor", (char *) NULL, (char *) NULL,
	"", Tk_Offset(ZnPostScriptInfo, page_anchor), 0, NULL},
    {TK_CONFIG_CUSTOM, "-pageheight", (char *) NULL, (char *) NULL,
	"", Tk_Offset(ZnPostScriptInfo, page_height), 0, &psDimOption},
    {TK_CONFIG_CUSTOM, "-pagewidth", (char *) NULL, (char *) NULL,
	"", Tk_Offset(ZnPostScriptInfo, page_width), 0, &psDimOption},
    {TK_CONFIG_CUSTOM, "-pagex", (char *) NULL, (char *) NULL,
	"", Tk_Offset(ZnPostScriptInfo, page_x), 0, &psDimOption},
    {TK_CONFIG_CUSTOM, "-pagey", (char *) NULL, (char *) NULL,
	"", Tk_Offset(ZnPostScriptInfo, page_y), 0, &psDimOption},
    {TK_CONFIG_BOOLEAN, "-prolog", (char *) NULL, (char *) NULL,
	"", Tk_Offset(ZnPostScriptInfo, prolog), 0, NULL},
    {TK_CONFIG_END, (char *) NULL, (char *) NULL, (char *) NULL,
	(char *) NULL, 0, 0, NULL}
};


/*
 *----------------------------------------------------------------------
 *
 * ZnPsDimParse
 * ZnPsDimPrint --
 *	Converter for the PostScript dimension options
 *      (-pagex, -pagey, -pagewidth, -pageheight).
 *
 *----------------------------------------------------------------------
 */
static int
ZnPsDimParse(ClientData	client_data __unused,
	     Tcl_Interp	*interp __unused,
	     Tk_Window	tkwin __unused,
	     Tcl_Obj	*ovalue,
	     char	*widget_rec,
	     int	offset)
{
  ZnReal *dim = (ZnReal *) (widget_rec + offset);
#ifdef PTK
  char	*value = Tcl_GetString(ovalue);
#else
  char	*value = (char *) ovalue;
#endif
  char	*end;
  double d;

  d = strtod(value, &end);
  if (end == value) {
  dim_error:
    Tcl_AppendResult(interp, "bad distance \"", value, "\"", NULL);
    return TCL_ERROR;
  }

  while ((*end != '\0') && isspace(UCHAR(*end))) {
    end++;
  }
  
  switch (*end) {
  case 'c':
    d *= 72.0/2.54;
    end++;
    break;
  case 'i':
    d *= 72.0;
    end++;
    break;
  case 'm':
    d *= 72.0/25.4;
    end++;
    break;
  case 0:
    break;
  case 'p':
    end++;
    break;
  default:
    goto dim_error;
  }

  while ((*end != '\0') && isspace(UCHAR(*end))) {
    end++;
  }
  if (*end != 0) {
    goto dim_error;
  }
  *dim = d;

  return TCL_OK;
}

static Tcl_Obj *
ZnPsDimPrint(ClientData	client_data __unused,
	     Tk_Window	tkwin __unused,
	     char	*widget_rec,
	     int	offset,
#ifdef PTK
	     Tcl_FreeProc **free_proc __unused
#else
	     Tcl_FreeProc **free_proc
#endif
)
{
  ZnReal *dim = (ZnReal *) (widget_rec + offset);
  Tcl_Obj *obj = Tcl_NewDoubleObj(*dim);
#ifdef PTK
  return obj;
#else
 {
   char *s1, *s2;

   *free_proc = TCL_DYNAMIC;
   s1 = Tcl_GetString(obj);
   s2 = ZnMalloc(strlen(s1) + 1);
   strcpy(s2, s1);
   Tcl_DecrRefCount(obj);
   return (Tcl_Obj *) s2;
 }
#endif
}

/*
 *----------------------------------------------------------------------
 *
 * ZnPsColorModeParse
 * ZnPsColorModePrint --
 *	Converter for the PostScript -colormode option.
 *
 *----------------------------------------------------------------------
 */
static int
ZnPsColorModeParse(ClientData	client_data __unused,
		   Tcl_Interp	*interp __unused,
		   Tk_Window	tkwin __unused,
		   Tcl_Obj	*ovalue,
		   char		*widget_rec,
		   int		offset)
{
  int	*mode = (int *) (widget_rec + offset);
#ifdef PTK
  char	*value = Tcl_GetString(ovalue);
#else
  char	*value = (char *) ovalue;
#endif
  int	result = TCL_OK;

  if (value != NULL) {
    if (strcmp(value, "monochrome") == 0) {
      *mode = 0;
    }
    else if (strcmp(value, "gray") == 0) {
      *mode = 1;
    }
    else if (strcmp(value, "color") == 0) {
      *mode = 2;
    }
    else {
      Tcl_AppendResult(interp, " incorrect PostScript color mode \"",
		       value, "\" should be \"monochrome\", \"gray\"",
		       " or \"color\"", NULL);
      result = TCL_ERROR;
    }
  }

  return result;
}

static Tcl_Obj *
ZnPsColorModePrint(ClientData	client_data __unused,
		   Tk_Window	tkwin __unused,
		   char		*widget_rec,
		   int		offset,
		   Tcl_FreeProc **free_proc __unused)
{
  int	*mode = (int *) (widget_rec + offset);
  char	*s;

  switch (*mode) {
  case 0: s = "monochrome";
    break;
  case 1: s = "gray";
    break;
  case 2: s = "color";   
    break;
  default: s = "PsColorModeInvalid";
    break;
  }
#ifdef PTK
  return Tcl_NewStringObj(s, -1);
#else
  return (Tcl_Obj *) s;
#endif
}

/*
 *----------------------------------------------------------------------
 *
 * ZnBBoxParse
 * ZnBBoxPrint --
 *	Converter for the -area option.
 *
 *----------------------------------------------------------------------
 */
static int
ZnBBoxParse(ClientData	client_data __unused,
	    Tcl_Interp	*interp __unused,
	    Tk_Window	tkwin __unused,
	    Tcl_Obj	*ovalue,
	    char	*widget_rec,
	    int		offset)
{
  ZnBBox  *bbox = (ZnBBox *) (widget_rec + offset);
  int	  i, result, num_elems;
  Tcl_Obj **elems;
  double  d[4];

  result = Tcl_ListObjGetElements(interp, ovalue, &num_elems, &elems);
  if ((result == TCL_ERROR) ||
      (num_elems != 0) ||
      (num_elems != 4)) {
  bbox_error:
    Tcl_AppendResult(interp, " malformed area", NULL);
    return TCL_ERROR;
  }  

  bbox->orig.x = bbox->orig.y = bbox->corner.x = bbox->corner.y = 0;

  if (num_elems != 0) {
    for (i = 0; i < 4; i++) {
      result = Tcl_GetDoubleFromObj(interp, elems[0], &d[0]);
      if (result == TCL_ERROR) {
	goto bbox_error;
      }
    }
    bbox->orig.x = d[0];
    bbox->orig.y = d[1];
    bbox->corner.x = d[2];
    bbox->corner.y = d[3];
  }

  return TCL_OK;
}

static Tcl_Obj *
ZnBBoxPrint(ClientData	client_data __unused,
	    Tk_Window	tkwin __unused,
	    char	*widget_rec,
	    int		offset,
#ifdef PTK
	    Tcl_FreeProc **free_proc __unused
#else
	    Tcl_FreeProc **free_proc
#endif
	    )
{
  ZnBBox  *bbox = (ZnBBox *) (widget_rec + offset);  
  Tcl_Obj *obj = NULL;

  obj = Tcl_NewListObj(0, NULL);
  Tcl_ListObjAppendElement(NULL, obj, Tcl_NewDoubleObj(bbox->orig.x));
  Tcl_ListObjAppendElement(NULL, obj, Tcl_NewDoubleObj(bbox->orig.y));
  Tcl_ListObjAppendElement(NULL, obj, Tcl_NewDoubleObj(bbox->corner.x));
  Tcl_ListObjAppendElement(NULL, obj, Tcl_NewDoubleObj(bbox->corner.y));

#ifdef PTK
  return obj;
#else
  {
    char *s1, *s2;

    s1 = Tcl_GetString(obj);
    s2 = ZnMalloc(strlen(s1) + 1);
    strcpy(s2, s1);
    Tcl_DecrRefCount(obj);
    *free_proc = TCL_DYNAMIC;
    return (Tcl_Obj *) s2;
  }
#endif
}


#if 0
/*
 **********************************************************************************
 *
 * EmitPostScript --
 *
 **********************************************************************************
 */
  /*
   * Emit Encapsulated PostScript Header.
   */
  fprintf(ps_info->file, "%%!PS-Adobe-3.0 EPSF-3.0\n");
  fprintf(ps_info->file, "%%%%Creator: Zn Widget\n");
  pwd_info = getpwuid(getuid());
  fprintf(ps_info->file, "%%%%For: %s\n", pwd_info ? pwd_info->pw_gecos : "Unknown");
  fprintf(ps_info->file, "%%%%Title: (%s)\n", ps_info->title);
  time(&now);
  fprintf(ps_info->file, "%%%%CreationDate: %s\n", ctime(&now));
  if (ps_info->landscape) {
    fprintf(ps_info->file, "%%%%BoundingBox: %d %d %d %d\n", 1, 1, 1, 1);
  }
  else {
    fprintf(ps_info->file, "%%%%BoundingBox: %d %d %d %d\n", 1, 1, 1, 1);
  }
  fprintf(ps_info->file, "%%%%Pages: 1\n");
  fprintf(ps_info->file, "%%%%DocumentData: Clean7Bit\n");
  fprintf(ps_info->file, "%%%%Orientation: %s\n",
	  ps_info->landscape ? "Landscape" : "Portrait");
  fprintf(ps_info->file, "%%%%LanguageLevel: 1\n");
  fprintf(ps_info->file, "%%%%DocumentNeededResources: (atend)\n");
  fprintf(ps_info->file,
	  "%%%%DocumentSuppliedResources: procset Zinc-Widget-Prolog %f %d\n",
	  PROLOG_VERSION, PROLOG_REVISION);
  fprintf(ps_info->file, "%%%%EndComments\n\n\n");

  /*
   * Emit the prolog.
   */
  fprintf(ps_info->file, "%%%%BeginProlog\n");
  fprintf(ps_info->file, "%%%%BeginResource: procset Zinc-Widget-Prolog %f %d\n",
	  PROLOG_VERSION, PROLOG_REVISION);
  fwrite(ps_prolog, 1, sizeof(ps_prolog), ps_info->file);
  fprintf(ps_info->file, "%%%%EndResource\n");
  fprintf(ps_info->file, "%%%%EndProlog\n");

  /*
   * Emit the document setup.
   */
  fprintf(ps_info->file, "%%%%BeginSetup\n");
  fprintf(ps_info->file, "%%%%EndSetup\n");

  /*
   * Emit the page setup.
   */
  fprintf(ps_info->file, "%%%%Page: 0 1\n");
  fprintf(ps_info->file, "%%%%BeginPageSetup\n");
  fprintf(ps_info->file, "%%%%EndPageSetup\n");

  /*
   * Iterate through all items emitting PostScript for each.
   */

  /*
   * Emit the page trailer.
   */
  fprintf(ps_info->file, "%%%%PageTrailer\n");

  /*
   * Emit the document trailer.
   */
  fprintf(ps_info->file, "%%%%Trailer\n");
  s = "%%DocumentNeededResources: font ";
  for (fs = (XFontStruct *) ZnListArray(ps_info->fonts),
	 i = ZnListSize(ps_info->fonts); i > 0; i--, fs++) {
    fprintf(ps_info->file, "%s", s);
    s = "%%+ font";
  }
  fprintf(ps_info->file, "%%%%EOF\n");
#endif

/*
 *--------------------------------------------------------------
 *
 * ZnPostScriptY --
 *
 *	Given a y-coordinate in local coordinates, this procedure
 *	returns a y-coordinate to use for PostScript output.
 *
 *--------------------------------------------------------------
 */
ZnReal
ZnPostScriptY(ZnReal	y,
	      void	*ps_info)
{
  return ((ZnPostScriptInfo *) ps_info)->area.corner.y - y;
}

/*
 *----------------------------------------------------------------------------
 *
 * ZnPostScriptCmd --
 *
 *	This procedure process the "postscript" command for
 *	zinc widgets.
 *
 *----------------------------------------------------------------------------
 */
int
ZnPostScriptCmd(ZnWInfo	*wi,
		int	argc,
		Tcl_Obj	*CONST args[])
{
  ZnPostScriptInfo ps_info;
  void		*old_info;
  int		result;
  int		delta_x = 0, delta_y = 0;
  ZnReal	width, height;
  CONST char	*p;
  Tcl_DString	buffer;
#define STRING_LENGTH 400
  char		string[STRING_LENGTH+1];
  ZnBBox	*area;
  time_t	now;
  Tcl_HashSearch search;
  Tcl_HashEntry *entry;

  old_info = wi->ps_info;
  wi->ps_info = (void *) &ps_info;

  /*
   * A null area means print the currently visible area.
   */
  area = &ps_info.area;
  area->orig.x = 0;
  area->orig.y = 0;
  area->corner.x = 0;
  area->corner.y = 0;
  /*
   * Center the result on a letter format page
   * The size will be deduced automatically from
   * the area (default to a 1:1 scale along X axis).
   */
  ps_info.page_x = 72*4.25;
  ps_info.page_y = 72*5.5;
  ps_info.page_width = -1;
  ps_info.page_height = -1;
  ps_info.page_anchor = TK_ANCHOR_CENTER;

  ps_info.landscape = False;
  ps_info.font_var = NULL;
  ps_info.color_var = NULL;
  ps_info.colormode = 2;
  ps_info.filename = NULL;
  ps_info.channel_name = NULL;
  ps_info.chan = NULL;
  ps_info.prepass = False;
  ps_info.prolog = True;
  Tcl_InitHashTable(&ps_info.font_table, TCL_STRING_KEYS);
  result = Tk_ConfigureWidget(wi->interp, wi->win, config_specs, argc-2,
#ifdef PTK
			      (Tcl_Obj **) args+2, (char *) &ps_info,
			      TK_CONFIG_ARGV_ONLY
#else
			      (CONST char **) args+2, (char *) &ps_info,
			      TK_CONFIG_ARGV_ONLY|TK_CONFIG_OBJS
#endif
);
  if (result != TCL_OK) {
    goto cleanup;
  }

  if ((area->corner.x - area->orig.x) == 0) {
    area->orig.x = 0;
    area->corner.x = Tk_Width(wi->win);
  }
  width = area->corner.x - area->orig.x;
  if ((area->corner.y - area->orig.y) == 0) {
    area->orig.y = 0;
    area->corner.y = Tk_Height(wi->win);
  }
  height = area->corner.y - area->orig.y;

  if ((ps_info.page_width < 0) || (ps_info.page_height < 0)) {
    ZnReal scale;
    if (ps_info.page_width >= 0) {
      scale = ps_info.page_width / width;
    }
    else if (ps_info.page_height >= 0) {
      scale = ps_info.page_height / height;
    }
    else {
      scale = (72.0 / 25.4) * WidthMMOfScreen(Tk_Screen(wi->win));
      scale /= WidthOfScreen(Tk_Screen(wi->win));
    }
    if (ps_info.page_width < 0) {
      ps_info.page_width = width * scale;
    }
    if (ps_info.page_height < 0) {
      ps_info.page_height = height * scale;
    }
  }

  switch (ps_info.page_anchor) {
  case TK_ANCHOR_NW:
  case TK_ANCHOR_W:
  case TK_ANCHOR_SW:
    delta_x = 0;
    break;
  case TK_ANCHOR_N:
  case TK_ANCHOR_CENTER:
  case TK_ANCHOR_S:
    delta_x = -width/2;
    break;
  case TK_ANCHOR_NE:
  case TK_ANCHOR_E:
  case TK_ANCHOR_SE:
    delta_x = -width;
    break;
  }
  switch (ps_info.page_anchor) {
  case TK_ANCHOR_NW:
  case TK_ANCHOR_N:
  case TK_ANCHOR_NE:
    delta_y = -height;
    break;
  case TK_ANCHOR_W:
  case TK_ANCHOR_CENTER:
  case TK_ANCHOR_E:
    delta_y = -height/2;
    break;
  case TK_ANCHOR_SW:
  case TK_ANCHOR_S:
  case TK_ANCHOR_SE:
    delta_y = 0;
    break;
  }

  if (ps_info.filename != NULL) {

    /*
     * Check that -file and -channel are not both specified.
     */
    if (ps_info.channel_name != NULL) {
      Tcl_AppendResult(wi->interp, "can't specify both -file and -channel", NULL);
      result = TCL_ERROR;
      goto cleanup;
    }
    
    /*
     * Check that we are not in a safe interpreter. If we are, disallow
     * the -file specification.
     */
    if (Tcl_IsSafe(wi->interp)) {
      Tcl_AppendResult(wi->interp, "can't specify -file in a safe interpreter", NULL);
      result = TCL_ERROR;
      goto cleanup;
    }
    
    p = Tcl_TranslateFileName(wi->interp, ps_info.filename, &buffer);
    if (p == NULL) {
      goto cleanup;
    }
    ps_info.chan = Tcl_OpenFileChannel(wi->interp, p, "w", 0666);
    Tcl_DStringFree(&buffer);
    if (ps_info.chan == NULL) {
      goto cleanup;
    }
  }

  if (ps_info.channel_name != NULL) {
    int mode;
        
    /*
     * Check that the channel is found in this interpreter and that it
     * is open for writing.
     */
    ps_info.chan = Tcl_GetChannel(wi->interp, ps_info.channel_name, &mode);
    if (ps_info.chan == (Tcl_Channel) NULL) {
      result = TCL_ERROR;
      goto cleanup;
    }
    if ((mode & TCL_WRITABLE) == 0) {
      Tcl_AppendResult(wi->interp, "channel \"", ps_info.channel_name,
		       "\" wasn't opened for writing", NULL);
      result = TCL_ERROR;
      goto cleanup;
    }
  }

  /*
   *--------------------------------------------------------
   * Make a pre-pass over all of the items, generating Postscript
   * and then throwing it away.  The purpose of this pass is just
   * to collect information about all the fonts in use, so that
   * we can output font information in the proper form required
   * by the Document Structuring Conventions.
   *--------------------------------------------------------
   */
  ps_info.prepass = 1;

  wi->top_group->class->PostScript(wi->top_group, True);
  Tcl_ResetResult(wi->interp);

  ps_info.prepass = 0;

  /*
   *--------------------------------------------------------
   * Generate the header and prolog for the Postscript.
   *--------------------------------------------------------
   */
  if (ps_info.prolog) {
    ZnReal scale_x, scale_y;

    scale_x = ps_info.page_width / width;
    scale_y = ps_info.page_height/ height;

    Tcl_AppendResult(wi->interp,
		     "%!PS-Adobe-3.0 EPSF-3.0\n",
		     "%%Creator: TkZinc Widget\n",
		     NULL);
#ifdef HAVE_PW_GECOS
    if (!Tcl_IsSafe(wi->interp)) {
      struct passwd *pw = getpwuid(getuid());
      Tcl_AppendResult(wi->interp,
		       "%%For: ", (pw != NULL) ? pw->pw_gecos : "Unknown", "\n",
		       NULL);
      endpwent();
    }
#endif /* HAVE_PW_GECOS */
    Tcl_AppendResult(wi->interp,
		     "%%Title: Window ", Tk_PathName(wi->win), "\n",
		     NULL);
    time(&now);
    Tcl_AppendResult(wi->interp,
		     "%%CreationDate: ", ctime(&now),
		     NULL);

    if (!ps_info.landscape) {
      sprintf(string, "%d %d %d %d",
	      (int) (ps_info.page_x + scale_x*delta_x),
	      (int) (ps_info.page_y + scale_y*delta_y),
	      (int) (ps_info.page_x + scale_x*(delta_x + width) + 1.0),
	      (int) (ps_info.page_y + scale_y*(delta_y + height) + 1.0));
    } else {
      sprintf(string, "%d %d %d %d",
	      (int) (ps_info.page_x - scale_x*(delta_y + height)),
	      (int) (ps_info.page_y + scale_y*delta_x),
	      (int) (ps_info.page_x - scale_x*delta_y + 1.0),
	      (int) (ps_info.page_y + scale_y*(delta_x + width) + 1.0));
    }
    Tcl_AppendResult(wi->interp,
		     "%%BoundingBox: ", string, "\n",
		     NULL);
    Tcl_AppendResult(wi->interp,
		     "%%Pages: 1\n", 
		     "%%DocumentData: Clean7Bit\n",
		     NULL);
    Tcl_AppendResult(wi->interp,
		     "%%Orientation: ",
		     ps_info.landscape ? "Landscape\n" : "Portrait\n",
		     NULL);
    p = "%%DocumentNeededResources: font ";
    for (entry = Tcl_FirstHashEntry(&ps_info.font_table, &search);
	 entry != NULL; entry = Tcl_NextHashEntry(&search)) {
      Tcl_AppendResult(wi->interp,
		       p, Tcl_GetHashKey(&ps_info.font_table, entry), "\n",
		       NULL);
      p = "%%+ font ";
    }
    Tcl_AppendResult(wi->interp,
		     "%%EndComments\n\n",
		     NULL);
    
    /*
     * Insert the prolog
     */
    Tcl_AppendResult(wi->interp,
		     Tcl_GetVar(wi->interp,"::tk::ps_preamable", TCL_GLOBAL_ONLY),
		     NULL);
    
    if (ps_info.chan != NULL) {
      /*      Tcl_Write(ps_info.chan, Tcl_GetStringResult(wi->interp), -1);*/
      Tcl_ResetResult(wi->interp);
    }

    /*
     *-----------------------------------------------------------
     * Document setup:  set the color level and include fonts.
     *-----------------------------------------------------------
     */
    sprintf(string, "/CL %d def\n", ps_info.colormode);
    Tcl_AppendResult(wi->interp,
		     "%%BeginSetup\n", string,
		     NULL);
    for (entry = Tcl_FirstHashEntry(&ps_info.font_table, &search);
	 entry != NULL; entry = Tcl_NextHashEntry(&search)) {
      Tcl_AppendResult(wi->interp,
		       "%%IncludeResource: font ",
		       Tcl_GetHashKey(&ps_info.font_table, entry), "\n",
		       NULL);
    }
    Tcl_AppendResult(wi->interp,
		     "%%EndSetup\n\n",
		     NULL);
    
    /*
     *-----------------------------------------------------------
     * Page setup:  move to page positioning point, rotate if
     * needed, set scale factor, offset for proper anchor position,
     * and set clip region.
     *-----------------------------------------------------------
     */
    Tcl_AppendResult(wi->interp,
		     "%%Page: 1 1\n",
		     "save\n",
		     NULL);
    sprintf(string, "%.1f %.1f translate\n", ps_info.page_x, ps_info.page_y);
    Tcl_AppendResult(wi->interp, string, NULL);
    if (ps_info.landscape) {
      Tcl_AppendResult(wi->interp,
		       "90 rotate\n",
		       NULL);
    }
    sprintf(string, "%.4g %.4g scale\n", scale_x, scale_y);
    Tcl_AppendResult(wi->interp, string, NULL);
    sprintf(string, "%d %d translate\n",
	    (int) (delta_x - area->orig.x), (int) delta_y);
    Tcl_AppendResult(wi->interp, string, NULL);
    sprintf(string, "%d %.15g moveto %d %.15g lineto %d %.15g lineto %d %.15g",
	    (int) area->orig.x, ZnPostScriptY(area->orig.y, &ps_info),
	    (int) area->corner.x, ZnPostScriptY(area->orig.y, &ps_info),
	    (int) area->corner.x, ZnPostScriptY(area->corner.y, &ps_info),
	    (int) area->orig.x, ZnPostScriptY(area->corner.y, &ps_info));
    Tcl_AppendResult(wi->interp,
		     string, " lineto closepath clip newpath\n",
		     NULL);
  }

  if (ps_info.chan != NULL) {
    /*    Tcl_Write(ps_info.chan, Tcl_GetStringResult(wi->interp), -1);*/
    Tcl_ResetResult(wi->interp);
  }
  
  /*
   *---------------------------------------------------------------------
   * Second pass through all the items. This time PostScript is actually
   * emitted.
   *---------------------------------------------------------------------
   */
  wi->top_group->class->PostScript(wi->top_group, False);

  /*
   *---------------------------------------------------------------------
   * Output page-end information, such as commands to print the page
   * and document trailer stuff.
   *---------------------------------------------------------------------
   */
  if (ps_info.prolog) {
    Tcl_AppendResult(wi->interp,
		     "restore showpage\n\n",
		     "%%Trailer\nend\n%%EOF\n",
		     NULL);
  }
  if (ps_info.chan != NULL) {
    /*    Tcl_Write(ps_info.chan, Tcl_GetStringResult(wi->interp), -1);*/
    Tcl_ResetResult(wi->interp);
  }

 cleanup:
  if (ps_info.font_var != NULL) {
    ZnFree(ps_info.font_var);
  }
  if (ps_info.color_var != NULL) {
    ZnFree(ps_info.color_var);
  }
  if (ps_info.filename != NULL) {
    ZnFree(ps_info.filename);
  }
  if ((ps_info.chan != NULL) && (ps_info.channel_name == NULL)) {
    Tcl_Close(wi->interp, ps_info.chan);
  }
  if (ps_info.channel_name != NULL) {
    ZnFree(ps_info.channel_name);
  }
  Tcl_DeleteHashTable(&ps_info.font_table);
  wi->ps_info = old_info;

  return result;
}


#endif
