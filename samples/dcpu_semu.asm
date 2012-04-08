; DCPU sandboxing emultator for DCPU
;
;	dpu-semu is an emulator for DCPU written in DCPU assembly language.
;
;
; Copyright 2012 Brian Monkaba
;
; This file is part of dcpu_semu.
;
;    dcpu_semu is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.
;
;    dcpu_semu is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.
;
;    You should have received a copy of the GNU General Public License
;    along with dcpu_semu.  If not, see <http://www.gnu.org/licenses/>.

; EMU register useage
; A = a (instruction not register)
; B = b (instruction not register)
; C = instuction (opcode)
; X = virtual register array pointer
; Y = temp storage / value a / decoded value a
; Z = temp storage
; I = virtual PC
; J = temp storage / value b / decoded value b
; SP is not used by the emulator

; virtual process register structure
; (X register points to the active process)
; X + 0x0 = A
; X + 0x1 = B
; X + 0x2 = C
; X + 0x3 = X
; X + 0x4 = Y
; X + 0x5 = Z
; X + 0x6 = I
; X + 0x7 = J
; X + 0x8 = OVERFLOW
; X + 0x9 = PC
; X + 0xA = SP
; X + 0xB = TICK
; X + 0xC = TIMER (will be used for priority task switching) (TODO)
; X + 0xD = virtual memory address offset (virtual 0x00 -- TODO)
; X + 0xE = virtual memory size (TODO)
; X + 0xF = process permissions (i/o guard) (TODO)
; X + 0x10 = SP upper bound (TODO)
; X + 0x11 = SP lower bound (TODO)

; memory layout
; 0x0000 - 0x0700 	emu core
; 0x2000 - 0x2011 	program one virtual registers
; 0x2020 - 0x2031	program two virtual registers
; 0x8000 - 0x8200 	terminal
; 0xDEAD		pointer storage for indirect 
;			loaded 'a' values, used for write backs
; 0xFFFF		stack space for program 1
; 0xFFFA		stack space for program 2


; quick summary:
;
;	before emulation begins the look up tables are built
;	for read / execute / write cpu operations
;
;	walk through of an emulation cycle:
;	1) load the instruction pointed to by the virtual PC
;	2) deconstruct the op code into the three components:
;		a) opcode is stored in C
;		b) value type (see cpu spec) is stored in A for 'a' 
;		c) value type (see cpu spec) is stored in B for 'b
;	3) values are decoded (loaded), value of 'a' is stored in Y, 'b' in J
;	4) opcode is executed (ex: SET Y, J)
;	5) result is stored (write back)
;	6) post execute increments PC if needed and implements EMU features (ex: TICK)
;
;	load->decode->execute->writeback->postexe


;
; initialize the virtual register arrays
;

:init
	;set up the virtual register arrays
	SET X, 0x2000
	SET [0x00+X], 0x00	;A
	SET [0x01+X], 0x00	;B
	SET [0x02+X], 0x00	;C
	SET [0x03+X], 0xFFFF	;X
	SET [0x04+X], 0x00	;Y
	SET [0x05+X], 0x7FFF	;Z
	SET [0x06+X], 0x00	;I
	SET [0x07+X], 0x00	;J
	SET [0x08+X], 0x00	;OVERFLOW
	SET [0x09+X], test_pgmb	;PC
	SET [0x0A+X], 0xFFFB	;SP
	SET [0x0B+X], 0x00	;TICK
	SET [0x0C+X], 0x00	;TIMER

	SET X, 0x2020
	SET [0x00+X], 0x5A	;A
	SET [0x01+X], 0x5A	;B
	SET [0x02+X], 0x5A	;C
	SET [0x03+X], 0x5A5A	;X
	SET [0x04+X], 0x5A	;Y
	SET [0x05+X], 0x8150	;Z
	SET [0x06+X], 0x5A	;I
	SET [0x07+X], 0x5A	;J
	SET [0x08+X], 0x5A	;OVERFLOW
	SET [0x09+X], test_pgma	;PC
	SET [0x0A+X], 0x00	;SP
	SET [0x0B+X], 0x00	;TICK
	SET [0x0C+X], 0x00	;TIMER
;
; initialize the point look up tables for read/execute/write cpu operations
;
	SET PC, gen_lookup_tables

;
; Start the emulation
;
;	emulation is broken down into four steps:
;		1) get/decode instruction
;		2) read values 
;		3) execute instruction
;		4) write value a

:begin
:load_inst
	;simple task switching 
	;toggle between the two programs every virtual instruction cycle
	XOR X, 0x0020	;toggle virtual register arrays (0x2000,0x2020)
	
	;load PC into I
	SET I, [0x09+X] 
	
	;load the raw opcode into the registers
	SET A, [I] ;a
	SET B, [I] ;b
	SET C, [I] ;instruction

	SET Y, C	;check for extended instruction (Y used as temp register)
	AND Y, 0x0F	;if lower 4 bits are 0, then is extended instruction 
	IFE Y, 0  
	SET PC, load_extended 
	SET PC, load_basic

:load_extended
	;decompose (shift/mask) the instruction into opcode, b
	;(b is the 6 bit value type, a is not used for extended opcodes)
	SHR A, 0x0A	
	AND A, 0x003F	;a
	SET B, 0	;b
	SHR C, 0x04	;lower 4 bits not used
	AND C, 0x3F	;mask the 6 bit instruction
	BOR C, 0x100	;set a temporary bit flag to indicate an extended instruction
	SET PC, decode_val

:load_basic
	;decompose (shift/mask) the instruction into opcode, a, b
	;(a and b are 6 bit value types)
	SHR A, 0x04	;a
	AND A, 0x3F
	SHR B, 0x0A	
	AND B, 0x3F	;b
	AND C, 0x0F	;4 bit instruction
	SET PC, decode_val

:decode_val
	SET J, 0x00   ;clear the registers
	SET Y, 0x00   ;which will hold the decoded values
	SET PC, decode_val_a

:decode_val_a
	;look up and goto the read type handler
	SET Z, 0x5000 ; decode look up table
	ADD Z, A      ; add the value type offset
	SET PC, [Z]

:decode_val_cont
	;decode happens in two passes, the first pass
	;loads a, the second b. the code below handles the
	;decode state.
	IFG C, 0x7FFF
	SET PC, decode_val_done
	SET PC, decode_val_b

:decode_val_b
	BOR C, 0x8000 ; set msb bit of C to tell
		      ; decode_val_cont the value b
		      ; has been loaded
	SET Z, 0x5000 ; decode look up table
	ADD Z, B      ; add the value type offset
	SET PC, [Z]   ; goto the handler
	
:decode_val_done
	AND C, 0x7FFF ; clear the temp bit flag used
		      ; durring the decode state
	SET PC, exe_instruction

:exe_instruction
	; at this point the values a & b have been loaded
	; into registers Y and J. Next step is to execute
	; the opcode.
	IFG C, 0xFF	     ; check to see if the temp bit flag 
			     ; was set indicating extended instruction
	SET PC, exe_extended ; extended instruction
	SET PC,	exe_basic    ; basic instruction

:exe_extended		; execute an extended instruction
	AND C, 0x3F	; clear the extended instruction bit flag
	SET Z, 0x6F80	; extended instruction look up table
	ADD Z, C	; add the instruction offset (op code value)
	SET PC, [Z]	; goto the handler
:exe_basic	      ; execute a basic instruction
	SET Z, 0x6000 ; basic instruction look up table
	ADD Z, C      ; add the instruction offset (op code value)
	SET PC, [Z]   ; goto the handler

:write_back
	; goto the write back handler to store the result
	SET Z, 0x5100 ; write back look up table
	ADD Z, A      ; add offset (write back type)
	SET PC, [Z]

:post_exe_skip_next
	ADD I, 0x01		; increment the PC to
	SET Z, [I]		; get the next instruction
	AND Z, 0x0F 		; test for extended instruction
	IFE Z, 0X00		; extended instructions are one word
	SET PC, post_exe	; jump to the normal handler and continue  
				; else, get the value types
	SET A, [I]	 	; a
	SET B, [I] 		; b	
	SHR A, 0x04		; decompose (shift/mask) the instruction into a, b
	AND A, 0x3F		; (a and b are 6 bit value types)
	SHR B, 0x0A	
	AND B, 0x3F	
				; next byte value types increment the PC (from DCPU spec):
				; 0x10-0x17: [next word + register]
				; 0x1e: [next word]
				; 0x1f: next word (literal)
				; if in this range increment the PC
	IFG 0x10, A				; test len of values	;A < 0x10 (16)
	SET PC, post_exe_skip_next_testb	; a is embedded
	IFG A, 0x1F							;A > 0x1F (31)
	SET PC, post_exe_skip_next_testb	; a is embedded
	IFG 0x18, A							;A < 18
	ADD I, 0x01				; a is in next word
	IFG A, 0x1D
	ADD I, 0x01				; a is in next word
:post_exe_skip_next_testb
	IFG 0x10, B
	SET PC, post_exe			; b is embedded
	IFG B, 0x1F
	SET PC, post_exe			; b is embedded
	IFG 0x18, B
	ADD I, 0x01				; b is in next word
	IFG B, 0x1D
	ADD I, 0x01				; b is in next word
	;continue into post_exe
:post_exe			; called post execution
	ADD I, 0x01		; increment the PC
	SET [0x09+X], I		; store the updated PC
:post_exe_dont_update_pc	; called post execution when the PC
				; was modifed by the opcode (JSR or SET PC)
	ADD [0x0B+X], 1		; increment the TICK counter
	SET PC, load_inst	; continue with the next instruction

;
;instruction implementation
;	at this point the values a & b have been loaded
;	into Y & J. I holds the virtual PC.

:_set
	SET Y, J
	SET PC, write_back
:_add
	ADD Y, J
	SET [0x08+X],O	;capture overflow register
	SET PC, write_back

:_sub
	SUB Y, J
	SET [0x08+X],O	;capture overflow register
	SET PC, write_back

:_mul
	MUL Y, J
	SET [0x08+X],O	;capture overflow register
	SET PC, write_back

:_div
	DIV Y, J
	SET [0x08+X],O	;capture overflow register
	SET PC, write_back

:_mod
	MOD Y, J
	SET [0x08+X],O	;capture overflow register
	SET PC, write_back

:_shl
	SHL Y, J
	SET [0x08+X],O	;capture overflow register
	SET PC, write_back

:_shr
	SHR Y, J
	SET [0x08+X],O	;capture overflow register
	SET PC, write_back

:_and
	AND Y, J
	SET PC, write_back

:_bor
	BOR Y, J
	SET PC, write_back

:_xor
	XOR Y, J
	SET PC, write_back

					; branching instructions dont write back, jump to post exe
					; instructions may be more than 1 word in length, skip
					; next instruction for false compares.
:_ife
	IFE Y, J
	SET PC, post_exe			
	SET PC, post_exe_skip_next
:_ifn
	IFN Y, J
	SET PC, post_exe
	SET PC, post_exe_skip_next
:_ifg
	IFG Y, J
	SET PC, post_exe
	SET PC, post_exe_skip_next
:_ifb
	IFB Y, J
	SET PC, post_exe
	SET PC, post_exe_skip_next
:_jsr
	SET B, [0x0A+X]	;load the SP address
	SUB B, 1	;decrement the pointer
	ADD I, 0x01	;increment the PC (point to the next instruction)
	SET [B], I	;write the PC to the stack
	SET [0x0A+X],B	;store the SP
	SET [0x09+X], Y	;load a into the PC
	SET PC, post_exe_dont_update_pc

;
;
;value loader
;
; - the following routines load the value types.
;   value a is stored in Y and value b is stored in J
;   the same routines are called for both a and b
;   high bit of C is used to flag the load destination
;
;   the pointer for an indirect load of value a is stored 
;   for post-execution write back. 
;   the exception is [register] loads, in this case the virtual
;   registers already contain the address.

;
; REG _A
;

:_ld_a			;direct load register a into value a or b
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _ld_a_b
	SET PC, _ld_a_a
:_ld_a_a
	SET Y, [X]
	SET PC, decode_val_cont
:_ld_a_b
	SET J, [X]
	SET PC, decode_val_cont

:_lid_a			;indirect load register a into value a or b
	SET Z, [X]	;dereference the pointer
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _lid_a_b
	SET PC, _lid_a_a
:_lid_a_a
	SET Y, [Z]
	SET PC, decode_val_cont
:_lid_a_b
	SET J, [Z]
	SET PC, decode_val_cont

:_lido_a		;indirect load (with offset) register a into value a or b
	ADD I, 0x01	;inc the PC
	SET Z, [X]	;load from register a
	ADD Z, [I]	;add the next word
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _lido_a_b
	SET PC, _lido_a_a
:_lido_a_a
	SET [0xDEAD], Z ;save the pointer
	SET Y, [Z]
	SET PC, decode_val_cont
:_lido_a_b
	SET J, [Z]
	SET PC, decode_val_cont


;
; REG B
;

:_ld_b			;direct load register a into value a or b
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _ld_b_b
	SET PC, _ld_b_a
:_ld_b_a
	SET Y, [0x01+X]
	SET PC, decode_val_cont
:_ld_b_b
	SET J, [0x01+X]
	SET PC, decode_val_cont


:_lid_b			;indirect load register a into value a or b
	SET Z, [0x01+X]	;dereference the pointer
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _lid_b_b
	SET PC, _lid_b_a
:_lid_b_a
	SET Y, [Z]
	SET PC, decode_val_cont
:_lid_b_b
	SET J, [Z]
	SET PC, decode_val_cont

:_lido_b		;indirect load (with offset) register into value a or b
	ADD I, 0x01	;inc the PC
	SET Z, [0x01+X]	;load from register
	ADD Z, [I]	;add the next word
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _lido_b_b
	SET PC, _lido_b_a
:_lido_b_a
	SET [0xDEAD], Z ;save the pointer
	SET Y, [Z]
	SET PC, decode_val_cont
:_lido_b_b
	SET J, [Z]
	SET PC, decode_val_cont

;
; REG C
;

:_ld_c			;direct load register into value a or b
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _ld_c_b
	SET PC, _ld_c_a
:_ld_c_a
	SET Y, [0x02+X]
	SET PC, decode_val_cont
:_ld_c_b
	SET J, [0x02+X]
	SET PC, decode_val_cont


:_lid_c			;indirect load register into value a or b
	SET Z, [0x02+X]	;dereference the pointer
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _lid_c_b
	SET PC, _lid_c_a
:_lid_c_a
	SET Y, [Z]
	SET PC, decode_val_cont
:_lid_c_b
	SET J, [Z]
	SET PC, decode_val_cont

:_lido_c		;indirect load (with offset) register into value a or b
	ADD I, 0x01	;inc the PC
	SET Z, [0x02+X]	;load from register
	ADD Z, [I]	;add the next word
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _lido_c_b
	SET PC, _lido_c_a
:_lido_c_a
	SET [0xDEAD], Z ;save the pointer
	SET Y, [Z]
	SET PC, decode_val_cont
:_lido_c_b
	SET J, [Z]
	SET PC, decode_val_cont


;
; REG X
;

:_ld_x			;direct load register into value a or b
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _ld_x_b
	SET PC, _ld_x_a
:_ld_x_a
	SET Y, [0x03+X]
	SET PC, decode_val_cont
:_ld_x_b
	SET J, [0x03+X]
	SET PC, decode_val_cont


:_lid_x			;indirect load register into value a or b
	SET Z, [0x03+X]	;dereference the pointer
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _lid_x_b
	SET PC, _lid_x_a
:_lid_x_a
	SET Y, [Z]
	SET PC, decode_val_cont
:_lid_x_b
	SET J, [Z]
	SET PC, decode_val_cont

:_lido_x		;indirect load (with offset) register into value a or b
	ADD I, 0x01	;inc the PC
	SET Z, [0x03+X]	;load from register
	ADD Z, [I]	;add the next word
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _lido_x_b
	SET PC, _lido_x_a
:_lido_x_a
	SET [0xDEAD], Z ;save the pointer
	SET Y, [Z]
	SET PC, decode_val_cont
:_lido_x_b
	SET J, [Z]
	SET PC, decode_val_cont

;
; REG Y
;

:_ld_y			;direct load register into value a or b
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _ld_y_b
	SET PC, _ld_y_a
:_ld_y_a
	SET Y, [0x04+X]
	SET PC, decode_val_cont
:_ld_y_b
	SET J, [0x04+X]
	SET PC, decode_val_cont


:_lid_y			;indirect load register into value a or b
	SET Z, [0x04+X]	;dereference the pointer
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _lid_y_b
	SET PC, _lid_y_a
:_lid_y_a
	SET Y, [Z]
	SET PC, decode_val_cont
:_lid_y_b
	SET J, [Z]
	SET PC, decode_val_cont

:_lido_y		;indirect load (with offset) register into value a or b
	ADD I, 0x01	;inc the PC
	SET Z, [0x04+X]	;load from register
	ADD Z, [I]	;add the next word
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _lido_y_b
	SET PC, _lido_y_a
:_lido_y_a
	SET [0xDEAD], Z ;save the pointer
	SET Y, [Z]
	SET PC, decode_val_cont
:_lido_y_b
	SET J, [Z]
	SET PC, decode_val_cont

;
; REG Z
;

:_ld_z			;direct load register into value a or b
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _ld_z_b
	SET PC, _ld_z_a
:_ld_z_a
	SET Y, [0x05+X]
	SET PC, decode_val_cont
:_ld_z_b
	SET J, [0x05+X]
	SET PC, decode_val_cont


:_lid_z			;indirect load register into value a or b
	SET Z, [0x05+X]	;dereference the pointer
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _lid_z_b
	SET PC, _lid_z_a
:_lid_z_a
	SET Y, [Z]
	SET PC, decode_val_cont
:_lid_z_b
	SET J, [Z]
	SET PC, decode_val_cont

:_lido_z		;indirect load (with offset) register into value a or b
	ADD I, 0x01	;inc the PC
	SET Z, [0x05+X]	;load from register
	ADD Z, [I]	;add the next word
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _lido_z_b
	SET PC, _lido_z_a
:_lido_z_a
	SET [0xDEAD], Z ;save the pointer
	SET Y, [Z]
	SET PC, decode_val_cont
:_lido_z_b
	SET J, [Z]
	SET PC, decode_val_cont

;
; REG I
;

:_ld_i			;direct load register into value a or b
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _ld_i_b
	SET PC, _ld_i_a
:_ld_i_a
	SET Y, [0x06+X]
	SET PC, decode_val_cont
:_ld_i_b
	SET J, [0x06+X]
	SET PC, decode_val_cont


:_lid_i			;indirect load register into value a or b
	SET Z, [0x06+X]	;dereference the pointer
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _lid_i_b
	SET PC, _lid_i_a
:_lid_i_a
	SET Y, [Z]
	SET PC, decode_val_cont
:_lid_i_b
	SET J, [Z]
	SET PC, decode_val_cont

:_lido_i		;indirect load (with offset) register into value a or b
	ADD I, 0x01	;inc the PC
	SET Z, [0x06+X]	;load from register 
	ADD Z, [I]	;add the next word
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _lido_i_b
	SET PC, _lido_i_a
:_lido_i_a
	SET [0xDEAD], Z ;save the pointer
	SET Y, [Z]
	SET PC, decode_val_cont
:_lido_i_b
	SET J, [Z]
	SET PC, decode_val_cont

;
; REG J
;

:_ld_j			;direct load register into value a or b
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _ld_j_b
	SET PC, _ld_j_a
:_ld_j_a
	SET Y, [0x07+X]
	SET PC, decode_val_cont
:_ld_j_b
	SET J, [0x07+X]
	SET PC, decode_val_cont


:_lid_j			;indirect load register into value a or b
	SET Z, [0x07+X]	;dereference the pointer
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _lid_j_b
	SET PC, _lid_j_a
:_lid_j_a
	SET Y, [Z]
	SET PC, decode_val_cont
:_lid_j_b
	SET J, [Z]
	SET PC, decode_val_cont

:_lido_j		;indirect load (with offset) register into value a or b
	ADD I, 0x01	;inc the PC
	SET Z, [0x07+X]	;load from register a
	ADD Z, [I]	;add the next word
	IFG C, 0x7FFF	;if high bit set load into value b
	SET PC, _lido_j_b
	SET PC, _lido_j_a
:_lido_j_a
	SET [0xDEAD], Z ;save the pointer
	SET Y, [Z]
	SET PC, decode_val_cont
:_lido_j_b
	SET J, [Z]
	SET PC, decode_val_cont


;
;stack/memory/literal loads
;

:_lpop				;read and pop from the stack
	SET Z, [0x0A+X]		; read
	ADD [0x0A+X], 0x01	; pop (post increment the SP)
	IFG C, 0x7FFF		;if high bit set load into value b
	SET PC, _lpop_b
	SET PC, _lpop_a
:_lpop_a
	SET [0xDEAD], Z 	; save the pointer
	SET Y, [Z]
	SET PC, decode_val_cont
:_lpop_b
	SET J, [Z]
	SET PC, decode_val_cont

:_lpeek				;load peek
	SET Z, [0x0A+X]		;read stack value
	IFG C, 0x7FFF		;if high bit set load into value b
	SET PC, _lpeek_b
	SET PC, _lpeek_a
:_lpeek_a
	SET [0xDEAD], Z 	; save the pointer
	SET Y, [Z]
	SET PC, decode_val_cont
:_lpeek_b
	SET J, [Z]
	SET PC, decode_val_cont

:_lpush				;load push
	SUB [0x0A+X], 0x01	;push (pre decrement the SP)
	SET Z, [0x0A+X]		;get the SP
	IFG C, 0x7FFF		;if high bit set load into value b
	SET PC, _lpush_b
	SET PC, _lpush_a
:_lpush_a
	SET [0xDEAD], Z 	;save the pointer for write back (address)
	SET Y, [Z]		;dereference the pointer and get the value
	SET PC, decode_val_cont
:_lpush_b
	SET J, [Z]
	SET PC, decode_val_cont

:_lsp				;load the stack pointer register
	IFG C, 0x7FFF		;if high bit set load into value b
	SET PC, _lsp_b
	SET PC, _lsp_a
:_lsp_a
	SET Y, [0x0A+X]
	SET PC, decode_val_cont
:_lsp_b
	SET J, [0x0A+X]
	SET PC, decode_val_cont

:_lpc				;load the program counter
	IFG C, 0x7FFF		;if high bit set load into value b
	SET PC, _lpc_b
	SET PC, _lpc_a
:_lpc_a
	SET Y, [0x09+X]
	SET PC, decode_val_cont
:_lpc_b
	SET J, [0x09+X]
	SET PC, decode_val_cont


:_lo				;load the overflow register
	IFG C, 0x7FFF		;if high bit set load into value b
	SET PC, _lo_b
	SET PC, _lo_a
:_lo_a
	SET Y, [0x08+X]
	SET PC, decode_val_cont
:_lo_b
	SET J, [0x08+X]
	SET PC, decode_val_cont


:_lidw				;load indirect next word
	ADD I, 0x01		;inc the PC
	SET Z, [I]		;load the next word
	IFG C, 0x7FFF		;if high bit set load into value b
	SET PC, _lidw_b
	SET PC, _lidw_a
:_lidw_a
	SET [0xDEAD], Z 	;save the pointer for write back (address)
	SET Y, [Z]		;dereference the pointer and get the value
	SET PC, decode_val_cont
:_lidw_b
	SET J, [Z]
	SET PC, decode_val_cont

:_ldw				;load literal next word
	ADD I, 0x01		;inc the PC
	IFG C, 0x7FFF		;if high bit set load into value b
	SET PC, _ldw_b
	SET PC, _ldw_a
:_ldw_a
	SET Y, [I]
	SET PC, decode_val_cont
:_ldw_b
	SET J, [I]
	SET PC, decode_val_cont

:_llv				;load literal value
	IFG C, 0x7FFF		;if high bit set load into value b
	SET PC, _llv_b
	SET PC, _llv_a
:_llv_a
	SET Y, A
	SUB Y, 0x20		;subtract 0x20 to get the actual literal value
	SET PC, decode_val_cont
:_llv_b
	SET J, B
	SUB J, 0x20		;subtract 0x20 to get the actual literal value
	SET PC, decode_val_cont

;
; value writer
;
; - post execute write back operation (store the result)
;

:_wd_a
	SET [0x00+X], Y
	SET PC, post_exe
:_wid_a
	SET Z, [0x00+X] 
	SET [Z], Y
	SET PC, post_exe

:_wido_a
	SET Z, [0xDEAD] 	;load the stored destination pointer
	SET [Z], Y
	SET PC, post_exe
:_wd_b
	SET [0x01+X], Y
	SET PC, post_exe

:_wid_b
	SET Z, [0x01+X] 
	SET [Z], Y
	SET PC, post_exe
:_wido_b
	SET Z, [0xDEAD] 	;load the stored destination pointer
	SET [Z], Y
	SET PC, post_exe
:_wd_c
	SET [0x02+X], Y
	SET PC, post_exe

:_wid_c
	SET Z, [0x02+X] 
	SET [Z], Y
	SET PC, post_exe
:_wido_c
	SET Z, [0xDEAD] 	;load the stored destination pointer
	SET [Z], Y
	SET PC, post_exe
:_wd_x
	SET [0x03+X], Y
	SET PC, post_exe

:_wid_x
	SET Z, [0x03+X] 
	SET [Z], Y
	SET PC, post_exe
:_wido_x
	SET Z, [0xDEAD] 	;load the stored destination pointer
	SET [Z], Y
	SET PC, post_exe
:_wd_y
	SET [0x04+X], Y
	SET PC, post_exe

:_wid_y
	SET Z, [0x04+X] 
	SET [Z], Y
	SET PC, post_exe
:_wido_y
	SET Z, [0xDEAD] 	;load the stored destination pointer
	SET [Z], Y
	SET PC, post_exe
:_wd_z
	SET [0x05+X], Y
	SET PC, post_exe

:_wid_z
	SET Z, [0x05+X] 
	SET [Z], Y
	SET PC, post_exe
:_wido_z
	SET Z, [0xDEAD] 	;load the stored destination pointer
	SET [Z], Y
	SET PC, post_exe
:_wd_i
	SET [0x06+X], Y
	SET PC, post_exe

:_wid_i
	SET Z, [0x06+X] 
	SET [Z], Y
	SET PC, post_exe

:_wido_i
	SET Z, [0xDEAD] 	;load the stored destination pointer
	SET [Z], Y
	SET PC, post_exe
:_wd_j
	SET [0x07+X], Y
	SET PC, post_exe

:_wid_j
	SET Z, [0x07+X] 
	SET [Z], Y
	SET PC, post_exe
:_wido_j
	SET Z, [0xDEAD] 	;load the stored destination pointer
	SET [Z], Y
	SET PC, post_exe
:_wpop
	SET Z, [0xDEAD] 	;load the stored destination pointer
	SET [Z], Y		;write 'a' to the stack
	SET PC, post_exe
:_wpeek
	SET Z, [0xDEAD] 	;load the stored destination pointer
	SET [Z], Y		;write 'a' to the stack
	SET PC, post_exe

:_wpush
	SET Z, [0xDEAD] 	;load the stored destination pointer
	SET [Z], Y		;write 'a' to the stack
	SET PC, post_exe
:_wsp				; write SP
	SET [0x0A+X], Y
	SET PC, post_exe

:_wpc				; write PC
	SET [0x09+X], Y
	SET PC, post_exe_dont_update_pc

:_wo				; write overflow
	SET [0x08+X], Y
	SET PC, post_exe

:_widw
	SET Z, [0xDEAD] 	;load the stored destination pointer
	SET [Z], Y
	SET PC, post_exe
:_wdw				;write literal word (illegal op)
:_wlv				;write literal value (illegal op)
	;NOP
	SET PC, post_exe

;
; look up table generation
;
;	- pointer tables for read / execute / write handlers 
;
;

:gen_lookup_tables
				;basic instructions
	SET J, 0x6000
	ADD J, 0x01
	SET [J], _set
	ADD J, 0x01
	SET [J], _add
	ADD J, 0x01
 	SET [J], _sub
	ADD J, 0x01
 	SET [J], _mul
	ADD J, 0x01
 	SET [J], _div
	ADD J, 0x01
 	SET [J], _mod
	ADD J, 0x01
 	SET [J], _shl
	ADD J, 0x01
 	SET [J], _shr
	ADD J, 0x01
 	SET [J], _and
	ADD J, 0x01
 	SET [J], _bor
	ADD J, 0x01
 	SET [J], _xor
	ADD J, 0x01
 	SET [J], _ife
	ADD J, 0x01
 	SET [J], _ifn
	ADD J, 0x01
 	SET [J], _ifg
	ADD J, 0x01
 	SET [J], _ifb
				;extended instructions
	SET J, 0x6F80
	ADD J, 0x01
	SET [J], _jsr

				;value type loaders
	SET J, 0x5000
	;direct load
	SET [J], _ld_a
	ADD J, 0x01
	SET [J], _ld_b
	ADD J, 0x01
	SET [J], _ld_c
	ADD J, 0x01
	SET [J], _ld_x
	ADD J, 0x01
	SET [J], _ld_y
	ADD J, 0x01
	SET [J], _ld_z
	ADD J, 0x01
	SET [J], _ld_i
	ADD J, 0x01
	SET [J], _ld_j
	
				;indirect load
	ADD J, 0x01
	SET [J], _lid_a
	ADD J, 0x01
	SET [J], _lid_b
	ADD J, 0x01
	SET [J], _lid_c
	ADD J, 0x01
	SET [J], _lid_x
	ADD J, 0x01
	SET [J], _lid_y
	ADD J, 0x01
	SET [J], _lid_z
	ADD J, 0x01
	SET [J], _lid_i
	ADD J, 0x01
	SET [J], _lid_j

				;indirect load /w word offset
	ADD J, 0x01
	SET [J], _lido_a
	ADD J, 0x01
	SET [J], _lido_b
	ADD J, 0x01
	SET [J], _lido_c
	ADD J, 0x01
	SET [J], _lido_x
	ADD J, 0x01
	SET [J], _lido_y
	ADD J, 0x01
	SET [J], _lido_z
	ADD J, 0x01
	SET [J], _lido_i
	ADD J, 0x01
	SET [J], _lido_j

				;stack/memory loads
	ADD J, 0x01
	SET [J], _lpop
	ADD J, 0x01
	SET [J], _lpeek
	ADD J, 0x01
	SET [J], _lpush
	ADD J, 0x01
	SET [J], _lsp
	ADD J, 0x01
	SET [J], _lpc
	ADD J, 0x01
	SET [J], _lo
	ADD J, 0x01
	SET [J], _lidw
	ADD J, 0x01
	SET [J], _ldw

				;5 bit literal loads 
				;(all point to the same function)
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv
	ADD J, 0x01
	SET [J], _llv

				;value type write-back
	SET J, 0x5100
	;direct write
	SET [J], _wd_a
	ADD J, 0x01
	SET [J], _wd_b
	ADD J, 0x01
	SET [J], _wd_c
	ADD J, 0x01
	SET [J], _wd_x
	ADD J, 0x01
	SET [J], _wd_y
	ADD J, 0x01
	SET [J], _wd_z
	ADD J, 0x01
	SET [J], _wd_i
	ADD J, 0x01
	SET [J], _wd_j
	
				;indirect write
	ADD J, 0x01
	SET [J], _wid_a
	ADD J, 0x01
	SET [J], _wid_b
	ADD J, 0x01
	SET [J], _wid_c
	ADD J, 0x01
	SET [J], _wid_x
	ADD J, 0x01
	SET [J], _wid_y
	ADD J, 0x01
	SET [J], _wid_z
	ADD J, 0x01
	SET [J], _wid_i
	ADD J, 0x01
	SET [J], _wid_j

				;indirect write /w word offset
	ADD J, 0x01
	SET [J], _wido_a
	ADD J, 0x01
	SET [J], _wido_b
	ADD J, 0x01
	SET [J], _wido_c
	ADD J, 0x01
	SET [J], _wido_x
	ADD J, 0x01
	SET [J], _wido_y
	ADD J, 0x01
	SET [J], _wido_z
	ADD J, 0x01
	SET [J], _wido_i
	ADD J, 0x01
	SET [J], _wido_j

				;stack/memory write
	ADD J, 0x01
	SET [J], _wpop
	ADD J, 0x01
	SET [J], _wpeek
	ADD J, 0x01
	SET [J], _wpush
	ADD J, 0x01
	SET [J], _wsp
	ADD J, 0x01
	SET [J], _wpc
	ADD J, 0x01
	SET [J], _wo
	ADD J, 0x01
	SET [J], _widw
	ADD J, 0x01
	SET [J], _wdw

				;5 bit literal writes 
				; invalid operation?? 
				; (all point to the same NOP handler)
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv
	ADD J, 0x01
	SET [J], _wlv

				; after generating the look up tables
				; goto 'begin' to start the emulation
	SET PC, begin
	

;
;	TEST PROGRAMS
;
; 	- These are the programs being emulated
;
;
;


:test_pgma		;draws a changing color pattern to the screen
	SET Z, 0x7FFF	
	SET X, 0x5A5A
:conta	ADD Z, 0x01
	SET [Z], X
	IFG Z, 0x8200
	SET PC, loopa
	SET PC, conta
:loopa
	SET Z, 0x7FFF
	SUB X, 0x1311
	SET PC, conta


:test_pgmb
	;
	; test instructions
	;

	SET A, 0x10
	SET B, 0x10
	SET C, 0x10
	SET X, 0x10
	SET Y, 0x10
	SET Z, 0x10
	SET I, 0x10
	SET J, 0x10

	ADD A, 0x10
	ADD B, 0x10
	ADD C, 0x10
	ADD X, 0x10
	ADD Y, 0x10
	ADD Z, 0x10
	ADD I, 0x10
	ADD J, 0x10

	SUB A, 0x10
	SUB B, 0x10
	SUB C, 0x10
	SUB X, 0x10
	SUB Y, 0x10
	SUB Z, 0x10
	SUB I, 0x10
	SUB J, 0x10

	MUL A, 0x02
	MUL B, 0x02
	MUL C, 0x02
	MUL X, 0x02
	MUL Y, 0x02
	MUL Z, 0x02
	MUL I, 0x02
	MUL J, 0x02

	DIV A, 0x02
	DIV B, 0x02
	DIV C, 0x02
	DIV X, 0x02
	DIV Y, 0x02
	DIV Z, 0x02
	DIV I, 0x02
	DIV J, 0x02

	SHL A, 0x01
	SHL B, 0x01
	SHL C, 0x01
	SHL X, 0x01
	SHL Y, 0x01
	SHL Z, 0x01
	SHL I, 0x01
	SHL J, 0x01

	SHR A, 0x01
	SHR B, 0x01
	SHR C, 0x01
	SHR X, 0x01
	SHR Y, 0x01
	SHR Z, 0x01
	SHR I, 0x01
	SHR J, 0x01

	;
	; test value types (READ ONLY - b)
	;

				;register literals
	SET A, 0x1234
	SET A, A
	SET B, A
	SET C, B
	SET X, C
	SET Y, X
	SET Z, Y
	SET I, Z
	SET J, I

				;register pointers
	SET A, 0xFFFF
	SET A, [A]
	SET B, 0xFFFF
	SET B, [B]
	SET C, 0xFFFF
	SET C, [C]
	SET X, 0xFFFF
	SET X, [X]
	SET Y, 0xFFFF
	SET Y, [Y]
	SET Z, 0xFFFF
	SET Z, [Z]
	SET I, 0xFFFF
	SET I, [I]
	SET J, 0xFFFF
	SET J, [J]

				;offset register pointers
	SET A, 0xFFFD
	SET A, [0x01+A]
	SET B, 0xFFFD
	SET B, [0x01+B]
	SET C, 0xFFFD
	SET C, [0x01+C]
	SET X, 0xFFFD
	SET X, [0x01+X]
	SET Y, 0xFFFD
	SET Y, [0x01+Y]
	SET Z, 0xFFFD
	SET Z, [0x01+Z]
	SET I, 0xFFFD
	SET I, [0x01+I]
	SET J, 0xFFFD
	SET J, [0x01+J]

				;SP
	SET A, SP
	SET B, SP
	SET C, SP
	SET X, SP
	SET Y, SP
	SET Z, SP
	SET I, SP
	SET J, SP

				;PC
	SET A, PC
	SET B, PC
	SET C, PC
	SET X, PC
	SET Y, PC
	SET Z, PC
	SET I, PC
	SET J, PC

				;test overflow
	ADD A, 0xFFFF
	ADD B, 0xFFFF
	ADD C, 0xFFFF
	ADD X, 0xFFFF
	ADD Y, 0xFFFF
	ADD Z, 0xFFFF
	ADD I, 0xFFFF
	ADD J, 0xFFFF

				;Overflow
	SET A, O
	SET B, O
	SET C, O
	SET X, O
	SET Y, O
	SET Z, O
	SET I, O
	SET J, O

				;next word literals
	SET A, 0x1010
	SET B, 0x1010
	SET C, 0x1010
	SET X, 0x1010
	SET Y, 0x1010
	SET Z, 0x1010
	SET I, 0x1010
	SET J, 0x1010

				;next word pointers
	SET A, [0x0000]
	SET B, [0x0000]
	SET C, [0x0000]
	SET X, [0x0000]
	SET Y, [0x0000]
	SET Z, [0x0000]
	SET I, [0x0000]
	SET J, [0x0000]

	;
	;test stack operations
	;
	SET PUSH, 0xDEAD
	SET A, PEEK
	SET PUSH, 0xBEEF
	SET B, PEEK
	SET I, POP
	SET J, POP

	;
	;test indirect write backs
	;
	SET A, 0x5A5A
	SET B, 0x01
	SET [0xFFF0], A		;literal pointer
	SET [0xFFF0+B], A	;literal offset pointer
	SET B, 0xFFF2
	SET [B], A		;register pointer

	SET PC, test_pgmb
:end
