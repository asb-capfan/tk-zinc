#
# $Id: tkZincLogo.tcl,v 1.5 2003/04/16 09:42:57 lecoanet Exp $
# this simple demo has been adapted by C. Mertz <mertz@cena.fr> from the original
# work of JL. Vinot <vinot@cena.fr>
# Ported to Tcl by P.Lecoanet

if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}

#
# We need the zincLogo support
package require zincLogo


set w .tkZincLogo
catch {destroy $w}
toplevel $w
wm title $w "Zinc logo Demonstration"
wm iconname $w tkZincLogo

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

$w.text insert end {This tkZinc logo should used openGL for a correct rendering!
   You can transform this logo with your mouse:
     Drag-Button 1 for moving the logo,
     Drag-Button 2 for zooming the logo,
     Drag-Button 3 for rotating the logo,
     Shift-Drag-Button 1 for modifying the logo transparency,
     Shift-Drag-Button 2 for modifying the logo gradient.}


###########################################
# Zinc
##########################################
zinc $w.zinc -width 350 -height 250 -render 1 -font 10x20 \
    -borderwidth 3 -relief sunken
pack $w.zinc

set topGroup [$w.zinc add group 1]

set logo [zincLogo::create $w.zinc $topGroup 800 40 70 0.6 0.6]

#
# Controls for the window transform.
#
bind $w.zinc <ButtonPress-1>  "press motion %x %y"
bind $w.zinc <ButtonRelease-1>  release
bind $w.zinc <ButtonPress-2>  "press zoom %x %y"
bind $w.zinc <ButtonRelease-2>  release
bind $w.zinc <ButtonPress-3> "press mouseRotate %x %y"
bind $w.zinc <ButtonRelease-3> release

#
# Controls for alpha and gradient
#
bind $w.zinc <Shift-ButtonPress-1> "press modifyAlpha %x %y"
bind $w.zinc <Shift-ButtonRelease-1> release
bind $w.zinc <Shift-ButtonPress-2> "press modifyGradient %x %y"
bind $w.zinc <Shift-ButtonRelease-2> release


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
    global w curAngle logo

    set lAngle [expr atan2($y, $x)]
    $w.zinc rotate $logo [expr $lAngle - $curAngle]
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

proc modifyGradient {x y} {
    global w

    set yRate [expr double($y) / [$w.zinc cget -height]]
    set yRate [expr ($yRate < 0) ? 0 : ($yRate > 1) ? 1 : $yRate]
    set gradPercent [expr int($yRate * 100)]
    
    $w.zinc itemconfigure letters -fillcolor "=axial 270|#ffffff;100 0 28|#66848c;100 $gradPercent|#7192aa;100 100"
}