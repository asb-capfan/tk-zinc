#        Tk::Zinc::Debug Perl Module :
#
#        For debugging/analysing a Zinc application.
#
#        Author : Daniel Etienne <etienne@cena.fr>
#
# $Id: Debug.pm,v 1.37 2003/09/15 16:17:05 mertz Exp $
#---------------------------------------------------------------------------
package Tk::Zinc::Debug;

use vars qw( $VERSION );
($VERSION) = sprintf("%d.%02d", q$Revision: 1.37 $ =~ /(\d+)\.(\d+)/);

use strict 'vars';
use vars qw(@ISA @EXPORT @EXPORT_OK $WARNING $endoptions);
use Carp;
use English;
require Exporter;
use File::Basename;
use Tk::LabFrame;
use Tk::Dialog;
use Tk::Tree;
use Tk::ItemStyle;
use Tk::Pane;
use Tk::FBox;

@ISA = qw(Exporter);
@EXPORT = qw(finditems snapshot tree);
@EXPORT_OK = qw(finditems snapshot tree);

my ($itemstyle, $groupstyle, $step);
my (%help_tl, $result_tl, $result_fm, $search_tl, $helptree_tl, $coords_tl,
    $searchtree_tl, $tree_tl, $tree, $transfo_tl);
my $showitemflag;
my ($x0, $y0);
my ($help_print, $imagecounter, $saving) = (0, 0, 0);
my %searchEntryValue;
my $searchTreeEntryValue;
my %enclosedModBtn;
my %overlapModBtn;
my %treeModBtn;
my %searchKey;
my %snapKey;
my %treeKey;
my %keys;
my %seq;
my %wwidth;
my %wheight;
my $preload;
my %defaultoptions;
my %focus;
my %instances;
my @instances;
my %cmdoptions;
my $initobjectfunction;

BEGIN {
    # test if Tk::Zinc::Debug is loaded using the -M perl option
    $preload = 1 if (caller(2))[2] == 0;
    return unless $preload;
    # parse Tk::Zinc::Debug options
    require Getopt::Long;
    Getopt::Long::Configure('pass_through');
    Getopt::Long::GetOptions(\%cmdoptions,
	       'itemModBtn=s', 'tkey=s', 'optionsToDisplay=s', 'optionsFormat=s',
	       'color=s', 'enclosedModBtn=s', 'overlapModBtn=s', 'searchKey=s',
	       'skey=s', 'verbosity=s', 'basename=s',
	       );
    # save current Tk::Zinc::InitObject function; it will be invoked in
    # overloaded one (see below)
    use Tk;
    use Tk::Zinc;
    $initobjectfunction = Tk::Zinc->can('InitObject');
    
}


# Hack to capture the instance of zinc. Tk::Zinc::Debug functions are invoked here.
# Note that created bindings might be overloaded by the application.
sub Tk::Zinc::InitObject {
    print "Tk::Zinc::Debug is ON\n";
    # invoke function possibly overloaded in other modules
    &$initobjectfunction(@_) if $initobjectfunction;
    return unless $preload;
    my $zinc = $_[0];
    my @options = ();
    push (@options, -itemModBtn => [split(/,/, $cmdoptions{itemModBtn})])
	if $cmdoptions{itemModBtn};
    push (@options, -tkey => $cmdoptions{tkey}) if $cmdoptions{tkey};
    push (@options, -optionsToDisplay => $cmdoptions{optionsToDisplay})
	if $cmdoptions{optionsToDisplay};
    push (@options, -optionsFormat => $cmdoptions{optionsFormat})
	if $cmdoptions{optionsFormat};
      #print "options=@options\n";
    &tree($zinc, @options);
    @options = ();
    push (@options, -color => $cmdoptions{color}) if $cmdoptions{color};
    push (@options, -enclosedModBtn => [split(/,/, $cmdoptions{enclosedModBtn})])
	if $cmdoptions{enclosedModBtn};
    push (@options, -overlapModBtn => [split(/,/, $cmdoptions{overlapModBtn})])
	if $cmdoptions{overlapModBtn};
    &finditems($zinc, @options);
    @options = ();
    push (@options, -searchKey => $cmdoptions{searchKey}) if $cmdoptions{searchKey};
    push (@options, -skey => $cmdoptions{skey}) if $cmdoptions{skey};
    push (@options, -verbosity => $cmdoptions{verbosity}) if $cmdoptions{verbosity};
    push (@options, -basename => $cmdoptions{basename}) if $cmdoptions{basename};
    &snapshot($zinc, @options);
}



#---------------------------------------------------------------------------
# tree : display items hierarchy
#---------------------------------------------------------------------------
sub tree {
    
    my $zinc = shift;
    unless ($zinc) {
	carp "In Tk::Zinc::Debug module, tree() function, widget must be specified\n";
	return;
    }
    &newinstance($zinc);
    # styles definition
    $itemstyle =
	$zinc->ItemStyle('text', -stylename => "item", -foreground => 'black')
	    unless $itemstyle;
    $groupstyle =
	$zinc->ItemStyle('text', -stylename => "group", -foreground => 'black')
	    unless $groupstyle;
    
    # options 
    my %options = @_;
    for my $opt (keys(%options)) {
	carp "in Tk::Zinc::Debug module, tree() function, unknown option $opt\n"
	    unless ($opt eq '-itemModBtn' or $opt eq '-key' or $opt eq '-tkey' or
		    $opt eq '-optionsToDisplay' or $opt eq '-optionsFormat');
    }
    
    # unset previous bindings;
    $zinc->Tk::bind('<'.$treeKey{$zinc}.'>', '') if $treeKey{$zinc};
    if ($treeModBtn{$zinc}) {
	my $seq;
	if ($treeModBtn{$zinc}->[0]) {
	    $seq = $treeModBtn{$zinc}->[0]."-".$treeModBtn{$zinc}->[1];
	} else {
	    $seq = $treeModBtn{$zinc}->[1];

	}
	$zinc->Tk::bind('<'.$seq.'>', '');
    }
    if ($options{-tkey}) {
	$treeKey{$zinc} = $options{-tkey};
    } elsif ($options{-key}) {
	$treeKey{$zinc} = $options{-key};
    } else {
	$treeKey{$zinc} = 'Control-t';
    }
    $treeModBtn{$zinc} = ($options{-itemModBtn}) ? $options{-itemModBtn} :
	['Control', 2];
    $options{-optionsFormat} = 'column' unless $options{-optionsFormat};
    if ($options{-optionsFormat} ne 'row' and $options{-optionsFormat} ne 'column') {
	carp "in Tk::Zinc::Debug module, tree() function, expected values for ".
	    "-optionsFormat are 'row' or 'column'. Option is set to 'column'\n";
	$options{-optionsFormat} = 'column';
    }
    # binding for building tree
    $zinc->Tk::bind('<'.$treeKey{$zinc}.'>',
			      [\&showtree, $options{-optionsToDisplay},
			       $options{-optionsFormat}]);
    # binding for displaying item in tree
    my $seq;
    if ($treeModBtn{$zinc}->[0]) {
	$seq = $treeModBtn{$zinc}->[0]."-".$treeModBtn{$zinc}->[1];
    } else {
	$seq = $treeModBtn{$zinc}->[1];
    }
    $zinc->Tk::bind("<".$seq.">", [\&findintree, $options{-optionsToDisplay},
			   $options{-optionsFormat}]);
    # binding for general help
    $zinc->toplevel->Tk::bind('<Key-Escape>', \&showgeneralhelp);
    
} # end tree


#---------------------------------------------------------------------------
# finditems : scan items which are enclosed in a rectangular area first
# drawn by drag & drop or all items which overlap it
#---------------------------------------------------------------------------
sub finditems {
    
    my $zinc = shift;
    unless ($zinc) {
	carp "In Tk::Zinc::Debug module, finditems() function, widget must be specified\n";
	return;
    }
    &newinstance($zinc);
    # options 
    my %options = @_;
    for my $opt (keys(%options)) {
	carp "in Tk::Zinc::Debug module, finditems() function, unknown option $opt\n"
	    unless ($opt eq '-color' or $opt eq '-enclosedModBtn' or
		    $opt eq '-overlapModBtn' or $opt eq '-searchKey');
    }
    # unset previous bindings;
    my $ekb = $enclosedModBtn{$zinc};
    if ($ekb) {
	if ($ekb->[0]) {
	    $zinc->Tk::bind("<".$ekb->[0]."-".$ekb->[1].">", '');
	    $zinc->Tk::bind("<".$ekb->[0]."-B".$ekb->[1]."-Motion>", '');
	    $zinc->Tk::bind("<".$ekb->[0]."-B".$ekb->[1]."-ButtonRelease>", '');
	} else {
	    $zinc->Tk::bind("<".$ekb->[1].">", '');
	    $zinc->Tk::bind("<B".$ekb->[1]."-Motion>", '');
	    $zinc->Tk::bind("<B".$ekb->[1]."-ButtonRelease>", '');
	}
    }
    my $okb = $overlapModBtn{$zinc};
    if ($okb) {
	if ($okb->[0]) {
	    $zinc->Tk::bind("<".$okb->[0]."-".$okb->[1].">", '');
	    $zinc->Tk::bind("<".$okb->[0]."-B".$okb->[1]."-Motion>", '');
	    $zinc->Tk::bind("<".$okb->[0]."-B".$okb->[1]."-ButtonRelease>", '');
	} else {
	    $zinc->Tk::bind("<".$okb->[1].">", '');
	    $zinc->Tk::bind("<B".$okb->[1]."-Motion>", '');
	    $zinc->Tk::bind("<B".$okb->[1]."-ButtonRelease>", '');
	}
    }
    
    my $color = ($options{-color}) ? $options{-color} : 'sienna';
    $enclosedModBtn{$zinc} = ($options{-enclosedModBtn}) ? $options{-enclosedModBtn} :
	['Control', 3];
    $overlapModBtn{$zinc} = ($options{-overlapModBtn}) ? $options{-overlapModBtn} :
	['Shift', 3];
    $searchKey{$zinc} = ($options{-searchKey}) ? $options{-searchKey} : 'Control-f';
    # bindings for Enclosed search
    $ekb = $enclosedModBtn{$zinc};
    if ($ekb) {
	if ($ekb->[0]) {
	    $zinc->Tk::bind("<".$ekb->[0]."-".$ekb->[1].">",
			    [\&startrectangle, 'simple', 'Enclosed', $color]);
	    $zinc->Tk::bind("<".$ekb->[0]."-B".$ekb->[1]."-Motion>", \&resizerectangle);
	    $zinc->Tk::bind("<".$ekb->[0]."-B".$ekb->[1]."-ButtonRelease>",
			    [\&stoprectangle, 'enclosed', 'Enclosed search']);
	} else {
	    $zinc->Tk::bind("<".$ekb->[1].">",
			    [\&startrectangle, 'simple', 'Enclosed', $color]);
	    $zinc->Tk::bind("<B".$ekb->[1]."-Motion>", \&resizerectangle);
	    $zinc->Tk::bind("<B".$ekb->[1]."-ButtonRelease>",
			    [\&stoprectangle, 'enclosed', 'Enclosed search']);
	}
    }
    # bindings for Overlap search
    $okb = $overlapModBtn{$zinc};
    if ($okb) {
	if ($okb->[0]) {
	    $zinc->Tk::bind("<".$okb->[0]."-".$okb->[1].">",
			    [\&startrectangle, 'mixed', 'Overlap', $color]);
	    $zinc->Tk::bind("<".$okb->[0]."-B".$okb->[1]."-Motion>", \&resizerectangle);
	    $zinc->Tk::bind("<".$okb->[0]."-B".$okb->[1]."-ButtonRelease>",
			    [\&stoprectangle, 'overlapping', 'Overlap search']);
	} else {
	    $zinc->Tk::bind("<".$okb->[1].">",
			    [\&startrectangle, 'mixed', 'Overlap', $color]);
	    $zinc->Tk::bind("<B".$okb->[1]."-Motion>", \&resizerectangle);
	    $zinc->Tk::bind("<B".$okb->[1]."-ButtonRelease>",
			    [\&stoprectangle, 'overlapping', 'Overlap search']);
	}
    }
    # binding for search entry
    $zinc->Tk::bind('<'.$searchKey{$zinc}.'>', \&searchentry);
    # binding for general help
    $zinc->toplevel->Tk::bind('<Key-Escape>', \&showgeneralhelp);
    
} # end finditems



#---------------------------------------------------------------------------
# snapshot : snapshot the application window, in order to illustrate a
# graphical bug for example
#---------------------------------------------------------------------------
sub snapshot {
    
    my $zinc = shift;
    unless ($zinc) {
	carp "In Tk::Zinc::Debug module, snapshot() function, widget must be specified\n";
	return;
    }
    &newinstance($zinc);
    # options 
    my %options = @_;
    for my $opt (keys(%options)) {
	carp "in Tk::Zinc::Debug module, snapshot() function, unknown option $opt\n"
	    unless ($opt eq '-key' or $opt eq '-skey' or
		    $opt eq '-verbosity' or $opt eq '-basename');
    }
    # unset previous bindings;
    $zinc->Tk::bind("<".$snapKey{$zinc}.">", '') if $snapKey{$zinc};
    
    if ($options{-skey}) {
	$snapKey{$zinc} = $options{-skey};
    } elsif ($options{-key}) {
	$snapKey{$zinc} = $options{-key};
    } else {
	$snapKey{$zinc} = 'Control-s';
    }
    my $snapshotVerbosity = (defined $options{-verbosity}) ? $options{-verbosity} : 1;
    my $snapshotBasename = ($options{-basename}) ? $options{-basename} : "zincsnapshot";
    # binding for printing a full zinc window
    $zinc->Tk::bind("<".$snapKey{$zinc}.">",
  		    [\&printWindow , $snapshotBasename, $snapshotVerbosity]);
    # binding for general help
    $zinc->toplevel->Tk::bind('<Key-Escape>', \&showgeneralhelp);

} # end snapshot


#---------------------------------------------------------------------------
#
# TREE PRIVATE FUNCTIONS
#
#---------------------------------------------------------------------------
sub findintree {
    my ($zinc, $optionstodisplay, $optionsFormat) = @_;
    if (not Tk::Exists($tree_tl)) {
	&showtree($zinc, $optionstodisplay, $optionsFormat);
    }
    my $ev = $zinc->XEvent;
    ($x0, $y0) = ($ev->x, $ev->y);
    my @atomicgroups = &unsetAtomicity($zinc);
    my $item = $zinc->find('closest', $x0, $y0);
    &restoreAtomicity($zinc, @atomicgroups);
    return unless $item > 1;
    my @ancestors = reverse($zinc->find('ancestors', $item));
    my $path = join('.', @ancestors).".".$item;
    $tree->see($path);
    $tree->selectionClear;
    $tree->anchorSet($path);
    $tree->selectionSet($path);
    &surrounditem($zinc, $item);
    $tree->focus;

} # end findintree



sub showtree {
    my ($zinc, $optionstodisplay, $optionsFormat) = @_;
    $WARNING = 0;
    my @optionstodisplay = split(/,/, $optionstodisplay);
    $WARNING = 1;
    $tree_tl->destroy if $tree_tl and Tk::Exists($search_tl);
    $tree_tl = $zinc->Toplevel;
    $tree_tl->minsize(280, 200);
    $tree_tl->title("Zinc Items Tree");
    $tree = $tree_tl->Scrolled('Tree',
			       -scrollbars => 'se',
			       -height => 40,
			       -width => 50,
			       -itemtype => 'text',
			       -selectmode => 'single',
			       -separator => '.',
			       -drawbranch => 1,
			       -indent => 30,
			       -command => sub {
				   my $path = shift;
				   my $item = (split(/\./, $path))[-1];
				   &showresult("", $zinc, $item);
				   $zinc->after(100, sub {
				       &undohighlightitem(undef, $zinc)});
			       },
			       );
    $tree->bind('<1>', [sub {
	my $path = $tree->nearest($_[1]);
	my $item = (split(/\./, $path))[-1];
	&highlightitem($tree, $zinc, $item, 0);
		       
    }, Ev('y')]);
    
    $tree->bind('<2>', [sub {
	my $path = $tree->nearest($_[1]);
	return if $path eq 1;
	$tree->selectionClear;
	$tree->selectionSet($path);
	$tree->anchorSet($path);
	my $item = (split(/\./, $path))[-1];
	&highlightitem($tree, $zinc, $item, 1);
		       
    }, Ev('y')]);

    $tree->bind('<3>', [sub {
	my $path = $tree->nearest($_[1]);
	return if $path eq 1;
	$tree->selectionClear;
	$tree->selectionSet($path);
	$tree->anchorSet($path);
	my $item = (split(/\./, $path))[-1];
	&highlightitem($tree, $zinc, $item, 2);
		       
    }, Ev('y')]);
    
    $tree->add("1", -text => "Group(1)", -state => 'disabled');
    &scangroup($zinc, $tree, 1, "1", $optionsFormat, @optionstodisplay);
    $tree->autosetmode;
    # control buttons frame
    my $tree_butt_fm = $tree_tl->Frame(-height => 40)->pack(-side => 'bottom',
							    -fill => 'y');
    $tree_butt_fm->Button(-text => 'Help',
			  -command => [\&showHelpAboutTree, $zinc],
			  )->pack(-side => 'left', -pady => 10,
				  -padx => 30, -fill => 'both');
    
    $tree_butt_fm->Button(-text => 'Search',
			  -command => [\&searchInTree, $zinc],
			  )->pack(-side => 'left', -pady => 10,
				  -padx => 30, -fill => 'both');
    $tree_butt_fm->Button(-text => "Build\ncode",
			  -command => [\&buildCode, $zinc, $tree],
			  )->pack(-side => 'left', -pady => 10,
				  -padx => 30, -fill => 'both');
    

    $tree_butt_fm->Button(-text => 'Close',
			  -command => sub {$zinc->remove("zincdebug");
					   $tree_tl->destroy},
			  )->pack(-side => 'left', -pady => 10,
				  -padx => 30, -fill => 'both');
    # pack tree
    $tree->pack(-padx => 10, -pady => 10,
		-ipadx => 10,
		-side => 'top',
		-fill => 'both',
		-expand => 1,
		);


} # end showtree


sub buildCode {
    my $zinc = shift;
    my $tree = shift;
    my @code;
    push(@code, 'use Tk;');
    push(@code, 'use Tk::Zinc;');
    push(@code, 'my $mw = MainWindow->new();');
    push(@code, 'my $zinc = $mw->Zinc(-render => '.$zinc->cget(-render).
	 ')->pack(-expand => 1, -fill => both);');
    push(@code, '# hash %items : keys are original items ID, values are built items ID');
    push(@code, 'my %items;');
    push(@code, '');
    my $path = $tree->selectionGet;
    $path = 1 unless $path;
    my $item = (split(/\./, $path))[-1];
    $endoptions = [];
    if ($zinc->type($item) eq 'group') {
	push(@code, &buildGroup($zinc, $item, 1));
	for(@$endoptions) {
	    my ($item, $option, $value) = @$_;
	    push(@code,
		 '$zinc->itemconfigure('.$item.', '.$option.' => '.$value.');');
	}
    } else {
	push(@code, &buildItem($zinc, $item, 1));
    }
    push(@code, 'MainLoop;');
    
    my $file = $zinc->getSaveFile(-filetypes => [['Perl Files',   '.pl'],
                                               ['All Files',   '*']],
				  -initialfile => 'zincdebug.pl',
				  -title => 'Save code',
				  );
    $zinc->Busy;
    open (OUT, ">$file");
    for (@code) {
	print OUT $_."\n";
    }
    close(OUT);
    $zinc->Unbusy;
    
} # end buildCode



sub buildGroup {
    my $zinc = shift;
    my $item = shift;
    my $group = shift;
    my @code;
    push(@code, '$items{'.$item.'}=$zinc->add("group", '.$group.', ');
    # options
    push(@code, &buildOptions($zinc, $item));
    push(@code, ');');
    push(@code, '');
    push(@code, '$zinc->coords($items{'.$item.'}, ['.
	 join(',', $zinc->coords($item)).']);');
    my @items = $zinc->find('withtag', "$item.");
    for my $it (reverse(@items)) {
	if ($zinc->type($it) eq 'group') {
	    push(@code, &buildGroup($zinc, $it, '$items{'.$item.'}'));
	} else {
	    push(@code, &buildItem($zinc, $it, '$items{'.$item.'}'));
	}
    }
    return @code;

} # end buildGroup


sub buildItem {
    my $zinc = shift;
    my $item = shift;
    my $group = shift;
    my $type = $zinc->type($item);
    my @code;
    my $numfields = 0;
    my $numcontours = 0;
    # type group and initargs
    my $initstring = '$items{'.$item.'}=$zinc->add('.$type.', '.$group.', ';
    if ($type eq 'tabular' or $type eq 'track' or $type eq 'waypoint') {
	$numfields = $zinc->itemcget($item, -numfields);
	$initstring .= $numfields.' ,';
    } elsif ($type eq 'curve' or $type eq 'triangles' or
	     $type eq 'arc' or $type eq 'rectangle') {
	$initstring .= "[ ";
	my (@coords) = $zinc->coords($item);
	if (ref($coords[0]) eq 'ARRAY') {
	    my @coords2;
	    for my $c (@coords) {
		if (@$c > 2) {
		     push(@coords2, '['.$c->[0].', '.$c->[1].', "'.$c->[2].'"]');
		} else {
		     push(@coords2, '['.$c->[0].', '.$c->[1].']');
		    
		}
	    }
	    $initstring .= join(', ', @coords2);
	} else {
	    $initstring .= join(', ', @coords);
	}
	$initstring .= " ], ";
	$numcontours = $zinc->contour($item);
    } 
    push(@code, $initstring);
    # options
    push(@code, &buildOptions($zinc, $item));
    push(@code, ');');
    push(@code, '');
    if ($numfields > 0) {
    	for (my $i=0; $i < $numfields; $i++) {
	    push(@code, &buildField($zinc, $item, $i));
	}
    }
    if ($numcontours > 1) {
	for (my $i=1; $i < $numcontours; $i++) {
	    my (@coords) = $zinc->coords($item);
	    my @coords2;
	    for my $c (@coords) {
		if (@$c > 2) {
		    push(@coords2, '['.$c->[0].', '.$c->[1].', "'.$c->[2].'"]');
		} else {
		    push(@coords2, '['.$c->[0].', '.$c->[1].']');
		}
	    }
	    my $coordstr = '[ '.join(', ', @coords2).' ]';
	    push(@code, '$zinc->contour($items{'.$item.'}, "add", 0, ');
	    push(@code, '            '.$coordstr.');');
	}
    }
    return @code;

} # end buildItem


sub buildField {
    my $zinc = shift;
    my $item = shift;
    my $field = shift;
    my @code;
    # type group and initargs
    push(@code, '$zinc->itemconfigure($items{'.$item.'}, '.$field.', ');
    # options
    push(@code, &buildOptions($zinc, $item, $field));
    push(@code, ');');
    push(@code, '');
    return @code;

} # end buildField


sub buildOptions {
    my $zinc = shift;
    my $item = shift;
    my $field = shift;
    my @code;
    my @args = defined($field) ? ($item, $field) : ($item);
    my @options = $zinc->itemconfigure(@args);
    for my $elem (@options) {
	my ($option, $type, $readonly, $value) = (@$elem)[0, 1, 2, 4];
	next if $value eq '';
	next if $readonly;
	if ($type eq 'point') {
	    push(@code, "           ".$option." => [".join(',', @$value)."], ");
	    
	} elsif (($type eq 'bitmap' or $type eq 'image') and $value !~ /^AtcSymbol/
	    and $value !~ /^AlphaStipple/) {
	    push(@code, "#           ".$option." => '".$value."', ");
	    
	} elsif ($type eq 'item') {
	    $endoptions->[@$endoptions] =
		['$items{'.$item.'}', $option, '$items{'.$value.'}'];
	    
	} elsif ($option eq '-text') {
	    $value =~ s/\"/\\"/;       # comment for emacs legibility => "
	    push(@code, "           ".$option.' => "'.$value.'", ');

	} elsif (ref($value) eq 'ARRAY') {
	    push(@code, "           ".$option." => [qw(".join(',', @$value).")], ");

	} else {
	    push(@code, "           ".$option." => '".$value."', ");
	}
    }
    return @code;

} # end buildOptions


sub searchInTree {
    my $zinc = shift;
    $searchtree_tl->destroy if $searchtree_tl and Tk::Exists($searchtree_tl);
    $searchtree_tl = $zinc->Toplevel;
    $searchtree_tl->title("Find string in tree");
    my $fm = $searchtree_tl->Frame->pack(-side => 'top');
    $fm->Label(-text => "Find : ",
	       )->pack(-side => 'left', -padx => 10, -pady => 10);
    my $entry = $fm->Entry(-width => 20)->pack(-side => 'left',
					       -padx => 10, -pady => 10);
    my $status = $searchtree_tl->Label(-foreground => 'sienna',
				   )->pack(-side => 'top');
    my $ep = 1;
    my $searchfunc =  sub {
	my $side = shift;
	my $found = 0;
        #print "ep=$ep side=$side\n";
	$status->configure(-text => "");
	$status->update;
	$searchTreeEntryValue = $entry->get();
	$searchTreeEntryValue = quotemeta($searchTreeEntryValue);
	my $text;
	while ($ep) {
 	    $ep = $tree->info($side, $ep);
	    unless ($ep) {
		$ep = 1;
		$found = 0;
		last;
	    }
	    $text = $tree->entrycget($ep, -text);
	    if ($text =~ /$searchTreeEntryValue/) {
		$tree->see($ep);
		$tree->selectionClear;
		$tree->anchorSet($ep);
		$tree->selectionSet($ep);
		$found = 1;
		last;
	    }
	}
	#print "searchTreeEntryValue=$searchTreeEntryValue found=$found\n";
	$status->configure(-text => "Search string not found") unless $found > 0;
    };

    my $fm2 = $searchtree_tl->Frame->pack(-side => 'top');
    $fm2->Button(-text => 'Prev',
		 -command => sub {&$searchfunc('prev');},
		 )->pack(-side => 'left', -pady => 10);
    $fm2->Button(-text => 'Next',
		 -command => sub {&$searchfunc('next');},
		 )->pack(-side => 'left', -pady => 10);
    $fm2->Button(-text => 'Close',
		 -command => sub {$searchtree_tl->destroy},
		 )->pack(-side => 'right', -pady => 10);
    $entry->focus;
    $entry->delete(0, 'end');
    $entry->insert(0, $searchTreeEntryValue) if $searchTreeEntryValue;
    $entry->bind('<Key-Return>', sub {&$searchfunc('next');});
    
} # end searchInTree


sub extractinfo {
    my $zinc = shift;
    my $item = shift;
    my $format = shift;
    my $option = shift;
    my $titleflag = shift;
    $option =~ s/^\s+//;
    $option =~ s/\s+$//;
    #print "option=[$option]\n";
    my @info;
    $WARNING = 0;
    eval {@info = $zinc->itemcget($item, $option)};
    #print "eval $option = (@info) $@\n";
    return if $@;
    return if @info == 0;
    my $info;
    my $sep = ($format eq 'column') ? "\n  " : ", ";
    if ($titleflag) {
	$info = $sep."[$option] ".$info[0];
    } else {
	$info = $sep.$info[0];
    }
    if (@info > 1) {
	shift(@info);
	for (@info) {
	    if ($format eq 'column') {
		if (length($info." ".$_) > 40) {
		    if ($titleflag) {
			$info .= $sep."[$option] ".$_;
		    } else {
			$info .= $sep.$_;
		    }
		} else {
		    $info .= ", $_";
		}
	    } else {
		$info .= $sep.$_;
	    }
	}
    }
    $WARNING = 1;
    return $info;
    
} # end extractinfo


sub scangroup {
    my ($zinc, $tree, $group, $path, $format, @optionstodisplay) = @_;
    my @items = $zinc->find('withtag', "$group.");
    for my $item (@items) {
	my $Type = ucfirst($zinc->type($item));
	my $info = " ";
	if (@optionstodisplay == 1) {
	    $info .= &extractinfo($zinc, $item, $format, $optionstodisplay[0]);
	} elsif (@optionstodisplay > 1) {
	    for my $opt (@optionstodisplay) {
		$info .= &extractinfo($zinc, $item, $format, $opt, 1);
	    }
	}
	if ($Type eq "Group") {
	    $tree->add($path.".".$item,
		       -text => "$Type($item)$info",
		       -style => 'group',
		       );
	    &scangroup($zinc, $tree, $item, $path.".".$item, $format, @optionstodisplay);
	} else {
	    $tree->add($path.".".$item,
		       -text => "$Type($item)$info",
		       -style => 'item',
		       );
	}
    }

} # end scangroup

#---------------------------------------------------------------------------
#
# AREA SEARCH PRIVATE FUNCTIONS
#
#---------------------------------------------------------------------------
# begin to draw rectangular area for search
sub startrectangle {
    my ($zinc, $style, $text, $color) = @_;
    $zinc->remove("zincdebugrectangle", "zincdebuglabel");
    my $ev = $zinc->XEvent;
    ($x0, $y0) = ($ev->x, $ev->y);
    $zinc->add('rectangle', 1, [$x0, $y0, $x0, $y0],
	       -linecolor => $color,
	       -linewidth => 2,
	       -linestyle => $style,
	       -tags => ["zincdebugrectangle"],
			       );
    $zinc->add('text', 1,
	       -color => $color,
	       -font => '7x13',
	       -position => [$x0+5, $y0-15],
	       -text => $text,
	       -tags => ["zincdebuglabel"],
	       );
  
} # end startrectangle


# resize the rectangular area for search
sub resizerectangle {
    my $zinc = shift;
    my $ev = $zinc->XEvent;
    my ($x, $y) = ($ev->x, $ev->y);
    return unless ($zinc->find('withtag', "zincdebugrectangle"));

    $zinc->coords("zincdebugrectangle", 1, 1, [$x, $y]);
    if ($x < $x0) {
	if ($y < $y0) {
	    $zinc->coords("zincdebuglabel", [$x+5, $y-15]);
	} else {
	    $zinc->coords("zincdebuglabel", [$x+5, $y0-15]);
	}
    } else {
	if ($y < $y0) {
	    $zinc->coords("zincdebuglabel", [$x0+5, $y-15]);
	} else {
	    $zinc->coords("zincdebuglabel", [$x0+5, $y0-15]);
	}
    }
    $zinc->raise("zincdebugrectangle");
    $zinc->raise("zincdebuglabel");

} # end resizerectangle



# stop drawing rectangular area for search
sub stoprectangle {
    my ($zinc, $searchtype, $text) = @_;
    return unless ($zinc->find('withtag', "zincdebugrectangle"));

    my @atomicgroups = &unsetAtomicity($zinc);
    my @coords = $zinc->coords0("zincdebugrectangle");
    my @items;
    for my $item ($zinc->find($searchtype, @coords, 1, 1)) {
	push (@items, $item) unless $zinc->hastag($item, "zincdebugrectangle") or
	    $zinc->hastag($item, "zincdebuglabel");
    }
    &restoreAtomicity($zinc, @atomicgroups);
    if (@items) {
	&showresult($text, $zinc, @items);
    } else {
	$zinc->remove("zincdebugrectangle", "zincdebuglabel");
    }

} # end stoprectangle



# in order to avoid find problems with group atomicity, we set all -atomic
# attributes to 0
sub unsetAtomicity {
    my $zinc = shift;
    my @groups = $zinc->find('withtype', 'group');
    my @atomicgroups;
    for my $group (@groups) {
	if ($zinc->itemcget($group, -atomic)) {
	    push(@atomicgroups, $group);
	    $zinc->itemconfigure($group, -atomic => 0);
	}
    }
    return @atomicgroups;
    
} # end unsetAtomicity



sub restoreAtomicity {
    my $zinc = shift;
    my @atomicgroups = @_;
    for my $group (@atomicgroups) {
	$zinc->itemconfigure($group, -atomic => 1);
    }

} # end restoreAtomicity



# display search entry field
sub searchentry {
    my $zinc = shift;
    $search_tl->destroy if $search_tl and Tk::Exists($search_tl);
    $search_tl = $zinc->Toplevel;
    $search_tl->title("Specific search");
    my $fm = $search_tl->Frame->pack(-side => 'top');
    $fm->Label(-text => "Item TagOrId : ",
	       )->pack(-side => 'left', -padx => 10, -pady => 10);
    my $entry = $fm->Entry(-width => 20)->pack(-side => 'left',
					       -padx => 10, -pady => 10);
    my $status = $search_tl->Label(-foreground => 'sienna',
				   )->pack(-side => 'top');
    $search_tl->Button(-text => 'Close',
		       -command => sub {$search_tl->destroy},
		       )->pack(-side => 'top', -pady => 10);
    $entry->focus;
    $entry->delete(0, 'end');
    $entry->insert(0, $searchEntryValue{$zinc}) if $searchEntryValue{$zinc};
    $entry->bind('<Key-Return>', [sub {
	$status->configure(-text => "");
	$status->update;
	$searchEntryValue{$zinc} = $entry->get();
	my @items = $zinc->find('withtag', $searchEntryValue{$zinc});
	if (@items) {
	    &showresult("Search with TagOrId $searchEntryValue{$zinc}", $zinc, @items);
	} else {
	    $status->configure(-text => "No such TagOrId ($searchEntryValue{$zinc})");
	}
    }]);
    
} # end searchentry


#---------------------------------------------------------------------------
#
# RESULTS DISPLAY PRIVATE FUNCTIONS
#
#---------------------------------------------------------------------------

# display in a toplevel the result of search ; a new toplevel destroyes the
# previous one
sub showresult {
    my ($label, $zinc, @items) = @_;
    # toplevel (re-)creation
    $result_tl->destroy if Tk::Exists($result_tl);
    $result_tl = $zinc->Toplevel();
    my $title = "Zinc Debug";
    $title .= " - $label" if $label;
    $result_tl->title($title);
    $result_tl->geometry('+10+20');
    my $fm = $result_tl->Frame()->pack(-side => 'bottom',
				       );
    $fm->Button(-text => 'Help',
		-command => [\&showHelpAboutAttributes, $zinc]
		)->pack(-side => 'left', -padx => 40, -pady => 10);
    $fm->Button(-text => 'Close',
		-command => sub {
		    $result_tl->destroy;
		    $zinc->remove("zincdebugrectangle", "zincdebuglabel");
		})->pack(-side => 'left', -padx => 40, -pady => 10);
    
    # scrolled pane creation
    my $heightmax = 500;
    my $height = 100 + 50*@items;
    my $width = $result_tl->screenwidth;
    $width = 1200 if $width > 1200;
    $height = $heightmax if $height > $heightmax;
    $result_fm = $result_tl->Scrolled('Listbox',
			       -scrollbars => 'se',
			       );

    $result_fm = $result_tl->Scrolled('Pane',
				      -scrollbars => 'oe',
				      -height => 200,
				      );
    
    # attributes display
    &showattributes($zinc, $result_fm, \@items);
    
    $result_fm->pack(-padx => 10, -pady => 10,
		     -ipadx => 10,
		     -fill => 'both',
		     -expand => 1,
		     );

} # end showresult



sub showalloptions {
    my ($zinc, $item, $fmp) = @_;
    my $tl = $fmp->Toplevel;
    my $title = "All options of item $item";
    $tl->title($title);
    $tl->geometry('-10+0');
    
    # header
    #----------------
    my $fm_top = $tl->Frame()->pack(-fill => 'x', -expand => 0,
				    -padx => 10, -pady => 10,
				   -ipadx => 10,
				   );
    # show item
    my $btn = $fm_top->Button(-height => 2,
			      -text => 'Show Item',
			      )->pack(-side => 'left', -fill => 'x', -expand => 1);
    $btn->bind('<1>', [\&highlightitem, $zinc, $item, 0]);
    $btn->bind('<2>', [\&highlightitem, $zinc, $item, 1]);
    $btn->bind('<3>', [\&highlightitem, $zinc, $item, 2]);
    # bounding box
    $btn = $fm_top->Button(-height => 2,
			   -text => 'Bounding Box',
			   )->pack(-side => 'left', -fill => 'x', -expand => 1);
    $btn->bind("<1>", [\&showbbox, $zinc, $item]);
    $btn->bind("<ButtonRelease-1>", [\&hidebbox, $zinc]);
    # transformations
    $btn = $fm_top->Button(-height => 2,
			   -text => "treset")
	->pack(-side => 'left', -fill => 'x', -expand => 1);
    $btn->bind('<1>', [\&showtransfo, $zinc, $item, 0]);
    $btn->bind('<2>', [\&showtransfo, $zinc, $item, 1]);
    $btn->bind('<3>', [\&showtransfo, $zinc, $item, 2]);
    

    # footer
    #----------------
    $tl->Button(-text => 'Close',
		-command => sub {$tl->destroy})->pack(-side => 'bottom');
    # option scrolled frame
    #-----------------------
    my $fm = $tl->Scrolled('Pane',
			   -scrollbars => 'oe',
			   -height => 500,
			   )->pack(-padx => 10, -pady => 10,
				   -ipadx => 10,
				   -expand => 1,
				   -fill => 'both');
    
   my $bgcolor = 'ivory';
    $fm->Label(-text => 'Option', -background => $bgcolor, -relief => 'ridge')
	->grid(-row => 2, -col => 1, -ipady => 10, -ipadx => 5, -sticky => 'nswe');
    $fm->Label(-text => 'Value', -background => $bgcolor, -relief => 'ridge')
	->grid(-row => 2, -col => 2, -ipady => 10, -ipadx => 5, -sticky => 'nswe');

    my @options = $zinc->itemconfigure($item);
    my $i = 3;
    for my $elem (@options) {
	my ($option, $type, $value) = (@$elem)[0,1,4];
	$fm->Label(-text => $option, -relief => 'ridge')
	    ->grid(-row => $i, -col => 1, -ipady => 5, -ipadx => 5, -sticky => 'nswe');
	&entryoption($fm, $item, $zinc, $option, undef, 50, 25)
	    ->grid(-row => $i, -col => 2, -ipady => 5, -ipadx => 5, -sticky => 'nswe');
	$i++;
    }
    
} # end showalloptions



sub showdevicecoords {
    my ($zinc, $item) = @_;
    &showcoords($zinc, $item, 1);

} # end showdevicecoords



sub showcoords {
    my ($zinc, $item, $deviceflag) = @_;
    my $bgcolor = 'ivory';
    my $bgcolor2 = 'gray75';
    $coords_tl->destroy if Tk::Exists($coords_tl) and not $deviceflag;
    
    $coords_tl = $zinc->Toplevel();
    my $title = "Zinc Debug";
    if ($deviceflag) {
	$title .= " - Coords of item $item";
    } else {
	$title .= " - Device coords of item $item";
    }
    $coords_tl->title($title);
    $coords_tl->geometry('+10+20');
    $coords_tl->Button(-text => 'Close',
		       -command => sub {
			   $coords_tl->destroy;
		       })->pack(-side => 'bottom');
    # scrolled pane creation
    my $coords_fm = $coords_tl->Scrolled('Pane',
					 -scrollbars => 'oe',
					 -height => 200,
					 )->pack(-padx => 10, -pady => 10,
						 -ipadx => 10,
						 -expand => 1,
						 -fill => 'both');
    my @contour;
    my $contournum = $zinc->contour($item);
    for (my $i=0; $i < $contournum; $i++) {
	my @coords = $zinc->coords($item, $i);
	if (!ref $coords[0]) {
	    ## The first item of the list is not a reference, so the
	    ## list is guarranted to be a flat list (x, y, ...)
	    ## normaly of only one pair of (x y)
	    @coords = $zinc->transform(scalar $zinc->group($item), 1, [@coords])
		if $deviceflag;
	    for (my $j=0; $j < @coords; $j += 2) {
		push(@{$contour[$i]}, [$coords[$j], $coords[$j+1]]);
	    }
	}
	else {
	    ## the first element is an array reference, as every
	    ## other elements of the list
	    for (my $j=0; $j < @coords; $j ++) {
		my @c = @{$coords[$j]};
		@c = $zinc->transform(scalar $zinc->group($item), 1, [@c])
		    if $deviceflag;
		push(@{$contour[$i]}, [@c]);
	    }
	}
    }
    my $row = 1;
    my $col = 1;
    for (my $i=0; $i < @contour; $i++) {
	$col = 1;
	$coords_fm->Label(-text => "Contour $i",
			  -background => $bgcolor,
			  -relief => 'ridge')->grid(-row => $row,
						    -col => $col++,
						    -ipadx => 5,
						    -ipady => 5,
						    -sticky => 'nswe');
	for my $coords (@{$contour[$i]}) {
	    if ($col > 10) {
		$col = 2;
		$row++;
	    }
	    $coords->[0] =~ s/\.(\d\d).*/\.$1/;
	    $coords->[1] =~ s/\.(\d\d).*/\.$1/;
	    my @opt;
	    if (defined $coords->[2]) {
		@opt = (-text => sprintf('%s, %s, %s', @$coords),
			-underline => length(join(',', @$coords)) + 1,
			);
	    } else {
		@opt = (-text => sprintf('%s, %s', @{$coords}[0,1]));
	    }
	    $coords_fm->Label(@opt,
			      -width => 15,
			      -relief => 'ridge')->grid(-row => $row,
							-ipadx => 5,
							-ipady => 5,
							-col => $col++,
							-sticky => 'nswe');
	}
	$row++;
    }

} # end showcoords


# display in a toplevel group's attributes
sub showgroupattributes {
    my ($zinc, $item) = @_;
    my $tl = $zinc->Toplevel;
    my $title = "About group $item";
    $tl->title($title);

    # header
    #-----------

    my $fm_top = $tl->Frame()->pack(-fill => 'x', -expand => 0,
				    -padx => 10, -pady => 10,
				   -ipadx => 10,
				   );
    # content
    $fm_top->Button(-command => [\&showgroupcontent, $zinc, $item],
		    -height => 2,
		    -text => 'Content',
		    )->pack(-side => 'left', -fill => 'both', -expand => 1);
    # bounding box
    my $btn = $fm_top->Button(-height => 2,
			  -text => 'Bounding Box',
			  )->pack(-side => 'left', -fill => 'both', -expand => 1);
    $btn->bind("<1>", [\&showbbox, $zinc, $item]);
    $btn->bind("<ButtonRelease-1>", [\&hidebbox, $zinc]);

    # transformations
    my $trbtn = $fm_top->Button(-height => 2,
			  -text => "treset")
	->pack(-side => 'left', -fill => 'both', -expand => 1);
    if ($item == 1) {
	$trbtn->configure(-state => 'disabled');
    } else {
	$trbtn->bind('<1>', [\&showtransfo, $zinc, $item, 0]);
	$trbtn->bind('<2>', [\&showtransfo, $zinc, $item, 1]);
	$trbtn->bind('<3>', [\&showtransfo, $zinc, $item, 2]);
    }
    
    # parent group
    my $gr = $zinc->group($item);
    my $bpg = $fm_top->Button(-command => [\&showgroupattributes, $zinc, $gr],
			      -height => 2,
			      -text => "Parent group [$gr]",
			      )->pack(-side => 'left', -fill => 'both', -expand => 1);
    $bpg->configure(-state => 'disabled') if  $item == 1;
    

    # footer
    #-----------
    $tl->Button(-text => 'Close',
		-command => sub {$tl->destroy})->pack(-side => 'bottom');
    
    # coords and options scrolled frame
    #----------------------------------
    my $fm = $tl->Scrolled('Pane',
			   -scrollbars => 'oe',
			   -height => 400,
			   )->pack(-padx => 10, -pady => 10,
				   -ipadx => 10,
				   -expand => 1,
				   -fill => 'both');
    
    my $r = 1;
    my $bgcolor = 'ivory';
    # coords
    $fm->Label(-text => 'Coordinates', -background => $bgcolor, -relief => 'ridge')
	->grid(-row => $r++, -col => 1, -ipady => 10, -ipadx => 5, -sticky => 'nswe',
	       -columnspan => 2);	# coords
    $fm->Label(-text => 'Coords', -relief => 'ridge')
	->grid(-row => $r, -col => 1, -ipady => 10, -ipadx => 5, -sticky => 'nswe');
    my @coords = $zinc->coords($item);
    my $coords;
    if (@coords == 2) {
	my $x0 = int($coords[0]);
	my $y0 = int($coords[1]);
	$coords = "($x0, $y0)";
    } elsif (@coords == 4) {
	my $x0 = int($coords[0]);
	my $y0 = int($coords[1]);
	my $x1 = int($coords[2]);
	my $y1 = int($coords[3]);
	$coords = "($x0, $y0, $x1, $y1)";
	print "we should not go through this case (1)!\n";
    } else {
	my $x0 = int($coords[0]);
	my $y0 = int($coords[1]);
	my $xn = int($coords[$#coords-1]);
	my $yn = int($coords[$#coords]);
	my $n = @coords/2 - 1;
	$coords = "C0=($x0, $y0), ..., C".$n."=($xn, $yn)";
	print "we should not go through this case (2d)!\n";
    }
    $fm->Label(-text => $coords, -relief => 'ridge')
	->grid(-row => $r++, -col => 2, -ipady => 10, -ipadx => 5, -sticky => 'nswe');
    # device coords
    $fm->Label(-text => 'Device coords', -relief => 'ridge')
	->grid(-row => $r, -col => 1, -ipady => 10, -ipadx => 5, -sticky => 'nswe');
    @coords = $zinc->transform(scalar $zinc->group($item), 1, [@coords]);
    if (@coords == 2) {
	my $x0 = int($coords[0]);
	my $y0 = int($coords[1]);
	$coords = "($x0, $y0)";
    } elsif (@coords == 4) {
	my $x0 = int($coords[0]);
	my $y0 = int($coords[1]);
	my $x1 = int($coords[2]);
	my $y1 = int($coords[3]);
	$coords = "($x0, $y0, $x1, $y1)";
	print "we should not go through this case (3)!\n";
    } else {
	my $x0 = int($coords[0]);
	my $y0 = int($coords[1]);
	my $xn = int($coords[$#coords-1]);
	my $yn = int($coords[$#coords]);
	my $n = @coords/2 - 1;
	$coords = "C0=($x0, $y0), ..., C".$n."=($xn, $yn)";
	print "we should not go through this case (4)!\n";
    }
    $fm->Label(-text => $coords, -relief => 'ridge')
	->grid(-row => $r++, -col => 2, -ipady => 10, -ipadx => 5, -sticky => 'nswe');

    # options
    $fm->Label(-text => 'Option', -background => $bgcolor, -relief => 'ridge')
	->grid(-row => $r, -col => 1, -ipady => 10, -ipadx => 5, -sticky => 'nswe');
    $fm->Label(-text => 'Value', -background => $bgcolor, -relief => 'ridge')
	->grid(-row => $r++, -col => 2, -ipady => 10, -ipadx => 5, -sticky => 'nswe');

    my @options = $zinc->itemconfigure($item);
    for my $elem (@options) {
	my ($option, $value) = (@$elem)[0,4];
	$fm->Label(-text => $option, -relief => 'ridge')
	    ->grid(-row => $r, -col => 1, -ipady => 10, -ipadx => 5, -sticky => 'nswe');
	my $w;
	if ($option and $option eq '-tags') {
	    $value = join("\n", @$value);
	    $w = $fm->Label(-text => $value, -relief => 'ridge');
	} elsif ($option and $option eq '-clip' and $value and $value > 0) {
	    $value .= " (". $zinc->type($value) .")";
	    $w = $fm->Label(-text => $value, -relief => 'ridge');
	} else {
	    $w = &entryoption($fm, $item, $zinc, $option, undef, 50, 25);
	}
	$w->grid(-row => $r, -col => 2, -ipady => 10, -ipadx => 5, -sticky => 'nswe');
	$r++;
    }

} # end showgroupattributes


# display in a toplevel the content of a group item
sub showgroupcontent {
    my ($zinc, $group) = @_;
    my $tl = $zinc->Toplevel;
    
    my @items = $zinc->find('withtag', $group.".");
    my $title = "Content of group $group";
    $tl->title($title);
    my $fm2 = $tl->Frame()->pack(-side => 'bottom',
				 );
    $fm2->Button(-text => 'Help',
		-command => [\&showHelpAboutAttributes, $zinc]
		 )->pack(-side => 'left', -padx => 40, -pady => 10);
    $fm2->Button(-text => 'Close',
		-command => sub {
		    $tl->destroy;
		})->pack(-side => 'left', -padx => 40, -pady => 10);

    # coords and options scrolled frame
    #----------------------------------
    my $fm = $tl->Scrolled('Pane',
			   -scrollbars => 'oe',
			   -height => 200,
			   )->pack(-padx => 10, -pady => 10,
				   -ipadx => 10,
				   -expand => 1,
				   -fill => 'both');

    &showattributes($zinc, $fm, [@items]);

} # end showgroupcontent

# display the bbox of a group item
sub showbbox {
    my ($btn, $zinc, $item) = @_;
    my @bbox  = $zinc->bbox($item);
    if (scalar @bbox == 4) {
	# If item is visible, rectangle is drawm surround it.
	# Else, a warning is displayed.
	unless (&itemisoutside($zinc, @bbox)) {
	    my $i = -2;
	    for ('white', 'blue', 'white') {
		$zinc->add('rectangle', 1,
			   [$bbox[0] + $i, $bbox[1] + $i,
			    $bbox[2] - $i, $bbox[3] - $i],
			   -linecolor => $_,
			   -linewidth => 1,
			   -tags => ['zincdebugbbox']);
		$i += 2;
	    }
	}
    }
    $zinc->raise('zincdebugbbox');

} # end showgroupbbox


sub hidebbox {
    my ($btn, $zinc) = @_;
    $zinc->remove("zincdebugbbox");

} # end hidegroupbbox


# highlight an item (by cloning it and hiding other found items)
# why cloning? because we can't simply make visible an item which
# belongs to an invisible group.
sub highlightitem {
    my ($btn, $zinc, $item, $level) = @_;
    #print "highlightitem\n";
    return if $showitemflag or $item == 1;
    $showitemflag = 1;
    
    &surrounditem($zinc, $item, $level);
    
    $btn->bind('<ButtonRelease>', [\&undohighlightitem, $zinc]) if $btn;

} # end highlightitem


sub showtransfo {
    my ($btn, $zinc, $item, $level) = @_;

    my $anim = &highlighttransfo($zinc, $item, $level);

    $btn->bind('<ButtonRelease>', [\&undohighlighttransfo, $zinc, $anim]) if $btn;

} # end showtransfo




sub itemisoutside {
    my $zinc = shift;
    my @bbox = @_;
    return unless @bbox == 4;
    my $outflag;
    $WARNING = 0;
    if ($bbox[2] < 0) {
	if ($bbox[1] >  $wheight{$zinc}) {
	    $outflag = 'left+bottom';
	} elsif ($bbox[3] < 0) {
	    $outflag = 'left+top';
	} else {
	    $outflag = 'left';
	} 
    } elsif ($bbox[0] > $wwidth{$zinc}) {
	if ($bbox[1] >  $wheight{$zinc}) {
	    $outflag = 'right+bottom';
	} elsif ($bbox[3] < 0) {
	    $outflag = 'right+top';
	} else {
	    $outflag = 'right';
	}
    } elsif ($bbox[3] < 0) {
	$outflag = 'top';
    } elsif ($bbox[1] > $wheight{$zinc}) {
	$outflag = 'bottom';
    }
    #print "outflag=$outflag bbox=@bbox\n";
    return 0 unless $outflag;
    my $g = $zinc->add('group', 1, -tags => ['zincdebug']);
    my $hw = 110;
    my $hh = 80;
    my $r = 5;
    $zinc->add('rectangle', $g, [-$hw, -$hh, $hw, $hh],
	       -filled => 1,
	       -linecolor => 'sienna',
	       -linewidth => 3,
	       -fillcolor => 'bisque',
	       -priority => 1,
	       );
    $zinc->add('text', $g,
	       -position => [0, 0],
	       -color => 'sienna',
	       -font => '-b&h-lucida-bold-i-normal-sans-34-240-*-*-p-*-iso8859-1',
	       -anchor => 'center',
	       -priority => 2,
	       -text => "Item is\noutside\nwindow\n");
    my ($x, $y);
    if ($outflag eq 'bottom') {
	$x = $bbox[0] + ($bbox[2]-$bbox[0])/2;
	$x = $hw + 10 if $x < $hw + 10;
	$x = $wwidth{$zinc} - $hw - 10 if $x > $wwidth{$zinc} - $hw - 10;
	$y = $wheight{$zinc} - $hh - 10;
    } elsif ($outflag eq 'top') {
	$x = $bbox[0] + ($bbox[2]-$bbox[0])/2;
	$x = $hw + 10 if $x < $hw + 10;
	$x = $wwidth{$zinc} - $hw - 10if $x > $wwidth{$zinc} - $hw - 10;
	$y = $hh + 10;
    } elsif ($outflag eq 'left') {
	$x = $hw + 10;
	$y = $bbox[1] + ($bbox[3]-$bbox[1])/2;
	$y = $hh + 10 if $y < $hh + 10;
	$y = $wheight{$zinc} - $hh - 10 if $y > $wheight{$zinc} - $hh - 10;
    } elsif ($outflag eq 'right') {
	$x = $wwidth{$zinc} - $hw - 10;
	$y = $bbox[1] + ($bbox[3]-$bbox[1])/2;
	$y = $hh + 10 if $y < $hh + 10;
	$y = $wheight{$zinc} - $hh - 10 if $y > $wheight{$zinc} - $hh - 10;
    } elsif ($outflag eq 'left+top') {
	$x = $hw + 10;
	$y = $hh + 10;
    } elsif ($outflag eq 'left+bottom') {
	$x = $hw + 10;
	$y = $wheight{$zinc} - $hh - 10;
    } elsif ($outflag eq 'right+top') {
	$x = $wwidth{$zinc} - $hw - 10;
	$y = $hh + 10;
    } elsif ($outflag eq 'right+bottom') {
	$x = $wwidth{$zinc} - $hw - 10;
	$y = $wheight{$zinc} - $hh - 10;
    }
    $zinc->coords($g, [$x, $y]);
    $zinc->raise('zincdebug');
    
} # end itemisoutside


sub highlighttransfo {
    my ($zinc, $item, $level) = @_;
    $zinc->remove("zincdebug");
    my $g = $zinc->add('group', 1);
    my $g0 = $zinc->add('group', $g, -alpha => 0);
    my $g1 = $zinc->add('group', $g);
    # clone item and reset its transformation
    my $clone0 = $zinc->clone($item, -visible => 1, -tags =>['zincdebug']);
    $zinc->treset($clone0);
    # clone item and preserve its transformation
    my $clone1 = $zinc->clone($item, -visible => 1, -tags => ['zincdebug']);
    # move clones is dedicated group
    $zinc->chggroup($clone0, $g0, 1);
    $zinc->chggroup($clone1, $g1, 1);
    # create a rectangle around 
    my @bbox0  = $zinc->bbox($g);
    if (scalar @bbox0 == 4) {
	my @bbox = $zinc->transform(1, $g, [@bbox0]);
	# If item is visible, rectangle is drawm surround it.
	# Else, a warning is displayed.
	unless (&itemisoutside($zinc, @bbox0)) {
	    my $r = $zinc->add('rectangle', $g,
			       [$bbox[0] - 10, $bbox[1] - 10,
				$bbox[2] + 10, $bbox[3] + 10],
			       -filled => 1,
			       -linewidth => 0,
			       -tags => ['zincdebug'],
			       -fillcolor => "gray90");
	    $zinc->itemconfigure($r, -fillcolor => "gray50") if $level == 1;
	    $zinc->itemconfigure($r, -fillcolor => "gray20") if $level == 2;
	    my $i = 0;
	    for ('white', 'green', 'white') {
		$zinc->add('rectangle', $g,
			   [$bbox[0] - 5 - 2*$i, $bbox[1] - 5 - 2*$i,
			    $bbox[2] + 5 + 2*$i, $bbox[3] + 5 + 2*$i],
			   -linecolor => $_,
			   -linewidth => 1,
			   -tags => ['zincdebug']);
		$i++;
	    }
	}
    }
    # raise
    $zinc->raise('zincdebug');
    $zinc->raise($clone0);
    $zinc->raise($clone1);
    # animation
    my $anim;
    if ($zinc->cget(-render) == 0) {
	$anim = $zinc->after(150, [sub {
	    $zinc->itemconfigure($g1, -visible => 0);
	    $zinc->itemconfigure($g0, -visible => 1);
	    $zinc->update;
	}]);
    } else {
	my $maxsteps = 5;
	$step = $maxsteps;
	$anim = $zinc->repeat(100, [sub {
	    return if $step < 0;
	    $zinc->itemconfigure($g1, -alpha => ($step)*100/$maxsteps);
	    $zinc->itemconfigure($g0, -alpha => ($maxsteps-$step)*100/$maxsteps);
	    $zinc->update;
	    $step--;
	}]);


    }
    return $anim;

} # end highlighttransfo


sub undohighlighttransfo {
    my ($btn, $zinc, $anim) = @_;
    $btn->bind('ReleaseButton', '') if $btn;
    $zinc->remove('zincdebug');
    $zinc->afterCancel($anim);

} # end undohighlightitem


# draw a rectangle arround the selected item
sub surrounditem {
    my ($zinc, $item, $level) = @_;
    $zinc->remove("zincdebug");
    # get item ancestors
    my @itemancestors = reverse($zinc->find('ancestors', $item));
    # skip group 1
    shift(@itemancestors);
    # create item's tree with good transformations
    my $topgroup = 1;
    for my $g (@itemancestors) {
	my $gc = $zinc->add('group', $topgroup, -tags => ['zincdebug']);
	$zinc->tsave($g, "mytrans");
	my @c = $zinc->coords($g);
	$zinc->trestore($gc, "mytrans");
	$zinc->coords($gc, [@c]);
	$zinc->tdelete("mytrans");
	$topgroup = $gc;
    }
    # cloning
    my $clone = $zinc->clone($item, -visible => 1, -tags => ['zincdebug']);
    # move in topgroup  
    $zinc->chggroup($clone, $topgroup);
    # create a rectangle around 
    my @bbox0  = $zinc->bbox($clone);
    if (scalar @bbox0 == 4) {
	my @bbox = $zinc->transform(1, $topgroup, [@bbox0]);
	# If item is visible, rectangle is drawm surround it.
	# Else, a warning is displayed.
	unless (&itemisoutside($zinc, @bbox0)) {
	    if (defined($level) and $level > 0) {
		my $r = $zinc->add('rectangle', $topgroup,
				   [$bbox[0] - 10, $bbox[1] - 10,
				    $bbox[2] + 10, $bbox[3] + 10],
				   -linewidth => 0,
				   -filled => 1,
				   -tags => ['zincdebug'],
				   -fillcolor => "gray20");
		$zinc->itemconfigure($r, -fillcolor => "gray80") if $level == 1;
	    } 
	    my $i = 0;
	    for ('white', 'red', 'white') {
		$zinc->add('rectangle', $topgroup,
			   [$bbox[0] - 5 - 2*$i, $bbox[1] - 5 - 2*$i,
			    $bbox[2] + 5 + 2*$i, $bbox[3] + 5 + 2*$i],
			   -linecolor => $_,
			   -linewidth => 1,
			   -tags => ['zincdebug']);
		$i++;
	    }
	}
    }
    # raise
    $zinc->raise('zincdebug');
    $zinc->raise($clone);
   
} # end surrounditem


sub undohighlightitem {
    my ($btn, $zinc) = @_;
    #print "undohighlightitem\n";
    $btn->bind('ReleaseButton', '') if $btn;
    $zinc->remove('zincdebug');
    $showitemflag = 0;

} # end undohighlightitem



sub showbanner {
    my $fm = shift;
    my $i = shift;
    my $bgcolor = 'ivory';
    $fm->Label(-text => 'Id', -background => $bgcolor, -relief => 'ridge')
	->grid(-row => $i, -col => 1, -ipady => 10, -ipadx => 5, -sticky => 'nswe');
    $fm->Label(-text => 'Type', -background => $bgcolor, -relief => 'ridge')
	->grid(-row => $i, -col => 2, -ipady => 10, -ipadx => 5, -sticky => 'nswe');
    $fm->Label(-text => 'Group', -background => $bgcolor, -relief => 'ridge')
	->grid(-row => $i, -col => 3, -ipady => 10, -ipadx => 5, -sticky => 'nswe');
    $fm->Label(-text => 'Priority', -background => $bgcolor, -relief => 'ridge')
	->grid(-row => $i, -col => 4, -ipady => 10, -ipadx => 5, -sticky => 'nswe');
    $fm->Label(-text => 'Sensitive', -background => $bgcolor, -relief => 'ridge')
	->grid(-row => $i, -col => 5, -ipady => 10, -ipadx => 5, -sticky => 'nswe');
    $fm->Label(-text => 'Visible', -background => $bgcolor, -relief => 'ridge')
	->grid(-row => $i, -col => 6, -ipady => 10, -ipadx => 5, -sticky => 'nswe');
    $fm->Label(-text => 'Coords', -background => $bgcolor, -relief => 'ridge')
	->grid(-row => $i, -col => 7, -ipady => 10, -ipadx => 5, -sticky => 'nswe');
    $fm->Label(-text => 'Device coords', -background => $bgcolor, -relief => 'ridge')
	->grid(-row => $i, -col => 8, -ipady => 10, -ipadx => 5, -sticky => 'nswe');
    $fm->Label(-text => 'Bounding box', -background => $bgcolor, -relief => 'ridge')
	->grid(-row => $i, -col => 9, -ipady => 10, -ipadx => 5, -sticky => 'nswe');
    $fm->Label(-text => 'Tags', -background => $bgcolor, -relief => 'ridge')
	->grid(-row => $i, -col => 10, -ipady => 10, -ipadx => 5, -sticky => 'nswe');
    $fm->Label()->grid(-row => 1, -col => 11, -pady => 10);
     
} # end showbanner


# display in a grid the values of most important attributes 
sub showattributes {
    my ($zinc, $fm, $items) = @_;
    unless ($wwidth{$zinc} > 1) {
        $zinc->update;
	my $geom = $zinc->geometry =~ /(\d+)x(\d+)+/=~ /(\d+)x(\d+)+/;
	($wwidth{$zinc}, $wheight{$zinc}) = ($1, $2);
    }
    my $bgcolor = 'ivory';
    my $i = 1;
    &showbanner($fm, $i++);
    for my $item (@$items) {
	my $type = $zinc->type($item);
	# transformations
	my $btn = $fm->Button(-text => 'treset')
	    ->grid(-row => $i, -col => 0, -sticky => 'nswe', -ipadx => 5);
	$btn->bind('<1>', [\&showtransfo, $zinc, $item, 0]);
	$btn->bind('<2>', [\&showtransfo, $zinc, $item, 1]);
	$btn->bind('<3>', [\&showtransfo, $zinc, $item, 2]);
	# id
	my $idbtn =
	    $fm->Button(-text => $item,
			-foreground => 'red'
			)->grid(-row => $i, -col => 1, -sticky => 'nswe',
				-ipadx => 5);
	$idbtn->bind('<1>', [\&highlightitem, $zinc, $item, 0]);
	$idbtn->bind('<2>', [\&highlightitem, $zinc, $item, 1]);
	$idbtn->bind('<3>', [\&highlightitem, $zinc, $item, 2]);
	# type
	if ($type eq 'group') {
	    $fm->Button(-text => $type, 
			-command => [\&showgroupcontent, $zinc, $item])
		->grid(-row => $i, -col => 2, -sticky => 'nswe', -ipadx => 5);
	} else {
	    $fm->Label(-text => $type, -relief => 'ridge')
		->grid(-row => $i, -col => 2, -sticky => 'nswe', -ipadx => 5);
	}
	# group
	my $group = $zinc->group($item);
	$fm->Button(-text => $group,
		    -command => [\&showgroupattributes, $zinc, $group])
	    ->grid(-row => $i, -col => 3, -sticky => 'nswe', -ipadx => 5);
	# priority
	&entryoption($fm, $item, $zinc, -priority)
	    ->grid(-row => $i, -col => 4, -sticky => 'nswe', -ipadx => 5);
	# sensitiveness
	&entryoption($fm, $item, $zinc, -sensitive)
	    ->grid(-row => $i, -col => 5, -sticky => 'nswe', -ipadx => 5);
	# visibility
	&entryoption($fm, $item, $zinc, -visible)
	    ->grid(-row => $i, -col => 6, -sticky => 'nswe', -ipadx => 5);
	# coords
	my @coords = $zinc->coords($item);
	my $coords;
	if (!ref $coords[0]) {
	    my $x0 = int($coords[0]);
	    my $y0 = int($coords[1]);
	    $coords = "($x0, $y0)";
	} else {
	    my @points0 = @{$coords[0]};
	    my $n = $#coords;
	    my @pointsN = @{$coords[$n]};
	    my $x0 = int($points0[0]);
	    my $y0 = int($points0[1]);
	    my $xn = int($pointsN[0]);
	    my $yn = int($pointsN[1]);
	    if ($n == 1) { ## a couple of points
		$coords = "($x0, $y0, $xn, $yn)";
	    } else {
		$coords = "C0=($x0, $y0), ..., C".$n."=($xn, $yn)";
	    }
	}
	if (@coords > 2) {
	    $fm->Button(-text => $coords,
			-command => [\&showcoords, $zinc, $item])
		->grid(-row => $i, -col => 7, -sticky => 'nswe', -ipadx => 5);
	} else {
	    $fm->Label(-text => $coords, -relief => 'ridge')
		->grid(-row => $i, -col => 7, -sticky => 'nswe', -ipadx => 5);
	}
	# device coords
	@coords = $zinc->transform(scalar $zinc->group($item), 1, [@coords]);
	if (!ref $coords[0]) {
	    my $x0 = int($coords[0]);
	    my $y0 = int($coords[1]);
	    $coords = "($x0, $y0)";
	} else {
	    my @points0 = @{$coords[0]};
	    my $n = $#coords;
	    my @pointsN = @{$coords[$n]};
	    my $x0 = int($points0[0]);
	    my $y0 = int($points0[1]);
	    my $xn = int($pointsN[0]);
	    my $yn = int($pointsN[1]);
	    if ($n == 1) { ## a couple of points
		$coords = "($x0, $y0, $xn, $yn)";
	    } else {
		$coords = "C0=($x0, $y0), ..., C".$n."=($xn, $yn)";
	    }
	}
	if (@coords > 2) {
	    $fm->Button(-text => $coords,
			-command => [\&showdevicecoords, $zinc, $item])
		->grid(-row => $i, -col => 8, -sticky => 'nswe', -ipadx => 5);
	} else {
	    $fm->Label(-text => $coords, -relief => 'ridge')
		->grid(-row => $i, -col => 8, -sticky => 'nswe', -ipadx => 5);
	}
	# bounding box
	my @bbox = $zinc->bbox($item);
	if (@bbox == 4) {
	    my $btn = $fm->Button(-text => "($bbox[0], $bbox[1]), ($bbox[2], $bbox[3])")
		->grid(-row => $i, -col => 9, -sticky => 'nswe', -ipadx => 5);
	    $btn->bind('<1>', [\&showbbox, $zinc, $item]);
	    $btn->bind('<ButtonRelease-1>', [\&hidebbox, $zinc]) ;
	} else {
	    $fm->Label(-text => "--", , -relief => 'ridge')
		->grid(-row => $i, -col => 9, -sticky => 'nswe', -ipadx => 5);
	}
	# tags
  	my @tags = $zinc->gettags($item);
	&entryoption($fm, $item, $zinc, -tags, join("\n", @tags), 30, scalar @tags)
	    ->grid(-row => $i, -col => 10, -sticky => 'nswe', -ipadx => 5);

	# other options
	$fm->Button(-text => 'All options',
		    -command => [\&showalloptions, $zinc, $item, $fm])
	    ->grid(-row => $i, -col => 11, -sticky => 'nswe', -ipadx => 5);
	$i++;
	&showbanner($fm, $i++) if ($i % 15 == 0);
    }
    $fm->update;
    return ($fm->width, $fm->height);
    
} # end showattributes

#---------------------------------------------------------------------------
#
# SNAPSHOT FUNCTIONS
#
#---------------------------------------------------------------------------

# print a zinc window in png format
sub printWindow {
    exit if $saving;
    $saving = 1;
    my ($zinc,$basename,$verbosity) = @_;
    my $id = $zinc->id;
    my $filename = $basename . $imagecounter . ".png";
    $imagecounter++;
    my $original_cursor = ($zinc->configure(-cursor))[3];
    $zinc->configure(-cursor => 'watch');
    $zinc->update;
    my $res = system("import", -window, $id, $filename);
    $zinc->configure(-cursor => $original_cursor);
    
    $saving = 0;
    if ($res) {
	&showErrorWhilePrinting($zinc, $res)
	}
    else {
	my $dir = `pwd`; chomp ($dir);
	print "Tk::Zinc::Debug: Zinc window snapshot saved in $dir". "/$filename\n"
	    if $verbosity;
    }

} # end printWindow


# display complete help screen
sub showErrorWhilePrinting {
    my ($zinc, $res) = @_;
    my $dir = `pwd`; chomp ($dir);
    $help_print->destroy if $help_print and Tk::Exists($help_print);
    $help_print = $zinc->Dialog(-title => 'Zinc Print info',
				-text =>
				"To acquire a TkZinc window snapshot, you must " .
				"have access to the import command, which is ".
				"part of imageMagic package\n\n".
				"You must also have the rights to write ".
				"in the current dir : $dir",
				-bitmap => 'warning',
				);
    $help_print->after(300, sub {$help_print->grabRelease});
    $help_print->Show();

} # end showErrorWhilePrinting

#---------------------------------------------------------------------------
#
# HELP FUNCTIONS
#
#---------------------------------------------------------------------------
# display complete help screen
sub showgeneralhelp {
    if (@instances == 1) {
	&showinstancehelp($instances[0], "Tk::Zinc::Debug help", 1);
    } elsif (@instances > 1) {
	$help_tl{gene}->destroy if $help_tl{gene} and Tk::Exists($help_tl{gene});
	$help_tl{gene} = $instances[0]->Toplevel;
	$help_tl{gene}->title("Tk::Zinc::Debug general help");

	my $text = $help_tl{gene}->Scrolled('Text', -font =>
					     scalar $instances[0]->cget(-font),
					     -wrap => 'word',
					     -foreground => 'gray10',
					     -width => 50,
					     -height => 15,
					     -scrollbars => 'osoe',
					     );
	$text->tagConfigure('keyword', -foreground => 'darkblue');
	$text->tagConfigure('title', -foreground => 'ivory',
			    -background => 'gray60',
			    -spacing1 => 3,
			    -spacing3 => 3);

	my $fm = $text->Frame;
	for (my $i=0; $i < @instances; $i++) {
	    my $j = $i + 1;
	    $fm->Label(-text => 'Instance #'.$j)->grid(-row => $j, -column => 1);
	    $fm->Button(-text => 'Show',
			-cursor  => 'top_left_arrow',
			-command => [\&showinstance, $instances[$i]],
			)->grid(-row => $j, -column => 2);
	    
	    $fm->Button(-text => 'Take focus',
			-cursor  => 'top_left_arrow',
			-command => [\&takefocus, $instances[$i]],
			)->grid(-row => $j, -column => 3);
	    
	    $fm->Button(-text => 'Help',
			-cursor  => 'top_left_arrow',
			-command => [\&showinstancehelp, $instances[$i],
				     'Tk::Zinc::Debug help about instance #'.$j],
			)->grid(-row => $j, -column => 4);
	    #&showinstancehelp($_);
	}
	$text->insert('end', "Several instances of Zinc widget are managed. ");
	$text->insert('end', "They are listed in the following table. \n\n\n");
	$text->window('create', 'end', -window => $fm);
	$text->insert('end', "\n\n\nStrike <");
	$text->insert('end', 'Escape', 'keyword');
	$text->insert('end', "> key to display this help message again.");

	$help_tl{gene}->Button(-command => sub {$help_tl{gene}->destroy},
			    -text => 'Close')->pack(-side => 'bottom',
						 -pady => 10);
	$text->pack(-side => 'top', -pady => 10, -padx => 10);
    }
} # end showgeneralhelp

sub showinstancehelp {
    my $zinc = shift;
    my $title = shift;
    my $singleflag = shift;
    &takefocus($zinc);
    $help_tl{$zinc}->destroy if $help_tl{$zinc} and Tk::Exists($help_tl{$zinc});
    if ($singleflag) {
	$help_tl{$zinc} = $zinc->Toplevel;
    } else {
	$help_tl{$zinc} = $help_tl{gene}->Toplevel;
	$help_tl{$zinc}->transient($help_tl{gene}) unless $singleflag;
    }
    $help_tl{$zinc}->title($title);

    my $text = $help_tl{$zinc}->Scrolled('Text', -font => scalar $zinc->cget(-font),
					 -wrap => 'word',
					 -foreground => 'gray10',
					 -width => 50,
					 -height => 32,
					 -scrollbars => 'osoe',
					 );
    $text->tagConfigure('keyword', -foreground => 'darkblue');
    $text->tagConfigure('title', -foreground => 'ivory',
			-background => 'gray60',
			-spacing1 => 3,
			-spacing3 => 3);
    my $zincnb = scalar keys(%instances);
   if ($treeKey{$zinc}) {
	$text->insert('end', " To display the items tree\n", 'title');
	$text->insert('end', "\nUse the <");
	$text->insert('end', $treeKey{$zinc}, 'keyword');
	$text->insert('end', "> sequence.\n\n");

	$text->insert('end', " To generate perl code\n", 'title');
	$text->insert('end', "\nUse the <");
	$text->insert('end', $treeKey{$zinc}, 'keyword');
	$text->insert('end', "> sequence. Then select a branch of the tree ");
	$text->insert('end', "and press on the ");
	$text->insert('end', "Build code", 'keyword');
	$text->insert('end', " button.\n\n");
	
    }
    if ($enclosedModBtn{$zinc}) {
	my $eseq = $enclosedModBtn{$zinc}->[0]."-Button".$enclosedModBtn{$zinc}->[1];
	my $oseq = $overlapModBtn{$zinc}->[0]."-Button".$overlapModBtn{$zinc}->[1];
	$eseq =~ s/^-//;
	$oseq =~ s/^-//;
	$text->insert('end', " To analyse a particular area\n", 'title');
	$text->insert('end', "\nWith <");
	$text->insert('end', $oseq, 'keyword');
	$text->insert('end', "> sequence, create a rectangular area to parse items ");
	$text->insert('end', "which overlap it.\n");
	$text->insert('end', "\nWith <");
	$text->insert('end',  $eseq, 'keyword');
	$text->insert('end', "> sequence, create a rectangular area to parse items ");
	$text->insert('end', "which are enclosed in it.\n\n");
    }
    if ($treeKey{$zinc} or $enclosedModBtn{$zinc}) {
	$text->insert('end', "To analyse a specific item.\n", 'title');
	if ($enclosedModBtn{$zinc}) {
	    $text->insert('end', "\nWith <");
	    $text->insert('end', $searchKey{$zinc}, 'keyword');
	    $text->insert('end', "> sequence, locate a specific item entering ".
			  "its tagOrId.\n");
	}
	if ($treeKey{$zinc}) {
	    my $tseq = $treeModBtn{$zinc}->[0]."-Button".$treeModBtn{$zinc}->[1];
	    $tseq =~ s/^-//;
	    $text->insert('end', "\nWith <");
	    $text->insert('end', $tseq, 'keyword');
	    $text->insert('end', "> sequence, select a particular item in the ".
			  "application window and locate it in the tree.\n");
	}
	$text->insert('end', "\n");
    }

    if ($snapKey{$zinc}) {
	$text->insert('end', "To snapshot the application window.\n", 'title');
	$text->insert('end', "\nWith <");
	$text->insert('end', $snapKey{$zinc}, 'keyword');
	$text->insert('end', "> sequence you can acquire " .
		      "a snapshot of the full zinc window. ".
		      "It will be saved in the current directory ".
		      "with the name zincsnapshot<n>.png ".
		      "The ImageMagic package must be installed.\n");
    }
    my $fm = $help_tl{$zinc}->Frame->pack(-side => 'bottom',
					  -pady => 5,
					  -expand => 1,
					  -fill => 'none');
    $fm->Button(-text => 'Show',
		-cursor  => 'top_left_arrow',
		-command => [\&showinstance, $zinc],
		)->pack(-side => 'left', -padx => 10) unless $singleflag;
	    
    $fm->Button(-text => 'Take focus',
		-cursor  => 'top_left_arrow',
		-command => [\&takefocus, $zinc],
		)->pack(-side => 'left', -padx => 10);
	    
    $fm->Button(-command => sub {$help_tl{$zinc}->destroy},
			    -text => 'Close')->pack(-side => 'left', -padx => 10);
    $text->pack(-side => 'top', -pady => 10, -padx => 10);
    
} # end showsinstancehelp


# display help about tree
sub showHelpAboutTree {
    my $zinc = shift;
    $helptree_tl->destroy if $helptree_tl and Tk::Exists($helptree_tl);
    $helptree_tl = $tree_tl->Toplevel;
    $helptree_tl->title("Help about Tree");

    my $text = $helptree_tl->Scrolled('Text',
					-font => scalar $zinc->cget(-font),
					-wrap => 'word',
					-foreground => 'gray10',
					-scrollbars => 'osoe',
					);
    $text->tagConfigure('keyword', -foreground => 'darkblue');
    $text->insert('end', "\nNAVIGATION IN TREE\n\n");
    $text->insert('end', "<Up>", "keyword");
    $text->insert('end', " arrow key moves the anchor point to the item right on ".
		  "top of the current anchor item. ");
    $text->insert('end', "<Down>", "keyword");
    $text->insert('end', " arrow key moves the anchor point to the item right below ".
		  "the current anchor item. ");
    $text->insert('end', "<Left>", "keyword");
    $text->insert('end', " arrow key moves the anchor to the parent item of the ".
		  "current anchor item. ");
    $text->insert('end', "<Right>", "keyword");
    $text->insert('end', " moves the anchor to the first child of the current anchor ".
		  "item. If the current anchor item does not have any children, moves ".
		  "the anchor to the item right below the current anchor item.\n\n");
    $text->insert('end', "\nHIGHLIGHTING ITEMS\n\n");
    $text->insert('end', "To display item's features, ");
    $text->insert('end', "double-click", "keyword");
    $text->insert('end', " on it or press ");
    $text->insert('end', "<Return>", "keyword");
    $text->insert('end', " key.\n\n");
    $text->insert('end', "To highlight item in the application, simply ");
    $text->insert('end', "click", "keyword");
    $text->insert('end', " on it.");
    &infoAboutHighlighting($text);
    $text->insert('end', "\n\n\nBUILDING CODE\n\n");
    $text->insert('end', "To build perl code, select a branch or a leaf ".
		  "and click on the ");
    $text->insert('end', "Build code", "keyword");
    $text->insert('end', " button. Then select an output file with the ".
		  "file selector.\n\n");
     $text->configure(-state => 'disabled');
    
    $helptree_tl->Button(-command => sub {$helptree_tl->destroy},
			 -text => 'Close')->pack(-side => 'bottom',
						 -pady => 10);
    $text->pack->pack(-side => 'top', -pady => 10, -padx => 10);
} # end showHelpAboutTree



sub showHelpAboutAttributes {
    my $zinc = shift;
    $helptree_tl->destroy if $helptree_tl and Tk::Exists($helptree_tl);
    $helptree_tl = $zinc->Toplevel;
    $helptree_tl->title("Help about attributes");

    my $text = $helptree_tl->Scrolled('Text',
				      -font => scalar $zinc->cget(-font),
				      -wrap => 'word',
				      -height => 30,
				      -foreground => 'gray10',
				      -scrollbars => 'oe',
				      );
    $text->tagConfigure('keyword', -foreground => 'darkblue');
    $text->tagConfigure('title', -foreground => 'ivory',
			-background => 'gray60',
			-spacing1 => 3,
			-spacing3 => 3);

    
    $text->insert('end', " To highlight a specific item\n", 'title');
    $text->insert('end',
		  "\nThe column labeled 'Id' contains items identifiers buttons you ".
		  "can press to highlight corresponding items in the application.\n");
    &infoAboutHighlighting($text);
    $text->insert('end', "\n\nThe column labeled 'Group' contains groups identifiers ".
		  "buttons you can press to display groups content and attributes.\n\n");
    $text->insert('end', " To display the bounding box of an item\n", 'title');
    $text->insert('end', "\nUse the buttons of the column labeled ".
		  "'Bounding Box'.\n\n");
    $text->insert('end', " To change the value of attributes\n", 'title');
    $text->insert('end', "\nMost of information fields are editable. A simple ".
		  "colored feedback shows which attributes have changed. Use <");
    $text->insert('end', "Control-z", "keyword");
    $text->insert('end', "> sequence to restore the initial value\n\n");
    $text->insert('end', " To visualize item's transformations\n", 'title');
    $text->insert('end', "\nClick on the ");
    $text->insert('end', "treset", "keyword");
    $text->insert('end', " button in the first column. This action restores the item's transformation to its initial state. Transition is displayed with a fade-in/fade-out animation (needs OpenGL rendering)\n");

    $text->configure(-state => 'disabled');
    
    $helptree_tl->Button(-command => sub {$helptree_tl->destroy},
			 -text => 'Close')->pack(-side => 'bottom',
						 -pady => 10);
    $text->pack->pack(-side => 'top', -pady => 10, -padx => 10);

} # end showHelpAboutAttributes



sub infoAboutHighlighting {
    my $text = shift;
    $text->insert('end', "By default, using ");
    $text->insert('end', "left mouse button", "keyword");
    $text->insert('end', ", highlighting is done by raising selected item and drawing ".
		  "a rectangle arround. ");
    $text->insert('end', "In order to improve visibility, ");
    $text->insert('end', "item will be light backgrounded if you use ");
    $text->insert('end', "center mouse button", "keyword");
    $text->insert('end', " and dark backgrounded if you use ");
    $text->insert('end', "right mouse button", "keyword");
    $text->insert('end', ". ");
    
} # end infoAboutHighlighting


#---------------------------------------------------------------------------
#
# EDITION FUNCTION
#
#---------------------------------------------------------------------------
sub entryoption {
    my ($fm, $item, $zinc, $option, $def, $widthmax, $widthmin, $height) = @_;
    my $arrayflag;
    unless ($def) {
	my @def = $zinc->itemcget($item, $option);
	if (@def > 1) {
	    $arrayflag = 1;
	    $def = join(', ', @def);
	} else {
	    $def = $def[0];
	}
    }
    my $i0;
    my $e;
    if ($def =~ /\n/) {
	$height = 1 unless defined($height);
	$e = $fm->Text(-height => $height, -width => 1, -wrap => 'none');
	$i0 = '0.0';
    } else {
	$e = $fm->Entry();
	$i0 = 0;
    }
    my $width = length($def);
    $width = $widthmax if defined($widthmax) and $width > $widthmax;
    $width = $widthmin if defined($widthmin) and $width < $widthmin;
    $e->configure(-width => $width);
    if ($defaultoptions{$item}->{$option} and
	$def ne $defaultoptions{$item}->{$option}) {
	$e->configure(-foreground => 'blue');
    }
    
    $e->insert($i0, $def);
    $e->bind('<Control-z>', sub {
	return unless $defaultoptions{$item}->{$option};
	my $bg = $e->cget(-background);
	$zinc->itemconfigure($item, $option => $defaultoptions{$item}->{$option});
	$e->delete($i0, 'end');
	$e->insert($i0, $defaultoptions{$item}->{$option});
	$e->configure(-background => 'ivory');
	$e->after(80, sub {$e->configure(-background => $bg, -foreground => 'black')});
    });
    $e->bind('<Key-Return>',
	     sub {my $val = $e->get;
		  my $bg = $e->cget(-background);
		  $e->configure(-background => 'ivory');
		  if ($def ne $val) {
		      $defaultoptions{$item}->{$option} = $def
			  unless $defaultoptions{$item}->{$option};
		  }
		  my $fg = ($val ne $defaultoptions{$item}->{$option}) ?
		      'blue' : 'black';
		  $e->after(80, sub {
		      $e->configure(-background => $bg, -foreground => $fg);
		  });
		  if ($arrayflag) {
		      $zinc->itemconfigure($item, $option => [split(/,/, $val)]);
		  } else {
		      $zinc->itemconfigure($item, $option => $val);
		  }
	      });

    return $e;

} # end entryoption


sub showinstance {
    my $zinc = shift;
    my $a = $zinc->itemcget(1, -alpha);
    my $b = ($a > 40) ? 10 : 100;
    $zinc->itemconfigure(1, -alpha => $b);
    $zinc->update;
    $zinc->after(100);
    $zinc->itemconfigure(1, -alpha => $a);
    $zinc->update;

} # end showinstance


sub takefocus {
    my $zinc = shift;
    $zinc->Tk::focus;

} # end takefocus


sub newinstance {
    my $zinc = shift;
    return if $instances{$zinc};
    &takefocus($zinc);
    $instances{$zinc} = 1;    
    push(@instances, $zinc);
    
} # end newinstance

1;

__END__


=head1 NAME

Tk::Zinc::Debug - a perl module for analysing a Zinc application. 


=head1 SYNOPSIS

 perl -MTk::Zinc::Debug zincscript [zincscript-opts] [zincdebug-opts]
    
     or
    
 use Tk::Zinc::Debug;
 my $zinc = MainWindow->new()->Zinc()->pack;
 finditems($zinc, [options]);
 tree($zinc, [options]);
 snapshot($zinc, [options]);


=head1 DESCRIPTION

Tk::Zinc::Debug provides an interface to help developers to debug or analyse Zinc applications.

With B<finditems()> function, you are able to scan all items which are enclosed in a rectangular area you have first drawn by drag & drop, or all items which overlap it. Result is a Tk table which presents details (options, coordinates, ...) about found items; you can also highlight a particular item, even if it's not visible, by clicking on its corresponding button in the table. You can also display particular item's features by entering this id in dedicated entry field

B<tree()> function displays items hierarchy. You can find a particular item's position in the tree and you can highlight items and see their features as described above. You can also generate the perl code corresponding to a selected branch. However there are some limitations : transformations and images can't be reproduced.

With B<snapshot()> function, you are able to snapshot the application window, in order to illustrate a graphical bug for example.
    
Press B<Escape> key in the toplevel of the application to have some help about available input sequences.

B<If you load Tk::Zinc::Debug using the -M perl option, nothing needs to be added to your code>. By default, all the previous specific functions are invoked with their default attributes for each instance of Zinc widget. You can overload these by passing the same options to the command. Note that perl arrays must be transformed to comma separated string. For example:
   perl -M Tk::Zinc::Debug zincscript -optionsToDisplay '-tags'
   -optionsFormat row -itemModBtn Control,1


=head1 FUNCTIONS 


=over

=item B<finditems>($zinc, ?option => value, ...?)

This function creates required Tk bindings to permit items search. You can specify the following options :

=over

=item E<32>E<32>E<32>B<-color> => color

Defines color of search area contour. Default to 'sienna'.

=item E<32>E<32>E<32>B<-enclosedModBtn> => [Mod, Btn]

Defines input sequence used to process "enclosed" search. Default to ['Control', 3]. B<Mod> can be set to undef.

=item E<32>E<32>E<32>B<-overlapModBtn> => [Mod, Btn]

Defines input sequence used to process "overlap" search. Default to ['Shift', 3]. B<Mod> can be set to undef.

=item E<32>E<32>E<32>B<-searchKey> => key

Defines input key used to process particular search. Default to 'Control-f'.

=back

=item B<tree>($zinc, ?option => value, ...?)

This function creates required Tk bindings to build items tree. You can specify the following options :

=over

=item E<32>E<32>E<32>B<-tkey|-key> => key

Defines input sequence used to build and display items tree. Default to 'Control-t'.

=item E<32>E<32>E<32>B<-itemModBtn> => [Mod, Btn]

Defines input sequence used to select an item in the application window in order to display its position in the item's tree. Default to ['Control', 2]. B<Mod> can be set to undef.

=item E<32>E<32>E<32>B<-optionsToDisplay> => opt1[,..,optN]

Used to display some option's values associated to items of tree. Expected argument is a string of commas separated options.


=item E<32>E<32>E<32>B<-optionsFormat> => row | column

Defines the display format of option's values. Default is 'column'.

=back

    
=item B<snapshot>($zinc, ?option => value, ...?)

This function creates required Tk binding to snapshot the application window. You can specify the following options :

=over

=item E<32>E<32>E<32>B<-skey|-key> => key

Defines input key used to process a snapshot of the zinc window. Default to ['Control-s'].

=item E<32>E<32>E<32>B<-verbosity> => boolean

Defines if snapshot should print a message on the terminal. Default to true.

=item E<32>E<32>E<32>B<-basename> => "a_string"

Defines the basename used for the file containing the snaphshot. The filename will be <currentdir>/basename<n>.png  Defaulted to zincsnapshot.


=back

=back
    

=head1 AUTHOR

Daniel Etienne <etienne@cena.fr>

    
=head1 HISTORY

Sep 15 2003 : due to CPAN-isation, the ZincDebug module has been renamed Tk::Zinc::Debug

May 20 2003 : perl code can be generated from the items tree, with some limitations concerning transformations and images.

Mar 11 2003 : ZincDebug can manage several instances of Zinc widget. Options of ZincDebug functions can be set on the command line. 

Jan 20 2003 : item's attributes can be edited.

Jan 14 2003 : ZincDebug can be loaded at runtime using the -M perl option without any change in the application's code.

Nov 6 2002 : some additional informations (like tags or other attributes values) can be displayed in the items tree. Add feedback when selected item is not visible because outside window.

Sep 2 2002 : add the tree() function

May 27 2002 : add the snapshot() function contributed by Ch. Mertz.
    
Jan 28 2002 : Zincdebug provides the finditems() function and can manage only one instance of Zinc widget. 
