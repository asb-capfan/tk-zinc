# these simple samples have been developped by C. Mertz mertz@cena.fr in perl
# tcl version by Jean-Paul Imbert imbert@cena.fr

if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}

set w .windowContours
catch {destroy $w}
toplevel $w
wm title $w "Zinc Contours Demonstration"
wm iconname $w Contours

set defaultfont [font create -family Helvetica -size 10 -weight bold]

frame $w.buttons
pack $w.buttons -side bottom -fill x -pady 2m
button $w.buttons.dismiss -text Dismiss -command "destroy $w"
button $w.buttons.code -text "See Code" -command "showCode $w"
pack $w.buttons.dismiss $w.buttons.code -side left -expand 1

# Creating the zinc widget
zinc $w.zinc -width 600 -height 500 -font 9x15 -borderwidth 3 -relief sunken
pack $w.zinc

# The explanation displayed when running this demo
$w.zinc add text 1 -position {10 10} -text "These windows are simply rectangles holed by 4 smaller\nrectangles. The text appears behind the window glasses.\nYou can drag text or windows" -font 10x20


# Text in background
set backtext [$w.zinc add text 1 -position {50 200} -text "This text appears\nthrough holes of curves" -font "-adobe-helvetica-bold-o-normal--34-240-100-100-p-182-iso8859-1"]

set window [$w.zinc add curve 1 {100 100 300 100 300 400 100 400} -closed 1 -visible 1 -filled 1 -fillcolor grey66]


set aGlass [$w.zinc add rectangle 1 {120 120 190 240}]
$w.zinc contour $window add +1 $aGlass

$w.zinc translate $aGlass 90 0
$w.zinc contour $window add +1 $aGlass

$w.zinc translate $aGlass 0 140
$w.zinc contour $window add +1 $aGlass

$w.zinc translate $aGlass -90 0
$w.zinc contour $window add +1 $aGlass


# deleting $aGlass which is no more usefull
$w.zinc remove $aGlass

# cloning $window
set window2 [$w.zinc clone $window]

# changing its background moving it and scaling it!
$w.zinc itemconfigure $window2 -fillcolor grey50
$w.zinc translate $window2 30 50
$w.zinc scale $window 0.8 0.8




# adding drag and drop callback to the two windows and backtext
foreach item "$window $window2 $backtext" {
    # Some bindings for dragging the items
    $w.zinc bind $item <1> "itemStartDrag $item %x %y" 
    $w.zinc bind $item <B1-Motion> "itemDrag $item %x %y"
}

# callback for starting a drag
set x_orig ""
set y_orig ""

proc itemStartDrag {item x y} {
    global x_orig y_orig
    set x_orig $x
    set y_orig $y
}

# Callback for moving an item
proc itemDrag {item x y} {
    global x_orig y_orig
    global w
    $w.zinc translate $item [expr $x-$x_orig] [expr $y-$y_orig];
    set x_orig $x;
    set y_orig $y;
}


