#
# Copyright (c) 1992-1994 The Regents of the University of California.
# Copyright (c) 1994 Sun Microsystems, Inc.
# Copyright (c) 1995-1999 Nick Ing-Simmons. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself, subject
# to additional disclaimer in Tk/license.terms due to partial
# derivation from Tk8.0 sources.
#
# Copyright (c) 2002 CENA, C.Mertz <mert@cena.fr> to trace all
# Tk::Zinc methods calls as well as the args in a human readable
# form. Updated by D.Etienne.
#
# This package overloads the Tk::Methods function in order to trace
# every Tk::Zinc method call in your application.
#
# This may be very usefull when your application segfaults and
# when you have no idea where this happens in your code.
#
# $Id: Trace.pm,v 1.10 2003/09/15 16:17:05 mertz Exp $
#
# To trap Tk::Zinc errors, use rather the Tk::Zinc::TraceErrors package.
#
# for using this file do some thing like :
# perl -MTk::Zinc::Trace myappli.pl

package Tk::Zinc::Trace;

use vars qw( $VERSION );
($VERSION) = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

use Tk;
use strict;
use Tk::Zinc::TraceUtils;

my $WidgetMethodfunction;
BEGIN {
    if ($ZincTraceErrors::on == 1) {
	print STDERR "Tk::Zinc::Trace: incompatible package Tk::Zinc::TraceErrors is already ".
	    "loaded (exit 1)\n";
	exit 1;
    }
    print "Tk::Zinc::Trace is ON\n";
    $ZincTrace::on = 1;
    select STDOUT; $|=1; ## for flushing the trace output
    # save current Tk::Zinc::InitObject function; it will be invoked in
    # overloaded one (see below)
    use Tk;
    use Tk::Zinc;
    $WidgetMethodfunction = Tk::Zinc->can('WidgetMethod');
    
}

sub Tk::Zinc::WidgetMethod {
    my ($zinc, $name, @args) = @_;
    my ($package, $filename, $line) = caller(1);
    $package="" unless defined $package;
    $filename="" unless defined $filename;
    $line="" unless defined $line;
    print "TRACE: $filename line $line $name";
    &printList(@args);
    # invoke function possibly overloaded in other modules
    if (wantarray()) {
	my @res = &$WidgetMethodfunction(@_) if $WidgetMethodfunction;
	print "  RETURNS ";
	&printList (@res); print "\n";
	$zinc->update;
	return @res;
    } else {
	my $res = &$WidgetMethodfunction(@_) if $WidgetMethodfunction;
	print "  RETURNS ";
	&printItem ($res); print "\n";
	$zinc->update;
	return $res;
    }
}
    
1;



