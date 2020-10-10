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
;Mode	EQU	0x20
Res0H	EQU	0x21
Res0L	EQU	0x22
;Res1H	EQU	0x23
;Res1L	EQU	0x24
;Res5H	EQU	0x25
;Res5L	EQU	0x26
;Res6H	EQU	0x27
;Res6L	EQU	0x28
Timer	EQU	0x29
Shift	EQU	0x2A

;Begin
	ORG     0x0000

	BANK1

	BCF	OSCCON, IRCF0
	BCF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2	;1mhz

	BSF	TRISA, 0	;an0
	BSF	TRISA, 2	;vref-
	BSF	TRISA, 3	;vref+

	BSF	ANSEL, 0
	BSF	ANSEL, 2
	BSF	ANSEL, 3
	
	BCF	TRISB, 0	;data
	BCF	TRISB, 4	;clock
	BCF	TRISB, 5	;busy/dataready

	BSF	ADCON1, ADFM	;result right justified
	BCF	ADCON1, ADCS2	;clock not divided
	BSF	ADCON1, VCFG0	;vref+
	BSF	ADCON1, VCFG1	;vref-

	BANK0

	BSF	ADCON0, ADCS0	;internal ad clock
	BSF	ADCON0, ADCS1	;internal ad clock
	BSF	ADCON0, ADON	;adc module ON

	BCF	ADCON0, CHS0	; Set channel 0
	BCF	ADCON0, CHS1
	BCF	ADCON0, CHS2

MAIN	BSF	PORTB, 5	;busy

	CALL	WACQ		; wait TACQ time
	BSF	ADCON0, GO 	; Start conversion
S_Loop0	BTFSC	ADCON0, GO	; pool GO/Done for 0
	GOTO S_Loop0

	BCF	PORTB, 5	;dataready

	BANK1
	MOVF	ADRESL, W
	BANK0
	MOVWF	Res0l
	MOVF	ADRESH, W
	MOVWF	Res0H

	MOVLW	0X08
	MOVWF	SHIFT

SEND_L	BSF	PORTB, 0
	BSF	PORTB, 4	; CLOCK UP
	RRF	Res0l, F
	BTFSS	STATUS, C
	BCF	PORTB, 0
	NOP
	
	BCF	PORTB, 4	; CLOCK DOWN

	DECFSZ	SHIFT
	GOTO	SEND_L

	MOVLW	0X02
	MOVWF	SHIFT

SEND_H	BSF	PORTB, 0
	BSF	PORTB, 4	; CLOCK UP
	RRF	Res0h, F
	BTFSS	STATUS, C
	BCF	PORTB, 0
	NOP
	
	BCF	PORTB, 4	; CLOCK DOWN

	DECFSZ	SHIFT
	GOTO	SEND_H


	GOTO	MAIN




Wacq	MOVLW	0x05
	MOVWF	Timer
Wacql	DECFSZ	Timer, f
	GOTO	Wacql
	RETURN


	END
