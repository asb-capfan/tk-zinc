/*  Copyright (C) 1996-2001  Martin Vicente			      -*- c -*-
    This file is part of the eXtended C Library (XCLIB).

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU Library General Public
    License along with this library (see the file COPYING.LIB).
    If not, write to the Free Software Foundation, Inc.,
    59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.		     */


/*  XCLIB 0.3	PRIVATE:	PRIVATE AND INTERNALS			     */


#ifndef __XC_PRIVATE_H
#define __XC_PRIVATE_H


/* Standard C Library: */
#include <stddef.h>


#if !defined __STDC__
#error "Use a modern C compiler please"
#endif

#if __STDC__ - 1
#warning "Use a C ANSI compiler please"
#endif


#if __WORDSIZE == 64 || defined __alpha || defined __sgi && _MIPS_SZLONG == 64
# undef  __LONG64__
# define __LONG64__
#endif


#if defined _FACILITY && !defined __FACI__
#define __FACI__	_FACILITY
#endif

#if defined __DEBUG__ && !defined __FACI__
#define __FACI__	""
#endif


#if	defined __GNUG__
#define __FUNC__	__PRETTY_FUNCTION__
#elif	defined __GNUC__
#define __FUNC__	__FUNCTION__
#elif	defined __STDC_VERSION__ && __STDC_VERSION__ >= 199901L
#define __FUNC__	__func__
#else
#define __FUNC__	""
#endif


#if defined __sun && defined __SUNPRO_C && defined __SVR4 /* Solaris 2.x */
#define __PRAGMA_INIT__
#define __PRAGMA_FINI__
#endif


#if __GNUC__ < 2 || (__GNUC__ == 2 && __GNUC_MINOR__ < 8)
#define __extension__
#endif

#if __GNUC__ < 2 || (__GNUC__ == 2 && __GNUC_MINOR__ < 7)
#define __format__	format
#define __printf__	printf
#define __scanf__	scanf
#endif

#if __GNUC__ < 2 || (__GNUC__ == 2 && __GNUC_MINOR__ < 5)
#define	__attribute(spec)
#define	__attribute__(spec)
#endif

#define __constructor		__attribute__ ((__constructor__))
#define __destructor		__attribute__ ((__destructor__))
#define __noreturn		__attribute__ ((__noreturn__))
#define __unused		__attribute__ ((__unused__))


#ifndef __GNUC__
#define   inline
#define __inline
#define __inline__
#endif


#ifndef	NULL
#if	defined __GNUG__
#define	NULL	__null			/* NUL POINTER */
#elif	defined	__cplusplus
#define	NULL	0
#else
#define	NULL	((void *)0)
#endif
#endif


#define __noop	((void)0)		/* VOID INSTRUCTION (NO OPERATION) */


#if defined __GNUC__ && !defined __STRICT_ANSI__
#define _XC_ESC		'\e'		/* ESCAPE CHARACTER */
#define _XC_ESC_STRING	"\e"		/* ESCAPE CHARACTER (STRING) */
#else
#define _XC_ESC		'\x1b'
#define _XC_ESC_STRING	"\x1b"
#endif


#define _XC_E		2.7182818284590452354		       /* e          */
#define _XC_LOG2E	1.4426950408889634074		       /* log_2(e)   */
#define _XC_LOG10E	0.43429448190325182765		       /* log_10(e)  */
#define _XC_LN2		0.69314718055994530942		       /* log_e(2)   */
#define _XC_LN10	2.30258509299404568402		       /* log_e(10)  */
#define _XC_PI		3.14159265358979323846		       /* pi         */
#define _XC_PI_2	1.57079632679489661923		       /* pi/2       */
#define _XC_PI_4	0.78539816339744830962		       /* pi/4       */
#define _XC_1_PI	0.31830988618379067154		       /* 1/pi       */
#define _XC_2_PI	0.63661977236758134308		       /* 2/pi       */
#define _XC_2_SQRTPI	1.12837916709551257390		       /* 2/sqrt(pi) */
#define _XC_SQRT2	1.41421356237309504880		       /* sqrt(2)    */
#define _XC_SQRT1_2	0.70710678118654752440		       /* 1/sqrt(2)  */

#define _XC_El		2.7182818284590452353602874713526625L  /* e          */
#define _XC_LOG2El	1.4426950408889634073599246810018922L  /* log_2(e)   */
#define _XC_LOG10El	0.4342944819032518276511289189166051L  /* log_10(e)  */
#define _XC_LN2l	0.6931471805599453094172321214581766L  /* log_e(2)   */
#define _XC_LN10l	2.3025850929940456840179914546843642L  /* log_e(10)  */
#define _XC_PIl		3.1415926535897932384626433832795029L  /* pi         */
#define _XC_PI_2l	1.5707963267948966192313216916397514L  /* pi/2       */
#define _XC_PI_4l	0.7853981633974483096156608458198757L  /* pi/4       */
#define _XC_1_PIl	0.3183098861837906715377675267450287L  /* 1/pi       */
#define _XC_2_PIl	0.6366197723675813430755350534900574L  /* 2/pi       */
#define _XC_2_SQRTPIl	1.1283791670955125738961589031215452L  /* 2/sqrt(pi) */
#define _XC_SQRT2l	1.4142135623730950488016887242096981L  /* sqrt(2)    */
#define _XC_SQRT1_2l	0.7071067811865475244008443621048490L  /* 1/sqrt(2)  */


#define	__XC_T_1_2(type)	((type)1 / (type)2)

#ifdef __GNUC__
#define	__XC_1_2(x)	__XC_TYPE_1_2(typeof (x))
#endif


#if defined __GNUC__ && !defined __STRICT_ANSI__
#define __MACRO_VARARGS__
#endif


#if defined __GNUC__ && !defined __STRICT_ANSI__
#define _MBEGIN	({			/* TO DEFINE COMPLEX MACROS */
#define _MEND	})
#else
#/* Attention ici à l'utilisation des `break' et des `continue'! */
#define _MBEGIN	do {
#define _MEND	} while (0)
#endif

#ifdef __GNUC__
#ifdef __STRICT_ANSI__
#define _FBEGIN	( __extension__ ({	/* TO DEFINE FUNCTION MACROS */
#define _FEND	}))
#else
#define _FBEGIN	({
#define _FEND	})
#endif
#endif


#ifdef __REENTRANT__
#define __XC_AUTO	auto
#define __XC_REGISTER	auto
#else
#define __XC_AUTO
#define __XC_REGISTER	register
#endif


#ifdef __GNUC__
#ifdef __STRICT_ANSI__
#define TYPEDEF	__extension__ typedef
#else
#define TYPEDEF	typedef
#endif
#endif


#define __xclib(reference)	  xc__ ## reference
#define __xcint(reference)	__xc__ ## reference


#endif /* XC PRIVATE HEADER */


/*------------------------------/ END OF FILE /------------------------------*/
