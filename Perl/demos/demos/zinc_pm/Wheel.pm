package Wheel;

use vars qw( $VERSION );
($VERSION) = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use strict 'vars';
use Carp;

# Animation constants
my $afterdelay = 60;
my $stepsnumber = 10;
# Zoom constants
my $shrinkrate = 0.80;
my $zoomrate = 1.1;

#====================
# Object constructor
#====================
sub new {
    my ($proto, $widget, $x, $y, $radius) = @_;
  
    # object attributes
    my $self = {
	'widget' => $widget,   # widget reference
	'origin' => [$x, $y],  # origin coordinates
	'radius' => $radius,   # wheel radius
	'topgroup' => undef,   # top Group item
	'itemclip' => undef,   # id of item which clips the wheel
	'hand' => undef,       # id of item wich represents the hand
	'angle' => 60          # the angle between hand and jackpot
	};
    bless $self;    
    
    # First, we create a new Group item for the wheel. Why a Group item ?
    # At least two reasons. Wheel object consists of several Zinc items,  
    # we'll see below; it moves when it is mapped or unmapped, grows when  
    # you hit the jackpot. So, it's more easy to apply such transformations 
    # to a structured items set, using Group capability, rather than apply 
    # to each item separately or using canvas-like Tags mechanism.
    # Second reason refers to clipping. When it is mapped or unmapped, wheel 
    # object is drawn inside a circle with variant radius; clipping is a 
    # specific property of Group item

    # That's why we create a Group item in the top group, and set its
    # coordinates.
    $self->{topgroup} = $widget->add('group', 1, -visible => 0);
    $widget->coords($self->{topgroup}, [$x, $y]);
    # All the following items will be created in this group...
    
    # Create the invisible Arc item used to clip the wheel, centered on the
    # group origin.
    $self->{itemclip} = $widget->add('arc',  $self->{topgroup},
				     [-$radius, -$radius, $radius, $radius],
				     -visible => 0,
				     );
    $widget->itemconfigure($self->{topgroup}, -clip => $self->{itemclip});

    # Create the wheel with 6 filled Arc items centered on the group origin
    my $i = 0;
    for my $color (qw(magenta blue cyan green yellow red)) {
	$widget->add('arc',  $self->{topgroup},
		     [-$radius, -$radius, $radius, $radius],
		     -visible => 1,
		     -filled => 1,
		     -closed => 1,
		     -extent => 60,
		     -pieslice => 1,
		     -fillcolor => $color,
		     -linewidth => 0,
		     -startangle => 60*$i ,
		     -tags => [$self],
		     );
	$i++;
    }
    
    # Create the Text item representing the jackpot.
    $widget->add('text', $self->{topgroup},
		 -position => [0, -$radius+20],
		 -font =>
		 '-adobe-helvetica-bold-o-normal--34-240-100-100-p-182-iso8859-1',
		 -anchor => 'center',
		 -text => "\$",
		 );
    
    # Create the closed Curve item representing the hand.
    # In order to make processing easier, its rotation axis will be placed
    # on the group origin.
    $self->{hand} = $widget->add('curve', $self->{topgroup},
				 [0, -$radius + 10, 20, -$radius + 40,
				  6, -$radius + 40, 20, 10,
				  -20, 10, -6, -$radius + 40,
				  -20, -$radius + 40],
				 -linewidth => 3,
				 -linecolor => 'gray40',
				 -filled => 1,
				 -fillcolor => 'gray80',
				 -closed => 1,
				 -tags => [$self]);
    # Then, we apply rotation to the hand using the Zinc 'rotation' method.
    $widget->rotate($self->{hand}, 3.1416/3);
    
    # Then we unmap the wheel; in fact, Group item is translated and its
    # clipping circle is shrunk to a point.
    $self->_clipAndTranslate($shrinkrate**$stepsnumber);

    return $self;
    
}

#================
# Public methods
#================

# Return 1 if wheel is moving (opening or closing animation)
sub ismoving {
    my $self = shift;
    return 1 if $self->{opening} or $self->{closing};
}

# Display wheel with animation effect
sub show {
    my ($self, $x, $y) = @_;
    # simple lock management
    return if $self->{opening} or $self->{closing};
    $self->{opening} = 1;
    # start animation 
    $self->_open($x, $y, 0);
}


# Unmap wheel with animation effect
sub hide {
    my ($self, $x, $y) = @_;
    # simple lock management
    return if $self->{opening} or $self->{closing};
    $self->{closing} = 1;
    # start animation
    $self->_close($x, $y, 0);
}


# Just rotate the hand with animation effect.
sub rotatehand {
    my $self = shift;
    my $angle = shift;
    return if $self->{turning};
    $angle = 360 unless $angle;
    $self->{angle} += $angle;
    if ($self->{angle} % 360 == 0) {
	$self->{fortune} = 1;
    }
    $self->_rotatehand(2*3.1416*$angle/360);   
}


#=================
# Private methods
#=================

# Generate opening animation; see below _clipAndTranslate method for
# Zinc specific use.
sub _open {
    my ($self, $x, $y, $cnt) = @_;
    my $widget = $self->{widget};
    my $group = $self->{topgroup};
    # first step of animation
    if ($cnt == 0) {
	$widget->itemconfigure($group, -visible => 1);
	my @pos = $widget->coords($group);
	$x = ($x - $pos[0])/$stepsnumber;
	$y = ($y - $pos[1])/$stepsnumber;
    # last step
    } elsif ($cnt == $stepsnumber) {
	$self->{opening} = undef;
	return;
    }
    $cnt++;
    # move and grow the wheel
    $self->_clipAndTranslate(1/$shrinkrate, $x, $y);
    # process the animation using the 'after' Tk defering method
    $widget->after($afterdelay, sub {$self->_open($x, $y, $cnt)});
}


# Generate closing animation; see below _clipAndTranslate method for
# Zinc specific use.
sub _close {
    my ($self, $x, $y, $cnt) = @_;
    my $widget = $self->{widget};
    my $group = $self->{topgroup};
    # first step of animation
    if ($cnt == 0) {
	my @pos = $widget->coords($group);
	$x = ($x - $pos[0])/$stepsnumber;
	$y = ($y - $pos[1])/$stepsnumber;
    # last step
    } elsif ($cnt == $stepsnumber) {
	$widget->itemconfigure($group, -visible => 0);
	$self->{closing} = undef;
	return;
    }
    $cnt++;
    # move and shrink the wheel
    $self->_clipAndTranslate($shrinkrate, $x, $y);
    # process the animation using the 'after' Tk defering method
    $widget->after($afterdelay, sub {$self->_close($x, $y, $cnt)});
}


# Generate hand rotation animation.
sub _rotatehand {
    my ($self, $angle, $cnt) = @_;
    my $widget = $self->{widget};
    my $group = $self->{topgroup};
    $self->{turning} = 1;
    # first step of animation
    if (not $cnt) {
	$angle /= $stepsnumber;
    # last step
    } elsif ($cnt == $stepsnumber) {
	if ($self->{fortune}) {
	    $self->_fortune;
	} else {
	    $self->{turning} = undef;
	}
	return;
    }
    $cnt++;
    # use 'rotation' Zinc method.
    $widget->rotate($self->{hand}, $angle);
    
    # process the animation using the 'after' Tk defering method
    $widget->after($afterdelay, sub {$self->_rotatehand($angle, $cnt)});
        
}

# Generate growing animation to notify jackpot
sub _fortune {
    my ($self, $cnt) = @_;
    my $zf;
    my $widget = $self->{widget};
    my $group = $self->{topgroup};
    my @pos = $widget->coords($group);
    # last step of animation
    if ($cnt == 6) {
	$self->{fortune} = undef;
	$self->{turning} = undef;
	return;
    # event steps : wheel grows
    } elsif ($cnt % 2 == 0) {
	$zf = $zoomrate;
    # odd steps : wheel is shrunk
    } else {
	$zf = 1/$zoomrate;
    }
    $cnt++;
    
    # Now, we apply scale transformation to the Group item, using the 'scale'
    # Zinc method. Note that we reset group coords before scaling it, in order
    # that the origin of the transformation corresponds to the center of the
    # wheel. When scale is done, we restore previous coords of group.
    $widget->coords($group, [0, 0]);
    $widget->scale($group, $zf, $zf);
    $widget->coords($group, \@pos);
    
    # process the animation using the 'after' Tk defering method
    $widget->after(100, sub {$self->_fortune($cnt)});
    
}

# Update group clipping and translation, using 'scale' and 'translate'
# Zinc methods.
sub _clipAndTranslate {
    my ($self, $shrinkfactor, $x, $y) = @_;
    $x = 0 unless $x;
    $y = 0 unless $y;
    $self->{widget}->scale($self->{itemclip}, $shrinkfactor, $shrinkfactor);
    $self->{widget}->translate($self->{topgroup}, $x, $y);

}


1;
