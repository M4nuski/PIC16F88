#INCLUDE	<PIC16F88_Macro_Tester.asm>	
	
data_H10	EQU	var1
data_H01	EQU	var2
data_m10	EQU	var3
data_m01	EQU	var4
data_s10	EQU	var5
data_s01	EQU	var6

dest		EQU	var3

Arg1		EQU	8
Arg2		EQU	8
Result		EQU	Arg1 * Arg2

	NOP
	; GT
	MOVLW	35
	CMP_LW	36; > 35
	SK_GT
	ASSERT_SKIPPED
	
	MOVLW	35
	CMP_LW	35; > 35
	SK_GT
	ASSERT_NOT_SKIPPED
	
	MOVLW	35
	CMP_LW	34; > 35
	SK_GT
	ASSERT_NOT_SKIPPED
	
	NOP
	; GE
	MOVLW	35
	CMP_LW	36; >= 35
	SK_GE
	ASSERT_SKIPPED
	
	MOVLW	35
	CMP_LW	35; >= 35
	SK_GE
	ASSERT_SKIPPED
	
	MOVLW	35
	CMP_LW	34; >= 35
	SK_GE
	ASSERT_NOT_SKIPPED
	
	NOP	
	; LT
	MOVLW	35
	CMP_LW	36; < 35
	SK_LT
	ASSERT_NOT_SKIPPED
	
	MOVLW	35
	CMP_LW	35; < 35
	SK_LT
	ASSERT_NOT_SKIPPED
	
	MOVLW	35
	CMP_LW	34; < 35
	SK_LT
	ASSERT_SKIPPED
	
	NOP
	; LE
	MOVLW	35
	CMP_LW	36; <= 35
	SK_LE
	ASSERT_NOT_SKIPPED
	
	MOVLW	35
	CMP_LW	35; <= 35
	SK_LE
	ASSERT_SKIPPED
	
	MOVLW	35
	CMP_LW	34; <= 35
	SK_LE
	ASSERT_SKIPPED
	NOP
	
		
	MOVLW	0x02
	MOVWF	data_H10
	MOVLW	0x03
	MOVWF	data_H01
	
	BCF	STATUS, C
	RLF	data_H10, F ; h10  = 2*h10
	MOVF	data_H10, W ; w = 2*h10
	BCF	STATUS, C
	RLF	data_H10, F ; h10  = 4*h10
	RLF	data_H10, F ; h10  = 8*h10
	ADDWF	data_H10, W
	
	ADDWF	data_H01, F ; h01 = 10*h10 + h01 = HH(utc)
	

	
	

	MOVLW	Arg1
	MOVWF	var1
	MOVLW	Arg2
	MOVWF	var2
	
	Test_StartCounter 1
	CLRF	dest
	CLRF	dest + 1
	CLRF	SCRATCH
	
	MOVF	var1, F
	BTFSC	STATUS, Z
	GOTO	_END
	MOVF	var2, F
	BTFSC	STATUS, Z
	GOTO	_END
	
	BTFSS	var1, 0
	GOTO	_1
	
	MOVF	var2, W
	MOVWF	dest
_1:
	BCF	STATUS, C
	RLF	var2, F
	RLF	SCRATCH, F
	BTFSS	var1, 1
	GOTO	_2
	
	MOVF	var2, W
	ADDWF	dest, F
	BTFSC	STATUS, C
	INCF	dest + 1, F
	MOVF	SCRATCH, W
	ADDWF	dest + 1, F
_2:	
	BCF	STATUS, C
	RLF	var2, F
	RLF	SCRATCH, F
	BTFSS	var1, 2
	GOTO	_3
	
	MOVF	var2, W
	ADDWF	dest, F
	BTFSC	STATUS, C
	INCF	dest + 1, F
	MOVF	SCRATCH, W
	ADDWF	dest + 1, F

_3:	
	BCF	STATUS, C
	RLF	var2, F
	RLF	SCRATCH, F
	BTFSS	var1, 3
	GOTO	_4
	
	MOVF	var2, W
	ADDWF	dest, F
	BTFSC	STATUS, C
	INCF	dest + 1, F
	MOVF	SCRATCH, W
	ADDWF	dest + 1, F

_4:	
	BCF	STATUS, C
	RLF	var2, F
	RLF	SCRATCH, F
	BTFSS	var1, 4
	GOTO	_5
	
	MOVF	var2, W
	ADDWF	dest, F
	BTFSC	STATUS, C
	INCF	dest + 1, F
	MOVF	SCRATCH, W
	ADDWF	dest + 1, F

_5:	
	BCF	STATUS, C
	RLF	var2, F
	RLF	SCRATCH, F
	BTFSS	var1, 5
	GOTO	_6
	
	MOVF	var2, W
	ADDWF	dest, F
	BTFSC	STATUS, C
	INCF	dest + 1, F
	MOVF	SCRATCH, W
	ADDWF	dest + 1, F

_6:	
	BCF	STATUS, C
	RLF	var2, F
	RLF	SCRATCH, F
	BTFSS	var1, 6
	GOTO	_7
	
	MOVF	var2, W
	ADDWF	dest, F
	BTFSC	STATUS, C
	INCF	dest + 1, F
	MOVF	SCRATCH, W
	ADDWF	dest + 1, F

_7:	
	BTFSS	var1, 7
	GOTO	_END
	
	BCF	STATUS, C
	RLF	var2, F
	RLF	SCRATCH, F

	MOVF	var2, W
	ADDWF	dest, F
	BTFSC	STATUS, C
	INCF	dest + 1, F
	MOVF	SCRATCH, W
	ADDWF	dest + 1, F

_END:
	Test_StopCounter var5
	
	;ASSERTs	Result, dest
	
	NOP
	NOP

MULT88l	MACRO	dest, a, b ;dest is 2 bytes, a and b are 1 byte
	LOCAL	_next, _shift, _end
	
	CLRF	dest
	CLRF	dest + 1
	CLRF	SCRATCH
	
	MOVF	b, W		; test that b !=0
	BTFSC	STATUS, Z
	GOTO	_end	
_next
	MOVF	a, F		;test if "a" have bits set to 1
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
	
	MOVLW	Arg1	
	MOVWF	var1
	MOVLW	Arg2
	MOVWF	var2
	
	Test_StartCounter 1
	MULT88l var4, var1, var2
	Test_StopCounter var6
	
	;ASSERTs	Result, dest
	
	NOP
	NOP
	NOP
	
DIV88	MACRO dest, a, b
	; dest = a / b, dest + 1 = a % b
	MOVF	b, F
	BR_ZE	_div88End
	CLRF	dest
	MOV	a, dest + 1
	MOV	b, var8
	STR	0x01, SCRATCH	
	BTFSC	var8, 7
	GOTO	_div88Loop
	
_div88Prep:
	BCF	STATUS, C
	RLF	var8, F
	BCF	STATUS, C
	RLF	SCRATCH, F
	BTFSS	var8, 7
	GOTO	_div88Prep
_div88Loop:
	SUB	dest + 1, var8
	BR_EQ	_div88eq
	BR_GT	_div88pos
	BR_LT	_div88neg
_div88eq:
	ADD	dest, SCRATCH
	GOTO	_div88End
_div88pos:
	ADD	dest, SCRATCH
	GOTO	_div88roll
_div88neg:
	ADD	dest + 1, var8
	GOTO	_div88roll
_div88roll:
	BCF	STATUS, C
	RRF	var8, F
	BCF	STATUS, C
	RRF	SCRATCH, F
	BTFSS	STATUS, C
	GOTO	_div88Loop	
_div88End:
	ENDM
	
	MOVLW	235	
	MOVWF	var1
	MOVLW	8	
	MOVWF	var2
	
	Test_StartCounter 1
	DIV88 var3, var1, var2
	Test_StopCounter var6
	
	NOP
	NOP
	NOP
	NOP

D88_Num		EQU	var1
D88_Fract	EQU	var2

	MOVLW	235	
	MOVWF	D88_Num
	
	Test_StartCounter 1
	
D8:	; D88_Fract = D88_Num / D88_Denum, D88_Num = D88_Num % D88_Denum 
	CLRF	D88_Fract
	
	BCF	STATUS, C	; / 2
	RRF	D88_Num, F
	RRF	D88_Fract, F
	
	BCF	STATUS, C	; / 4
	RRF	D88_Num, F
	RRF	D88_Fract, F
	
	BCF	STATUS, C	; / 8
	RRF	D88_Num, F
	RRF	D88_Fract, F
	
	BCF	STATUS, C	; shift modulo 1 more time to align with nibble
	RRF	D88_Fract, F
	SWAPF	D88_Fract, F
	
	Test_StopCounter var6
	
	
	NOP
	NOP
	NOP
	MOVLW	10
	NOP
	NOP
	NOP
D8_Num		EQU	var1
D8_Modulo	EQU	var2

;http://www.piclist.com/techref/method/math/divconst.htm
DIV10	MACRO
	MOVF	D8_Num, W
	MOVWF	D8_Modulo
	CLRF	D8_Num

	MOVLW	b'10100000'
	SUBWF	D8_Modulo, F
	SK_BO
	BSF	D8_Num, 4
	SK_NB
	ADDWF	D8_Modulo, F

	MOVLW	b'01010000'
	SUBWF	D8_Modulo, F
	SK_BO
	BSF	D8_Num, 3
	SK_NB
	ADDWF	D8_Modulo, F

	MOVLW	b'00101000'
	SUBWF	D8_Modulo, F
	SK_BO
	BSF	D8_Num, 2
	SK_NB
	ADDWF	D8_Modulo, F

	MOVLW	b'00010100'
	SUBWF	D8_Modulo, F
	SK_BO
	BSF	D8_Num, 1
	SK_NB
	ADDWF	D8_Modulo, F

	MOVLW	b'00001010'
	SUBWF	D8_Modulo, F
	SK_BO
	BSF	D8_Num, 0
	SK_NB
	ADDWF	D8_Modulo, F
	ENDM
	

    MOVLW	235
    MOVWF	D8_Num
    	Test_StartCounter 1
    DIV10
    	Test_StopCounter var6
	
	NOP
	NOP
	NOP
	MOVLW	33
	NOP
	NOP
	NOP
	
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
	
ADDc	MACRO	a, b	; a = a + b
	LOCAL	_nc0
	
	CLRF	SCRATCH	
	
	MOVF	b, W
	ADDWF 	a, F
	
	SK_ZE
	BSF	SCRATCH, Z
	BR_NC	_nc0
	INCF	a + 1, F
	SK_NZ
	INCF	a + 2, F
_nc0:
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
	
STRc	MACRO	lit, to
	MOVLW	( lit & 0x0000FF )
	MOVWF	to
	MOVLW	( lit & 0x00FF00 ) >> 8
	MOVWF	to + 1
	MOVLW	( lit & 0xFF0000 ) >> 16
	MOVWF	to + 2
	ENDM
	
RRFc	MACRO	file
	RRF	file + 2, F	
	RRF	file + 1, F	
	RRF	file, F
	ENDM
	
	
D88_Num		EQU	var1
D88_Fract	EQU	var2
D88_Denum	EQU	var3
D88_Modulo	EQU	var4

	NOP
	NOP
	NOP
	NOP
	NOP
	NOP

testAddC	MACRO	val1,val2
	STRc	val1, var1
	STRc	val2, var2
	ADDc	var1, var2
	SUBc	var1, var2
	ADDc	var1, var2
	ASSERTc	(val1+val2) & 0xFFFFFF, var1
	ENDM
	; 0xFD 0xFE 0xFF 0x00 0x01 0x02
	; 0x0000aa 0x00aa00 0xaa0000
	testAddC	0x000000, 0x000000
	testAddC	0xFFFFFF, 0x000000
	testAddC	0x000001, 0x000001
	testAddC	0x000001, 0x000002
	testAddC	0x010000, 0x00FFFF
	testAddC	0x010000, 0x010000
	testAddC	0x010000, 0x010001
	testAddC	0x010000, 0x010101
	
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP

	CLRF	D88_Num
	CLRF	D88_Num + 1
	CLRF	D88_Num + 2
	CLRF	D88_Num + 3
	
	CLRF	D88_Fract
	CLRF	D88_Fract + 1
	CLRF	D88_Fract + 2
	CLRF	D88_Fract + 3
	
	CLRF	D88_Denum
	CLRF	D88_Denum + 1
	CLRF	D88_Denum + 2
	CLRF	D88_Denum + 3
	
	CLRF	D88_Modulo
	CLRF	D88_Modulo + 1
	CLRF	D88_Modulo + 2
	CLRF	D88_Modulo + 3
	
	STRc	0x063704, var1
	
	 Test_StartCounter 8
	CALL	DIV33c
    	 Test_StopCounter var6
	 
	STALL
;	000001100011011100000100 ;num	
;	100001000000000000000000 ;less
;	010000100000000000000000 ;less
;	001000010000000000000000 ;less
;
;	000100001000000000000000 ;less
;	000010000100000000000000 ;less
;	
;	000001100011011100000100 ;num
;	000001000010000000000000 ;gt
;	
;	000000100001011100000100 ;num
;	000000100001000000000000 ;gt
;	
;	000000000000011100000100 ;num
;	000000010000100000000000 ;less
;	000000001000010000000000 ;less
;	000000000100001000000000 ;less
;	
;	000000000010000100000000 ;less
;	000000000001000010000000 ;less
;	000000000000100001000000 ;less
;	
;	000000000000011100000100 ;num
;	000000000000010000100000 ;gt
;	
;	000000000000001011100100 ;num	
;	000000000000001000010000 ;gt
;	
;	000000000000000011010100 ;num	
;	000000000000000100001000 ;less
;	
;	000000000000000011010100 ;num	
;	000000000000000010000100 ;gt
;	
;	000000000000000001010000 ;num	
;	000000000000000001000010 ;gt
;	
;	000000000000000000001110 ;num	
;	000000000000000000100001 ;less
;		
DIV33c:	; div by 33, 24 bit ; D88_Fract = D88_Num / 33, D88_Num = D88_Num % 33
	CLRF	D88_Fract
	CLRF	D88_Fract + 1
	CLRF	D88_Fract + 2
	;STRc	b'0000 0100  0000 0000  0000 0000', D88_Modulo
	;STRc	b'1000 0100  0000 0000  0000 0000', D88_Denum
	
	STRc	0x040000, D88_Modulo
	STRc	0x840000, D88_Denum
	
_DIV33c_loop:
	SUBc	D88_Num, D88_Denum
	BR_GT	_DIV33c_pos
	BR_LT	_DIV33c_neg
;if equal
	ADDc	D88_Fract, D88_Modulo
	RETURN
_DIV33c_pos:
	ADDc	D88_Fract, D88_Modulo
	GOTO	_DIV33c_roll
_DIV33c_neg:
	ADDc	D88_Num, D88_Denum
_DIV33c_roll:
	BCF	STATUS, C
	RRFc	D88_Denum
	BCF	STATUS, C
	RRFc	D88_Modulo
	
	BTFSS	STATUS, C
	GOTO	_DIV33c_loop
	RETURN
	

	
	Test_Footer