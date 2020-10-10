	LIST		p=16F88		; list directive to define processor
	#INCLUDE	<P16F88.INC>	; processor specific variable definitions
	#INCLUDE	<PIC16F88_Macro.asm>

; Bank #    SFR           GPR               SHARED GPR's
; Bank 0    0x00-0x1F     0x20-0x6F         0x70-0x7F    
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF

; Pinout:
; pin  1 PORTA2 Input	Vref-	battery ground
; pin  2 PORTA3 Input	Vref+	10.24V 
; pin  3 PORTA4
; pin  4 PORTA5
; pin  5 VSS		GND
; pin  6 PORTB0 Output 	LED Ready
; pin  7 PORTB1 Output	LED Stab(F) / Charging	
; pin  8 PORTB2 Output 	LED Done
; pin  9 PORTB3	Output	LM317 Charge Control (active low)
; pin 10 PORTB4
; pin 11 PORTB5
; pin 12 PORTB6
; pin 13 PORTB7
; pin 14 VDD		VCC
; pin 15 PORTA6
; pin 16 PORTA7
; pin 17 PORTA0 Input	Battery Voltage Sensing
; pin 18 PORTA1	Input	PushButton Start

; Reset
;   Cut-Off Charge
;   Reset LEDs
;   Wait For Battery
; Set LED "Ready"
; Wait PB "Start"
; Loop and Stabilize for 30s flashing LED "Stab/Charge"
; Set LED "Stab/Charge"
; charge and pool
; Stop Charge
; Set LED "Done"
; wait for battery removed and go back to reset

;Variables declarations:

ResH	EQU	0x21
ResL	EQU	0x22
WaitS	EQU	0x23
Wait25	EQU	0x24

;Main program

	ORG     0x0000

	BANK1

	CLRF	TRISB
	MOVLW	0x0F
	MOVWF	TRISA

MAIN	BANK0

	CLRF	PORTB	;Turn LEDs off
	BSF	PORTB, 3 	;cut-off charge

	BANK1

	BSF	OSCCON, IRCF0
	BCF	OSCCON, IRCF1
	BCF	OSCCON, IRCF2	;125.0 Khz internal clock 32us / instruction

	CLRF	ANSEL
	BSF	ANSEL, 0	;PORTA0 AN0
	BSF	ANSEL, 2	;vref-
	BSF	ANSEL, 3	;vref+

	BSF	ADCON1, ADFM	;result right justified
	BSF	ADCON1, VCFG0	;vref+
	BSF	ADCON1, VCFG1	;vref-

	BANK0

	BSF	ADCON0, ADCS0	;
	BSF	ADCON0, ADCS1	;adc internal osc
	BSF	ADCON0, ADON	;adc module ON

	BCF	ADCON0, CHS0	;Set channel an0
	BCF	ADCON0, CHS1
	BCF	ADCON0, CHS2



; Wait For Battery

; Set LED "Ready"

; Wait PB "Start"

; Loop and Stabilize for 30s flashing LED "Stab/Charge"

; Set LED "Stab/Charge"

; charge and pool

; Stop Charge

; Set LED "Done"

; wait for battery removed and go back to reset
	GOTO	MAIN


ADC	BSF	ADCON0, GO 	;Start conversion
LoopADC	BTFSC	ADCON0, GO	;pool GO/Done for 0
	GOTO	LoopADC
	BANK1			;backup results
	MOVF	ADRESL, W
	BANK0
	MOVWF	ResL
	MOVF	ADRESH, W
	MOVWF	ResH
	RETURN			;return from subroutine


WAIT_S	MOVLW	0x28		;wait cycles - 1 
	MOVWF	Waits
LoopWs	NOP
	CALL	WAIT_32
	DECFSZ	Waits, W	;4x32us / cycle 
	GOTO	LoopWs	
	RETURN			;32.768ms


WAIT_25	MOVLW	0xC3		;wait cycles - 1 
	MOVWF	Wait25
LoopW25	NOP
	DECFSZ	Wait25, W	;4x32us / cycle 
	GOTO	LoopW25	
	RETURN			;25.088 ms

	END