#!/usr/bin/perl
#-----------------------------------------------------------------------------------
#
#      Graphics.pm
#      some graphic design functions
#
#-----------------------------------------------------------------------------------
#  Functions to create complexe graphic component :
#  ------------------------------------------------
#      buildZincItem          (realize a zinc item from description hash table)
#
#  Function to compute complexe geometrical forms :
#  (text header of functions explain options for each form,
#  function return curve coords using control points of cubic curve)
#  -----------------------------------------------------------------
#      roundedRectangleCoords (return curve coords of rounded rectangle)
#      hippodromeCoords       (return curve coords of circus form)
#      polygonCoords          (return curve coords of regular polygon)
#      roundedCurveCoords     (return curve coords of rounded curve)
#      polylineCoords         (return curve coords of polyline)
#      tabBoxCoords           (return curve coords of tabBox's pages)
#      pathLineCoords         (return triangles coords of pathline)
#
#  Geometrical basic Functions :
#  -----------------------------
#      perpendicularPoint
#      lineAngle
#      vertexAngle
#      arc_pts
#      rad_point
#
#  Pictorial Functions  :
#  ----------------------
#      setGradients
#      getPattern
#      getTexture
#      getImage
#      init_pixmaps
#      hexaRGBcolor
#      createGraduate
#
#-----------------------------------------------------------------------------------
#      Authors: Jean-Luc Vinot <vinot@cena.fr>
#
# $Id: 
#-----------------------------------------------------------------------------------
package Tk::Zinc::Graphics;

use vars qw( $VERSION );
($VERSION) = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(&buildZincItem

	     &roundedRectangleCoords &hippodromeCoords &polygonCoords
	     &roundedCurveCoords &polylineCoords &tabBoxCoords &pathLineCoords 

	     &perpendicularPoint &lineAngle &vertexAngle &rad_point &arc_pts

	     &setGradients &getPattern &getTexture &getImage &init_pixmaps &hexaRGBcolor &createGraduate
	     );

use strict;
use Carp;
use Tk;
use Math::Trig;

# constante facteur point directeur
my $const_ptd_factor = .5523;

my @Gradients;
my %textures;
my %images;
my %bitmaps;


#-----------------------------------------------------------------------------------
# Graphics::buildZincItem
# Création d'un objet Zinc de représentation
# paramètres :
# widget : <widget>
# parentgroup : <group>
# style : {hash table options}
# specific_tags : [list of specific tags] to add to params -tags
# name : <str> nom de l'item
#-----------------------------------------------------------------------------------
# type d'item valide :
# les items natifs zinc : group, rectangle, arc, curve, text, icon
# les items ci-après permettent de spécifier des curves 'particulières' :
# -roundedrectangle : rectangle à coin arrondi
#       -hippodrome : hippodrome
#         -polygone : polygone régulier à n cotés (convexe ou en étoile)
#     -roundedcurve : curve multicontours à coins arrondis (rayon unique)
#         -polyline : curve multicontours à coins arrondis (le rayon pouvant être défini 
#                     spécifiquement pour chaque sommet)
#         -pathline : création d'une ligne 'épaisse' avec l'item Zinc triangles
#                     décalage par rapport à un chemin donné (largeur et sens de décalage)
#                     dégradé de couleurs de la ligne (linéaire, transversal ou double)
#-----------------------------------------------------------------------------------
sub buildZincItem {
  my ($zinc, $parentgroup, $style, $specific_tags, $name) = @_;
  $parentgroup = 1 if !$parentgroup;

  my @tags = ($specific_tags) ? @{$specific_tags} : ();
  my $params_tags;

  if ($style->{'-params'}->{'-tags'}) {
    $params_tags = delete $style->{'-params'}->{'-tags'};
    push (@tags, @{$params_tags}) if $params_tags;
  }

  my $itemtype = $style->{'-itemtype'};
  my $coords = $style->{'-coords'};

  # création de l'item Zinc
  my $item;

  # gestion des polygones particuliers et à coin arrondi
  if ($itemtype eq 'roundedrectangle') {
    $itemtype = 'curve';
    $style->{'-params'}->{'-closed'} = 1;
    $coords = &roundedRectangleCoords($coords, %{$style});

  } elsif ($itemtype eq 'hippodrome') {
    $itemtype = 'curve';
    $style->{'-params'}->{'-closed'} = 1;
    $coords = &hippodromeCoords($coords, %{$style});

  } elsif ($itemtype eq 'polygone') {
    $itemtype = 'curve';
    $style->{'-params'}->{'-closed'} = 1;
    $coords = &polygonCoords($coords, %{$style});

  } elsif ($itemtype eq 'roundedcurve' or $itemtype eq 'polyline') {
    $itemtype = 'curve';
    if ($itemtype eq 'roundedcurve') {
      $style->{'-params'}->{'-closed'} = 1;
      $coords = &roundedCurveCoords($coords, %{$style});

    } else {
      $coords = &polylineCoords($coords, %{$style});
    }

    # multi-contours
    if ($style->{'-contours'}) {
      my @contours = @{$style->{'-contours'}};
      my $numcontours = scalar(@contours);
      for (my $i = 0; $i < $numcontours; $i++) {
	# radius et corners peuvent être défini spécifiquement pour chaque contour
	my ($type, $way, $coords, $radius, $corners, $corners_radius) = @{$contours[$i]};
	$radius = $style->{'-radius'} if (!defined $radius);
	my $newcoords;
	if ($itemtype eq 'roundedcurve') {
	  $newcoords = &roundedCurveCoords($coords, -radius => $radius, -corners => $corners);
	} else {
	  $newcoords = &polylineCoords($coords, -radius => $radius, -corners => $corners, -corners_radius => $corners_radius);
	}

	$style->{'-contours'}->[$i] = [$type, $way, $newcoords];
      }
    }
  }  elsif ($itemtype eq 'pathline') {
    $itemtype = 'triangles';
    if ($style->{'-metacoords'}) {
      $coords = &metaCoords(%{$style->{'-metacoords'}});

    }

    if ($style->{'-graduate'}) {
      my $numcolors = scalar(@{$coords});
      $style->{'-params'}->{'-colors'} = &pathGraduate($zinc, $numcolors, $style->{'-graduate'});
    }

    $coords = &pathLineCoords($coords, %{$style});

  }

  if ($itemtype eq 'group') {
    $item = $zinc->add($itemtype,
		       $parentgroup,
		       %{$style->{'-params'}},
		       -tags => \@tags,
		      );

    $zinc->coords($item, $coords) if $coords;

  } elsif ($itemtype eq 'text' or $itemtype eq 'icon') {
    my $imagefile;
    if ($itemtype eq 'icon') {
      $imagefile = $style->{'-params'}->{'-image'};
      $style->{'-params'}->{'-image'} = &init_pixmap($zinc, $imagefile) if $imagefile;
    }

    $item = $zinc->add($itemtype,
		       $parentgroup,
		       -position => $coords,
		       %{$style->{'-params'}},
		       -tags => \@tags,
		      );

    $style->{'-params'}->{'-image'} = $imagefile if $imagefile;

  } else {
    $item = $zinc->add($itemtype,
		       $parentgroup,
		       $coords,
		       %{$style->{'-params'}},
		       -tags => \@tags,
		      );

    if ($itemtype eq 'curve' and $style->{'-contours'}) {
      foreach my $contour (@{$style->{'-contours'}}) {
	$zinc->contour($item, @{$contour});
      }
    }
	
    # gestion du mode norender
    if ($style->{'-texture'}) {
      my $texture = &getTexture($zinc, $style->{'-texture'});
      $zinc->itemconfigure($item, -tile => $texture) if $texture;
    }

    if ($style->{'-fillpattern'}) {
      my $bitmap = &getBitmap($style->{'-fillpattern'});
      $zinc->itemconfigure($item, -fillpattern => $bitmap) if $bitmap;
    }


  }

  # transformation scale de l'item si nécessaire
  $zinc->scale($item, @{$style->{'-scale'}}) if ($style->{'-scale'});

  # transformation rotate de l'item si nécessaire
  $zinc->rotate($item, deg2rad($style->{'-rotate'})) if ($style->{'-rotate'});

  # transformation scale de l'item si nécessaire
  $zinc->translate($item, @{$style->{'-translate'}}) if ($style->{'-translate'});

  # remise étét initial de la table de hash
  $style->{'-params'}->{'-tags'} = $params_tags if ($params_tags);

  return $item;

}

#-----------------------------------------------------------------------------------
# FONCTIONS GEOMETRIQUES
#-----------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------
# Graphics::metaCoords
# retourne une liste de coordonnées en utilisant la fonction d'un autre type d'item
# paramètres : (options)
#   -type : type de primitive utilisée
# -coords : coordonnées nécessitée par la fonction [type]Coords
#  + options spécialisées passés à la fonction [type]Coords
#-----------------------------------------------------------------------------------
sub metaCoords {
  my (%options) = @_;
  my $pts;

  my @options = keys(%options);
  my $type = delete $options{'-type'};
  my $coords = delete $options{'-coords'};

  if ($type eq 'polygone') {
    $pts = &polygonCoords($coords, %options);

  } elsif ($type eq 'hyppodrome') {
    $pts = &hippodromeCoords($coords, %options);

  } elsif ($type eq 'polyline') {
    $pts = &polylineCoords($coords, %options);
  }

  return $pts;
}

#-----------------------------------------------------------------------------------
# Graphics::roundedRectangleCoords
# calcul des coords du rectangle à coins arrondis
# paramètres :
# coords : point centre du polygone
# options :
#  -radius : rayon de raccord d'angle
# -corners : liste des raccords de sommets [0 (aucun raccord)|1] par défaut [1,1,1,1]
#-----------------------------------------------------------------------------------
sub roundedRectangleCoords {
  my ($coords, %options) = @_;
  my ($x0, $y0, $xn, $yn) = ($coords->[0]->[0], $coords->[0]->[1],
			     $coords->[1]->[0], $coords->[1]->[1]);

  my @options = keys(%options);
  my $radius = $options{'-radius'};
  my $corners = $options{'-corners'} ? $options{'-corners'} : [1, 1, 1, 1];

  # attention aux formes 'négatives'
  if ($xn < $x0) {
    my $xs = $x0;
    ($x0, $xn) = ($xn, $xs);
  }
   if ($yn < $y0) {
    my $ys = $y0;
    ($y0, $yn) = ($yn, $ys);
  }

  my $height = &_min($xn -$x0, $yn - $y0);

  if (!defined $radius) {
    $radius = int($height/10);
    $radius = 3 if $radius < 3;
  }

  if (!$radius or $radius < 2) {
    return [[$x0, $y0],[$x0, $yn],[$xn, $yn],[$xn, $y0]];

  }


  # correction de radius si necessaire
  my $max_rad = $height;
  $max_rad /= 2 if (!defined $corners);
  $radius = $max_rad if $radius > $max_rad;

  # points remarquables
  my $ptd_delta = $radius * $const_ptd_factor;
  my ($x2, $x3) = ($x0 + $radius, $xn - $radius);
  my ($x1, $x4) = ($x2 - $ptd_delta, $x3 + $ptd_delta);
  my ($y2, $y3) = ($y0 + $radius, $yn - $radius);
  my ($y1, $y4) = ($y2 - $ptd_delta, $y3 + $ptd_delta);

  # liste des 4 points sommet du rectangle : angles sans raccord circulaire
  my @angle_pts = ([$x0, $y0],[$x0, $yn],[$xn, $yn],[$xn, $y0]);

  # liste des 4 segments quadratique : raccord d'angle = radius
  my @roundeds = ([[$x2, $y0],[$x1, $y0, 'c'],[$x0, $y1, 'c'],[$x0, $y2],],
		  [[$x0, $y3],[$x0, $y4, 'c'],[$x1, $yn, 'c'],[$x2, $yn],],
		  [[$x3, $yn],[$x4, $yn, 'c'],[$xn, $y4, 'c'],[$xn, $y3],],
		  [[$xn, $y2],[$xn, $y1, 'c'],[$x4, $y0, 'c'],[$x3, $y0],]);

  my @pts = ();
  my $previous;
  for (my $i = 0; $i < 4; $i++) {
    if ($corners->[$i]) {
      if ($previous) {
	# on teste si non duplication de point
	my ($nx, $ny) = @{$roundeds[$i]->[0]};
	if ($previous->[0] == $nx and $previous->[1] == $ny) {
	  pop(@pts);
	}
      }
      push(@pts, @{$roundeds[$i]});
      $previous = $roundeds[$i]->[3];

    } else {
      push(@pts, $angle_pts[$i]);
    }
  }

  return \@pts;
}


#-----------------------------------------------------------------------------------
# Graphics::hippodromeCoords
# calcul des coords d'un hippodrome
# paramètres :
# coords : coordonnées du rectangle exinscrit
# options :
# -orientation : orientation forcée de l'ippodrome [horizontal|vertical]
#     -corners : liste des raccords de sommets [0|1] par défaut [1,1,1,1]
#       -trunc : troncatures [left|right|top|bottom|both]
#-----------------------------------------------------------------------------------
sub hippodromeCoords {
  my ($coords, %options) = @_;
  my ($x0, $y0, $xn, $yn) = ($coords->[0]->[0], $coords->[0]->[1],
			     $coords->[1]->[0], $coords->[1]->[1]);

  my @options = keys(%options);
  my $orientation = ($options{'-orientation'}) ? $options{'-orientation'} : 'none';

  # orientation forcée de l'hippodrome (sinon hippodrome sur le plus petit coté)
  my $height = ($orientation eq 'horizontal') ? abs($yn - $y0)
    : ($orientation eq 'vertical') ? abs($xn - $x0) : &_min(abs($xn - $x0), abs($yn - $y0));
  my $radius = $height/2;
  my $corners = [1, 1, 1, 1];

  if  ($options{'-corners'}) {
    $corners = $options{'-corners'};

  } elsif ($options{'-trunc'}) {
    my $trunc = $options{'-trunc'};
    if ($trunc eq 'both') {
      return [[$x0, $y0],[$x0, $yn],[$xn, $yn],[$xn, $y0]];

    } else {
      $corners = ($trunc eq 'left') ? [0, 0, 1, 1] :
	($trunc eq 'right') ? [1, 1, 0, 0] :
	  ($trunc eq 'top') ? [0, 1, 1, 0] : 
	    ($trunc eq 'bottom') ? [1, 0, 0, 1] : [1, 1, 1, 1];

    }
  }

  # l'hippodrome est un cas particulier de roundedRectangle
  # on retourne en passant la 'configuration' à la fonction générique roundedRectangleCoords
  return &roundedRectangleCoords($coords, -radius => $radius, -corners => $corners);
}


#-----------------------------------------------------------------------------------
# Graphics::polygonCoords
# calcul des coords d'un polygone régulier
# paramètres :
# coords : point centre du polygone
# options :
#      -numsides : nombre de cotés
#        -radius : rayon de définition du polygone (distance centre-sommets)
#  -inner_radius : rayon interne (polygone type étoile)
#       -corners : liste des raccords de sommets [0|1] par défaut [1,1,1,1]
# -corner_radius : rayon de raccord des cotés
#    -startangle : angle de départ du polygone
#-----------------------------------------------------------------------------------
sub polygonCoords {
  my ($coords, %options) = @_;

  my @options = keys(%options);
  my $numsides = $options{'-numsides'};
  my $radius = $options{'-radius'};
  if ($numsides < 3 or !$radius) {
    print "Vous devez au moins spécifier un nombre de cotés >= 3 et un rayon...\n";
    return undef;
  }

  my ($cx, $cy) = ($coords) ? @{$coords} : (0, 0);
  my $startangle = ($options{'-startangle'}) ? $options{'-startangle'} : 0;
  my $anglestep = 360/$numsides;
  my $inner_radius = $options{'-inner_radius'};
  my @pts;

  # points du polygone
  for (my $i = 0; $i < $numsides; $i++) {
    my ($xp, $yp) = &rad_point($cx, $cy, $radius, $startangle + ($anglestep*$i));
    push(@pts, ([$xp, $yp]));

    # polygones 'étoiles'
    if ($inner_radius) {
      ($xp, $yp) = &rad_point($cx, $cy, $inner_radius, $startangle + ($anglestep*($i+ 0.5)));
      push(@pts, ([$xp, $yp]));
    }
  }


  if ($options{'-corner_radius'}) {
    return &roundedCurveCoords(\@pts, -radius => $options{'-corner_radius'}, -corners => $options{'-corners'});
  } else {
    return \@pts;
  }
}



#-----------------------------------------------------------------------------------
# Graphics::roundedAngle
# THIS FUNCTION IS NO MORE USED, NEITHER EXPORTED
# curve d'angle avec raccord circulaire
# paramètres :
# zinc : widget
# parentgroup : group zinc parent
# coords : les 3 points de l'angle
# radius : rayon de raccord
#-----------------------------------------------------------------------------------
sub roundedAngle {
  my ($zinc, $parentgroup, $coords, $radius) = @_;
  my ($pt0, $pt1, $pt2) = @{$coords};

  my ($corner_pts, $center_pts) = &roundedAngleCoords($coords, $radius);
  my ($cx0, $cy0) = @{$center_pts};

  # valeur d'angle et angle formé par la bisectrice
  my ($angle)  = &vertexAngle($pt0, $pt1, $pt2);

  $parentgroup = 1 if (!defined $parentgroup);

  $zinc->add('curve', $parentgroup,
	     [$pt0,@{$corner_pts},$pt2],
	     -closed => 0, 
	     -linewidth => 1,
	     -priority => 20,
	    );

}

#-----------------------------------------------------------------------------------
# Graphics::roundedAngleCoords
# calcul des coords d'un raccord d'angle circulaire
#-----------------------------------------------------------------------------------
# le raccord circulaire de 2 droites sécantes est traditionnellement réalisé par un
# arc (conique) du cercle inscrit de rayon radius tangent à ces 2 droites
#
# Quadratique :
# une approche de cette courbe peut être réalisée simplement par le calcul de 4 points
# spécifiques qui définiront - quelle que soit la valeur de l'angle formé par les 2
# droites - le segment de raccord :
# - les 2 points de tangence au cercle inscrit seront les points de début et de fin
# du segment de raccord
# - les 2 points de controle seront situés chacun sur le vecteur reliant le point de
# tangence au sommet de l'angle (point secant des 2 droites)
# leur position sur ce vecteur peut être simplifiée comme suit :
# - à un facteur de 0.5523 de la distance au sommet pour un angle >= 90° et <= 270°
# - à une 'réduction' de ce point vers le point de tangence pour les angles limites
# de 90° vers 0° et de 270° vers 360°
# ce facteur sera légérement modulé pour recouvrir plus précisement l'arc correspondant
#-----------------------------------------------------------------------------------
sub roundedAngleCoords {
  my ($coords, $radius) = @_;
  my ($pt0, $pt1, $pt2) = @{$coords};

  # valeur d'angle et angle formé par la bisectrice
  my ($angle, $bisecangle)  = &vertexAngle($pt0, $pt1, $pt2);

  # distance au centre du cercle inscrit : rayon/sinus demi-angle
  my $sin = sin(deg2rad($angle/2));
  my $delta = ($sin) ? abs($radius / $sin) : $radius;

  # point centre du cercle inscrit de rayon $radius
  my $refangle = ($angle < 180) ? $bisecangle+90 : $bisecangle-90;
  my ($cx0, $cy0) = rad_point($pt1->[0], $pt1->[1], $delta, $refangle);

  # points de tangeance : pts perpendiculaires du centre aux 2 droites
  my ($px1, $py1) = &perpendicularPoint([$cx0, $cy0], [$pt0, $pt1]);
  my ($px2, $py2) = &perpendicularPoint([$cx0, $cy0], [$pt1, $pt2]);

  # point de controle de la quadratique
  # facteur de positionnement sur le vecteur pt.tangence, sommet
  my $ptd_factor =  $const_ptd_factor;
  if ($angle < 90 or $angle > 270) {
    my $diffangle = ($angle < 90) ? $angle : 360 - $angle;
    $ptd_factor -= (((90 - $diffangle)/90) * ($ptd_factor/4)) if $diffangle > 15 ;
    $ptd_factor = ($diffangle/90) * ($ptd_factor + ((1 - $ptd_factor) * (90 - $diffangle)/90));
  } else {
    my $diffangle = abs(180 - $angle);
    $ptd_factor += (((90 - $diffangle)/90) * ($ptd_factor/3)) if $diffangle > 15;
  }

  # delta xy aux pts de tangence
  my ($d1x, $d1y) = (($pt1->[0] - $px1) * $ptd_factor, ($pt1->[1] - $py1) *  $ptd_factor);
  my ($d2x, $d2y) = (($pt1->[0] - $px2) * $ptd_factor, ($pt1->[1] - $py2) *  $ptd_factor);

  # les 4 points de l'arc 'quadratique'
  my $corner_pts = [[$px1, $py1],[$px1+$d1x, $py1+$d1y, 'c'],
		    [$px2+$d2x, $py2+$d2y, 'c'],[$px2, $py2]];


  # retourne le segment de quadratique et le centre du cercle inscrit
  return ($corner_pts, [$cx0, $cy0]);

}


#-----------------------------------------------------------------------------------
# Graphics::roundedCurveCoords
# retourne les coordonnées d'une curve à coins arrondis
# paramètres :
# coords : points de la curve
# options :
#  -radius : rayon de raccord d'angle
# -corners : liste des raccords de sommets [0|1] par défaut [1,1,1,1]
#-----------------------------------------------------------------------------------
sub roundedCurveCoords {
  my ($coords, %options) = @_;
  my $numfaces = scalar(@{$coords});
  my @curve_pts;

  my @options = keys(%options);
  my $radius = ($options{'-radius'}) ? $options{'-radius'} : 0;
  my $corners = $options{'-corners'};

  for (my $index = 0; $index < $numfaces; $index++) {
    if ($corners and !$corners->[$index]) {
      push(@curve_pts, $coords->[$index]);

    } else {
      my $prev = ($index) ? $index - 1 : $numfaces - 1;
      my $next = ($index > $numfaces - 2) ? 0 : $index + 1;
      my $anglecoords = [$coords->[$prev], $coords->[$index], $coords->[$next]];

      my ($quad_pts) = &roundedAngleCoords($anglecoords, $radius);
      push(@curve_pts, @{$quad_pts});
    }
  }

  return \@curve_pts;

}


#-----------------------------------------------------------------------------------
# Graphics::polylineCoords
# retourne les coordonnées d'une polyline
# paramètres :
# coords : sommets de la polyline
# options :
#  -radius : rayon global de raccord d'angle
# -corners : liste des raccords de sommets [0|1] par défaut [1,1,1,1],
# -corners_radius : liste des rayons de raccords de sommets
#-----------------------------------------------------------------------------------
sub polylineCoords {
  my ($coords, %options) = @_;
  my $numfaces = scalar(@{$coords});
  my @curve_pts;

  my @options = keys(%options);
  my $radius = ($options{'-radius'}) ? $options{'-radius'} : 0;
  my $corners_radius = $options{'-corners_radius'};
  my $corners = ($corners_radius) ? $corners_radius : $options{'-corners'};

  for (my $index = 0; $index < $numfaces; $index++) {
    if ($corners and !$corners->[$index]) {
      push(@curve_pts, $coords->[$index]);

    } else {
      my $prev = ($index) ? $index - 1 : $numfaces - 1;
      my $next = ($index > $numfaces - 2) ? 0 : $index + 1;
      my $anglecoords = [$coords->[$prev], $coords->[$index], $coords->[$next]];

      my $rad = ($corners_radius) ? $corners_radius->[$index] : $radius;
      my ($quad_pts) = &roundedAngleCoords($anglecoords, $rad);
      push(@curve_pts, @{$quad_pts});
    }
  }

  return \@curve_pts;

}

#-----------------------------------------------------------------------------------
# Graphics::pathLineCoords
# retourne les coordonnées d'une pathLine
# paramètres :
# coords : points de path
# options :
# -closed : ligne fermée
# -shifting : sens de décalage [both|left|right] par défaut both
# -linewidth : epaisseur de la ligne
#-----------------------------------------------------------------------------------
sub pathLineCoords {
  my ($coords, %options) = @_;
  my $numfaces = scalar(@{$coords});
  my @pts;

  my @options = keys(%options);
  my $closed = $options{'-closed'};
  my $linewidth = ($options{'-linewidth'}) ? $options{'-linewidth'} : 0;
  my $shifting = ($options{'-shifting'}) ? $options{'-shifting'} : 'both';

  return undef if (!$numfaces or $linewidth < 2);

  my $previous = ($closed) ? $coords->[$numfaces - 1] : undef;
  my $next = $coords->[1];
  $linewidth /= 2 if ($shifting eq 'both');

  for (my $i = 0; $i < $numfaces; $i++) {
    my $pt = $coords->[$i];

    if (!$previous) {
      # extrémité de curve sans raccord -> angle plat
      $previous = [$pt->[0] + ($pt->[0] - $next->[0]), $pt->[1] + ($pt->[1] - $next->[1])];
    }

    my ($angle, $bisecangle) = &vertexAngle($previous, $pt, $next);

    # distance au centre du cercle inscrit : rayon/sinus demi-angle
    my $sin = sin(deg2rad($angle/2));
    my $delta = ($sin) ? abs($linewidth / $sin) : $linewidth;

    if ($shifting eq 'left' or $shifting eq 'right') {
      my $adding = ($shifting eq 'left') ? 90 : -90;
      push (@pts,  &rad_point($pt->[0], $pt->[1], $delta, $bisecangle + $adding));
      push (@pts,  @{$pt});

    } else {
      push (@pts,  &rad_point($pt->[0], $pt->[1], $delta, $bisecangle+90));
      push (@pts,  &rad_point($pt->[0], $pt->[1], $delta, $bisecangle-90));

    }

    if ($i == $numfaces - 2) {
      $next = ($closed) ? $coords->[0] :
	[$coords->[$i+1]->[0] + ($coords->[$i+1]->[0] - $pt->[0]), $coords->[$i+1]->[1] + ($coords->[$i+1]->[1] - $pt->[1])];
    } else {
      $next = $coords->[$i+2];
    }

    $previous = $coords->[$i];
  }

  if ($closed) {
    push (@pts, ($pts[0], $pts[1], $pts[2], $pts[3]));
  }

  return \@pts;
}

#-----------------------------------------------------------------------------------
# Graphics::perpendicularPoint
# retourne les coordonnées du point perpendiculaire abaissé d'un point sur une ligne
#-----------------------------------------------------------------------------------
sub perpendicularPoint {
  my ($point, $line) = @_;
  my ($p1, $p2) = @{$line};

  # cas partiuculier de lignes ortho.
  my $min_dist = .01;
  if (abs($p2->[1] - $p1->[1]) < $min_dist) {
    # la ligne de référence est horizontale
    return ($point->[0], $p1->[1]);

  } elsif (abs($p2->[0] - $p1->[0]) < $min_dist) {
    # la ligne de référence est verticale
    return ($p1->[0], $point->[1]);
  }

  my $a1 = ($p2->[1] - $p1->[1]) / ($p2->[0] - $p1->[0]);
  my $b1 = $p1->[1] - ($a1 * $p1->[0]);

  my $a2 = -1.0 / $a1;
  my $b2 = $point->[1] - ($a2 * $point->[0]);

  my $x = ($b2 - $b1) / ($a1 - $a2);
  my $y = ($a1 * $x) + $b1;

  return ($x, $y);

}


#-----------------------------------------------------------------------------------
# Graphics::lineAngle
# retourne l'angle d'un point par rapport à un centre de référence
#-----------------------------------------------------------------------------------
sub lineAngle {
  my ($x, $y, $xref, $yref) = @_;
  my $angle = atan2($y - $yref, $x - $xref);

  $angle += pi/2;
  $angle *= 180/pi;
  $angle += 360  if ($angle < 0);

  return $angle;

}



#-----------------------------------------------------------------------------------
# Graphics::vertexAngle
# retourne la valeur de l'angle formée par 3 points
# ainsi que l'angle de la bisectrice
#-----------------------------------------------------------------------------------
sub vertexAngle {
  my ($pt0, $pt1, $pt2) = @_;
  my $angle1 = &lineAngle(@{$pt1}, @{$pt0});
  my $angle2 = &lineAngle(@{$pt1}, @{$pt2});

  $angle2 += 360 if $angle2 < $angle1;
  my $alpha = $angle2 - $angle1;
  my $bisectrice = $angle1 + ($alpha/2);

  return ($alpha, $bisectrice);
}


#-----------------------------------------------------------------------------------
# Graphics::arc_pts
# calcul des points constitutif d'un arc
# params : x,y centre, rayon, angle départ, delta angulaire, pas en degré
#-----------------------------------------------------------------------------------
sub arc_pts {
    my ($x, $y, $rad, $angle, $extent, $step, $debug) = @_;
    my @pts = ();


    if ($extent > 0) {
	for (my $alpha = $angle; $alpha <= ($angle + $extent); $alpha += $step) {
	    my ($xn, $yn) = &rad_point($x, $y, $rad,$alpha);
	    push (@pts, ([$xn, $yn]));
	}
    } else {
	for (my $alpha = $angle; $alpha >= ($angle + $extent); $alpha += $step) {
	    push (@pts, &rad_point($x, $y, $rad,$alpha));
	}
    }

    return @pts;
}


#-----------------------------------------------------------------------------------
# Graphics::rad_point
# retourne le point circulaire défini par centre-rayon-angle
#-----------------------------------------------------------------------------------
sub rad_point {
    my ($x, $y, $rad, $angle) = @_;
    my $alpha = deg2rad($angle);

    my $xpt = $x + ($rad * cos($alpha));
    my $ypt = $y + ($rad * sin($alpha));

    return ($xpt, $ypt);
}


#-----------------------------------------------------------------------------------
# Graphics::buildTabBox
# création des items Zinc d'un ensemble de page à onglet
#-----------------------------------------------------------------------------------
sub buidTabBox {
  my ($zinc, $group, $style, $specific_tags,) = @_;

  # création d'un groupe principal si besoin
  my $groupstyle = delete $style->{'-group'};
  if ($groupstyle) {
    $group = &buildZincItem($zinc, $group, $groupstyle);

  } else {
    $group = 1 if (!defined $group);
  }

  # calcul des shapes
  my $coords = $style->{'-coords'};
  my $params = $style->{'-params'};
  my $multi = $style->{'-multi'};
  my $titles = $style->{'-titles'};

  my ($shapes, $title_coords) = &computeDividers($coords,%{$style});

  # création des intercalaires
  my $i = scalar(@{$shapes}) - 1;
  foreach my $shape (reverse @{$shapes}) {
    if ($multi) {
      while (my ($key, $values) = each(%{$multi})) {
	$params->{$key} = $values->[$i];
      }
    }

    # item zinc enveloppe intercalaire
    my $intergroup = $zinc->add('group', $group);
    my %interstyle = (-itemtype => 'curve',
		    -closed => 1,
		    -coords => $shape,
		    -params => $params,
		   );
    $interstyle{-texture} = $style->{'-texture'} if ($style->{'-texture'});
    my $inter = &buildZincItem($zinc, $intergroup, \%interstyle, $specific_tags);

    # titre de l'onglet
    if ($titles) {
      my $params = $titles->{'-params'};
      $coords = ($titles->{'-coords'}) ? $titles->{'-coords'}->[$i] : $title_coords->[$i];
      $params->{'-text'} = $titles->{'-text'}->[$i];
      $zinc->add('text', $intergroup,
		 -position => $coords,
		 %{$params},
		 );
    }

    # zone page interne à l'intercalaire
    if ($style->{'-page'}) {
      &buildZincItem($zinc, $intergroup, $style->{'-page'});
    }

    # items complémentaires
    if ($style->{'-decos'}) {
      while (my ($itemname, $itemstyle) = each(%{$style->{'-decos'}})) {
	&buildZincItem($zinc, $intergroup, $itemstyle);
      }
    }

    $i--;
  }
}

#-----------------------------------------------------------------------------------
# tabBoxCoords
# Calcul des shapes de boites à onglets
#
# coords : coordonnées rectangle de la bounding box
#
# options
# -numpages <n> : nombre de pages (onglets) de la boite
# -anchor [n|e|s|w] : ancrage des onglets
# -alignment [left|center|right] : alignement des onglets sur le coté d'ancrage
# -tabwidth [<n>|[<n1>,<n2>,<n3>...]|auto] : largeur des onglets
# -tabheight [<n>|auto] : hauteur des onglets
# -tabshift <n> : décalage onglet
# -radius <n> : rayon des arrondis d'angle
# -overlap <n> : distance de recouvrement des onglets
#-----------------------------------------------------------------------------------
sub tabBoxCoords {
  my ($coords, %options) = @_;
  my ($x0, $y0, $xn, $yn) = (@{$coords->[0]}, @{$coords->[1]});
  my (@shapes, @titles_coords);
  my $inverse;

  my @options = keys(%options);
  my $numpages = $options{'-numpages'};

  if (!defined $x0 or !defined $y0 or !defined $xn or !defined $yn or !$numpages) {
    print "Vous devez au minimum spécifier le rectangle englobant et le nombre de pages\n";
    return undef;

  }

  my $anchor = ($options{'-anchor'}) ? $options{'-anchor'} : 'n';
  my $alignment = ($options{'-alignment'}) ? $options{'-alignment'} : 'left';
  my $len = ($options{'-tabwidth'}) ? $options{'-tabwidth'} : 'auto';
  my $thick = ($options{'-tabheight'}) ? $options{'-tabheight'} : 'auto';
  my $biso = ($options{'-tabshift'}) ? $options{'-tabshift'} : 'auto';
  my $radius = ($options{'-radius'}) ? $options{'-radius'} : 0;
  my $overlap = ($options{'-overlap'}) ? $options{'-overlap'} : 0;
  my $orientation = ($anchor eq 'n' or $anchor eq 's') ? 'horizontal' : 'vertical';
  my $maxwidth = ($orientation eq 'horizontal') ? ($xn - $x0) : ($yn - $y0);
  my $tabswidth = 0;
  my $align = 1;

  if ($len eq 'auto') {
    $tabswidth = $maxwidth;
    $len = ($tabswidth + ($overlap * ($numpages - 1)))/$numpages;

  } else {
    if (ref($len) eq 'ARRAY') {
      foreach my $w (@{$len}) {
	$tabswidth += ($w - $overlap);
      }
      $tabswidth += $overlap;
    } else {
      $tabswidth = ($len * $numpages) - ($overlap * ($numpages - 1));
    }

    if ($tabswidth > $maxwidth) {
      $tabswidth = $maxwidth;
      $len = ($tabswidth + ($overlap * ($numpages - 1)))/$numpages;
    }

    $align = 0 if ($alignment eq 'center' and (($maxwidth - $tabswidth) > $radius));
  }


  if ($thick eq 'auto') {
    $thick = ($orientation eq 'horizontal') ? int(($yn - $y0)/10) : int(($xn - $y0)/10);
    $thick = 10 if ($thick < 10);
    $thick = 40 if ($thick > 40);
  }

  if ($biso eq 'auto') {
    $biso = int($thick/2);
  }

  if (($alignment eq 'right' and $anchor ne 'w') or
      ($anchor eq 'w' and $alignment ne 'right')) {

    if (ref($len) eq 'ARRAY') {
      for (my $p = 0; $p < $numpages; $p++) {
	$len->[$p] *= -1;
      }
    } else {
      $len *= -1;
    }
    $biso *= -1;
    $overlap *= -1;
  }

  my ($biso1, $biso2) = ($alignment eq 'center') ? ($biso/2, $biso/2) : (0, $biso);

  my (@cadre, @tabdxy);
  my ($xref, $yref);
  if ($orientation eq 'vertical') {
    $thick *= -1 if ($anchor eq 'w');
    my ($startx, $endx) = ($anchor eq 'w') ? ($x0, $xn) : ($xn, $x0);
    my ($starty, $endy) = (($anchor eq 'w' and $alignment ne 'right') or 
			   ($anchor eq 'e' and $alignment eq 'right')) ? 
			     ($yn, $y0) : ($y0, $yn);

    $xref = $startx - $thick;
    $yref = $starty;
    if  ($alignment eq 'center') {
      my $ratio = ($anchor eq 'w') ? -2 : 2;
      $yref += (($maxwidth - $tabswidth)/$ratio);
    }

    @cadre = ([$xref, $endy], [$endx, $endy], [$endx, $starty], [$xref, $starty]);

    # flag de retournement de la liste des pts de curve si nécessaire -> sens anti-horaire
    $inverse = ($alignment ne 'right');

  } else {
    $thick *= -1 if ($anchor eq 's');
    my ($startx, $endx) = ($alignment eq 'right') ? ($xn, $x0) : ($x0, $xn);
    my ($starty, $endy) = ($anchor eq 's') ? ($yn, $y0) : ($y0, $yn);


    $yref = $starty + $thick;
    $xref = ($alignment eq 'center') ? $x0 + (($maxwidth - $tabswidth)/2) : $startx;

    @cadre = ([$endx, $yref], [$endx, $endy], [$startx, $endy], [$startx, $yref]);

    # flag de retournement de la liste des pts de curve si nécessaire -> sens anti-horaire
    $inverse = (($anchor eq 'n' and $alignment ne 'right') or ($anchor eq 's' and $alignment eq 'right'));
  }

  for (my $i = 0; $i < $numpages; $i++) {
    my @pts = ();

    # décrochage onglet
    #push (@pts, ([$xref, $yref])) if $i > 0;

    # cadre
    push (@pts, @cadre);

    # points onglets
    push (@pts, ([$xref, $yref])) if ($i > 0 or !$align);

    my $tw = (ref($len) eq 'ARRAY') ? $len->[$i] : $len;
    @tabdxy = ($orientation eq 'vertical') ?
      ([$thick, $biso1],[$thick, $tw - $biso2],[0, $tw]) : ([$biso1, -$thick],[$tw - $biso2, -$thick],[$tw, 0]);
    foreach my $dxy (@tabdxy) {
      push (@pts, ([$xref + $dxy->[0], $yref + $dxy->[1]]));
    }


    if ($radius) {
      my $corners = ($i > 0 or !$align) ? [0, 1, 1, 1, 0, 1, 1, 0] : [0, 1, 1, 0, 1, 1, 0, 0, 0];
      my $curvepts = &roundedCurveCoords(\@pts, -radius => $radius, -corners => $corners);
      @{$curvepts} = reverse @{$curvepts} if ($inverse);
      push (@shapes, $curvepts);
    } else {
      @pts = reverse @pts if ($inverse);
      push (@shapes, \@pts);
    }

    if ($orientation eq 'horizontal') {
      push (@titles_coords, [$xref + ($tw - ($biso2 - $biso1))/2, $yref - ($thick/2)]);
      $xref += ($tw - $overlap);

    } else {
      push (@titles_coords, [$xref + ($thick/2), $yref + ($len - (($biso2 - $biso1)/2))/2]);
      $yref += ($len - $overlap);
    }

  }

  return (\@shapes, \@titles_coords, $inverse);

}



#-----------------------------------------------------------------------------------
# RESOURCES GRAPHIQUES GRADIENTS, PATTERNS, TEXTURES, IMAGES...
#-----------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------
# Graphics::setGradients
# création de gradient nommés Zinc
#-----------------------------------------------------------------------------------
sub setGradients {
  my ($zinc, $grads) = @_;

  # initialise les gradients de taches
  unless (@Gradients) {
    while (my ($name, $gradient) = each( %{$grads})) {
      # création des gradients nommés
      $zinc->gname($gradient, $name);
      push(@Gradients, $name);
    }
  }
}


#-----------------------------------------------------------------------------------
# Graphics::getPattern
# retourne la ressource bitmap en l'initialisant si première utilisation
#-----------------------------------------------------------------------------------
sub getPattern {
  my ($name) = @_;
  my $bitmap;

  if (!exists($bitmaps{$name})) {
    $bitmap = '@'.Tk::findINC($name);
    $bitmaps{$name} = $bitmap;

  } else {
    $bitmap = $bitmaps{$name};
  }

  return $bitmap;
}

#-----------------------------------------------------------------------------------
# Graphics::getTexture
# retourne l'image de texture en l'initialisant si première utilisation
#-----------------------------------------------------------------------------------
sub getTexture {
  my ($zinc, $name) = @_;
  my $texture;

  if (!exists($textures{$name})) {
    $texture = $zinc->Photo(-file => Tk::findINC($name));
    $textures{$name} = $texture;

  } else {
    $texture = $textures{$name};
  }

  return $texture;
}

#-----------------------------------------------------------------------------------
# Graphics::getImage
# retourne la ressource image en l'initialisant si première utilisation
#-----------------------------------------------------------------------------------
sub getImage {
  my ($widget, $imagefile) = @_;

  if (!exists($images{$imagefile})) {
    my $image = $widget->Photo(-file => Tk::findINC($imagefile));
    $images{$imagefile} = $image if $image;
    return $image;
  }

  return $images{$imagefile};

}


#-----------------------------------------------------------------------------------
# Graphics::init_pixmaps
# initialise une liste de fichier image
#-----------------------------------------------------------------------------------
sub init_pixmaps {
    my ($widget, @pixfiles) = @_;
    my @imgs = ();


    foreach (@pixfiles) {
	push(@imgs, &getImage($widget, $_));
    }

    return @imgs;
}


sub _min {
  my ($n1, $n2) = @_;
  my $mini = ($n1 > $n2) ? $n2 : $n1;
  return $mini;

}

sub _max {
  my ($n1, $n2) = @_;
  my $maxi = ($n1 > $n2) ? $n1 : $n2;
  return $maxi;

}

#-----------------------------------------------------------------------------------
# Graphics::_trunc
# fonction interne de troncature des nombres: n = position décimale 
#-----------------------------------------------------------------------------------
sub _trunc {
  my ($val, $n) = @_;
  my $str;
  my $dec;

  ($val) =~ /([0-9]+)\.?([0-9]*)/;
  $str = ($val < 0) ? "-$1" : $1;

  if (($2 ne "") && ($n != 0)) {
    $dec = substr($2, 0, $n);
    if ($dec != 0) {
      $str = $str . "." . $dec;
    }
  }
  return $str;
}


#-----------------------------------------------------------------------------------
# Graphics::RGB_dec2hex
# conversion d'une couleur RGB (255,255,255) au format Zinc '#ffffff'
#-----------------------------------------------------------------------------------
sub RGB_dec2hex {
   my (@rgb) = @_;
   return (sprintf("#%04x%04x%04x", @rgb));
}

#-----------------------------------------------------------------------------------
# Graphics::pathGraduate
# création d'un jeu de couleurs dégradées pour item pathLine
#-----------------------------------------------------------------------------------
sub pathGraduate {
  my ($zinc, $numcolors, $style) = @_;

  my $type = $style->{'-type'};
  my $triangles_colors;

  if ($type eq 'linear') {
    return &createGraduate($zinc, $numcolors, $style->{'-colors'}, 2);

  } elsif ($type eq 'double') {
    my $colors1 = &createGraduate($zinc, $numcolors/2+1, $style->{'-colors'}->[0]);
    my $colors2 = &createGraduate($zinc, $numcolors/2+1, $style->{'-colors'}->[1]);
    my @colors;
    for (my $i = 0; $i <= $numcolors; $i++) {
      push(@colors, ($colors1->[$i], $colors2->[$i]));
    }

    return \@colors;

  } elsif ($type eq 'transversal') {
    my ($c1, $c2) = @{$style->{'-colors'}};
    my @colors = ($c1, $c2);
    for (my $i = 0; $i < $numcolors; $i++) {
      push(@colors, ($c1, $c2));
    }

    return \@colors;
  }
}

#-----------------------------------------------------------------------------------
# Graphics::createGraduate
# création d'un jeu de couleurs intermédiaires (dégradé) entre n couleurs
#-----------------------------------------------------------------------------------
sub createGraduate {
  my ($widget, $totalsteps, $refcolors, $repeat) = @_;
  my @colors;

  $repeat = 1 if (!$repeat);
  my $numgraduates = scalar @{$refcolors} - 1;

  if ($numgraduates < 1) {
    print "Le dégradé necessite au minimum 2 couleurs de référence...\n";
    return undef;
  }

  my $steps = ($numgraduates > 1) ? $totalsteps/($numgraduates -1) : $totalsteps;

  for (my $c = 0; $c < $numgraduates; $c++) {
    my ($c1, $c2) = ($refcolors->[$c], $refcolors->[$c+1]);

    for (my $i = 0 ; $i < $steps ; $i++) {
      my $color = computeColor($widget, $c1, $c2, $i/($steps-1));
      for (my $k = 0; $k < $repeat; $k++) {
	push (@colors, $color);
      }
    }

    if ($c < $numgraduates - 1) {
      for (my $k = 0; $k < $repeat; $k++) {
	pop @colors;
      }
    }
  }
  return \@colors;
}


#-----------------------------------------------------------------------------------
# Graphics::computeColor
# calcul d'une couleur intermédiaire défini par un ratio ($rate) entre 2 couleur
#-----------------------------------------------------------------------------------
sub computeColor {
  my ($widget, $color0, $color1, $rate) = @_;
  $rate = 1 if ($rate > 1);
  $rate = 0 if ($rate < 0);

  my ($r0, $g0, $b0, $a0) = &ZnColorToRGB($color0);
  my ($r1, $g1, $b1, $a1) = &ZnColorToRGB($color1);

  my $r = $r0 + int(($r1 - $r0) * $rate);
  my $g = $g0 + int(($g1 - $g0) * $rate);
  my $b = $b0 + int(($b1 - $b0) * $rate);
  my $a = $a0 + int(($a1 - $a0) * $rate);

  return &hexaRGBcolor($r, $g, $b, $a);
}

sub ZnColorToRGB {
  my ($zncolor) = @_;

  my ($color, $alpha) = split /;/, $zncolor;
  my $ndigits = (length($color) > 8) ? 4 : 2;
  my $R = hex(substr($color, 1, $ndigits));
  my $G = hex(substr($color, 1+$ndigits, $ndigits));
  my $B = hex(substr($color, 1+($ndigits*2), $ndigits));

  $alpha = 100 if (!defined $alpha or $alpha eq "");

  return ($R, $G, $B, $alpha);

}

#-----------------------------------------------------------------------------------
# Graphics::hexaRGBcolor
# conversion d'une couleur RGB (255,255,255) au format Zinc '#ffffff'
#-----------------------------------------------------------------------------------
sub hexaRGBcolor {
   my ($r, $g, $b, $a) = @_;

   if (defined $a) {
     my $hexacolor = sprintf("#%02x%02x%02x", ($r, $g, $b));
     return ($hexacolor.";".$a);
   }

   return (sprintf("#%02x%02x%02x ", ($r, $g, $b)));
}

1;

