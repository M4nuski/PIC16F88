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
; pin  3 PORTA4 LSB Number of Channels
; pin  4 PORTA5 MSB Number of Channels
; pin  5 VSS
; pin  6 PORTB0 Output Serial Data Out Channel 0 
; pin  7 PORTB1 Output Serial Data Out Channel 1 
; pin  8 PORTB2 Output Serial Data Out Channel 5 
; pin  9 PORTB3 Output Serial Data Out Channel 6 
; pin 10 PORTB4 Output Serial Data Out Clock
; pin 11 PORTB5 Output Busy/¯Dataready¯ 
; pin 12 PORTB6 Input AN5
; pin 13 PORTB7 Input AN6
; pin 14 VDD
; pin 15 N/C
; pin 16 N/C
; pin 17 PORTA0 Input AN0
; pin 18 PORTA1 Input AN1

;Variables declarations:
Mode	EQU	0x20
Res0H	EQU	0x21
Res0L	EQU	0x22
Res1H	EQU	0x23
Res1L	EQU	0x24
Res5H	EQU	0x25
Res5L	EQU	0x26
Res6H	EQU	0x27
Res6L	EQU	0x28
Timer	EQU	0x29
Shift	EQU	0x2A

;Begin
	ORG     0x0000
	BCF	INTCON, GIE

	BANK1

	BCF	OSCCON, IRCF0
	BCF	OSCCON, IRCF1
	BCF	OSCCON, IRCF2 

	;TRISA  00111111 3F all inputs except 6 and 7
	MOVLW	0x3F
	MOVWF	TRISA

	;TRISB  11000000 C0 all outputs except 6 and 7 
	MOVLW	0xC0
	MOVWF	TRISB

	;ANSEL	01101111 6F select an0 an1 an2(vref) an3(vref) an5 an6 as analog inputs
	MOVLW	0x6F
	MOVWF	ANSEL

	BSF ADCON1, ADFM  ;result right justified
	BCF ADCON1, ADCS2 ;clock not divided
	BSF ADCON1, VCFG0 ;vref+
	BSF ADCON1, VCFG1 ;vref-

	BANK0
	BSF ADCON0, ADON  ;adc module ON
	BSF ADCON0, ADCS0 ;internal ad clock
	BSF ADCON0, ADCS1 ;internal ad clock

MAIN	BANK0
	CLRF	Mode
	BTFSC	PORTA, 4
	BSF	Mode, 0
	BTFSC	PORTA, 5
	BSF	Mode, 1
	INCF	Mode, f

	BSF	PORTB, 5 ;busy



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
	MOVWF	Res0H
	BANK1
	MOVF	ADRESL, w
	BANK0
	MOVWF	Res0L	

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
