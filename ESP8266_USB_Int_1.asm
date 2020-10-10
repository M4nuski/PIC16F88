	LIST		p=16F88			;Processor
	#INCLUDE	<p16F88.inc>	;Processor Specific Registers
	#INCLUDE	<PIC16F88_Macro.asm>	;Bank switching, 16bit methods , wrapped jumps 

	__CONFIG	_CONFIG1, _CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_OFF & _PWRTE_ON & _WDT_OFF & _INTRC_IO
	__CONFIG	_CONFIG2, _IESO_OFF & _FCMEN_ON

; ESP8266 to FTDI USB transcriber
; Version 01
; EC2017
; 
; Internal 8MHz OSC 2MOPS 0.5us per ops
; UART at 74880 bauds (26 MHz crystal) 26.71 inst per signal
; PORTB as input / output from USB


#define _USB_READ	PORTA, 0
#define _USB_WRITE	PORTA, 1
#define _USB_RX_RDY	PORTA, 6
#define _USB_TX_RDY	PORTA, 7

#define _ESP_MOSI	PORTA, 2
#define _ESP_MISO	PORTA, 3
;#define			PORTA, 4
;#define			PORTA, 5

_delay			EQU 0xFF - 0x18 ;timer0 interrupt

STACK_W			EQU 0x7D
STACK_STATUS	EQU 0x7E
STACK_PCLATH	EQU 0x7F

;GPR
	cblock 0x020
		uart_in_bit_indx
		uart_out_bit_indx
		uart_in_data
		uart_out_data
	endc

	
	
RESET
	ORG	0x000
	GOTO SETUP
	
INTERRUPT
	ORG 0x004
	
	;reset interrupt
	MOVLW _delay
	MOVWF TMR0
	BCF INTCON, TMR0IF
	;3

	;uart is 1 state per 27 instruction clocks
	;no context saving because all code is in ISR and should never collide
	
	; check uart input state
	BCF STATUS, C
	BTFSC _ESP_MISO
	BSF STATUS, C
	RLF uart_in_data, F
	DECFSZ uart_in_bit_indx, F
	GOTO chkUSB ; if input buffer full, send data on usb and end ISR, otherwise check usb for data or uart output buffer
	;7 / 10
	
	MOVF uart_in_data, W
	MOVWF PORTB
	BSF _USB_WRITE
	MOVLW 0x08
	MOVWF uart_in_bit_indx
	BCF _USB_WRITE
	RETFIE
	;8 / 18
	
	
	
chkUSB	
	MOVF uart_out_bit_indx, F
	BTFSS STATUS, Z		;uart output buffer not empty, keep sending bits, else check usb for new data
	GOTO sendUart
	;4 / 14
	
	BTFSC _USB_RX_RDY	;usb data ready signal
	RETFIE
	;3 / 17
	
	BCF	_USB_READ
	MOVF PORTB, W
	MOVWF uart_out_data	; load data and prep uart output buffer and index
	MOVLW 0x08
	MOVWF uart_out_bit_indx
	BSF _USB_READ
	RETFIE
	;8 / 25
	
sendUart
	RRF uart_out_data, F	; send 1 bit to slave
	BTFSS STATUS, C
	BCF _ESP_MOSI
	BTFSC STATUS, C
	BSF _ESP_MOSI
	DECF uart_out_bit_indx, F
	;6 / 20

	RETFIE
	
	
	
	
	
SETUP
	BANK0
	BCF	INTCON, GIE	; clear global interrupts for now	

	BANK1
	BSF	OSCCON, IRCF0	; internal OSC setup
	BSF	OSCCON, IRCF1	; 8mhz
	BSF	OSCCON, IRCF2	
	
	CLRF ANSEL			; all digital IO

	CLRF PORTB 	; all output
	
	BCF _USB_READ
	BCF _USB_WRITE
	
	BSF _USB_RX_RDY
	BSF _USB_TX_RDY

	BCF _ESP_MOSI
	BSF	_ESP_MISO
	
	BCF OPTION_REG, T0CS
		
	BANK0		

	; default states
	BSF _USB_READ
	BCF _USB_WRITE
	BSF _ESP_MOSI


	MOVLW 0x08
	MOVWF uart_in_bit_indx
	MOVWF uart_out_bit_indx

	
	MOVLW _delay
	MOVWF TMR0
	BSF INTCON, TMR0IE
	BCF INTCON, TMR0IF
	BSF INTCON, GIE
	
	
	
	
MAIN
	; just wait for ISR
	; maybe add a bunch of NOP to prevent interrupt falling in goto
	GOTO MAIN
	END

	