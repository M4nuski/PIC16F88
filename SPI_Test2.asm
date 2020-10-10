	LIST	p=16F88		;Processor
	#INCLUDE <p16F88.inc>	;Processor Specific Registers
	#INCLUDE <PIC16F88_Macro.asm>
	
	__CONFIG	_CONFIG1, _CP_OFF & _CCP1_RB0 & _DEBUG_OFF & _WRT_PROTECT_OFF & _CPD_OFF & _LVP_OFF & _BODEN_OFF & _MCLR_OFF & _PWRTE_ON & _WDT_OFF & _INTRC_IO
	__CONFIG	_CONFIG2, _IESO_ON & _FCMEN_ON

; Bank #    SFR           GPR               SHARED GPR's
; Bank 0    0x00-0x1F     0x20-0x6F         0x70-0x7F    
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF

; SPI 0 Config
#define _SPI0_CS  PORTB, 0
#define _SPI0_SCK PORTB, 1
#define _SPI0_DTA PORTB, 2
#define _SPI0_A0  PORTB, 3 ; register select / A0 command:0, data:1
#define _SPI0_RST PORTB, 4

; ST7735 TFT Controller command constants
_TFT_SWRESET EQU 0x01;
_TFT_SLPOUT  EQU 0x11;
_TFT_NORON 	 EQU 0x13;
_TFT_DISPON  EQU 0x29;
_TFT_CASET 	 EQU 0x2A;
_TFT_RASET 	 EQU 0x2B;
_TFT_RAMWR 	 EQU 0x2C;
_TFT_MADCTL  EQU 0x36;
_TFT_COLMOD  EQU 0x3A;
	
; SPI interface GPR
cblock 0x020
	d1, d2 ; loops counters
	SPI0_OUT ; output buffer for SPI 0
;_SPI0_IN		EQU 0x0E
;_SPI0_LEN_B2	EQU 0x0F
;_SPI0_LEN_B1	EQU 0x10
;_SPI0_LEN_B0	EQU 0x11	
endc


	ORG	0x0000
	BANK0
	BCF	INTCON, GIE	; clear global interrupts

	BANK1
	BSF	OSCCON, IRCF0
	BSF	OSCCON, IRCF1	; 8mhz
	BSF	OSCCON, IRCF2	
	
	; init registers
	
	CLRF ANSEL
	
	; SPI		
	bcf _SPI0_CS
	bcf _SPI0_SCK
	bcf _SPI0_DTA
	bcf _SPI0_RST
	bcf _SPI0_A0
	
	; status leds
	BCF TRISA, 2 ;out
	BCF TRISA, 3 ;out
	BCF TRISA, 4 ;out

	BANK0
	
	; default state mode 3
	bsf PORTB, _SPI0_CS
	bsf PORTB, _SPI0_SCK
	bsf PORTB, _SPI0_RST
	
	; clear status
	CLRF PORTA
	call delay
	call delay
	call delay
	
	BSF PORTA, 2
	
	; main
	; reset TFT
	
	call delay
	BCF PORTB, _SPI0_RST
	call delay	
	BSF PORTB, _SPI0_RST
	
	
	; init TFT
	

	movlw _TFT_SWRESET	;sendCMD(ST7735_SWRESET);
	call SPI0_Send_CMD
	call delay
	
	movlw _TFT_SLPOUT	;sendCMD(ST7735_SLPOUT);
	call SPI0_Send_CMD
	call delay
	
	movlw _TFT_NORON		;sendCMD(ST7735_NORON);
	call SPI0_Send_CMD	
	call delay
	
 	movlw _TFT_COLMOD	;sendCMD(ST7735_COLMOD);
	call SPI0_Send_CMD	  
 	movlw 0x06			;RGB666
	call SPI0_Send_DTA	  
	call delay
	
	movlw _TFT_DISPON	;sendCMD(ST7735_DISPON);
	call SPI0_Send_CMD	
	call delay	
	
	movlw _TFT_MADCTL	;sendCMD(ST7735_MADCTL);
	call SPI0_Send_CMD
	movlw 0xA0			;MY1 MX0 MV1 ML0 RGB MH0
	call SPI0_Send_DTA 
	call delay
	
	movlw _TFT_CASET		;sendCMD(ST7735_CASET);
	call SPI0_Send_CMD
	CLRW
	call SPI0_Send_DTA 	;sendDTA(0x00)
	CLRW
	call SPI0_Send_DTA 	;sendDTA(0x00)
	CLRW
	call SPI0_Send_DTA 	;sendDTA(0x00)
	movlw 0x9F			;160 pixels wide
	call SPI0_Send_DTA 	;sendDTA(0x9F)
	call delay
	
	movlw _TFT_RASET	;sendCMD(ST7735_RASET);
	call SPI0_Send_CMD	
	CLRW
	call SPI0_Send_DTA 	;sendDTA(0x00)
	CLRW
	call SPI0_Send_DTA 	;sendDTA(0x00)
	CLRW
	call SPI0_Send_DTA 	;sendDTA(0x00)
	movlw 0x7F			;128 pixels high
	call SPI0_Send_DTA 	;sendDTA(0x7F)
	call delay
	
	BSF PORTA, 3
	
	movlw _TFT_RAMWR	;sendCMD(ST7735_RAMWR);
	call SPI0_Send_CMD	
	call delay
	
	CLRW
	call SPI0_Send_DTA
	CLRW
	call SPI0_Send_DTA
	CLRW
	call SPI0_Send_DTA

	movlw 0xFF
	call SPI0_Send_DTA
	CLRW
	call SPI0_Send_DTA
	CLRW
	call SPI0_Send_DTA

	CLRW
	call SPI0_Send_DTA
	MOVLW 0xFF
	call SPI0_Send_DTA
	CLRW
	call SPI0_Send_DTA	
	
	CLRW
	call SPI0_Send_DTA
	CLRW
	call SPI0_Send_DTA	
	MOVLW 0xFF
	call SPI0_Send_DTA
	
	MOVLW 0xFF
	call SPI0_Send_DTA
	MOVLW 0xFF
	call SPI0_Send_DTA
	MOVLW 0xFF
	call SPI0_Send_DTA
	
	clrf d1	
nx
	movf d1, W	
	call SPI0_Send_DTA
	movf d1, W
	call SPI0_Send_DTA	
	movf d1, W
	call SPI0_Send_DTA

	decfsz d1, F
	goto nx
	
	BSF PORTA, 4
	
e	GOTO e ;end of program stall
	
	
	

delay	
	clrf d1
	clrf d2
	
l1
	nop
	nop
	nop
	nop
	nop
	decfsz d2, f
	goto l1
	decfsz d1, f
	goto l1
	
	RETURN
	

	
SPI0_Send_CMD
	BCF PORTB, _SPI0_A0
	GOTO SPI_TX_BYTE


SPI0_Send_DTA	
	BSF PORTB, _SPI0_A0
	GOTO SPI_TX_BYTE

	
; Transfer 1 Byte Subroutine
SPI_TX_BYTE
	MOVWF SPI0_OUT
	movlw 0x08
	movwf _SPI_BitCount
	
	bcf PORTB, _SPI0_CS
	nop
	
spi_bit_loop	;clk down, latch, clk up, hold

	bcf PORTB, _SPI0_SCK
	
	RLF	SPI0_OUT, F	;msb first, Carry Bit contains data	
	BTFSC STATUS, C 
	GOTO stb_set 
	BCF PORTB, _SPI0_DTA 
	GOTO stb_end 
	
stb_set	
	BSF PORTB, _SPI0_DTA
	
stb_end
	nop ;1
	nop ;2 
	bsf PORTB, _SPI0_SCK
	decfsz _SPI_BitCount, F
	GOTO spi_bit_loop
	
	nop	
	bsf PORTB, _SPI0_CS	
	RETURN
	
	
	END
	
	

	
	
	