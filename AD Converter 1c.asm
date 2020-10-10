	LIST		p=16F88		; list directive to define processor
	#INCLUDE	<P16F88.INC>	; processor specific variable definitions
	#INCLUDE	<PIC16F88_Macro.asm>

; Bank #    SFR           GPR               SHARED GPR's
; Bank 0    0x00-0x1F     0x20-0x6F         0x70-0x7F    
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF

; Pinout:
; pin  1 PORTA2 Input Vref-			xxx
; pin  2 PORTA3 Input Vref+			xxx
; pin  3 PORTA4 LSB Number of Channels		xxx
; pin  4 PORTA5 MSB Number of Channels		xxx
; pin  5 VSS						GND
; pin  6 PORTB0 Output Serial Data Out Channel 0xxx 
; pin  7 PORTB1 Output Serial Data Out Channel 1xxx
; pin  8 PORTB2 Output Serial Data Out Channel 5 	data out 
; pin  9 PORTB3 Output Serial Data Out Channel 6xxx 
; pin 10 PORTB4 Output Serial Data Out Clock	xxx
; pin 11 PORTB5 Output Busy/¯Dataready¯ 		clock out
; pin 12 PORTB6 Input AN5			xxx
; pin 13 PORTB7 Input AN6			xxx
; pin 14 VDD						VCC
; pin 15 N/C					xxx
; pin 16 N/C					xxx
; pin 17 PORTA0 Input AN0				Analog Input
; pin 18 PORTA1 Input AN1				busy/_dataready_

;Variables declarations:



	ORG     0x0000

	BSF	RCSTA, SPEN	;ausart enable

	BANK1

	BSF	OSCCON, IRCF0
	BCF	OSCCON, IRCF1
	BCF	OSCCON, IRCF2	;125.0 Khz internal clock

	BSF	TRISA, 0	;i an0
	BCF	TRISA, 1	;o busy / _ready_

	BSF	TRISB, 2	;i Data out
	BSF	TRISB, 5	;i Clock out

	BSF	TXSTA, SYNC	;syncronous ausart
	BSF	TXSTA, CSRC	;clock source is brg
	MOVLW	0X0B		;ausart delay fosc / 4(1+11)
	MOVWF	SPBRG

	BSF	ANSEL, 0	;an0

	BSF	ADCON1, ADFM	;result right justified
	BCF	ADCON1, ADCS2	;clock not divided
	BCF	ADCON1, VCFG0	;vref+ is vcc
	BCF	ADCON1, VCFG1	;vref- is gnd

	BSF	TXSTA, TXEN	;ausart tx enable

	BANK0

	BCF	ADCON0, ADCS0	;
	BCF	ADCON0, ADCS1	;adc clock
	BSF	ADCON0, ADON	;adc module ON

	BCF	ADCON0, CHS0	;Set channel 0
	BCF	ADCON0, CHS1
	BCF	ADCON0, CHS2

MAIN	BSF	PORTA, 1	;busy
	BSF	ADCON0, GO 	;Start conversion
LoopADC	BTFSC	ADCON0, GO	;pool GO/Done for 0
	GOTO	LoopADC
	BCF	PORTA, 1	;dataready

	BANK1
	MOVF	ADRESL, W

	BANK0
	MOVWF	TXREG		;send low byte

	BANK1
Loop0	BTFSS	TXSTA, TRMT
	GOTO	Loop0

	BANK0

	MOVF	ADRESH, W
	MOVWF	TXREG		;send high byte

	BANK1
Loop1	BTFSS	TXSTA, TRMT
	GOTO	Loop1

	BANK0

	GOTO	MAIN

	END
