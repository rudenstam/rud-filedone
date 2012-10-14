##########################################################################
# dZSbot - mkvsize Plug-in                                               #
##########################################################################

if {[info procs ::rud::mkvsize::deinit] != ""} {::rud::mkvsize::deinit}

namespace eval ::rud::mkvsize {
	## Keep version in sync with the Makefile
	variable version "0.3"

	variable scriptName [namespace current]::check
	bind evnt -|- prerehash [namespace current]::deinit
}

proc ::rud::mkvsize::init {args} {
	global postcommand msgtypes variables announce
	variable version
	variable scriptName
	variable mkvSize 0

	## Register the event handler.
	lappend postcommand(MKV_DONE) $scriptName
	lappend msgtypes(SECTION) "MKV_DONE"
	set variables(MKV_DONE) ""
	set announce(MKV_DONE) ""

	bind pub -|- !mkvsize ::rud::mkvsize::irccheck

	log "Version $version loaded succesfully."
	return
}

proc ::rud::mkvsize::deinit {args} {
	global postcommand msgtypes
	variable scriptName
	variable version

	## Remove the script event from postcommand.
	if {[info exists postcommand(MKV_DONE)] && [set pos [lsearch -exact $postcommand(MKV_DONE) $scriptName]] !=  -1} {
		set postcommand(MKV_DONE) [lreplace $postcommand(MKV_DONE) $pos $pos]
	}

	if {[info exists msgtypes(SECTION)] && [set pos [lsearch -exact $msgtypes(SECTION) "MKV_DONE"]] !=  -1} {
		set msgtypes(SECTION) [lreplace $msgtypes(SECTION) $pos $pos]
	}

	catch {
		unset variables(MKV_DONE)
		unset announce(MKV_DONE)
	}

	catch {unbind evnt -|- prerehash [namespace current]::deinit}

	namespace delete [namespace current]
	log "Version $version unloaded succesfully."
	return
}

proc rud::mkvsize::log {text} {
	putlog "rud-mkvsize -> $text"
}

proc ::rud::mkvsize::formatBytes {bytes} {
	set suffixes [list bytes KiB MiB GiB TiB]
	set i 0
	while {$bytes >= 1024 && $i < 4} {
		set bytes [expr wide($bytes)/wide(1024)]
		incr i
	}
	return "$bytes [lindex $suffixes $i]"
}

proc ::rud::mkvsize::check {event section logdata} {
	set path "$::glroot[lindex $logdata 0]"
	set file [lindex $logdata 1]

	doIt $file $path $section

	return 1
}

proc ::rud::mkvsize::doIt [list theFile theDir section [list outchan $::mainchan]] {
	variable mkvSize

	set fp [open $theDir/$theFile r]

	chan configure $fp -translation binary

	set res 1
	while {![eof $fp] && $res} {
		set res [parseChunk $fp]
		if {$res == -1} {
			log "parseChunk returned -1 at position [tell $fp], eof: [eof $fp]"
		}
	}
	close $fp

	set filesize [file size $theDir/$theFile]
	if {$mkvSize == $filesize} {
		set status 1
	} else {
		set status 0
	}

	set releaseName [lindex [split $theDir "/"] end-1]
	if {$status} {
		set outmsg "< \00303$section \017> \002$releaseName\002 -> $theFile -> \00303OK\017"
	} else {
		set outmsg "< \00303$section \017> \002$releaseName\002 -> $theFile -> \00304$mkvSize ([formatBytes $mkvSize]) expected, $filesize ([formatBytes $filesize]) found\017"
	}
	putserv "PRIVMSG $outchan :$outmsg"
}

proc ::rud::mkvsize::irccheck {nick uhost hand chan arg} {
	set path "$::glroot/site/[lindex $arg 0]"

	if {![file isfile $path]} {
		set files [glob -nocomplain -dir $path *.mkv]
	}

	if {[llength $files] > 0} {
		foreach item $files {
			doIt [lindex [split $item "/"] end] [join [lrange [split $path "/"] 0 end-1] "/"] "irc" $chan
		}
	} else {
		putserv "PRIVMSG $chan :No mkv files found in $arg"
	}

	return 1
}

#
# EBML parsing
#
proc ::rud::mkvsize::getId {fp} {
	set data [read $fp 1]

	if {[binary scan $data cu firstByte] != 1} {
		return ""
	}

	set size 0
	for {set i 7} {$i >= 0} {incr i -1} {
		if {[expr {$firstByte & (1 << $i)}]} {
			set size [expr 7-$i]
			break
                }
        }

	append data [read $fp $size]
	binary scan $data H* id
	return $id
}

proc ::rud::mkvsize::getSize {fp} {
	set data [read $fp 1]

	if {[binary scan $data cu firstByte] != 1} {
		return -1
	}

	set size 0
	for {set i 7} {$i >= 0} {incr i -1} {
		if {[expr {$firstByte & (1 << $i)}]} {
			set size [expr 7-$i]
			break
		}
	}

	set data [binary format cu [expr {$firstByte & ~(1 << (7-$size))}]]

	binary scan $data cu test

	append data [read $fp $size]
	set data "[string repeat \00 [expr {8-[string length $data]}]]$data"
	binary scan $data W sizeSize

	return $sizeSize
}

proc ::rud::mkvsize::parseChunk {fp} {
	variable mkvSize

	set id [getId $fp]
	set size [getSize $fp]

	if {$id == "" || $size == -1} {
		return -1
	}

	switch -exact -nocase $id {
		18538067 {
			set mkvSize [expr $size + [tell $fp]]
			return 0
		}

		default {
			seek $fp $size current
		}
	}

	return 1
}

proc ::rud::mkvsize::parseFile {filename} {
	set fp [open $filename r]
	chan configure $fp -translation binary

	set res 1
	while {![eof $fp] && $res} {
		set res [parseChunk $fp]
		if {$res == -1} {
			puts "parseChunk returned -1 at position [tell $fp], eof: [eof $fp]"
		}
	}
	close $fp
}

::rud::mkvsize::init
