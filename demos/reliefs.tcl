# $Id: reliefs.tcl,v 1.2 2003/04/24 14:20:33 lecoanet Exp $
# this simple demo has been developped by P.Lecoanet <lecoanet@cena.fr>

if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}

set w .reliefs
catch {destroy $w}
toplevel $w
wm title $w "Zinc Relief Testbed"
wm iconname $w reliefs

set allReliefs {flat raised sunken groove ridge \
	        roundraised roundsunken roundgroove roundridge \
	        sunkenrule raisedrule}

set defaultfont [font create -family Helvetica -size 10 -weight bold]

frame $w.buttons
pack $w.buttons -side bottom -fill x -pady 2m
button $w.buttons.dismiss -text Dismiss -command "destroy $w"
button $w.buttons.code -text "See Code" -command "showCode $w"
pack $w.buttons.dismiss $w.buttons.code -side left -expand 1



###########################################
# Text zone
#######################
####################

text $w.text -relief sunken -borderwidth 2 -height 8 -width 50
pack $w.text -expand yes -fill both

$w.text insert end {  This demo lets you play with the various relief parameters
on rectangles polygons and arcs. Some reliefs and The smooth relief
capability is only available with openGL.
  You can modify the items with your mouse:

  Drag-Button 1 for moving    Ctrl/Shft-Button 1 for Incr/Decr sides
  Drag-Button 2 for zooming   Ctrl/Shft-Button 2 for cycling reliefs
  Drag-Button 3 for rotating  Ctrl/Shft-Button 3 for Incr/Decr border}


###########################################
# Zinc
##########################################
proc deg2Rad {deg} {
    return [expr 3.14159 * $deg / 180.0]
}

proc rad2Deg {rad} {
    return [expr int(fmod(($rad * 180.0 / 3.14159)+360.0, 360.0))]
}

set bw 4
set width 60
set lightAngle 120
set lightAngleRad [deg2Rad $lightAngle]
set zincSize 500

zinc $w.zinc -width $zincSize -height $zincSize -render 1 -font 10x20 \
    -highlightthickness 0 -borderwidth 0 -relief sunken -backcolor lightgray \
    -lightangle $lightAngle
pack $w.zinc -expand t -fill both

set topGroup [$w.zinc add group 1]

proc polyPoints { ox oy rad n } {
    set step [expr 2 * 3.14159 / $n]
    for {set i 0} {$i < $n} {incr i} {
	set x [expr $ox + ($rad * cos($i * $step))];
	set y [expr $oy + ($rad * sin($i * $step))];
	lappend coords $x $y;
    }
    lappend coords [lindex $coords 0] [lindex $coords 1]
    return $coords
}

proc makePoly {x y bw sides color group} {
    global w state allReliefs width

    set relief 2

    set g [$w.zinc add group $group]
    $w.zinc translate $g $x $y
    $w.zinc add curve $g [polyPoints 0 0 $width $sides] \
	-relief [lindex $allReliefs $relief] -linewidth $bw \
	-smoothrelief 1 -fillcolor $color -linecolor $color \
	-filled t -tags {subject polygon}
    $w.zinc add text $g -anchor center \
	-text [lindex $allReliefs $relief] -tags {subject relief}
    $w.zinc add text $g -anchor center -position {0 16} \
	-text $bw -tags {subject bw}
    set state($g,sides) $sides
    set state($g,relief) $relief
    set state($g,bw) $bw
    return $g
}

set poly [makePoly 100 100 $bw 8 lightblue $topGroup]
set poly [makePoly [expr 100 + 2*($width + 10)] 100 $bw 8 tan $topGroup]
set poly [makePoly [expr 100 + 4*($width + 10) ] 100 $bw 8 slateblue $topGroup]

proc lightCenter {radius angle} {
    return [list [expr $radius * (1 + 0.95*cos($angle))] \
		[expr $radius * (1 - 0.95*sin($angle))]]
}

#
# Place the light at lightAngle on the circle
$w.zinc add arc 1 {-5 -5 5 5} -filled 1 -fillcolor yellow \
    -tags light -priority 10
eval "$w.zinc translate light [lightCenter [expr $zincSize/2] $lightAngleRad]"

#
# Controls.
#
$w.zinc bind subject <ButtonPress-1>  "press motion %x %y"
$w.zinc bind subject <ButtonRelease-1>  release
$w.zinc bind subject <ButtonPress-2>  "press zoom %x %y"
$w.zinc bind subject <ButtonRelease-2>  release
$w.zinc bind subject <ButtonPress-3>  "press mouseRotate %x %y"
$w.zinc bind subject <ButtonRelease-3>  release

$w.zinc bind polygon <Shift-ButtonPress-1>  "incrPolySides 1"
$w.zinc bind polygon <Control-ButtonPress-1>  "incrPolySides -1"

$w.zinc bind subject <Shift-ButtonPress-2>  "cycleRelief 1"
$w.zinc bind subject <Control-ButtonPress-2>  "cycleRelief -1"

$w.zinc bind subject <Shift-ButtonPress-3>  "incrBW 1"
$w.zinc bind subject <Control-ButtonPress-3>  "incrBW -1"

$w.zinc bind light <ButtonPress-1>  "press lightMotion %x %y"
$w.zinc bind light <ButtonRelease-1>  release

set curX 0
set curY 0
set curAngle 0

proc press {action x y} {
    global w curAngle curX curY

    $w.zinc raise [$w.zinc group current]

    set curX $x
    set curY $y
    set curAngle [expr atan2($y, $x)]
    bind $w.zinc <Motion> "$action %x %y"
}

proc motion {x y} {
    global w curX curY topGroup

    foreach {x1 y1 x2 y2} [$w.zinc transform $topGroup \
			       [list $x $y $curX $curY]] break
    $w.zinc translate [$w.zinc group current] [expr $x1 - $x2] [expr $y1 - $y2]
    set curX $x
    set curY $y
}

proc lightMotion {x y} {
    global w zincSize topGroup

    set radius [expr $zincSize/2]
    if { $x < 0 } {
	set x 0
    } elseif { $x > $zincSize } {
	set x $zincSize
    }
	
    set angle [expr acos(double($x-$radius)/$radius)]
    if { $y > $radius } {
	set angle [expr - $angle]
    }
    $w.zinc treset light
    eval "$w.zinc translate light [lightCenter [expr $zincSize/2] $angle]"
    $w.zinc configure -lightangle [rad2Deg $angle]
}

proc zoom {x y} {
    global w curX curY

    if {$x > $curX} {
	set maxX $x
    } else {
	set maxX $curX
    }
    if {$y > $curY} {
	set maxY $y
    } else {
	set maxY $curY
    }
    if {($maxX == 0) || ($maxY == 0)} {
	return;
    }
    set sx [expr 1.0 + (double($x - $curX) / $maxX)]
    set sy [expr 1.0 + (double($y - $curY) / $maxY)]
    $w.zinc scale current $sx $sx

    set curX $x
    set curY $y
}

proc mouseRotate {x y} {
    global w curAngle

    set lAngle [expr atan2($y, $x)]
    $w.zinc rotate current [expr $lAngle - $curAngle]
    set curAngle  $lAngle
}

proc release {} {
    global w

    bind $w.zinc <Motion> {}
}

proc incrPolySides {incr} {
    global w state width

    set g [$w.zinc group current]
    incr state($g,sides) $incr
    if { $state($g,sides) < 3 } {
	set state($g,sides) 3
    }

    set points [polyPoints 0 0 $width $state($g,sides)]
    $w.zinc coords $g.polygon $points
}

proc cycleRelief {incr} {
    global w state allReliefs

    set g [$w.zinc group current]
    incr state($g,relief) $incr
    if { $state($g,relief) < 0 } {
	set state($g,relief) [expr [llength $allReliefs] - 1]
    } elseif { $state($g,relief) >= [llength $allReliefs] } {
	set state($g,relief) 0
    }
    set rlf [lindex $allReliefs $state($g,relief)]
    $w.zinc itemconfigure $g.polygon -relief $rlf
    $w.zinc itemconfigure $g.relief -text $rlf
}

proc incrBW {incr} {
    global w state

    set g [$w.zinc group current]
    incr state($g,bw) $incr
    if { $state($g,bw) < 0 } {
	set state($g,bw) 0
    }
    $w.zinc itemconfigure $g.polygon -linewidth $state($g,bw)
    $w.zinc itemconfigure $g.bw -text $state($g,bw)
}
