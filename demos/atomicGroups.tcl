# these simple samples have been developped by C. Mertz mertz@cena.fr in perl
# tcl version by Jean-Paul Imbert imbert@cena.fr

if {![info exists zincDemo]} {
    error "This script should be run from the zinc-widget demo."
}


set w .atomicGroups
catch {destroy $w}
toplevel $w
wm title $w "Zinc Atomicity Demonstration"
wm iconname $w "Atomic"

set defaultfont [font create -family Helvetica -size 10 -weight bold]

frame $w.buttons
pack $w.buttons -side bottom -fill x -pady 2m
button $w.buttons.dismiss -text Dismiss -command "destroy $w"
button $w.buttons.code -text "See Code" -command "showCode $w"
pack $w.buttons.dismiss $w.buttons.code -side left -expand 1

zinc  $w.zinc -width  500 -height  350 -font  "10x20"  -borderwidth  0
pack $w.zinc

set groups_group_atomicity  0
set red_group_atomicity  0
set green_group_atomicity  0

set display_clipping_item_background  0
set clip  1

$w.zinc add "text"  1 -font  $defaultfont -text  "- There are 3 groups: a red group containing 2 redish objects\na green group containing 2 greenish objects,\nand groups_group containing both previous groups.\n- You can make some groups atomic or not by depressing \nthe toggle buttons at the bottom of the window\n- Try and then click on some items to observe that callbacks\n are then different: they modify either the item, or 2 items of\n a group or all items" -anchor  "nw" -position  "10 10"


############### creating the top group with its bindings ###############################
set groups_group [$w.zinc add group 1 -visible 1 -atomic $groups_group_atomicity -tags groups_group]

# the following callbacks will be called only if "groups_group" IS atomic
$w.zinc bind $groups_group <1> modify_bitmap_bg
$w.zinc bind $groups_group <ButtonRelease-1> modify_bitmap_bg

############### creating the red_group, with its binding and its content ################
# the red_group may be atomic, that is is makes all children as a single object
# and sensitive to red_group callbacks
set red_group [$w.zinc add group $groups_group -visible 1 -atomic $red_group_atomicity -sensitive 1 -tags red_group]

# the following callbacks will be called only if "groups_group" IS NOT-atomic
# and if "red_group" IS atomic
$w.zinc bind $red_group <1> "modify_item_lines $red_group"
$w.zinc bind $red_group <ButtonRelease-1> "modify_item_lines $red_group" 


set rc [$w.zinc add arc $red_group {100 200 140 240} -filled 1 -fillcolor red2 -linewidth 3 -linecolor white -tags red_circle]
set rr [$w.zinc add rectangle $red_group {300 200 400 250} -filled 1 -fillcolor red2 -linewidth 3 -linecolor white -tags red_rectangle]

# the following callbacks will be called only if "groups_group" IS NOT atomic
# and if "red_group" IS NOT atomic
$w.zinc bind $rc  <1> toggle_color
$w.zinc bind $rc  <ButtonRelease-1> toggle_color
$w.zinc bind $rr  <1> toggle_color
$w.zinc bind $rr  <ButtonRelease-1> toggle_color

############### creating the green_group, with its binding and its content ################
# the green_group may be atomic, that is is makes all children as a single object
# and sensitive to green_group callbacks
set green_group  [$w.zinc add group $groups_group -visible 1 -atomic $green_group_atomicity -sensitive 1 -tags green_group]

# the following callbacks will be called only if "groups_group" IS NOT atomic
# and if "green_group" IS atomic
$w.zinc bind $green_group <1> "modify_item_lines $green_group"
$w.zinc bind $green_group <ButtonRelease-1> "modify_item_lines $green_group"

set gc [$w.zinc add arc $green_group {100 270  140 310} -filled 1 -fillcolor green2 -linewidth 3 -linecolor white -tags green_circle]

set gr [$w.zinc add rectangle $green_group {300 270   400 320} -filled 1 -fillcolor green2 -linewidth 3 -linecolor white -tags green_rectangle]
# the following callbacks will be called only if "groups_group" IS NOT atomic
# and if "green_group" IS NOT atomic
$w.zinc bind $gc  <1>  toggle_color
$w.zinc bind $gc  <ButtonRelease-1>  toggle_color
$w.zinc bind $gr  <1>  toggle_color
$w.zinc bind $gr  <ButtonRelease-1>  toggle_color



set current_bg  ""
###################### groups_group callback ##############

proc modify_bitmap_bg {} {
    global current_bg		      
    global rc rr gc gr
    global w
    if {$current_bg=="AlphaStipple2"} {
	set current_bg {}
    } else {
	set current_bg AlphaStipple2
    }
    foreach item "$rc  $rr  $gc  $gr" {
	$w.zinc itemconfigure $item -fillpattern $current_bg
    }
}

#################### red/green_group callback ##############
proc modify_item_lines {gr} {
    global w
    
    set children [$w.zinc find withtag ".$gr*"] 
    # we are using a pathtag (still undocumented feature of 3.2.6) to get items of an atomic group!
    # we could also temporary modify the groups (make it un-atomic) to get its child

    set current_linewidth [$w.zinc itemcget [lindex $children 0] -linewidth]

    if {$current_linewidth == 3} {
	set current_linewidth 0
    } else {
	set current_linewidth 3
    }
    foreach item $children {
	$w.zinc itemconfigure $item  -linewidth  $current_linewidth
    }
	
}


##################### items callback ######################
proc toggle_color {} {
    global w
    set item  [$w.zinc find withtag current]
    set fillcolor  [$w.zinc itemcget $item  -fillcolor]
    regexp {([a-z]+)(\d)} $fillcolor "" color num

    #my ($color $num) = $fillcolor =~ /("a-z"+)(\d)/ 
    if {$num == 2} {    
	set val 1
	set num 4
    } else {
	set num 2
    }
    $w.zinc itemconfigure $item -fillcolor "$color$num"
}

proc  atomic_or_not {gr} {
    global w
    set val [lindex [$w.zinc itemconfigure $gr  -atomic] 4]
    if {$val==1} {
	$w.zinc itemconfigure $gr  -atomic 0
    } else {
	$w.zinc itemconfigure $gr  -atomic 1
    }
    update_found_items
}


###################### toggle buttons at the bottom ####
frame $w.row  
pack $w.row
	 
checkbutton $w.row.cb -text "groups_group is atomic" -variable groups_group_atomicity -command "atomic_or_not  $groups_group"
pack $w.row.cb -anchor  "w"	  

checkbutton $w.row.cb2 -text "red group is atomic" -foreground red4 -variable red_group_atomicity -command "atomic_or_not $red_group"
pack $w.row.cb2 -anchor w  

checkbutton $w.row.cb3 -text "green group is atomic" -foreground green4 -variable  green_group_atomicity -command  "atomic_or_not $green_group"
pack $w.row.cb3 -anchor w  

label $w.row.lb 
pack $w.row.lb -anchor w

label $w.row.lb2 -text "Following command $w.zinc find overlapping 0 200 500 400 returns:"
pack $w.row.lb2 -anchor w
set label  [pack [label $w.row.label -background gray95] -anchor w]

##### to update the list of enclosed items
proc update_found_items {} {
    global w
    set found  [$w.zinc find overlapping 0 200 500 400]
    set str  ""
    foreach item $found {
	set tags [$w.zinc itemcget $item  -tags]
	set str  "$str $tags"
    }
    $w.row.label configure -text  $str 
}

# to init the list of enclosed items
update_found_items
