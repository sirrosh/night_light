#include P12F675.inc
; https://class.ece.uw.edu/475/peckol/code/Microchip/microchipExamples/mpasm/P12F675.INC
; https://www.microchip.com/forums/fb.aspx?m=478014
; http://www.piclist.com/techref/microchip/math/incdec/best16.htm

    __CONFIG   _CP_OFF & _CPD_OFF & _WDT_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT & _MCLRE_OFF
    __IDLOCS H'6969'

#define BlinkDebug

#define Light       GPIO, GP0
#define Button      GPIO, GP2
#define	RS_INTCON   B'11010000'
; GIE ----------------+|||||||
; PEIE ----------------+||||||
; T0IE -----------------+|||||
; INTE ------------------+||||
; GPIE -------------------+|||
; T0IF --------------------+||
; INTF ---------------------+|
; GPIF ----------------------+
#define	RS_T1CON    B'00111111'     ; Tc=32768Hz, 1:8 = 4096ticks/s, interrupt every 16 seconds
; N/I ----------------+|||||||
; TMR1GE --------------+||||||
; T1CKPS1 --------------+|||||
; T1CKPS0 ---------------+||||
; T1OSCEN ----------------+|||
; /T1SYNC -----------------+||
; TMR1CS -------------------+|
; TMR1ON --------------------+
#define T24H_h      0x15            ; There are 5400 (0x1518) 16-second cycles in 24 hours
#define T24H_l      0x18
                                    ; Work modes register
#define mLearning   wMode, 0        ; Learning active
#define mConfigured wMode, 1        ; The time has been configured or loaded
#define mLight      wMode, 2        ; The light is lit (GPIO shadow bit)

#include math16.inc
#include eeprom.inc

    CBLOCK 0x20
i_cycle
W_temp
STATUS_temp
TH_h
TH_l
T_h
T_l
wMode
    ENDC


DEEPROM     CODE                     ; let's put initial values to eeprom
    de 0x69, 0xFF

RES_VECT    CODE    0x0000          ; processor reset vector
    NOP                             ; for ICD
    GOTO    START

INT_VECT    CODE    0x0004          ; interrupt vector
    GOTO    INTERRUPT


MAIN_PROG   CODE                    ; let linker place main program

START
    CLRF    INTCON
    CLRF    wMode
    banksel OSCCAL
    CALL    0x3FF                   ; Get the OSCCAL value
    MOVWF   OSCCAL                  ; Calibrate oscillator
    banksel GPIO
    CLRF    GPIO                    ; Clearig port
    MOVLW   0x07                    ; Turning off analog modules
    MOVWF   CMCON
    banksel ANSEL
    CLRF    ANSEL
    BSF     Button                  ; TRISIO configuration while BANK=1
    BCF     Light
    MOVLW   B'00000100'             ; Pull-ups config, only on INT/GP2 
    MOVWF   WPU
    BCF     OPTION_REG, NOT_GPPU    ; Enable pull-ups globally
    BCF     OPTION_REG, INTEDG      ; Interrupt on falling INT edge
    banksel T1CON                   ; Configure TMR1
    CLRF    TMR1L
    CLRF    TMR1H
    MOVLW   RS_T1CON
    MOVWF   T1CON
    banksel PIE1
    BSF     PIE1, TMR1IE            ; Enable TMR1 interrupt
    banksel T1CON
    MOVLW   T24H_h                  ; Start counting 24h
    MOVWF   TH_h
    MOVLW   T24H_l
    MOVWF   TH_l

#ifdef BlinkDebug
    GOTO    CONFIGURED              ; just skip everything in debugmode
#endif

    BTFSS   Button                  ; check if a button is pressed (active low)
    GOTO    START_LEARNING          ; start learning if yes

    eeread  0x00, T_l               ; Read the timer value from EEPROM
    eeread  0x01, T_h
    COMF    T_l, W                  ; if 0xFF then test high
    BTFSS   STATUS, Z
    GOTO    CONFIGURED
    COMF    T_h, W
    BTFSS   STATUS, Z
    GOTO    CONFIGURED              ; if low !=0xFF then values in EEPROM are valid
    CLRF    T_l                     ; timer values are not configured
    CLRF    T_h

    GOTO    RUN_CYCLE               ; and die (sleep forever, act like a dumb light)

START_LEARNING
    BSF     mLearning               ; start learning
    CALL    TMR1_WAIT_BTN_REL       ; wait for the button release+debounce
    CALL    TLIGHT                  ; turn the light on

CONFIGURED
    BSF     mConfigured             ; we have a valid configuration in EEPROM
    MOVLW   RS_INTCON
    MOVWF   INTCON                  ; Enable interrupts

RUN_CYCLE
    ; do smth useful
    NOP
    banksel INTCON
    BSF     INTCON, INTE
    SLEEP
    NOP
    banksel INTCON
    BCF     INTCON, INTE

    GOTO RUN_CYCLE                  ; loop forever

;
; Subroutine for waiting the release of Button with contact debouncing
; based on the TMR1 (should be already initialized and running at 32768/8)
; === void TMR1_WAIT_BTN_REL(void)
;
TMR1_WAIT_BTN_REL
    banksel GPIO
    BTFSS   Button                  ; wait for the first button release
    GOTO    $-1
BOUNCE_AGAIN                        ; begin contact debounce seqence
    INCF    TMR1L                   ; TMR1 is already running at 32768/8, make sure it isn't 0
    CLRF    i_cycle                 ; let's use it for eliminating contact bounce
BOUNCE_DELAY
    BTFSS   Button
    INCF    i_cycle                 ; counting "0"'s per cycle
    MOVF    TMR1L, F                ; testing if the low timer is full (=0)
    BTFSS   STATUS, Z
    GOTO    BOUNCE_DELAY            ; not full, repeat counting
    MOVF    i_cycle, F              ; testing if we had at least one bounce
    BTFSS   STATUS, Z
    GOTO    BOUNCE_AGAIN            ; then wait one more cycle
    RETURN

;
; Subroutine toggles the light and saves the current state
; === void TLIGHT(void)
;
TLIGHT
    banksel GPIO
    BTFSC   mLight          ; are we on?
    GOTO    LIGHT_IS_ON     ; yes
    BSF     Light           ; no, turning on
    BSF     mLight
    RETURN
LIGHT_IS_ON
    BCF     Light           ; yes, turning off
    BCF     mLight
    RETURN



INTERRUPT
    MOVWF   W_temp          ; copy W to temp register, could be in either bank
    SWAPF   STATUS, W       ; swap status to be saved into W
    BCF     STATUS, RP0     ; change to bank 0 regardless ofcurrent bank
    MOVWF   STATUS_temp     ; save status to bank 0 register
                            ; why we are here?
    banksel PIR1
    BTFSS   PIR1, TMR1IF    ; is it TMR1?
    GOTO    BTN_INT         ; no, something else
;--- here starts TMR1 ISR
    BCF     PIR1, TMR1IF    ; yes, it is TMR1

#ifdef BlinkDebug
    CALL    TLIGHT          ; just blink
#endif

BTN_INT
    BTFSS   INTCON, INTF    ; is it INT/GP2 button?
    GOTO    OTHER_INT       ; no, something else
;--- here starts INT ISR
    BCF     INTCON, INTF    ; yes, it is INT

#ifdef BlinkDebug
;    CALL    TMR1_WAIT_BTN_REL
    CALL    TLIGHT          ; wait for the button release and toggle LED
#endif

    GOTO    EXIT_INT

OTHER_INT
    banksel PIR1
    CLRF    PIR1            ; we souldn't be here, unexpected interrupt
    BCF     INTCON, GPIF    ; clearing all IFs to avoid interrupt loop
    BCF     INTCON, T0IF
EXIT_INT
    SWAPF   STATUS_temp, W  ; swap STATUS_TEMP register into W, sets bank to original state
    MOVWF   STATUS          ; move W into STATUS register
    SWAPF   W_temp, F       ; swap W_TEMP
    SWAPF   W_temp, W       ; swap W_TEMP into W

    RETFIE

    END