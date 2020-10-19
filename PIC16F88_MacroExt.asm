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
;	STRx, MOVEx, SAWPx, NEGx, ADDx, ADDLx, SUBx, SUBLx, SUBFLx
;	CLRFx, INCFx, DECFx
;	ASSERTx
;#############################################################################



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
	CLRF	SCRATCH	
	MOVF	b, W
	ADDWF 	a, F		; add
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	SK_NC
	INCF	a + 1, F	; propagate Carry
	SK_NC
	INCF	a + 2, F
	SK_NC
	INCF	a + 3, F
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
	CLRF	SCRATCH	
	MOVF	b, W
	SUBWF	a, F		; sub
	SK_ZE			; save #Z flag
	BSF	SCRATCH, Z
	SK_NB			; propagate Borrow
	DECF	a + 1, F
	SK_NB
	DECF	a + 2, F
	SK_NB
	DECF	a + 3, F
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
	CLRF	SCRATCH	
	MOVLW	( lit & 0x000000FF ) >> 0
	ADDWF 	a, F		; add
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	SK_NC
	INCF	a + 1, F	; propagate Carry
	SK_NC
	INCF	a + 2, F
	SK_NC
	INCF	a + 3, F
	
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
	CLRF	SCRATCH	
	MOVLW	( lit & 0x000000FF ) >> 0
	SUBWF 	a, F		; subtract
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	SK_NB
	DECF	a + 1, F	; propagate Borrow
	SK_NB
	DECF	a + 2, F
	SK_NB
	DECF	a + 3, F
	
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
;SUBFs
;SUBFc
SUBFi	MACRO	a, b	; a = b - a
	CLRF	SCRATCH	
	
	MOVF	a, W
	SUBWF	b, W	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	SK_NB
	DECF	a + 1, F	; propagate Borrow
	SK_NB
	DECF	a + 2, F
	SK_NB
	DECF	a + 3, F
	
	MOVWF	a
	
	MOVF	a + 1, W	; load next byte
	SUBLW	b + 1, W	
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag
	SK_NB
	DECF	a + 2, F	; propagate Borrow
	SK_NB
	DECF	a + 3, F
	
	MOVWF	a + 1
		
	MOVF	a + 2, W	; load next byte
	SUBLW	b + 2, W	
	SK_ZE
	BSF	SCRATCH, Z
	SK_NB	
	DECF	a + 3, F
	
	MOVWF	a + 2
	
	MOVF	a + 3, W	; load next byte
	SUBLW	b + 3, W
	SK_ZE
	BSF	SCRATCH, Z

	MOVWF	a + 3
	
	BSF	STATUS, Z
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
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	SK_NB
	DECF	a + 1, F	; propagate Borrow
	
	MOVWF	a
	
	MOVF	a + 1, W	; load next byte
	SUBLW	( lit & 0xFF00 ) >> 8
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVWF	a + 1
	
	BSF	STATUS, Z
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	
SUBFLc	MACRO	a, lit	; a = lit - a
	CLRF	SCRATCH	
	
	MOVF	a, W
	SUBLW	( lit & 0x0000FF ) >> 0
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	SK_NB
	DECF	a + 1, F	; propagate Borrow
	SK_NB
	DECF	a + 2, F
	
	MOVWF	a
	
	MOVF	a + 1, W	; load next byte
	SUBLW	( lit & 0x00FF00 ) >> 8
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag
	SK_NB
	DECF	a + 2, F	; propagate Borrow
	
	MOVWF	a + 1
	
	MOVF	a + 2, W	; load next byte
	SUBLW	( lit & 0xFF0000 ) >> 16
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVWF	a + 2
	
	BSF	STATUS, Z
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	
SUBFLi	MACRO	a, lit	; a = lit - a
	CLRF	SCRATCH	
	
	MOVF	a, W
	SUBLW	( lit & 0x000000FF ) >> 0
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag for this byte
	SK_NB
	DECF	a + 1, F	; propagate Borrow
	SK_NB
	DECF	a + 2, F
	SK_NB
	DECF	a + 3, F
	
	MOVWF	a
	
	MOVF	a + 1, W	; load next byte
	SUBLW	( lit & 0x0000FF00 ) >> 8
	SK_ZE
	BSF	SCRATCH, Z	; save #Z flag
	SK_NB
	DECF	a + 2, F	; propagate Borrow
	SK_NB
	DECF	a + 3, F
	
	MOVWF	a + 1
	
	MOVF	a + 2, W	; load next byte
	SUBLW	( lit & 0x00FF0000 ) >> 16
	SK_ZE
	BSF	SCRATCH, Z
	SK_NB	
	DECF	a + 3, F
	
	MOVWF	a + 2
	
	MOVF	a + 3, W	; load next byte
	SUBLW	( lit & 0xFF000000 ) >> 24
	SK_ZE
	BSF	SCRATCH, Z
	
	MOVWF	a + 3
	
	BSF	STATUS, Z
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z	
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
DECFs 	MACRO
	MOVLW	0x01
	SUBWF	file, F	
	SK_NB
	SUBWF	file + 1, F
	ENDM

DECFc	MACRO
	LOCAL	_END
	
	MOVLW	0x01
	SUBWF	file, F	
	BR_NB	_END
	SUBWF	file + 1, F
	SK_NB
	SUBWF	file + 2, F
_END:
	ENDM

DECFi	MACRO
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


