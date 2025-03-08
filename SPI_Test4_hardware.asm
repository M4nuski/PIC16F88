;#############################################################################
;
;       SPI Interface test
;       SSP test for hardware SPI
;       Exteranl Clock source at 20MHz 5MOPS 0.2us per ops
;	3.3v
;
;#############################################################################
;
;       Version 01
;
;#############################################################################

	LIST		p=16F88			;Processor
	#INCLUDE	<p16F88.inc>	;Processor Specific Registers
	#INCLUDE	<PIC16F88_Macro.asm>	;Bank switching, 16bit methods , wrapped jumps 

	__CONFIG	_CONFIG1, _CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_ON & _PWRTE_ON & _WDT_OFF &_INTRC_IO; _INTRC_IO;_EXTCLK
	__CONFIG	_CONFIG2, _IESO_OFF & _FCMEN_ON
; cmd.exe /k ""C:/Prog/PIC/MPASM 560/MPASMx" /c- /e=CON /q+ /m+ /x- /rDEC  "$(FULL_CURRENT_PATH)""
	ERRORLEVEL -302		; suppress "bank" warnings
;#############################################################################
;	Pinout
;#############################################################################

; PIC16F88:
; pin  1 IOA PORTA2	I 
; pin  2 IOA PORTA3	I 
; pin  3 IOA PORTA4	I  
; pin  4 I__ PORTA5	I  
; pin  5 PWR VSS	GND
; pin  6 IO_ PORTB0	O 
; pin  7 IO_ PORTB1	O SSP_SDI 
; pin  8 IOR PORTB2	O SSP_SDO 
; pin  9 IO_ PORTB3	O 

; pin 10 IO_ PORTB4	0 SSP_SCK 
; pin 11 IOT PORTB5	O TFT_CS
; pin 12 IOA PORTB6	I 
; pin 13 IOA PORTB7	I 
; pin 14 PWR VDD	VCC
; pin 15 _OX PORTA6	O 
; pin 16 I_X PORTA7	OSC Input
; pin 17 IOA PORTA0	I  
; pin 18 IOA PORTA1	I  

; Config - IL19488 SPI TFT

#DEFINE PIN_TFT_CS	PORTB, 5 ; active low
#DEFINE PIN_SSP_SCK	PORTB, 4 ; active low

#DEFINE PIN_SSP_SDO	PORTB, 2 ; mode is sck idle low, latch on rising edge
#DEFINE PIN_SSP_SDI	PORTB, 1


;GPR
d1		EQU	0x20 ; loop
d2		EQU	0x21
d3		EQU	0x22
;	EQU     0x23 ; 
;	EQU     0x24 ; 
;	EQU     0x25 ; 

; MACRO

; CODE
	ORG	0x0000

SETUP:
	BANK0
	BCF	INTCON, GIE	; clear global interrupts	

	BANK1
	BCF	OSCCON, SCS0	; no switchover
	BCF	OSCCON, SCS1
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1
	BSF	OSCCON, IRCF2
	
SETUP_OSC:
	BTFSS	OSCCON, IOFS
	GOTO	SETUP_OSC
	
	CLRF    ANSEL		; all digital IO

	; Port pin direction
        BCF     PIN_TFT_CS
        BCF     PIN_SSP_SCK
        BCF     PIN_SSP_SDO
	BSF	PIN_SSP_SDI
        
	BANK0		
	; default state SPI mode 3
	BSF     PIN_TFT_CS
	BCF     PIN_SSP_SCK ; clock idle low
	
	; initialise SSP for SPI
	BANKSEL	PIE1
	BSF	PIE1, SSPIE
	BANKSEL	PIR1
	BSF	PIR1, SSPIF ; default is flag set, end of tx
	
	BANKSEL	SSPSTAT
	BCF	SSPSTAT, 7 ; SMP sample input at same time
	BSF	SSPSTAT, 6 ; CKE 
	
	BANKSEL	SSPCON
	BCF	SSPCON, 7 ; WCOL clear collision flag
	BCF	SSPCON, 6 ; SSPOV clear receive overflow flag
	BCF	SSPCON, 4 ; CPK low, tx on rising edge
	BCF	SSPCON, 3
	BCF	SSPCON, 2
	BCF	SSPCON, 1
	BCF	SSPCON, 0 ; SSPM 0000 SPI Master Clock at Fosc/4
	BSF	SSPCON, 5 ; SSPEN enable SPI port


MAIN:
	BANK0

LOOP:

	MOVLW	0x55
	CALL	TFT_TX_BYTE
	CALL	TFT_SEND_DATA1
	CALL	d120ms
	
	MOVLW	0xAA
	CALL	TFT_TX_BYTE
	CALL	TFT_SEND_DATA1
	CALL	d120ms

	GOTO	LOOP

;#############################################################################
;	Delay subroutines for 20MHzkin
;#############################################################################

d50us: ; delay 50 us: 6ops overhead (1.2us) + 3 (0.6us) per loop, 81 loops
	MOVLW   81
	MOVWF   d1
d50l:
	DECFSZ  d1, F
	GOTO    d50l
	RETURN
	
d10ms:
	MOVLW	20
	MOVWF	d1
	CLRF	d2
	GOTO	$+1
	NOP
d10msLoop:	;2us per d2 loop*256 = 0.512 ms per 256d2
        GOTO    $+1
	GOTO    $+1
	GOTO    $+1
        NOP
	DECFSZ  d2, F
	GOTO    d10msLoop	;loop d2 : 10op / cycles, = 2560 op / d1
	DECFSZ  d1, F
	GOTO    d10msLoop	;loop d1 overhead = 3 
	
	RETURN
	
d120ms:	; delay 120ms : header + d1loops * (d1 overhead + (d2loops * (d2 delay)))
	MOVLW   233
	MOVWF   d1
	CLRF    d2
        GOTO    $+1
        NOP
	;header+RETURN : 10 = 2us
d120l:	;2us per d2 loop*256 = 0.512 ms per 256d2
        GOTO    $+1
	GOTO    $+1
	GOTO    $+1
        NOP
	DECFSZ  d2, F
	GOTO    d120l	;loop d2 : 10op / cycles, = 2560 op / d1
	DECFSZ  d1, F
	GOTO    d120l	;loop d1 overhead = 3 
	
	RETURN
	
;#############################################################################
;	TFT communication subroutines
;#############################################################################

TFT_TX_BYTE:	; hardware SPI version, async, no interrupt
	BCF     PIN_TFT_CS
	
	MOVWF   SSPBUF		; byte to send in internal buffer
	BSF	STATUS, RP0
	BTFSS	SSPSTAT, BF
	GOTO	$-1
	BCF	STATUS, RP0
	
	BSF	PIN_TFT_CS
	RETURN
	
TFT_SEND_DATA0:	; send data 0
	BCF     PIN_TFT_CS
	
	CLRF	SSPBUF
	BSF	STATUS, RP0
	BTFSS	SSPSTAT, BF
	GOTO	$-1
	BCF	STATUS, RP0
	
	BSF	PIN_TFT_CS
	RETURN
	
TFT_SEND_DATA00: ; send data 00
	BCF     PIN_TFT_CS
	
	CLRF	SSPBUF
	BSF	STATUS, RP0
	BTFSS	SSPSTAT, BF
	GOTO	$-1
	BCF	STATUS, RP0
	
	CLRF	SSPBUF
	BSF	STATUS, RP0
	BTFSS	SSPSTAT, BF
	GOTO	$-1
	BCF	STATUS, RP0
	
	BSF	PIN_TFT_CS
	RETURN
	
TFT_SEND_DATA1:	; send data 1
	BCF     PIN_TFT_CS
	
	MOVLW	0xFF
	MOVWF	SSPBUF
	BSF	STATUS, RP0
	BTFSS	SSPSTAT, BF
	GOTO	$-1
	BCF	STATUS, RP0
	
	BSF	PIN_TFT_CS
	RETURN
	
TFT_SEND_DATA11: ; send data 11
	BCF     PIN_TFT_CS
	
	MOVLW	0xFF
	MOVWF	SSPBUF
	BSF	STATUS, RP0
	BTFSS	SSPSTAT, BF
	GOTO	$-1
	BCF	STATUS, RP0
	
	MOVWF	SSPBUF
	BSF	STATUS, RP0
	BTFSS	SSPSTAT, BF
	GOTO	$-1
	BCF	STATUS, RP0
	
	BSF	PIN_TFT_CS
	RETURN
	
	
	
	END