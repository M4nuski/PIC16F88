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
; w word  32bit
; d double 64bit

; f file
; l literal
; u unsigned
; s signed

; SCRATCH		EQU 0x7A
; STACK_SCRATCH	EQU 0x7B

; 8 bit compare
COMP_l_f	MACRO lit, file	; literal vs file
	MOVF	file, W			; w = f
	SUBLW	lit			; w = l - f(w)
	ENDM
	
COMP_f_f	MACRO file1, file2	; file vs file
	MOVF	file2, W		; w = f2
	SUBWF	file1, W		; w = f1 - f2(w)
	ENDM

COMP_f_w	MACRO file		; w vs file
	SUBWF	file, W			; w = f - w
	ENDM

COMP_l_w	MACRO lit		; literal vs w
	SUBLW	lit			; w = l - w
	ENDM
	
; 8 bit branch
BR_EQ	MACRO	dest
	BTFSC	STATUS, Z
	GOTO	dest
	ENDM
	
BR_NE	MACRO	dest
	BTFSS	STATUS, Z
	GOTO	dest
	ENDM

; BR_GT
; BR_GE
; BR_LT
; BR_LE

TEST_f	MACRO	file	; test file
	MOVF	file, F
	ENDM
	
TEST_w	MACRO		; test w
	ANDLW	0xFF
	ENDM
	

BR_ZE	MACRO	dest	; zero
	BTFSC	STATUS, Z
	GOTO	dest
	ENDM
	
BR_NZ	MACRO	dest	; not zero
	BTFSS	STATUS, Z
	GOTO	dest
	ENDM

BR_CA	MACRO	dest	; carry
	BTFSC	STATUS, C
	GOTO	dest
	ENDM
	
BR_NC	MACRO	dest	; no carry
	BTFSS	STATUS, C
	GOTO	dest
	ENDM
	
BR_BO	MACRO	dest	; borrow
	BTFSS	STATUS, C
	GOTO	dest
	ENDM
	
BR_NB	MACRO	dest	; no borrow
	BTFSC	STATUS, C
	GOTO	dest
	ENDM
	

BR_FBS	MACRO	file, bit, dest	; branch if file bit set
	BTFSC	file, bit
	GOTO	dest
	ENDM
	
BR_FBC	MACRO	file, bit, dest	; branch if file bit clear
	BTFSS	file, bit
	GOTO	dest
	ENDM

;BR_WBS	MACRO	bit, dest		; brach if w bit set
;	MOVWF	SCRATCH
;	BTFSC	SCRATCH, bit
;	GOTO	dest
;	ENDM
	
;BR_WBC	MACRO	bit, dest		; brach if w bit set
;	MOVWF	SCRATCH
;	BTFSS	SCRATCH, bit
;	GOTO	dest
;	ENDM
	
	
	
	
	
	
; Short
MOV_short 	MACRO from_byte, to_byte
	MOVF from_byte, W
	MOVWF to_byte
	MOVF from_byte + 1, W
	MOVWF to_byte + 1
	ENDM
	
ADD_short	MACRO increm, dest ;dest = dest + increm
	MOVF increm, W
	ADDWF dest, F
	BTFSC STATUS, C
	INCF dest+1, F
	MOVF increm+1, W
	ADDWF dest+1, F
	ENDM
	
SUB_short	MACRO decrem, dest ;dest = dest - decrem
	MOVF decrem, W
	SUBWF dest, F
	BTFSS STATUS, C
	DECF dest+1, F; ???
	MOVF decrem+1, W
	SUBWF dest+1, F; 
	ENDM
	
BR_FF_NE	MACRO var1, var2, dest	;branch file-file not equal
	MOVF var1, W
	XORWF var2, W
	BTFSS STATUS, Z ; EQ: z=1, NEQ: Z=0;
	GOTO dest
	ENDM
	
BR_FF_EQ	MACRO var1, var2, dest	;branch file-file equal
	MOVF var1, W
	XORWF var2, W
	BTFSC STATUS, Z
	GOTO dest
	ENDM
	
BR_W_LT_W	MACRO word1, word2, dest	;branch to dest if word1 < word2 
	LOCAL BRWLTW1
	LOCAL BRWLTW2
	; test high byte
	MOVF word2 + 1, W ; W = word2
	SUBWF word1 + 1, W ; Subtract W(word2) from f(word1)
	; w = word1 - word2
	; if equal Z is set, C is set (borrow is clear)
	; if word1 > word2 C is set (borrow is clear)
	; if word1 < word2 C is clear (borrow is set)
	
	BTFSS STATUS, C; skip if C is set (borrow is clear, word1 >= word2)
	GOTO dest; high byte is less
	
	BTFSC STATUS, Z; check if equal
	GOTO BRWLTW1; if high bytes are equal test low bytes
	GOTO BRWLTW2; otherwise word1 > word2
	; test low byte
BRWLTW1:
	MOVF word2, W
	SUBWF word1, W	
	BTFSS STATUS, C
	GOTO dest
BRWLTW2:
	ENDM
	
BR_W_GT_W	MACRO word1, word2, dest	;branch to dest if word1 > word2 
	LOCAL BRWGTW1
	LOCAL BRWGTW2
	; test high byte
	MOVF word1 + 1, W ; W = word1
	SUBWF word2 + 1, W ; Subtract W(word1) from f(word2)
	; w = word2 - word1
	BTFSS STATUS, C; skip if C is set 
	GOTO dest; high byte is less	
	BTFSC STATUS, Z; check if equal
	GOTO BRWGTW1;
	GOTO BRWGTW2;
BRWGTW1:
	MOVF word1, W
	SUBWF word2, W	
	BTFSS STATUS, C
	GOTO dest
BRWGTW2:
	ENDM

	
BR_W_EQ_W	MACRO word1, word2, dest	;branch to dest if word1 == word2
	LOCAL BRWWEQW
	; test high byte
	MOVF word1 + 1, W
	SUBWF word2 + 1, W
	BTFSS STATUS, Z
	GOTO BRWWEQW
	; test low byte
	MOVF word1, W
	SUBWF word2, W
	BTFSC STATUS, Z
	GOTO dest
BRWWEQW:
	ENDM	

;C: Carry/borrow bit (ADDWF, ADDLW, SUBLW and SUBWF instructions)(1,2)
;1 = A carry-out from the Most Significant bit of the result occurred
;0 = No carry-out from the Most Significant bit of the result occurred
	
BR_LF_NE	MACRO lit1, var2, dest ;branch literate-file not equal
	MOVLW lit1
	XORWF var2, W
	BTFSS STATUS, Z
	GOTO dest
	ENDM
	
BR_LF_EQ	MACRO lit1, var2, dest ;branch literate-file equal
	MOVLW lit1
	XORWF var2, W
	BTFSC STATUS, Z
	GOTO dest
	ENDM	
	
READ_TMR0	MACRO destH, destL
	LOCAL CONTINUE_READ_TMR0
	MOVF TMR1H, W ; Read high byte
	MOVWF destH
	MOVF TMR1L, W ; Read low byte
	MOVWF destL
	MOVF TMR1H, W ; Read high byte
	SUBWF destH, W ; Sub 1st read with 2nd read
	BTFSC STATUS, Z ; Is result = 0
	GOTO CONTINUE_READ_TMR0 ; Good 16-bit read
	; TMR1L may have rolled over between the read of the high and low bytes.
	; Reading the high and low bytes now will read a good value.
	MOVF TMR1H, W ; Read high byte
	MOVWF destH
	MOVF TMR1L, W ; Read low byte
	MOVWF destL ; Re-enable the Interrupt (if required)
CONTINUE_READ_TMR0:  ; Continue with your code
	ENDM
	
PUSH	MACRO
	MOVWF	STACK_W
	SWAPF	STATUS, W
	CLRF	STATUS
	MOVWF	STACK_STATUS
	MOVF	PCLATH, W
	MOVWF	STACK_PCLATH
	CLRF	PCLATH
	MOVF	FSR, W
	MOVWF	STACK_FSR
	ENDM

POP	MACRO
	MOVF	STACK_FSR, W
	MOVWF	FSR
	MOVF	STACK_PCLATH, W
	MOVWF 	PCLATH
	SWAPF	STACK_STATUS, W
	MOVWF	STATUS
	SWAPF	STACK_W, F
	SWAPF	STACK_W, W
	ENDM
	
qPUSH	MACRO
	MOVWF	STACK_W
	SWAPF	STATUS, W
	CLRF	STATUS
	MOVWF	STACK_STATUS
	ENDM

qPOP	MACRO
	SWAPF	STACK_STATUS, W
	MOVWF	STATUS
	SWAPF	STACK_W, F
	SWAPF	STACK_W, W
	ENDM