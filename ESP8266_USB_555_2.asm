	LIST		p=16F88			;Processor
	#INCLUDE	<p16F88.inc>	;Processor Specific Registers
	#INCLUDE	<PIC16F88_Macro.asm>	;Bank switching, 16bit methods , wrapped jumps 

	__CONFIG	_CONFIG1, _CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_OFF & _PWRTE_ON & _WDT_OFF & _EXTRC_IO
	__CONFIG	_CONFIG2, _IESO_OFF & _FCMEN_ON

; ESP8266 to FTDI USB transcriber
; Version 02
; EC2017
; 
; External 25.175MHZ Clock, 0.1589 us per instruction
; UART at 74880 bauds (26 MHz crystal on ESP module) 84 instructions per baud
; 555 Timer at 3.34us per cycle, 21 op max between trigger, including state check overhead
; PORTB as input / output from USB


#define _USB_RX_BSY	PORTA, 0 ;busy when high, data to read when low
#define _USB_TX_BSY	PORTA, 1 ;busy when high, data can be written when low

#define _USB_WRITE	PORTA, 2 ;wite data to fifo when high to low
#define _USB_READ	PORTA, 3 ;output read enabled when low, high to low read next fifo

#define _ESP_MISO	PORTA, 4
#define _TIMER_IN	PORTA, 5 ;from 555 perform uart when high to low ;input only RA5/#MCLR/Vpp

#define	_ESP_MOSI	PORTA, 6 ;ouput only RA6/OSC2/CLKO
#define	_CLOCK_IN	PORTA, 7 ;from SG531P ;input only RA7/OSC1/CLKI



STACK_W			EQU 0x7D
STACK_STATUS	EQU 0x7E
STACK_PCLATH	EQU 0x7F

;GPR
	cblock 0x020
		uart_in_bit_indx	; default 0x08, when 0 send data to usb
		uart_out_bit_indx	; default 0x00, when !=0 send data to uart
		uart_in_data		; uart input buffer from ESP
		uart_out_data		; uart output buffer from USB
	endc

	
	
RESET
	ORG	0x000
	GOTO SETUP
	
SETUP
	BANK0
	BCF	INTCON, GIE	; clear global interrupts

	BANK1
	;BSF	OSCCON, IRCF0	; internal OSC setup
	;BSF	OSCCON, IRCF1	; 8mhz
	;BSF	OSCCON, IRCF2	
	
	CLRF ANSEL			; all digital IO

	CLRF PORTB 	; all output
	
	BCF _USB_READ
	BCF _USB_WRITE
	
	BSF _USB_RX_BSY
	BSF _USB_TX_BSY

	BCF _ESP_MOSI
	BSF	_ESP_MISO
	
	BCF _TIMER_IN
	;BCF _CLOCK_IN
	
	;BCF OPTION_REG, T0CS
		
	BANK0		

	; default states
	BSF _USB_READ
	BCF _USB_WRITE
	BSF _ESP_MOSI


	MOVLW 0x08
	MOVWF uart_in_bit_indx
	
	CLRF uart_out_bit_indx

	
	;MOVLW _delay
	;MOVWF TMR0
	;BSF INTCON, TMR0IE
	;BCF INTCON, TMR0IF
	;BSF INTCON, GIE
	
	
	
	
MAIN


w_timer_H
	BTFSS _TIMER_IN
	GOTO w_timer_H
	
w_timer_H2L
	BTFSC _TIMER_IN
	GOTO w_timer_H2L
	
	;4-10
	
	;uart is 1 state per 21 instruction clocks

	
	; check uart input state
	BCF STATUS, C
	BTFSC _ESP_MISO
	BSF STATUS, C
	RLF uart_in_data, F
	DECFSZ uart_in_bit_indx, F
	GOTO MAIN ; if input buffer full, send data on usb and end ISR, otherwise check usb for data or uart output buffer
	;6 / 12
	
	MOVF uart_in_data, W
	MOVWF PORTB
	BSF _USB_WRITE
	MOVLW 0x08
	MOVWF uart_in_bit_indx
	BCF _USB_WRITE
	
	GOTO MAIN
	;8 / 20
	
	END
	
;chkUSB	
;	MOVF uart_out_bit_indx, F
;	BTFSS STATUS, Z		;uart output buffer not empty, keep sending bits, else check usb for new data
;	GOTO sendUart
	;4 / 24
	
;	BTFSC _USB_RX_RDY	;usb data ready signal
;	RETFIE
	;3 / 17
	
;	BCF	_USB_READ
;	MOVF PORTB, W
;	MOVWF uart_out_data	; load data and prep uart output buffer and index
;	MOVLW 0x08
;	MOVWF uart_out_bit_indx
;	BSF _USB_READ
;	RETFIE
	;8 / 25
	
;sendUart
;	RRF uart_out_data, F	; send 1 bit to slave
;	BTFSS STATUS, C
;	BCF _ESP_MOSI
;	BTFSC STATUS, C
;	BSF _ESP_MOSI
;	DECF uart_out_bit_indx, F
;	;6 / 20

	;RETFIE



;	GOTO MAIN
;	END

	