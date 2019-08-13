/* Theremin Test / Omar Ben Romdhane
 *2019 Sofrecom Tunisie
 * Therremin avec un Oscillator TTL 4MHz
 * Timer1 pour mesurer la frequence
 * Timer2 for gate time
 */
 //******************************************************************
#include <Stdio.h>
#define cbi(sfr, bit) (_SFR_BYTE(sfr) &= ~_BV(bit))
#define sbi(sfr, bit) (_SFR_BYTE(sfr) |= _BV(bit))
//******************************************************************


//******************************************************************
int pinLed = 13;                 
int pinFreq = 5;
//******************************************************************


//******************************************************************
//! Macro pour vider Timer/Counter1 interrupt flags.
#define CLEAR_ALL_TIMER1_INT_FLAGS    (TIFR1 = TIFR1)
//******************************************************************



//******************************************************************
void setup()
{
  pinMode(pinLed, OUTPUT);      //  digital pin comme un output
  pinMode(pinFreq, INPUT);
  pinMode(8, OUTPUT);           // pour les les hauts parleurs

  Serial.begin(57600);        // connection  serial port

  // hardware counter parametrage ( Voir atmega168.pdf chapter 16-bit counter1)
  TCCR1A=0;                   // reseter timer/counter1 control register A
  TCCR1B=0;                   // reseter timer/counter1 control register A
  TCNT1=0;                    // counter value = 0
  
  sbi (TCCR1B ,CS10);         
  sbi (TCCR1B ,CS11);
  sbi (TCCR1B ,CS12);

  // timer2 setup / est utilisé pour la génération de mesure de fréquence
  // timer 2 presaler set to 256 / timer 2 clock = 16Mhz / 256 = 62500 Hz
  cbi (TCCR2B ,CS20);
  sbi (TCCR2B ,CS21);
  sbi (TCCR2B ,CS22);

  //Config timer2 to CTC Mode
  cbi (TCCR2A ,WGM20);
  sbi (TCCR2A ,WGM21);
  cbi (TCCR2B ,WGM22);
  OCR2A = 124;                  // CTC at top of OCR2A / timer2 interrupt quand coun val est a OCR2A val

  // interrupt controles

  sbi (TIMSK2,OCIE2A);          // activer Timer2 Interrupt

}

volatile byte i_tics;
volatile byte f_ready ;
volatile byte mlt ;
unsigned int ww;

int cal;
int cal_max;

char st1[32];
long freq_in;
long freq_zero;
long freq_cal;

unsigned int dds;
int tune;

int cnt=0;

void loop()
{
  cnt++;
  // add=analogRead(0);

  f_meter_start();

  tune=tune+1;
  while (f_ready==0) {            // attend pour une fin periode (100ms) de interrupt
    PORTB=((dds+=tune) >> 15);    //  connecter H-P à portb.0 = arduino pin8
  }
 tune = freq_in-freq_zero;

  // startup
  if (cnt==10) {
    freq_zero=freq_in;
    freq_cal=freq_in;
    cal_max=0;
    Serial.print("** START **");
  }

  // auto-calibration
  if (cnt % 20 == 0) {   // essayer auto-calibrate apres n cycles
    Serial.print("*");
    if (cal_max <= 2) {
      freq_zero=freq_in;
      Serial.print(" calibration");
    }
    freq_cal=freq_in;
    cal_max=0;
    Serial.println("");
  }
  cal = freq_in-freq_cal;
  if ( cal < 0) cal*=-1;  // val abso
  if (cal > cal_max) cal_max=cal;

  digitalWrite(pinLed,1);  // autor LED blink
  Serial.print(cnt);
  Serial.print("  "); 

  if ( tune < 0) tune*=-1;  //  val abso
   sprintf(st1, " %04d",tune);
  Serial.print(st1);
  Serial.print("  "); 

  Serial.print(freq_in);
  Serial.print("  ");
/*
  Serial.print(freq_zero);
  Serial.print("  ");
  Serial.print(cal_max);
*/
  Serial.println("");
  digitalWrite(pinLed,0);

}
//******************************************************************
void f_meter_start() {
  f_ready=0;                      // reseter period de mesure flag
  i_tics=0;                        // reseter interrupt counter
  sbi (GTCCR,PSRASY);              // reseter presacler counting
  TCNT2=0;                         // timer2=0
  TCNT1=0;                         // Counter1 = 0
  cbi (TIMSK0,TOIE0);              // dissactiver Timer0 encore // millis et delay
  sbi (TIMSK2,OCIE2A);             // activer Timer2 Interrupt
  TCCR1B = TCCR1B | 7;             //  Counter Clock source = pin T1 , commencer counting maint
}

//******************************************************************
// Timer2 Interrupt Service est activer par hardware Timer2 every 2ms = 500 Hz
//  16Mhz / 256 / 125 / 500 Hz

ISR(TIMER2_COMPA_vect) {

  if (i_tics==50) {         
                            
    TCCR1B = TCCR1B & ~7;   
    cbi (TIMSK2,OCIE2A);    
    sbi (TIMSK0,TOIE0);     
    f_ready=1;              

                            
    freq_in=0x10000 * mlt;  
    freq_in += TCNT1;       
    mlt=0;

  }
  i_tics++;                 
  if (TIFR1 & 1) {          
    mlt++;                  
    sbi(TIFR1,TOV1);        // vider Timer/Counter 1 overflow flag
  }

}
