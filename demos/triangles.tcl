# these simple samples have been developped by C. Mertz mertz@cena.fr and N. Banoun banoun@cena.fr
# tcl version by Jean-Paul Imbert imbert@cena.fr

if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}

set w .triangles
catch {destroy $w}
toplevel $w
wm title $w "Zinc Triangles Demonstration"
wm iconname $w Triangles

frame $w.buttons
pack $w.buttons -side bottom -fill x -pady 2m
button $w.buttons.dismiss -text Dismiss -command "destroy $w"
button $w.buttons.code -text "See Code" -command "showCode $w"
pack $w.buttons.dismiss $w.buttons.code -side left -expand 1


set defaultfont [font create -family Helvetica -size 10 -weight bold]

zinc $w.zinc -width 700 -height 300 -font 10x20 -render 1 -borderwidth 3 -relief sunken 
pack $w.zinc

# 6 equilateral triangles around a point 
$w.zinc add text 1 -position {5 10} -text "Triangles item without transparency"

set x0 200 
set y0 150
set coords [list "$x0 $y0"]
for {set i 0} {$i<=6} {incr i} {
    set angle [expr $i * 6.28/6]
    lappend coords "[expr $x0 + 100 * cos($angle)] [expr $y0 - 100 * sin ($angle)]"
}

set tr1 [$w.zinc add triangles 1 $coords -fan 1 -colors {white yellow magenta blue cyan green red yellow} -visible 1]


$w.zinc add text 1 -position {370 10} -text "Triangles item with transparency"


# using the clone method to make a copy and then modify the clone"colors
set tr2 [$w.zinc clone $tr1]
$w.zinc translate $tr2 300 0
$w.zinc itemconfigure $tr2 -colors {white;50 yellow;50 magenta;50 blue;50 cyan;50 green;50 red;50 yellow;50}
