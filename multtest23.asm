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

	
	Test_Footer