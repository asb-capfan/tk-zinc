#!/usr/bin/perl
#-----------------------------------------------------------------------------------
#
#      MagicLens.pl
#
#      This small demo is based on Zinc::Graphics.pm for creating
#      the graphic items.
#      The magnifyer effect is obtained with the help of clipping,
#      and some glass effect is based on color transparency through
#      a triangles item bordering the magnifier
#
#      Authors: Jean-Luc Vinot <vinot@cena.fr>
#
# $Id: 
#-----------------------------------------------------------------------------------

use vars qw( $VERSION );
($VERSION) = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

use Tk;
use Tk::Zinc;
use Tk::Zinc::Graphics;
use Getopt::Long;
use strict 'vars';

# the original fonts are not available everywhere, even if they are free!
my $font_9b = '7x13bold'; # '-cenapii-bleriot mini-bold-r-normal--9-90-75-75-p-*-iso8859-15';
my $font_8 = '7x13';  #'-cenapii-bleriot mini-book-r-normal--8-80-75-75-p-*-iso8859-15';
my ($dx, $dy);

my @basiccolors = (['Jaune','#fff52a','#f1f1f1','#6a6611'],
		   ["Jaune\nOrang�",'#ffc017','#cfcfcf','#6b510a'],
		   ['Orang�','#ff7500','#a5a5a5','#622d00'],
		   ['Rouge','#ff2501','#8b8b8b','#620e00'],
		   ['Magenta','#ec145d','#828282','#600826'],
		   ["Violet\nRouge",'#a41496','#636363','#020940'],
		   ["Violet\nBleu",'#6a25b6','#555555','#2a0f48'],
		   ['Bleu','#324bde','#646464','#101846'],
		   ['Cyan','#0a74f0','#818181','#064a9a'],
		   ["Bleu\nVert",'#009bb4','#969696','#006474'],
		   ['Vert','#0fa706','#979797','#096604'],
		   ["Jaune\nVert",'#9dd625','#c9c9c9','#496311']);

my $circle_coords = [[0,-30],[-16.569,-30,'c'],[-30,-16.569,'c'],[-30,0],[-30,16.569,'c'],[-16.569,30,'c'],[0,30],
		     [16.569,30,'c'],[30,16.569,'c'],[30,0],[30,-16.569,'c'],[16.569,-30,'c'],[0,-30]];


# MagicLens
my %lensitems = ('back' => {-itemtype => 'arc',
			    -coords => [[-100, -100],[100,100]],
			    -params => {-priority => 10,
					-closed => 1,
					-filled => 1,
					-visible => 0,
					-tags => ['lensback'],
				       },
			   },
		 'light' => {-itemtype => 'pathline',
			     -metacoords => {-type => 'polygone',
					     -coords => [0, 0],
					     -numsides => 36,
					     -radius => 100,
					     -startangle => 240,
					    },
			     -linewidth => 10,
			     -shifting => 'right',
			     -closed => 1,
			     -graduate => {-type => 'double',
					   -colors => [['#ffffff;0', '#6666cc;0', '#ffffff;0'],
						       ['#ffffff;100', '#333399;50', '#ffffff;100']],
					  },
			     -params => {-priority => 50,
					},
			    },
		 'bord' => {-itemtype => 'hippodrome',
			    -coords => [[-100, -100],[100, 100]],
			    -params => {-priority => 100,
					-closed => 1,
					-filled => 0,
					-linewidth => 2,
					-linecolor => '#222266;80'
				       },
			   },
		);
				

# creation de la fenetre principale
my $mw = MainWindow->new();
$mw->geometry("1000x900+0+0");
$mw->title('Color Magic Lens');


# creation du widget Zinc
my $zinc = $mw->Zinc(-render => 1,
		     -width => 1000,
		     -height => 900,
		     -borderwidth => 0,
		     -lightangle => 140,
		     -borderwidth => 0,
		     );
$zinc->pack(-fill => 'both', -expand => 1);

# to find some images (used as textures) needed by this demo
push @INC , Tk->findINC('demos/zinc_data');
my $texture = &getTexture($zinc, 'paper-grey1.gif');
$zinc->configure(-tile => $texture);

# cr�ation des 2 vues
my $normview = $zinc->add('group', 1, -priority => 100);
my $lensview = $zinc->add('group', 1, -priority => 200);
my $infoview = $zinc->add('group', $lensview);

my $zoom=1.20;
$zinc->scale($infoview, $zoom, $zoom);

my $lenstexture = &getTexture($zinc, 'paper-grey.gif');
$zinc->add('rectangle', $infoview,
	   [[0,0],[1000,900]],
	   -filled => 1,
	   -fillcolor => '#000000',
	   -tile => $lenstexture,
	   -linewidth => 0,
	   );

my $gradbar;

my $x = 60;
for (my $i = 0; $i < 12; $i++) {

  # ajout d'un groupe dans chacune des les 2 vues
  my $cgroup = $zinc->add('group', $normview);
  $zinc->coords($cgroup, [$x, 60]);
  my $lgroup = $zinc->add('group', $infoview);
  $zinc->coords($lgroup, [$x, 60]);

  # r�f�rences de la couleur : name, Zncolor satur�e, ZnColor d�satur�e, ZnColor d'ombrage
  my ($colorname, $saturcolor, $greycolor, $shadcolor) = @{$basiccolors[$i]};

  # �chantillon r�f�rence couleur satur�e + relief
  my $refgrad = "=radial -12 -20|#ffffff 0|".$saturcolor." 40|".$shadcolor." 100";
  my $refitem = $zinc->add('curve', $cgroup,
			   $circle_coords,
			   -filled => 1,
			   -fillcolor => $refgrad,
			   -linewidth => 2,
			   -priority => 100
			  );

  # clone dans le group infoview
  my $clone = $zinc->clone($refitem);
  $zinc->chggroup($clone, $lgroup);

  # label couleur (infoview)
  $zinc->add('text', $lgroup,
	     -priority => 200,
	     -position => [0, 0],
	     -text => $colorname,
	     -anchor => 'center',
	     -alignment => 'center',
	     -font => $font_9b,
	     -spacing => 2,
	    );

  # d�grad� de la couleur vers le gris de m�me luminosit�
  my $bargrad = "=axial 270|".$saturcolor."|".$greycolor;

  # cr�ation des �chantillons de couleur (curve multi-contours)
  $gradbar = $zinc->add('curve', $cgroup,
			[],
			-closed => 1,
			-filled => 1,
			-fillcolor => $bargrad,
			-linewidth => 2,
			-priority => 20,
			-fillrule => 'nonzero'
		       );

  # d�finition des couleurs du d�grad� (saturation 100% -> 0%)
  my $zncolors = &createGraduate($zinc, 11, [$saturcolor, $greycolor]);
  # on retire les valeurs alphas
  foreach (@{$zncolors}){ ($_) = split /;/, $_;}

  # r�alisation des pas de d�grad� (saturation -> d�saturation)
  my $c;
  for ($c = 0; $c < 11; $c++) {

    # couleur du pas
    my $color = $zncolors->[$c];

    # item zinc de l'exemple couleur
    my $sample = $zinc->clone($refitem, -fillcolor => $color);
    $zinc->translate($sample, 0, 65*($c+1));

    # ajout � la curve multi-contours
    $zinc->contour($gradbar, 'add', 1, $sample);

    # d�placement vers le groupe info
    $zinc->chggroup($sample, $lgroup);

    # label texte (% saturation + ZnColor)
    my $txtcolor = ((10 - $c)*10)."%\n$color";
    $zinc->add('text', $lgroup,
	       -priority => 200,
	       -position => [0, ($c + 1)* 65],
	       -text => $txtcolor,
	       -anchor => 'center',
	       -alignment => 'center',
	       -font => $font_8,
	       -spacing => 2,
	      );
  }


  $x += 80;
}

# cr�ation de la MagicLens
my $lensgroup = $zinc->add('group', 1,
			   -priority => 300,
			   -atomic => 1,
			   -tags => ['lens'],
			  );
$zinc->coords($lensgroup, [300, 110]);
&lensMove(0,0);

# items graphiques
while (my ($name, $style) = each(%lensitems)) {
  &buildZincItem($zinc, $lensgroup, $style, undef, $name);
}

# clipping lensview
my $lenszone = $zinc->clone('lensback', -tags => ['lenszone']);
$zinc->chggroup($lenszone, $lensview, 1);
$zinc->itemconfigure($lensview, -clip => $lenszone);

# consigne globale
my $consigne = $zinc->add('text', 1,
			  -position => [30, 840],
			  -text => "<Up>, <Down>, <Left> and <Right> keys or <Mouse Drag>\nMove the Magic Color Lens behind the color gradiants\nto see the ZnColor value of Hue/saturation\n",
			  -font => $font_8,
			  -alignment => 'left',
			  -color => '#ffffff',
			  -spacing => 2,
			 );

my $cclone = $zinc->clone($consigne, -font => $font_9b);
$zinc->chggroup($cclone, $infoview);

&setBindings;


MainLoop;
#----------------------------------------------------------------------- fin de MAIN


sub setBindings {
  $zinc->bind('lens', '<1>', sub {&lensStart();});
  $zinc->bind('lens', '<B1-Motion>', sub {&lensMove();});
  $zinc->bind('lens', '<ButtonRelease>', sub {&lensStop();});

  $mw->Tk::focus();

  # Up, Down, Right, Left : Translate
  $mw->Tk::bind('<KeyPress-Up>', sub {lensTranslate('up');});
  $mw->Tk::bind('<KeyPress-Down>', sub {lensTranslate('down');});
  $mw->Tk::bind('<KeyPress-Left>', sub {lensTranslate('left');});
  $mw->Tk::bind('<KeyPress-Right>', sub {lensTranslate('right');});
}




#-----------------------------------------------------------------------------------
# Callback CATCH de s�lection (d�but de d�placement) de la lentille
#-----------------------------------------------------------------------------------
sub lensStart {
  my $ev = $zinc->XEvent;
  ($dx, $dy) = (0 - $ev->x, 0 - $ev->y);

}


#-----------------------------------------------------------------------------------
# Callback MOVE de d�placement de la lentille
#-----------------------------------------------------------------------------------
sub lensMove {
  my ($tx, $ty) = @_;

  if (defined $tx and defined $ty) {
    # interaction clavier
    $zinc->translate('lens', $tx, $ty);
    $zinc->translate('lenszone', $tx, $ty);

  } else {
    my $ev = $zinc->XEvent;
    $zinc->translate('current', $ev->x + $dx, $ev->y +$dy);
    $zinc->translate('lenszone', $ev->x + $dx, $ev->y +$dy);
    ($dx, $dy) = (0 - $ev->x, 0 - $ev->y);
  }

  my ($lx, $ly) = $zinc->coords('lens');
  $zinc->coords($infoview, [$lx * (1-$zoom), $ly * (1-$zoom)]);

}


#-----------------------------------------------------------------------------------
# Callback RELEASE de relach� (fin de d�placement) de la lentille
#-----------------------------------------------------------------------------------
sub lensStop {
  &lensMove;
}

sub lensTranslate {
  my $way = shift;

  my $dx = ($way eq 'left') ? -10 : ($way eq 'right') ? 10 : 0;
  my $dy = ($way eq 'up') ? -10 : ($way eq 'down') ? 10 : 0;

  &lensMove($dx, $dy);

}



1;
