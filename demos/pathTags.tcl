#
# these simple samples have been developped by C. Mertz mertz@cena.fr in perl
# tcl version by Jean-Paul Imbert imbert@cena.fr

if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}

set w .pathTags
catch {destroy $w}
toplevel $w
wm title $w "Zinc Path tags Demonstration"
wm iconname $w "Path tags"

set defaultfont [font create -family Helvetica -size 10 -weight bold]

frame $w.buttons
pack $w.buttons -side bottom -fill x -pady 2m
button $w.buttons.dismiss -text Dismiss -command "destroy $w"
button $w.buttons.code -text "See Code" -command "showCode $w"
pack $w.buttons.dismiss $w.buttons.code -side left -expand 1


## this demo demonstrates the use of path tags to address one or more items
## belonging to a hierarchy of groups.
## This hierarchy is described just below gr_xxx designates a group
## (with a tag xxx and i_yyy designates an non-group item (with a tag yyy .

#  gr_top --- gr_a --- gr_aa --- gr_aaa --- gr_aaaa --- i_aaaaa
#          |       |         |          |-- i_aaab  |-- i_aaaab
#          |       |         -- i_aab
#          |       |-- i_ab
#          |       |
#          |       ---gr_ac --- i_aca
#          |                |
#          |-- i_b          --- i_acb
#          |
#          --- gr_c --- gr_ca --- i_caa
#                   |         |
#                   |         --- i_cab
#                   |-- i_cb
#                   |
#                   ---gr_cc --- i_cca
#                            |
#                            --- i_ccb
#the same objects are cloned and put in an other hierarchy where
#grTop is replaced by grOtherTop

set defaultForeColor sienna

###########################################
# Text zone
###########################################

text $w.text -relief sunken -borderwidth 2 -height 5
pack $w.text -expand yes -fill both

$w.text insert end {This represents a group hierarchy:
    - groups are represented by a rectangle and a Title.
    - non-group items are represented by a text.
    Select a pathTag or a tag with one of the radio-button
    or experiment your own tags in the input field}

###########################################
# Zinc creation
###########################################
zinc $w.zinc -width 850 -height 360 -font 10x20 -borderwidth 0 -backcolor white
pack $w.zinc

###########################################
# Creation of a bunch of radiobutton and a text input
###########################################

pack [frame $w.tagsfm]

set pathtag {}
pack [frame $w.left] -side left -expand 1 -padx .5c -pady .2c
pack [frame $w.middle] -side left -expand 1 -padx .5c -pady .2c
pack [frame $w.right] -side left -expand 1 -padx .5c -pady .2c
pack [frame $w.rtop] -side left -expand 1 -padx .5c -pady .2c
pack [frame $w.rbottom ] -side left -expand 1 -padx .5c -pady .2c
pack [frame $w.rbot_left] -side left -expand 1 -padx .5c -pady .2c
pack [frame $w.rbot_right] -side left -expand 1 -padx .5c -pady .2c

set i 0
foreach p {top .top .top. .top* .top*cca .5.} {
    radiobutton $w.left.r$i -text $p -command displayPathtag \
	-variable pathtag -relief flat -value $p 
    pack $w.left.r$i -side top -pady 2 -anchor w
    incr i
}
set i 0
foreach p {.top*aa .top*aa. .top*aa* .top*aaa .top*aaa. .5*} {
    radiobutton $w.middle.r$i -text $p -command displayPathtag \
	-variable pathtag -relief flat -value $p
    pack $w.middle.r$i -side top -pady 2 -anchor w
    incr i
}


label $w.rtop.label -relief flat -text {your own tag:}
pack $w.rtop.label -side left
entry $w.rtop.entry -width 15
pack $w.rtop.entry -side left
bind $w.rtop.entry <Key-Return> " "
#sub {$pathtag $_"0"->get &displayPathtag} 

set i 0
foreach p {.top*aa*aaa .top*aa*aaa. .top*aa*aaa* .otherTop*aa* .5*ca*} {
    radiobutton $w.rbot_left.r$i -text $p -command displayPathtag \
	-variable pathtag -relief flat -value $p
    pack $w.rbot_left.r$i -side top -pady 2 -anchor w
    incr i
}

set i 0
foreach p "{*aa*aaaa *aaa} {aa || ca} none all" {
    radiobutton $w.rbot_right.r$i -text $p -command displayPathtag \
	-variable pathtag -relief flat -value p 
    pack $w.rbot_right.r$i -side top -pady 2 -anchor w
    incr i
}

### Here we create the genuine hierarchy of groups and items
### Later we will create graphical objects to display groups
proc createSubHierarchy {gr} {
    global w
    $w.zinc add group $gr -tags a 
    $w.zinc add text $gr -tags {b text} -text b -position {270 150}
    $w.zinc add group $gr -tags c 
    
    $w.zinc add group a -tags aa 
    $w.zinc add text a -tags {ab text} -text ab -position {60 220}
    $w.zinc add group a -tags ac 
    
    $w.zinc add group aa -tags aaa 
    $w.zinc add text aa -tags {aab text} -text aab -position {90 190}
    $w.zinc add group aaa -tags aaaa 
    $w.zinc add text aaaa -tags {aaaaa text} -text aaaaa -position {150 110}
    $w.zinc add text aaaa -tags {aaaab text} -text aaaab -position {150 130}
    $w.zinc add text aaa -tags {aaab text} -text aaab -position {120 160}
    
    $w.zinc add text ac -tags aca -text aca -position {90 260}
    $w.zinc add text ac -tags {acb text} -text acb -position {90 290}
    
    $w.zinc add group c -tags ca 
    $w.zinc add text c -tags {cb text} -text cb -position {330 160}
    $w.zinc add group c -tags cc 
    
    $w.zinc add text ca -tags {caa text} -text caa -position {360 110}
    $w.zinc add text ca -tags {cab text} -text cab -position {360 130}
    
    $w.zinc add text cc -tags {cca text} -text cca -position {360 200}
    $w.zinc add text cc -tags {ccb text} -text ccb -position {360 220}
}


# converts a list of items ids in a list of sorted tags the first tag of each item 
proc items2tags {items} {
    global w

    foreach item $items {
	set tags [$w.zinc itemcget $item -tags ]
	if {[lindex $tags 0]=="frame" || [lindex $tags 0]=="title"} {
	    continue
	}
	lappend selected_tags [lindex $tags 0]
    }
    return [lsort selected_tags]
}

### drawing :
#### a rectangle item for showing the bounding box of each group 
### a text item for the group name i.e. its first tag 

## backgrounds used to fill rectangles representing groups
set backgrounds {grey90 grey82 grey75 grey68 grey60 grey52 grey45}

proc drawHierarchy {group level} {
    global w backgrounds

    set tags [$w.zinc gettags $group]

    foreach g [$w.zinc find withtype group ".$group."] {
	drawHierarchy $g [expr $level+1]
    }
    set coords [$w.zinc bbox $group]
    foreach {x y x2 y2} $coords break
    $w.zinc add text $group -position [list [expr $x-5] [expr $y-4]] \
	-text [lindex $tags 0] -anchor w -alignment left \
	-underlined 1 -priority 20 -tags [list "title_.[lindex $tags 0]" group_title] 

    if {$x} {
	set background [lindex $backgrounds $level] 
	$w.zinc add rectangle $group [list [expr $x+0] [expr $y+5] [expr $x2+5] [expr $y2+2]]\
	    -filled 1 -fillcolor $background -priority $level \
	    -tags [list frame_.[lindex $tags 0]group_frame]
	
    } else {
	puts "undefined bbox for $group : $tags\n"
    }
}

### this sub extracts out of groups both text and frame representing
### each group. This is necessary to avoid unexpected selection of
### rectangles and titles inside groups
proc extractTextAndFrames {} {
    global w
    foreach group_title [$w.zinc find withtag {group_title || group_frame}] {
	set ancestors [$w.zinc find ancestor $group_title]
	# puts "$group_title @ancestors\n"
	set grandFather [lindex $ancestors 1]
	$w.zinc chggroup $group_title $grandFather 1 
    }
}

## this sub modifies the color/line color of texts and rectangles
## representing selected items. 
proc displayPathtag {} {
    global w pathtag defaultForeColor

    set selected [$w.zinc find withtag $pathtag]
    set tags [items2tags $selected]
    puts "selected: $tags\n"
    # puts "selected= "
    # foreach sel $selected {
    #     puts "$sel [$w.zinc type $sel] [join [$w.zinc gettags $sel] ,] /\n"
    # }
    #
    ## unselecting all items 
    foreach item [$w.zinc find withtype text] {
	$w.zinc itemconfigure $item -color $defaultForeColor 
    }
    foreach item [$w.zinc find withtype rectangle] {
	$w.zinc itemconfigure $item -linecolor $defaultForeColor 
    }

    ## highlighting selected items
    foreach item $selected {
	set type [$w.zinc type $item ]
	#	print $item " " $w.zinc type $item " " join " " $w.zinc gettags $item "\n"
	switch -- $type {
	    text {
		$w.zinc itemconfigure $item -color black 
	    }
	    rectangle {
		$w.zinc itemconfigure $item -linecolor black 
	    }
	    group {
		set tag [lindex [$w.zinc gettags $item] 0]
		set grandFather [$w.zinc find ancestors $item top]
		if {$grandFather == 1} {
		    ## as there is 2 // hierachy we must refine the tag used
		    ## to restrict to the proper hierarchy
		    $w.zinc itemconfigure "*$grandFather*frame_$tag" -linecolor black
		    $w.zinc itemconfigure "*$grandFather*title_$tag" -color black
		} else {
		    ## when a group as no grandfather it can only be top or otherTop
		    ## as their tags are non-ambiguous no need to refine!
		    $w.zinc itemconfigure "frame_$tag" -linecolor black
		    $w.zinc itemconfigure "title_$tag" -color black
		}
	    }
	}
    }
}

# creating the item hierarchy
$w.zinc add group 1 -tags top
createSubHierarchy top

# creating a parallel hierarchy
$w.zinc add group 1 -tags otherTop
createSubHierarchy otherTop

drawHierarchy top 0 
drawHierarchy otherTop 0 
$w.zinc translate otherTop 400 0
extractTextAndFrames
