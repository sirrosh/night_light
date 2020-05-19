; EEPROM macros

eeread  macro   e_addr, e_data      ; Read EEPROM macro (literal, register)
    MOVLW   e_addr
    banksel EEADR
    MOVWF   EEADR
    BSF     EECON1, RD
    MOVFW   EEDATA
    banksel e_data
    MOVWF   e_data
    endm
