# these simple samples have been developped by C. Mertz mertz@cena.fr in perl
# tcl version by Jean-Paul Imbert imbert@cena.fr

if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}

set w .labelformat
catch {destroy $w}
toplevel $w
wm title $w "Zinc Label Format Demonstration"
wm iconname $w Label

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

$w.text insert end {This scipt demonstrates the use of labelformat for tabular items.
The fieldPos (please, refer to the labelformat type description
in the Zinc reference manual) of each field as described in
the labelformat is displayed inside the field.}


###########################################
# Zinc
##########################################
zinc $w.zinc -width 600 -height 500 -font 10x20 -borderwidth 3 -relief sunken
pack $w.zinc

### this function displays in each field, the corresponding <fieldPos>
### part of the labelformat
proc setLabelContent {item labelformat} {
    global w
    set i 0
    foreach fieldSpec $labelformat {
	set posSpec $i
	regexp {^.\d+.\d+(.*)} $fieldSpec "" posSpec
	$w.zinc itemconfigure $item $i -text "$i: $posSpec" -border "contour"
	incr i
    }
}

###########################################
# Tabulars
###########################################

### first labelformat and tabular
set labelformat1 {x100x20+0+0 x100x20+100+0 x100x20+0+20 x100x20+100+20 x100x20+50+55}

set tabular1 [$w.zinc add tabular 1 5 -position {10 10} -labelformat $labelformat1]

setLabelContent $tabular1 $labelformat1

$w.zinc add text 1 -position {10 100} -text "All fields positions\nare given in pixels"


### second labelformat and tabular
set labelformat2 {x110x20+100+30 x80x20<0<0 x80x20<0>0 x80x20>0>0 x80x20>0<0}

set tabular2 [$w.zinc add tabular 1 5 -position {270 10} -labelformat $labelformat2]
setLabelContent $tabular2 $labelformat2

$w.zinc add text 1 -position {260 100} -text "All fields positions are given\nrelatively to field 0.\nThey are either on the left/right\nand up/down the field 0."


### third labelformat and tabular
set labelformat3 {x200x70+100+70 x80x26^0<0 x80x26^0>0 x80x29$0$0 x80x32$0^0 x90x20<1^1 x90x20<2$2 x90x20^4<4 x90x20^3>3}

set tabular3 [$w.zinc add tabular 1 9 -position {150 180} -labelformat $labelformat3]

setLabelContent $tabular3 $labelformat3

$w.zinc add text 1 -position {40 360} -text "Fields 1-4 are positionned relatively to field 0.\nField 5 is positionned relatively to field 1\nField 6 is positionned relatively to field 2..."
