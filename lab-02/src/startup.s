/* Clock */
.equ CM_PER_GPIO1_CLKCTRL, 0x44e000AC
.equ CM_PER_GPIO2_CLKCTRL, 0x44E000B0

/* Watch Dog Timer */
.equ WDT_BASE, 0x44E35000

/* GPIO */
.equ GPIO1_OE,              0x4804C134
.equ GPIO1_SETDATAOUT,      0x4804C194
.equ GPIO1_CLEARDATAOUT,    0x4804C190

.equ GPIO2_OE,           0x481AC134
.equ GPIO2_DATAIN,       0x481AC138
.equ GPIO2_SETDATAOUT,   0x481AC194


/* UART BASE */
.equ UART0_BASE, 0x44E09000
.equ UART0_RHR,  0x44E09000
.equ UART0_THR,  0x44E09000
.equ UART0_LSR,  0x44E09014

/* CPSR */
.equ CPSR_I,   0x80
.equ CPSR_F,   0x40
.equ CPSR_IRQ, 0x12
.equ CPSR_USR, 0x10
.equ CPSR_FIQ, 0x11
.equ CPSR_SVC, 0x13
.equ CPSR_ABT, 0x17
.equ CPSR_UND, 0x1B
.equ CPSR_SYS, 0x1F

_start:
    /* init */
    mrs r0, cpsr
    bic r0, r0, #0x1F @ clear mode bits
    orr r0, r0, #0x13 @ set SVC mode
    orr r0, r0, #0xC0 @ disable FIQ and IRQ
    msr cpsr, r0

    bl .gpio_setup
    bl .disable_wdt
    adr r0, hello
    bl .print_string

    
/* logical 1 turns on the led, TRM 25.3.4.2.2.2 */
.main_loop:
/*contador */
    mov r2, #0
    mov r3, #0

.loop_led:
    @ a cada loop, imprime o valor atual do contador 
    bl .print_contador
    mov r0, #0x0a @ \n
    bl .uart_putc
    mov r0, #0x0d @ \r
    bl .uart_putc

    cmp r2, #15
    beq .main_loop
    add r2, #1

    @ led blink
    mov r3, r2, lsl #21
    ldr r0, =GPIO1_SETDATAOUT
    str r3, [r0]
    bl .delay

    ldr r0, =GPIO1_CLEARDATAOUT
    mov r4, #(0xF<<21)
    str r4, [r0]
    b .loop_led

    
.print_contador:
    stmfd sp!, {r0-r2, lr} @ push -> empilhando pra salvar o valor atual do contador
    mov r3, #10
    mov r0, #0
    
.divisor:
    cmp r2, r3   @ r2 > r3? 10 - r2, r0+1 -> r0 = quociente da divisao
    blt .end_div @ r2 < r3? salta para percorrer vetor ascii 
    sub r2, #10
    add r0, #1
    b .divisor
        
.end_div:
    bl .vet_char
    mov r0, r2
    bl .vet_char
    ldmfd sp!, {r0-r2, pc}

.vet_char:
    stmfd sp!, {r0-r2, lr} @ push -> empilhando pra salvar o valor atual do contador
    adr r1, ascii_vet      @ carregando endereco do vetor ascii no r1
    
.loop:
    ldrb r2, [r1], #1 @ carregando byte do vetor de r1 em r2
    sub r0, r0, #1
    cmp r0, #0
    blt .end_loop
    b .loop
    
.end_loop:
    and r2, r2, #0xFF
    mov r0, r2
    bl .uart_putc
    ldmfd sp!, {r0-r2, pc}
    

.delay:
    ldr r1, =0xfffffff
.wait:
    sub r1, r1, #0x1
    cmp r1, #0
    bne .wait
    bx lr

/********************************************************
  Registers (see TRM 20.4.4.1):
    WDT_BASE -> 0x44E35000
    WDT_WSPR -> 0x44E35048
    WDT_WWPS -> 0x44E35034
********************************************************/
.gpio_setup:
    /* set clock for GPIO1, TRM 8.1.12.1.31 */
    ldr r0, =CM_PER_GPIO1_CLKCTRL
    ldr r1, =0x40002
    str r1, [r0]

    /* set pin 21, 22, 23, 24 for output, led USR0, USR1, USR2, USR3 TRM 25.3.4.3 */
    ldr r0, =GPIO1_OE
    ldr r1, [r0]
    bic r1, r1, #(0x1<<21)
    str r1, [r0]
    
    /*setando o pino 22 como saida, led usr1 */
    ldr r2, [r0]
    bic r2, r2, #(1<<22)
    str r2, [r0]
    /*setando o pino 23 como saida, led usr2 */
    ldr r3, [r0]
    bic r3, r3, #(1<<23)
    str r3, [r0]
    /*setando o pino 23 como saida, led usr2 */
    ldr r4, [r0]
    bic r4, r4, #(1<<24)
    str r4, [r0]
    
    bx lr

/********************************************************
  WDT disable sequence (see TRM 20.4.3.8):
    1- Write XXXX AAAAh in WDT_WSPR.
    2- Poll for posted write to complete using WDT_WWPS.W_PEND_WSPR. (bit 4)
    3- Write XXXX 5555h in WDT_WSPR.
    4- Poll for posted write to complete using WDT_WWPS.W_PEND_WSPR. (bit 4)
    
  Registers (see TRM 20.4.4.1):
    WDT_BASE -> 0x44E35000
    WDT_WSPR -> 0x44E35048
    WDT_WWPS -> 0x44E35034
********************************************************/
.disable_wdt: 
    /* TRM 20.4.3.8 */
    stmfd sp!,{r0-r1,lr}
    ldr r0, =WDT_BASE
    
    ldr r1, =0xAAAA
    str r1, [r0, #0x48]
    bl .poll_wdt_write

    ldr r1, =0x5555
    str r1, [r0, #0x48]
    bl .poll_wdt_write

    ldmfd sp!,{r0-r1,pc}

.poll_wdt_write:
    ldr r1, [r0, #0x34]
    and r1, r1, #(1<<4)
    cmp r1, #0
    bne .poll_wdt_write
    bx lr
/********************************************************/


/********************************************************
UART0 PUTC (Default configuration)  
********************************************************/
.uart_putc:
    stmfd sp!,{r1-r2,lr}
    ldr r1, =UART0_BASE

.wait_tx_fifo_empty:
    ldr r2, [r1, #0x14] 
    and r2, r2, #(1<<5)
    cmp r2, #0
    beq .wait_tx_fifo_empty

    strb  r0, [r1]
    ldmfd sp!,{r1-r2,pc}


/********************************************************
Imprime uma string até o '\0'
// R0 -> Endereço da string
/********************************************************/
.print_string:
    stmfd sp!, {r0-r2, lr} //push
    mov r1, r0

.print:
    ldrb r0, [r1], #1
    and r0, r0, #0xff
    cmp r0, #0
    beq .end_print
    bl .uart_putc
    b .print

.end_print:
    ldmfd sp!, {r0-r2, pc}
/********************************************************/

hello: .asciz "hello embedded world ARM!\n\r"
    @ asciz -> definir string
    @.asciz "hello embedded world ARM!\n\r\0"
@ .global printf
ascii_vet: .asciz "0123456789abcdef"
