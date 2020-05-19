; some 16-bit math

incf_16		macro   f_high, f_low
    INCF    f_high, f
    INCFSZ  f_low, f
    DECF    f_high, f
    endm

decf_16		macro   f_high, f_low
    MOVF    f_low, f
    skpnz
    DECF    f_high, f
    DECF    f_low, f
    endm