package Tk::Zinc::TraceUtils;

use vars qw( $VERSION );
($VERSION) = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use Tk;
use strict;
use Tk::Font;
use Tk::Photo;
use vars qw(@EXPORT);
@EXPORT = qw(printItem printArray printList Item Array List);


sub printItem {
    print &Item (@_);
}

sub printArray {
    print &Array (@_);
}

sub printList {
    print &List (@_);
}

sub Item {
    my ($value) = @_;
    my $ref = ref($value);
#    print "VALUE=$value REF=$ref\n";
    if ($ref eq 'ARRAY') {
	return Array ( @{$value} );
    } elsif ($ref eq 'CODE') {
	return "{CODE}";
    } elsif ($ref eq 'Tk::Photo') {
#	print " **** $value ***** ";
	return "Tk::Photo(\"". scalar $value->cget('-file') . "\")";
    } elsif ($ref eq 'Tk::Font') {
	return "'$value'";
    } elsif ($ref eq '') {  # scalar 
	print "value: $value\n";
	if (defined $value) {
	    print "defined value: $value\n";
	    { no strict;
	      if ($value eq eval ($value)) {
		  return $value;
	      } else {
		  return "'$value'";
	      }
	      use strict;
	  }
	} else {
	    return "_undef";
	}
    } else { # some  class instance
	return $value;
    }
    
} # end Item

### to print something
sub Item {
    my ($value) = @_;
    my $ref = ref($value);
#    print "VALUE=$value REF=$ref\n";
    if ($ref eq 'ARRAY') {
	return Array ( @{$value} );
    } elsif ($ref eq 'CODE') {
	return "{CODE}";
    } elsif ($ref eq 'Tk::Photo') {
#	print " **** $value ***** ";
	return "Tk::Photo(\"". scalar $value->cget('-file') . "\")";
    } elsif ($ref eq 'Tk::Font') {
	return "'$value'";
    } elsif ($ref eq '') {  # scalar 
	if (defined $value) {
	    if ($value =~ /^-?\d+(\.\d*(e[+-]?\d+)?)?$/ or # -1. or 1.0
		$value =~ /^-[a-zA-Z]([\w])*$/ # -option1 or -option-1
		) {
		return $value;
	    } elsif ($value eq ''
		     or $value =~ /\s/
		     or $value =~ /^[a-zA-Z]/
		     or $value =~ /^[\W]/
		     ) {
		return "'$value'";
	    } else {
		return $value;
	    }
	} else {
	    return "_undef";
	}
    } else { # some  class instance
	return $value;
    }
    
} # end Item


### to print a list of something
sub Array {
    my (@values) = @_;
    if (! scalar @values) {
	return "[]";
    }
    else {  # the list is not empty
	my $res = "[";
	while (@values) {
	    my $value = shift @values;
	    $res .= &Item ($value);
	    $res .= ", " if (@values);
	}
	return $res. "]" ;
    }
    
} # end Array


sub List {
    my $res = "(";
    while (@_) {
	my $v = shift @_;
	$res .= Item ($v);
	if (@_ > 0) {
	    ## still some elements
	    if ($v =~ /^-\d+$/) {
		$res .= ", ";
	    } elsif ($v =~ /^-\w+$/) {
		$res .= " => ";
	    } else {
		$res .= ", ";
	    }
	}
    }
    return $res. ")";
    
} # end List

1;


