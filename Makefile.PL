use 5.006;
use Tk;
use Config;
use Tk::Config;
use ExtUtils::MakeMaker;
use strict;

my $TkLibDir = $Tk::library;
my $platform = $Tk::platform;

my $VERSION = 3.298;


if (!$TkLibDir)
{
    print stderr "==================================================================\n";
    print stderr "Could not find the Perl/Tk (pTk) library.\n";
    print stderr "Please, install first Perl/Tk interface before installing Tk::Zinc\n";
    print stderr "==================================================================\n";
    die;
}


print "Configuring version $VERSION for $platform platform...\n";
print "Using $TkLibDir as Tk library...\n";

my @GENERIC_C = ('Track.c', 'Tabular.c', 'Reticle.c', 'Map.c', 'Rectangle.c', 'Arc.c', 'Curve.c',
		 'Item.c', 'PostScript.c', 'MapInfo.c', 'Attrs.c', 'Draw.c', 'Geo.c', 'List.c',
		 'perfos.c', 'Transfo.c', 'Group.c', 'Icon.c', 'Text.c', 'Image.c', 'Color.c',
		 'Field.c', 'Triangles.c', 'Window.c', 'tkZinc.c');

my @LIBTESS_C = ('dict.c', 'geom.c', 'memalloc.c', 'mesh.c', 'normal.c', 'priorityq.c',
		 'render.c', 'sweep.c', 'tess.c', 'tessmono.c');

my @OM_C = ('OverlapMan.c');

my @WIN_C = ('WinPort.c');

my @C;

my $WIN = ($platform =~ /win/i);

push @C, @LIBTESS_C, @GENERIC_C ;

my $NeededLibs = ['-L/usr/X11R6/lib -lXext -lX11 -lGL -L.'];

if ($WIN) {
    push @C, @WIN_C;
    $NeededLibs = ['-lopengl32']
}
my $ZincObj = "Zinc" . $Config{"_o"};

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	      'AUTHOR'          => 'Patrick Lecoanet <lecoanet@cena.fr>',
	      'NAME'		=> 'Tk::Zinc',
	      'VERSION'	        => $VERSION,
	      'PREREQ_PM'	=> {Tk => 8.0},
	      'LIBS'		=> $NeededLibs, 
	      'DEFINE'		=> &get_flags,
	      'INC'             => "-I. -I$TkLibDir -I$TkLibDir/pTk -I$TkLibDir/X11",
	      'C'               => [@C],
	      'XS_VERSION'      => $Tk::Config::VERSION,
	      'XS'              => {'Zinc.xs' => 'Zinc.c'},
	      'linkext'         => {LINKTYPE => 'dynamic'},
	      'depend'          => {$ZincObj => '$(O_FILES) Zinc.c'},
	      'LDFROM'		=> "\$(O_FILES) $ZincObj",
	      );

sub get_flags {
    my %DEF_FLAGS = ('GL'        => 1,
		     'SHAPE'     => 1,
		     'GL_DAMAGE' => 1,
		     'OM'        => 1
		     );
    
    foreach my $arg (@ARGV) {
	print "$arg ....\n";
	my ($name, $value) = split(/[=]+/, $arg);
	if ($name =~ /(with-gl)/i) {
	    if ($value =~ /no/i) {
		$DEF_FLAGS{'GL'} = 0;
		$DEF_FLAGS{'GL_DAMAGE'} = 0;
	    }
	}
	elsif ($name =~ /(with-om)/i) {
	    if ($value =~ /no/i) {
		$DEF_FLAGS{'OM'} = 0;
	    }
	}
	elsif ($name =~ /(with-shape)/i) {
	    if ($value =~ /no/i) {
		$DEF_FLAGS{'SHAPE'} = 0;
	    }
	}
    }
    
    my $defines = '-DPTK';

    if ($WIN) {
	#
	# No shape extension on Windows (planned later).
	$DEF_FLAGS{'SHAPE'} = 0;
	#
	# Visual C++ does not define __STDC__ by default
	$defines .= ' -D__STDC__';
    }

    print "Configuring with:\n    ";
    foreach my $flag (keys %DEF_FLAGS) {
	print "$flag=", $DEF_FLAGS{$flag} ? 'ok' : 'no', " ";
	if ($DEF_FLAGS{$flag}) {	    
	    $defines = $defines . " " . "-D$flag";
	    if ($flag eq 'OM') {
		push @C, @OM_C
	    }
	}
    }
    if ($Tk::VERSION =~ /^800/) {
      $defines .= " -DPTK_800";
      print "PTK=800";
    } else {
      print "PTK=804";
    }
    print "\n";
    return $defines;
}

#
# For the demo
#
# perl -Mblib demos/zinc-demos
