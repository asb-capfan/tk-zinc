/*
** gluos.h - operating system dependencies for GLU
**
** $Header: /pii/repository/Tkzinc/libtess/gluos.h,v 1.3 2004/05/14 09:07:37 lecoanet Exp $
*/
#ifdef __VMS
#ifdef __cplusplus 
#pragma message disable nocordel
#pragma message disable codeunreachable
#pragma message disable codcauunr
#endif
#endif

#ifdef _WIN32
#include <stdlib.h>         /* For _MAX_PATH definition */
#include <stdio.h>
#include <malloc.h>

#define WIN32_LEAN_AND_MEAN
/*#define NOGDI*/
#define NOIME
#define NOMINMAX

#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0400
#endif
#ifndef STRICT
  #define STRICT 1
#endif

#include <windows.h>

/* Disable warnings */
#ifndef __GNUC__
#pragma warning(disable : 4101)
#pragma warning(disable : 4244)
#pragma warning(disable : 4761)
#endif

#if defined(_MSC_VER) && _MSC_VER >= 1200
#pragma comment(linker, "/OPT:NOWIN98")
#endif

#else

/* Disable Microsoft-specific keywords */
#define GLAPIENTRY
#define WINGDIAPI

#endif
