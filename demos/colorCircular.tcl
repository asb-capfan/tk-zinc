# these simple samples have been developped by C. Mertz mertz@cena.fr in perl
# tcl version by Jean-Paul Imbert imbert@cena.fr

if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}

set w .colorCircular
catch {destroy $w}
toplevel $w
wm title $w "Zinc Color Circular Demonstration"
wm iconname $w "Color Circular"

frame $w.buttons
pack $w.buttons -side bottom -fill x -pady 2m
button $w.buttons.dismiss -text Dismiss -command "destroy $w"
button $w.buttons.code -text "See Code" -command "showCode $w"
pack $w.buttons.dismiss $w.buttons.code -side left -expand 1

set defaultfont [font create -family Helvetica -size 10 -weight bold]

zinc $w.zinc -width 700 -height 600 -borderwidth 3 -relief sunken -render 1
pack $w.zinc

$w.zinc add rectangle 1 {10 10 80 80} -fillcolor {=radial 50 50|red|blue} -filled 1
$w.zinc add text 1 -font $defaultfont -text {Radial variation from non-transparent red to non-transparent blue in a square.
The gradient starts in the lower right corner.} -anchor nw -position {120 20}

$w.zinc add arc 1 {10 110 90 190} -fillcolor {=radial 0 25|red;40|blue;40} -filled 1

$w.zinc add text 1 -font $defaultfont -text {Radial variation from 40% transparent red to 40% transparent blue in a disc.
The gradient starts mid way between the center and the bottom.} \
    -anchor nw -position {120 120}

$w.zinc add arc 1 {10 210 90 290} -fillcolor {=radial 0 0|red;40|green;40 50|blue;40} -filled 1

$w.zinc add text 1 -font $defaultfont -text {A variation from 40% transparent red to 40% transparent blue
through 40% green in the middle of the disc. The gradient is centered.} \
    -anchor nw -position {120 220}

$w.zinc add text 1 -font $defaultfont -text {Two overlapping items filled by a transparent radial gradient on a white background.
On the right three gradient filled ovals, note the warped gradients following the ovals.} -anchor w -position {20 320}

$w.zinc add rectangle 1 {10 340 690 590} -fillcolor white -filled  1 

$w.zinc add rectangle 1 {20 365 220 565} -fillcolor {=radial 0 0|red;40|green;40 50|blue;40} -filled 1

$w.zinc add arc 1 {150 365 350 565} -fillcolor {=radial 0 0|yellow;40|black;40 50|cyan;40} -filled 1

$w.zinc add arc 1 {280 365 480 565} -fillcolor {=radial 0 0|black;100|black;100 20|mistyrose;40} -filled 1 -linewidth 0

set warc [$w.zinc add arc 1 {-50 -50 50 50} \
	      -fillcolor {=radial -10 16|black;80|blue;20 90 100} -filled 1]
$w.zinc scale $warc 1.5 1
$w.zinc translate $warc 500 432

set warc [$w.zinc add arc 1 {-50 -50 50 50} \
	      -fillcolor {=radial 0 20|black;70|green;20} -filled 1]
$w.zinc scale $warc 1 1.5
$w.zinc translate $warc 630 432
