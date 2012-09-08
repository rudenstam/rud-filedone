##########################################################################
# dZSbot - mkvsize Plug-in                                               #
##########################################################################
#
# 0.1.1 Fixed the header reading, now reads the size properly
#
# 0.1 Initial release
#
##########################################################################


if {[info procs ::rud::mkvsize::deinit] != ""} {::rud::mkvsize::deinit}

namespace eval ::rud::mkvsize {
	variable version "0.1.1"

	variable scriptName [namespace current]::check
	bind evnt -|- prerehash [namespace current]::deinit
}

proc ::rud::mkvsize::init {args} {
	global postcommand msgtypes variables announce
	variable version
	variable scriptName

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

proc ::rud::mkvsize::readWeirdInt {buffer} {
	set result 0
	if {[catch {
		set binary [a2b [string index $buffer 0]]
		set first [string first "1" $binary]
		set sizebuffer [string range $buffer 0 $first]
		set binary [string range [d2b [a2d $sizebuffer] 1] [expr {$first + 1}] end]
		set result [a2d [string range $buffer [expr {$first+1}] [expr {$first+[b2d $binary]}]]]
	} err]} {
		log $err
	}
	return $result
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

	doit $file $path $section

	return 1
}

proc ::rud::mkvsize::doit [list theFile theDir section [list outchan $::mainchan]] {
	# Read first 64 kb from file to use for info
	set fp [open $theDir/$theFile r]
	fconfigure $fp -translation binary
	set data [read $fp 65536]
	close $fp

	set what [lindex [split $theDir "/"] end-1]

	set segmentstart [string first "\x18\x53\x80\x67" $data]

	if {$segmentstart == -1} {
		log "No segmentstart found"
		return
	}

	# Get the expected file size (mkvdata +  mkvheader)
	set mkvsizevar(first) [string index $data [expr {$segmentstart+4}]]
	set mkvsizevar(firstbin) [d2b [a2d $mkvsizevar(first)] 1]
	set mkvsizevar(readbytes) [string first "1" $mkvsizevar(firstbin)]
	set mkvsizevar(segmentend) [expr {$segmentstart+4+$mkvsizevar(readbytes)}]
	set mkvsizevar(whole) [string range $data [expr {$segmentstart+4}] $mkvsizevar(segmentend)]
	set mkvsizevar(wholebin) [string range [d2b [a2d $mkvsizevar(whole)]] 1 end]
	set mkvsizevar(bytes) [b2d $mkvsizevar(wholebin)]
	set headerbytes [expr {$mkvsizevar(segmentend)+1}]
	set mkvsize [expr {$mkvsizevar(bytes) + $headerbytes}]

	set filesize [file size $theDir/$theFile]
	if {$mkvsize == $filesize} {
		set status 1
	} else {
		set status 0
	}

	set releasename [lindex [split $theDir "/"] end-1]
	if {$status} {
		set outmsg "< \00303$section \017> \002$releasename\002 -> $theFile -> \00303OK\017"
	} else {
		set outmsg "< \00303$section \017> \002$releasename\002 -> $theFile -> \00304$mkvsize ([formatBytes $mkvsize]) expected, $filesize ([formatBytes $filesize]) found\017"
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
			doit [lindex [split $item "/"] end] [join [lrange [split $path "/"] 0 end-1] "/"] "irc" $chan
		}
	} else {
		putserv "PRIVMSG $chan :No mkv files found in $arg"
	}

	return 1
}

::rud::mkvsize::init
