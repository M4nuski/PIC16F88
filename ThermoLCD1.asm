	LIST		p=16F88		; list directive to define processor
	#INCLUDE	<P16F88.INC>	; processor specific variable definitions
	#INCLUDE	<PIC16F88_Macro.asm>

__CONFIG    _CONFIG1, _CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_OFF & _PWRTE_OFF & _WDT_OFF & _INTRC_IO
__CONFIG    _CONFIG2, _IESO_OFF & _FCMEN_OFF

; Bank #    SFR           GPR               SHARED GPR's
; Bank 0    0x00-0x1F     0x20-0x6F         0x70-0x7F    
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF

; Pinout:
; pin  1 PORTA2 AN2 VREF- N/C
; pin  2 PORTA3 AN3 VREF+ Input 640mv = 64 from AD after div by 16
; pin  3 PORTA4 AN4 Digit Select 2 (RH)
; pin  4 PORTA5 AN5 Digit Select 1 (LH)
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

ResH	EQU	0x20
ResL	EQU	0x21


;Begin
	ORG     0x0000
	BCF	INTCON, GIE	; clear global interrupts

	BANK1

	BCF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1	; 4mhz
	BSF	OSCCON, IRCF2 	; internal osc with Port Function on RA6 / RA7

	;TRISA  0000 1001 all outputs except 0 and 3
	MOVLW	0x09
	MOVWF	TRISA

	;TRISB  0000 0000 all outputs
	MOVLW	0x00
	MOVWF	TRISB

	;ANSEL	0000 1001 AN0 input and AN3/VREF+
	MOVLW	0x09
	MOVWF	ANSEL

	BCF ADCON1, ADFM  ;result LEFT justified MSBs in adresH
	BCF ADCON1, ADCS2 ;clock not divided
	BCF ADCON1, VCFG0 ;GND
	BSF ADCON1, VCFG1 ;VREF+

	BANK0
	BSF ADCON0, ADON  ;adc module ON
	BSF ADCON0, ADCS0 ;internal ad clock
	BSF ADCON0, ADCS1 ;internal ad clock

MAIN	BANK0


; SAMPLE CHANNEL 0
	BCF	ADCON0, CHS0	; Set channel 0
	BCF	ADCON0, CHS1
	BCF	ADCON0, CHS2
	CALL WAIT40		; wait TACQ time
	BSF	ADCON0, GO 	; Start conversion
S_Loop0	BTFSC	ADCON0, GO	; pool GO/Done for 0
	GOTO S_Loop0

	; read data pair ADRESH ADRESL	
	MOVF	ADRESH, w
	MOVWF	ResH
	BANK1
	MOVF	ADRESL, w
	BANK0
	MOVWF	ResL	


























	DECF	Mode, f
	BTFSC	STATUS, Z
	GOTO    SEND



; SAMPLE CHANNEL 1
	BSF	ADCON0, CHS0	; Set channel 1
	BCF	ADCON0, CHS1
	BCF	ADCON0, CHS2
	CALL WAIT40		; wait TACQ time
	BSF	ADCON0, GO 	; Start conversion
S_Loop1	BTFSC	ADCON0, GO	; pool GO/Done for 0
	GOTO S_Loop1

	; read data pair ADRESH ADRESL	
	MOVF	ADRESH, w
	MOVWF	Res1H
	BANK1
	MOVF	ADRESL, w
	BANK0
	MOVWF	Res1L	

	DECF	Mode, f
	BTFSC	STATUS, Z
	GOTO    SEND



; SAMPLE CHANNEL 5
	BSF	ADCON0, CHS0	; Set channel 5
	BCF	ADCON0, CHS1
	BSF	ADCON0, CHS2
	CALL	WAIT40		; wait TACQ time
	BSF	ADCON0, GO 	; Start conversion
S_Loop5	BTFSC	ADCON0, GO	; pool GO/Done for 0
	GOTO S_Loop5

	; read data pair ADRESH ADRESL	
	MOVF	ADRESH, w
	MOVWF	Res5H
	BANK1
	MOVF	ADRESL, w
	BANK0
	MOVWF	Res5L	

	DECF	Mode, f
	BTFSC	STATUS, Z
	GOTO    SEND


; SAMPLE CHANNEL 6
	BCF	ADCON0, CHS0	; Set channel 6
	BSF	ADCON0, CHS1
	BSF	ADCON0, CHS2
	CALL	WAIT40		; wait TACQ time
	BSF	ADCON0, GO 	; Start conversion
S_Loop6	BTFSC	ADCON0, GO	; pool GO/Done for 0
	GOTO S_Loop6

	; read data pair ADRESH ADRESL	
	MOVF	ADRESH, w
	MOVWF	Res6H
	BANK1
	MOVF	ADRESL, w
	BANK0
	MOVWF	Res6L	


SEND	BCF	PORTB, 5	;dataready

; Bits 0-7
	MOVLW	0x08
	MOVWF	Shift

Send_L1	BSF	PORTB, 4	; clock up

	BCF	PORTB, 0
	RRF	Res0L, f
	BTFSC	STATUS, C
	BSF	PORTB, 0

	BCF	PORTB, 1
	RRF	Res1L, f
	BTFSC	STATUS, C
	BSF	PORTB, 1

	BCF	PORTB, 2
	RRF	Res5L, f
	BTFSC	STATUS, C
	BSF	PORTB, 2

	BCF	PORTB, 3
	RRF	Res6L, f
	BTFSC	STATUS, C
	BSF	PORTB, 3

	BCF	PORTB, 4	; clock down

	NOP
	NOP
	NOP
	NOP

	NOP
	NOP
	NOP
	NOP

	DECFSZ	Shift, f
	GOTO Send_L1


; Bits 8-9
	MOVLW	0x02
	MOVWF	Shift

Send_L2	BSF	PORTB, 4	; clock up

	BCF	PORTB, 0
	RRF	Res0H, f
	BTFSC	STATUS, C
	BSF	PORTB, 0

	BCF	PORTB, 1
	RRF	Res1H, f
	BTFSC	STATUS, C
	BSF	PORTB, 1

	BCF	PORTB, 2
	RRF	Res5H, f
	BTFSC	STATUS, C
	BSF	PORTB, 2

	BCF	PORTB, 3
	RRF	Res6H, f
	BTFSC	STATUS, C
	BSF	PORTB, 3

	BCF	PORTB, 4	; clock down

	NOP
	NOP
	NOP
	NOP

	NOP
	NOP
	NOP
	NOP

	DECFSZ	Shift, f
	GOTO Send_L2

	GOTO	MAIN

WAIT40	MOVLW	0x05
	MOVWF	Timer
Wait40l	DECFSZ	Timer, f
	GOTO	Wait40l
	RETURN


	END