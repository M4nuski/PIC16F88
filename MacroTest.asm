	LIST		p=16F88		; list directive to define processor
	#INCLUDE	<P16F88.INC>	; processor specific variable definitions
	#INCLUDE	<PIC16F88_Macro.asm>
	
	__CONFIG	_CONFIG1, _CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_OFF & _WDT_OFF & _INTRC_IO
	__CONFIG	_CONFIG2, _IESO_OFF & _FCMEN_OFF

; Bank #    SFR           GPR               SHARED GPR's			total 368 bytes of GPR, 16 shared between banks
; Bank 0    0x00-0x1F     0x20-0x7F         target area 0x70-0x7F		96
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  			80 (+ top 16 shared with bank 0)
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F			16 + 80 (+ top 16 shared with bank 0)
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF			16 + 80 (+ top 16 shared with bank 0)

; Pinout:
; pin  1 PORTA2	Input	Vref-	battery ground	
; pin  2 PORTA3	Input	Vref+	10.24V 
; pin  3 PORTA4
; pin  4 PORTA5	MCLR (is input only)
; pin  5 VSS		GND
; pin  6 PORTB0	Output 	LED blink: stab/standby, solid charging
; pin  7 PORTB1	Output	LED/buzzer Done/voltage dropping	
; pin  8 PORTB2	Output	last test is a drop	
; pin  9 PORTB3
; pin 10 PORTB4
; pin 11 PORTB5
; pin 12 PORTB6
; pin 13 PORTB7
; pin 14 VDD		VCC
; pin 15 PORTA6
; pin 16 PORTA7
; pin 17 PORTA0	Input	Battery Voltage Sensing
; pin 18 PORTA1
; all active low


;Variables declarations:
loop	EQU 0x20
Result	EQU 0x21
;Res H		EQU	0x22
Wait1S	EQU 0x23
Wait20ms	EQU 0x24
last_Res	EQU 0x25
;last_Res H	EQU	0x26

;Main program

	ORG     0x0000

	BANK1

	CLRF	TRISB
	MOVLW	0x0F
	MOVWF	TRISA

	BANK0

	CLRF	PORTB		;Turn LEDs off and stop charge
	DECF	PORTB, F

	BANK1

	; init osc
	BCF	OSCCON, IRCF0
	BCF	OSCCON, IRCF1
	BCF	OSCCON, IRCF2	;31.25 kHz internal clock 32us/clock, 128us/instruction

	; init adc
	CLRF	ANSEL
	BSF	ANSEL, 0	;PORTA0 AN0
	BSF	ANSEL, 2	;vref-
	BSF	ANSEL, 3	;vref+

	BCF	ADCON1, ADFM	;result LEFT justified
	;	BSF	ADCON1, ADFM	;result right justified
	BSF	ADCON1, VCFG0	;vref+
	BSF	ADCON1, VCFG1	;vref-

	BANK0

	BSF	ADCON0, ADCS0	;
	BSF	ADCON0, ADCS1	;adc internal osc
	BSF	ADCON0, ADON	;adc module ON

	BCF	ADCON0, CHS0	;Set channel an0
	BCF	ADCON0, CHS1
	BCF	ADCON0, CHS2

	MOVLW 10	; blink and stabilize 10 seconds
	MOVWF loop
	
MAIN	BSF PORTB, 0;
	CALL WAIT_05s
	BCF PORTB, 0;
	CALL WAIT_05s
	DECFSZ loop, F
	GOTO MAIN
	
	; check voltage
	CALL ADC


wait_pool	MOVLW 5	; wait 5 sec before pooling
		MOVWF loop
wait_pool_sub	CALL WAIT_1s
		DECFSZ loop, F
		GOTO wait_pool_sub
	
	; save values
	MOV_short Result, last_Res
	
	CLRF PORTB	
	; check voltage
	CALL ADC
	
	; compare values
	BR_W_EQ_W Result, last_Res, EQ
	BR_W_LT_W Result, last_Res, LT 
	
GT	BSF PORTB, 2 ; high
	GOTO wait_pool	
	
LT	BSF PORTB, 0 ; low
	GOTO wait_pool
	
EQ	BSF PORTB, 1 ; eq	
	GOTO wait_pool
	
	DECF	Result, F
	BR_W_EQ_W Result, last_Res, EQ2
	BR_W_LT_W Result, last_Res, LT2

EQ2
	NOP
	BSF PORTB, 2
	GOTO GT2
LT2
	BSF PORTB, 0
	GOTO GT2
GT2
	NOP
; start ADC conversion, wait for result and store in ResL ResH
ADC	BSF	ADCON0, GO 	;Start conversion
LoopADC	BTFSC	ADCON0, GO	;pool GO/Done for 0
	GOTO	LoopADC
	BANK1			;backup results
	MOVF	ADRESL, W
	BANK0
	MOVWF	Result
	MOVF	ADRESH, W
	MOVWF	Result + 1
	RETURN			;return from subroutine

; wait 0.5s
WAIT_05s	MOVLW	12
	MOVWF	Wait1S
Loop_W05s	NOP
	CALL	WAIT_20ms
	DECFSZ	Wait1S, F
	GOTO	Loop_W05s
	RETURN
		
; wait 1s
WAIT_1s	MOVLW	25
	MOVWF	Wait1S
Loop_W1s NOP
	CALL	WAIT_20ms
	DECFSZ	Wait1S, F
	GOTO	Loop_W1s
	RETURN

; wait 20ms
; call is 2 instruction cylce (2*128)
WAIT_20ms	MOVLW	37		;wait cycles - 2 ; 37 + 2 = 39, *4 = 156, *0.000128 = 0.019968s
	MOVWF	Wait20ms
	NOP
	NOP
; preambule is 4 cycles
Loop_W20ms	NOP
	DECFSZ	Wait20ms, F
	GOTO	Loop_W20ms	
; loop is 4 cycles
	RETURN
; return is 2 cycles

	END