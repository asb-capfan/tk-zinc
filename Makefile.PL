# this code has been developped by Somanos Sar from CENA
# and modified par C.Mertz from CENA
# $Id: Makefile.PL,v 1.3 2003/09/22 10:01:03 mertz Exp $

use 5.00404;
use Cwd;
use Config;
use File::Basename;
use Carp;


BEGIN
{
  my $IsWin32 = ($^O eq 'MSWin32' || $Config{'ccflags'} =~ /-D_?WIN32_?/);
}

my %opt = parse_opt();


print "Trying to find a libGL by myself (may be long)...\n";
my $gl_lib = guess_libs('libGL.so');
if ($gl_lib)
{
    my $gl_lib_a = guess_libs('libGL.a');
    if ($gl_lib_a) {
	warn ("### you have both libGL.so [in $gl_lib] and libGL.a [in $gl_lib_a].
### Tk::Zinc may have trouble building a correct libTkzinc3.x.yy.so library.
### We suggest you to put the libGL.a aside ....")
	}
    $gl_lib = 'yes';
}
else
{
    $gl_lib = 'no';
}

# Directories
my $prefix="";
$prefix = "--prefix=" . $opt{'--prefix'} if ($opt{'--prefix'});


#############################################
#   SUBROUTINES 
#############################################

# Try to guess which library are to be use for tk and tcl
sub guess_libs
{
    my $lib_name = shift;
    
    my @libs = split(/[ \t]+/, $Config{'libpth'});
    foreach my $lib (@libs)
    {
	my @configs = (`find  /usr/lib -name $lib_name`, `find  /usr/local/lib -name $lib_name` , );
	if (@configs)
	{
	    print "Using $configs[0]\n";
	    $configs[0] = dirname($configs[0]);
	    return $configs[0];
	}
    }
    return undef;
}

# Parse option from command line
sub parse_opt
{
    my $args = join(/_IFS_/, @ARGV);
    my @tokens = split(/_IFS_/, $args);
    my %options;
    
    foreach my $token (@tokens)
    {
	my ($key, $value) = split(/[ =]+/, $token);
	$options{$key} = $value;
    }
    return %options;
}



#print "Installing in $prefix gl_lib=$gl_lib\n";

my @withTclTk=();
if (-f "fake_TCL_libs/tclConfig.sh" &&
    -f "fake_TCL_libs/tkConfig.sh") {
    @withTclTk = ("--with-tcl=fake_TCL_libs", "--with-tk=fake_TCL_libs");
}
else {
    print "### configure will search tcl / tk configs in thje system\n";
}
my @args =  ("./configure",
	     "--enable-ptk=yes",
	     "--enable-gl=$gl_lib",
	     "--enable-shared=yes",
	     @withTclTk,
	     $prefix,
#	     INSTALL_PERL=\"yes\""
	     );
print "\nConfiguring with... ", join (' ', @args), "\n";

system (@args);
