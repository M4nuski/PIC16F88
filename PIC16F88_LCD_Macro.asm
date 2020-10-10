; LCD Definitions

; PORTA0 I/O AN0				LCD E		White
; PORTA1 I/O AN1				LCD S/R		Black
; PORTA2 I/O AN2 CVref Vref-	LCD Clock	Green
; PORTA3 I/O AN3 Vref+ C1Out	LCD Data	Red

; Default interface
#ifndef __LCD_E
	#define	__LCD_E		PORTA, 0
#endif
#ifndef __LCD_RS
	#define	__LCD_RS	PORTA, 1
#endif
#ifndef __LCD_CLK
	#define	__LCD_CLK	PORTA, 2
#endif
#ifndef __LCD_DATA
	#define	__LCD_DATA	PORTA, 3
#endif

; Line addresses
#define __LCD_LINE1			0x00
#define __LCD_LINE2			0x40
#define __LCD_LINE3			0x14
#define __LCD_LINE4			0x54

; Configuration and commands
#define __LCD_CLEAR			0x01 ;Clear Display
#define __LCD_HOME			0x02 ;Return Cursor to Home Position

#define __LCD_EMS			0x04 ;Entry Mode Set
#define __LCD_EMS_INC		0x02
#define __LCD_EMS_FOLLOW	0x01

#define __LCD_DISP			0x08 ;Display Setup
#define __LCD_DISP_ON		0x04 ;Display On
#define __LCD_DISP_CUR		0x02 ;Cursor On
#define __LCD_DISP_BLINK	0x01 ;Cursor Blink On
	
#define __LCD_SHIFT			0x10 ;Shift
#define __LCD_SHIFT_DISP	0x08 ;Shift display instead of cursor
#define __LCD_SHIFT_RIGHT	0x04 ;Shift right else left

#define __LCD_SYSTEM		0x20 ;System Set +0x10 8bit Interface else 4bit +0x08 2 Lines else 1 Line +0x04 5x10 font else 5x7
#define __LCD_SYS_8BIT		0x10 ;8Bit interface, else 4bits
#define __LCD_SYS_2LINES	0x08 ;2 Lines, else 1 line
#define __LCD_SYS_5X10		0x04 ;5x10 font else 5x7

	;ORG 0x2100
	;DE "LCD Test M4nusky2016"
	;ORG 0x2110
	;DE "Ligne 2 du flash"
	

;GPRs for LCD	
	cblock 0x020
		__LCD_BUFFER
		__LCD_ROM_SIZE
		__LCD_LOOP1
		__LCD_LOOP2
	endc
	

LCD_INIT	MACRO ; Default Init sequence and configuration
	BANK1
	BCF __LCD_E		;Output LCD E		White
	BCF __LCD_RS	;Output LCD R/S		Black
	BCF __LCD_CLK	;Output LCD CLK		Green
	BCF __LCD_DATA	;Output LCD Data	Red
	BANK0

	CALL LCD_WAIT_50ms	;Wait 50ms for the LCD to initialize itself
	BCF __LCD_RS		;R/S to CTRL Register 

	__LCD_SEND_L __LCD_SYSTEM | __LCD_SYS_8BIT
	__LCD_SEND_L __LCD_SYSTEM | __LCD_SYS_8BIT
	
	CALL LCD_WAIT_50ms	

	__LCD_SEND_L __LCD_SYSTEM | __LCD_SYS_8BIT | __LCD_SYS_2LINES | __LCD_SYS_5X10	
	__LCD_SEND_L __LCD_DISP   | __LCD_DISP_ON
	__LCD_SEND_L __LCD_CLEAR
	__LCD_SEND_L __LCD_EMS    | __LCD_EMS_INC
	
	CALL LCD_WAIT_50ms

	BSF __LCD_RS		;R/S to RAM
ENDM

__LCD_SEND_W		MACRO
	MOVWF __LCD_BUFFER
	CALL __LCD_SEND
ENDM

__LCD_SEND_F		MACRO file
	MOVF file, W
	MOVWF __LCD_BUFFER
	CALL __LCD_SEND
ENDM

__LCD_SEND_L		MACRO literate
	MOVLW literate
	MOVWF __LCD_BUFFER
	CALL __LCD_SEND
ENDM

_LCD_ADDRESS_W		MACRO
	MOVWF __LCD_BUFFER
	BSF __LCD_BUFFER, 7	;Address Flag
	BCF __LCD_RS		;R/S to CTRL
	CALL __LCD_SEND
	BSF __LCD_RS		;R/S to RAM
ENDM

_LCD_ADDRESS_F		MACRO file
	MOVF file, W
	MOVWF __LCD_BUFFER
	BSF __LCD_BUFFER, 7	;Address Flag
	BCF __LCD_RS		;R/S to CTRL
	CALL __LCD_SEND
	BSF __LCD_RS		;R/S to RAM
ENDM

_LCD_ADDRESS_L		MACRO literate
	MOVLW literate
	MOVWF __LCD_BUFFER
	BSF __LCD_BUFFER, 7	;Address Flag
	BCF __LCD_RS		;R/S to CTRL
	CALL __LCD_SEND
	BSF __LCD_RS		;R/S to RAM
ENDM

__LCD_SEND_ROM_L		MACRO address, length
	MOVLW address
	MOVWF EEADR
	MOVLW length
	MOVWF __LCD_ROM_SIZE
	CALL __LCD_SEND_ROM	
ENDM

_LCD_TEST	MACRO
	_LCD_ADDRESS_L _LCD_Line1
	__LCD_SEND_ROM_L 0x00 , 0x14

	_LCD_ADDRESS_L _LCD_Line2
	__LCD_SEND_ROM_L 0x14 0x10	

	_LCD_ADDRESS_L _LCD_Line3	
	__LCD_SEND_L 0x41
	__LCD_SEND_L 0x42
	__LCD_SEND_L 0x43
	__LCD_SEND_L 0x44

	_LCD_ADDRESS_L _LCD_Line4	
	__LCD_SEND_L 0x45
	__LCD_SEND_L 0x46
	__LCD_SEND_L 0x47
	__LCD_SEND_L 0x48
ENDM
	
	
;Subroutines


LCD_CLEAR	
	BCF __LCD_RS		;R/S to CTRL
	__LCD_SEND_L _LCD_CLR
	BSF __LCD_RS		;R/S to RAM
	CALL LCD_WAIT_50ms
	RETURN	
	
; TODO LOOPS AND LOOP DELAY CONSTANTS
LCD_WAIT_50ms
	MOVLW 0x32		;50*250*4uS = 50mS
	MOVWF LCDLP2
LW50M1	MOVLW 0xFA
	MOVWF LCDLP1
LW50M2	NOP
	DECFSZ LCDLP1, F
	GOTO LW50M2
	DECFSZ LCDLP2, F
	GOTO LW50M1
	RETURN	

_LCD_SEND_ROM
	BANK1
	BSF EECON1, RD
	BANK0
	__LCD_SEND_F EEDATA
	INCF EEADR, F
	DECFSZ __LCD_ROM_SIZE, F
	GOTO __LCD_SEND_ROM
	RETURN	

_LCD_SEND
	MOVLW 0x08	; 8 bit for the shift register
	MOVWF LCDLP1

LCDSL
	BCF __LCD_CLK
	RLF __LCD_BUFFER, F	;MSB first
	BSF __LCD_DATA
	BTFSS STATUS, C
	BCF __LCD_DATA	
	BSF __LCD_CLK	;trig sr
	DECFSZ LCDLP1, F
	GOTO LCDSL
	BSF __LCD_E	;Trig E
	BCF __LCD_E
	MOVLW 0x10	;16 CYCLE
	MOVWF LCDLP1
LCDSW	
	DECFSZ LCDLP1, F;3uS PER CYCLE
	GOTO LCDSW
	RETURN


	
	END