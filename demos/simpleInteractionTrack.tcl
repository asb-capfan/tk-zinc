# these simple samples have been developped by C. Mertz mertz@cena.fr in perl
# tcl version by Jean-Paul Imbert imbert@cena.fr

if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}


set w .simpleInteractionTrack
catch {destroy $w}
toplevel $w
wm title $w "Zinc Track Interaction Demonstration"
wm iconname $w TrackInteraction

set defaultfont [font create -family Helvetica -size 10 -weight bold]

frame $w.buttons
pack $w.buttons -side bottom -fill x -pady 2m
button $w.buttons.dismiss -text Dismiss -command "destroy $w"
button $w.buttons.code -text "See Code" -command "showCode $w"
pack $w.buttons.dismiss $w.buttons.code -side left -expand 1

###########################################
# Zinc
###########################################
zinc $w.zinc -width 600 -height 500 -font 10x20 -borderwidth 0
pack $w.zinc


# The explanation displayed when running this demo
$w.zinc add text 1 -position {10 10} -text {This toy-appli shows some interactions on different parts of a flight track item.
    The following operations are possible:
    - Drag Button 1 on the track to move it.
    Please Note the position history past positions
    - Enter/Leave flight label fields
    - Enter/Leave the speedvector symbol i.e. current position label leader} -font 9x15


###########################################
# Track
###########################################

#the label format 6 formats for 6 fields#
set labelformat {x80x60+0+0 x60a0^0^0 x30a0^0>1 a0a0>2>1 x30a0>3>1 a0a0^0>2}

#the track#
set x 250
set y 200
set track [$w.zinc add track 1 6 -labelformat $labelformat -position "$x $y" -speedvector {30 -15} -markersize 10]

# moving the track to display past positions
for {set i 0} {$i<=5} {incr i} { 
    $w.zinc coords "$track" "[expr $x+$i*10] [expr $y-$i*5]" 
}

#fields of the label#
$w.zinc itemconfigure $track 0 -filled 0 -bordercolor DarkGreen -border contour
$w.zinc itemconfigure $track 1 -filled 1 -backcolor gray60 -text AFR6128

$w.zinc itemconfigure $track 2 -filled 0 -backcolor gray65 -text 390

$w.zinc itemconfigure $track 3 -filled 0 -backcolor gray65 -text /

$w.zinc itemconfigure $track 4 -filled 0 -backcolor gray65 -text 350

$w.zinc itemconfigure $track 5 -filled 0 -backcolor gray65 -text TUR



###########################################
# Events on the track
###########################################
#---------------------------------------------
# Enter/Leave a field of the label of the track
#---------------------------------------------

for {set field 0} {$field<=5} {incr field} { 
    #Entering the field $field higlights it#
    $w.zinc bind "$track:$field" "<Enter>" "highlight_enter $field"
    #Leaving the field cancels the highlight of $field#
    $w.zinc bind "$track:$field" "<Leave>" "highlight_leave $field"
}

proc highlight_enter {field} {
    if {$field ==0} { 
	higlight_label_on 
    } else {
	highlight_fields_on $field
    }
    
}
proc highlight_leave {field} {
    if {$field==0} {
	higlight_label_off 
    } else {
	if {$field==1} {
	    highlight_field1_off 
	} else {
	    highlight_other_fields_off $field
	}
    }
}

#fonction#
proc higlight_label_on {} {
    global w
    $w.zinc itemconfigure current 0 -filled 0 -bordercolor red -border contour
}

proc higlight_label_off {} {
    global w
    $w.zinc itemconfigure current 0 -filled 0 -bordercolor DarkGreen -border contour
}

proc highlight_fields_on {field} {
    global w
    $w.zinc itemconfigure current $field -border contour -filled 1 -color white
}

proc highlight_field1_off {} {
    global w
    $w.zinc itemconfigure current 1 -border "" -filled 1 -color black -backcolor gray60
}

proc highlight_other_fields_off {field} {
    global w
    $w.zinc itemconfigure current $field -border "" -filled 0 -color black -backcolor gray65
}

#---------------------------------------------
# Enter/Leave other parts of the track
#---------------------------------------------
$w.zinc bind "$track:position" <Enter> {$w.zinc itemconfigure "$track" -symbolcolor red}
$w.zinc bind "$track:position" <Leave> {$w.zinc itemconfigure "$track" -symbolcolor black }
$w.zinc bind "$track:speedvector" <Enter> {$w.zinc itemconfigure "$track" -speedvectorcolor red }
$w.zinc bind "$track:speedvector" <Leave> {$w.zinc itemconfigure "$track" -speedvectorcolor black }
$w.zinc bind "$track:leader" <Enter> {$w.zinc itemconfigure "$track" -leadercolor red }
$w.zinc bind "$track:leader" <Leave> {$w.zinc itemconfigure "$track" -leadercolor black }

#---------------------------------------------
# Drag and drop the track
#---------------------------------------------
#Binding to ButtonPress event -> "move_on" state#
$w.zinc bind "$track" <1> { 
    select_color_on
    move_on %x %y
}



#"move_on" state#
proc move_on {x y} {
    global track w
    global xi yi

    set xi $x
    set yi $y

    #ButtonPress event not allowed on track
    $w.zinc bind "$track" <ButtonPress-1> ""
    #Binding to Motion event -> move the track#
    $w.zinc bind "$track" <Motion> "bind_motion %x %y" 

    #Binding to ButtonRelease event -> "move_off" state#
    $w.zinc bind "$track" <ButtonRelease-1> {
	select_color_off 
	move_off 
    } 
}

proc bind_motion { x y} {
    global xi yi

    move $xi $yi $x $y

    set xi $x
    set yi $y
}

#"move_off" state#
proc move_off {} {
    global track w
    #Binding to ButtonPress event -> "move_on" state#
    $w.zinc bind "$track" <ButtonPress-1> { 
	select_color_on
	move_on %x %y 
    }

    
    #Motion event not allowed on track
    $w.zinc bind "$track" <Motion> "" 
    #ButtonRelease event not allowed on track
    $w.zinc bind "$track" <ButtonRelease-1> ""
}

#move the track#
proc move {xi yi x y} {
    global w
    global track
    select_color_on 
    set coords [$w.zinc coords "$track"]
    set X1 [lindex [lindex $coords 0] 0]
    set Y1 [lindex [lindex $coords 0] 1]
    $w.zinc coords "$track" "[expr $X1+$x-$xi] [expr $Y1+$y-$yi]"
}


proc select_color_on {} {
    global track w
    $w.zinc itemconfigure "$track" -speedvectorcolor white -markercolor white -leadercolor white
}

proc select_color_off {} {
    global track w
    $w.zinc itemconfigure "$track" -speedvectorcolor black -markercolor black -leadercolor black
}
