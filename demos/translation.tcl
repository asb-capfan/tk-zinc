# these simple samples have been developped by C. Mertz mertz@cena.fr in perl
# tcl version by Jean-Paul Imbert imbert@cena.fr

if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}

set w .translation
catch {destroy $w}
toplevel $w
wm title $w "Zinc Translation Demonstration"
wm iconname $w Translation

set defaultfont [font create -family Helvetica -size 10 -weight bold]

frame $w.buttons
pack $w.buttons -side bottom -fill x -pady 2m
button $w.buttons.dismiss -text Dismiss -command "destroy $w"
button $w.buttons.code -text "See Code" -command "showCode $w"
pack $w.buttons.dismiss $w.buttons.code -side left -expand 1

###########################################
# Text zone
###########################################
text $w.text -relief sunken -borderwidth 2 -setgrid true -height 6

pack $w.text -expand yes -fill both

$w.text insert end "This toy-appli shows translations on waypoint items.\nThe following operations are possible:\n  Click Up for up translation\n  Click Left for left translation\n  Click Right for right translation\n  Click Down for down translation"

###########################################
# Zinc
###########################################
set zinc_width 600
set zinc_height 500;
zinc $w.zinc -width $zinc_width -height $zinc_height -font 10x20 -borderwidth 3 -relief sunken
pack $w.zinc

###########################################
# Waypoints
###########################################

set wp_group [$w.zinc add group 1 -visible 1]

set p1 {200 200}
set wp1 [$w.zinc add waypoint $wp_group 1 -position $p1 -connectioncolor green -symbolcolor blue -labelformat {x20x18+0+0} -leaderwidth 0 -labeldx -20]

$w.zinc itemconfigure $wp1 0 -text DO


set p2 {300 300}
set wp2 [$w.zinc add waypoint $wp_group 1 -position $p2 -connecteditem $wp1 -connectioncolor blue -symbolcolor blue -labelformat {x20x18+0+0} -leaderwidth 0 -labeldx -20]

$w.zinc itemconfigure $wp2 0 -text RE


set p3 {400 150}
set wp3 [$w.zinc add waypoint $wp_group 2 -position $p3 -connecteditem $wp2 -connectioncolor blue -symbolcolor blue -labelformat {x20x18+0+0} -leaderwidth 0 -labeldx 20 -labeldy +10]

$w.zinc itemconfigure $wp3 0 -text MI


###################################################
# control panel
###################################################
frame $w.rc
pack $w.rc

button $w.rc.up -width 2 -height 2 -text Up -command {
    $w.zinc translate "$wp_group" 0 -10
}
grid $w.rc.up -row 0 -column 1

button $w.rc.left -width 2 -height 2 -text Left -command {
    $w.zinc translate "$wp_group" -10 0
}
grid $w.rc.left -row 1 -column 0


button $w.rc.right -width 2 -height 2 -text Right -command {
    $w.zinc translate "$wp_group" 10 0
}
grid $w.rc.right -row 1 -column 2

button $w.rc.down -width 2 -height 2 -text Down -command {
    $w.zinc translate "$wp_group" 0 10
}
grid $w.rc.down -row 2 -column 1
