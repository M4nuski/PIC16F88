DIV8:	; D88_Num = D88_Num / 8, D88_Modulo = D88_Num % 8 
	CLRF	D88_Modulo
	
	BCF	STATUS, C	; / 2
	RRF	D88_Num, F
	RRF	D88_Modulo, F
	
	BCF	STATUS, C	; / 4
	RRF	D88_Num, F
	RRF	D88_Modulo, F
	
	BCF	STATUS, C	; / 8
	RRF	D88_Num, F
	RRF	D88_Modulo, F
	
	BCF	STATUS, C	; shift modulo 1 more time to align with nibble
	RRF	D88_Modulo, F
	SWAPF	D88_Modulo, F
	
DIV10: ; div 8bit by 10
	MOV	D88_Num, D88_Modulo
	CLRF	D88_Num

	MOVLW	b'10100000'
	SUBWF	D88_Modulo, F
	SK_BO
	BSF	D88_Num, 4
	SK_NB
	ADDWF	D88_Modulo, F

	MOVLW	b'01010000'
	SUBWF	D88_Modulo, F
	SK_BO
	BSF	D88_Num, 3
	SK_NB
	ADDWF	D88_Modulo, F

	MOVLW	b'00101000'
	SUBWF	D88_Modulo, F
	SK_BO
	BSF	D88_Num, 2
	SK_NB
	ADDWF	D88_Modulo, F

	MOVLW	b'00010100'
	SUBWF	D88_Modulo, F
	SK_BO
	BSF	D88_Num, 1
	SK_NB
	ADDWF	D88_Modulo, F

	MOVLW	b'00001010'
	SUBWF	D88_Modulo, F
	SK_BO
	BSF	D88_Num, 0
	SK_NB			; could be removed if modulo is not used
	ADDWF	D88_Modulo, F	; could be removed if modulo is not used
	RETURN
	
; 33 =	00100001
; shift2
;	10000100
;	00000100

;	01000010
;	00000010

;	00100001
;	00000001
DIV33:; div 8bit by 33
	MOV	D88_Num, D88_Modulo
	CLRF	D88_Num

	MOVLW	b'10000100'
	SUBWF	D88_Modulo, F
	SK_BO
	BSF	D88_Num, 2
	SK_NB
	ADDWF	D88_Modulo, F

	MOVLW	b'01000010'
	SUBWF	D88_Modulo, F
	SK_BO
	BSF	D88_Num, 1
	SK_NB
	ADDWF	D88_Modulo, F

	MOVLW	b'00100001'
	SUBWF	D88_Modulo, F
	SK_BO
	BSF	D88_Num, 0
	SK_NB			; could be removed if modulo is not used
	ADDWF	D88_Modulo, F	; could be removed if modulo is not used
	RETURN
	
	
	
	
DIV88:	; D88_Fract = D88_Num / D88_Denum, D88_Num = D88_Num % D88_Denum 
	CLRF	D88_Fract
	
	MOVF	D88_Denum, F	; return if Denum is 0
	BTFSC	STATUS, Z
	RETURN
	
	STR	0x01, D88_Modulo
	BTFSC	D88_Denum, 7
	GOTO	_div88Loop
	
_div88Prep:
	BCF	STATUS, C
	RLF	D88_Denum, F
	BCF	STATUS, C
	RLF	D88_Modulo, F
	BTFSS	D88_Denum, 7
	GOTO	_div88Prep
	
_div88Loop:
	SUB	D88_Num, D88_Denum
	BR_GT	_div88pos
	BR_LT	_div88neg
;if equal
	ADD	D88_Fract, D88_Modulo
	RETURN
_div88pos:
	ADD	D88_Fract, D88_Modulo
	GOTO	_div88roll
_div88neg:
	ADD	D88_Num, D88_Denum
_div88roll:
	BCF	STATUS, C
	RRF	D88_Denum, F
	BCF	STATUS, C
	RRF	D88_Modulo, F
	BTFSS	STATUS, C
	GOTO	_div88Loop	

	RETURN
	
	
	
DIV1616:; D88_Fract = D88_Num / D88_Denum, D88_Num = D88_Num % D88_Denum
	CLRFs	D88_Fract

	TESTs	D88_Denum	; return if Denum is 0
	SK_NZ
	RETURN

_DIV1616_start:	
	STRs	0x0001, D88_Modulo
	
	BTFSCs	D88_Denum, 15
	GOTO	_DIV1616_loop
	
_DIV1616_preShift:
	BCF	STATUS, C
	RLFs	D88_Denum
	BCF	STATUS, C
	RLFs	D88_Modulo
	BTFSSs	D88_Denum, 15
	GOTO	_DIV1616_preShift
	
_DIV1616_loop:
	SUBs	D88_Num, D88_Denum
	BR_GT	_DIV1616_pos
	BR_LT	_DIV1616_neg
;if equal
	ADDs	D88_Fract, D88_Modulo
	RETURN
_DIV1616_pos:
	ADDs	D88_Fract, D88_Modulo
	GOTO	_DIV1616_roll
_DIV1616_neg:
	ADDs	D88_Num, D88_Denum
_DIV1616_roll:
	BCF	STATUS, C
	RRFs	D88_Denum
	BCF	STATUS, C
	RRFs	D88_Modulo
	BTFSS	STATUS, C
	GOTO	_DIV1616_loop	

	RETURN
	
	
;idx '0000 0000  0000 0001'
; 10 '0000 0000  0000 1010' b0
; 10 '1010 0000  0000 0000' b12
;idx '0001 0000  0000 0000'
DIV10c:	; div by 10, 24 bit; D88_Fract = D88_Num / 10, D88_Num = D88_Num % 10
	CLRFc	D88_Fract
	;STRc	b'000100000000000000000000', D88_Modulo
	;STRc	b'101000000000000000000000', D88_Denum
	
	STRc	0x100000, D88_Modulo
	STRc	0xA00000, D88_Denum
	
_DIV10c_loop:
	SUBc	D88_Num, D88_Denum
	BR_GT	_DIV10c_pos
	BR_LT	_DIV10c_neg
;if equal
	ADDc	D88_Fract, D88_Modulo
	RETURN
_DIV10c_pos:
	ADDc	D88_Fract, D88_Modulo
	GOTO	_DIV10c_roll
_DIV10c_neg:
	ADDc	D88_Num, D88_Denum
_DIV10c_roll:
	BCF	STATUS, C
	RRFc	D88_Denum
	BCF	STATUS, C
	RRFc	D88_Modulo
	
	BTFSS	STATUS, C
	GOTO	_DIV10c_loop
	RETURN

