# these simple samples have been developped by C. Mertz mertz@cena.fr in perl
# tcl version by Jean-Paul Imbert imbert@cena.fr

if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}

set w .colorX
catch {destroy $w}
toplevel $w
wm title $w "Zinc Color-x Demonstration"
wm iconname $w "Color X"

frame $w.buttons
pack $w.buttons -side bottom -fill x -pady 2m
button $w.buttons.dismiss -text Dismiss -command "destroy $w"
button $w.buttons.code -text "See Code" -command "showCode $w"
pack $w.buttons.dismiss $w.buttons.code -side left -expand 1

set defaultfont [font create -family Helvetica -size 10 -weight bold]

zinc  $w.zinc -width 700 -height 600 -borderwidth 3 -relief sunken -render 1 
pack $w.zinc

$w.zinc add rectangle 1 {10 10 690 100} -fillcolor {red|blue} -filled 1

$w.zinc add text 1 -font $defaultfont -text "A variation from non transparent red to non transparent blue.\n" -anchor nw -position {20 20}

$w.zinc add rectangle 1 {10 110 690 200} -fillcolor {red;40|blue;40} -filled 1

$w.zinc add text 1 -font $defaultfont -text "A variation from 40%transparent red to 40% transparent blue." -anchor nw -position {20 120}

$w.zinc add rectangle 1 {10 210 690 300} -fillcolor {red;40|green;40 50|blue;40} -filled 1

$w.zinc add text 1 -font $defaultfont -text "A variation from 40%transparent red to 40% transparent blue.\nthrough a 40%green on the middle" -anchor nw -position {20 220}

$w.zinc add text 1 -font $defaultfont -text "Two overlaping transparently colored rectangles on a white background" -anchor nw -position {20 320}

$w.zinc add rectangle 1 {10 340 690 590} -fillcolor white -filled 1
$w.zinc add rectangle 1 {200 350 500 580} -fillcolor {red;40|green;40 50|blue;40} -filled 1

$w.zinc add rectangle 1 {10 400 690 500} -fillcolor {yellow;40|black;40 50|cyan;40} -filled 1
