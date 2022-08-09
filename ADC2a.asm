	LIST		p=16F88		; processor model
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
; pin  1 PORTA2	Input	AN2
; pin  2 PORTA3	Input	AN3 VREF+
; pin  3 PORTA4	Input	AN4
; pin  4 PORTA5	Input	#MCLR
; pin  5 VSS		GND
; pin  6 PORTB0	Output 	Bit0
; pin  7 PORTB1	Output	Bit1
; pin  8 PORTB2	Output	Bit2
; pin  9 PORTB3	Output	Bit3
; pin 10 PORTB4	Output	Bit4
; pin 11 PORTB5	Output	Bit5
; pin 12 PORTB6	Output	Bit6
; pin 13 PORTB7	Output	Bit7
; pin 14 VDD		VCC
; pin 15 PORTA6	Output WR
; pin 16 PORTA7	Input  #TXE
; pin 17 PORTA0	Input	AN0
; pin 18 PORTA1	Input	AN1


;Variables declarations:
channel		EQU	0x20
resultL		EQU	0x21
resultH		EQU	0x22
buffer		EQU	0x23


;Main program

	ORG     0x0000
	
	BCF	INTCON, GIE	;no interrupts

	BANK1

	CLRF	TRISB	; all outputs
	;MOVLW	0x0F
	;MOVWF	TRISA
	CLRF	TRISA
	BSF	TRISA, 0    ;porta bit 0 is input AN0
	BSF	TRISA, 1    ;porta bit 1 is input AN1
	BSF	TRISA, 2    ;porta bit 2 is input AN2
	BSF	TRISA, 3    ;porta bit 3 is input VREF+
	BSF	TRISA, 4    ;porta bit 4 is input AN4
	BSF	TRISA, 5    ;porta bit 5 is MCLR
	;BSF	TRISA, 6    ;porta bit 6 is output WR
	BSF	TRISA, 7    ;porta bit 7 is input #TXE	
	
	BANK0

	CLRF	PORTB
	BCF	PORTA, 6	; WR low
		
	BANK1

	; init osc
	BSF	OSCCON, IRCF0
	BCF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2	;2.0 MHz internal clock, 2.0us/instruction

	; init adc
	CLRF	ANSEL		;all digital
	BSF	ANSEL, 0	;AN0 analog
	BSF	ANSEL, 1	;AN1 analog
	BSF	ANSEL, 2	;AN2 analog
	BSF	ANSEL, 3	;AN3 analog vref+
	BSF	ANSEL, 4	;AN4 analog


	BSF	ADCON1, ADFM	;result right justified, 6 msb of ADRESH are 0
	BCF	ADCON1, VCFG0	;vref+ is AN3
	BSF	ADCON1, VCFG1	;vref- GND
	BSF	ADCON1, ADCS2	;clock divider

	BANK0

	BSF	ADCON0, ADCS0	;fosc / 64
	BSF	ADCON0, ADCS1	;
	
	BSF	ADCON0, ADON	;adc module ON	

	GOTO	start
	
	
Loop3:
	BTFSC	ADCON0, GO	;pool GO/Done for 0
	GOTO	Loop3
start:
	BCF	ADCON0, CHS0	;Set channel an0
	BCF	ADCON0, CHS1
	BCF	ADCON0, CHS2
	
	MOVLW	B'11000000'	;3
	MOVWF	channel
	CALL	Send	; send channel 3 data
	BSF	ADCON0, GO 	;Start next conversion
	
Loop0:
	BTFSC	ADCON0, GO	;pool GO/Done for 0
	GOTO	Loop0

	BSF	ADCON0, CHS0	;Set channel an1
	BCF	ADCON0, CHS1
	BCF	ADCON0, CHS2
	
	MOVLW	B'00000000'	;0
	MOVWF	channel
	CALL	Send	; send channel 0 data	
	BSF	ADCON0, GO 	;Start next conversion
	
Loop1:
	BTFSC	ADCON0, GO	;pool GO/Done for 0
	GOTO	Loop1
	
	BCF	ADCON0, CHS0	;Set channel an2
	BSF	ADCON0, CHS1
	BCF	ADCON0, CHS2
	
	MOVLW	B'01000000'	;1
	MOVWF	channel
	CALL	Send	; send channel 1 data
	BSF	ADCON0, GO 	;Start next conversion
	
Loop2:
	BTFSC	ADCON0, GO	;pool GO/Done for 0
	GOTO	Loop2
	
	BCF	ADCON0, CHS0	;Set channel an4
	BCF	ADCON0, CHS1
	BSF	ADCON0, CHS2
	
	MOVLW	B'10000000'	;2
	MOVWF	channel
	CALL	Send	; send channel 1 data
	BSF	ADCON0, GO 	;Start next conversion
	
	GOTO	Loop3


; routines

Send:
	BSF	STATUS, RP0 	;BANK1
	MOVF	ADRESL, W	
	BCF	STATUS, RP0 	;BANK0
	MOVWF	resultL
	MOVWF	buffer		; buffer = resultL
	MOVF	ADRESH, W
	MOVWF	resultH

	; L 7654 3210
	; H 0000 0098

	RLF	buffer, F	; rotate the 3 MSB of buffer(resultL) into resultH
	RLF	resultH, F
	
	RLF	buffer, F
	RLF	resultH, F
	
	RLF	buffer, F
	RLF	resultH, F
	
	MOVLW	B'00011111'
	ANDWF	resultL, F
	ANDWF	resultH, F

	; L --n4 3210
	BSF	resultH, 5
	; H --N9 8765

	MOVF	channel, W
	IORWF	resultL, F
	IORWF	resultH, F
	; L IDn4 3210
	; H IDN9 8765
	
	MOVF	resultL, W
	MOVWF	PORTB
	
	; check if clear to send
waitTXE_0:
	BTFSC	PORTA, 7
	GOTO	waitTXE_0
	
	; strobe WR
	BSF	PORTA, 6
	BCF	PORTA, 6
	
	MOVF	resultH, W
	MOVWF	PORTB	
	
	; check if clear to send
waitTXE_1:
	BTFSC	PORTA, 7
	GOTO	waitTXE_1

	; strobe WR
	BSF	PORTA, 6
	BCF	PORTA, 6
	
	RETURN




; end marker
	END
	
	















