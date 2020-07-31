/*
 * a4.c
 *
 * Created: 2019-12-04 6:38:19 PM
 * Author : Lucas J. Antonsen
 */ 

#include <avr/io.h>
#include "CSC230.h"
#include <stdio.h>

#define  ADC_BTN_RIGHT 0x032
#define  ADC_BTN_UP 0x0C3
#define  ADC_BTN_DOWN 0x17C
#define  ADC_BTN_LEFT 0x22B
#define  ADC_BTN_SELECT 0x316

char start[] = "Lucas J AntonsenCSC 230 Fall '19";  //start message
volatile int blink = 0;                             //blink variable, fluctuates between 0 and 1
unsigned int cursor = 5;                            //cursor location on top line of LCD screen
char space = ' ';                                   //used in blinking phenomenon
unsigned int prev_button = 0;                       //previous button press
volatile unsigned int curr_button = 0;              //current button press
char d1 = '0';                                      //digit 1 (_00)
char d2 = '0';                                      //digit 2 (0_0)
char d3 = '0';                                      //digit 3 (00_)
char curr_spd = '0';                                //current speed
char mem_spd = '0';                                 //speed held in memory that can be switched to current speed via SELECT button press
volatile unsigned int count = 0;                    //count of elements in Collatz sequence as it is built
volatile long unsigned int collatz = 0;             //number used for Collatz sequence. begins as n and is altered as program progresses
unsigned int flag = 0;                              //stops program from updating collatz variable at the beginning until n is selected


//purpose: provides a blinking phenomenon at the location of the cursor
//arguments: blink (blink flag), cursor (cursor location)
//return value: none
void blink_char(){
    if(blink == 1) {
        lcd_xy(cursor, 0);
        lcd_putchar(space);
    }
    _delay_ms(15);
}

//modified from lab9_ADC_show_result.c
//purpose: checks button input
//arguments: ADCL, ADCH (LCD button input)
//return value: unsigned integer (button input)
unsigned int check_button(){
    unsigned short adc_result = 0; //16 bits
    
    ADCSRA |= 0x40;
    while((ADCSRA & 0x40) == 0x40); //Busy-wait
    
    unsigned short result_low = ADCL;
    unsigned short result_high = ADCH;
    
    adc_result = (result_high<<8)|result_low;
    
    if(adc_result < ADC_BTN_RIGHT){
        return 1;                           //right button press
    }else if(adc_result < ADC_BTN_UP){
        return 2;                           //up button press
    }else if(adc_result < ADC_BTN_DOWN){
        return 3;                           //down button press
    }else if(adc_result < ADC_BTN_LEFT){
        return 4;                           //left button press
    }else if(adc_result < ADC_BTN_SELECT){
        return 5;                           //select button press
    }else{
        return 0;                           //no button press
    }
}

//purpose: changes timer 4 count
//arguments: curr_spd (current speed)
//return value: none
void change_timer(){
    if(curr_spd == '0'){
        TIMSK4 = 0<<TOIE4;      //disable timer overflow interrupt while speed is '0'
        return;
    }else{
        TIMSK4 = 1<<TOIE4;      //otherwise enable interrupt
    }
    //set countdown value for timer
    if(curr_spd == '1'){
        TCNT4 = 0xFFFF - 977;   //1/16s
    }else if(curr_spd == '2'){
        TCNT4 = 0xFFFF - 1954;  //1/8s
    }else if(curr_spd == '3'){
        TCNT4 = 0xFFFF - 3907;  //1/4s
    }else if(curr_spd == '4'){
        TCNT4 = 0xFFFF - 7813;  //1/2s
    }else if(curr_spd == '5'){
        TCNT4 = 0xFFFF - 15625; //1.0s
    }else if(curr_spd == '6'){
        TCNT4 = 0xFFFF - 23478; //1.5s
    }else if(curr_spd == '7'){
        TCNT4 = 0xFFFF - 31250; //2.0s
    }else if(curr_spd == '8'){
        TCNT4 = 0xFFFF - 39063; //2.5s
    }else{
        TCNT4 = 0xFFFF - 46875; //3.0s
    }
}

//purpose: changes collatz value given n. sets count to 0 and flag to 1 so timer doesn't start updating anything before (*) start has been pressed
//arguments: d1 (digit 1), d2 (digit 2), d3 (digit 3), count, flag
//return value: none
void change_n(){
    collatz = 100*(d1-'0') + 10*(d2-'0') + d3-'0';
    count = 0;
    flag = 1;
}

//purpose: changes cursor location in the right direction
//arguments: cursor (cursor location)
//return value: none
void right(){
    if(cursor == 14){
        return;
    }else if(cursor == 6){
        cursor += 8;
    }else{
        cursor++;
    }   
}

//purpose: changes n, or starts sequence calculation, or changes timer speed
//arguments: cursor (cursor location), d1 (digit 1), d2 (digit 2), d3 (digit 3), curr_spd (current speed)
//return value: none
void up(){
    //change n value displayed
    if(cursor == 3){
        if (d1 == '9'){
            d1 = '0';
        }else{
            d1++;
        }   
    }else if(cursor == 4){
        if (d2 == '9'){
            d2 = '0';
        }else{
            d2++;
        }
    }else if(cursor == 5){
        if (d3 == '9'){
            d3 = '0';
        }else{
            d3++;
        }
    //start sequence calculation
    }else if(cursor == 6){
        change_n();
        return;
    //change timer speed
    }else{
        if(curr_spd == '9'){
            curr_spd = '0';
        }else{
            curr_spd++;
        }
        change_timer();
    }
}

//purpose: changes n, or starts sequence calculation, or changes timer speed
//arguments: cursor (cursor location), d1 (digit 1), d2 (digit 2), d3 (digit 3), curr_spd (current speed)
//return value: none
void down(){
    //change n value displayed
    if(cursor == 3){
        if (d1 == '0'){
            d1 = '9';
        }else{
            d1--;
        }
    }else if(cursor == 4){
        if (d2 == '0'){
            d2 = '9';
        }else{
            d2--;
        }
    }else if(cursor == 5){
        if (d3 == '0'){
            d3 = '9';
        }else{
            d3--;
        }
    //start sequence calculation
    }else if(cursor == 6){
        change_n();
        return;
    //change timer speed
    }else{
        if(curr_spd == '0'){
            curr_spd = '9';
        }else{
            curr_spd--;
        }
        change_timer();
    }
}

//purpose: changes cursor location in the left direction
//arguments: cursor (cursor location)
//return value: none
void left(){
    if(cursor == 3){
        return;
    }else if(cursor == 14){
        cursor -= 8;
    }else{
        cursor--;
    }
}

//purpose: switches current speed with memory speed
//arguments: cur_spd (current speed), mem_spd(memory speed)
//return value: none
void select(){
    char temp = curr_spd;
    curr_spd = mem_spd;
    mem_spd = temp;
    change_timer();
}

//purpose: checks current button input vs previous button input and calls associated functions involved with the given button press. sets previous button
//to current if value is not repeated, for use in button validation later
//arguments: curr_button (current button), prev_button (previous button)
//return value: none
void update_String(){
    if (curr_button == prev_button) {//|| curr_button == 0){
        return;
    }else if(curr_button == 1){
        right();
    }else if(curr_button == 2){
        up();
    }else if(curr_button == 3){
        down();
    }else if(curr_button == 4){
        left();
    }else if(curr_button == 5){
        select();
    }
    prev_button = curr_button;
    //_delay_ms(100);
}

//purpose: uses collatz conjecture to alter collatz value
//arguments: collatz (collatz value), flag, curr_spd (current speed)
//return value: none
void collatz_gen(){
    if(collatz == 1 || collatz == 0 || flag == 0 || curr_spd == '0'){
        return;
    }else if(collatz % 2 == 0){
        count++;
        collatz /=2;
    }else{
        count++;
        collatz = 3*collatz + 1;
    }
}


int main(void)
{
    ADCSRA = 0x87;
    ADMUX = 0x40;
    
    lcd_init();
    
    lcd_xy(0,0);
    lcd_puts(start);
    _delay_ms(1000);
    
    // Set up Timer 0 for blink
    TCCR1A = 0;
    TCCR1B = (1<<CS12)|(1<<CS10);   // Prescaler of 7813
    TCNT1 = 0xFFFF - 7813;          // 1/2 second
    TIMSK1 = 1<<TOIE1;
    sei();
    
    // Set up Timer 3 for check button
    TCCR3A = 0;
    TCCR3B = (1<<CS32)|(1<<CS30);   // Prescaler of 782
    TCNT3 = 0xFFFF - 782;           // 1/20 second
    TIMSK3 = 1<<TOIE3;
    sei();
    
    // Set up Timer 4 for collatz
    TCCR4A = 0;
    TCCR4B = (1<<CS42)|(1<<CS40);   // Prescaler of 46875
    TCNT4 = 0xFFFF - 46875;         // 3 seconds
    TIMSK4 = 0<<TOIE4;              //disable timer interrupt initially
    sei();
    
    char str[100];
    
    /* Replace with your application code */
    while (1) 
    {
        sprintf(str, " n=%c%c%c*   SPD:%c cnt:%3u v:%6lu", d1, d2, d3, curr_spd, count, collatz);   //create formatted string for display
        lcd_xy(0,0);
        lcd_puts(str);                                                                              //display string
        blink_char();                                                                               //set cursor location to blink/not blink
        update_String();                                                                            //handle button input and change string variables
    }
    
}


//isr's modified from lab9_LED_blink_isr.c

//timer 0 isr
//purpose: handles blinking for lcd
//arguments: TIMER1_OVF_vect, blink (blink flag)
//return value: none
ISR(TIMER1_OVF_vect) {
    // Reset the initial count
    TCNT1 = 0xFFFF - 7813;

    // Update a variable
    if(blink == 1) {
        blink--;
    }else{
        blink++;
    }
}

//timer 3 isr
//purpose: handles button input and sets curr_button for use with other functions
//arguments: TIMER3_OVF_vect
//return value: none
ISR(TIMER3_OVF_vect) {
    // Reset the initial count
    TCNT3 = 0xFFFF - 782;
    curr_button = check_button();
}

//timer 4 isr
//purpose: generates collatz sequence numbers
//arguments: TIMER4_OVF_vect
//return value: none
ISR(TIMER4_OVF_vect) {
    // Reset the initial count
    change_timer();
    collatz_gen();
}


