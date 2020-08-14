;By Lucas Antonsen

;button constants
.equ RIGHT  = 0x032 
.equ UP     = 0x0C3
.equ DOWN   = 0x17C
.equ LEFT   = 0x22B

.org 0x0000
    jmp setup

.org 0x0028
    jmp timer1_ISR  ;collatz sequence updater

.org 0x0046
    jmp timer2_ISR  ;button input handler
    
.org 0x0072

main_loop:
    call delay1             ;short delay
    call display_strings    ;display current strings
    ;call check_button      ;check button input and return a value for the press. we'll just leave it here in case our timer2_isr malfunctions
    call update_strings     ;update the strings according to the button press

    lds r16, blink      ;passing blink value via stack
    push r16
    call blink_char     ;determine if a space is necessary in our current location
    pop r16
    sts blink, r16      ;return blink value via stack and store it
    rjmp main_loop

;modified from Lab 8 - timers_interrupt.asm by Prof. Tom Arjannikov
setup:
    ; initialize the stack pointer (we are using functions!)
    ldi r16, high(RAMEND)
    out SPH, r16
    ldi r16, low(RAMEND)
    out SPL, r16

    ; initialize Analog to Digital converter
    ldi r16, 0x87
    sts ADCSRA, r16
    ldi r16, 0x40
    sts ADMUX, r16

    ;set cursor to starting position
    ldi r16, 3
    sts cursor, r16

    ;set starting values for d1, d2, d3, spd
    ldi r16, '0'
    sts d1, r16     ;_00
    sts d2, r16     ;0_0
    sts d3, r16     ;00_
    sts spd, r16    ;collatz update speed

    ;set starting values for n, n+1, n+2, cnt, start
    ldi r16, 0
    sts n, r16      ;high byte of number n
    sts n+1, r16    ;middle byte of number n
    sts n+2, r16    ;low byte of number n
    sts cnt, r16    ;count of elements in collatz sequence
    sts start, r16  ;begin collatz updates flag. set to 0 to disable initial updates until n is set via user input

    call timer1_setup       ;setup timer1
    call lcd_init           ;initialize lcd
    call lcd_clr            ;clear lcd
    call starting_strings   ;convert display name, class info from program to data memory
    call display_strings    ;display name, class info
    call main_strings       ;convert main display strings from program to data memory
    call delay              ;short delay before transitioning to main screen of collatz navigator
    call timer2_setup       ;setup timer2
    jmp main_loop

;modified from Lab 8 - timers_interrupt.asm by Prof. Tom Arjannikov
.equ TIMER1_PRESCALAR_1 = 977   ;1/16s prescaler
.equ TIMER1_PRESCALAR_2 = 1954  ;1/8s prescaler
.equ TIMER1_PRESCALAR_3 = 3907  ;1/4s prescaler
.equ TIMER1_PRESCALAR_4 = 7813  ;1/2s prescaler
.equ TIMER1_PRESCALAR_5 = 15625 ;1.0s prescaler
.equ TIMER1_PRESCALAR_6 = 23478 ;1.5s prescaler
.equ TIMER1_PRESCALAR_7 = 31250 ;2.0s prescaler
.equ TIMER1_PRESCALAR_8 = 39063 ;2.5s prescaler
.equ TIMER1_PRESCALAR_9 = 46875 ;3.0s prescaler

.equ TIMER1_MAX_COUNT = 0xFFFF  ;max count

.equ TIMER1_COUNTER_1 = TIMER1_MAX_COUNT-TIMER1_PRESCALAR_1 ;1/16s
.equ TIMER1_COUNTER_2 = TIMER1_MAX_COUNT-TIMER1_PRESCALAR_2 ;1/8s
.equ TIMER1_COUNTER_3 = TIMER1_MAX_COUNT-TIMER1_PRESCALAR_3 ;1/4s
.equ TIMER1_COUNTER_4 = TIMER1_MAX_COUNT-TIMER1_PRESCALAR_4 ;1/2s
.equ TIMER1_COUNTER_5 = TIMER1_MAX_COUNT-TIMER1_PRESCALAR_5 ;1.0s
.equ TIMER1_COUNTER_6 = TIMER1_MAX_COUNT-TIMER1_PRESCALAR_6 ;1.5s
.equ TIMER1_COUNTER_7 = TIMER1_MAX_COUNT-TIMER1_PRESCALAR_7 ;2.0s
.equ TIMER1_COUNTER_8 = TIMER1_MAX_COUNT-TIMER1_PRESCALAR_8 ;2.5s
.equ TIMER1_COUNTER_9 = TIMER1_MAX_COUNT-TIMER1_PRESCALAR_9 ;3.0s

;initializes collatz updater timer (timer 1). timer overflow interrupt is disabled until number n is set via user input
timer1_setup:
    push r16    
    ; timer mode    
    ldi r16, 0x00       ; normal operation
    sts TCCR1A, r16

    ; prescale 
    ; Our clock is 16 MHz, which is 16,000,000 per second
    ;
    ; scale values are the last 3 bits of TCCR1B:
    ;
    ; 000 - timer disabled
    ; 001 - clock (no scaling)
    ; 010 - clock / 8
    ; 011 - clock / 64
    ; 100 - clock / 256
    ; 101 - clock / 1024
    ; 110 - external pin Tx falling edge
    ; 111 - external pin Tx rising edge
    ldi r16, (1<<CS12)|(1<<CS10)    ; clock / 1024
    sts TCCR1B, r16

    ; set timer counter to TIMER1_COUNTER_9 (defined above) to start counting although we will not allow timer to interrupt initially
    ldi r16, high(TIMER1_COUNTER_9)
    sts TCNT1H, r16     ; must WRITE high byte first 
    ldi r16, low(TIMER1_COUNTER_9)
    sts TCNT1L, r16     ; low byte
    
    ; don't initially allow timer to interrupt the CPU when it's counter overflows
    ldi r16, 0<<TOV1
    sts TIMSK1, r16

    ; enable interrupts (the I bit in SREG)
    sei 
    pop r16
    ret

;sets collatz updater timer (timer 1) overflow count given speed value
change_timer:
    push r16    ;for spd, timer count
    push r17    ;for TOV1

    ;if speed is zero disable interrupt to halt collatz updates
    lds r16, spd
    cpi r16, '0'
    breq set_timer1_0

    ;enable timer interrupt if speed is not zero
    ldi r17, 1<<TOV1
    sts TIMSK1, r17

    ;we must check the value at speed and adjust accordingly
    cpi r16, '1'
    breq set_timer1_1
    cpi r16, '2'
    breq set_timer1_2
    cpi r16, '3'
    breq set_timer1_3
    cpi r16, '4'
    breq set_timer1_4
    cpi r16, '5'
    breq set_timer1_5
    cpi r16, '6'
    breq set_timer1_6
    cpi r16, '7'
    breq set_timer1_7
    cpi r16, '8'
    breq set_timer1_8
    jmp set_timer1_9

;disable interrupt
set_timer1_0:
    ldi r17, 0<<TOV1
    sts TIMSK1, r17
    jmp fin_change

; set timer counter to TIMER1_COUNTER_X (defined above)
;1/16s
set_timer1_1:
    ldi r16, high(TIMER1_COUNTER_1)
    sts TCNT1H, r16     ; must WRITE high byte first 
    ldi r16, low(TIMER1_COUNTER_1)
    sts TCNT1L, r16     ; low byte
    jmp fin_change

;1/8s
set_timer1_2:
    ldi r16, high(TIMER1_COUNTER_2)
    sts TCNT1H, r16     ; must WRITE high byte first 
    ldi r16, low(TIMER1_COUNTER_2)
    sts TCNT1L, r16     ; low byte
    jmp fin_change

;1/4s
set_timer1_3:
    ldi r16, high(TIMER1_COUNTER_3)
    sts TCNT1H, r16     ; must WRITE high byte first 
    ldi r16, low(TIMER1_COUNTER_3)
    sts TCNT1L, r16     ; low byte
    jmp fin_change

;1/2s
set_timer1_4:
    ldi r16, high(TIMER1_COUNTER_4)
    sts TCNT1H, r16     ; must WRITE high byte first 
    ldi r16, low(TIMER1_COUNTER_4)
    sts TCNT1L, r16     ; low byte
    jmp fin_change

;1.0s
set_timer1_5:
    ldi r16, high(TIMER1_COUNTER_5)
    sts TCNT1H, r16     ; must WRITE high byte first 
    ldi r16, low(TIMER1_COUNTER_5)
    sts TCNT1L, r16     ; low byte
    jmp fin_change

;1.5s
set_timer1_6:
    ldi r16, high(TIMER1_COUNTER_6)
    sts TCNT1H, r16     ; must WRITE high byte first 
    ldi r16, low(TIMER1_COUNTER_6)
    sts TCNT1L, r16     ; low byte
    jmp fin_change

;2.0s
set_timer1_7:
    ldi r16, high(TIMER1_COUNTER_7)
    sts TCNT1H, r16     ; must WRITE high byte first 
    ldi r16, low(TIMER1_COUNTER_7)
    sts TCNT1L, r16     ; low byte
    jmp fin_change

;2.5s
set_timer1_8:
    ldi r16, high(TIMER1_COUNTER_8)
    sts TCNT1H, r16     ; must WRITE high byte first 
    ldi r16, low(TIMER1_COUNTER_8)
    sts TCNT1L, r16     ; low byte
    jmp fin_change

;3.0s
set_timer1_9:
    ldi r16, high(TIMER1_COUNTER_9)
    sts TCNT1H, r16     ; must WRITE high byte first 
    ldi r16, low(TIMER1_COUNTER_9)
    sts TCNT1L, r16     ; low byte

fin_change:
    pop r17
    pop r16
    ret

; modified from Lab 8 - timers_interrupt.asm
; by Prof. Tom Arjannikov
; timer interrupt flag is automatically
; cleared when this ISR is executed
; per page 168 ATmega datasheet.
;
; handles collatz updating when timer 1 overflows
timer1_ISR:
    push r16
    lds r16, SREG
    push r16

    ;avoid collatz update if speed is zero
    lds r16, spd
    cpi r16, '0'        
    breq done_timer

    ;avoid collatz update if start flag not set. prevents collatz function from updating initial value of n before n is selected via user input
    lds r16, start
    cpi r16, 0
    breq done_timer

    ;avoid collatz update if digits = '000'
    lds r16, d1
    cpi r16, '0'
    brne calls
    lds r16, d2
    cpi r16, '0'
    brne calls
    lds r16, d3
    cpi r16, '0'
    breq done_timer
    
calls:
    call change_timer   ;reset timer
    call collatz        ;update n via collatz conjecture

done_timer:
    pop r16
    sts SREG, r16
    pop r16
    reti

;updates collatz number's integer value (n) and the sequence count
collatz:
    push r16
    push r17
    push r18
    push r19
    push r20
    push r21
    push r22

    lds r18, n      ;load high byte of n
    lds r17, n+1    ;load middle byte of n
    lds r16, n+2    ;load low byte of n
    lds r19, cnt    ;load collatz sequence count

;check if n = 0. if so then n does not require an update

;check if high byte is 0
check_high:
    cpi r18, 0
    breq check_med
    jmp collatz_op

;check if med byte is 0
check_med:
    cpi r17, 0      
    breq check_low
    jmp collatz_op

;check if low byte is 0
check_low:
    cpi r16, 0
    breq collatz_done

;check if low byte is 1. if so then no longer need to update n
    cpi r16, 1
    breq collatz_done

;perform collatz conjecture operations
collatz_op:

    ;increment collatz sequence count
    inc r19
    sts cnt, r19

    bst r16, 0      ;sets T flag to 1 if first bit is set (nl is odd), else 0 if cleared (nl is even)
    brtc divby2     ;branches to divby2 if T flag is cleared (0), continues if set (1)

    ;n is odd so n = 3n + 1

    mov r22, r18    ;copy n high to r22
    mov r21, r17    ;copy n med to r21
    mov r20, r16    ;copy n low to r20
    add r16, r16    ;add low byte of n to itself (ie. 2n)
    adc r17, r17    ;add med byte of n to itself (ie. 2n)
    adc r18, r18    ;add high byte of n to itself (ie. 2n)

    add r16, r20    ;add low byte of n again (ie. 3n)
    adc r17, r21    ;add med byte of n again (ie. 3n)
    adc r18, r22    ;add high byte of n again (ie. 3n)

    ldi r19, 1      ;we'll use r19 as a temp variable given that we are done with it's count value
    add r16, r19    ;3n+1
    clr r19         ;r19 = 0 for carry
    adc r17, r19
    adc r18, r19

    jmp collatz_done

;n is even so n = n/2
divby2:
    lsr r18         ;n = n/2
    ror r17
    ror r16

;store n
collatz_done:
    sts n, r18
    sts n+1, r17
    sts n+2, r16

    pop r22
    pop r21
    pop r20
    pop r19
    pop r18
    pop r17
    pop r16
    ret

;modified from Lab 8 - timers_interrupt.asm by Prof. Tom Arjannikov
.equ TIMER2_PRESCALAR = 782 ;1/20s prescalar
.equ TIMER2_COUNTER = TIMER1_MAX_COUNT-TIMER2_PRESCALAR ;1/20s

;initializes button input timer (timer 2)
timer2_setup:
    push r16    
    ; timer mode    
    ldi r16, 0x00       ; normal operation
    sts TCCR3A, r16

    ; prescale 
    ; Our clock is 16 MHz, which is 16,000,000 per second
    ;
    ; scale values are the last 3 bits of TCCR3B:
    ;
    ; 000 - timer disabled
    ; 001 - clock (no scaling)
    ; 010 - clock / 8
    ; 011 - clock / 64
    ; 100 - clock / 256
    ; 101 - clock / 1024
    ; 110 - external pin Tx falling edge
    ; 111 - external pin Tx rising edge
    ldi r16, (1<<CS32)|(1<<CS30)    ; clock / 1024
    sts TCCR3B, r16

    ; set timer counter to TIMER2_COUNTER (defined above) to start counting
    ldi r16, high(TIMER2_COUNTER)
    sts TCNT3H, r16     ; must WRITE high byte first 
    ldi r16, low(TIMER2_COUNTER)
    sts TCNT3L, r16     ; low byte
    
    ; allow timer to interrupt the CPU when it's counter overflows
    ldi r16, 1<<TOV3
    sts TIMSK3, r16

    ; enable interrupts (the I bit in SREG)
    sei 
    pop r16
    ret

;modified from Lab 8 - timers_interrupt.asm by Tom Arjannikov
;handles button input
timer2_ISR:
    push r16
    lds r16, SREG
    push r16

    ldi r16, high(TIMER2_COUNTER)
    sts TCNT3H, r16     ; must WRITE high byte first 
    ldi r16, low(TIMER2_COUNTER)
    sts TCNT3L, r16     ; low byte

    call check_button

    pop r16
    sts SREG, r16
    pop r16
    reti

;modified from Lab 8 - init_strings ~ timers_interrupt.asm by Prof. Tom Arjannikov
;copies start message strings from program memory to data memory
starting_strings:
    push r16

    ; copy start1 from program memory to data memory (line1)
    ldi r16, high(line1)        ; address of the destination string in data memory
    push r16
    ldi r16, low(line1)
    push r16
    ldi r16, high(start1 << 1)  ; address the source string in program memory
    push r16
    ldi r16, low(start1 << 1)
    push r16
    call str_init   ; copy from program to data
    pop r16         ; remove the parameters from the stack
    pop r16
    pop r16
    pop r16

    ; copy start2 from program memory to data memory (line2)
    ldi r16, high(line2)        ; address of the destination string in data memory
    push r16
    ldi r16, low(line2)
    push r16
    ldi r16, high(start2 << 1)  ; address the source string in program memory
    push r16
    ldi r16, low(start2 << 1)
    push r16
    call str_init   ; copy from program to data
    pop r16         ; remove the parameters from the stack
    pop r16
    pop r16
    pop r16

    pop r16
    ret

;modified from Lab 8 - init_strings ~ timers_interrupt.asm by Prof. Tom Arjannikov
;copies main screen strings from program to data memory
main_strings:
    push r16

    ; copy start1 from program memory to data memory (line1)
    ldi r16, high(line1)        ; address of the destination string in data memory
    push r16
    ldi r16, low(line1)
    push r16
    ldi r16, high(line1_p << 1) ; address the source string in program memory
    push r16
    ldi r16, low(line1_p << 1)
    push r16
    call str_init   ; copy from program to data
    pop r16         ; remove the parameters from the stack
    pop r16
    pop r16
    pop r16

    ; copy start2 from program memory to data memory (line2)
    ldi r16, high(line2)        ; address of the destination string in data memory
    push r16
    ldi r16, low(line2)
    push r16
    ldi r16, high(line2_p << 1) ; address the source string in program memory
    push r16
    ldi r16, low(line2_p << 1)
    push r16
    call str_init   ; copy from program to data
    pop r16         ; remove the parameters from the stack
    pop r16
    pop r16
    pop r16

    ; copy cnt_p from program memory to data memory (cnt_str)
    ldi r16, high(cnt_str)      ; address of the destination string in data memory
    push r16
    ldi r16, low(cnt_str)
    push r16
    ldi r16, high(cnt_p << 1)   ; address the source string in program memory
    push r16
    ldi r16, low(cnt_p << 1)
    push r16
    call str_init   ; copy from program to data
    pop r16         ; remove the parameters from the stack
    pop r16
    pop r16
    pop r16

    ; copy v_p from program memory to data memory (v_str)
    ldi r16, high(v_str)        ; address of the destination string in data memory
    push r16
    ldi r16, low(v_str)
    push r16
    ldi r16, high(v_p << 1)     ; address the source string in program memory
    push r16
    ldi r16, low(v_p << 1)
    push r16
    call str_init   ; copy from program to data
    pop r16         ; remove the parameters from the stack
    pop r16
    pop r16
    pop r16

    pop r16
    ret

;modified from Lab 8 - timers_interrupt.asm by Prof. Tom Arjannikov
;displays message on LCD
display_strings:

    ; This subroutine sets the position the next
    ; character will be on the lcd
    ;
    ; The first parameter pushed on the stack is the Y (row) position
    ; 
    ; The second parameter pushed on the stack is the X (column) position
    ; 
    ; This call moves the cursor to the top left corner (ie. 0,0)
    ; subroutines used are defined in lcd.asm in the following lines:
    ; The string to be displayed must be stored in the data memory
    ; - lcd_clr at line 661
    ; - lcd_gotoxy at line 589
    ; - lcd_puts at line 538
    push r16

    ;call lcd_clr

    ; first line of lcd
    ldi r16, 0x00
    push r16
    ldi r16, 0x00
    push r16
    call lcd_gotoxy
    pop r16
    pop r16

    ; Now display line1 on the first line
    ldi r16, high(line1)
    push r16
    ldi r16, low(line1)
    push r16
    call lcd_puts
    pop r16
    pop r16

    ;second line of lcd
    ldi r16, 0x01
    push r16
    ldi r16, 0x00
    push r16
    call lcd_gotoxy
    pop r16
    pop r16

    ; Now display line2 on the second line
    ldi r16, high(line2)
    push r16
    ldi r16, low(line2)
    push r16
    call lcd_puts
    pop r16
    pop r16

    pop r16
    ret

;checks button input and returns an integer corresponding to the button press
check_button:
    push r16
    push r17
    push r18
    push r19
    push r20

;start a2d conversion
    lds r16, ADCSRA   ; get the current value of SDRA
    ori r16, 0x40     ; set the ADSC bit to 1 to initiate conversion
    sts ADCSRA, r16

; wait for A2D conversion to complete
wait:
    lds r16, ADCSRA
    andi r16, 0x40     ; see if conversion is over by checking ADSC bit
    brne wait          ; ADSC will be reset to 0 if finished

    ; read the value available as 10 bits in ADCH:ADCL
    lds r17, ADCL
    lds r18, ADCH

; checks the values from ADCL, ADCH
checkright:
    cpi r17, low(RIGHT)
    ldi r19, high(RIGHT)
    cpc r18, r19
    brlo loadright

checkup:
    cpi r17, low(UP)
    ldi r19, high(UP)
    cpc r18, r19
    brlo loadup

checkdown:
    cpi r17, low(DOWN)
    ldi r19, high(DOWN)
    cpc r18, r19
    brlo loaddown

checkleft:
    cpi r17, low(LEFT)
    ldi r19, high(LEFT)
    cpc r18, r19
    brlo loadleft
    jmp loadnone

;loads the button press value into curr_button
loadright:
    ldi r20, 1
    sts curr_button, r20
    jmp skip

loadup:
    ldi r20, 2
    sts curr_button, r20
    jmp skip

loaddown:
    ldi r20, 3
    sts curr_button, r20
    jmp skip

loadleft:
    ldi r20, 4
    sts curr_button, r20
    jmp skip

;no button press
loadnone:
    ldi r20, 0
    sts curr_button, r20

skip:
    pop r20
    pop r19
    pop r18
    pop r17
    pop r16
    ret

;updates main display message given button input
update_strings:
    push r16
    push r17
    ;push r18
    push r19
    push r20
    push ZH
    push ZL
    push YH
    push YL

;checks if buttons are being held down. functions branches if the curr_button is the same as prev_button
check_prev:
    lds r16, prev_button
    lds r17, curr_button
    cp r16, r17
    breq no_change
    sts prev_button, r17

; here we check button presses againsts various conditions involving position and content
; cursor index:     1234       5
; values:       " n=000*   SPD:0 "

;check button press 
check_press:
    cpi r17, 1
    breq press_right
    cpi r17, 2
    breq press_up
    cpi r17, 3
    breq press_down
    cpi r17, 4
    breq press_left
    ;curr_button = 0 so no action
    jmp update

;conducts operations related to a right push
press_right:
    call right_func
    jmp update

;conducts operations related to a up push
press_up:
    call up_func
    jmp update

;conducts operations related to a down push
press_down:
    call down_func
    jmp update

;conducts operations related to a left push
press_left:
    call left_func
    jmp update

;prev_button = curr_button
no_change:
    ;ldi r18, 0             ;commented out as it was messing with the inputs, re-add if issues arise
    ;sts prev_button, r18

update:
    ;line1 update
    ldi ZH, high(line1+3)
    ldi ZL, low(line1+3)

    lds r19, d1
    st Z+, r19      ;update d1's corresponding location on line1 (" n=_00*   SPD:0 ")

    lds r19, d2
    st Z+, r19      ;update d2's corresponding location on line1 (" n=0_0*   SPD:0 ")

    lds r19, d3
    st Z+, r19      ;update d3's corresponding location on line1 (" n=00_*   SPD:0 ")

    ldi r19, '*'
    st Z, r19       ;update asterisk just in case the space from blink overwrote it (" n=000_   SPD:0 ")

    adiw Z, 8
    lds r19, spd    ;update spd's corresponding location on line1 (" n=000*   SPD:_ ")
    st Z, r19

    ;check if start flag set. if not, then go to finish and avoid updating line 2
    lds r16, start
    cpi r16, 0
    breq finish

    ;check if digits = '000'. avoid updating line 2 as n = 0 is invalid
    lds r16, d1
    cpi r16, '0'
    brne line2update
    lds r16, d2
    cpi r16, '0'
    brne line2update
    lds r16, d3
    cpi r16, '0'
    breq finish

;line2 update
;when updating fill everything with spaces then update with int values 
;or update with cnt:"_ _ 0" and v:"_ _ _ _ _ 0"
;v is the count'th number in the collatz sequence (n)
line2update:

    ;convert cnt and v to a string
    call integer_to_string
    
    ;add cnt to line 2
    ldi YH, high(cnt_str)
    ldi YL, low(cnt_str)

    ldi ZH, high(line2+4)
    ldi ZL, low(line2+4)

    ldi r20, 3  ;for the 3 digits of count

loop1:
    cpi r20, 0  ;loop 3 times (the max number of digits for count), each time copying an element from the count string
    breq add_v
    ld r19, Y+;
    st Z+, r19
    dec r20
    jmp loop1

;add v to line 2
add_v:
    ldi YH, high(v_str)
    ldi YL, low(v_str)
    adiw Z, 3

    ldi r20, 6  ;for the 6 digits of v

loop2:
    cpi r20, 0  ;loop 6 times (the max number of digits for v), each time copying an element from the v string
    breq finish
    ld r19, Y+
    st Z+, r19
    dec r20
    jmp loop2
    
finish:
    pop YL
    pop YH
    pop ZL
    pop ZH
    pop r20
    pop r19
    ;pop r18
    pop r17
    pop r16
    ret

;modifies main display message given right button press
;right button press = 1
right_func:
    push r16

    lds r16, cursor ;load cursor value
    cpi r16, 5      ;compare cursor value. if cursor equals 5 (spd value) then do nothing
    breq invalid_r  
    inc r16         ;else increment cursor location
    sts cursor, r16

invalid_r:
    pop r16
    ret

;modifies main display message given up button press
;up button press = 2
up_func:
    push r16
    push r17

    lds r16, cursor ;load cursor value
    cpi r16, 1
    breq check_d1_up;digit 1: x _ _ * _
    cpi r16, 2
    breq check_d2_up;digit 2: _ x _ * _
    cpi r16, 3
    breq check_d3_up;digit 3: _ _ x * _
    cpi r16, 4
    breq start_up   ;digit 4: _ _ _ x _ start collatz sequence with new initial value n=d1d2d3
    ;only other cursor location left is 5
    jmp check_spd_up;digit 5: _ _ _ * x change speed for collatz updates

;cursor = 1 for d1
check_d1_up:
    lds r17, d1         ;1st digit of number
    cpi r17, '9'
    breq load_zero_d1   ;digit 1 is 9 so we will replace it with 0
    inc r17             ;otherwise increment the digit value
return_d1_up:
    sts d1, r17
    jmp up_done

load_zero_d1:
    ldi r17, '0'
    jmp return_d1_up    ;go back to store d1

;cursor = 2 for d2
check_d2_up:
    lds r17, d2         ;2nd digit of number
    cpi r17, '9'
    breq load_zero_d2   ;digit 2 is 9 so we will replace it with 0
    inc r17             ;otherwise increment the digit value
return_d2_up:
    sts d2, r17
    jmp up_done

load_zero_d2:
    ldi r17, '0'
    jmp return_d2_up    ;go back to store d2

;cursor = 3 for d3
check_d3_up:
    lds r17, d3         ;3rd digit of number
    cpi r17, '9'
    breq load_zero_d3   ;digit 3 is 9 so we will replace it with 0
    inc r17             ;otherwise increment the digit value
return_d3_up:
    sts d3, r17
    jmp up_done

load_zero_d3:
    ldi r17, '0'
    jmp return_d3_up    ;go back to store d3

;cursor = 4 for *
start_up:
    ;check if digits = '000'. if so, avoid go_up as n = 0 is invalid
    lds r16, d1
    cpi r16, '0'
    brne go_up
    lds r16, d2
    cpi r16, '0'
    brne go_up
    lds r16, d3
    cpi r16, '0'
    brne go_up
    jmp up_done

;initializes new n value
go_up:
    call display_first      ;copies initial count (0) and digits to line 2
    call display_strings    ;display main message
    call delay              ;short delay

    ldi r17, 1
    sts cnt, r17    ;initialize count to 1 for new number n
    sts start, r17  ;set start flag to 1 so collatz can update n as soon as spd > 0
    
    call change_n   ;change n integer held in memory
    
    jmp up_done

;cursor = 5 for spd
check_spd_up:
    lds r17, spd        ;speed of collatz updates
    cpi r17, '9'
    breq load_zero_spd  ;speed is 9 so we will replace it with 0
    inc r17             ;otherwise increment the digit value
return_spd_up:
    sts spd, r17
    call change_timer   ;change timer count to reflect current speed
    jmp up_done

load_zero_spd:
    ldi r17, '0'
    jmp return_spd_up   ;go back to store speed

up_done:
    pop r17
    pop r16
    ret

;modifies main display message given down button press
;down button press = 3
down_func:
    push r16
    push r17

    lds r16, cursor ;load cursor value
    cpi r16, 1
    breq check_d1_down;digit 1: x _ _ * _
    cpi r16, 2
    breq check_d2_down;digit 2: _ x _ * _
    cpi r16, 3
    breq check_d3_down;digit 3: _ _ x * _
    cpi r16, 4
    breq start_down ;digit 4: _ _ _ x _ start collatz sequence with new initial value n=d1d2d3
    ;only other cursor location left is 5
    jmp check_spd_down;digit 5: _ _ _ * x change speed for updating collatz updates

;cursor = 1 for d1
check_d1_down:
    lds r17, d1         ;1st digit of number
    cpi r17, '0'
    breq load_nine_d1   ;digit 1 is 9 so we will replace it with 0
    dec r17             ;otherwise increment the digit value
return_d1_down:
    sts d1, r17
    jmp down_done

load_nine_d1:
    ldi r17, '9'
    jmp return_d1_down  ;go back to store d1

;cursor = 2 for d2
check_d2_down:
    lds r17, d2         ;2nd digit of number
    cpi r17, '0'
    breq load_nine_d2   ;digit 2 is 9 so we will replace it with 0
    dec r17             ;otherwise increment the digit value
return_d2_down:
    sts d2, r17
    jmp down_done

load_nine_d2:
    ldi r17, '9'
    jmp return_d2_down  ;go back to store d2

;cursor = 3 for d3
check_d3_down:
    lds r17, d3         ;3rd digit of number
    cpi r17, '0'
    breq load_nine_d3   ;digit 3 is 9 so we will replace it with 0
    dec r17             ;otherwise increment the digit value
return_d3_down:
    sts d3, r17
    jmp down_done

load_nine_d3:
    ldi r17, '9'
    jmp return_d3_down  ;go back to store d3

;cursor = 4 for *
start_down:
    ;check if digits = '000'. if so, avoid go_up as n = 0 is invalid
    lds r16, d1
    cpi r16, '0'
    brne go_down
    lds r16, d2
    cpi r16, '0'
    brne go_down
    lds r16, d3
    cpi r16, '0'
    brne go_down
    jmp down_done

;initializes new n value
go_down:
    call display_first      ;copies initial count (0) and digits to line 2
    call display_strings    ;display main message
    call delay              ;short delay

    ldi r17, 1
    sts cnt, r17        ;initialize count to 1 for new number n
    sts start, r17      ;set start flag to 1 so collatz can update n as soon as spd > 0
    
    call change_n       ;change n integer held in memory
    
    jmp down_done

;cursor = 5 for spd
check_spd_down:
    lds r17, spd        ;speed of collatz updates
    cpi r17, '0'
    breq load_nine_spd  ;speed is 9 so we will replace it with 0
    dec r17             ;otherwise decrement the digit value
return_spd_down:
    sts spd, r17
    call change_timer
    jmp down_done

load_nine_spd:
    ldi r17, '9'
    jmp return_spd_down ;go back to store speed

down_done:
    pop r17
    pop r16
    ret

;modifies main display message given left button press
;left button press = 4
left_func:
    push r16

    lds r16, cursor ;load cursor value
    cpi r16, 1      ;compare cursor value. if cursor equals 1 (spd value) then do nothing
    breq invalid_l  
    dec r16         ;else decrement cursor location
    sts cursor, r16

invalid_l:
    pop r16
    ret

;converts digits from ASCII to binary integer n
change_n:
    push r16 ;initially d3, then used as the low-byte
    push r17 ;initially d2,then used as the medium-byte (carry over)
    push r18 ;initially d1, then used as the high-byte (which will be zero since max digits value '999' requires only two bytes)
    push r19 ;temp variable
    push r20 ;temp variable
    push r21 ;temp variable 0 for add carry
    push ZH
    push ZL

    ;load digits in string format
    lds r16, d3
    lds r17, d2
    lds r18, d1
    ldi r19, 0x30

    ;check if digits are '0' and clear corresponding registers if so
    ;else convert digits from ASCII to binary by subtracting '0'
    cpi r16, '0'
    breq d1zero
    sub r16, r19

d2ascii:
    cpi r17, '0'
    breq d2zero
    sub r17, r19

d3ascii:
    cpi r18, '0'
    breq d3zero
    sub r18, r19
    jmp convert

d1zero:
    clr r16
    jmp d2ascii

d2zero:
    clr r17
    jmp d3ascii

d3zero:
    clr r18

;integer conversion step
convert:
    ldi r19, 0xA    ;load 10 to r19
    mov r20, r17    ;copy digit 2 to r20

multiply_d2:
    cpi r20, 0      ;check if digit 2 is 0. if so, skip add 10 step
    brne add10      ;go and add 10 to lower byte of integer n

    ldi r19, 0x64   ;load 100 to r19
    clr r17         ;clr r17 so we can use it for the medium byte of integer n
    mov r20, r18    ;copy digit 3 to r20
    ldi r21, 0      ;load 0 for add carry
    ;clz

multiply_d3:
    cpi r20, 0      ;check if digit 3 is 0. if so, skip add 100 step and store integer n
    brne add100
    jmp store_n

add10:
    add r16, r19    ;add 10 to low byte of n. r16 contains lowest digit number in n (00_) and will be what we add to
    dec r20         ;decrement r20. when r20 is zero the first two digits have been entered into integer n
    jmp multiply_d2

add100:
    add r16, r19    ;add 100 to last digit of n. r16 is the low byte of integer n
    adc r17, r21    ;add carry to medium byte of n
    dec r20         ;decrement r20. when r20 is zero every digit has been entered into n
    jmp multiply_d3

store_n:
    ldi ZH, high(n) ; initialize Z to point to n
    ldi ZL, low(n)
    clr r18         ; clear high byte of n as it's zero
    st Z+, r18      ; store n in Big-Endian format
    st Z+, r17
    st Z, r16

    pop ZL
    pop ZH
    pop r21
    pop r20
    pop r19
    pop r18
    pop r17
    pop r16
    ret

;displays bottom line with initial count and digits (with spaces in front if necessary. v = n) before collatz updates
display_first:
    push r16    ;d1
    push r17    ;d2
    push r18    ;d3
    push r19    ;temp

    ;set line 2 to ' cnt:  0 v:   xxx' (x has yet to be set)
    ldi r16, ' '
    sts line2+4, r16
    sts line2+5, r16
    sts line2+10, r16
    sts line2+11, r16
    sts line2+12, r16
    ldi r16, '0'
    sts line2+6, r16

    lds r16, d1
    lds r17, d2
    lds r18, d3
    
    ;set leading '0's to space
    ;else set digit on line 2 and r19 to 1 as flag and fill in following digits

    cpi r16, '0'
    brne set_d1
    ldi r16, ' '
    sts line2+13, r16
    jmp digit2

set_d1:
    sts line2+13, r16
    ldi r19, 1

digit2:
    cpi r19, 1
    breq set_d2
    cpi r17, '0'
    brne set_d2
    ldi r17, ' '
    sts line2+14, r17
    jmp set_d3

set_d2:
    sts line2+14, r17
    ldi r19, 1

set_d3:
    sts line2+15, r18   ;always set line 2 to ' cnt:  0 v:   yyx' (y is ' ' or a digit, x is d3) regardless of flag

done_digits:
    pop r19
    pop r18
    pop r17
    pop r16
    ret

;converts collatz number from binary integer to ASCII (with spaces in front if necessary)
integer_to_string:
    push r16    ;temp variable
    push r18    ;low byte of number
    push r19    ;med byte of number
    push r20    ;high byte of number
    push r21
    push YH
    push YL

    ldi YH, high(v_str) ;create v_str first. pointer used in send_char to add to string
    ldi YL, low(v_str)
    lds r20, n          ;n high
    lds r19, n+1        ;n med
    lds r18, n+2        ;n low

next:
;referring to a 6 digit number
digit_1:
    ldi r16, $2F    ;this is the '0' character less one
    
count100k:
    inc r16         ;counts instances of 100,000
    subi r18, $A0 
    sbci r19, $86 
    sbci r20, $01
    brcc count100k  ;if the number is greater than 100,000 continue subtracting. basically branches until the carry is cleared 
    subi r18, $60   ;add 100,000 (via 2's complement;-(-100,000)) once this process is complete to the negative of our number to          
    sbci r19, $79   ;return the number minus all the 100,000s
    sbci r20, $FE
    sts tempr, r16  ;tempr is resulting ASCII character
    call send_char  ;send 100,000 character

digit_2:
    ldi r16, $2F    ;this is the '0' character less one
     
count10k:
    inc r16         ;counts instances of 10,000 
    subi r18, $10 
    sbci r19, $27 
    sbci r20, $00
    brcc count10k 
    subi r18, $F0   ;-(-10,000) = +10,000. return number minus all 100,000's and 10,000's
    sbci r19, $D8
    sbci r20, $FF
    sts tempr, r16
    call send_char  ;send 10,000 character

digit_3:
    ldi r16, $2F 

count1k:  
    inc r16         ;counts instances of 1,000 
    subi r18, $E8 
    sbci r19, $03 
    sbci r20, $00
    brcc count1k 
    subi r18, $18   ;-(-1000) = +1,000. return number minus all 100,000's, 10,000's and 1,000's
    sbci r19, $FC
    sbci r20, $FF
    sts tempr, r16
    call send_char  ;send 1,000 character

digit_4:
    ldi r16, $2F

count100: 
    inc r16         ;counts instances of 100 
    subi r18, $64 
    sbci r19, $00
    sbci r20, $00
    brcc count100
    subi r18, $9C   ;-(-100) = +100. return number minus all 100,000's, 10,000's, 1,000's and 100's
    sbci r19, $FF
    sbci r20, $FF
    sts tempr, r16
    call send_char  ;send 100 character

digit_5:
    ldi r16, $2F

count10:  
    inc r16         ;counts instances of 10
    subi r18, $0A
    brcc count10  
    subi r18, $F6   ;-(-10) = +10. return number minus all 100,000's, 10,000's, 1,000's, 100's and 10's
    sts tempr, r16
    call send_char  ;send 10 character
    mov r16, r18    ;copy low byte to r16 for final step

digit_6:
    subi r16, $D0   ;convert 1's digit to ASCII via 2's complement
    sts tempr, r16
    call send_char  ;send 1 character

;convert count integer to ASCII
    cpi r21, 1
    breq fin_str

    ldi r16, 0
    sts flag, r16           ;clear flag. flag = 1 indicates all following '0's after a nonzero character must be set to '0' rather than to ' '
    ldi YH, high(cnt_str)   ;point Y to count string
    ldi YL, low(cnt_str)
    clr r20                 ;cnt high
    clr r19                 ;cnt med
    lds r18, cnt            ;cnt low
    inc r21                 ;set r21 to 1 to skip this step on following pass
    jmp digit_4

fin_str:
    ldi r16, 0
    sts flag, r16   ;clear flag for next conversion
    pop YL
    pop YH
    pop r21
    pop r20
    pop r19
    pop r18
    pop r16 
    ret

;stores ASCII character from integer_to_string in corresponding string
send_char:
    push r16
    push r17

    lds r16, tempr  ;ASCII character
    lds r17, flag   ;trailing zeros flag (indicates whether to replace '0' with ' ' or not)

    cpi r17, 1
    breq setchar    ;set character if flag is 1
    cpi r16, '0'
    brne setflag    ;set flag if character is not '0' and flag is not set
    ldi r16, ' '
    jmp setchar     ;else set '0' to ' '

setflag:
    ldi r17, 1
    sts flag, r17

setchar:
    st Y+, r16      ;set character to Y location chosen via integer_to_string

    pop r17
    pop r16
    ret

;blink function returns a space in our cursor location if our toggle (blink) = 1, else the location will remain the same. blink is toggled each time
blink_char:
    .set OFFSET = 6
    push r16
    push r17
    push ZH
    push ZL
    push YH
    push YL

    in ZH, SPH  ;point Z to stack pointer
    in ZL, SPL

    adiw Z, SP_OFFSET+OFFSET+1  ;adjust Z to point to blink value on stack

    ld r16, Z
    cpi r16, 1      ;check if toggle is 0 or 1
    brne toggle0

    ldi YH, high(line1)
    ldi YL, low(line1)
    ldi r16, ' '

    lds r17, cursor ;load cursor value
    cpi r17, 1
    breq blink_d1   ;digit 1: x _ _ * _
    cpi r17, 2
    breq blink_d2   ;digit 2: _ x _ * _
    cpi r17, 3
    breq blink_d3   ;digit 3: _ _ x * _
    cpi r17, 4
    breq blink_ast  ;digit 4: _ _ _ x _
    ;only other cursor location left is 5
    jmp blink_spd   ;digit 5: _ _ _ *

blink_d1:
    adiw Y, 3
    st Y, r16
    jmp toggle1
    
blink_d2:
    adiw Y, 4
    st Y, r16
    jmp toggle1

blink_d3:
    adiw Y, 5
    st Y, r16
    jmp toggle1
    
blink_ast:
    adiw Y, 6
    st Y, r16
    jmp toggle1

blink_spd:
    adiw Y, 14
    st Y, r16
    jmp toggle1

;toggle 0 to 1
toggle0:
    ldi r16, 1
    st Z, r16       ;changes bottom value on stack
    jmp blink_done

;toggle 1 to 0
toggle1:
    clr r16
    st Z, r16       ;changes bottom value on stack
    jmp blink_done

blink_done:
    pop YL
    pop YH
    pop ZL
    pop ZH
    pop r17
    pop r16
    ret
;remember to always update asterisk in line1

;modified from Lab 8 - timers_interrupt.asm by Prof. Tom Arjannikov
; Function that delays for a period of time using busy-loop
delay:
    push r20
    push r21
    push r22
    ; Nested delay loop
    ldi r20, 0x50   ;use 50 for first delay
x1:
        ldi r21, 0xFF
x2:
            ldi r22, 0xFF
x3:
                dec r22
                brne x3
            dec r21
            brne x2
        dec r20
        brne x1

    pop r22
    pop r21
    pop r20
    ret 

;modified from Lab 8 - timers_interrupt.asm by Prof. Tom Arjannikov
; Function that delays for a period of time (shorter than delay) using busy-loop
delay1:
    push r20
    push r21
    push r22
    ; Nested delay loop
    ldi r20, 0x10   ;use 10 for first delay
xx1:
        ldi r21, 0xFF
xx2:
            ldi r22, 0xFF
xx3:
                dec r22
                brne xx3
            dec r21
            brne xx2
        dec r20
        brne xx1

    pop r22
    pop r21
    pop r20
    ret 

start1:     .db "Lucas J Antonsen", 0, 0    ;top line of start message
start2:     .db "CSC 230 Fall '19", 0, 0    ;bottom line of start message
line1_p:    .db " n=000*   SPD:0 ", 0, 0    ;top line of main message
line2_p:    .db "cnt:  0 v:     0", 0, 0    ;bottom line of main message
cnt_p:      .db "  0", 0                    ;count string
v_p:        .db "     0", 0, 0              ;current collatz sequence number (n) string

.dseg
line1:  .byte 17    ;string. top line of main message
line2:  .byte 17    ;string. bottom line of main message
d1:     .byte 1     ;string. 1st digit (_00) of n set via user input
d2:     .byte 1     ;string. 2nd digit (0_0) of n set via user input
d3:     .byte 1     ;string. 3rd digit (00_) of n set via user input
spd:    .byte 1     ;string. speed of collatz updates set via user input
blink:  .byte 1     ;integer. blink parameter
cursor: .byte 1     ;integer. cursor location
prev_button: .byte 1;integer. previous button press
curr_button: .byte 1;integer. current button press
n:      .byte 3     ;integer. Big-Endian format. n value in collatz sequence
cnt:    .byte 1     ;integer. count of elements in collatz sequence
v_str:  .byte 6     ;string. string version of n
cnt_str:.byte 3     ;string. string version of count
tempr:  .byte 1     ;string. ASCII version of integer
flag:   .byte 1     ;integer. trailing zeros flag for integer to string conversions
start:  .byte 1     ;integer. start flag for collatz updates

#define LCD_LIBONLY
.include "lcd.asm"
