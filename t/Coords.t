#!/usr/bin/perl -w

#
# $Id: Coords.t,v 1.2 2004/04/02 12:01:49 mertz Exp $
# Author: Christophe Mertz
#

# testing all the import

BEGIN {
    if (!eval q{
#        use Test::More qw(no_plan);
        use Test::More tests => 12;
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

my $rect = $zinc->add('rectangle', 1, [10,20,40,50]);


is_deeply([ $zinc->coords($rect) ],
	  [ [10,20], [40, 50] ],
	  "coords are list of arrays");

is_deeply([ $zinc->coords($rect,0) ],
	  [ [10,20], [40, 50] ],
	  "coords of first contour is a list of arrays");

is_deeply([ $zinc->coords($rect,0,0) ],
	  [ 10,20 ],
	  "coords of one point of a contour is a list of two numbers");

is_deeply([ $zinc->coords($rect,0,1) ],
	  [ 40,50 ],
	  "coords of one point of a contour is a list of two numbers");

my $curve = $zinc->add('curve', 1, [ [10,20] ,[40,50,'c'], [90,10,'c'], [30,60] ]);

is_deeply([ $zinc->coords($curve) ],
	  [ [10,20] ,[40,50,'c'], [90,10,'c'], [30,60] ],
	  "coords of a curve is a list of arrays");

is_deeply([ $zinc->coords($curve,0) ],
	  [ [10,20] ,[40,50,'c'], [90,10,'c'], [30,60] ],
	  "coords of contour 0 of a curve are list of arrays");

is_deeply([ $zinc->coords($curve,0,0) ],
	  [ 10,20 ],
	  "coords of first point of contour 0 of a curve is list of two numbers");

is_deeply([ $zinc->coords($curve,0,1) ],
	  [ 40,50,'c' ],
	  "coords of a control point of a curve contour is list of three elements");

my $text = $zinc->add('text', 1, -position => [10,20], -text => 'test');

is_deeply([ $zinc->coords($text) ],
	  [ 10,20 ],
	  "coords of a text");

is_deeply([ $zinc->coords($text,0) ],
	  [ 10,20 ],
	  "coords of text contour");

is_deeply([ $zinc->coords($text,0,0) ],
	  [ 10,20 ],
	  "coords of text contour first point");

diag("############## coords test");


