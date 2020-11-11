;#############################################################################
;	PIC16F88 Extension Macro
;	16, 24 and 32 bits operation extensions
;	Suffixes (x):
;	- s short  16bit
;	- c color  24bit
;	- i int    32bit
;	- d double 64bit (Not yet implemented) 
;
;	Types (t)
;	- f file
;	- l literal
;	- w w register
;	- u unsigned (Not yet implemented) 
;	- s signed (Not yet implemented) 
;
;	Operations:
;	TESTx f
;	CMPx_tt f f
;	STRx l f, MOVEx f f, SAWPx f f, NEGx f
;	ADDx f f, ADDLx f l, SUBx f f, SUBLx f l, SUBFx f f, SUBFLx f l 
;	CLRFx f, INCFx f, DECFx f, DECFSZx f
;	RLFx f, RRFx f, COMFx f, ANDx f f, IORx f f, XORx f f
;	ASSERTx l f
;	SHIFTRx f f, SHIFTLx f f, RRx f f, RLx f f 
;	BSetx f f, BClearx f f, BTSSx f f, BTSCx f f
;#############################################################################
; TODO new instructions:
; 	MULT, DIV
;	packed BCD arithmetics
;	signed arithmetics
;	string utilities


BTFSCs	MACRO	file, bit
	if (bit >= 8)
	BTFSC	file + 1, bit - 8
	else 
	BTFSC 	file, bit
	endif
	ENDM
	
BTFSCc	MACRO	file, bit
	if (bit >= 16)
	BTFSC	file + 2, bit - 16
	else if (bit >= 8)
	BTFSC	file + 1, bit - 8
	else 
	BTFSC 	file, bit
	endif
	ENDM
	
BTFSCi	MACRO	file, bit
	if (bit >= 24)
	BTFSC	file + 3, bit - 24
	else if (bit >= 16)
	BTFSC	file + 2, bit - 16
	else if (bit >= 8)
	BTFSC	file + 1, bit - 8
	else 
	BTFSC 	file, bit
	endif
	ENDM
	
BTFSSs	MACRO	file, bit
	if (bit >= 8)
	BTFSS	file + 1, bit - 8
	else 
	BTFSS 	file, bit
	endif
	ENDM
	
BTFSSc	MACRO	file, bit
	if (bit >= 16)
	BTFSS	file + 2, bit - 16
	else if (bit >= 8)
	BTFSS	file + 1, bit - 8
	else 
	BTFSS 	file, bit
	endif
	ENDM
	
BTFSSi	MACRO	file, bit
	if (bit >= 24)
	BTFSS	file + 3, bit - 24
	else if (bit >= 16)
	BTFSS	file + 2, bit - 16
	else if (bit >= 8)
	BTFSS	file + 1, bit - 8
	else 
	BTFSS 	file, bit
	endif
	ENDM
;#############################################################################
;	Bit Test SKip if Set (file)target, (file)bit
;	Check if a bit is set in a file, skip next
;#############################################################################

BTSS	MACRO	file, bit
	LOCAL	_select
	MOVLW	0x01	;0000 0001 
	BTFSC	bit, 2	;4
	MOVLW	0x10	;0001 0000
	MOVWF	SCRATCH
	BCF	STATUS, C
	
	BTFSC	bit, 0
	RLF	SCRATCH, F ; 1
	BTFSS	bit, 1
	GOTO	_select
	RLF	SCRATCH, F
	RLF	SCRATCH, F ; 2
_select:
	MOVF	file, W
	
	ANDWF	SCRATCH, W	
	BTFSC	STATUS, Z	; if not Z, bit was set
	ENDM
	
BTSSs	MACRO	file, bit	; 16 bit
	LOCAL	_select
	MOVLW	0x01	;0000 0001 ;0
	BTFSC	bit, 2
	MOVLW	0x10	;0001 0000 ;4
	MOVWF	SCRATCH
	BCF	STATUS, C
	
	BTFSC	bit, 0
	RLF	SCRATCH, F ; 1
	BTFSS	bit, 1
	GOTO	_select
	RLF	SCRATCH, F
	RLF	SCRATCH, F ; 2
_select:
	BTFSC	bit, 3
	MOVF	file + 1, W
	BTFSS	bit, 3
	MOVF	file + 0, W
	
	ANDWF	SCRATCH, W	
	BTFSC	STATUS, Z	; if not Z, bit was set
	ENDM

BTSSc	MACRO	file, bit	; 24 bit
	LOCAL	_select, _8, _end
	MOVLW	0x01	;0000 0001 ;0
	BTFSC	bit, 2
	MOVLW	0x10	;0001 0000 ;4
	MOVWF	SCRATCH
	BCF	STATUS, C
	
	BTFSC	bit, 0
	RLF	SCRATCH, F ; 1
	BTFSS	bit, 1
	GOTO	_select
	RLF	SCRATCH, F
	RLF	SCRATCH, F ; 2
_select:
	BTFSS	bit, 4 ; 16
	GOTO	_8
	MOVF	file + 2, W
	GOTO	_end
_8:
	BTFSC	bit, 3 ; 8
	MOVF	file + 1, W
	BTFSS	bit, 3 ; 8
	MOVF	file + 0, W	
_end:
	ANDWF	SCRATCH, W	
	BTFSC	STATUS, Z	; if not Z, bit was set
	ENDM
	
BTSSi	MACRO	file, bit	; 32 bit
	LOCAL	_select, _8, _end
	MOVLW	0x01	;0000 0001 ;0
	BTFSC	bit, 2
	MOVLW	0x10	;0001 0000 ;4
	MOVWF	SCRATCH
	BCF	STATUS, C
	
	BTFSC	bit, 0
	RLF	SCRATCH, F ; 1
	BTFSS	bit, 1
	GOTO	_select
	RLF	SCRATCH, F
	RLF	SCRATCH, F ; 2
_select:
	BTFSS	bit, 4 ; 16
	GOTO	_8
	BTFSC	bit, 3 ; 8
	MOVF	file + 3, W
	BTFSS	bit, 3 ; 8
	MOVF	file + 2, W	
	GOTO	_end
_8:
	BTFSC	bit, 3 ; 8
	MOVF	file + 1, W
	BTFSS	bit, 3 ; 8
	MOVF	file + 0, W	
_end:
	ANDWF	SCRATCH, W	
	BTFSC	STATUS, Z	; if not Z, bit was set
	ENDM



;#############################################################################
;	Bit Test SKip if Clear (file)target, (file)bit
;	Check if a bit is cleared in a file, skip next
;#############################################################################

BTSC	MACRO	file, bit
	LOCAL	_select
	MOVLW	0x01	;0000 0001 
	BTFSC	bit, 2	;4
	MOVLW	0x10	;0001 0000
	MOVWF	SCRATCH
	BCF	STATUS, C
	
	BTFSC	bit, 0
	RLF	SCRATCH, F ; 1
	BTFSS	bit, 1
	GOTO	_select
	RLF	SCRATCH, F
	RLF	SCRATCH, F ; 2
_select:
	MOVF	file, W
	
	ANDWF	SCRATCH, W	
	BTFSS	STATUS, Z	; if Z, bit was cleared
	ENDM
	
BTSCs	MACRO	file, bit	; 16 bit
	LOCAL	_select
	MOVLW	0x01	;0000 0001 ;0
	BTFSC	bit, 2
	MOVLW	0x10	;0001 0000 ;4
	MOVWF	SCRATCH
	BCF	STATUS, C
	
	BTFSC	bit, 0
	RLF	SCRATCH, F ; 1
	BTFSS	bit, 1
	GOTO	_select
	RLF	SCRATCH, F
	RLF	SCRATCH, F ; 2
_select:
	BTFSC	bit, 3
	MOVF	file + 1, W
	BTFSS	bit, 3
	MOVF	file + 0, W
	
	ANDWF	SCRATCH, W	
	BTFSS	STATUS, Z	; if Z, bit was cleared
	ENDM

BTSCc	MACRO	file, bit	; 24 bit
	LOCAL	_select, _8, _end
	MOVLW	0x01	;0000 0001 ;0
	BTFSC	bit, 2
	MOVLW	0x10	;0001 0000 ;4
	MOVWF	SCRATCH
	BCF	STATUS, C
	
	BTFSC	bit, 0
	RLF	SCRATCH, F ; 1
	BTFSS	bit, 1
	GOTO	_select
	RLF	SCRATCH, F
	RLF	SCRATCH, F ; 2
_select:
	BTFSS	bit, 4 ; 16
	GOTO	_8
	MOVF	file + 2, W
	GOTO	_end
_8:
	BTFSC	bit, 3 ; 8
	MOVF	file + 1, W
	BTFSS	bit, 3 ; 8
	MOVF	file + 0, W	
_end:
	ANDWF	SCRATCH, W	
	BTFSS	STATUS, Z	; if Z, bit was cleared
	ENDM
	
BTSCi	MACRO	file, bit	; 32 bit
	LOCAL	_select, _8, _end
	MOVLW	0x01	;0000 0001 ;0
	BTFSC	bit, 2
	MOVLW	0x10	;0001 0000 ;4
	MOVWF	SCRATCH
	BCF	STATUS, C
	
	BTFSC	bit, 0
	RLF	SCRATCH, F ; 1
	BTFSS	bit, 1
	GOTO	_select
	RLF	SCRATCH, F
	RLF	SCRATCH, F ; 2
_select:
	BTFSS	bit, 4 ; 16
	GOTO	_8
	BTFSC	bit, 3 ; 8
	MOVF	file + 3, W
	BTFSS	bit, 3 ; 8
	MOVF	file + 2, W	
	GOTO	_end
_8:
	BTFSC	bit, 3 ; 8
	MOVF	file + 1, W
	BTFSS	bit, 3 ; 8
	MOVF	file + 0, W	
_end:
	ANDWF	SCRATCH, W	
	BTFSS	STATUS, Z	; if Z, bit was cleared
	ENDM



;#############################################################################
;	BitSet
;	Set bit in file, bit number is read from file
;#############################################################################

BSet	MACRO	file, bit
	LOCAL	_set
	MOVLW	0x01	;0000 0001 
	BTFSC	bit, 2	;4
	MOVLW	0x10	;0001 0000
	MOVWF	SCRATCH
	BCF	STATUS, C
	
	BTFSC	bit, 0
	RLF	SCRATCH, F ; 1
	BTFSS	bit, 1
	GOTO	_set
	RLF	SCRATCH, F
	RLF	SCRATCH, F ; 2
_set:
	MOVF	SCRATCH, W
	IORWF	file, F
	ENDM

BSets	MACRO	file, bit	; 16 bit
	LOCAL	_set
	MOVLW	0x01	;0000 0001 ;0
	BTFSC	bit, 2
	MOVLW	0x10	;0001 0000 ;4
	MOVWF	SCRATCH
	BCF	STATUS, C
	
	BTFSC	bit, 0
	RLF	SCRATCH, F ; 1
	BTFSS	bit, 1
	GOTO	_set
	RLF	SCRATCH, F
	RLF	SCRATCH, F ; 2
_set:
	MOVF	SCRATCH, W
	BTFSC	bit, 3
	IORWF	file + 1, F
	BTFSS	bit, 3
	IORWF	file + 0, F
	ENDM
	
BSetc	MACRO	file, bit	; 24 bit
	LOCAL	_set, _8, _end
	MOVLW	0x01	;0000 0001 ;0
	BTFSC	bit, 2
	MOVLW	0x10	;0001 0000 ;4
	MOVWF	SCRATCH
	BCF	STATUS, C
	
	BTFSC	bit, 0
	RLF	SCRATCH, F ; 1
	BTFSS	bit, 1
	GOTO	_set
	RLF	SCRATCH, F
	RLF	SCRATCH, F ; 2
_set:
	MOVF	SCRATCH, W
	BTFSS	bit, 4 ; 16
	GOTO	_8
	IORWF	file + 2, F
	GOTO	_end
_8:
	BTFSC	bit, 3 ; 8
	IORWF	file + 1, F
	BTFSS	bit, 3 ; 8
	IORWF	file + 0, F	
_end:
	ENDM

BSeti	MACRO	file, bit	; 32 bit
	LOCAL	_set, _8, _end
	MOVLW	0x01	;0000 0001 ;0
	BTFSC	bit, 2
	MOVLW	0x10	;0001 0000 ;4
	MOVWF	SCRATCH
	BCF	STATUS, C
	
	BTFSC	bit, 0
	RLF	SCRATCH, F ; 1
	BTFSS	bit, 1
	GOTO	_set
	RLF	SCRATCH, F
	RLF	SCRATCH, F ; 2
_set:
	MOVF	SCRATCH, W
	BTFSS	bit, 4 ; 16
	GOTO	_8
	BTFSC	bit, 3 ; 8
	IORWF	file + 3, F
	BTFSS	bit, 3 ; 8
	IORWF	file + 2, F	
	GOTO	_end
_8:
	BTFSC	bit, 3 ; 8
	IORWF	file + 1, F
	BTFSS	bit, 3 ; 8
	IORWF	file + 0, F	
_end:
	ENDM



;#############################################################################
;	BitClear
;	Set bit in file, bit number is read from file
;#############################################################################

BClear	MACRO	file, bit
	LOCAL	_clear
	MOVLW	0xFE	;1111 1110 
	BTFSC	bit, 2	;4
	MOVLW	0xEF	;1110 1111
	MOVWF	SCRATCH
	BSF	STATUS, C
	
	BTFSC	bit, 0
	RLF	SCRATCH, F ; 1
	BTFSS	bit, 1
	GOTO	_clear
	RLF	SCRATCH, F
	RLF	SCRATCH, F ; 2
_clear:
	MOVF	SCRATCH, W
	ANDWF	file, F
	ENDM

BClears	MACRO	file, bit	; 16 bit
	LOCAL	_set
	MOVLW	0xFE	;1111 1110 
	BTFSC	bit, 2	;4
	MOVLW	0xEF	;1110 1111
	MOVWF	SCRATCH
	BSF	STATUS, C
	
	BTFSC	bit, 0
	RLF	SCRATCH, F ; 1
	BTFSS	bit, 1
	GOTO	_set
	RLF	SCRATCH, F
	RLF	SCRATCH, F ; 2
_set:
	MOVF	SCRATCH, W
	BTFSC	bit, 3
	ANDWF	file + 1, F
	BTFSS	bit, 3
	ANDWF	file + 0, F
	ENDM
	
BClearc	MACRO	file, bit	; 24 bit
	LOCAL	_set, _8, _end
	MOVLW	0xFE	;1111 1110 
	BTFSC	bit, 2	;4
	MOVLW	0xEF	;1110 1111
	MOVWF	SCRATCH
	BSF	STATUS, C
	
	BTFSC	bit, 0
	RLF	SCRATCH, F ; 1
	BTFSS	bit, 1
	GOTO	_set
	RLF	SCRATCH, F
	RLF	SCRATCH, F ; 2
_set:
	MOVF	SCRATCH, W
	BTFSS	bit, 4 ; 16
	GOTO	_8
	ANDWF	file + 2, F
	GOTO	_end
_8:
	BTFSC	bit, 3 ; 8
	ANDWF	file + 1, F
	BTFSS	bit, 3 ; 8
	ANDWF	file + 0, F	
_end:
	ENDM

BCleari	MACRO	file, bit	; 32 bit
	LOCAL	_set, _8, _end
	MOVLW	0xFE	;1111 1110 
	BTFSC	bit, 2	;4
	MOVLW	0xEF	;1110 1111
	MOVWF	SCRATCH
	BSF	STATUS, C
	
	BTFSC	bit, 0
	RLF	SCRATCH, F ; 1
	BTFSS	bit, 1
	GOTO	_set
	RLF	SCRATCH, F
	RLF	SCRATCH, F ; 2
_set:
	MOVF	SCRATCH, W
	BTFSS	bit, 4 ; 16
	GOTO	_8
	BTFSC	bit, 3 ; 8
	ANDWF	file + 3, F
	BTFSS	bit, 3 ; 8
	ANDWF	file + 2, F	
	GOTO	_end
_8:
	BTFSC	bit, 3 ; 8
	ANDWF	file + 1, F
	BTFSS	bit, 3 ; 8
	ANDWF	file + 0, F	
_end:
	ENDM



;#############################################################################
;	Shift Right(qty)
;	Fill bits with carry
;#############################################################################

SHIFTR	MACRO	file, qty 	; 8 bit Shift Right, fill with Carry
	LOCAL	 _4, _2, _1, _end
	
	TEST	qty
	BR_ZE	_end
	MOVF	STATUS, W	; save status( for Carry bit )

	BTFSS	qty, 3 		; shift by 8: all bits are replaced by C
	GOTO	_4	
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file
	GOTO 	_end
_4:
	BTFSS	qty, 2 		; shift by 4
	GOTO	_2	
	RRF	file, F
	MOVWF	STATUS
	RRF	file, F
	MOVWF	STATUS
	RRF	file, F
	MOVWF	STATUS
	RRF	file, F	
	MOVWF	STATUS	
_2:
	BTFSS	qty, 1 		; shift by 2
	GOTO	_1
	RRF	file, F
	MOVWF	STATUS
	RRF	file, F	
	MOVWF	STATUS	
_1:
	BTFSC	qty, 0 		; shift by 1
	RRF	file, F	
_end:
	ENDM

SHIFTRs	MACRO	file, qty	; 16 bit Shift Right, fill with Carry
	LOCAL	 _8, _4, _2, _1, _end

	TEST	qty
	BR_ZE	_end
	MOVF	STATUS, W	; save status( for Carry bit )
	
	BTFSS	qty, 4 		; shift by 16: byte1 and byte0 are filled with C
	GOTO	_8
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file + 0
	MOVWF	file + 1
	GOTO 	_end
_8:
	BTFSS	qty, 3 		; shift by 8: move byte1 to byte0, fill byte1 with C
	GOTO	_4
	MOVWF	SCRATCH		; save w (STATUS)
	MOVF	file + 1, W
	MOVWF	file + 0
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file + 1
	MOVF	SCRATCH, W
_4:
	BTFSS	qty, 2 		; shift by 4
	GOTO	_2	
	RRF	file + 1, F
	RRF	file + 0, F
	MOVWF	STATUS
	RRF	file + 1, F
	RRF	file + 0, F
	MOVWF	STATUS
	RRF	file + 1, F
	RRF	file + 0, F
	MOVWF	STATUS
	RRF	file + 1, F
	RRF	file + 0, F	
	MOVWF	STATUS
_2:
	BTFSS	qty, 1 		; shift by 2
	GOTO	_1	
	RRF	file + 1, F
	RRF	file + 0, F
	MOVWF	STATUS
	RRF	file + 1, F
	RRF	file + 0, F
	MOVWF	STATUS
_1:
	BTFSS	qty, 0 		; shift by 1
	GOTO	_end
	RRF	file + 1, F
	RRF	file + 0, F	
_end:
	ENDM

SHIFTRc	MACRO	file, qty	; 24 bit Shift Right, fill with Carry
	LOCAL	_8, _4, _2, _1, _end

	TEST	qty
	BR_ZE	_end
	MOVF	STATUS, W	; save status( for Carry bit )
	
	BTFSS	qty, 4 		; shift by 16: move byte2 to byte0, fill byte1 and byte2 with C
	GOTO	_8
	MOVWF	SCRATCH		; save w (STATUS)
	MOVF	file + 2, W
	MOVWF	file + 0
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file + 1
	MOVWF	file + 2
	MOVF	SCRATCH, W
_8:
	BTFSS	qty, 3 		; shift by 8: move byte1 to byte0 and byte2 to byte1, fill byte2 with C
	GOTO	_4
	MOVWF	SCRATCH		; save w (STATUS)
	MOVF	file + 1, W
	MOVWF	file + 0
	MOVF	file + 2, W
	MOVWF	file + 1
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file + 2
	MOVF	SCRATCH, W
_4:
	BTFSS	qty, 2 		; shift by 4
	GOTO	_2	
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	MOVWF	STATUS
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	MOVWF	STATUS
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	MOVWF	STATUS
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F	
	MOVWF	STATUS
_2:
	BTFSS	qty, 1 		; shift by 2
	GOTO	_1
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	MOVWF	STATUS
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	MOVWF	STATUS
_1:
	BTFSS	qty, 0 		; shift by 1
	GOTO	_end
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F	
_end:
	ENDM

SHIFTRi	MACRO	file, qty	; 32 bit Shift Right, fill with Carry
	LOCAL	_16, _8, _4, _2, _1, _end

	TEST	qty
	BR_ZE	_end
	MOVF	STATUS, W	; save status( for Carry bit )
	
	BTFSS	qty, 5 		; shift by 32: replace all by C
	GOTO	_16
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file + 0
	MOVWF	file + 1
	MOVWF	file + 2
	MOVWF	file + 3
	GOTO	_end
_16:
	BTFSS	qty, 4 		; shift by 16: move byte2 to byte0, byte3 to byte1 fill byte3 and byte2 with C
	GOTO	_8
	MOVWF	SCRATCH		; save w (STATUS)
	MOVF	file + 2, W
	MOVWF	file + 0
	MOVF	file + 3, W
	MOVWF	file + 1
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file + 2
	MOVWF	file + 3
	MOVF	SCRATCH, W
_8:
	BTFSS	qty, 3 		; shift by 8: move byte1 to byte0 and byte2 to byte1, byte3 to byte2, fill byte3 with C
	GOTO	_4
	MOVWF	SCRATCH		; save w (STATUS)
	MOVF	file + 1, W
	MOVWF	file + 0
	MOVF	file + 2, W
	MOVWF	file + 1
	MOVF	file + 3, W
	MOVWF	file + 2
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file + 3
	MOVF	SCRATCH, W
_4:
	BTFSS	qty, 2 		; shift by 4
	GOTO	_2
	RRF	file + 3, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	MOVWF	STATUS
	RRF	file + 3, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	MOVWF	STATUS
	RRF	file + 3, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	MOVWF	STATUS
	RRF	file + 3, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F	
	MOVWF	STATUS
_2:
	BTFSS	qty, 1 		; shift by 2
	GOTO	_1
	RRF	file + 3, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	MOVWF	STATUS
	RRF	file + 3, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	MOVWF	STATUS
_1:
	BTFSS	qty, 0 		; shift by 1
	GOTO	_end
	RRF	file + 3, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F	
_end:
	ENDM



;#############################################################################
;	Shift Left(qty)
;	Fill bits with carry
;#############################################################################

SHIFTL	MACRO	file, qty 	; 8 bit Shift Left, fill with Carry
	LOCAL	 _4, _2, _1, _end
	
	TEST	qty
	BR_ZE	_end
	MOVF	STATUS, W	; save status( for Carry bit )

	BTFSS	qty, 3 		; shift by 8: all bits are replaced by C
	GOTO	_4	
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file
	GOTO 	_end
_4:
	BTFSS	qty, 2 		; shift by 4
	GOTO	_2	
	RLF	file, F
	MOVWF	STATUS
	RLF	file, F
	MOVWF	STATUS
	RLF	file, F
	MOVWF	STATUS
	RLF	file, F	
	MOVWF	STATUS	
_2:
	BTFSS	qty, 1 		; shift by 2
	GOTO	_1
	RLF	file, F
	MOVWF	STATUS
	RLF	file, F	
	MOVWF	STATUS	
_1:
	BTFSC	qty, 0 		; shift by 1
	RLF	file, F	
_end:
	ENDM

SHIFTLs	MACRO	file, qty	; 16 bit Shift Left, fill with Carry
	LOCAL	 _8, _4, _2, _1, _end

	TEST	qty
	BR_ZE	_end
	MOVF	STATUS, W	; save status( for Carry bit )
	
	BTFSS	qty, 4 		; shift by 16: byte0 and byte1 are filled with C
	GOTO	_8
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file + 0
	MOVWF	file + 1
	GOTO 	_end
_8:
	BTFSS	qty, 3 		; shift by 8: move byte0 to byte1, fill byte0 with C
	GOTO	_4
	MOVWF	SCRATCH		; save w (STATUS)
	MOVF	file + 0, W
	MOVWF	file + 1
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file + 0
	MOVF	SCRATCH, W
_4:
	BTFSS	qty, 2 		; shift by 4
	GOTO	_2	
	RLF	file + 0, F
	RLF	file + 1, F
	MOVWF	STATUS
	RLF	file + 0, F
	RLF	file + 1, F
	MOVWF	STATUS
	RLF	file + 0, F
	RLF	file + 1, F
	MOVWF	STATUS
	RLF	file + 0, F
	RLF	file + 1, F
	MOVWF	STATUS
_2:
	BTFSS	qty, 1 		; shift by 2
	GOTO	_1	
	RLF	file + 0, F
	RLF	file + 1, F
	MOVWF	STATUS
	RLF	file + 0, F
	RLF	file + 1, F
	MOVWF	STATUS
_1:
	BTFSS	qty, 0 		; shift by 1
	GOTO	_end
	RLF	file + 0, F
	RLF	file + 1, F
_end:
	ENDM

SHIFTLc	MACRO	file, qty	; 24 bit Shift Left, fill with Carry
	LOCAL	_8, _4, _2, _1, _end

	TEST	qty
	BR_ZE	_end
	MOVF	STATUS, W	; save status( for Carry bit )
	
	BTFSS	qty, 4 		; shift by 16: move byte0 to byte2, fill byte0 and byte1 with C
	GOTO	_8
	MOVWF	SCRATCH		; save w (STATUS)
	MOVF	file + 0, W
	MOVWF	file + 2
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file + 0
	MOVWF	file + 1
	MOVF	SCRATCH, W
_8:
	BTFSS	qty, 3 		; shift by 8: move byte1 to byte2 and byte0 to byte1, fill byte0 with C
	GOTO	_4
	MOVWF	SCRATCH		; save w (STATUS)
	MOVF	file + 1, W
	MOVWF	file + 2
	MOVF	file + 0, W
	MOVWF	file + 1
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file + 0
	MOVF	SCRATCH, W
_4:
	BTFSS	qty, 2 		; shift by 4
	GOTO	_2	
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	MOVWF	STATUS
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	MOVWF	STATUS
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	MOVWF	STATUS
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	MOVWF	STATUS
_2:
	BTFSS	qty, 1 		; shift by 2
	GOTO	_1
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	MOVWF	STATUS
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	MOVWF	STATUS
_1:
	BTFSS	qty, 0 		; shift by 1
	GOTO	_end
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
_end:
	ENDM

SHIFTLi	MACRO	file, qty	; 32 bit Shift Left, fill with Carry
	LOCAL	_16, _8, _4, _2, _1, _end

	TEST	qty
	BR_ZE	_end
	MOVF	STATUS, W	; save status( for Carry bit )
	
	BTFSS	qty, 5 		; shift by 32: replace all by C
	GOTO	_16
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file + 0
	MOVWF	file + 1
	MOVWF	file + 2
	MOVWF	file + 3
	GOTO	_end
_16:
	BTFSS	qty, 4 		; shift by 16: move byte1 to byte3, byte0 to byte2 fill byte0 and byte1 with C
	GOTO	_8
	MOVWF	SCRATCH		; save w (STATUS)
	MOVF	file + 1, W
	MOVWF	file + 3
	MOVF	file + 0, W
	MOVWF	file + 2
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file + 0
	MOVWF	file + 1
	MOVF	SCRATCH, W
_8:
	BTFSS	qty, 3 		; shift by 8: move byte2 to byte3 and byte1 to byte2, byte0 to byte1, fill byte0 with C
	GOTO	_4
	MOVWF	SCRATCH		; save w (STATUS)
	MOVF	file + 2, W
	MOVWF	file + 3
	MOVF	file + 1, W
	MOVWF	file + 2
	MOVF	file + 0, W
	MOVWF	file + 2
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file + 0
	MOVF	SCRATCH, W
_4:
	BTFSS	qty, 2 		; shift by 4
	GOTO	_2
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 3, F
	MOVWF	STATUS
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 3, F
	MOVWF	STATUS
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 3, F
	MOVWF	STATUS
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 3, F
	MOVWF	STATUS
_2:
	BTFSS	qty, 1 		; shift by 2
	GOTO	_1
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 3, F
	MOVWF	STATUS
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 3, F
	MOVWF	STATUS
_1:
	BTFSS	qty, 0 		; shift by 1
	GOTO	_end
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 3, F
_end:
	ENDM



;#############################################################################
;	Rotate Right(qty)
;	Through carry
;#############################################################################

RR	MACRO	file, qty 	; 8 bit Rotate Right, through Carry
	LOCAL	_2, _1, _end
	
	TEST	qty
	BR_ZE	_end

	BTFSC	qty, 3 		; rotate by 8: all bits are the same
	GOTO 	_end

	BTFSS	qty, 2 		; rotate by 4
	GOTO	_2	
	RRF	file, F
	RRF	file, F
	RRF	file, F
	RRF	file, F	
_2:
	BTFSS	qty, 1 		; rotate by 2
	GOTO	_1
	RRF	file, F
	RRF	file, F	
_1:
	BTFSC	qty, 0 		; rotate by 1
	RRF	file, F	
_end:
	ENDM

RRs	MACRO	file, qty 	; 16 bit Rotate Right, through Carry
	LOCAL	 _4, _2, _1, _end

	TEST	qty
	BR_ZE	_end
	
	BTFSC	qty, 4 		; rotate by 16: all bits are the same
	GOTO	_end

	BTFSS	qty, 3 		; rotate by 8: swap byte1 and byte0
	GOTO	_4
	MOVF	file + 0, W
	MOVWF	SCRATCH
	MOVF	file + 1, W
	MOVWF	file + 0
	MOVF	SCRATCH
	MOVWF	file + 1
_4:
	BTFSS	qty, 2 		; rotate by 4
	GOTO	_2	
	RRF	file + 1, F
	RRF	file + 0, F
	RRF	file + 1, F
	RRF	file + 0, F
	RRF	file + 1, F
	RRF	file + 0, F
	RRF	file + 1, F
	RRF	file + 0, F	
_2:
	BTFSS	qty, 1 		; rotate by 2
	GOTO	_1	
	RRF	file + 1, F
	RRF	file + 0, F
	RRF	file + 1, F
	RRF	file + 0, F
_1:
	BTFSS	qty, 0 		; rotate by 1
	GOTO	_end
	RRF	file + 1, F
	RRF	file + 0, F	
_end:
	ENDM

RRc	MACRO	file, qty 	; 24 bit Rotate Right, through Carry
	LOCAL	_8, _4, _2, _1, _end

	TEST	qty
	BR_ZE	_end

	BTFSS	qty, 4 		; rotate by 16: move byte2 to byte0, byte1 to byte2, byte0 to byte1
	GOTO	_8		; 210 -> 102 
	MOVF	file + 0, W
	MOVWF	SCRATCH
	MOVF	file + 2, W
	MOVWF	file + 0
	MOVF	file + 1, W
	MOVWF	file + 2
	MOVF	SCRATCH
	MOVWF	file + 1
_8:
	BTFSS	qty, 3 		; rotate by 8: move byte1 to byte0 and byte2 to byte1, byte0 to byte2
	GOTO	_4		; 210 -> 021
	MOVF	file + 0, W
	MOVWF	SCRATCH
	MOVF	file + 1, W
	MOVWF	file + 0
	MOVF	file + 2, W
	MOVWF	file + 1
	MOVF	SCRATCH
	MOVWF	file + 2
_4:
	BTFSS	qty, 2 		; rotate by 4
	GOTO	_2	
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F	
_2:
	BTFSS	qty, 1 		; rotate by 2
	GOTO	_1
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
_1:
	BTFSS	qty, 0 		; rotate by 1
	GOTO	_end
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F	
_end:
	ENDM

RRi	MACRO	file, qty 	; 32 bit Rotate Right, through Carry
	LOCAL	_8, _4, _2, _1, _end

	TEST	qty
	BR_ZE	_end
	
	BTFSC	qty, 5 		; rotate by 32: all bits are the same
	GOTO	_end
	
	BTFSS	qty, 4 		; rotate by 16: b2 -> b0, b3 -> b1, b0 -> b2, b1 -> b3 
	GOTO	_8		; 3210 -> 1032
	MOVF	file + 0, W
	MOVWF	SCRATCH		; s = b0	
	MOVF	file + 2, W
	MOVWF	file + 0	; b0 = b2
	MOVF	SCRATCH, W
	MOVWF	file + 2	; b2 = b0		
	MOVF	file + 1, W
	MOVWF	SCRATCH		; s = b1	
	MOVF	file + 3, W
	MOVWF	file + 1	; b1 = b3
	MOVF	SCRATCH, W
	MOVWF	file + 3	; b3 = b1	
_8:
	BTFSS	qty, 3 		; rotate by 8: b1 -> b0, b2 -> b1, b3 -> b2, b0 -> b3 
	GOTO	_4		; 3210 -> 0321
	MOVF	file + 0, W
	MOVWF	SCRATCH	
	MOVF	file + 1, W
	MOVWF	file + 0
	MOVF	file + 2, W
	MOVWF	file + 1
	MOVF	file + 3, W
	MOVWF	file + 2
	MOVF	SCRATCH
	MOVWF	file + 3
_4:
	BTFSS	qty, 2 		; rotate by 4
	GOTO	_2
	RRF	file + 3, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	RRF	file + 3, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	RRF	file + 3, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	RRF	file + 3, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F	
_2:
	BTFSS	qty, 1 		; rotate by 2
	GOTO	_1
	RRF	file + 3, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
	RRF	file + 3, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F
_1:
	BTFSS	qty, 0 		; rotate by 1
	GOTO	_end
	RRF	file + 3, F
	RRF	file + 2, F
	RRF	file + 1, F
	RRF	file + 0, F	
_end:
	ENDM



;#############################################################################
;	Rotate Left(qty)
;	Through carry
;#############################################################################

RL	MACRO	file, qty 	; 8 bit Rotate Left, through Carry
	LOCAL	 _2, _1, _end	
	
	TEST	qty
	BR_ZE	_end

	BTFSC	qty, 3 		; rotate by 8: all bits are the same
	GOTO 	_end

	BTFSS	qty, 2 		; rotate by 4
	GOTO	_2	
	RLF	file, F
	RLF	file, F
	RLF	file, F
	RLF	file, F	
_2:
	BTFSS	qty, 1 		; rotate by 2
	GOTO	_1
	RLF	file, F
	RLF	file, F	
_1:
	BTFSC	qty, 0 		; rotate by 1
	RLF	file, F	
_end:
	ENDM

RLs	MACRO	file, qty 	; 16 bit Rotate Left, through Carry
	LOCAL	 _4, _2, _1, _end

	TEST	qty
	BR_ZE	_end
	
	BTFSC	qty, 4 		; rotate by 16: all bits are the same
	GOTO	_end

	BTFSS	qty, 3 		; rotate by 8: swap byte1 and byte0
	GOTO	_4
	MOVF	file + 0, W
	MOVWF	SCRATCH
	MOVF	file + 1, W
	MOVWF	file + 0
	MOVF	SCRATCH
	MOVWF	file + 1
_4:
	BTFSS	qty, 2 		; rotate by 4
	GOTO	_2	
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 0, F
	RLF	file + 1, F
_2:
	BTFSS	qty, 1 		; rotate by 2
	GOTO	_1	
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 0, F
	RLF	file + 1, F
_1:
	BTFSS	qty, 0 		; rotate by 1
	GOTO	_end
	RLF	file + 0, F
	RLF	file + 1, F
_end:
	ENDM

RLc	MACRO	file, qty 	; 24 bit Rotate Left, through Carry
	LOCAL	_8, _4, _2, _1, _end

	TEST	qty
	BR_ZE	_end

	BTFSS	qty, 4 		; rotate by 16: move byte1 to byte0, byte2 to byte1, byte0 to byte2
	GOTO	_8		; 210 -> 021
	MOVF	file + 0, W
	MOVWF	SCRATCH
	MOVF	file + 1, W
	MOVWF	file + 0
	MOVF	file + 2, W
	MOVWF	file + 1
	MOVF	SCRATCH
	MOVWF	file + 2
_8:
	BTFSS	qty, 3 		; rotate by 8: move byte2 to byte0, byte1 to byte2, byte0 to byte1
	GOTO	_4		; 210 -> 102
	MOVF	file + 0, W
	MOVWF	SCRATCH
	MOVF	file + 2, W
	MOVWF	file + 0
	MOVF	file + 1, W
	MOVWF	file + 2
	MOVF	SCRATCH
	MOVWF	file + 1
_4:
	BTFSS	qty, 2 		; rotate by 4
	GOTO	_2	
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
_2:
	BTFSS	qty, 1 		; rotate by 2
	GOTO	_1
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
_1:
	BTFSS	qty, 0 		; rotate by 1
	GOTO	_end
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
_end:
	ENDM

RLi	MACRO	file, qty 	; 32 bit Rotate Left, through Carry
	LOCAL	_16, _8, _4, _2, _1, _end

	TEST	qty
	BR_ZE	_end
	
	BTFSC	qty, 5 		; rotate by 32: all bits are the same
	GOTO	_end
	
	BTFSS	qty, 4 		; rotate by 16: b2 -> b0, b3 -> b1, b0 -> b2, b1 -> b3 
	GOTO	_8		; 3210 -> 1032
	MOVF	file + 0, W
	MOVWF	SCRATCH		; s = b0	
	MOVF	file + 2, W
	MOVWF	file + 0	; b0 = b2
	MOVF	SCRATCH, W
	MOVWF	file + 2	; b2 = b0		
	MOVF	file + 1, W
	MOVWF	SCRATCH		; s = b1	
	MOVF	file + 3, W
	MOVWF	file + 1	; b1 = b3
	MOVF	SCRATCH, W
	MOVWF	file + 3	; b3 = b1	
_8:
	BTFSS	qty, 3 		; rotate by 8: b3 -> b0, b2 -> b3, b1 -> b2, b0 -> b3 
	GOTO	_4		; 3210 -> 2103
	MOVF	file + 0, W
	MOVWF	SCRATCH	
	MOVF	file + 3, W
	MOVWF	file + 0
	MOVF	file + 2, W
	MOVWF	file + 3
	MOVF	file + 1, W
	MOVWF	file + 2
	MOVF	SCRATCH
	MOVWF	file + 3
_4:
	BTFSS	qty, 2 		; rotate by 4
	GOTO	_2
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 3, F
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 3, F
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 3, F
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 3, F
_2:
	BTFSS	qty, 1 		; rotate by 2
	GOTO	_1
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 3, F
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 3, F
_1:
	BTFSS	qty, 0 		; rotate by 1
	GOTO	_end
	RLF	file + 0, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 3, F
_end:
	ENDM



;#############################################################################
;	Tests
;	Result in STATUS Z
;#############################################################################
	
TESTs	MACRO	file
	CLRF	SCRATCH
	
	MOVF	file, F
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	file + 1, F	
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM

TESTc	MACRO	file
	LOCAL	_end
	CLRF	SCRATCH
	
	MOVF	file, F
	BR_NZ	_end
	BSF	SCRATCH, Z
	
	MOVF	file + 1, F
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	file + 2, F
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
_end:
	ENDM
	
TESTi	MACRO	file
	LOCAL	_end
	CLRF	SCRATCH
	
	MOVF	file, F
	BR_NZ	_end
	BSF	SCRATCH, Z
	
	MOVF	file + 1, F
	BR_NZ	_end
	BSF	SCRATCH, Z
	
	MOVF	file + 2, F
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	file + 3, F
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
_end:
	ENDM
	
	
	
;#############################################################################
;	Compare
;	Result in STATUS Z and C
;#############################################################################

CMPs_lf	MACRO	lit, file	; 16bit literal vs file
	LOCAL	_NB, _BR, _END
	CLRF	SCRATCH
	
	MOVF	file, W
	SUBLW	(lit & 0x00FF)		; w = lit - file
	SK_ZE
	BSF	SCRATCH, Z		; #Z propagation
	BR_NB	_NB

	; if borrow
	CLRW
	ADDLW	(lit & 0xFF00)	>> 8
	BR_NE	_BR
	
	; if high byte of lit == 0
	BCF	STATUS, Z	; not equal
	BCF	STATUS, C 	; borrow
	GOTO	_END
	
_BR:
	MOVF	file + 1, W
	SUBLW	((lit & 0xFF00) >> 8) - 1 	; apply borrow to literal
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	GOTO	_END	
	
_NB:
	MOVF	file + 1, W
	SUBLW	(lit & 0xFF00) >> 8
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	
_END:
	ENDM


; TODO
;COMPc_l_f
;COMPi_l_f



CMPs_ff	MACRO	file1, file2	; 16bit file1 vs file2
	LOCAL	_NB, _BR, _end	
	CLRF	SCRATCH
	
	MOVF	file2, W
	SUBWF	file1, W		; w = file1 - file2	
	SK_ZE
	BSF	SCRATCH, Z		; save #Z
	BR_NB	_NB
	
	; if borrow
	MOVF	file1 + 1, F		; test if file1+1 is zero
	BTFSS	STATUS, Z
	GOTO	_BR
	
	; high byte is zero
	BCF	STATUS, Z	; not equal
	BCF	STATUS, C 	; borrow
	GOTO	_end
	
_BR:
	MOVF	file2 + 1, W
	DECF	file1 + 1, F		; apply borrow from last byte
	SUBWF	file1 + 1, W
	SK_ZE
	BSF	SCRATCH, Z		; save #Z
	SK_NC
	BSF	SCRATCH, C		; save C
	INCF	file1 + 1, F		; restore file to pre-borrow
	
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z		; restore Z
	
	BCF	STATUS, C
	BTFSC	SCRATCH, C	
	BSF	STATUS, C		; restore C
	GOTO	_end
	
_NB:
	MOVF	file2 + 1, W
	SUBWF	file1 + 1, W		; w = file1 - file2
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	
_end:
	ENDM

CMPc_ff	MACRO	file1, file2	; 24bit file1 vs file2
	LOCAL	_b1, _b2, _end

#DEFINE sC0	0	; scratch C/#B byte 0
#DEFINE sC1	1	; scratch C/#B byte 1

#DEFINE snZ	4	; scratch #Z
#DEFINE sfZ	5	; scratch Final Z
#DEFINE sfC	6	; scratch Final C
	
	CLRF	SCRATCH	
	
	MOVF	file2, W	; comp byte0
	SUBWF	file1, W
	SK_ZE
	BSF	SCRATCH, snZ
	BR_NB	_b1
	BSF	SCRATCH, sC0
	DECF	file1 + 1, F
	SK_NB
	DECF	file1 + 2, F
	
_b1:	;shortcut if no borrow on byte 0
	MOVF	file2 + 1, W	; comp byte1
	SUBWF	file1 + 1, W
	SK_ZE
	BSF	SCRATCH, snZ
	BR_NB	_b2
	BSF	SCRATCH, sC1
	DECF	file1 + 2, F

_b2:
	MOVF	file2 + 2, W	; comp byte2
	SUBWF	file1 + 2, W
	BTFSC	SCRATCH, snZ
	BCF	STATUS, Z
	
	; save final STATUS values
	SK_NZ
	BSF	SCRATCH, sfZ
	SK_NC
	BSF	SCRATCH, sfC
	
	; revert all borrows from file1
	BTFSC	SCRATCH, sC1
	INCF	file1 + 2, F
	
	BTFBC	SCRATCH, sC0, _end
	INCF	file1 + 1, F
	SK_NC
	INCF	file1 + 2, F
	
_end:
	; restore final STATUS values
	BCF	STATUS, C
	BTFSC	SCRATCH, sfC
	BSF	STATUS, C
	
	BCF	STATUS, Z
	BTFSC	SCRATCH, sfZ
	BSF	STATUS, Z
	ENDM

	
CMPi_ff	MACRO	file1, file2	; 32bit file1 vs file2
	LOCAL	_b1, _b2, _b3, _r0, _end

#DEFINE sC0	0	; scratch C/#B byte 0
#DEFINE sC1	1	; scratch C/#B byte 1
#DEFINE sC2	2	; scratch C/#B byte 2

#DEFINE snZ	4	; scratch #Z
#DEFINE sfZ	5	; scratch Final Z
#DEFINE sfC	6	; scratch Final C
	
	CLRF	SCRATCH	
	
	MOVF	file2, W
	SUBWF	file1, W
	SK_ZE
	BSF	SCRATCH, snZ
	BR_NB	_b1
	BSF	SCRATCH, sC0
	DECF	file1 + 1, F
	SK_NB
	DECF	file1 + 2, F
	SK_NB
	DECF	file1 + 3, F
	
_b1:	;shortcut if no borrow on byte 0
	MOVF	file2 + 1, W
	SUBWF	file1 + 1, W
	SK_ZE
	BSF	SCRATCH, snZ
	BR_NB	_b2
	BSF	SCRATCH, sC1
	DECF	file1 + 2, F
	SK_NB
	DECF	file1 + 3, F
	
_b2:	;shortcut if no borrow on byte 1
	MOVF	file2 + 2, W
	SUBWF	file1 + 2, W
	SK_ZE
	BSF	SCRATCH, snZ
	BR_NB	_B3
	BSF	SCRATCH, sC2
	DECF	file1 + 3, F

_b3:
	MOVF	file2 + 3, W
	SUBWF	file1 + 3, W
	BTFSC	SCRATCH, snZ
	BCF	STATUS, Z
	
	; save final STATUS values
	SK_NZ
	BSF	SCRATCH, sfZ
	SK_NC
	BSF	SCRATCH, sfC
	
	; revert all borrows from file1
	BTFSC	SCRATCH, sC2
	INCF	file1 + 3, F
	
	BTFBC	SCRATCH, sC1, _r0
	INCF	file1 + 2, F
	SK_NC
	INCF	file1 + 3, F

_r0:	
	BTFBC	SCRATCH, sC0, _end
	INCF	file1 + 1, F
	SK_NC
	INCF	file1 + 2, F
	SK_NC
	INCF	file1 + 3, F
	
	
_end:
	; restore final STATUS values
	BCF	STATUS, C
	BTFSC	SCRATCH, sfC
	BSF	STATUS, C
	
	BCF	STATUS, Z
	BTFSC	SCRATCH, sfZ
	BSF	STATUS, Z
	ENDM



;#############################################################################
;	Store literal to file
;	to = lit
;#############################################################################

STRs	MACRO	lit, to
	MOVLW	( lit & 0x00FF )
	MOVWF	to
	MOVLW	( lit & 0xFF00 ) >> 8
	MOVWF	to + 1
	ENDM
	
STRc	MACRO	lit, to
	MOVLW	( lit & 0x0000FF )
	MOVWF	to
	MOVLW	( lit & 0x00FF00 ) >> 8
	MOVWF	to + 1
	MOVLW	( lit & 0xFF0000 ) >> 16
	MOVWF	to + 2
	ENDM
	
STRi	MACRO	lit, to
	MOVLW	( lit & 0x000000FF )
	MOVWF	to
	MOVLW	( lit & 0x0000FF00 ) >> 8
	MOVWF	to + 1
	MOVLW	( lit & 0x00FF0000 ) >> 16
	MOVWF	to + 2
	MOVLW	( lit & 0xFF000000 ) >> 24
	MOVWF	to + 3
	ENDM
	
	
	
;#############################################################################
;	Move file content
;	to = from
;#############################################################################

MOVs 	MACRO	from, to
	MOVF	from, W
	MOVWF	to
	MOVF	from + 1, W
	MOVWF	to + 1
	ENDM
	
MOVc 	MACRO	from, to
	MOVF	from, W
	MOVWF	to
	MOVF	from + 1, W
	MOVWF	to + 1
	MOVF	from + 2, W
	MOVWF	to + 2
	ENDM
	
MOVi 	MACRO	from, to
	MOVF	from, W
	MOVWF	to
	MOVF	from + 1, W
	MOVWF	to + 1
	MOVF	from + 2, W
	MOVWF	to + 2
	MOVF	from + 3, W
	MOVWF	to + 3
	ENDM
	
	
	
;#############################################################################
;	Swap content of 2 files
;	s = a, a = b, b = s
;#############################################################################

SWAPs	MACRO	a, b
	MOVF	a, W		; w = a
	MOVWF	SCRATCH		; s = a
	MOVF	b, W		; w = b
	MOVWF	a		; a = b
	MOVF	SCRATCH, W	; w = a
	MOVWF	b		; b = a
	
	MOVF	a + 1, W
	MOVWF	SCRATCH	
	MOVF	b + 1, W
	MOVWF	a + 1
	MOVF	SCRATCH, W
	MOVWF	b + 1
	ENDM
	
SWAPc	MACRO	a, b
	MOVF	a, W		; w = a
	MOVWF	SCRATCH		; s = a
	MOVF	b, W		; w = b
	MOVWF	a		; a = b
	MOVF	SCRATCH, W	; w = a
	MOVWF	b		; b = a
	
	MOVF	a + 1, W
	MOVWF	SCRATCH	
	MOVF	b + 1, W
	MOVWF	a + 1
	MOVF	SCRATCH, W
	MOVWF	b + 1
	
	MOVF	a + 2, W
	MOVWF	SCRATCH	
	MOVF	b + 2, W
	MOVWF	a + 2
	MOVF	SCRATCH, W
	MOVWF	b + 2
	ENDM
	
SWAPi	MACRO	a, b
	MOVF	a, W		; w = a
	MOVWF	SCRATCH		; s = a
	MOVF	b, W		; w = b
	MOVWF	a		; a = b
	MOVF	SCRATCH, W	; w = s (a)
	MOVWF	b		; b = w (a)
	
	MOVF	a + 1, W
	MOVWF	SCRATCH	
	MOVF	b + 1, W
	MOVWF	a + 1
	MOVF	SCRATCH, W
	MOVWF	b + 1
	
	MOVF	a + 2, W
	MOVWF	SCRATCH	
	MOVF	b + 2, W
	MOVWF	a + 2
	MOVF	SCRATCH, W
	MOVWF	b + 2
	
	MOVF	a + 3, W
	MOVWF	SCRATCH	
	MOVF	b + 3, W
	MOVWF	a + 3
	MOVF	SCRATCH, W
	MOVWF	b + 3
	ENDM



;#############################################################################
;	Add content of 2 files
;	 a = a + b
;#############################################################################

ADDs	MACRO	a, b	; a = a + b
	LOCAL	_nc0
	CLRF	SCRATCH		; scratch register to keep track of STATUS Z flag, inverted to reduce setup time
	
	MOVF	b, W
	ADDWF 	a, F
	
	SK_ZE
	BSF	SCRATCH, Z
	
	BR_NC	_nc0
	INCF	a + 1, F	; if increasing the highest byte cause a 0, set the carry flag
	SK_NZ
	BSF	SCRATCH, C
_nc0:
	MOVF	b + 1, W
	ADDWF	a + 1, F
	
	BTFSC	SCRATCH, C
	BSF	STATUS, C
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z	; clear status Z flag if any one of the add instruction didn't produce a Z
	ENDM

ADDc	MACRO	a, b	; a = a + b
	LOCAL	_nc0, _nc1	
	CLRF	SCRATCH	
	
	MOVF	b, W
	ADDWF 	a, F
	
	SK_ZE
	BSF	SCRATCH, Z
	
	BR_NC	_nc0
	INCF	a + 1, F
	SK_NZ
	INCF	a + 2, F
	SK_NZ
	BSF	SCRATCH, C
_nc0:
	MOVF	b + 1, W
	ADDWF	a + 1, F
	
	SK_ZE
	BSF	SCRATCH, Z
	
	BR_NC	_nc1
	INCF	a + 2, F
	SK_NZ
	BSF	SCRATCH, C
_nc1:
	MOVF	b + 2, W
	ADDWF	a + 2, F
	
	BTFSC	SCRATCH, C
	BSF	STATUS, C
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z	
	ENDM

ADDi	MACRO	a, b	; a = a + b
	LOCAL	_nc0, _nc1, _nc2
	CLRF	SCRATCH	
	
	MOVF	b, W
	ADDWF 	a, F		; add
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	
	BR_NC	_nc0
	INCF	a + 1, F	; propagate Carry
	SK_NZ
	INCF	a + 2, F
	SK_NZ
	INCF	a + 3, F
	SK_NZ
	BSF	SCRATCH, C
_nc0:
	MOVF	b + 1, W	; load next byte
	ADDWF	a + 1, F	; add
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag
	
	BR_NC	_nc1
	INCF	a + 2, F	; propagate Carry
	SK_NZ
	INCF	a + 3, F
	SK_NZ
	BSF	SCRATCH, C
_nc1:
	MOVF	b + 2, W
	ADDWF	a + 2, F
	
	SK_ZE
	BSF	SCRATCH, Z
	
	BR_NC	_nc2	
	INCF	a + 3, F
	SK_NZ
	BSF	SCRATCH, C
_nc2:
	MOVF	b + 3, W
	ADDWF	a + 3, F
	
	BTFSC	SCRATCH, C
	BSF	STATUS, C
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	


;#############################################################################
;	Subtract content of 2 files
;	 a = a - b
;#############################################################################

SUBs	MACRO	a, b	; a = a - b
	LOCAL	_nb0
	CLRF	SCRATCH	
	
	MOVF	b, W
	SUBWF	a, F
	
	SK_ZE
	BSF	SCRATCH, Z
	
	BR_NB	_nb0
	MOVLW	0x01
	SUBWF	a + 1, F
	SK_NB
	BSF	SCRATCH, C
_nb0:
	MOVF	b + 1, W
	SUBWF	a + 1, F
	
	BTFSC	SCRATCH, C
	BCF	STATUS, C
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM

SUBc	MACRO	a, b	; a = a - b
	LOCAL	_nb0, _nb1
	CLRF	SCRATCH	
	
	MOVF	b, W		; sub byte 0
	SUBWF	a, F
	
	SK_ZE
	BSF	SCRATCH, Z
	
	BR_NB	_nb0		; if no borrow sub next byte
	MOVLW	0x01		; propagate carry
	SUBWF	a + 1, F
	SK_NB
	SUBWF	a + 2, F
	SK_NB
	BSF	SCRATCH, C	; set borrow
_nb0:
	MOVF	b + 1, W	; sub byte 1
	SUBWF	a + 1, F
	
	SK_ZE
	BSF	SCRATCH, Z
	
	BR_NB	_nb1
	MOVLW	0x01	
	SUBWF	a + 2, F
	SK_NB
	BSF	SCRATCH, C	; set borrow
_nb1:
	MOVF	b + 2, W
	SUBWF	a + 2, F
	
	BTFSC	SCRATCH, C
	BCF	STATUS, C
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	
SUBi	MACRO	a, b	; a = a - b
	LOCAL	_nb0, _nb1, _nb2
	CLRF	SCRATCH	
	
	MOVF	b, W
	SUBWF	a, F		; sub
	
	SK_ZE			; save #Z flag
	BSF	SCRATCH, Z
	
	BR_NB	_nb0		; propagate Borrow	
	MOVLW	0x01
	SUBWF	a + 1, F
	SK_NB
	SUBWF	a + 2, F
	SK_NB
	SUBWF	a + 3, F
	SK_NB
	BSF	SCRATCH, C
_nb0:
	MOVF	b + 1, W	; next byte
	SUBWF	a + 1, F	; sub
	
	SK_ZE			; save #Z
	BSF	SCRATCH, Z
	
	BR_NB	_nb1		; propagate Borrow
	MOVLW	0x01
	SUBWF	a + 2, F
	SK_NB
	SUBWF	a + 3, F
	SK_NB
	BSF	SCRATCH, C
_nb1:
	MOVF	b + 2, W
	SUBWF	a + 2, F
	
	SK_ZE
	BSF	SCRATCH, Z
	
	BR_NB	_nb2
	MOVLW	0x01
	SUBWF	a + 3, F
	SK_NB
	BSF	SCRATCH, C
_nb2:
	MOVF	b + 3, W
	SUBWF	a + 3, F
	
	BTFSC	SCRATCH, C
	BCF	STATUS, C
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM



;#############################################################################
;	Add literal to file content
;	 a = a + lit
;#############################################################################

ADDLs	MACRO	a, lit	; a = a + lit
	LOCAL	_nc0
	CLRF	SCRATCH	
	
	MOVLW	( lit & 0x00FF ) >> 0
	ADDWF 	a, F		; add
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	
	BR_NC	_nc0
	INCF	a + 1, F	; propagate Carry
	SK_NZ
	BSF	SCRATCH, C
_nc0:
	MOVLW	( lit & 0xFF00 ) >> 8
	ADDWF	a + 1, F
	
	BTFSC	SCRATCH, C
	BSF	STATUS, C
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	
ADDLc	MACRO	a, lit	; a = a + lit
	LOCAL	_nc0, _nc1
	CLRF	SCRATCH	
	
	MOVLW	( lit & 0x0000FF ) >> 0
	ADDWF 	a, F		; add
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	
	BR_NC	_nc0
	INCF	a + 1, F	; propagate Carry
	SK_NZ
	INCF	a + 2, F
	SK_NZ
	BSF	SCRATCH, C
_nc0:
	MOVLW	( lit & 0x00FF00 ) >> 8; load next byte
	ADDWF	a + 1, F
	
	SK_ZE
	BSF	SCRATCH, Z
	
	BR_NC	_nc1
	INCF	a + 2, F
	SK_NZ
	BSF	SCRATCH, C
_nc1:
	MOVLW	( lit & 0xFF0000 ) >> 16
	ADDWF	a + 2, F
	
	BTFSC	SCRATCH, C
	BSF	STATUS, C
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM

ADDLi	MACRO	a, lit	; a = a + lit
	LOCAL	_nc0, _nc1, _nc2
	CLRF	SCRATCH	
	
	MOVLW	( lit & 0x000000FF ) >> 0
	ADDWF 	a, F		; add
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	
	BR_NC	_nc0
	INCF	a + 1, F	; propagate Carry
	SK_NZ
	INCF	a + 2, F
	SK_NZ
	INCF	a + 3, F
	SK_NZ
	BSF	SCRATCH, C
_nc0:
	MOVLW	( lit & 0x0000FF00 ) >> 8; load next byte
	ADDWF	a + 1, F	; add
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag
	
	BR_NC	_nc1
	INCF	a + 2, F	; propagate Carry
	SK_NZ
	INCF	a + 3, F
	SK_NZ	SCRATCH, C
_nc1:
	MOVLW	( lit & 0x00FF0000 ) >> 16
	ADDWF	a + 2, F
	
	SK_ZE
	BSF	SCRATCH, Z
	
	BR_NC	_nc2	
	INCF	a + 3, F
	SK_NZ
	BSF	SCRATCH, C
_nc2:
	MOVLW	( lit & 0xFF000000 ) >> 24
	ADDWF	a + 3, F
	
	BTFSC	SCRATCH, C
	BSF	STATUS, C
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM



;#############################################################################
;	Subtract literal from file content
;	 a = a - lit
;#############################################################################

SUBLs	MACRO	a, lit	; a = a - lit
	LOCAL	_nb0
	CLRF	SCRATCH	
	
	MOVLW	( lit & 0x00FF ) >> 0
	SUBWF 	a, F		; subtract
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	
	BR_NB	_nb0
	MOVLW	0x01
	SUBWF	a + 1, F	; propagate Borrow
	SK_NB
	BSF	SCRATCH, C
_nb0:
	MOVLW	( lit & 0xFF00 ) >> 8; load next byte
	SUBWF	a + 1, F	; subtract

	BTFSC	SCRATCH, C
	BCF	STATUS, C
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	
SUBLc	MACRO	a, lit	; a = a - lit
	LOCAL	_nb0, _nb1
	CLRF	SCRATCH	
	
	MOVLW	( lit & 0x0000FF ) >> 0
	SUBWF 	a, F		; subtract
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	
	BR_NB	_nb0
	MOVLW	0x01
	SUBWF	a + 1, F	; propagate Borrow
	SK_NB
	SUBWF	a + 2, F
	SK_NB
	BSF	SCRATCH, C
_nb0:
	MOVLW	( lit & 0x00FF00 ) >> 8; load next byte
	SUBWF	a + 1, F	; subtract
	
	SK_ZE
	BSF	SCRATCH, Z
	
	BR_NB	_nb1
	MOVLW	0x01
	SUBWF	a + 2, F
	SK_NB
	BSF	SCRATCH, C
_nb1:
	MOVLW	( lit & 0xFF0000 ) >> 16
	SUBWF	a + 2, F
	
	BTFSC	SCRATCH, C
	BCF	STATUS, C
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	
SUBLi	MACRO	a, lit	; a = a - lit
	LOCAL	_nb0, _nb1, _nb2
	CLRF	SCRATCH	
	
	MOVLW	( lit & 0x000000FF ) >> 0	
	SUBWF 	a, F		; subtract
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	
	BR_NB	_nb0
	MOVLW	0x01
	SUBWF	a + 1, F	; propagate Borrow
	SK_NB
	SUBWF	a + 2, F
	SK_NB
	SUBWF	a + 3, F
	SK_NB
	SCRATCH, C
_nb0:
	MOVLW	( lit & 0x0000FF00 ) >> 8; load next byte
	SUBWF	a + 1, F	; subtract
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag
	
	BR_NB	_nb1
	MOVLW	0x01
	SUBWF	a + 2, F	; propagate Borrow
	SK_NB
	SUBWF	a + 3, F
	SK_NB
	BSF	SCRATCH, C
_nb1:
	MOVLW	( lit & 0x00FF0000 ) >> 16
	SUBWF	a + 2, F
	
	SK_ZE
	BSF	SCRATCH, Z
	
	BR_NB	_nb2
	MOVLW	0x01
	SUBWF	a + 3, F
	SK_NB
	BSF	SCRATCH, C
	
	MOVLW	( lit & 0xFF000000 ) >> 24
	SUBWF	a + 3, F
	
	BTFSC	SCRATCH, C
	BCF	STATUS, C
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM



;#############################################################################
;	Subtract target from other file
;	 a = b - a
; TODO don't modify b
; TODO propagate borrow
;#############################################################################

SUBFs	MACRO	a, b	; a = b - a
	LOCAL	_nb0
	CLRF	SCRATCH	
	
	MOVF	a, W
	SUBWF	b, W	
	MOVWF	a
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	
	BR_NB	_nb0
	MOVLW	0x01
	SUBWF	b + 1, F	; propagate Borrow
	SK_NB
	BSF	SCRATCH, C
_nb0:
	MOVF	a + 1, W	; load next byte
	SUBLW	b + 1, W	
	MOVWF	a + 1
	
	BTFSC	SCRATCH, C
	BCF	STATUS, C
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z	
	ENDM
	
SUBFc	MACRO	a, b	; a = b - a
	LOCAL	_nb0
	CLRF	SCRATCH	
	
	MOVF	a, W
	SUBWF	b, W	
	MOVWF	a
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	BR_NB	_nb0
	MOVLW	0x01
	SUBWF	a + 1, F	; propagate Borrow
	SK_NB
	SUBWF	a + 2, F
_nb0:
	MOVF	a + 1, W	; load next byte
	SUBLW	b + 1, W	
	MOVWF	a + 1
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag
	SK_NB
	DECF	a + 2, F
		
	MOVF	a + 2, W	; load next byte
	SUBLW	b + 2, W	
	MOVWF	a + 2

	BTFSC	SCRATCH, Z
	BCF	STATUS, Z	
	ENDM
	
	
SUBFi	MACRO	a, b	; a = b - a
	LOCAL	_nb0, _nb1
	CLRF	SCRATCH	
	
	MOVF	a, W
	SUBWF	b, W
	MOVWF	a
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	BR_NB	_nb0
	MOVLW	0x01
	SUBWF	a + 1, F	; propagate Borrow
	SK_NB
	SUBWF	a + 2, F
	SK_NB
	SUBWF	a + 3, F
_nb0:	
	MOVF	a + 1, W	; load next byte
	SUBLW	b + 1, W
	MOVWF	a + 1
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag
	BR_NB	_nb1
	SUBWF	a + 2, F	; propagate Borrow
	SK_NB
	SUBWF	a + 3, F
_nb1:
	MOVF	a + 2, W	; load next byte
	SUBLW	b + 2, W
	MOVWF	a + 2
	
	SK_ZE
	BSF	SCRATCH, Z
	SK_NB	
	DECF	a + 3, F
	
	MOVF	a + 3, W	; load next byte
	SUBLW	b + 3, W
	MOVWF	a + 3

	BTFSC	SCRATCH, Z
	BCF	STATUS, Z	
	ENDM



;#############################################################################
;	Subtract file content from literal
;	 a = lit - a
; TODO don't modify b
; TODO propagate borrow
;#############################################################################

SUBFLs	MACRO	a, lit	; a = lit - a
	CLRF	SCRATCH	
	
	MOVF	a, W
	SUBLW	( lit & 0x00FF ) >> 0	
	MOVWF	a
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	SK_NB
	DECF	a + 1, F	; propagate Borrow
		
	MOVF	a + 1, W	; load next byte
	SUBLW	( lit & 0xFF00 ) >> 8
	MOVWF	a + 1

	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	
SUBFLc	MACRO	a, lit	; a = lit - a
	LOCAL	_nb0
	CLRF	SCRATCH	
	
	MOVF	a, W
	SUBLW	( lit & 0x0000FF ) >> 0
	MOVWF	a
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	BR_NB	_nb0
	MOVLW	0x01
	SUBWF	a + 1, F	; propagate Borrow
	SK_NB
	SUBWF	a + 2, F
_nb0:
	MOVF	a + 1, W	; load next byte
	SUBLW	( lit & 0x00FF00 ) >> 8
	MOVWF	a + 1
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag
	SK_NB
	DECF	a + 2, F	; propagate Borrow
		
	MOVF	a + 2, W	; load next byte
	SUBLW	( lit & 0xFF0000 ) >> 16
	MOVWF	a + 2
	
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	
SUBFLi	MACRO	a, lit	; a = lit - a
	LOCAL	_nb0, _nb1
	CLRF	SCRATCH	
	
	MOVF	a, W
	SUBLW	( lit & 0x000000FF ) >> 0
	MOVWF	a
		
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	BR_NB	_nb0
	MOVLW	0x01
	SUBWF	a + 1, F	; propagate Borrow
	SK_NB
	SUBWF	a + 2, F
	SK_NB
	SUBWF	a + 3, F
_nb0:
	MOVF	a + 1, W	; load next byte
	SUBLW	( lit & 0x0000FF00 ) >> 8
	MOVWF	a + 1
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag
	BR_NB	_nb1
	MOVLW	0x01
	SUBWF	a + 2, F	; propagate Borrow
	SK_NB
	SUBWF	a + 3, F
_nb1:
	MOVF	a + 2, W	; load next byte
	SUBLW	( lit & 0x00FF0000 ) >> 16
	MOVWF	a + 2
		
	SK_ZE
	BSF	SCRATCH, Z
	SK_NB	
	DECF	a + 3, F
		
	MOVF	a + 3, W	; load next byte
	SUBLW	( lit & 0xFF000000 ) >> 24
	MOVWF	a + 3

	BTFSC	SCRATCH, Z
	BCF	STATUS, Z	
	ENDM



;#############################################################################
;	Invert (COMF)
;	 a = (NOT a)
;#############################################################################

COMFs	MACRO	file
	COMF	file, F
	COMF	file + 1, F
	ENDM
	
COMFc	MACRO	file
	COMF	file, F
	COMF	file + 1, F
	COMF	file + 2, F
	ENDM
	
COMFi	MACRO	file
	COMF	file, F
	COMF	file + 1, F
	COMF	file + 2, F
	COMF	file + 3, F
	ENDM



;#############################################################################
;	Negate (two's complement)
;	 a = (NOT a) + 1
;#############################################################################

NEGs	MACRO	file
	COMF	file, F
	COMF	file + 1, F
	
	INCF	file, F
	SK_NZ
	INCF	file + 1, F
	ENDM
	
NEGc	MACRO	file
	LOCAL	_END
	COMF	file, F
	COMF	file + 1, F
	COMF	file + 2, F
	
	INCF	file, F
	BR_NZ	_END
	INCF	file + 1, F
	SK_NZ
	INCF	file + 2, F
_END:
	ENDM
	
NEGi	MACRO	file
	LOCAL	_END
	COMF	file, F		; invert
	COMF	file + 1, F
	COMF	file + 2, F
	COMF	file + 3, F	
	
	INCF	file, F		; inc byte 0		
	BR_NZ	_END		; propagate carry
	INCF	file + 1, F
	BR_NZ	_END
	INCF	file + 2, F
	SK_NZ
	INCF	file + 3, F
_END:
	ENDM



;#############################################################################
;	Clear content of file
;	 a = 0
;#############################################################################

CLRFs	MACRO	file
	CLRF	file
	CLRF	file + 1
	ENDM
	
CLRFc	MACRO	file
	CLRF	file
	CLRF	file + 1
	CLRF	file + 2
	ENDM
	
CLRFi	MACRO	file
	CLRF	file
	CLRF	file + 1
	CLRF	file + 2
	CLRF	file + 3
	ENDM



;#############################################################################
;	Increase file
;	 a = a + 1
;#############################################################################

INCFs	MACRO	file
	INCF	file, F	
	SK_NZ
	INCF	file + 1, F ; msb overflow	
	ENDM
	
INCFc	MACRO	file
	LOCAL	_END
	
	INCF	file, F		
	BR_NZ	_END
	INCF	file + 1, F ; msb overflow
	SK_NZ
	INCF	file + 2, F
_END:
	ENDM
	
INCFi	MACRO	file
	LOCAL	_END
	
	INCF	file, F		
	BR_NZ	_END
	INCF	file + 1, F ; msb overflow
	BR_NZ	_END
	INCF	file + 2, F
	SK_NZ
	INCF	file + 3, F
_END:
	ENDM



;#############################################################################
;	Decrease file content
;	 a = a - 1
;#############################################################################

DECFs 	MACRO	file
	MOVLW	0x01
	SUBWF	file, F	
	SK_NB
	SUBWF	file + 1, F
	ENDM

DECFc	MACRO	file
	LOCAL	_END
	
	MOVLW	0x01
	SUBWF	file, F	
	BR_NB	_END
	SUBWF	file + 1, F
	SK_NB
	SUBWF	file + 2, F
_END:
	ENDM

DECFi	MACRO	file
	LOCAL	_END
	
	MOVLW	0x01
	SUBWF	file, F	
	BR_NB	_END
	SUBWF	file + 1, F
	BR_NB	_END
	SUBWF	file + 2, F
	SK_NB
	SUBWF	file + 3, F
_END:
	ENDM



;#############################################################################
;	Decrease file content, skip next if zero
;	 a = a - 1
;#############################################################################

DECFSZs	MACRO	file
	CLRF	SCRATCH
	MOVLW	0x01
	SUBWF	file, F
	SK_ZE
	BSF	SCRATCH, Z	; set #Z
	SK_NB
	SUBWF	file + 1, F	; propagate borrow to b1
	MOVF	file + 1, F	; make sure b1 is tested
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z	; mask Z if #Z is set
	SK_ZE
	ENDM
	
DECFSZc	MACRO	file
	CLRF	SCRATCH
	MOVLW	0x01
	SUBWF	file, F
	SK_ZE
	BSF	SCRATCH, Z	; set #Z if not zero
	SK_NB
	SUBWF	file + 1, F	; propagate borrow to b1
	SK_NB
	SUBWF	file + 2, F	; propagate borrow to b2	
	
	MOVF	file + 1, F	; test b1
	SK_ZE
	BSF	SCRATCH, Z	; set #Z
	
	MOVF	file + 2, F	; test b2
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z	; mask Z if #Z was set
	SK_ZE
	ENDM

DECFSZi	MACRO	file
	LOCAL	_b1
	CLRF	SCRATCH
	MOVLW	0x01
	SUBWF	file, F
	SK_ZE
	BSF	SCRATCH, Z	; set #Z
	BR_NB	_b1
	SUBWF	file + 1, F	; propagate borrow
	SK_NB
	SUBWF	file + 2, F
	SK_NB
	SUBWF	file + 3, F
_b1:
	MOVF	file + 1, F	; test b1
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	file + 2, F	; test b2
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	file + 3, F	; test b3
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z	; mask Z if #Z was set
	SK_ZE
	ENDM



;#############################################################################
;	Rotate Right through carry
;	Rotate Left through carry
;#############################################################################

RLFs	MACRO	file
	RLF	file, F
	RLF	file + 1, F
	ENDM
	
RLFc	MACRO	file
	RLF	file, F
	RLF	file + 1, F
	RLF	file + 2, F
	ENDM
	
RLFi	MACRO	file
	RLF	file, F
	RLF	file + 1, F
	RLF	file + 2, F
	RLF	file + 3, F
	ENDM
	
RRFs	MACRO	file
	RRF	file + 1, F	
	RRF	file, F
	ENDM
	
RRFc	MACRO	file
	RRF	file + 2, F	
	RRF	file + 1, F	
	RRF	file, F
	ENDM
RRFi	MACRO	file
	RRF	file + 3, F
	RRF	file + 2, F	
	RRF	file + 1, F	
	RRF	file, F
	ENDM



;#############################################################################
;	bitwise AND, IOR, XOR
;#############################################################################

; a = a & b
ANDs	MACRO	a, b
	CLRF	SCRATCH
	MOVF	b, W
	ANDWF	a, F
	SK_ZE
	BSF	SCRATCH, Z
	MOVF	b + 1, W
	ANDWF	a + 1, F
	BTFSC	SCRATCH
	BCF	STATUS, Z
	ENDM
	
ANDc	MACRO	a, b
	CLRF	SCRATCH
	
	MOVF	b, W
	ANDWF	a, F	
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	b + 1, W
	ANDWF	a + 1, F
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	b + 2, W
	ANDWF	a + 2, F
	BTFSC	SCRATCH
	BCF	STATUS, Z
	ENDM
	
ANDi	MACRO	a, b
	CLRF	SCRATCH
	
	MOVF	b, W
	ANDWF	a, F	
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	b + 1, W
	ANDWF	a + 1, F
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	b + 2, W
	ANDWF	a + 2, F
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	b + 3, W
	ANDWF	a + 3, F
	BTFSC	SCRATCH
	BCF	STATUS, Z
	ENDM

; a = a | b
IORs	MACRO	a, b
	CLRF	SCRATCH
	MOVF	b, W
	IORWF	a, F
	SK_ZE
	BSF	SCRATCH, Z
	MOVF	b + 1, W
	IORWF	a + 1, F
	BTFSC	SCRATCH
	BCF	STATUS, Z
	ENDM
	
IORc	MACRO	a, b
	CLRF	SCRATCH
	
	MOVF	b, W
	IORWF	a, F	
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	b + 1, W
	IORWF	a + 1, F
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	b + 2, W
	IORWF	a + 2, F
	BTFSC	SCRATCH
	BCF	STATUS, Z
	ENDM
	
IORi	MACRO	a, b
	CLRF	SCRATCH
	
	MOVF	b, W
	IORWF	a, F	
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	b + 1, W
	IORWF	a + 1, F
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	b + 2, W
	IORWF	a + 2, F
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	b + 3, W
	IORWF	a + 3, F
	BTFSC	SCRATCH
	BCF	STATUS, Z
	ENDM

; a = a ^ b
XORs	MACRO	a, b
	CLRF	SCRATCH
	MOVF	b, W
	XORWF	a, F
	SK_ZE
	BSF	SCRATCH, Z
	MOVF	b + 1, W
	XORWF	a + 1, F
	BTFSC	SCRATCH
	BCF	STATUS, Z
	ENDM
	
XORc	MACRO	a, b
	CLRF	SCRATCH
	
	MOVF	b, W
	XORWF	a, F	
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	b + 1, W
	XORWF	a + 1, F
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	b + 2, W
	XORWF	a + 2, F
	BTFSC	SCRATCH
	BCF	STATUS, Z
	ENDM
	
XORi	MACRO	a, b
	CLRF	SCRATCH
	
	MOVF	b, W
	XORWF	a, F	
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	b + 1, W
	XORWF	a + 1, F
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	b + 2, W
	XORWF	a + 2, F
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	b + 3, W
	XORWF	a + 3, F
	BTFSC	SCRATCH
	BCF	STATUS, Z
	ENDM



;#############################################################################
;	Multiplication
;#############################################################################

; inline implementation (no loop)
; would be best to wrap the macro in a subroutine call with proper calling convention
MULT88	MACRO	dest, a, b ;dest is 2 bytes, a and b are 1 byte
	LOCAL	_1, _2, _3, _4, _5, _6, _7, _END
	
	CLRF	dest
	CLRF	dest + 1
	CLRF	SCRATCH
	
	MOVF	a, W
	IORWF	b, W
	BTFSC	STATUS, Z
	GOTO	_END
	
	BTFSS	a, 0
	GOTO	_1
	
	MOVF	b, W
	MOVWF	dest
_1:
	BCF	STATUS, C
	RLF	b, F
	RLF	SCRATCH, F
	BTFSS	a, 1
	GOTO	_2
	
	MOVF	b, W
	ADDWF	dest, F
	BTFSC	STATUS, C
	INCF	dest + 1, F
	MOVF	SCRATCH, W
	ADDWF	dest + 1, F
_2:	
	BCF	STATUS, C
	RLF	b, F
	RLF	SCRATCH, F
	BTFSS	a, 2
	GOTO	_3
	
	MOVF	b, W
	ADDWF	dest, F
	BTFSC	STATUS, C
	INCF	dest + 1, F
	MOVF	SCRATCH, W
	ADDWF	dest + 1, F

_3:	
	BCF	STATUS, C
	RLF	b, F
	RLF	SCRATCH, F
	BTFSS	a, 3
	GOTO	_4
	
	MOVF	b, W
	ADDWF	dest, F
	BTFSC	STATUS, C
	INCF	dest + 1, F
	MOVF	SCRATCH, W
	ADDWF	dest + 1, F

_4:	
	BCF	STATUS, C
	RLF	b, F
	RLF	SCRATCH, F
	BTFSS	a, 4
	GOTO	_5
	
	MOVF	b, W
	ADDWF	dest, F
	BTFSC	STATUS, C
	INCF	dest + 1, F
	MOVF	SCRATCH, W
	ADDWF	dest + 1, F

_5:	
	BCF	STATUS, C
	RLF	b, F
	RLF	SCRATCH, F
	BTFSS	a, 5
	GOTO	_6
	
	MOVF	b, W
	ADDWF	dest, F
	BTFSC	STATUS, C
	INCF	dest + 1, F
	MOVF	SCRATCH, W
	ADDWF	dest + 1, F

_6:	
	BCF	STATUS, C
	RLF	b, F
	RLF	SCRATCH, F
	BTFSS	a, 6
	GOTO	_7
	
	MOVF	b, W
	ADDWF	dest, F
	BTFSC	STATUS, C
	INCF	dest + 1, F
	MOVF	SCRATCH, W
	ADDWF	dest + 1, F

_7:	
	BTFSS	a, 7
	GOTO	_END
	
	BCF	STATUS, C
	RLF	b, F
	RLF	SCRATCH, F

	MOVF	b, W
	ADDWF	dest, F
	BTFSC	STATUS, C
	INCF	dest + 1, F
	MOVF	SCRATCH, W
	ADDWF	dest + 1, F

_END:
	ENDM
	
; 8bit * 8bit mult, loop implementation
MULT88l	MACRO	dest, a, b ;dest is 2 bytes, a and b are 1 byte
	LOCAL	_next, _shift, _end
	
	CLRF	dest
	CLRF	dest + 1
	CLRF	SCRATCH
	
	MOVF	b, W		; test that b !=0
	BTFSC	STATUS, Z
	GOTO	_end	
_next
	MOVF	a, W		;test if "a" have bits set to 1
	BTFSC	STATUS, Z
	GOTO	_end

	BCF	STATUS, C
	RRF	a, F		; a >> 1
	BTFSS	STATUS, C
	GOTO	_shift		; if 0 shift only
	
	MOVF	b, W		; if 1 add to result then shift
	ADDWF	dest, F
	BTFSC	STATUS, C
	INCF	dest + 1, F
	MOVF	SCRATCH, W
	ADDWF	dest + 1, F	
_shift:
	BCF	STATUS, C
	RLF	b, F
	RLF	SCRATCH, F
	GOTO	_next
_end:
	ENDM
	
;MULT816
;MULT824
;MULT832
;MULT1616
;MULT1624
;MULT1632
;MULT3232
; mask = 0x01
; and mask var1
; rlf mask

;Result to Packed BCD, 16 bit input, max value is 65536, 2.5 BCD bytes (x6 55 36)
BIN2BCD		MACRO	BCD, Result, count_BCD1, count_BCD2
	LOCAL BIN2BCD_mainLoop, BIN2BCD_highNibble, BIN2BCD_lowNibble, BIN2BCD_nextNibble
	CLRF	BCD
	CLRF	BCD + 1
	CLRF	BCD + 2
	MOVLW	15		; Rotate and Increment 15 time
	MOVWF	count_BCD1

BIN2BCD_mainLoop:
 	BCF	STATUS, C
	RLF	Result, F
	RLF	Result + 1, F
	RLF	BCD, F
	RLF	BCD + 1, F
	RLF	BCD + 2, F

	MOVLW	BCD
	MOVWF	FSR

	MOVLW	0x03
	MOVWF	count_BCD2
	
BIN2BCD_highNibble:
	SWAPF	INDF, W	
	ANDLW	0x0F
	SUBLW	0x04
	BTFSC	STATUS, C
	GOTO	BIN2BCD_lowNibble
	MOVLW	0x30
	ADDWF	INDF, F

BIN2BCD_lowNibble:
	MOVLW	0x0F
	ANDWF	INDF, W
	SUBLW	0x04
	BTFSC	STATUS, C
	GOTO	BIN2BCD_nextNibble
	MOVLW	0x03
	ADDWF	INDF, F		

BIN2BCD_nextNibble:
	INCF	FSR, F
	DECFSZ	count_BCD2, F
	GOTO	BIN2BCD_highNibble

	DECFSZ	count_BCD1, F
	GOTO	BIN2BCD_mainLoop

 	BCF	STATUS, C	; 16th Time no C5A3
	RLF	Result, F
	RLF	Result + 1, F
	RLF	BCD, F
	RLF	BCD + 1, F
	RLF	BCD + 2, F

	ENDM
