	LIST		p=16F88		; processor model
	#INCLUDE	<P16F88.INC>	; processor specific variable definitions
	#INCLUDE	<PIC16F88_Macro.asm>

; Bank #    SFR           GPR               SHARED GPR's
; Bank 0    0x00-0x1F     0x20-0x6F         0x70-0x7F    
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF

; Pinout:
; pin  1 PORTA2 Input Vref-			 VRef-
; pin  2 PORTA3 Input Vref+			 VRef+
; pin  3 PORTA4 LSB Number of Channels		 Data Clock In
; pin  4 PORTA5 MSB Number of Channel
; pin  5 VSS					 GND
; pin  6 PORTB0 Output Serial Data Out Channel	 Data Bit0 Output
; pin  7 PORTB1 Output Serial Data Out Channel	 Data Bit1 Output
; pin  8 PORTB2 Output Serial Data Out Channel	 Data Bit2 Output
; pin  9 PORTB3 Output Serial Data Out Channel	 Data Bit3 Output
; pin 10 PORTB4 Output Serial Data Out Clock
; pin 11 PORTB5 Output Busy/¯Dataready¯ 
; pin 12 PORTB6 Input AN5
; pin 13 PORTB7 Input AN6
; pin 14 VDD					 VCC
; pin 15 N/C
; pin 16 N/C
; pin 17 PORTA0 Input AN0			 Busy / _Data Ready_
; pin 18 PORTA1 Input AN1			 Analog Input

;Variables declarations:

ResH	EQU	0x21
ResL	EQU	0x22

;Main program

	ORG     0x0000

	BANK1

	BCF	OSCCON, IRCF0
	BCF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2	;1Mhz internal clock

	BCF	TRISA, 0	;o busy / _ready_
	BSF	TRISA, 1	;i an1
	BSF	TRISA, 2	;i vref-
	BSF	TRISA, 3	;i vref+
	BSF	TRISA, 4	;i data clock

	CLRF	TRISB		;o data

	CLRF	ANSEL
	BSF	ANSEL, 1	;an1
	BSF	ANSEL, 2	;vref-
	BSF	ANSEL, 3	;vref+

	BSF	ADCON1, ADFM	;result right justified
	BSF	ADCON1, ADCS2	;clock divided
	BSF	ADCON1, VCFG0	;vref+
	BSF	ADCON1, VCFG1	;vref-

	BANK0

	BSF	ADCON0, ADCS0	;
	BCF	ADCON0, ADCS1	;adc fosc div 16
	BSF	ADCON0, ADON	;adc module ON

	BSF	ADCON0, CHS0	;Set channel 1
	BCF	ADCON0, CHS1
	BCF	ADCON0, CHS2

	BSF	ADCON0, GO 	;Start conversion

MAIN	BSF	PORTA, 0	;busy
LoopADC	BTFSC	ADCON0, GO	;pool GO/_Done_ for 0
	GOTO	LoopADC

	BANK1			;backup previous results
	MOVF	ADRESL, W
	BANK0
	MOVWF	ResL
	MOVF	ADRESH, W
	MOVWF	ResH

	BSF	ADCON0, GO 	;Start New conversion	


	MOVF	ResL, W
	MOVWF	PORTB		;send low byte low nibble

	BCF	PORTA, 0	;dataready

Loop0a	BTFSC	PORTA, 4	;wait clock up
	GOTO	Loop0a

Loop0b	BTFSS	PORTA, 4	;wait clock down
	GOTO	Loop0b

	SWAPF	ResL, W
	MOVWF	PORTB		;send low byte high nibble

Loop1a	BTFSC	PORTA, 4	;wait clock up
	GOTO	Loop1a

Loop1b	BTFSS	PORTA, 4	;wait clock down
	GOTO	Loop1b

	MOVF	ResH, W
	MOVWF	PORTB		;send high byte low nibble

Loop2a	BTFSC	PORTA, 4	;wait clock up
	GOTO	Loop2a

Loop2b	BTFSS	PORTA, 4	;wait clock down
	GOTO	Loop2b

	GOTO	MAIN

	END
