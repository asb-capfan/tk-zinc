#!/usr/bin/perl -w

#
# $Id: Transformations.t,v 1.1 2003/10/02 09:14:23 mertz Exp $
# Author: Christophe Mertz
#

# testing all the import

BEGIN {
    if (!eval q{
        use Test::More qw(no_plan);
        1;
    }) {
        print "# tests only work properly with installed Test::More module\n";
        print "1..1\n";
        print "ok 1\n";
        exit;
    }
    if (!eval q{
	use Tk::Zinc;
 	1;
    }) {
        print "unable to load Tk::Zinc";
        print "1..1\n";
        print "ok 1\n";
        exit;
    }
    if (!eval q{
 	MainWindow->new();
 	1;
    }) {
        print "# tests only work properly when it is possible to create a mainwindow in your env\n";
        print "1..1\n";
        print "ok 1\n";
        exit;
    }
}


$mw = MainWindow->new();
$zinc = $mw->Zinc(-width => 100, -height => 100);

like  ($zinc, qr/^Tk::Zinc=HASH/ , "zinc has been created");

my $g = $zinc->add('group',1);
$zinc->scale($g,2,2);
my $rect1 = $zinc->add('rectangle', $g, [10,10,40,40]);

# todo : add a test for the to-come method to get a transform!

is_deeply([ $zinc->coords($rect1) ],
	  [ [10,10], [40, 40] ],
	  "coords are not modified by the group transform!");

is_deeply([
	   $zinc->transform(1, $g, [100, 100, 300, 500] )
	    ],
	  [ 50, 50, 150, 250 ],
	  "transform from window coordinates to group"); 

is_deeply([
	   $zinc->transform($g, 1, [$zinc->coords($rect1)] )
	    ],
	  [ [20,20], [80, 80] ],
	  "transform to window coordinates"); 


# question suggested by D. Etienne (30 sept 2003):
# is it possible to get the window coordinate of a transformed item?
# the answer is of course yes and it is verified here.
my $rect2 = $zinc->add('rectangle', 1, [10,10,40,40]);

# applying a transform to the rectangle:
$zinc->scale($rect2, 2,2);

# todo : add a test for the to-come method to get a transform!

is_deeply([ $zinc->coords($rect1) ],
	  [ [10,10], [40, 40] ],
	  "coords are not modified by the item transform!");

is_deeply([
	   $zinc->transform(1, $rect2, [100, 100, 300, 500] )
	    ],
	  [ 50, 50, 150, 250 ],
	  "transform window coordinates with same transform than rect2 "); 
is_deeply([
	   $zinc->transform($rect2, 1, [$zinc->coords($rect2)] )
	    ],
	  [ [20,20], [80, 80] ],
	  "transform rect2 coordinates to window coordinates"); 



diag("############## transformations test");
