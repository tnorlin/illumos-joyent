\ Copyright (c) 2006-2015 Devin Teske <dteske@FreeBSD.org>
\ All rights reserved.
\
\ Redistribution and use in source and binary forms, with or without
\ modification, are permitted provided that the following conditions
\ are met:
\ 1. Redistributions of source code must retain the above copyright
\    notice, this list of conditions and the following disclaimer.
\ 2. Redistributions in binary form must reproduce the above copyright
\    notice, this list of conditions and the following disclaimer in the
\    documentation and/or other materials provided with the distribution.
\
\ THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
\ ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
\ IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
\ ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
\ FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
\ DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
\ OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
\ HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
\ LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
\ OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
\ SUCH DAMAGE.
\
\ Copyright 2015 Toomas Soome <tsoome@me.com>
\ Copyright 2019 Joyent, Inc.
\ Copyright 2020 OmniOS Community Edition (OmniOSce) Association.

marker task-menu-commands.4th

include /boot/forth/menusets.4th

only forth definitions

variable osconsole_state
variable acpi_state
variable kmdb_state
0 osconsole_state !
0 acpi_state !
0 kmdb_state !

also menu-namespace also menu-command-helpers

\ PATH_MAX + 6
create chaincmd 1030 chars allot

\
\ Rollback to previous platform image.
\ Used by Joyent Triton
\
: rollback_boot ( N -- NOTREACHED )
	dup
	s" prev-platform" getenv s" bootfile" setenv
	s" prev-archive" getenv s" boot_archive" set-module-path
	s" prev-hash" getenv s" boot_archive.hash" set-module-path
	0 boot ( state -- )
;

\
\ Boot from ipxe kernel
\ Used by Joyent Triton when booted in BIOS/CSM mode
\
: ipxe_boot ( N -- NOTREACHED )
	dup
	s" ipxe-bootfile" getenv s" bootfile" setenv
	s" ipxe-archive" getenv s" boot_archive" set-module-path
	s" boot_archive.hash" disable-module
	0 boot ( state -- )
;

\
\ Chainload the ipxe EFI binary
\ Used by Joyent Triton when booted in UEFI mode
\
: ipxe_chainload ( N -- NOTREACHED )
	s" chain " chaincmd place
	s" ipxe-efi" getenv chaincmd append
	chaincmd count evaluate
;

\
\ Boot
\

: init_boot ( N -- N )
	dup
	s" smartos" getenv? if
		s" set menu_keycode[N]=98" \ base command to execute
	else
		s" boot_single" getenv -1 <> if
			drop ( n n c-addr -- n n ) \ unused
			toggle_menuitem ( n n -- n n )
			s" set menu_keycode[N]=115" \ base command to execute
		else
			s" set menu_keycode[N]=98" \ base command to execute
		then
	then
	17 +c! \ replace 'N' with ASCII numeral
	evaluate
;

\
\ Alternate Boot
\

: init_altboot ( N -- N )
	dup
	s" smartos" getenv? if
		s" set menu_keycode[N]=114" \ base command to execute
	else
		s" boot_single" getenv -1 <> if
			drop ( n c-addr -- n ) \ unused
			toggle_menuitem ( n -- n )
			s" set menu_keycode[N]=109" \ base command to execute
		else
			s" set menu_keycode[N]=115" \ base command to execute
		then
	then
	17 +c! \ replace 'N' with ASCII numeral
	evaluate
;

: altboot ( N -- NOTREACHED )
	s" smartos" getenv? if
		s" alt-boot-args" getenv dup -1 <> if
			s" boot-args" setenv ( c-addr/u -- )
		then
		." NoInstall/Recovery mode boot. login/pw: root/root" cr
	else
		s" boot_single" 2dup getenv -1 <> if
			drop ( c-addr/u c-addr -- c-addr/u ) \ unused
			unsetenv ( c-addr/u -- )
		else
			2drop ( c-addr/u -- ) \ unused
			s" set boot_single=YES" evaluate
		then
	then
	0 boot ( state -- )
;

\
\ Platform-image selection for standalone SmartOS is mostly in pi.rc.
\ We will also steal a boot environment routine in pi_draw_screen (way below).

: init_pi ( -- )
	s" bootpi" getenv? 0= if
		s" default" s" bootpi" setenv
	then

	\ Reset the "options" text to show current bootpi selected.
	s" set menu_optionstext=${pitext}${bootpi}" evaluate 
	s" set pimenu_optionstext=${pitext}${bootpi}" evaluate 
;

\ Shorter than inlining this in pi.rc.
: pi_unload ( -- )
	s" unload" evaluate
;

\
\ Single User Mode
\

: singleuser_enabled? ( -- flag )
	s" boot_single" getenv -1 <> dup if
		swap drop ( c-addr flag -- flag )
	then
;

: singleuser_enable ( -- )
	s" set boot_single=YES" evaluate
;

: singleuser_disable ( -- )
	s" boot_single" unsetenv
;

: init_singleuser ( N -- N )
	singleuser_enabled? if
		toggle_menuitem ( n -- n )
	then
;

: toggle_singleuser ( N -- N TRUE )
	toggle_menuitem
	menu-redraw

	\ Now we're going to make the change effective

	dup toggle_stateN @ 0= if
		singleuser_disable
	else
		singleuser_enable
	then

	TRUE \ loop menu again
;

\
\ Verbose Boot
\

: verbose_enabled? ( -- flag )
	s" boot_verbose" getenv -1 <> dup if
		swap drop ( c-addr flag -- flag )
	then
;

: verbose_enable ( -- )
	s" set boot_verbose=YES" evaluate
;

: verbose_disable ( -- )
	s" boot_verbose" unsetenv
;

: init_verbose ( N -- N )
	verbose_enabled? if
		toggle_menuitem ( n -- n )
	then
;

: toggle_verbose ( N -- N TRUE )
	toggle_menuitem
	menu-redraw

	\ Now we're going to make the change effective

	dup toggle_stateN @ 0= if
		verbose_disable
	else
		verbose_enable
	then

	TRUE \ loop menu again
;

\
\ Reconfiguration boot
\

: reconfigure_enabled? ( -- flag )
	s" boot_reconfigure" getenv -1 <> dup if
		swap drop ( c-addr flag -- flag )
	then
;

: reconfigure_enable ( -- )
	s" set boot_reconfigure=YES" evaluate
;

: reconfigure_disable ( -- )
	s" boot_reconfigure" unsetenv
;

: init_reconfigure ( N -- N )
	reconfigure_enabled? if
		toggle_menuitem ( n -- n )
	then
;

: toggle_reconfigure ( N -- N TRUE )
	toggle_menuitem
	menu-redraw

	\ Now we're going to make the change effective

	dup toggle_stateN @ 0= if
		reconfigure_disable
	else
		reconfigure_enable
	then

	TRUE \ loop menu again
;

\
\ Framebuffer
\

: init_framebuffer ( N -- N )
	framebuffer? if
		toggle_menuitem ( n -- n )
	then
;

: toggle_framebuffer ( N -- N TRUE )
	toggle_menuitem

	dup toggle_stateN @ 0= if
		s" off"
	else
		s" on"
	then 1 framebuffer

	draw-beastie
	draw-brand
	menu-init		\ needed to reset menu position
	menu-redraw

	TRUE \ loop menu again
;

\
\ Disaster Recovery boot
\

: rescue_enabled? ( -- flag )
	s" noimport" getenv -1 <> dup if
		swap drop ( c-addr flag -- flag )
	then
;

: rescue_enable ( -- )
	s" set noimport=true" evaluate
	s" smartos" getenv? if
		s" set standalone=true" evaluate
		s" set smartos=false" evaluate
	then
;

: rescue_disable ( -- )
	s" noimport" unsetenv
	s" standalone" unsetenv
	s" smartos" getenv? if
		s" set smartos=true" evaluate
	then
;

: init_rescue ( N -- N )
	rescue_enabled? if
		toggle_menuitem ( n -- n )
	then
;

: toggle_rescue ( N -- N TRUE )
	toggle_menuitem
	menu-redraw

	\ Now we're going to make the change effective

	dup toggle_stateN @ 0= if
		rescue_disable
	else
		rescue_enable
	then

	TRUE \ loop menu again
;

\
\ Escape to Prompt
\

: goto_prompt ( N -- N FALSE )

	s" set autoboot_delay=NO" evaluate

	cr
	." To get back to the menu, type `menu' and press ENTER" cr
	." or type `boot' and press ENTER to start illumos." cr
	cr

	FALSE \ exit the menu
;

\
\ Cyclestate (used by osconsole/acpi/kmdb below)
\

: init_cyclestate ( N K -- N )
	over cycle_stateN ( n k -- n k addr )
	begin
		tuck @  ( n k addr -- n addr k c )
		over <> ( n addr k c -- n addr k 0|-1 )
	while
		rot ( n addr k -- addr k n )
		cycle_menuitem
		swap rot ( addr k n -- n k addr )
	repeat
	2drop ( n k addr -- n )
;

\
\ OS Console
\ getenv os_console, if not set getenv console, if not set, default to "text"
\ allowed serial consoles: ttya .. ttyd
\ if new console will be added (graphics?), this section needs to be updated
\
: init_osconsole ( N -- N )
	s" os_console" getenv dup -1 = if
		drop
		s" console" getenv dup -1 = if
			drop 0		\ default to text
		then
	then				( n c-addr/u | n 0 )

	dup 0<> if			( n c-addr/u )
		2dup s" ttyd" compare 0= if
			2drop 4
		else 2dup s" ttyc" compare 0= if
			2drop 3
		else 2dup s" ttyb" compare 0= if
			2drop 2
		else 2dup s" ttya" compare 0= if
			2drop 1
		else
			2drop 0		\ anything else defaults to text
		then then then then
	then
	osconsole_state !
;

: activate_osconsole ( N -- N )
	dup cycle_stateN @	( n -- n n2 )
	dup osconsole_state !	( n n2 -- n n2 )  \ copy for re-initialization

	case
	0 of s" text" endof
	1 of s" ttya" endof
	2 of s" ttyb" endof
	3 of s" ttyc" endof
	4 of s" ttyd" endof
	dup s" unknown state: " type . cr
	endcase
	s" os_console" setenv
;

: cycle_osconsole ( N -- N TRUE )
	cycle_menuitem	\ cycle cycle_stateN to next value
	activate_osconsole	\ apply current cycle_stateN
	menu-redraw	\ redraw menu
	TRUE		\ loop menu again
;

\
\ ACPI
\
: init_acpi ( N -- N )
	s" acpi-user-options" getenv dup -1 <> if
		evaluate		\ use ?number parse step

		\ translate option to cycle state
		case
		1 of 1 acpi_state ! endof
		2 of 2 acpi_state ! endof
		4 of 3 acpi_state ! endof
		8 of 4 acpi_state ! endof
		0 acpi_state !
		endcase
	else
		drop
	then
;

: activate_acpi ( N -- N )
	dup cycle_stateN @	( n -- n n2 )
	dup acpi_state !	( n n2 -- n n2 )  \ copy for re-initialization

	\ if N == 0, it's default, just unset env.
	dup 0= if
		drop
		s" acpi-user-options" unsetenv
	else
		case
		1 of s" 1" endof
		2 of s" 2" endof
		3 of s" 4" endof
		4 of s" 8" endof
		endcase
		s" acpi-user-options" setenv
	then
;

: cycle_acpi ( N -- N TRUE )
	cycle_menuitem	\ cycle cycle_stateN to next value
	activate_acpi	\ apply current cycle_stateN
	menu-redraw	\ redraw menu
	TRUE		\ loop menu again
;

\
\ kmdb
\

: kmdb_disable
	s" boot_kmdb" unsetenv
	s" boot_drop_into_kmdb" unsetenv
;

: init_kmdb ( N -- N )
	\ Retrieve the contents of "nmi" or default to "panic"
	( N -- N c-addr/u )
	s" nmi" getenv dup -1 <> if else drop s" panic" then
	\ Store the string in "nmi_initial" if not already set
	\ (to support re-entering the menu from the loader prompt)
	s" nmi_initial" getenv? if else
		2dup s" nmi_initial" setenv
	then
	( N caddr/u -- N flag )
	s" kmdb" compare if false else true then

	s" boot_kmdb" getenv -1 <> if
		drop
		s" boot_drop_into_kmdb" getenv -1 <> if
			drop
			if 4 else 3 then
		else
			if 2 else 1 then
		then
	else
		drop	\ drop flag
		0
	then
	kmdb_state !
;

: activate_kmdb ( N -- N )
	dup cycle_stateN @	( n -- n n2 )
	dup kmdb_state !	( n n2 -- n n2 )

	\ Reset "nmi" to its initial value
	s" nmi_initial" getenv s" nmi" setenv

	case 4 of		\ drop + nmi=kmdb
		s" set boot_kmdb=YES" evaluate
		s" set boot_drop_into_kmdb=YES" evaluate
		s" set nmi=kmdb" evaluate
	endof 3 of		\ drop
		s" set boot_kmdb=YES" evaluate
		s" set boot_drop_into_kmdb=YES" evaluate
	endof 2 of		\ load + nmi=kmdb
		s" set boot_kmdb=YES" evaluate
		s" boot_drop_into_kmdb" unsetenv
		s" set nmi=kmdb" evaluate
	endof 1 of		\ load
		s" set boot_kmdb=YES" evaluate
		s" boot_drop_into_kmdb" unsetenv
	endof
		kmdb_disable
	endcase
;

: cycle_kmdb ( N -- N TRUE )
	cycle_menuitem	\ cycle cycle_stateN to next value
	activate_kmdb	\ apply current cycle_stateN
	menu-redraw	\ redraw menu
	TRUE		\ loop menu again
;

\
\ Menusets
\

: goto_menu ( N M -- N TRUE )
	menu-unset
	menuset-loadsetnum ( n m -- n )
	menu-redraw
	TRUE \ Loop menu again
;

\
\ Defaults
\

: unset_boot_options
	0 acpi_state !
	s" acpi-user-options" unsetenv
	s" boot-args" unsetenv
	s" boot_ask" unsetenv
	singleuser_disable
	verbose_disable
	kmdb_disable		\ disables drop_into_kmdb as well
	reconfigure_disable
;

: set_default_boot_options ( N -- N TRUE )
	unset_boot_options
	2 goto_menu
;

\
\ Set boot environment defaults
\


: init_bootenv ( -- )
	s" set menu_caption[1]=${bemenu_current}${zfs_be_active}" evaluate
	s" set ansi_caption[1]=${beansi_current}${zfs_be_active}" evaluate
	s" set menu_caption[2]=${bemenu_bootfs}${currdev}" evaluate
	s" set ansi_caption[2]=${beansi_bootfs}${currdev}" evaluate
	s" set menu_caption[3]=${bemenu_page}${zfs_be_currpage}${bemenu_pageof}${zfs_be_pages}" evaluate
	s" set ansi_caption[3]=${beansi_page}${zfs_be_currpage}${bemenu_pageof}${zfs_be_pages}" evaluate
;

\
\ Redraw the entire screen. A long BE name can corrupt the menu
\

: be_draw_screen
	clear		\ Clear the screen (in screen.4th)
	print_version	\ print version string (bottom-right; see version.4th)
	draw-beastie	\ Draw FreeBSD logo at right (in beastie.4th)
	draw-brand	\ Draw brand.4th logo at top (in brand.4th)
	menu-init	\ Initialize menu and draw bounding box (in menu.4th)
;

\ PI reuse of be_draw_screen, plus some other things to be used by pi.rc.

: pi_draw_screen ( -- TRUE )
	\ So we can make SURE we have the current boot PI on display.
	init_pi

	be_draw_screen
	menu-redraw
	TRUE
;

\
\ Select a boot environment
\

: set_bootenv ( N -- N TRUE )
	dup s" bootenv_root[E]" 13 +c! getenv
	s" currdev" getenv compare 0= if
		s" zfs_be_active" getenv type ."  is already active"
	else
		dup s" set currdev=${bootenv_root[E]}" 27 +c! evaluate
		dup s" bootenvmenu_caption[E]" 20 +c! getenv
		s" zfs_be_active" setenv
		." Activating " s" currdev" getenv type cr
		s" unload" evaluate
		free-module-options
		unset_boot_options
		s" /boot/defaults/loader.conf" read-conf
		s" /boot/loader.conf" read-conf
		s" /boot/loader.conf.local" read-conf
		init_bootenv

		s" 1" s" zfs_be_currpage" setenv
		s" be-set-page" evaluate
	then

	500 ms			\ sleep so user can see the message
	be_draw_screen
	menu-redraw
	TRUE
;

\
\ Chainload this entry. Normally we do not return, in case of error
\ from chain load, we continue with normal menu code.
\

: set_be_chain ( N -- no return | N TRUE )
	dup s" chain ${bootenv_root[E]}" 21 +c! evaluate catch drop

	menu-redraw
	TRUE
;

\
\ Switch to the next page of boot environments
\

: set_be_page ( N -- N TRUE )
	s" zfs_be_currpage" getenv dup -1 = if
		drop s" 1"
	else
		s2n
		1+		\ increment the page number
		dup
		s" zfs_be_pages" getenv
		s2n
		> if drop 1 then
		n2s
	then

	s" zfs_be_currpage" setenv
	s" be-set-page" evaluate
	3 goto_menu
;

only forth definitions
