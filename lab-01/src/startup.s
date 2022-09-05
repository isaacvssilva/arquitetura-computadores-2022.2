/* Clock */
.equ CM_PER_GPIO1_CLKCTRL, 0x44e000AC

/* Watch Dog Timer */
.equ WDT_BASE, 0x44E35000

/* GPIO */
.equ GPIO1_OE, 0x4804C134
.equ GPIO1_SETDATAOUT, 0x4804C194
.equ GPIO1_CLEARDATAOUT, 0x4804C190


_start:
    /* init */
    mrs r0, cpsr
    bic r0, r0, #0x1F @ clear mode bits
    orr r0, r0, #0x13 @ set SVC mode
    orr r0, r0, #0xC0 @ disable FIQ and IRQ
    msr cpsr, r0

    bl .gpio_setup
    bl .disable_wdt

.main_loop:
    /* logical 1 turns on the led, TRM 25.3.4.2.2.2 */
    ldr r0, =GPIO1_CLEARDATAOUT
    ldr r1, =(1<<21)
    str r1, [r0]

    ldr r2, =(1<<22)
    str r2, [r0]
    ldr r3, =(1<<23)
    str r3, [r0]
    ldr r4, =(1<<24)
    str r4, [r0]
    bl .delay

    ldr r0, =GPIO1_SETDATAOUT
    ldr r1, =(1<<21)
    str r1, [r0]

    ldr r2, =(1<<22)
    str r2, [r0]
    ldr r3, =(1<<23)
    str r3, [r0]
    ldr r4, =(1<<24)
    str r4, [r0]
    bl .delay

    b .main_loop    


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

    /* set pin 21 for output, led USR0, TRM 25.3.4.3 */
    ldr r0, =GPIO1_OE
    ldr r1, [r0]
    bic r1, r1, #(1<<21)
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
