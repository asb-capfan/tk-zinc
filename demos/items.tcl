# $Id: items.tcl,v 1.2 2003/04/16 09:42:57 lecoanet Exp $
# tcl version by Jean-Paul Imbert imbert@cena.fr

if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}

set w .items
catch {destroy $w}
toplevel $w
wm title $w "Zinc Item Demonstration"
wm iconname $w Items

set defaultfont [font create -family Helvetica -size 10 -weight bold]

frame $w.buttons
grid $w.buttons -row 4 -column 1 -columnspan 2 -sticky we -pady 2m
button $w.buttons.dismiss -text Dismiss -command "destroy $w"
button $w.buttons.code -text "See Code" -command "showCode $w"
pack $w.buttons.dismiss $w.buttons.code -side left -expand 1

scrollbar $w.vscroll -command "$w.zinc yview"
grid $w.vscroll -row 2 -column 2 -sticky ns
scrollbar $w.hscroll -orient horiz -command "$w.zinc xview"
grid $w.hscroll -row 3 -column 1 -sticky we

zinc $w.zinc -width 700 -height 600 -scrollregion {-100 0 1000 1000} \
    -xscrollcommand "$w.hscroll set" \
    -yscrollcommand "$w.vscroll set" \
    -font 10x20 -borderwidth 3 -relief sunken
grid $w.zinc -row 2 -column 1 -sticky news

$w.zinc add rectangle 1 {10 10 100 50} -fillcolor green -filled 1 -linewidth 10 \
    -relief roundridge -linecolor darkgreen


$w.zinc add text 1 -font $defaultfont -anchor nw -position {120 20} \
    -text {A filled rectangle with a "roundridge" relief border of 10 pixels.}

set labelformat {x82x60+0+0 x60a0^0^0 x32a0^0>1 a0a0>2>1 x32a0>3>1 a0a0^0>2};

set x 20;
set y 120;
set track [$w.zinc add track 1 6 -labelformat $labelformat -position "$x $y" \
	       -speedvector {40 -10} -speedvectormark 1 -speedvectorticks 1]

# moving the track, to display past positions
for {set i 0} {$i<=5} {incr i} { 
    set x1 [expr $x+$i*10]
    set y1 [expr $y-$i*2]
    $w.zinc coords "$track" "$x1 $y1" 
}

$w.zinc add text 1 -font $defaultfont -anchor nw -position {200 80} \
    -text {A flight track for a radar display. A waypoint looks similar,
but has no speed vector and no past positions.}

$w.zinc itemconfigure $track 0 -filled 0 -bordercolor DarkGreen -border contour

$w.zinc itemconfigure $track 1 -filled 1 -backcolor gray60 -text AFR001
$w.zinc itemconfigure $track 2 -filled 0 -backcolor gray65 -text 360
$w.zinc itemconfigure $track 3 -filled 0 -backcolor gray65 -text /
$w.zinc itemconfigure $track 4 -filled 0 -backcolor gray65 -text 410
$w.zinc itemconfigure $track 5 -filled 0 -backcolor gray65 -text Beacon


$w.zinc add arc 1 {150 140 450 240} -fillcolor gray20 -filled 0 -linewidth 1 \
    -startangle 45 -extent 270
$w.zinc add arc 1 {260 150 340 230} -fillcolor gray20 -filled 0 -linewidth 1 \
    -startangle 45 -extent 270 -pieslice 1 -closed 1 -linestyle mixed -linewidth 3

$w.zinc add text 1 -font $defaultfont -anchor nw -position {320 180} \
    -text {Two arcs, starting at 45° with an extent of 270°}


$w.zinc add curve 1 {10 324 24 300 45 432 247 356 128 401} -filled 0 -relief roundgroove
# -linewidth 10, ## BUG with zinc 3.2.3g 

$w.zinc add text 1 -font $defaultfont -text {An open curve} -anchor nw -position {50 350}

$w.zinc add text 1 -font $defaultfont -text {A waypoint} -anchor nw -position {10 480}

set waypoint [$w.zinc add waypoint 1 6 -position {100 520} -labelformat $labelformat \
		  -symbol AtcSymbol2 -labeldistance 30] 

for {set fieldId 1} {$fieldId<=5} {incr fieldId} {
    $w.zinc itemconfigure $waypoint $fieldId -filled 0 -bordercolor DarkGreen \
	-border contour -text "field$fieldId"
}


$w.zinc add text 1 -font $defaultfont -anchor nw -position {510 380} \
    -text {3 tabulars of 2 fields,
attached together.}

set labelformat2 {x72x40 x72a0^0^0 x34a0^0>1}

set tabular1 [$w.zinc add tabular 1 6 -position {570 250} -labelformat $labelformat2]
set tabular2 [$w.zinc add tabular 1 6 -connecteditem $tabular1 -labelformat $labelformat2]
set tabular3 [$w.zinc add tabular 1 6 -connecteditem $tabular2 -labelformat $labelformat2]

set count 1

foreach tab "$tabular1 $tabular2 $tabular3" {
    $w.zinc itemconfigure $tab 1 -filled 0 -bordercolor DarkGreen -border contour -text tabular
    $w.zinc itemconfigure $tab 2 -filled 0 -bordercolor DarkGreen -border contour -text "n°$count"
    incr count
}


$w.zinc add reticle 1 -position {530 550} -firstradius 20 -numcircles 6 \
    -period 2 -stepsize 20 -brightlinestyle dashed -brightlinecolor darkred

$w.zinc add text 1 -font $defaultfont -text {a reticle with 6 circles} \
    -anchor nw -position {530 540}

bind $w.zinc <ButtonPress-1> "press $w.zinc motion %x %y"
bind $w.zinc <ButtonRelease-1> "release $w.zinc"

proc press {z action x y} {
    global curX curY

    set curX $x
    set curY $y
    bind $z <Motion> "$action $z %x %y"
}

proc motion {z x y} {
    global curX curY

    $z translate current [expr $x - $curX] [expr $y - $curY]
    set curX $x
    set curY $y
}

proc release {z} {
    bind $z <Motion> {}
}
