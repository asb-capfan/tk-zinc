# these simple samples have been developped by C. Mertz mertz@cena.fr in perl
# tcl version by Jean-Paul Imbert imbert@cena.fr

if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}

set w .clipping
catch {destroy $w}
toplevel $w
wm title $w "Zinc Clipping Demonstration"
wm iconname $w "Clipping"

set defaultfont [font create -family Helvetica -size 10 -weight bold]

frame $w.buttons
pack $w.buttons -side bottom -fill x -pady 2m
button $w.buttons.dismiss -text Dismiss -command "destroy $w"
button $w.buttons.code -text "See Code" -command "showCode $w"
pack $w.buttons.dismiss $w.buttons.code -side left -expand 1


zinc $w.zinc -width 700 -height 600 -font 10x20 -borderwidth 3 -relief sunken
pack $w.zinc

set display_clipping_item_background   0
set clip   1

$w.zinc add text 1 -font $defaultfont -text "You can drag and drop the objects.\nThere are two groups of objects a tan group and a blue group\nTry to move them and discover the clipping area which is a curve.\nwith two contours" -anchor nw -position {10 10}


set clipped_group [$w.zinc add group 1 -visible 1]

set clipping_item  [$w.zinc add curve $clipped_group {10 100 690 100 690 590 520 350 350 590 180 350 10 590} -closed 1 -priority 1 -fillcolor tan2 -linewidth 0 -filled $display_clipping_item_background]
$w.zinc contour $clipping_item add +1 {200 200 500 200 500 250 200 250}

############### creating the tan_group objects ################
# the tan_group is atomic  that is is makes all children as a single object
# and sensitive to tan_group callbacks
set tan_group [$w.zinc add group $clipped_group -visible 1 -atomic 1 -sensitive 1]
			   

$w.zinc add arc $tan_group {200 220 280 300} -filled 1 -linewidth 1 -startangle 45 -extent 270 -pieslice 1 -closed 1 -fillcolor tan
	   

$w.zinc add curve $tan_group {400 400 440 450 400 500 500 500 460 450 500 400} -filled 1 -fillcolor tan -linecolor tan
	   

############### creating the blue_group objects ################
# the blue_group is atomic too  that is is makes all children as a single object
# and sensitive to blue_group callbacks
set blue_group   [$w.zinc add group $clipped_group -visible 1 -atomic 1 -sensitive 1]

$w.zinc add rectangle $blue_group {570 180   470 280} -filled 1 -linewidth 1 -fillcolor blue2

$w.zinc add curve $blue_group {200 400 200 500 300 500 300 400 300 300} -filled 1 -fillcolor blue -linewidth 0


$w.zinc itemconfigure $clipped_group -clip  $clipping_item


###################### drag and drop callbacks ############
# for both tan_group and blue_group

$w.zinc bind $tan_group <1> "itemStartDrag $tan_group %x %y" 
$w.zinc bind $tan_group <B1-Motion> "itemDrag $tan_group %x %y"
$w.zinc bind $blue_group <1> "itemStartDrag $blue_group %x %y" 
$w.zinc bind $blue_group <B1-Motion> "itemDrag $blue_group %x %y"



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
    $w.zinc translate $item  [expr $x-$x_orig] [expr $y-$y_orig];
    set x_orig  $x;
    set y_orig  $y;
}



###################### toggle buttons at the bottom #######
frame $w.row
pack $w.row
checkbutton $w.row.show -text "Show clipping item" -variable display_clipping_item_background -command "display_clipping_area"
checkbutton $w.row.clip -text Clip -variable clip -command "clipcommand "
pack $w.row.show $w.row.clip

proc display_clipping_area {} {
    global clipping_item
    global w
    global display_clipping_item_background
    $w.zinc itemconfigure $clipping_item -filled  $display_clipping_item_background
}

proc clipcommand {} {
    global clip
    global clipped_group
    global clipping_item
    global w

    if {$clip} {
	$w.zinc itemconfigure $clipped_group -clip  $clipping_item
    } else {
	$w.zinc itemconfigure $clipped_group -clip ""
    }
}
