# these simple samples have been developped by C. Mertz mertz@cena.fr in perl
# tcl version by Jean-Paul Imbert imbert@cena.fr

if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}

set w .contours
catch {destroy $w}
toplevel $w
wm title $w "Zinc Curve contours Demonstration"
wm iconname $w Curve
frame $w.buttons

pack $w.buttons -side bottom -fill x -pady 2m
button $w.buttons.dismiss -text Dismiss -command "destroy $w"
button $w.buttons.code -text "See Code" -command "showCode $w"
pack $w.buttons.dismiss $w.buttons.code -side left -expand 1

# The explanation displayed when running this demo
text  $w.text -relief sunken -borderwidth 2 -setgrid true -height 9
pack $w.text -expand yes -fill both

$w.text insert end "All visibles items are made by combining 2 items using contours:
 - the firebrick curve1 has been holed using a addhole with a circle,
 - the lightblue curve2 has been mickey-moused by adding two circles,
 - the yellow curve3 is the union with a disjoint circle,
 - the grey curve4 is combined with 7 circles, with positive -fillrule.
The following operations are possible:
 - Mouse Button 1 for dragging objects.
 - Mouse Button 1 for dragging the black handle and
    modifying the grey curve contour."

# Creating the zinc widget
zinc $w.zinc -width 600 -height 500 -font 10x20 -borderwidth 3 -relief sunken
pack $w.zinc
set top 1

# Creation of 2 items NOT visible, but used for creating visible
# curves[1-5] with more than one contours.
# The center of these 2 items is 200,100

set curve0 [$w.zinc add curve $top {
    {300 0} {400 100 c} {300 200} {200 300 c} {100 200} {0 100 c} {100 0}
} -closed 1 -visible 0 -filled 1]
set cercle100  [$w.zinc add arc 1 {130 30 280 180} -visible 0]
			  

# cloning curve0 as curve1 and moving it
set  curve1 [$w.zinc clone $curve0 -visible 1 -fillcolor firebrick1]
# adding a 'difference' contour to the curve1
$w.zinc contour $curve1 add 1 $cercle100


# cloning curve0 as curve2 and moving it
# creating a curve without contour to control contour clockwise/counterclockwise
set curve2 [$w.zinc add curve $top {} -closed 1 -filled 1 \
		-fillcolor lightblue2 -fillrule positive]
$w.zinc contour $curve2 add +1 $curve0 
$w.zinc translate $curve2 100 90

# adding the left ear of mickey mouse!
$w.zinc contour $curve2 add +1 $cercle100
$w.zinc translate $curve2 -200 0

# adding the right ear of mickey mouse!
$w.zinc contour $curve2 add +1 $cercle100

# ... translate to make it more visible
$w.zinc translate $curve2 320 20

# cloning curve0 as curve3 and moving it
set curve3  [$w.zinc clone $curve0 -visible 1 -fillcolor yellow3]
$w.zinc translate $curve3 0 290

# adding an  nion' contour to the curve3
$w.zinc contour $curve3 add +1 $cercle100
# ... translate to make it more visible
$w.zinc translate $curve3 -130 0

    


# cloning curve0 as curve4 and moving it slightly
set curve4 [$w.zinc clone $curve0 -visible 1 -fillcolor grey50 \
		-tags grouped -fillrule positive]
# the tag "grouped" is used for both curve4 and
# a handle (see just below)
# It is used for translating both easily


set index  2; ## index of the vertex associated to the handle
set coord  [$w.zinc coords $curve4 0 $index]
set x [lindex $coord 0]
set y [lindex $coord 1]
set handle [$w.zinc add rectangle $top "[expr $x-5] [expr $y-5] [expr $x+5] [expr $y+5]" \
		-fillcolor black -filled 1 -tags {grouped}]
			

# adding a 'difference' contour to the curve4
$w.zinc contour $curve4 add +1 $cercle100
$w.zinc translate grouped 110 0
$w.zinc contour $curve4 add +1 $cercle100
$w.zinc translate grouped -220 0
$w.zinc contour $curve4 add +1 $cercle100
$w.zinc translate grouped 10 80
$w.zinc contour $curve4 add -1 $cercle100
$w.zinc translate grouped 0 -10
$w.zinc contour $curve4 add +1 $cercle100

$w.zinc translate grouped 200 80
$w.zinc contour $curve4  add +1 $cercle100
$w.zinc translate grouped -350 0
$w.zinc contour $curve4 add +1 $cercle100

$w.zinc translate grouped 350 250
#$zinc->lower(grouped);

# Deleting no more usefull items: curve0 and cercle10:
$w.zinc remove $curve0 $cercle100

$w.zinc raise $curve1

# adding drag and drop callback to each visible curve!
foreach item "$curve1 $curve2 $curve3 $curve4" {
    # Some bindings for dragging the items
    $w.zinc bind $item <ButtonPress-1> "press $item motion %x %y" 
    $w.zinc bind $item <ButtonRelease-1> release
}

# adding drag and drop on curve4 which also moves handle
$w.zinc bind $curve4  <ButtonPress-1> "press $curve4 motionWithHandle %x %y"
$w.zinc bind $curve4, <ButtonRelease-1> release

# adding drag and drop on handle which also modify curve4
$w.zinc bind $handle  <ButtonPress-1> "press $handle moveHandle %x %y"
$w.zinc bind $handle  <ButtonRelease-1> release

# callback for starting a drag
set xOrig 0
set yOrig 0

proc press {item action x y} {
    global w xOrig yOrig

    set xOrig $x
    set yOrig $y
    bind $w.zinc <Motion> "$action $item %x %y"
}

# Callback for moving an item
proc motion {item x y} {
    global w xOrig yOrig

    $w.zinc translate $item [expr $x - $xOrig] [expr $y - $yOrig]
    set xOrig $x
    set yOrig $y
}

# Callback for moving an item and its handle
proc motionWithHandle {item x y} {
    global w xOrig yOrig

    set tag [lindex [$w.zinc itemcget $item -tags] 0]
    $w.zinc translate $tag  [expr $x-$xOrig] [expr $y-$yOrig]
    set xOrig $x;
    set yOrig $y;
}

# Callback for moving the handle and modifying curve4
# this code is far from being generic. Only for demonstrating how we can
# modify a contour with a unique handle!
proc moveHandle {handle x y} {
    global w xOrig yOrig curve4 index

    $w.zinc translate $handle  [expr $x - $xOrig] [expr $y - $yOrig];

    foreach {vertxX vertxY} [$w.zinc coords $curve4 0 $index] break
    $w.zinc coords $curve4 0 $index "[expr $vertxX+($x-$xOrig)] [expr $vertxY+($y-$yOrig)]"
    set xOrig $x
    set yOrig $y
}


proc release {} {
    global w

    bind $w.zinc <Motion> {}
}
