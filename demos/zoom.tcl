# these simple samples have been developped by C. Mertz mertz@cena.fr in perl
# tcl version by Jean-Paul Imbert imbert@cena.fr


if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}

set w .zoom
catch {destroy $w}
toplevel $w
wm title $w "Zinc Zoom Demonstration"
wm iconname $w Zoom

set defaultfont [font create -family Helvetica -size 10 -weight bold]

frame $w.buttons
pack $w.buttons -side bottom -fill x -pady 2m
button $w.buttons.dismiss -text Dismiss -command "destroy $w"
button $w.buttons.code -text "See Code" -command "showCode $w"
pack $w.buttons.dismiss $w.buttons.code -side left -expand 1


###########################################
# Text zone
###########################################

text $w.text -relief sunken -borderwidth 2 -height 4
pack $w.text -expand yes -fill both

$w.text insert end "This toy-appli shows zoom actions on waypoint and curve items.\nThe following operations are possible:\n Click - to zoom out\n Click + to zoom in"

###########################################
# Zinc
###########################################
set zinc_width 600
set zinc_height 500
zinc $w.zinc -width $zinc_width -height $zinc_height -font 10x20 -borderwidth 3 -relief sunken
pack $w.zinc

###########################################
# Waypoints and sector
###########################################
set wp_group [$w.zinc add group 1 -visible 1]

set p1 {200 100}
set wp1 [$w.zinc add waypoint $wp_group 1 -position $p1 -connectioncolor green -symbolcolor blue -labelformat {x20x18+0+0} -leaderwidth 0 -labeldx -20]

$w.zinc itemconfigure $wp1 0 -text DO

set p2 {300 150}
set wp2 [$w.zinc add waypoint $wp_group 1 -position $p2 -connecteditem $wp1 -connectioncolor blue -symbolcolor blue -labelformat {x20x18+0+0} -leaderwidth 0 -labeldx -20]

$w.zinc itemconfigure $wp2 0 -text RE

set p3 {400 50}
set wp3 [$w.zinc add waypoint $wp_group 2 -position $p3 -connecteditem $wp2 -connectioncolor blue -symbolcolor blue -labelformat {x20x18+0+0} -leaderwidth 0 -labeldx 20 -labeldy +10]

$w.zinc itemconfigure $wp3 0 -text MI

set p4 {350 450}
set wp4 [$w.zinc add waypoint $wp_group 2 -position $p4 -connecteditem $wp2 -connectioncolor blue -symbolcolor blue -labelformat {x20x18+0+0} -leaderwidth 0 -labeldx -15]

$w.zinc itemconfigure $wp4 0 -text FA

set p5 {300 250}
set wp5 [$w.zinc add waypoint $wp_group 2 -position $p5 -connectioncolor blue -symbolcolor blue -labelformat {x20x18+0+0} -leaderwidth 0 -labeldx -15]

$w.zinc itemconfigure $wp5 0 -text SOL

set p6 {170 240}
set wp6 [$w.zinc add waypoint $wp_group 2 -position $p6 -connecteditem $wp5 -connectioncolor blue -symbolcolor blue -labelformat {x20x18+0+0} -leaderwidth 0 -labeldx -20]

$w.zinc itemconfigure $wp6 0 -text LA

set p7 {550 200}
set wp7 [$w.zinc add waypoint $wp_group 2 -position $p7 -connecteditem $wp5 -connectioncolor blue -symbolcolor blue -labelformat {x20x18+0+0} -leaderwidth 0 -labeldx 20]

$w.zinc itemconfigure $wp7 0 -text SI

set sector [$w.zinc add curve $wp_group {300 0 400 50 500 100 550 200 550 400 350 450 170 240 200 100 300 0}]

###################################################
# control panel
###################################################
frame $w.rc
pack $w.rc

#the reference of the scale function is top-left corner of the zinc object
#so we first translate the group to zoom in order to put its center on top-left corner
#change the scale of the group
#translate the group to put it back at the center of the zinc object 


button $w.rc.minus -width 2 -height 2 -text - -command {
    $w.zinc translate $wp_group [expr -$zinc_width/2] [expr -$zinc_height/2]
    $w.zinc scale $wp_group 0.8 0.8
    $w.zinc translate $wp_group [expr $zinc_width/2] [expr $zinc_height/2]
}
pack $w.rc.minus -side left

button $w.rc.plus -width 2 -height 2 -text + -command {
    $w.zinc translate $wp_group [expr -$zinc_width/2] [expr -$zinc_height/2]
    $w.zinc scale $wp_group 1.2 1.2
    $w.zinc translate $wp_group [expr $zinc_width/2] [expr $zinc_height/2]
}
pack $w.rc.plus -side right

