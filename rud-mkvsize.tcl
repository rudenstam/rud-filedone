##########################################################################
# dZSbot - mkvsize Plug-in                                               #
##########################################################################

namespace eval ::ngBot::plugin::mkvsize {
	## Keep version in sync with the Makefile
	variable version "0.3"

	variable ns [namespace current]
	variable np [namespace qualifiers [namespace parent]]

	variable scriptFile [info script]
	variable scriptName [namespace current]::check

	variable mainchan [set ${np}::mainchan]

	proc log {args} {
		putlog "\[mkvsize\] [join $args]"
	}

	proc init {args} {
		variable np
		variable ${np}::variables
		variable ${np}::precommand
		variable ${np}::msgtypes
		variable scriptName
		variable scriptFile
		variable version

		set variables(MKV_DONE_OK)  "%path %file %section %release %expectedSize %formatedExpectedSize %realSize %formatedRealSize"
		set variables(MKV_DONE_BAD) "%path %file %section %release %expectedSize %formatedExpectedSize %realSize %formatedRealSize"

		set theme_file [file normalize "[pwd]/[file rootname $scriptFile].zpt"]
		if {[file isfile $theme_file]} {
			${np}::loadtheme $theme_file true
		}

		# Add event handler
		set event MKV_DONE
		lappend precommand($event) $scriptName

		if {[info exists msgtypes(SECTION)] && [lsearch -exact $msgtypes(SECTION) $event] ==  -1} {
			lappend msgtypes(SECTION) $event
		}

		log "version $version loaded."
	}

	proc deinit {args} {
		variable np
		variable ${np}::precommand
		variable version
		variable scriptName

		# Remove event handler
		set event MKV_DONE
		if {[info exists precommand($event)] && [set pos [lsearch -exact $precommand($event) $scriptName]] !=  -1} {
			set precommand($event) [lreplace $precommand($event) $pos $pos]
		}

		if {[info exists msgtypes(SECTION)] && [set pos [lsearch -exact $msgtypes(SECTION) $event]] !=  -1} {
			set msgtypes(SECTION) [lreplace $msgtypes(SECTION) $pos $pos]
		}

		log "version $version unloadead."

		namespace delete [namespace current]
	}

	proc check {event section logdata} {
		variable np
		variable ${np}::glroot

		set path [lindex $logdata 0]
		set abspath $glroot$path
		set file [lindex $logdata 1]

		lassign [doIt $abspath/$file] result mkvSize fileSize

		set formatedMkvSize [${np}::format_kb [expr $mkvSize/1024.0]]
		set formatedFileSize [${np}::format_kb [expr $fileSize/1024.0]]

		if ($result) {
			set event MKV_DONE_OK
		} else {
			set event MKV_DONE_BAD
		}

		set release [findRelease $path]
		lappend logdata $section $release $mkvSize $formatedMkvSize $fileSize $formatedFileSize

		set output [${np}::ng_format $event $section $logdata]
		${np}::sndall $event $section $output

		return 0
	}

	proc findRelease {path} {
		variable np
		variable ${np}::paths

		foreach {sectionName sectionPath} [array get paths] {
			if {[string match $sectionPath $path]} {
				set release [string range $path [expr {[string length $sectionPath]-1}] end]
				set release [string range $release 0 [expr {[string first "/" $release] -1}]]
				break
			}
		}
		return $release
	}

	proc doIt {file} {
		set mkvSize [ebml::parseFile $file]

		set fileSize [file size $file]
		if {$mkvSize == $fileSize} {
			return [list 1 $mkvSize $fileSize]
		} else {
			return [list 0 $mkvSize $fileSize]
		}
	}

	proc irccheck {nick uhost hand chan arg} {
		set path "$::glroot/site/[lindex $arg 0]"

		if {![file isfile $path]} {
			set files [glob -nocomplain -dir $path *.mkv]
		}

		if {[llength $files] > 0} {
			foreach item $files {
				set releaseName [lindex [file split $item] end-1]
				set filename [lindex [file split $item] end]
				set result [doIt $item]
				if {[lindex $result 0]} {
					set outmsg "< \00303irc \017> \002$releaseName\002 -> $fileName -> \00303OK\017"
				} else {
					set outmsg "< \00303$section \017> \002$releaseName\002 -> $theFile -> \00304$mkvSize ([formatBytes $mkvSize]) expected, $filesize ([formatBytes $filesize]) found\017"
				}
				log [lindex [split $item "/"] end] [join [lrange [split $path "/"] 0 end-1] "/"] "irc" $chan
			}
		} else {
			putserv "PRIVMSG $chan :No mkv files found in $arg"
			log "No mkv files in $path"
		}

		return 1
	}

	#
	# EBML parsing
	#

	namespace eval [namespace current]::ebml {
		proc log {args} {
			putlog "\[mkvsize::ebml\] [join $text]"
		}

		proc getId {fp} {
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

		proc getSize {fp} {
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

		proc parseChunk {fp} {
			set id [getId $fp]
			set size [getSize $fp]

			if {$id == "" || $size == -1} {
				return -1
			}

			switch -exact -nocase $id {
				18538067 {
					return [expr $size + [tell $fp]]
				}

				default {
					seek $fp $size current
				}
			}

			return 0
		}

		proc parseFile {filename} {
			set fp [open $filename r]
			chan configure $fp -translation binary

			set res 0
			while {![eof $fp] && $res == 0} {
				set res [parseChunk $fp]
				if {$res == -1} {
					log "parseChunk returned -1 at position [tell $fp], eof: [eof $fp]"
				}
			}
			close $fp

			return $res
		}
	}
}
