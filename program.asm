

        JMP MAIN            ; 0x0000 - reset vektor

        ;.org direktiva ekvivalent
        CMP R0, R0
        CMP R0, R0
        CMP R0, R0
        CMP R0, R0
        CMP R0, R0
        CMP R0, R0
        CMP R0, R0
        CMP R0, R0
        CMP R0, R0
        CMP R0, R0
        CMP R0, R0
        CMP R0, R0
        CMP R0, R0
        CMP R0, R0

        JMP ISR             ; 0x0010 - irq vektor

MAIN:
        LOAD R1, #304        ; pocetna x koordinata (centar ekrana 640/2-16)
        LOAD R2, #224         ; pocetna y koordinata (480/2-16)
        STORE R1, [0xF000]     ; GFX_X
        STORE R2, [0xF001]     ; GFX_Y
        LOAD R3, #255
        STORE R3, [0xF002]     ; GFX_COLOR = belo
        LOAD R4, #1
        STORE R4, [0xF003]     ; GFX_CMD = 1, iscrtaj pocetni kvadrat

        LOAD R5, #3
        STORE R5, [0xF020]     ; irq_mask = 0b11, dozvoli IRQ0 i IRQ1

LOOP:
        JMP LOOP              ; glavni program samo ceka prekide

ISR:
        PUSH R0
        PUSH R1
        PUSH R2

        LOAD R0, [0xF010]      ; kbd_data, 0=gore 1=dole 2=levo 3=desno

        CMP R0, #2
        BEQ ISR_LEFT
        CMP R0, #3
        BEQ ISR_RIGHT
        CMP R0, #0
        BEQ ISR_UP
        CMP R0, #1
        BEQ ISR_DOWN
        JMP ISR_ACK

ISR_LEFT:
        LOAD R1, [0xF000]
        LOAD R2, #4
        SUB R1, R2
        STORE R1, [0xF000]
        JMP ISR_REDRAW

ISR_RIGHT:
        LOAD R1, [0xF000]
        LOAD R2, #4
        ADD R1, R2
        STORE R1, [0xF000]
        JMP ISR_REDRAW

ISR_UP:
        LOAD R1, [0xF001]
        LOAD R2, #4
        SUB R1, R2
        STORE R1, [0xF001]
        JMP ISR_REDRAW

ISR_DOWN:
        LOAD R1, [0xF001]
        LOAD R2, #4
        ADD R1, R2
        STORE R1, [0xF001]
        JMP ISR_REDRAW

ISR_REDRAW:
        LOAD R1, #1
        STORE R1, [0xF003]     ; gfx_cmd = 1  pomeri (obrisi staru, iscrtaj novu)

ISR_ACK:
        LOAD R1, #1
        STORE R1, [0xF022]     ; irq_ack bit0  potvrdi obradjeni irq0

        POP R2
        POP R1
        POP R0
        RTI
