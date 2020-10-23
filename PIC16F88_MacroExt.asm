;#############################################################################
;	PIC16F88 Extension Macro
;	16, 24 and 32 bits operation extensions
;	Suffixes:
;	- s short  16bit
;	- c color  24bit
;	- i int    32bit
;	- d double 64bit (Not yet implemented) 
;
;	- f file
;	- l literal
;	- w w register
;	- u unsigned (Not yet implemented) 
;	- s signed (Not yet implemented) 
;
;	Operations:
;	TESTx
;	COMPx_x_x
;	STRx, MOVEx, SAWPx, NEGx
;	ADDx, ADDLx, SUBx, SUBLx, SUBFx, SUBFLx
;	CLRFx, INCFx, DECFx, DECFSZx
;	RLFx, RRFx, COMFx, ADDx, IORx, XORx
;	ASSERTx
;#############################################################################
; TODO new instructions:
;	BS, BC with 2 operands as files (file to test, file with bit index)
;	BTSS, BTSC with 2 operands as files
;	SHIFTR, SHIFTL with # of bit shifted from file + optimized to avoid multiple RLF and RRF on 4/8/12/16/20/24/28/32
; 	MULT, DIV
;	packed BCD arithmetics
;	string utilities

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
	CLRF	SCRATCH
	
	MOVF	file, F
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	file + 1, F
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	file + 2, F
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	
TESTi	MACRO	file
	CLRF	SCRATCH
	
	MOVF	file, F
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	file + 1, F
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	file + 2, F
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVF	file + 3, F
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	
	
	
;#############################################################################
;	Compare
;	Result in STATUS Z and C
;#############################################################################

COMPs_l_f	MACRO	lit, file	; 16bit literal vs file
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
	
COMPs_f_f	MACRO	file1, file2	; 16bit file1 vs file2
	LOCAL	_NB, _BR, _END	
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
	GOTO	_END
	
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
	GOTO	_END
	
_NB:
	MOVF	file2 + 1, W
	SUBWF	file1 + 1, W		; w = file1 - file2
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	
_END:
	ENDM
	
COMPi_f_f	MACRO	file1, file2	; 32bit file1 vs file2
	LOCAL	_b1, _b2, _b3, _r1, _r0, _END

#DEFINE sC0	0	; scratch C/#B byte 0
#DEFINE sC1	1	; scratch C/#B byte 1
#DEFINE sC2	2	; scratch C/#B byte 2
#DEFINE sC3	3	; scratch C/#B byte 3
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
	BTFBC	SCRATCH, sC0, _END
	INCF	file1 + 1, F
	SK_NC
	INCF	file1 + 2, F
	SK_NC
	INCF	file1 + 3, F
	
	
_END:
	; restore final STATUS values
	CLRF	STATUS
	BTFSC	SCRATCH, sfC
	BSF	STATUS, C	
	BTFSC	SCRATCH, sfZ
	BSF	STATUS, Z
	ENDM

; TODO
;COMPc_l_f
;COMPc_f_f

;COMPi_l_f
;COMPi_f_f



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
	CLRF	SCRATCH		; scratch register to keep track of STATUS Z flag, inverted to reduce setup time
	
	MOVF	b, W
	ADDWF 	a, F
	
	SK_ZE
	BSF	SCRATCH, Z
	SK_NC
	INCF	a + 1, F
	
	MOVF	b + 1, W
	ADDWF	a + 1, F
	
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z	; clear status Z flag if any one of the add instruction didn't produce a Z
	ENDM

ADDc	MACRO	a, b	; a = a + b
	CLRF	SCRATCH	
	
	MOVF	b, W
	ADDWF 	a, F
	
	SK_ZE
	BSF	SCRATCH, Z
	SK_NC
	INCF	a + 1, F
	SK_NC
	INCF	a + 2, F
	
	MOVF	b + 1, W
	ADDWF	a + 1, F
	
	SK_ZE
	BSF	SCRATCH, Z
	SK_NC
	INCF	a + 2, F
	
	MOVF	b + 2, W
	ADDWF	a + 2, F
	
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z	
	ENDM

ADDi	MACRO	a, b	; a = a + b
	LOCAL	_b1
	CLRF	SCRATCH	
	
	MOVF	b, W
	ADDWF 	a, F		; add
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	BR_NC	_b1
	INCF	a + 1, F	; propagate Carry
	SK_NC
	INCF	a + 2, F
	SK_NC
	INCF	a + 3, F
_b1:
	MOVF	b + 1, W	; load next byte
	ADDWF	a + 1, F	; add
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag
	SK_NC
	INCF	a + 2, F	; propagate Carry
	SK_NC
	INCF	a + 3, F
	
	MOVF	b + 2, W
	ADDWF	a + 2, F
	
	SK_ZE
	BSF	SCRATCH, Z
	SK_NC	
	INCF	a + 3, F
	
	MOVF	b + 3, W
	ADDWF	a + 3, F
	
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	


;#############################################################################
;	Subtract content of 2 files
;	 a = a - b
;#############################################################################

SUBs	MACRO	a, b	; a = a - b
	CLRF	SCRATCH	
	
	MOVF	b, W
	SUBWF	a, F
	
	SK_ZE
	BSF	SCRATCH, Z
	SK_NB	
	DECF	a + 1, F
	
	MOVF	b + 1, W
	SUBWF	a + 1, F
	
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	
SUBc	MACRO	a, b	; a = a - b
	CLRF	SCRATCH	
	
	MOVF	b, W
	SUBWF	a, F
	
	SK_ZE
	BSF	SCRATCH, Z
	SK_NB
	DECF	a + 1, F
	SK_NB
	DECF	a + 2, F
	
	MOVF	b + 1, W
	SUBWF	a + 1, F
	
	SK_ZE
	BSF	SCRATCH, Z
	SK_NB
	DECF	a + 2, F
	
	MOVF	b + 2, W
	SUBWF	a + 2, F
	
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	
SUBi	MACRO	a, b	; a = a - b
	LOCAL	_b1
	CLRF	SCRATCH	
	
	MOVF	b, W
	SUBWF	a, F		; sub
	
	SK_ZE			; save #Z flag
	BSF	SCRATCH, Z
	BR_NB	_b1		; propagate Borrow
	DECF	a + 1, F
	SK_NB
	DECF	a + 2, F
	SK_NB
	DECF	a + 3, F
_b1:
	MOVF	b + 1, W	; next byte
	SUBWF	a + 1, F	; sub
	
	SK_ZE			; save #Z
	BSF	SCRATCH, Z
	SK_NB			; propagate Borrow
	DECF	a + 2, F
	SK_NB
	DECF	a + 3, F
	
	MOVF	b + 2, W
	SUBWF	a + 2, F
	
	SK_ZE
	BSF	SCRATCH, Z
	SK_NB
	DECF	a + 3, F
	
	MOVF	b + 3, W
	SUBWF	a + 3, F
	
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM



;#############################################################################
;	Add literal to file content
;	 a = a + lit
;#############################################################################

ADDLs	MACRO	a, lit	; a = a + lit
	CLRF	SCRATCH	
	
	MOVLW	( lit & 0x00FF ) >> 0
	ADDWF 	a, F		; add
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	SK_NC
	INCF	a + 1, F	; propagate Carry

	MOVLW	( lit & 0xFF00 ) >> 8
	ADDWF	a + 1, F
	
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	
ADDLc	MACRO	a, lit	; a = a + lit
	CLRF	SCRATCH	
	
	MOVLW	( lit & 0x0000FF ) >> 0
	ADDWF 	a, F		; add
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	SK_NC
	INCF	a + 1, F	; propagate Carry
	SK_NC
	INCF	a + 2, F
	
	MOVLW	( lit & 0x00FF00 ) >> 8; load next byte
	ADDWF	a + 1, F
	
	SK_ZE
	BSF	SCRATCH, Z
	SK_NC
	INCF	a + 2, F

	MOVLW	( lit & 0xFF0000 ) >> 16
	ADDWF	a + 2, F
	
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM

ADDLi	MACRO	a, lit	; a = a + lit
	LOCAL	_b1
	CLRF	SCRATCH	
	
	MOVLW	( lit & 0x000000FF ) >> 0
	ADDWF 	a, F		; add
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	BR_NC	_b1
	INCF	a + 1, F	; propagate Carry
	SK_NC
	INCF	a + 2, F
	SK_NC
	INCF	a + 3, F
_b1:
	MOVLW	( lit & 0x0000FF00 ) >> 8; load next byte
	ADDWF	a + 1, F	; add
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag
	SK_NC
	INCF	a + 2, F	; propagate Carry
	SK_NC
	INCF	a + 3, F
	
	MOVLW	( lit & 0x00FF0000 ) >> 16
	ADDWF	a + 2, F
	
	SK_ZE
	BSF	SCRATCH, Z
	SK_NC	
	INCF	a + 3, F
	
	MOVLW	( lit & 0xFF000000 ) >> 24
	ADDWF	a + 3, F
	
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM



;#############################################################################
;	Subtract literal from file content
;	 a = a - lit
;#############################################################################

SUBLs	MACRO	a, lit	; a = a - lit
	CLRF	SCRATCH	
	
	MOVLW	( lit & 0x00FF ) >> 0
	SUBWF 	a, F		; subtract
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	SK_NB
	DECF	a + 1, F	; propagate Borrow
	
	MOVLW	( lit & 0xFF00 ) >> 8; load next byte
	SUBWF	a + 1, F	; subtract

	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	
SUBLc	MACRO	a, lit	; a = a - lit
	CLRF	SCRATCH	
	
	MOVLW	( lit & 0x0000FF ) >> 0
	SUBWF 	a, F		; subtract
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	SK_NB
	DECF	a + 1, F	; propagate Borrow
	SK_NB
	DECF	a + 2, F
	
	MOVLW	( lit & 0x00FF00 ) >> 8; load next byte
	SUBWF	a + 1, F	; subtract
	
	SK_ZE
	BSF	SCRATCH, Z
	SK_NB
	DECF	a + 2, F
	
	MOVLW	( lit & 0xFF0000 ) >> 16
	SUBWF	a + 2, F
	
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	
SUBLi	MACRO	a, lit	; a = a - lit
	LOCAL	_b1
	CLRF	SCRATCH	
	
	MOVLW	( lit & 0x000000FF ) >> 0	
	SUBWF 	a, F		; subtract
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	BR_NB	_b1
	DECF	a + 1, F	; propagate Borrow
	SK_NB
	DECF	a + 2, F
	SK_NB
	DECF	a + 3, F
_b1:
	MOVLW	( lit & 0x0000FF00 ) >> 8; load next byte
	SUBWF	a + 1, F	; subtract
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag
	SK_NB
	DECF	a + 2, F	; propagate Borrow
	SK_NB
	DECF	a + 3, F
	
	MOVLW	( lit & 0x00FF0000 ) >> 16
	SUBWF	a + 2, F
	
	SK_ZE
	BSF	SCRATCH, Z
	SK_NB	
	DECF	a + 3, F
	
	MOVLW	( lit & 0xFF000000 ) >> 24
	SUBWF	a + 3, F
	
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM



;#############################################################################
;	Subtract target from other file
;	 a = b - a
;#############################################################################

SUBFs	MACRO	a, b	; a = b - a
	CLRF	SCRATCH	
	
	MOVF	a, W
	SUBWF	b, W	
	MOVWF	a
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	SK_NB
	DECF	a + 1, F	; propagate Borrow

	MOVF	a + 1, W	; load next byte
	SUBLW	b + 1, W	
	MOVWF	a + 1

	BTFSC	SCRATCH, Z
	BCF	STATUS, Z	
	ENDM
	
SUBFc	MACRO	a, b	; a = b - a
	CLRF	SCRATCH	
	
	MOVF	a, W
	SUBWF	b, W	
	MOVWF	a
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	SK_NB
	DECF	a + 1, F	; propagate Borrow
	SK_NB
	DECF	a + 2, F

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
	LOCAL	_b1
	CLRF	SCRATCH	
	
	MOVF	a, W
	SUBWF	b, W
	MOVWF	a
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	BR_NB	_b1
	DECF	a + 1, F	; propagate Borrow
	SK_NB
	DECF	a + 2, F
	SK_NB
	DECF	a + 3, F
_b1:	
	MOVF	a + 1, W	; load next byte
	SUBLW	b + 1, W
	MOVWF	a + 1
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag
	SK_NB
	DECF	a + 2, F	; propagate Borrow
	SK_NB
	DECF	a + 3, F
		
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
	CLRF	SCRATCH	
	
	MOVF	a, W
	SUBLW	( lit & 0x0000FF ) >> 0
	MOVWF	a
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	SK_NB
	DECF	a + 1, F	; propagate Borrow
	SK_NB
	DECF	a + 2, F
	
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
	LOCAL	_b1
	CLRF	SCRATCH	
	
	MOVF	a, W
	SUBLW	( lit & 0x000000FF ) >> 0
	MOVWF	a
		
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	BR_NB	_b1
	DECF	a + 1, F	; propagate Borrow
	SK_NB
	DECF	a + 2, F
	SK_NB
	DECF	a + 3, F
_b1:
	MOVF	a + 1, W	; load next byte
	SUBLW	( lit & 0x0000FF00 ) >> 8
	MOVWF	a + 1
	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag
	SK_NB
	DECF	a + 2, F	; propagate Borrow
	SK_NB
	DECF	a + 3, F
	
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
	SK_NC
	INCF	file + 1, F
	ENDM
	
NEGc	MACRO	file
	LOCAL	_END
	COMF	file, F
	COMF	file + 1, F
	COMF	file + 2, F
	
	INCF	file, F
	BR_NC	_END
	INCF	file + 1, F
	SK_NC
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
	BR_NC	_END		; propagate carry
	INCF	file + 1, F
	BR_NC	_END
	INCF	file + 2, F
	SK_NC
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
;	Assertion functions to Test and Debug
;	Extended to 16, 24 and 32 bits
;#############################################################################

ASSERTs		MACRO	val, file	; 16 bit val == file content
	MOVLW	(val & 0x000000FF) >> 0
	XORWF	file, W
	BTFSS	STATUS, Z
	STALL
	
	MOVLW	(val & 0x0000FF00) >> 8
	XORWF	file + 1, W
	BTFSS	STATUS, Z
	STALL
	ENDM
	
ASSERTc		MACRO	val, file	; 24 bit val == file content
	MOVLW	(val & 0x000000FF) >> 0
	XORWF	file, W
	BTFSS	STATUS, Z
	STALL
	
	MOVLW	(val & 0x0000FF00) >> 8
	XORWF	file + 1, W
	BTFSS	STATUS, Z
	STALL
	
	MOVLW	(val & 0x00FF0000) >> 16
	XORWF	file + 2, W
	BTFSS	STATUS, Z
	STALL
	ENDM
	
ASSERTi		MACRO	val, file	; 32 bit val == file content
	MOVLW	(val & 0x000000FF) >> 0
	XORWF	file, W
	BTFSS	STATUS, Z
	STALL
	
	MOVLW	(val & 0x0000FF00) >> 8
	XORWF	file + 1, W
	BTFSS	STATUS, Z
	STALL
	
	MOVLW	(val & 0x00FF0000) >> 16
	XORWF	file + 2, W
	BTFSS	STATUS, Z
	STALL

	MOVLW	(val & 0xFF000000) >> 24
	XORWF	file + 3, W
	BTFSS	STATUS, Z
	STALL
	ENDM


