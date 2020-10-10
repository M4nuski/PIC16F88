	LIST		p=16F88		; list directive to define processor
	#INCLUDE	<P16F88.INC>	; processor specific variable definitions
	#INCLUDE	<PIC16F88_Macro.asm>

; Bank #    SFR           GPR               SHARED GPR's
; Bank 0    0x00-0x1F     0x20-0x6F         0x70-0x7F    
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF

; Pinout:
; pin  1 PORTA2 Input Vref-			
; pin  2 PORTA3 Input Vref+			
; pin  3 PORTA4 LSB Number of Channels		xxx
; pin  4 PORTA5 MSB Number of Channels		xxx
; pin  5 VSS
; pin  6 PORTB0 Output Serial Data Out Channel 0 
; pin  7 PORTB1 Output Serial Data Out Channel 1xxx
; pin  8 PORTB2 Output Serial Data Out Channel 5xxx 
; pin  9 PORTB3 Output Serial Data Out Channel 6xxx 
; pin 10 PORTB4 Output Serial Data Out Clock
; pin 11 PORTB5 Output Busy/¯Dataready¯ 
; pin 12 PORTB6 Input AN5			xxx
; pin 13 PORTB7 Input AN6			xxx
; pin 14 VDD
; pin 15 N/C					xxx
; pin 16 N/C					xxx
; pin 17 PORTA0 Input AN0
; pin 18 PORTA1 Input AN1			xxx

;Variables declarations:



	ORG     0x0000

	BSF	RCSTA, SPEN
	BANK1

	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2	;8mhz

	BSF	TRISA, 0	;an0
	BCF	TRISA, 1	;busy / _ready_
	BSF	TRISA, 2	;Clock in


	MOVLW	0XF9
	MOVWF	SPBRG
	
	BSF	TRISB, 2	;Data out
	BSF	TRISB, 5	;Clock out
	BSF	TXSTA, SYNC
	BSF	TXSTA, CSRC

	BSF	ANSEL, 0	;an0

	BSF	ADCON1, ADFM	;result right justified
	BSF	ADCON1, ADCS2	;clock divided
	BCF	ADCON1, VCFG0	;vref+ is vcc
	BCF	ADCON1, VCFG1	;vref- is gnd

	BANK0


	BSF	ADCON0, ADCS0	;
	BCF	ADCON0, ADCS1	;div 16
	BSF	ADCON0, ADON	;adc module ON

	BCF	ADCON0, CHS0	;Set channel 0
	BCF	ADCON0, CHS1
	BCF	ADCON0, CHS2

MAIN	BSF	PORTA, 1
	BSF	ADCON0, GO 	;Start conversion
Loop0	BTFSC	ADCON0, GO	;pool GO/Done for 0
	GOTO	Loop0
	
	BANK1
	BSF	TXSTA, TXEN
	MOVF	ADRESL, W
	BANK0
	BCF	PORTA, 1
	MOVWF	TXREG
	MOVF	ADRESH, W
	MOVWF	TXREG	

	BANK1

Loop1	BTFSS	TXSTA, TRMT
	GOTO	Loop1

	BANK0

	GOTO	MAIN

	END
