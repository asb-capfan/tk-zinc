# these simple samples have been developped by C. Mertz mertz@cena.fr in perl
# tcl version by Jean-Paul Imbert imbert@cena.fr

if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}

set w .mapinfo
catch {destroy $w}
toplevel $w
wm title $w "Zinc Mapinfo Demonstration"
wm iconname $w Mapinfo

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

$w.text insert end "This toy-appli shows zoom actions on map item.\nThe following operations are possible:\n Click - to zoom out\n Click + to zoom in "

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

mapinfo mapinfo create
#creation of mapinfo

#--------------------------------
# Waypoints
#--------------------------------
mapinfo mapinfo add symbol 200 100 0
mapinfo mapinfo add symbol 300 150 0
mapinfo mapinfo add symbol 400 50 0
mapinfo mapinfo add symbol 350 450 0
mapinfo mapinfo add symbol 300 250 0
mapinfo mapinfo add symbol 170 240 0
mapinfo mapinfo add symbol 550 200 0

#--------------------------------
# Waypoints names
#--------------------------------
mapinfo mapinfo add text normal simple 170 100 DO
mapinfo mapinfo add text normal simple 270 160 RE
mapinfo mapinfo add text normal simple 410 50 MI
mapinfo mapinfo add text normal simple 345 470 FA
mapinfo mapinfo add text normal simple 280 265 SOL
mapinfo mapinfo add text normal simple 150 240 LA
mapinfo mapinfo add text normal simple 555 200 SI

#--------------------------------
# Routes
#--------------------------------

mapinfo mapinfo add line simple 1 200 100 300 150
mapinfo mapinfo add line simple 1 300 150 400 50
mapinfo mapinfo add line simple 1 300 150 350 450
mapinfo mapinfo add line simple 1 300 250 170 240
mapinfo mapinfo add line simple 1 300 250 550 200

#--------------------------------
# Sectors
#---------------------------------
mapinfo mapinfo add line simple 1 300 0 400 50
mapinfo mapinfo add line simple 1 400 50 500 100
mapinfo mapinfo add line simple 1 500 100 550 200
mapinfo mapinfo add line simple 1 550 200 550 400
mapinfo mapinfo add line simple 1 550 400 350 450
mapinfo mapinfo add line simple 1 350 450 170 240
mapinfo mapinfo add line simple 1 170 240 200 100
mapinfo mapinfo add line simple 1 200 100 300 0

#--------------------------------
# Sectors
#---------------------------------
set gpe [$w.zinc add group 1]
set map [$w.zinc add map $gpe -mapinfo mapinfo -symbols AtcSymbol15]


###################################################
# control panel
###################################################
frame $w.rc
pack $w.rc

#the reference of the scale function is top-left corner of the zinc object
#so we first translate the group to zoom in order to put its center on top-left corner
#change the scale of the group
#translate the group to put it back at the center of the zinc object 


button $w.rc.minus -width 2 -height 2 -text {-} -command {
    $w.zinc translate $gpe [expr -$zinc_width/2] [expr -$zinc_height/2]
    $w.zinc scale $gpe 0.8 0.8
    $w.zinc translate $gpe [expr $zinc_width/2] [expr $zinc_height/2]
}
pack $w.rc.minus -side left

button $w.rc.plus -width 2 -height 2 -text {+} -command {
    $w.zinc translate $gpe [expr -$zinc_width/2] [expr -$zinc_height/2]
    $w.zinc scale $gpe 1.2 1.2
    $w.zinc translate $gpe [expr $zinc_width/2] [expr $zinc_height/2]
}
pack $w.rc.plus -side right


