# $Id: transforms.tcl,v 1.3 2003/04/16 09:42:57 lecoanet Exp $
# This simple demo has been developped by P. Lecoanet <lecoanet@cena.fr>

#
# TODO:
#
# Add the building of missing items
#

if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}

set w .transforms
catch {destroy $w}
toplevel $w
wm title $w "Zinc Transformation Demonstration"
wm iconname $w Transformation

set defaultfont [font create -family Helvetica -size 10 -weight bold]

frame $w.buttons
pack $w.buttons -side bottom -fill x -pady 2m
button $w.buttons.dismiss -text Dismiss -command "destroy $w"
button $w.buttons.code -text "See Code" -command "showCode $w"
pack $w.buttons.dismiss $w.buttons.code -side left -expand 1


###########################################
# Text zone
###########################################
text $w.text -relief sunken -borderwidth 2 -setgrid true -height 12

pack $w.text -expand yes -fill x

$w.text insert 0.0 {Items are always added to the current group.
The available commands are:
   Button 1       on the background, add an item with initial translation
   Button 2       on the background, add a group with initial translation
   Button 1       on item/group axes, select/deselect that item space
   Drag Button 1  on item/group axes, translate that item space
   Del            reset the transformation
   Shift-Del      reset a group direct children transformations
   PageUp/Down    scale up/down
   End/Home       rotate right/left
   Ins            swap the Y axis
   4 arrows       translate in the 4 directions}
$w.text configure -state disabled

###########################################
# Zinc
###########################################
set zinc_width 600
set zinc_height 500;
zinc $w.zinc -width $zinc_width -height $zinc_height \
    -font 10x20 -borderwidth 3 -relief sunken -takefocus 1 -render 0
pack $w.zinc -expand y -fill both


set top 1

set inactiveAxisColor black
set activeAxisColor red
set worldAxisColor \#a5a5a5

set composeRot 1
set composeScale 1
set drag 0
set itemType Rectangle
set currentItem 0

image create photo logo -file [file join $zinc_library demos images zinc.gif]

frame $w.f
pack $w.f -expand 0 -fill x

tk_optionMenu $w.f.types itemType Rectangle Arc Curve Icon Tabular \
    Text Track Triangles WayPoint
grid $w.f.types -row 0 -column 1 -sticky w

button $w.f.add -text {Add item} -command addItem
grid $w.f.add -row 0 -column 2 -padx 10 -sticky ew

button $w.f.addg -text {Add group} -command addGroup
grid $w.f.addg -row 0 -column 3 -padx 10 -sticky ew

button $w.f.remove -text Remove -command removeItem
grid $w.f.remove -row 0 -column 4 -padx 10 -sticky ew

checkbutton $w.f.cscale -text -composescale -command toggleComposeScale \
    -variable composeScale
grid $w.f.cscale -row 0 -column 6 -sticky w

checkbutton $w.f.crot -text -composesrotation -command toggleComposeRot \
    -variable composeRot
grid $w.f.crot -row 1 -column 6 -sticky w


set world [$w.zinc add group $top]
set currentGroup $world
$w.zinc add curve $top {0 0 80 0} -linewidth 3 \
    -linecolor $worldAxisColor -lastend {6 8 3} -tags "axis:$world"
$w.zinc add curve $top {0 0 0 80} -linewidth 3 \
    -linecolor $worldAxisColor -lastend {6 8 3} -tags "axis:$world"
$w.zinc add rectangle $top {-2 -2 2 2} -filled 1 \
    -fillcolor $worldAxisColor -linecolor $worldAxisColor \
    -linewidth 3 -tags "axis:$world"
$w.zinc add text $top -text "This is the origin\nof the world" \
    -anchor s -color $worldAxisColor -alignment center \
    -tags [list "axis:$world" text]


bind $w.zinc <1> "mouseAdd Item %x %y"
bind $w.zinc <2> "mouseAdd Group %x %y"
bind $w.zinc <Up> moveUp
bind $w.zinc <Left> moveLeft
bind $w.zinc <Right> moveRight
bind $w.zinc <Down> moveDown
bind $w.zinc <Next> scaleDown
bind $w.zinc <Prior> scaleUp
bind $w.zinc <Delete> reset
bind $w.zinc <Shift-Delete> resetChildren
bind $w.zinc <End> rotateLeft
bind $w.zinc <Home> rotateRight
bind $w.zinc <Insert> swapAxis

bind $w.zinc <Configure> "resize %w %h"

focus $w.zinc
tk_focusFollowsMouse


proc resize {width height} {
    global w world

    set x [expr $width/2]
    set y [expr $height/2]
    
    $w.zinc treset $world
    $w.zinc treset "axis:$world"
    $w.zinc translate $world $x $y
    $w.zinc translate "axis:$world" $x $y
}

proc swapAxis {} {
    global w currentItem

    if {$currentItem != 0} {
	$w.zinc scale $currentitem 1 -1
	$w.zinc scale "axisgrp:$currentItem" 1 -1
    }
}

proc toggleComposeRot {} {
    global w currentItem composeRot

    if {$currentItem != 0} {
    $w.zinc itemconfigure $currentItem -composerotation $composeRot
    $w.zinc itemconfigure "axisgrp:$currentItem" -composerotation $composeRot
  }
}

proc toggleComposeScale {} {
    global w currentItem composeScale
    
    if {$currentItem != 0} {
	$w.zinc itemconfigure $currentItem -composescale $composeScale
	$w.zinc itemconfigure "axisgrp:$currentItem" -composescale $composeScale
    }
}

proc dragItem {x y} {
    global w drag currentItem

    set drag 1
    if {$currentItem == 0} {
	return
    }
    
    set group [$w.zinc group $currentItem]
    foreach {x y} [$w.zinc transform $group "$x $y"] break
    
    $w.zinc treset $currentItem
    $w.zinc treset "axisgrp:$currentItem"
    $w.zinc translate $currentItem $x $y
    $w.zinc translate "axisgrp:$currentItem" $x $y
}

proc select {} {
    global w
    
    foreach t [$w.zinc gettags current] {
	if {[regexp {^axis:(\d+)} $t m item]} {
	    changeItem $item
	}
    }
}

proc changeItem {item} {
    global w currentItem currentGroup
    global drag activeAxisColor inactiveAxisColor

    if {($currentItem != 0) && !$drag} {
	$w.zinc itemconfigure "axis:$currentItem && !text" \
	    -linecolor $inactiveAxisColor -fillcolor $inactiveAxisColor
	if {$currentItem != $currentGroup} {
	    $w.zinc itemconfigure "axis:$currentItem && !text" -linewidth 1
	}
    }
    if {($currentItem == 0) || ($item != $currentItem)} {
	$w.zinc itemconfigure "axis:$item && !text" \
	    -linecolor $activeAxisColor -fillcolor $activeAxisColor -linewidth 3
	set currentItem $item
	set composeRot [$w.zinc itemcget $currentItem -composerotation]
	$w.zinc itemconfigure "axisgrp:$currentItem" -composerotation $composeRot
	set composeScale [$w.zinc itemcget $currentItem -composescale]
	$w.zinc itemconfigure "axisgrp:$currentItem" -composescale $composeScale
    } elseif {!$drag} {
	set currentItem 0
	set composeRot 1
	set composeScale 1
    }
    set drag 0
}

proc selectGroup {} {
    global w

    foreach t [$w.zinc gettags current] {
	if {[regexp {^axis:(\d+)} $t m item]} {
	    changeGroup $item
	}
    }
}

proc changeGroup {grp} {
    global w currentItem currentGroup world
    
    changeItem $grp
    $w.zinc itemconfigure "axis:$currentGroup && !text" -linewidth 1
    if {$currentItem != 0} {
	set currentGroup $currentItem
    } else {
	set currentGroup $world
    }

    $w.zinc itemconfigure "axis:$currentGroup && !text" -linewidth 3
}

proc reset {} {
    global w currentItem

    if {$currentItem != 0} {
	$w.zinc treset $currentItem
	$w.zinc treset "axisgrp:$currentItem"
    }
}

proc resetChildren {} {
    global w currentItem

    if {($currentItem != 0) && ([$w.zinc type $currentItem] == "group")} {
	$w.zinc addtag rt withtag all $currentItem 0
	$w.zinc treset rt
	$w.zinc dtag rt rt
    }
}

proc moveUp {} {
  move 0 20
}

proc moveDown {} {
  move 0 -20
}

proc moveRight {} {
  move 20 0
}

proc moveLeft {} {
  move -20 0
}

proc move {dx dy} {
    global w currentItem

    if {$currentItem != 0} {
	$w.zinc translate $currentItem $dx $dy
	$w.zinc translate "axisgrp:$currentItem" $dx $dy
    }
}

proc scaleUp {} {
  scale 1.1 1.1
}

proc scaleDown {} {
  scale 0.9 0.9
}

proc scale {dx dy} {
    global w currentItem

    if {$currentItem != 0} {
	$w.zinc scale $currentItem $dx $dy
	$w.zinc scale "axisgrp:$currentItem" $dx $dy
    }
}

proc rotateLeft {} {
    rotate [expr -3.14159/18]
}

proc rotateRight {} {
    rotate [expr 3.14159/18]
}

proc rotate {angle} {
    global w currentItem
    
    if {$currentItem != 0} {
	$w.zinc rotate $currentItem $angle
	$w.zinc rotate "axisgrp:$currentItem" $angle
    }
}

proc newRectangle {} {
    global w currentGroup

    return [$w.zinc add rectangle $currentGroup {-15 -15 15 15} \
		-filled 1 -linewidth 0 -fillcolor tan]
}

proc newArc {} {
    global w currentGroup

    return [$w.zinc add arc $currentGroup {-25 -15 25 15} \
		-filled 1 -linewidth 0 -fillcolor tan]
}

proc newCurve {} {
    global w currentGroup

    return [$w.zinc add curve $currentGroup {-15 -15 -15 15 15 15 15 -15} \
		-filled 1 -linewidth 0 -fillcolor tan]
}

proc newText {} {
    global w currentGroup

    set item [$w.zinc add text $currentGroup -anchor s]
    $w.zinc itemconfigure $item -text "Item id: $item"
    return $item;
}

proc newIcon {} {
    global w currentGroup

    return [$w.zinc add icon $currentGroup -image logo -anchor center]
}

proc newTriangles {} {
    global w currentGroup

    return [$w.zinc add triangles $currentGroup \
		{-25 15 -10 -15 5 15 20 -15 35 15 50 -30} \
		-colors {tan wheat tan wheat}]
}

proc newTrack {} {
    global w currentGroup

    set labelformat {x80x50+0+0 a0a0^0^0 a0a0^0>1 a0a0>2>1 x30a0>3>1 a0a0^0>2}
    
    set item [$w.zinc add track $currentGroup 6 -labelformat $labelformat \
		  -speedvector {30 -15} -markersize 20]
    $w.zinc itemconfigure $item 0 -filled 0 -bordercolor DarkGreen -border contour
    $w.zinc itemconfigure $item 1 -filled 1 -backcolor gray60 -text AFR6128
    $w.zinc itemconfigure $item 2 -filled 0 -backcolor gray65 -text 390
    $w.zinc itemconfigure $item 3 -filled 0 -backcolor gray65 -text /
    $w.zinc itemconfigure $item 4 -filled 0 -backcolor gray65 -text 350
    $w.zinc itemconfigure $item 5 -filled 0 -backcolor gray65 -text TUR

    return $item;
}

proc newWayPoint {} {
    global w currentGroup

    set labelformat {a0a0+0+0 a0a0>0^1}

    set item [$w.zinc add waypoint $currentGroup 2 -labelformat $labelformat]
    $w.zinc itemconfigure $item 0 -filled 1 -backcolor DarkGreen -text TUR
    $w.zinc itemconfigure $item 1 -text >>>

    return $item;
}

proc newTabular {} {
    global w currentGroup

    set labelformat {f700f600+0+0 f700a0^0^0 f700a0^0>1 \
			 f700a0^0>2 f700a0^0>3 f700a0^0>4 f700a0^0>5}

    set item [$w.zinc add tabular $currentGroup 7 -labelformat $labelformat]
    $w.zinc itemconfigure $item 0 -filled 1 -border contour \
	-bordercolor black -backcolor gray60
    $w.zinc itemconfigure $item 1 -alignment center -text AFR6128
    $w.zinc itemconfigure $item 2 -alignment center -text 390
    $w.zinc itemconfigure $item 3 -alignment center -text 370
    $w.zinc itemconfigure $item 4 -alignment center -text 350
    $w.zinc itemconfigure $item 5 -alignment center -text 330
    $w.zinc itemconfigure $item 6 -alignment center -text TUR

    return $item;
}

proc addAxes {item length command inFront} {
    global w currentGroup

    set axesGroup [$w.zinc add group $currentGroup -tags "axisgrp:$item"]
    $w.zinc add curve $axesGroup "0 0 $length 0" -linewidth 2 \
	-lastend {6 8 3} -tags "axis:$item"
    $w.zinc add curve $axesGroup "0 0 0 $length" -linewidth 2 \
	-lastend {6 8 3} -tags "axis:$item"
    $w.zinc add rectangle $axesGroup {-2 -2 2 2} -filled 1 \
	-linewidth 0 -composescale 0 -tags "axis:$item"
    if {$inFront} {
	$w.zinc raise $item $axesGroup
    }
    $w.zinc bind "axis:$item" <B1-Motion> "dragItem %x %y"
    $w.zinc bind "axis:$item" <ButtonRelease-1> $command
}

proc addItem {} {
    global itemType

    set length 25
    set itemOnTop 0

    set item [eval "new$itemType"]
    if {($itemType == "Track") || ($itemType == "WayPoint")} {
	set itemOnTop 1
    }

    addAxes $item 25 select $itemOnTop
    changeItem $item
}

proc addGroup {} {
    global w currentGroup

    set item [$w.zinc add group $currentGroup]

    addAxes $item 80 selectGroup 1
    changeGroup $item
}

proc mouseAdd {itemOrGroup x y} {
    global w currentGroup currentItem

    foreach {x y} [$w.zinc transform $currentGroup "$x $y"] break
    set item [$w.zinc find withtag current]

    if {[llength $item] != 0} {
	foreach t [$w.zinc gettags [lindex $item 0]] {
	    if {[regexp {^axis} $t]} {
		return;
	    }
	}
    }

    eval "add$itemOrGroup"

    $w.zinc translate $currentItem $x $y
    $w.zinc translate "axisgrp:$currentItem" $x $y
}

proc removeItem {} { 
    global w currentGroup currentItem world
    
    if {$currentItem != 0} {
	$w.zinc remove $currentItem "axisgrp:$currentItem"
	if {$currentItem == $currentGroup} {
	    set currentGroup $world
	}
	set currentItem 0
	set composeScale 1
	set composeRot 1
    }
}
