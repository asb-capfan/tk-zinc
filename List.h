/*
 * List.h -- Header of list module.
 *
 * Authors		: Patrick Lecoanet.
 * Creation date	: Tue Mar 15 17:24:51 1994
 *
 * $Id: List.h,v 1.10 2003/04/16 09:49:22 lecoanet Exp $
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


#ifndef _List_h
#define _List_h


#ifdef __CPLUSPLUS__
extern "C" {
#endif


#define	ZnListHead	0
#define ZnListTail	(~(1 << ((8*sizeof(int)) - 1)))


typedef void	*ZnList;


ZnList	ZnListNew(unsigned int	/* initial_size */,
		  unsigned int	/* element_size */);
ZnList	ZnListDuplicate(ZnList	/* list */);
void	ZnListEmpty(ZnList	/* list */);
ZnList	ZnListFromArray(void	* /* array */,
			unsigned int	/* array_size */,
			unsigned int	/* element_size */);
void	*ZnListArray(ZnList	/* list */);
void	ZnListFree(ZnList	/* list */);
unsigned int ZnListSize(ZnList	/* list */);
void	ZnListAssertSize(ZnList	/* list */,
			 unsigned int	/* size */);
void	ZnListCopy(ZnList	/* to */,
		   ZnList	/* from */);
void	ZnListAppend(ZnList	/* to */,
		     ZnList	/* from */);
void	ZnListAdd(ZnList	/* list */,
		  void		* /* value */,
		  unsigned int	/* index */);
void	*ZnListAt(ZnList	/* list */,
		  unsigned int	/* index */);
void	ZnListAtPut(ZnList		/* list */,
		    void       * /* value */,
		    unsigned int /* index */);
void	ZnListDelete(ZnList		/* list */,
		     unsigned int	/* index */);
void	ZnListTruncate(ZnList		/* list */,
		       unsigned int	/* index */);

#ifdef __CPLUSPLUS__
}
#endif

#endif /* _List_h */
