	LIST		p=16F88		; list directive to define processor
	#INCLUDE	<P16F88.INC>	; processor specific variable definitions
	#INCLUDE	<PIC16F88_Macro.asm>

	__CONFIG	_CONFIG1, _CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_ON & _MCLR_OFF & _PWRTE_ON & _WDT_OFF & _INTRC_IO
	__CONFIG	_CONFIG2, _IESO_ON & _FCMEN_ON

; Bank #    SFR           GPR               SHARED GPR's
; Bank 0    0x00-0x1F     0x20-0x6F         0x70-0x7F    
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF

; Pinout:
; pin  1 PORTA2 AN2 VREF- Digit Select 1 (LH)
; pin  2 PORTA3 AN3 VREF+ Input 640mv = 64 from AD after div by 16
; pin  3 PORTA4 AN4 Digit Select 2 (RH)
; pin  4 PORTA5(Input only) AN5
; pin  5 VSS
; pin  6 PORTB0 Output seg D
; pin  7 PORTB1 Output seg E
; pin  8 PORTB2 Output seg B
; pin  9 PORTB3 Output seg C
; pin 10 PORTB4 Output seg F
; pin 11 PORTB5 Output seg A
; pin 12 PORTB6 Output seg G
; pin 13 PORTB7 N/C
; pin 14 VDD
; pin 15 PORTA6 N/C
; pin 16 PORTA7 N/C
; pin 17 PORTA0 AN0 Input LM35
; pin 18 PORTA1 AN1 N/C

;Variables declarations:

;ResH	EQU	0x20
;ResL	EQU	0x21
Loop1	EQU	0x22	;delay for segment display
Loop2	EQU	0x23	;delay for both digits display


Count	EQU	0x24	;ADC Result to be converted in BCD
Font	EQU	0x25	;7segments font

Digit1	EQU	0x26	;BCD nibble result for display 10th
Digit2	EQU	0x27	;BCD nibble result for display units
Digit	EQU	0x28	;BCD result of Count
BCDRot	EQU	0x29	;Bin2BCD itteration counter


;Begin
	ORG	0x0000
	BANK0
	BCF	INTCON, GIE	; clear global interrupts

	BANK1
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1	; 8mhz
	BSF	OSCCON, IRCF2	
	
	MOVLW 0x09		;0000 1001 analog inputs 0 and 3
	MOVWF	ANSEL	
	MOVLW 0xC9		;1100 1001 7 and 6 input to allow ground routing
	MOVWF	TRISA		;1100 1001 0 and 3 input for analog
	CLRF	TRISB		;0000 0000 all outputs	
	
	BCF ADCON1, ADFM  ;result LEFT justified MSBs in adresH
	BCF ADCON1, ADCS2 ;clock not divided
	BCF ADCON1, VCFG0 ;GND
	BSF ADCON1, VCFG1 ;VREF+
	
	BANK0	
	CLRF Count
	CLRF Digit
	CLRF Digit1
	CLRF Digit2
	CLRF PORTA
	MOVLW 0xFF
	MOVWF PORTB
	
	BSF ADCON0, ADON  ;adc module ON
	BSF ADCON0, ADCS0 ;internal ad clock
	BSF ADCON0, ADCS1 ;internal ad clock
	BCF ADCON0, CHS0	; Set channel 0
	BCF ADCON0, CHS1
	BCF ADCON0, CHS2
		
MAIN	CALL Del1		; TACQ Acquisition delay
	BSF	ADCON0, GO 	; Start conversion
ADLoop BTFSC	ADCON0, GO	; pool GO/Done for 0
	GOTO ADLoop
	
	MOVF	ADRESH, W	;read ADC Result
	MOVWF	Count
	BCF STATUS, C	
	RRF Count, F		; divide by 2
	BCF STATUS, C	
	RRF Count, F		; divide by 2
				; AD Result is 10bit long, with 8 MSB bits in ADRESH due to Left Justified option
				; LM35 outputs 10mv / Deg C, VRef+ is at 640mv = 64 Deg C
				; 256 /2 / 2 = 64 !  
				
	CALL BCD		; convert Binary to BCD
	
	MOVF Digit1, W
	BANK2
	MOVWF EEADR
	BANK3
	BCF EECON1, EEPGD	; Read EEPROM Data Memory
	BSF EECON1, RD
	BANK2
	MOVF EEDATA, W
	BANK0
	MOVWF Digit1	;now converted to font	
	
	
	MOVF Digit2, W
	BANK2
	MOVWF EEADR
	BANK3
	BCF EECON1, EEPGD	; Read EEPROM Data Memory
	BSF EECON1, RD
	BANK2
	MOVF EEDATA, W
	BANK0
	MOVWF Digit2	;now converted to font		
	
	MOVLW 0x50	;80
	MOVWF Loop2	
	
	
Disp	BSF PORTA, 2	;digit1
	MOVF Digit1, W
	MOVWF Font
	CALL SendF		
	BCF PORTA, 2	
	
	BSF PORTA, 4	;digit2
	MOVF Digit2, W
	MOVWF Font
	CALL SendF	
	BCF PORTA, 4	
	
	DECFSZ Loop2, F
	GOTO Disp	
	
	GOTO MAIN
	
SendF	BTFSC Font, 0
	BCF PORTB, 0
	CALL Del1
	BSF PORTB, 0

	BTFSC Font, 1
	BCF PORTB, 1
	CALL Del1
	BSF PORTB, 1

	BTFSC Font, 2
	BCF PORTB, 2
	CALL Del1
	BSF PORTB, 2

	BTFSC Font, 3
	BCF PORTB, 3
	CALL Del1
	BSF PORTB, 3

	BTFSC Font, 4
	BCF PORTB, 4
	CALL Del1
	BSF PORTB, 4

	BTFSC Font, 5
	BCF PORTB, 5
	CALL Del1
	BSF PORTB, 5

	BTFSC Font, 6
	BCF PORTB, 6
	CALL Del1
	BSF PORTB, 6
	RETURN

Del1	MOVLW 0xFF
	MOVWF Loop1
	NOP
	NOP
Del1a	NOP
	DECFSZ Loop1, F
	GOTO Del1a
	RETURN
	
BCD	CLRF Digit
	MOVLW 0x07	;Rotate and increment 7 times
	MOVWF BCDRot	
BCDR	BCF STATUS, C	;rotate
	RLF Count, F	;rotate trough carry
	RLF Digit, F	;carry now in Digit
	
	SWAPF Digit, W;H Nibble digit
	ANDLW 0x0F
	SUBLW 0x04
	BTFSC STATUS, C
	GOTO DL
	MOVLW 0x30
	ADDWF Digit, F
	
DL	MOVLW 0x0F	;L Nibble digit
	ANDWF Digit, W
	SUBLW 0x04
	BTFSC STATUS, C
	GOTO BCDE
	MOVLW 0x03
	ADDWF Digit, F		
	
BCDE	DECFSZ BCDRot, F
	GOTO BCDR
	BCF STATUS, C;rotate
	RLF Count, F
	RLF Digit, F;last time no C5A3	
	
	MOVLW 0x0F
	ANDWF Digit, W
	MOVWF Digit2
	
	SWAPF Digit, W
	ANDLW 0x0F	
	MOVWF Digit1
	
	RETURN

	END
	
	
























