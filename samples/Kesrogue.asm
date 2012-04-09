;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                                  KESROGUE                                   ;
;                                                                             ;
;                                    v0.1                                     ;
;                                                                             ;
;  The first roguelike for the DCPU, the computer in Notch's new game, 0x10c  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Originally written by Ethan Kaminski (aka Soron) in 2012
; no other contributors (yet) - but feel free to help out ;)!
; written in DCPU assembly, targeted at the DCPU

; hereby released into the public domain (Unlicense/CC0 also acceptable)
; I would like it if you properly credit all major contributors
; but, at the same time, I don't want 0x10c to be constrained by IP laws

; use DCPU-16 Studio to run this, at least until I/O specs are finalized


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; the newest code will always be available on Github ;
; likewise, Github is where the documentation lives  ;
; URL: https://github.com/ethankaminski/Kesrogue     ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CURRENT VERSION: leaves registers the way it found them when you quit via Q ;
; This may be subject to change depending on how the specs/ecosystem work out ;
; (and also depending on how resource-hungry this ends up being, of course)   ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; key codes that might vary:
; left: 0x0001
; right: 0x0002
; up: 0x0003
; down: 0x0004
; enter: 0x000A (line feed, unix-style newline)
; backspace: 0x0008 (ASCII backspace)
; escape: 0x001B (ASCII escape)

; all printing characters (even shifted) are assumed to be mapped to their ASCII value

:polite_entrance
; store ALL THE REGISTERS
	SET PUSH, A
	SET PUSH, B
	SET PUSH, C
	SET PUSH, X
	SET PUSH, Y
	SET PUSH, Z
	SET PUSH, I
	SET PUSH, J
	SET [initial_stack_pointer], SP
	
	SET PC, init

:polite_exit
	SET SP, [initial_stack_pointer]
	SET J, POP
	SET I, POP
	SET Z, POP
	SET Y, POP
	SET X, POP
	SET C, POP
	SET B, POP
	SET A, POP
	SET PC, POP

:initial_stack_pointer
	DAT 0x0000

:init
	
	JSR is_prng_null
	IFN A, 0
		JSR init_prng
	
	JSR clear_screen
	SET A, text_welcome
	SET B, 0
	JSR print_text
	
	SET A, [screen_width]
	MUL A, 7
	SUB A, 16
	JSR get_string
	
	SET B, player_name
	SET C, 0x0010
	JSR copy_string_backward
	
	JSR clear_screen
	JSR gen_level
	
	JSR write_name
	
	SET [0x9000], 0
	
:game_loop
	SET A, [0x9000]
	IFE A, 0
		SET PC, game_loop
	SET [0x9000], 0
	IFE A, [key_up]
		JSR walk_up
	IFE A, [key_down]
		JSR walk_down
	IFE A, [key_left]
		JSR walk_left
	IFE A, [key_right]
		JSR walk_right
	IFE A, 0x0051 ; "Q"
		SET PC, polite_exit
	SET PC, game_loop

:hang	
	SUB PC, 1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SECTION: GAME LOGIC FUNCTIONS ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


:walk_up
	SET A, 0
	SET B, 0xFFFF
	JSR move_player
	SET PC, POP
:walk_down
	SET A, 0
	SET B, 1
	JSR move_player
	SET PC, POP
:walk_right
	SET A, 1
	SET B, 0
	JSR move_player
	SET PC, POP
:walk_left
	SET A, 0xFFFF
	SET B, 0
	JSR move_player
	SET PC, POP


; inputs:
; A: amount to move rightward
; B: amount to move downward
; uses unsigned arithmetic, so pass large values to get negatives

; this function moves the player to the requested position (if valid)
; if NOT valid, it silently ignores
; if the target position contains a bumpable object, it bumps that object

; clobbers A, B, C

:move_player
	SET PUSH, J
	SET J, SP
	
	; first, get the target position
	SET C, [player_y]
	ADD C, B
	MUL C, [dungeon_width]
	ADD C, [player_x]
	ADD C, A
	SET PUSH, C
	
	; is the target position off the map?
	SET C, [dungeon_width]
	MUL C, [dungeon_height]
	IFG PEEK, C
		SET PC, exit_move_player
	
	; is there a mob at the target position?
	SET C, PEEK
	MUL C, 2
	ADD C, level_data
	SET C, [C]
	IFG C, 0x00FF
		SET PC, bump_mob
	
	; is the terrain passable?
	AND C, 0x000F
	ADD C, terrain_passability_def
	IFG [C], 0
		SET PC, player_move_successful
	
	; okay, then, is it bumpable?
	SUB C, terrain_passability_def
	ADD C, terrain_bumpability_def
	IFG [C], 0
		SET PC, bump_terrain
	
	; if we got here, then we should just silently exit
	
:exit_move_player
	SET SP, J
	SET J, POP
	
	JSR tick
	
	; TODO see if we need to make this more efficient than a full redraw
	; if we do, it might need to be moved elsewhere
	JSR draw_map
	
	SET PC, POP

:bump_mob
	SET A, PEEK
	MUL A, 2
	ADD A, level_data
	; TODO *actually* implement this (needs HP and attack vals and such first)
	JSR kill_mob
	SET PC, exit_move_player

:bump_terrain
	; TODO implement this
	SET PC, exit_move_player

:player_move_successful
	; [SP] should be the tile index that we're moving to
	SET C, PEEK
	MUL C, 2 ; two words per tile, remember?
	ADD C, level_data
	BOR [C], [player_offset]
	
	SET C, [player_y]
	MUL C, [dungeon_width]
	ADD C, [player_x]
	MUL C, 2
	ADD C, level_data
	AND [C], 0x00FF
	
	ADD [player_x], A
	ADD [player_y], B
	
	SET PC, exit_move_player


:tick
	; TODO implement this
	SET PC, POP
	

;;;;;;;;;;;;;;;;;;;;;;;;;;
; SECTION: MAP FUNCTIONS ;
;;;;;;;;;;;;;;;;;;;;;;;;;;

; assume this clobbers everything for now
; (we can make it safe later if needed)

:gen_level
	JSR clear_level
	
	JSR rand
	SET B, [dungeon_width]
	SUB B, 2
	MOD A, B
	ADD A, 1
	SET [player_x], A
	JSR rand
	SET B, [dungeon_height]
	SUB B, 2
	MOD A, B
	ADD A, 1
	SET [player_y], A
	
	; A is still player_y, so we can place the player in level data real quick
	
	; first, get the row of level data we need
	MUL A, [dungeon_width]
	MUL A, 2
	; now the column
	ADD A, [player_x]
	ADD A, [player_x]
	; now convert that to an address
	ADD A, level_data
	; and put the player there!
	BOR [A], [player_offset]
	
	JSR rand
	SET B, [screen_width]
	SUB B, 4 ; 2 reserved columns, and 2 walls
	MOD A, B
	IFG 4, A
		SET A, 4
	SET X, A
	JSR rand
	SET B, [screen_height]
	SUB B, 4 ; 2 reserved rows, and 2 walls
	MOD A, B
	IFG 4, A
		SET A, 4
	SET Y, A
	
	
	JSR rand
	MOD A, Y
	SET B, A
	JSR rand
	MOD A, X
	
	; make sure that the room is on the screen
	; first: make sure that (player_x - left) > 0
	; i.e., the left WALL is not off the map
	
	; TODO - test this THOROUGHLY to make sure I understand it properly
	
	SET Z, [player_x]
	SUB Z, A
	SUB Z, 1
	IFG Z, [dungeon_width]
		ADD A, Z
	
	set Z, [player_y]
	SUB Z, B
	SUB Z, 1
	IFG Z, [dungeon_height]
		ADD B, Z
	
	; TODO make sure we don't exceed the right or bottom bounds
	
	SET [room_left], [player_x]
	SUB [room_left], A
	SUB [room_left], 1
	
	SET [room_top], [player_y]
	SUB [room_top], B
	SUB [room_top], 1
	
	SET [room_right], [room_left]
	ADD [room_right], X
	ADD [room_right], 2
	
	SET [room_bottom], [room_top]
	ADD [room_bottom], Y
	ADD [room_bottom], 2
	
	JSR furnish_room
	
	JSR place_first_mob ; TODO make this less hack-y
	
	JSR draw_map
	
	
	SET PC, POP


; clobbers A, B, C

:furnish_room
	SET B, [room_top]
	MUL B, [dungeon_width]
	MUL B, 2
	ADD B, level_data
	SET C, B
	
	ADD B, [room_left]
	ADD B, [room_left]
	ADD C, [room_right]
	ADD C, [room_right]
	
	; set up an end point
	SET PUSH, [room_bottom]
	MUL PEEK, [dungeon_width]
	MUL PEEK, 2
	ADD PEEK, level_data
	ADD PEEK, [room_right]
	
	SET A, B
	SET PC, build_horiz_wall_row
	
:furnish_room_loop
	ADD B, [dungeon_width]
	ADD B, [dungeon_width]
	ADD C, [dungeon_width]
	ADD C, [dungeon_width]
	
	SET A, B
	
	IFG C, PEEK
		SET PC, build_bottom_wall
	SET PC, build_next_room_row

:build_bottom_wall
	SET [A], [wall_tile]
	ADD A, 2
	IFG A, C
		SET PC, exit_furnish_room
	SET PC, build_bottom_wall
	
:build_horiz_wall_row
	SET [A], [wall_tile]
	ADD A, 2
	IFG A, C
		SET PC, furnish_room_loop
	SET PC, build_horiz_wall_row

:build_next_room_row
	IFE A, B
		SET PC, add_vert_wall
	IFE A, C
		SET PC, add_vert_wall
	AND [A], 0xFF00
	BOR [A], [empty_floor_tile]
	ADD A, 2
	SET PC, build_next_room_row
:add_vert_wall
	SET [A], [wall_tile]
	ADD A, 2
	IFG A, C
		SET PC, furnish_room_loop
	SET PC, build_next_room_row

:exit_furnish_room
	ADD SP, 1
	SET PC, POP
	

; clobbers A, B, C, X, Y, Z
; TODO should probably clean this up later
:draw_map
	; set up our drawing bounds
	SET B, 0x8000
	ADD B, [screen_width]
	ADD B, 1
	SET C, B
	ADD C, [screen_width]
	SUB C, 2
	
	; set up our level data bounds
	SET Y, [room_top]
	MUL Y, [dungeon_width]
	MUL Y, 2
	ADD Y, level_data
	ADD Y, [room_left]
	ADD Y, [room_left]
	
	; set up our drawing pointers
	SET A, B
	SET X, Y
	
	; set up an end condition
	SET PUSH, [screen_height]
	SUB PEEK, 1
	MUL PEEK, [screen_width]
	SUB PEEK, 1
	ADD PEEK, 0x8000

:draw_map_loop
	IFG [X], 0x00FF
		SET PC, draw_mob
	IFG	[X], 0x0000
		SET PC, draw_floor
	; huh, if we got here, there's nothing on this tile!
	SET [A], 0x0000
:draw_map_incr
	ADD A, 1
	IFG A, C
		SET PC, draw_map_nextline
	ADD X, 2
	SET PC, draw_map_loop

:draw_map_nextline
	ADD B, [screen_width]
	ADD C, [screen_width]
	
	IFG C, PEEK
		SET PC, exit_draw_map
	
	ADD Y, [dungeon_width]
	ADD Y, [dungeon_width]
	
	SET A, B
	SET X, Y
	SET PC, draw_map_loop

:draw_mob
	SET Z, [X]
	AND Z, 0xFF00
	IFE Z, [player_offset]
		SET PC, draw_player

	; get the mob ID
	SHR Z, 8
	SUB Z, 1
	MUL Z, 3
	ADD Z, mob_data ; okay, now we have the mob address
	SET Z, [Z]
	AND Z, 0x00FF ; mob type
	ADD Z, mob_tiles ; tile address
	SET [A], [Z]
	SET PC, draw_map_incr

:draw_player
	SET [A], [player_tile]
	SET PC, draw_map_incr

:draw_floor
	SET Z, [X]
	ADD Z, floor_tile_data
	SET [A], [Z]
	SET PC, draw_map_incr

:exit_draw_map
	ADD SP, 1 ; don't need that temporary variable any more
	
; DEBUG CODE follows
	JSR debug_dump_player_coords
	
	SET A, room_left
	SET B, 0x000C
	SET C, 4
	JSR print_mem_dump
; END DEBUG CODE
	
	SET PC, POP
	
	

; leaves registers how it found them
; no inputs taken

:clear_level
	SET PUSH, A
	SET PUSH, B
	SET A, SP
	SET SP, level_data
	SET B, [dungeon_width]
	MUL B, [dungeon_height]
	MUL B, 2 ; we're using 2 words per tile
	ADD B, SP
:clear_level_loop
	SET POP, 0
	IFG SP, B
		SET PC, exit_clear_level
	SET PC, clear_level_loop
:exit_clear_level
	SET SP, A
	SET B, POP
	SET A, POP
	SET PC, POP
	
;;;;;;;;;;;;;;;;;;;;;;;;;;
; SECTION: MOB FUNCTIONS ;
;;;;;;;;;;;;;;;;;;;;;;;;;;

; this one is pretty hacky right now
; also, clobbers A and B

:place_first_mob
	SET A, [player_x];
	SUB A, 1;
	IFE A, [room_left]
		ADD A, 2
	
	SET B, mob_data
	SET [B], 0x0001 ; harmless rabbit (for now)
	
	; set the position
	ADD B, 2
	SHL A, 8
	SET [B], A ; X
	SET A, [player_y]
	BOR [B], A ; Y
	
	SET A, 1 ; ID of first mob
	JSR place_mob_on_map
	SET PC, POP


; inputs:
; A: ID of mob to place

; clobbers B and C, and shifts A to the upper byte

; note: does *not* check to make sure the tile is empty!

:place_mob_on_map
	SET C, A
	SUB C, 1
	MUL C, 3
	ADD C, mob_data
	ADD C, 2
	SET B, [C]
	AND B, 0x00FF
	MUL B, [dungeon_width]
	SET C, [C]
	AND C, 0xFF00
	SHR C, 8
	ADD B, C
	MUL B, 2
	ADD B, level_data
	;okay, now we have the address we need to write to
	
	SHL A, 8
	BOR [B], A
	
	SET PC, POP
	

; inputs:
; A: tile address that the mob lives on

; clobbers B

:kill_mob
	SET B, [A]
	SHR B, 8
	AND [A], 0x00FF ; wipe the tile first
	
	
	SUB B, 1
	MUL B, 3
	ADD B, mob_data ; get the address to work at
	SET [B], 0
	ADD B, 1
	SET [B], 0
	ADD B, 1	
	SET [B], 0
	
	SET PC, POP

;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SECTION: PRNG FUNCTIONS ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

; output:
; A: pseudorandom number

:rand
	MUL [prng_state], 31421
	MUL [prng_state], 6927
	SET A, [prng_state]
	SET PC, POP

; returns 1 if prng state is zero
; returns 0 otherwise
:is_prng_null
	IFE [prng_state], 0
		SET A, 1
	SET PC, POP

:init_prng
	JSR clear_screen
	SET A, text_seed_entropy
	SET B, 0
	JSR print_text
:prng_seed_loop
	SET A, [0x9000]
	IFE A, 0
		SET PC, prng_seed_loop
	IFE A, [key_newline]
		SET PC, POP
	ADD [prng_state], 1 ; so that we don't get stuck on 0
	MUL [prng_state], A
	SET [0x9000], 0
	
; DEBUG code
	SET A, prng_state
	SET B, [screen_height]
	SUB B, 1
	MUL B, [screen_width]
	SET C, 1
	JSR print_mem_dump
; end DEBUG code
	
	SET PC, prng_seed_loop


;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SECTION: TEXT FUNCTIONS ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
; input:
; A: pointer to c-string to be printed
; B: offset to print at

; clobbers B and increments A all the way to the end of the c-string

:print_text
	ADD B, 0x8000
:print_text_loop
	IFE [A], 0x0000
		SET PC, POP
	IFE [A], 0x000A
		SET PC, print_text_newline
	SET [B], [A]
	BOR [B], 0xF000
	ADD A, 1
	ADD B, 1
	SET PC, print_text_loop

:print_text_newline
	SUB B, 0x8000
	DIV B, [screen_width]
	ADD B, 1
	MUL B, [screen_width]
	ADD B, 0x8000
	ADD A, 1
	SET PC, print_text_loop


; inputs:
; A: position to place the cursor (offset)

; outputs:
; A: a pointer to where the string resides (on the stack! be careful to copy it ASAP)

; clobbers B and C

:get_string
	SET B, SP
	ADD A, 0x8000
	SET [A], [cursor_char]
	SET [0x9000], 0
:get_string_loop
	SET C, [0x9000]
	IFE C, 0
		SET PC, get_string_loop
	SET [0x9000], 0
	IFE C, [key_newline]
		SET PC, exit_get_string
	IFE C, [key_backspace]
		SET PC, get_string_backspace
	SET PUSH, C
	SET [A], PEEK
	BOR [A], 0xF000
	ADD A, 1
	SET [A], [cursor_char]
	SET PC, get_string_loop

:get_string_backspace
	SET POP, 0
	SET [A], 0
	SUB A, 1
	SET [A], [cursor_char]
	SET PC, get_string_loop

:exit_get_string
	SET PUSH, 0x0000
	SET SP, B
	SET A, B
	SUB A, 1
	SET PC, POP


; no inputs
; clobbers A and B
; writes name to lower-left corner (16 chars only)

:write_name
	SET A, player_name
	SET B, [screen_height]
	SUB B, 1
	MUL B, [screen_width]
	JSR print_text
	SET PC, POP


; inputs:
; A: source string pointer (backwards, e.g. on the stack)
; B: destination string pointer
; C: maximum length of B (not including the null terminator)

; clobbers A, B and C, but ensures that the dest string is null-terminated

:copy_string_backward
	IFE C, 0
		SET PC, exit_copy_string
	IFE [A], 0
		SET PC, exit_copy_string
	SUB C, 1
	SET [B], [A]
	ADD B, 1
	SUB A, 1
	SET PC, copy_string_backward

:exit_copy_string
	ADD B, 1
	SET [B], 0
	SET PC, POP

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SECTION: UTILITY FUNCTIONS ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; leaves registers how it found them
; no inputs taken

:clear_screen
	SET PUSH, A
	SET PUSH, B
	SET A, SP
	SET SP, 0x8000
	SET B, [screen_width]
	MUL B, [screen_height]
	ADD B, 0x8000
:clear_screen_loop
	SET POP, 0
	IFG SP, B
		SET PC, exit_clear_screen
	SET PC, clear_screen_loop
:exit_clear_screen
	SET SP, A
	SET B, POP
	SET A, POP
	SET PC, POP
	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SECTION: DEBUG FUNCTIONS ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; inputs:
; A: position to start dumping from
; B: offset on screen to start writing to
; C: length to dump

; do note that B+C should not be greater than width*height, or memory may be corrupted

; B is progressively incremented here
; I is used as an iterator

:print_mem_dump
	SET PUSH, I
	SET PUSH, X
	SET I, 0
	SET X, A
	ADD B, 0x8000
:mem_dump_loop
	SET A, [X]
	AND A, 0xf000
	SHR A, 12
	JSR write_hex
	
	SET A, [X]
	AND A, 0x0f00
	SHR A, 8
	JSR write_hex
	
	SET A, [X]
	AND A, 0x00f0
	SHR A, 4
	JSR write_hex
	
	SET A, [X]
	AND A, 0x000f
	JSR write_hex
	
	SET [B], 0xF020 ; write a space to screen
	ADD B, 1
	
	ADD X, 1
	ADD I, 1
	
	IFG C, I
		SET PC, mem_dump_loop
		
:exit_mem_dump
	SET X, POP
	SET I, POP
	SET PC, POP


; writes the lowest nybble of A to screen position B
; clobbers A and increments B by 1

:write_hex
	AND A, 0x000F
	ADD A, 0xF030 ; we want (A | 0xF000) + 30, but A is 4 bits, so A + 0x7030 is safe
	IFG A, 0xF039 ; check if A is A-F, which are offset a little higher (*sigh*)
		ADD A, 7
	SET [B], A
	ADD B, 1
	SET PC, POP


; clobbers A, B, C

:debug_dump_player_coords
	SET A, player_x
	SET B, 0
	SET C, 2
	JSR print_mem_dump
	SET PC, POP

;;;;;;;;;;;;;;;;;;;;;;
; SECTION: CONSTANTS ;
;;;;;;;;;;;;;;;;;;;;;;

:dungeon_width
	DAT 0x0080
:dungeon_height
	DAT 0x0040
:screen_width
	DAT 32
:screen_height
	DAT 16
	
:key_up
	DAT 0x0003
:key_down
	DAT 0x0004
:key_left
	DAT 0x0001
:key_right
	DAT 0x0002
:key_newline
	DAT 0x000A ; ASCII line feed (Unix-style \n)
:key_backspace
	DAT 0x0008 ; ASCII backspace char

:cursor_char
	DAT 0x0700

:player_offset ; for purposes of placing the player on a tile
	DAT 0xFF00

;;;;;;;;;;;;;;;;;;;;
; SECTION: CONTENT ;
;;;;;;;;;;;;;;;;;;;;

:mob_tiles
; 0x000? block
	DAT 0x0000 ; this one should be empty
	DAT 0x7072 ; light gray r
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x001? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x002? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x003? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x004? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x005? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x006? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x007? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x008? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x009? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x00A? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x00B? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x00C? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x00D? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x00E? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x00F? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
:player_tile
	DAT 0xF040 ; mob_tiles + 0x00FF

:empty_floor_tile
	DAT 0x0001
:wall_tile
	DAT 0x000F

; floor tiles:
; 0 = void
; 1 = empty floor
; F = wall

:terrain_passability_def
	DAT 0x0000
	DAT 0x0001
	DAT 0x0001
	DAT 0x0001
	
	DAT 0x0001
	DAT 0x0001
	DAT 0x0001
	DAT 0x0001
	
	DAT 0x0001
	DAT 0x0001
	DAT 0x0001
	DAT 0x0001
	
	DAT 0x0001
	DAT 0x0001
	DAT 0x0001
	DAT 0x0000

:terrain_bumpability_def
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000

; this floor tile data could probably be condensed, once we figure out
; what the second nybble (0x00?0) is used for! After all, it IS a flag

:floor_tile_data
; comes in blocks of 16

; 0x000? block
	DAT 0x0000
	DAT 0xF02E ; floor
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0700 ; wall (light gray)
	
; 0x001? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x002? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x003? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x004? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x005? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x006? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x007? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x008? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x009? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x00A? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x00B? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x00C? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x00D? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x00E? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
; 0x00F? block
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000

;;;;;;;;;;;;;;;;;
; SECTION: TEXT ;
;;;;;;;;;;;;;;;;;

; this uses c-strings

:text_welcome
	DAT "       Welcome to Kesrogue,"
	DAT 0x000A
	DAT "    the first DCPU roguelike!"
	DAT 0x000A
	DAT 0x000A
	DAT "Enter your name:"
	DAT 0x0000

:text_seed_entropy
	DAT "Type a bit to seed the entropy"
	DAT 0x000A
	DAT 0x000A
	DAT "Press enter when you're done"
	DAT 0x0000

;;;;;;;;;;;;;;;;;;;;;;;;;;
; SECTION: VARIABLE DATA ;
;;;;;;;;;;;;;;;;;;;;;;;;;;

:prng_state
	DAT 0x0000

:player_name ; up to 16 chars allowed (plus a terminal 0x0000)
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	DAT 0x0000
	
	DAT 0x0000

:player_x
	DAT 0x0000
:player_y
	DAT 0x0000

; TODO make this robust enough to handle more than one room
:room_left
	DAT 0x0000
:room_top
	DAT 0x0000
:room_right
	DAT 0x0000
:room_bottom
	DAT 0x0000
	

; mobs are stored in 3 words
; first word: lower byte = mob type, upper byte = mob state (bitmask)
; second word: lower byte = HP, upper byte = MP (tentative)
; third word: lower byte = Y position, upper byte = X position

; we only need room for 254 mobs

:mob_data
; block of 16
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	
	
	
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	
	
	
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	
	
	
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	DAT 0x0000, 0x0000, 0x0000
	;we DO NOT need these last two; only 254 mobs!
;	DAT 0x0000, 0x0000, 0x0000
;	DAT 0x0000, 0x0000, 0x0000
	
	
	

; dungeon tile stored as 2 words
; tile type stored on the lowest nybble of the first word
; the next nybble is reserved for temporary tile data
; highest byte stores a mob ID (player at 255, and up to 254 mobs allowed)
; note that a null value is EMPTY
; item stored on second word


; items are stored in 1 (?) byte, with the content ID on the low byte
; the high byte is used to indicate the enchantment (may need more space...?)

:level_data
	; we need to reserve a LOT of space... each string is 64 chars long, so we need 256 of them
	; each BLOCK is 16 strings long, so we need 16
	; there are 3 blank lines every 4th block
	; yes, this is massive. Hopefully we don't need to store too much else >_>...
	
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	
	
	
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	
	
	
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	
	
	
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	DAT "0123456789ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef"
	
	

; terminate the data block

	DAT 0xDEAD
	DAT 0xBEEF
	DAT 0xDEAD
	DAT 0xBEEF