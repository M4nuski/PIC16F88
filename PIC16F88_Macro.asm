BANK0	MACRO
	BCF	STATUS, RP0
	BCF	STATUS, RP1
	ENDM

BANK1	MACRO
	BSF	STATUS, RP0
	BCF	STATUS, RP1
	ENDM

BANK2	MACRO
	BCF	STATUS, RP0
	BSF	STATUS, RP1
	ENDM

BANK3	MACRO
	BSF	STATUS, RP0
	BSF	STATUS, RP1
	ENDM

; b byte 8bit
; s short 16bit
; c color 24bit
; i int  32bit
; d double 64bit

; f file
; l literal
; w w register
; u unsigned
; s signed


; Compare a vs b (Sets Z and C)
COMP_l_f	MACRO lit, file	; literal vs file
	MOVF	file, W			; w = f
	SUBLW	lit			; w = l - f(w)
	ENDM
	
COMP_f_f	MACRO file1, file2	; file1 vs file2
	MOVF	file2, W		; w = f2
	SUBWF	file1, W		; w = f1 - f2(w)
	ENDM

COMP_f_w	MACRO file		; file vs w
	SUBWF	file, W			; w = f - w
	ENDM

COMP_l_w	MACRO lit		; literal vs w
	SUBLW	lit			; w = l - w
	ENDM
	
; Branch from COMP result
BR_EQ	MACRO	dest
	BTFSC	STATUS, Z
	GOTO	dest
	ENDM
	
BR_NE	MACRO	dest
	BTFSS	STATUS, Z
	GOTO	dest
	ENDM

BR_GT	MACRO 	dest
	LOCAL	_end
	BTFSC	STATUS, Z	; first test that not equal
	GOTO	_end
	BTFSC	STATUS, C	; skip goto if there was no carry (greater)
	GOTO	dest
_end:
	ENDM

BR_GE	MACRO 	dest
	BTFSC	STATUS, C
	GOTO	dest
	BTFSC	STATUS, Z
	GOTO	dest
	ENDM
	
BR_LT	MACRO	dest
	LOCAL	_end
	BTFSC	STATUS, Z	; test that not equal
	GOTO	_end
	BTFSS	STATUS, C	; skip if there was a carry (less)
	GOTO	dest
_end:
	ENDM

BR_LE	MACRO 	dest
	BTFSS	STATUS, C
	GOTO	dest
	BTFSC	STATUS, Z
	GOTO	dest
	ENDM

; Test (check if Zero)
TEST	MACRO	file
	MOVF	file, F
	ENDM
	
TESTw	MACRO
	ANDLW	0xFF
	ENDM
	
TESTs	MACRO file
	CLRF	SCRATCH
	MOVF	file, F
	SK_ZE
	BSF	SCRATCH, Z
	MOVF	file + 1, F
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM

TESTc	MACRO file
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
	
TESTi	MACRO file
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
	
; Branch and Skip from STATUS
BR_ZE	MACRO	dest	; zero
	BTFSC	STATUS, Z
	GOTO	dest
	ENDM
SK_ZE	MACRO
	BTFSS	STATUS, Z
	ENDM
	
BR_NZ	MACRO	dest	; not zero
	BTFSS	STATUS, Z
	GOTO	dest
	ENDM
SK_NZ	MACRO
	BTFSC	STATUS, Z
	ENDM

BR_CA	MACRO	dest	; carry
	BTFSC	STATUS, C
	GOTO	dest
	ENDM
SK_CA	MACRO
	BTFSS	STATUS, C
	ENDM
	
BR_NC	MACRO	dest	; no carry
	BTFSS	STATUS, C
	GOTO	dest
	ENDM
SK_NC	MACRO
	BTFSC	STATUS, C
	ENDM
	
BR_BO	MACRO	dest	; borrow
	BTFSS	STATUS, C
	GOTO	dest
	ENDM
SK_BO	MACRO
	BTFSC	STATUS, C
	ENDM
	
BR_NB	MACRO	dest	; no borrow
	BTFSC	STATUS, C
	GOTO	dest
	ENDM
SK_NB	MACRO
	BTFSS	STATUS, C
	ENDM

; Bit Test File and Branch
BTFBS	MACRO	file, bit, dest	; brach if set
	BTFSC	file, bit
	GOTO	dest
	ENDM
	
BTFBC	MACRO	file, bit, dest	; branch if clear
	BTFSS	file, bit
	GOTO	dest
	ENDM

; Bit Test w and Branch
BTWBS	MACRO	bit, dest		; branch if set
	MOVWF	SCRATCH
	BTFSC	SCRATCH, bit
	GOTO	dest
	ENDM
	
BTWBC	MACRO	bit, dest		; branch if clear
	MOVWF	SCRATCH
	BTFSS	SCRATCH, bit
	GOTO	dest
	ENDM

; Bit Test W and Skip
BTWSS	MACRO	bit			; skip if set
	MOVWF	SCRATCH
	BTFSS	SCRATCH, bit
	ENDM
	
BTWSC	MACRO	bit			; skip if clear
	MOVWF	SCRATCH
	BTFSC	SCRATCH, bit
	ENDM

; Store literal to file
STR	MACRO	lit, to			
	MOVLW	lit
	MOVWF	to
	ENDM
	
STRs	MACRO	lit, to
	MOVLW	(lit & 0x00FF)
	MOVWF	to
	MOVLW	(lit & 0xFF00) >> 8
	MOVWF	to + 1
	ENDM
	
STRc	MACRO	lit, to
	MOVLW	(lit & 0x0000FF)
	MOVWF	to
	MOVLW	(lit & 0x00FF00) >> 8
	MOVWF	to + 1
	MOVLW	(lit & 0xFF0000) >> 16
	MOVWF	to + 2
	ENDM
	
STRi	MACRO	lit, to
	MOVLW	(lit & 0x000000FF)
	MOVWF	to
	MOVLW	(lit & 0x0000FF00) >> 8
	MOVWF	to + 1
	MOVLW	(lit & 0x00FF0000) >> 16
	MOVWF	to + 2
	MOVLW	(lit & 0xFF000000) >> 24
	MOVWF	to + 3
	ENDM
	
; Move file data
MOV	MACRO	from, to
	MOVF	from, W
	MOVWF	to

MOVs 	MACRO	from, to
	MOVF	from, W
	MOVWF	to
	MOVF	from + 1, W
	MOVWF	to + 1
	ENDM
	
MOVc 	MACRO from, to
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
	
; TODO SWAP

; Add and Subtract
ADD	MACRO	a, b	; a = a + b
	MOVF	b, W
	ADDWF	a, F
	ENDM

SUB	MACRO	a, b	; a = a - b
	MOVF	b, W
	SUBWF	a, F
	ENDM
	
ADDs	MACRO	a, b	; a = a + b
	CLRF	SCRATCH	; scratch register to keep track of STATUS Z flag, inverted to reduce setup time
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
	
; TODO ADDl and SUBl (with literal)
; ADDL
; ADDls
; ADDLc
; ADDLi
; SUBL
; SUBLs
; SUBLc
; SUBli
	
; Negate (two's complement)
NEG	MACRO 	file
	COMF	file, F
	INCF	file, F
	ENDM
	
NEGw	MACRO
	XORLW	0xFF
	ADDLW	0x01
	ENDM

NEGs	MACRO	file
	COMF	file, F
	COMF	file + 1, F
	INCF	file, F
	SK_NC
	INCF	file + 1, F
	ENDM
	
NEGc	MACRO	file
	COMF	file, F
	COMF	file + 1, F
	COMF	file + 2, F
	INCF	file, F
	SK_NC
	INCF	file + 1, F
	SK_NC
	INCF	file + 2, F
	ENDM
	
NEGi	MACRO	file
	COMF	file, F		; invert
	COMF	file + 1, F
	COMF	file + 2, F
	COMF	file + 3, F	
	INCF	file, F		; inc byte 0		
	SK_NC			; propagate carry
	INCF	file + 1, F
	SK_NC
	INCF	file + 2, F
	SK_NC
	INCF	file + 3, F
	ENDM

; Clear file
; CLRF is standard 8bit instruction
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

; TODO expanded inc file
; INCFs
; INCFc
; INCFi

; TODO expanded dec file
; DECFs 
; DECFc
; DECFi

COMPs_l_f	MACRO	lit, file	; 16bit literal vs file compare
	CLRF	SCRATCH
	
	MOVF	file, W
	SUBLW	(lit & 0x00FF)		; w = lit - file
	SK_ZE
	BSF	SCRATCH, Z
	SK_NB
	BSF	SCRATCH, C		; set C if borrow
	
	CLRW
	BTFSC	SCRATCH, C		; if borrow
	MOVLW	0x01			; preset w to 1

	ADDWF	file + 1, W		; w = file if there was no borrow, or file+1 if there was
					; instead of decreasing the literal for the borrow, the file was increased
	SUBLW	(lit & 0xFF00) >> 8
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM
	
COMPs_f_f	MACRO	file1, file2	; 16bit file1 vs file2 compare
	CLRF	SCRATCH
	
	MOVF	file2, W
	SUBWF	file1, W		; w = file1 - file2	
	SK_ZE
	BSF	SCRATCH, Z		; save #Z
	SK_NB
	BSF	SCRATCH, C		; set C if borrow
	
	; ################### TODO test and debug
	CLRW
	BTFSC	SCRATCH, C
	MOVLW	0x01			; preload w if borrow
	
	ADDWF	file2 + 1, W		; w = (file2) if no borrow on previous byte, or (file2 + 1) if there was 
	SK_NB
	ADDLW	0xFF			; decrease by 1 if there was another borrow from last instruction
	
	; ###################
	
	SUBWF	file2 + 1, W
	BTFSC	SCRATCH, Z
	BCF	STATUS, Z
	ENDM

;COMPc_l_f
;COMPc_f_f

;COMPi_l_f
;COMPi_f_f





; Timer1 helper


READ_TMR1	MACRO dest
	LOCAL READ_TMR1_goodread
	MOVF TMR1H, W ; Read high byte
	MOVWF dest + 1
	MOVF TMR1L, W ; Read low byte
	MOVWF dest
	MOVF TMR1H, W ; Read high byte
	SUBWF dest + 1, W ; Sub 1st read with 2nd read
	BTFSC STATUS, Z ; Is result = 0
	GOTO READ_TMR1_goodread
	; TMR1L may have rolled over between the read of the high and low bytes.
	; Reading the high and low bytes now will read a good value.
	MOVF TMR1H, W ; Read high byte again
	MOVWF dest + 1
	MOVF TMR1L, W ; Read low byte
	MOVWF dest ; Re-enable the Interrupt (if required)
READ_TMR1_goodread:  ; Continue with your code
	ENDM



; Context switching



; GPR files in shared GPR
STACK_W		EQU	0x7F
STACK_STATUS	EQU	0x7E
STACK_PCLATH	EQU	0x7D
SCRATCH		EQU	0x7C
STACK_SCRATCH	EQU	0x7B
STACK_FSR	EQU	0x7A

; Push and Pop for W, STATUS and PCLATH
; should be first to push and last to pop
;
;ex
; 	ORG 0x0000
; ISR:
; 	PUSH
; 	PUSHfsr
; 	PUSHscr
;
; ...isr...
;
; 	POPscr
; 	POPfsr
; 	POP
; 	REFTIE
;
; 	ORG 0x0004

PUSH	MACRO
	MOVWF	STACK_W
	SWAPF	STATUS, W
	MOVWF	STACK_STATUS
	CLRF	STATUS
	MOVF 	PCLATH, W
	MOVWF	STACK_PCLATH
	ENDM

POP	MACRO
	MOVF	STACK_PCLATH, W
	MOVWF 	PCLATH
	SWAPF	STACK_STATUS, W
	MOVWF	STATUS
	SWAPF	STACK_W, F
	SWAPF	STACK_W, W
	ENDM

; FSR
; required if ISR uses FSR
PUSHfsr	MACRO
	MOVF	FSR, W
	MOVWF	STACK_FSR
	ENDM
	
POPfsr	MACRO
	MOVF	STACK_FSR, W
	MOVWF	FSR
	ENDM

; Scratch register for expanded instructions
; required if ISR uses expanded instructions
PUSHscr	MACRO
	MOVF	SCRATCH, W
	MOVWF	STACK_SCRATCH
	ENDM
	
POPscr	MACRO
	MOVF	STACK_SCRATCH, W
	MOVWF	SCRATCH
	ENDM






; Assertion functions to Test and Debug



TRUE	EQU	0x00
FALSE	EQU	0x01

ASSERTw		MACRO	val
	LOCAL	jam
	XORLW	val
	BTFSS	STATUS, Z
jam:
	GOTO	jam
	XORLW	val
	ENDM
	
ASSERTbs	MACRO file, bit
	LOCAL jam
	BTFSS	file, bit
jam:
	GOTO jam
	ENDM
	
ASSERTbc	MACRO file, bit
	LOCAL jam
	BTFSC	file, bit
jam:
	GOTO jam
	ENDM
	
ASSERTf		MACRO	val, file
	LOCAL	jam
	MOVLW	val
	XORWF	file, W
	BTFSS	STATUS, Z
jam:
	GOTO	jam
	ENDM

ASSERTs		MACRO	val, file
	LOCAL	jam
	
	MOVLW	(val & 0x000000FF) >> 0
	XORWF	file, W
	BTFSS	STATUS, Z
jam:
	GOTO	jam
	
	MOVLW	(val & 0x0000FF00) >> 8
	XORWF	file + 1, W
	BTFSS	STATUS, Z
	GOTO	jam	
	ENDM
	
ASSERTc		MACRO	val, file
	LOCAL	jam
	
	MOVLW	(val & 0x000000FF) >> 0
	XORWF	file, W
	BTFSS	STATUS, Z
jam:
	GOTO	jam
	
	MOVLW	(val & 0x0000FF00) >> 8
	XORWF	file + 1, W
	BTFSS	STATUS, Z
	GOTO	jam	
	
	MOVLW	(val & 0x00FF0000) >> 16
	XORWF	file + 2, W
	BTFSS	STATUS, Z
	GOTO	jam	
	ENDM
	
ASSERTi		MACRO	val, file
	LOCAL	jam
	
	MOVLW	(val & 0x000000FF) >> 0
	XORWF	file, W
	BTFSs	STATUS, Z
jam:
	GOTO	jam
	
	MOVLW	(val & 0x0000FF00) >> 8
	XORWF	file + 1, W
	BTFSS	STATUS, Z
	GOTO	jam	
	
	MOVLW	(val & 0x00FF0000) >> 16
	XORWF	file + 2, W
	BTFSS	STATUS, Z
	GOTO	jam

	MOVLW	(val & 0xFF000000) >> 24
	XORWF	file + 3, W
	BTFSS	STATUS, Z
	GOTO	jam	
	ENDM

