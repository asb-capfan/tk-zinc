# $Id: photoAlpha.tcl,v 1.2 2003/04/16 09:42:57 lecoanet Exp $
# this simple demo has been developped by P.Lecoanet <lecoanet@cena.fr>

if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}

package require Img

set w .photoAlpha
catch {destroy $w}
toplevel $w
wm title $w "Zinc photo transparency Demonstration"
wm iconname $w photoAlpha

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

text $w.text -relief sunken -borderwidth 2 -height 7
pack $w.text -expand yes -fill both

$w.text insert end {This demo needs openGL for displaying the photo
with transparent pixels and for rescaling/rotating.
   You can transform this png photo with your mouse:
     Drag-Button 1 for moving the photo,
     Drag-Button 2 for zooming the photo,
     Drag-Button 3 for rotating the photo,
     Shift-Drag-Button 1 for modifying the global photo transparency.}


image create photo girl -file [file join $zinc_library demos images photoAlpha.png]
image create photo texture -file [file join $zinc_library demos images stripped_texture.gif]

###########################################
# Zinc
##########################################
zinc $w.zinc -width 350 -height 250 -render 1 -font 10x20 \
    -borderwidth 3 -relief sunken -tile texture
pack $w.zinc

set topGroup [$w.zinc add group 1]

set girl [$w.zinc add icon $topGroup -image girl \
	      -composescale 1 -composerotation 1]

#
# Controls for the window transform.
#
bind $w.zinc <ButtonPress-1>  "press motion %x %y"
bind $w.zinc <ButtonRelease-1>  release
bind $w.zinc <ButtonPress-2>  "press zoom %x %y"
bind $w.zinc <ButtonRelease-2>  release
bind $w.zinc <ButtonPress-3>  "press mouseRotate %x %y"
bind $w.zinc <ButtonRelease-3>  release

#
# Controls for alpha and gradient
#
bind $w.zinc <Shift-ButtonPress-1> "press modifyAlpha %x %y"
bind $w.zinc <Shift-ButtonRelease-1> release


set curX 0
set curY 0
set curAngle 0

proc press {action x y} {
    global w curAngle curX curY

    set curX $x
    set curY $y
    set curAngle [expr atan2($y, $x)]
    bind $w.zinc <Motion> "$action %x %y"
}

proc motion {x y} {
    global w topGroup curX curY

    foreach {x1 y1 x2 y2} [$w.zinc transform $topGroup \
			       [list $x $y $curX $curY]] break
    $w.zinc translate $topGroup [expr $x1 - $x2] [expr $y1 - $y2]
    set curX $x
    set curY $y
}

proc zoom {x y} {
    global w topGroup curX curY

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
    $w.zinc scale $topGroup $sx $sx

    set curX $x
    set curY $y
}

proc mouseRotate {x y} {
    global w curAngle topGroup

    set lAngle [expr atan2($y, $x)]
    $w.zinc rotate $topGroup [expr $lAngle - $curAngle]
    set curAngle  $lAngle
}

proc release {} {
    global w

    bind $w.zinc <Motion> {}
}

proc modifyAlpha {x y} {
    global w topGroup

    set xRate [expr double($x) / [$w.zinc cget -width]]
    set xRate [expr ($xRate < 0) ? 0 : ($xRate > 1) ? 1 : $xRate]
    set alpha [expr int($xRate * 100)]

    $w.zinc itemconfigure $topGroup -alpha $alpha
}
