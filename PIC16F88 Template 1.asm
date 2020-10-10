;******************************************************************************
;                                                                             *
;    Filename:         xxx.asm                                                *
;    Date:                                                                    *
;    File Version:                                                            *
;                                                                             *
;    Author:                                                                  *
;    Company:                                                                 *
;                                                                             *
;******************************************************************************

     LIST      p=16F88              ; list directive to define processor
     #INCLUDE <P16F88.INC>          ; processor specific variable definitions


;           SFR           GPR               SHARED GPR's
; Bank 0    0x00-0x1F     0x20-0x6F         0x70-0x7F    
; Bank 1    0x80-0x9F     0xA0-0xEF         0xF0-0xFF  
; Bank 2    0x100-0x10F   0x110-0x16F       0x170-0x17F
; Bank 3    0x180-0x18F   0x190-0x1EF       0x1F0-0x1FF


W_TEMP         EQU        0x7D  ; w register for context saving (ACCESS)
STATUS_TEMP    EQU        0x7E  ; status used for context saving (ACCESS)
PCLATH_TEMP    EQU        0x7F  ; variable used for context saving





RESET     ORG     0x0000            ; processor reset vector
          PAGESEL START
          GOTO    START             ; go to beginning of program

;------------------------------------------------------------------------------
; INTERRUPT SERVICE ROUTINE
;------------------------------------------------------------------------------

ISR       ORG     0x0004            ; interrupt vector location

;         Context saving for ISR
          MOVWF   W_TEMP            ; save off current W register contents
          MOVF    STATUS,W          ; move status register into W register
          MOVWF   STATUS_TEMP       ; save off contents of STATUS register
          MOVF    PCLATH,W          ; move pclath register into W register
          MOVWF   PCLATH_TEMP       ; save off contents of PCLATH register

;------------------------------------------------------------------------------
; USER INTERRUPT SERVICE ROUTINE GOES HERE
;------------------------------------------------------------------------------

;         Restore context before returning from interrupt
          MOVF    PCLATH_TEMP,W     ; retrieve copy of PCLATH register
          MOVWF   PCLATH            ; restore pre-isr PCLATH register contents
          MOVF    STATUS_TEMP,W     ; retrieve copy of STATUS register
          MOVWF   STATUS            ; restore pre-isr STATUS register contents
          SWAPF   W_TEMP,F
          SWAPF   W_TEMP,W          ; restore pre-isr W register contents
          RETFIE                    ; return from interrupt

;------------------------------------------------------------------------------
; MAIN PROGRAM
;------------------------------------------------------------------------------

START

;------------------------------------------------------------------------------
; PLACE USER PROGRAM HERE
;------------------------------------------------------------------------------

          GOTO $

          END
