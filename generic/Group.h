/*
 * Group.h -- Header for Group items.
 *
 * Authors		: Patrick Lecoanet.
 * Creation date	:
 *
 * $Id: Group.h,v 1.3 2003/04/16 09:49:22 lecoanet Exp $
 */

/*
 *  Copyright (c) 2002 CENA, Patrick Lecoanet --
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


#ifndef _Group_h
#define _Group_h


ZnItem ZnGroupHead(ZnItem group);
ZnItem ZnGroupTail(ZnItem group);
ZnBool ZnGroupCallOm(ZnItem group);
ZnBool ZnGroupAtomic(ZnItem group);
void ZnGroupSetCallOm(ZnItem group, ZnBool set);
void ZnInsertDependentItem(ZnItem item);
void ZnExtractDependentItem(ZnItem item);
void ZnDisconnectDependentItems(ZnItem item);
void ZnGroupInsertItem(ZnItem group, ZnItem item, ZnItem mark_item, ZnBool before);
void ZnGroupExtractItem(ZnItem item);
void ZnGroupRemoveClip(ZnItem group, ZnItem clip);

#endif /* _Group_h */
