# these simple samples have been developped by C. Mertz mertz@cena.fr in perl
# tcl version by Jean-Paul Imbert imbert@cena.fr


if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}

#
# We need the text input support
package require zincText


set w .textInput
catch {destroy $w}
toplevel $w
wm title $w "Zinc textInput Demonstration"
wm iconname $w textInput

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

text $w.text -relief sunken -borderwidth 2 -height 5
pack $w.text -expand yes -fill both

$w.text insert end {This demo demonstrates the use of the zincText package.
This module is designed for facilitating text input.
It works on text items or on fields of items such as
tracks, waypoints or tabulars.}


###########################################
# Zinc
##########################################
zinc $w.zinc -width 500 -height 300 -font 10x20 -borderwidth 0
pack $w.zinc

#
# Activate text input support from zincText
zn_TextBindings $w.zinc

### creating a tabular with 3 fields 2 of them being editable
set labelformat1 {130x100 x130x20+0+0 x130x20+0+20 x130x20+0+40}

set x 120
set y 6
set track [$w.zinc add track 1 3 -position "$x $y" -speedvector {40 10} -labeldistance 30 -labelformat $labelformat1 -tags text]

# moving the track to display past positions
for {set i 0} {$i<=5} {incr i} { 
    $w.zinc coords "$track" "[expr $x+$i*10] [expr $y+$i*2]" 
}

$w.zinc itemconfigure $track 0 -border contour -text {not editable} -sensitive 0

$w.zinc itemconfigure $track 1 -border contour -text editable -sensitive 1

$w.zinc itemconfigure $track 2 -border contour -text {editable too} -alignment center -sensitive 1


# creating a text item tagged with "text" but not editable because
# it is not sensitive
$w.zinc add text 1 -position {220 160} -text "this text is not editable \nbecause it is not sensitive" -sensitive 0 -tags text


# creating an editable text item
$w.zinc add text 1 -position {50 230} -text {this text IS editable} -sensitive 1 -tags text
