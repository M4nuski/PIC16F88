SHIFTRloop	MACRO	file, qty ; fill with Carry
	LOCAL	_top, _end
	; zero check, 3 cycles if not 0, 4 if zero
	TEST	qty
	BR_ZE	_end

	; context save, 3 cycles
	MOVF	qty, W		; save qty
	MOVWF	SCRATCH	
	MOVF	STATUS, W	; save status( for Carry bit )
	
	; 6 cycles to get here qty + no0
	; 5 cycles -qty
	; 3 cycles -no0
	; 2 cycles -qty -no0
_top:
	RRF	file, F
	MOVWF	STATUS
	DECFSZ	qty
	GOTO	_top
	; loop, 5 cycles per loop, 4 for single pass
	
	MOVF	SCRATCH, W	; restore qty
	MOVWF	qty
	; context restore, 2 cycles
	; 1 cycles -qty
_end:
	ENDM
; qty	cycles	-qty	-no0	-qty-no0
; 0	4	4	1029	1027	
; 1	12	10	9	7
; 2	17	15	14	12
; 3	22	10	19	17
; 4	27	25	24	22
; 5	32	30	29	27
; 6	37	35	34	32
; 7	42	40	39	37
; 8	47	45	44	42
;E	240	214	1241/212 1223/196

SHIFTRhash	MACRO	file, qty ; fill with Carry
	LOCAL	 _4, _2, _1, _end
	
	TEST	qty
	BR_ZE	_end
	; zero check, 3 cycles if not 0, 4 if zero
		
	MOVF	STATUS, W	; save status( for Carry bit )
	; context save, 1 cycle

	BTFSS	qty, 3 ; shift by 8 all bits are replaced by C
	GOTO	_4
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file
	GOTO 	_end
	;8 cycles, 3 if skipped
_4:
	BTFSS	qty, 2 ; shift by 4 nibbles are swapped
	GOTO	_2
	
	RRF	file, F
	MOVWF	STATUS
	RRF	file, F
	MOVWF	STATUS
	RRF	file, F
	MOVWF	STATUS
	RRF	file, F	
	MOVWF	STATUS
	; shift 4, 10 cycles, 3 if skipped
				; f = hgfe dcba
	;MOVLW	0xF0		; w = 1111 0000
	;ANDWF	file, F		; f = hgfe 0000
	;SWAPF	file, F		; f = 0000 hgfe
	;BTFSS	STATUS, C	; if C = 0		if C = 1
	;MOVLW	0x00		; w = 0000 0000	w = 1111 0000
	;IORWF	file, F		; f = CCCC hgfe
	;MOVF	STATUS, W
	; shift 4, 9 cycles, 3 if skipped
	
_2:
	BTFSS	qty, 1 ; shift by 2
	GOTO	_1
	RRF	file, F
	MOVWF	STATUS
	RRF	file, F	
	MOVWF	STATUS
	; shift 2, 6 cycles, 3 if skipped
_1:
	BTFSC	qty, 0 ; shift by 1
	RRF	file, F	
_end:
	ENDM
; qty	cycles	-no0	swap	swap - no0
; 0	4	12	4	12
; 1	15	12	15	12
; 2	18	15	18	15
; 3	18	15	18	15
; 4	22	19	21	18
; 5	22	19	21	18
; 6	25	22	24	21
; 7	25	22	24	21
; 8	12	9	12	9
; E	161	145	157	141	

SHIFTRhash16	MACRO	file, qty ; fill with Carry
	LOCAL	 _8, _4, _2, _1, _end

	TEST	qty
	BR_ZE	_end
	; 3 if skip to end
	
	MOVF	STATUS, W	; save status( for Carry bit )
	MOVWF	SCRATCH
	; 5 for full setup
	
	BTFSS	qty, 4 ; shift by 16: all bits are replaced by C
	GOTO	_8
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file
	MOVWF	file + 1
	GOTO 	_end
	; 8, 3 if skip
_8:
	BTFSS	qty, 3 ; shift by 8: swap high byte with low, replace high with C
	GOTO	_4
	MOVF	file + 1, W
	MOVWF	file
	CLRW
	BTFSC	STATUS, C
	MOVLW	0xFF
	MOVWF	file + 1
	MOVF	SCRATCH, W
	; 9, 3 if skip
	
_4:
	BTFSS	qty, 2 ; shift by 4
	GOTO	_2
	
	RRF	file + 1, F
	RRF	file, F
	MOVWF	STATUS
	RRF	file + 1, F
	RRF	file, F
	MOVWF	STATUS
	RRF	file + 1, F
	RRF	file, F
	MOVWF	STATUS
	RRF	file + 1, F
	RRF	file, F	
	MOVWF	STATUS
	; 14, 3 if skip	
	
	
	; Shift Right ->	;     file + 1     file
				; f = ponm lkji  hgfe dcba
	;MOVLW	0xF0		; w = 1111 0000
	;ANDWF	file, F		; f = ponm lkji  hgfe 0000
	;SWAPF	file, F		; f = ponm lkji  0000 hgfe
	
	;SWAPF	file + 1, F	; f = lkji ponm  0000 hgfe
	;ANDWF	file + 1, W	; w = lkji 0000
	;IORWF	file, F		; f = lkji ponm  lkji hgfe	
	
	;MOVLW 0x0F		; w = 0000 1111
	;ANDWF	file + 1, F	; f = 0000 ponm  lkji hgfe
	;MOVLW 0xF0		; w = 1111 0000
	;BTFSC	STATUS, C	; 
	;IORWF	file + 1, F	; f = 1111 ponm  lkji hgfe
	
	;MOVF	SCRATCH, W
	;MOVWF	STATUS, W
	; 13, 3 if skip
	
_2:
	BTFSS	qty, 1 ; shift by 2
	GOTO	_1
	
	RRF	file + 1, F
	RRF	file, F
	MOVWF	STATUS
	RRF	file + 1, F
	RRF	file, F
	MOVWF	STATUS
	; 8, 3 if skip 
_1:
	BTFSC	qty, 0 ; shift by 1
	RRF	file, F	
	; always 2
_end:
	ENDM
;qty	cycles
; 0	3
; 1	19
; 2	24
; 3	24
; 4	28
; 5	28
; 6	33
; 7	33
; 8	25
; 9	25
;10	30
;11	30
;12	34
;13	34
;14	42
;15	42
;16	13
;E	467
	
SHIFTRhash16loop	MACRO	file, qty ; fill with Carry
	LOCAL	_top, _end

	TEST	qty
	BR_ZE	_end
	; 3 if skip to end
	
	MOVF	qty, W
	MOVWF	SCRATCH
	MOVF	STATUS, W	; save status( for Carry bit )
	; 6 for full setup

_top
	RRF	file + 1, F
	RRF	file, F
	MOVWF	STATUS
	DECFSZ	qty, F
	GOTO _top
	;5 pass, 6 loop
	MOVF	SCRATCH, W
	MOVWF	qty
	;2
_end
	ENDM

;qty	cycles
; 0	3
; 1	13
; 2	19
; 3	25
; 4	31
; 5	37
; 6	43
; 7	49
; 8	55
; 9	61
;10	67
;11	73
;12	79
;13	85
;14	91
;15	97
;16	103
;E	931
	
	
	