package Tk::Zinc::TraceUtils;

use vars qw( $VERSION );
($VERSION) = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use Tk;
use strict;
use Tk::Font;
use Tk::Photo;
use vars qw(@EXPORT);
@EXPORT = qw(printItem printArray printList);


### to print something
sub printItem {
    my ($value) = @_;
    my $ref = ref($value);
#    print "VALUE=$value REF=$ref\n";
    if ($ref eq 'ARRAY') {
	printArray ( @{$value} );
    }
    elsif ($ref eq 'CODE') {
	print "{CODE}";
    }
    elsif ($ref eq 'Tk::Photo') {
#	print " **** $value ***** ";
	print "Tk::Photo(\"". scalar $value->cget('-file') . "\")";
    }
    elsif ($ref eq 'Tk::Font') {
	print "'$value'";
    }
    elsif ($ref eq '') {  # scalar 
	if (defined $value) {
	    if ($value eq '') {
		print  "''";
	    } elsif ($value =~ /\s/
		     or $value =~ /^[a-zA-Z]/
		     or $value =~ /^[\W]$/ ) {
		print "'$value'";
	    }  else {
		print $value;
	    }
	}
	else {
	    print "undef";
	}
    }
    else { # some  class instance
	return $value;
    }
    
} # end printitem


### to print a list of something
sub printArray {
    my (@values) = @_;
    if (! scalar @values) {
	print "[]";
    }
    else {  # the list is not empty
	my @res;
	print "[";
	while (@values) {
	    my $value = shift @values;
	    &printItem ($value);
	    print ", " if (@values);
	}
	print "]" ;
    }
    
} # end printArray


sub printList {
    print "(";
    while (@_) {
	my $v = shift @_;
	printItem $v;
	if ($v =~ /^-\w+/) {
	    print " => ";
	} elsif (@_) {
	    print ", ";
	}
    }
    print ")";
    
} # end printList

1;



