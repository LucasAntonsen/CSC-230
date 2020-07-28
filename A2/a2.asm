;
;CSC 230: Assignment 2
;  
;Lucas Antonsen
;Date: Oct 6/19
;
;
;Pascal's Triangle
;
.cseg
;board v1.1
.equ RIGHT	= 0x032 
.equ UP	    = 0x0C3
.equ DOWN	= 0x17C
.equ LEFT	= 0x22B

.def button = r16		;stores button response
.def portlnumber = r17	;stores portl output
.def portbnumber = r18	;stores portb output
.def row = r19			;i location in array
.def col = r20			;j location in array


;initialize pascal's triangle as an array in xram. r21 = position in array, r22 = X-pointer, r23 = Y-pointer
pascal:
	ldi r21, 1	;defines the location of our Y-pointer (position 1 {A[0]})

	ldi XH, high(arraydata)		;points to the undefined byte before A[0]
	ldi XL, low(arraydata)
	ldi YH, high(arraydata+1)	;points to A[0]
	ldi YL, low(arraydata+1)
	ldi ZH, high(arraydata+11)	;points to A[10]
	ldi ZL, low(arraydata+11)

	st Y, r21	;load starting 1 of pascal's triangle to A[0]

fill:
	ld r22, X+		;loads adjacent elements in array and increments X and Y-pointer's
	ld r23, Y+
	add r22, r23	;adds elements
	st Z+, r22		;stores addition of X and Y elements in Z-pointer address 10 elements ahead
					;of Y-pointer (A[r23+10]). if elements at X and Y are empty, then 0 is stored

	inc r21			;increments position to track movement through array
	cpi r21, 91		;compare to see if we have completed filling the 9 rows after the 1st. position 91 (A[90])
					;is 10 elements behind of the Z-pointer at position 101 (A[100])
	breq initialize	;break when finished and go to initialize for Analog to Digital converter
	jmp fill		;else loop back and continue filling the array


;initialize Analog to Digital converter. r21 = temp
initialize:
	ldi r21, 0x87
	sts ADCSRA, r21
	ldi r21, 0x40
	sts ADMUX, r21

;initialize PORTB and PORTL for ouput
	ldi	r21, 0b00001010
	out DDRB, r21
	ldi	r21, 0b10101010 
	sts DDRL, r21

;load values of starting position for i, j
	ldi row, 0
	ldi col, 0


main_loop:
	call loadvalue		;loads value in current A[i][j] location
	call display		;displays value at A[i][j] location
	call check_button   ;check to see if a button is pressed
	call adjustindex	;adjusts A[i][j] location accordingly
	call delay			;delay before displaying new A[i][j] value
	rjmp main_loop      ;go back to main loop to load and display new value


;loads our current A[i][j] location value into r23. r21 = temp, r22 = max row, r23 = value, r24 = low byte of multiplied number, r25 = high byte of multiplied number
loadvalue:
	ldi r21, 0					;temp number
	ldi r22, 10					;for max row = 10
	ldi YH, high(arraydata+1)	;points to A[0]
	ldi YL, low(arraydata+1)
	mul row, r22				;multiply row by 10 to get correct row position
	movw r24:r25, r0:r1			;copy over result to r24, r25
	add r24, col				;add column value to row position to get current A[i][j] position
	adc r25, r21
	add YL, r24					;adjust Y pointer to reflect A[i][j] position
	adc YH, r25
	ld r23, Y					;load value at A[i][j]
	ret


;mapping for external arduino output
;
;binary ex: 0b 1 0 1 0 1 0 1 0
;bit order	   7 6 5 4 3 2 1 0
;
;led mapping
;
;port l:		42 44 46 48
;bit in number:	 7  5  3  1
;dec value:    128 32  8  2
;
;port b:		50 52
;bit in number:	 3  1
;dec value:		 8  2

;displays current value in on the led from the A[i][j] location. r21 = temp, r23 = number from load value
display:
	ldi portlnumber, 0
	ldi portbnumber, 0

bit0check:
	bst r23, 0			;sets T flag to 1 if bit is set, else 0 if cleared
	brts ldbit0			;branches to ldbit0 if T flag is cleared (0), continues if set (1)
						;all bitxcheck's below follow this logic
bit1check:
	bst r23, 1
	brts ldbit1

bit2check:
	bst r23, 2
	brts ldbit2

bit3check:
	bst r23, 3
	brts ldbit3

bit4check:
	bst r23, 4
	brts ldbit4

bit5check:
	bst r23, 5
	brts ldbit5
	jmp turnon		;done checking bits, go to turn on LED

;load LED bits corresponding to our number by adding to portl and portb numbers
loadbits:

ldbit0:
	ldi r21, 128			;position definition
	add portlnumber, r21
	jmp bit1check			;continue checking bits of number

ldbit1:
	ldi r21, 32		
	add portlnumber, r21
	jmp bit2check

ldbit2:
	ldi r21, 8		
	add portlnumber, r21
	jmp bit3check

ldbit3:
	ldi r21, 2		
	add portlnumber, r21
	jmp bit4check

ldbit4:
	ldi r21, 8		
	add portbnumber, r21
	jmp bit5check

ldbit5:
	ldi r21, 2		
	add portbnumber, r21

;display number on LED
turnon:
	sts PORTL, portlnumber  ;turn on LED on given pin
	out PORTB, portbnumber	;turn on LED on given pin
	ret


;checks button press. r21 = temp, r22 = ADCL, r23 = ADCH
check_button:
; start a2d conversion
	lds	r21, ADCSRA	  ; get the current value of SDRA
	ori r21, 0x40     ; set the ADSC bit to 1 to initiate conversion
	sts	ADCSRA, r21

	; wait for A2D conversion to complete
wait:
	lds r21, ADCSRA
	andi r21, 0x40     ; see if conversion is over by checking ADSC bit
	brne wait          ; ADSC will be reset to 0 is finished

	; read the value available as 10 bits in ADCH:ADCL
	lds r22, ADCL
	lds r23, ADCH


;for testing
;.def lowbyte = r16
;.def highbyte = r17
;ldi r22, 0x6C	;low byte
;ldi r23, 0x01	;high byte

ldi r21, 0

;check values of ADCL, ADCH against button constants to conclude which button was pressed
checkright:
	cpi r22, low(RIGHT)		;check value against right button constant
	ldi r21, high(RIGHT)
	cpc r23, r21
	brlo loadright			;branch to loadright if value is within constant range
							;all checkdirection's below follow same logic
checkup:
	cpi r22, low(UP)
	ldi r21, high(UP)
	cpc r23, r21
	brlo loadup

checkdown:
	cpi r22, low(DOWN)
	ldi r21, high(DOWN)
	cpc r23, r21
	brlo loaddown

checkleft:
	cpi r22, low(LEFT)
	ldi r21, high(LEFT)
	cpc r23, r21
	brlo loadleft
	jmp loadnone			;outside of range, no button input

;load corresponding value of button press
loadright:
	ldi button, 1
	jmp skip

loadup:
	ldi button, 2
	jmp skip

loaddown:
	ldi button, 3
	jmp skip

loadleft:
	ldi button, 4
	jmp skip

;no button input
loadnone:
	ldi button, 5

skip:	
	ret


;adjusts A[i][j] location given valid input
adjustindex:

	cpi button, 1	;right press
	breq moveright

	cpi button, 2	;up press
	breq moveup

	cpi button, 3	;down press
	breq movedown

	cpi button, 4	;left press
	breq moveleft

	cpi button, 5	;no press
	jmp jmpback		;exit function

moveright:
	cp row, col		;check if row, column are equal. if so we cannot move right
	breq jmpback
	inc col			;else increment column value
	jmp jmpback

moveup:
	cp row, col		;check if row, column are equal. if so we cannot move up
	breq jmpback
	dec row			;else decrement row value
	jmp jmpback

movedown:
	cpi row, 9		;check if row is at max value. if so we cannot move down
	breq jmpback
	inc row			;else increment row value
	jmp jmpback

moveleft:
	cpi col, 0		;check if column is at min value. if so we cannot move left
	breq jmpback
	dec col			;else decrement column value
	jmp jmpback

jmpback:
	ret


;short delay before loading new or old value in array. r21 = temp, r22 = temp2, r23 = temp3
delay:
	; Nested delay loop
	ldi r21, 0x10
x1:
		ldi r22, 0xFF
x2:
			ldi r23, 0xFF
x3:
				dec r23
				brne x3
			dec r22
			brne x2
		dec r21
		brne x1
	ret

.dseg
.org 0x200
arraydata:	.byte 101