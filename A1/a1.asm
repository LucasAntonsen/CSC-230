;
; CSC 230: Assignment 1
;  
; YOUR NAME GOES HERE: Lucas Antonsen
;	Date: Sept 23/19
;
; Template by Prof. Tom Arjannikov
;
; This program generates each number in the Collatz sequence and stops at 1. 
; It retrieves the number at which to start the sequence from data memory 
; location labeled "input", then counts how many numbers there are in the 
; sequence (by generating them) and stores the resulting count in data memory
; location labeled "output". For more details see the related PDF on conneX.
;
; Input:
;  (input) Positive integer with which to start the sequence (8-bit).
;
; Output: 
;  (output) Number of items in the sequence as 16-bit little-endian integer.
;
; The code provided below already contains the labels "input" and "output".
; In the AVR there is no way to automatically initialize data memory, therefore
; the code that initializes data memory with values from program memory is also
; provided below.
;
.cseg
.org 0
	ldi ZH, high(init<<1)		; initialize Z to point to init
	ldi ZL, low(init<<1)
	lpm r0, Z+					; get the first byte
	sts input, r0				; store it in data memory
	lpm r0, Z					; get the second byte
	sts input+1, r0				; store it in data memory
	clr r0

;*** Do not change anything above this line ***

;****
; YOUR CODE GOES HERE:
;
.def countl = r16	;set low byte of count to r16
.def counth = r17	;set high byte of count to r17
.def nl = r18		;set low byte of n to r18
.def nh = r19		;set high byte of n to r19
.def templ = r20	;for incrementing low byte
.def temph = r21	;covers carry instance (r21 = 0)
	
	ldi templ, 1	;for incrementing

	lds nl, input	;load low byte of input to nl
	lds nh, input+1 ;load high byte of input to nh

count:
	add countl, templ	;adds 1 to countl
	adc counth, temph	;in the case of a carry (temph = 0)

compare:
	cpi nh, 0		;check if nh is 0
	breq checknl	;to check if nl is 1

collatz:
	bst nl, 0			;sets T flag to 1 if first bit is set (nl is odd), else 0 if cleared (nl is even)
	brtc divby2			;branches to divby2 if T flag is cleared (0), continues if set (1)

	movw r22:r23, nl:nh	;copy nl,nh to r22,r23 so they can be added later as the 3rd n in n = 3n + 1
	add nl, nl			;add low byte of n (2nd n added in n = 3n + 1)
	adc nh, nh			;add high byte of n
	add nl, r22			;add low byte of n again (3rd n added in n = 3n + 1)
	adc nh, r23			;add high byte of n again
	add nl, templ		;add 1 to n (for n = 3n + 1)
	adc nh, temph		;in the case of a carry			;
	jmp count			;go back to count to increment count and then check if n = 1 in compare

checknl:
	cpi nl, 1		;check if nl is 1
	breq complete	;if n is 1 go to store countl, counth in output, output+1 respectively
	jmp collatz		;else go to collatz to follow procedure

divby2:
	lsr nh			;n = n/2
	ror nl			
	jmp count		;go back to count to increment count and then check if n = 1 in compare

complete:	sts output, countl	;stores countl, counth in output, output+1 respectively and goes to done statement
	sts output+1, counth
;
; YOUR CODE FINISHES HERE
;****

;*** Do not change anything below this line ***

done:	jmp done

; This is the constant for initializing the "input" data memory location
; Note that program memory must be specified in double-bytes (words).
init:	.db 0x07, 0x00

; This is in the data memory segment (i.e. SRAM)
; The first real memory location in SRAM starts at location 0x200 on
; the ATMega 2560 processor. Locations below 0x200 are reserved for
; memory addressable registers and I/O
;
.dseg
.org 0x200
input:	.byte 2
output:	.byte 2
