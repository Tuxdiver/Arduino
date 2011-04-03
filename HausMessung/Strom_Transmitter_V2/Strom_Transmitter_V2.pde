// transmitter_v2.pde
//
// Überwacht die Drehscheibe im Stromzähler mit einer Reflex-Lichtschranke
// und berechnet die Wattzahl
// Der Wert wird dann per Funk an einen Empfänger übermittelt
//
// (c) Dirk Melchers
// www.dirk-melchers.de

#include <VirtualWire.h>

#define SCHWELLWERT_IN 55
#define SCHWELLWERT_OUT 40
#define TRANSMIT_RATE 1000

#define REFLEX_DEBUG 1
#define VIRTUAL_WIRE 4

// no-cost stream operator as described at 
// http://sundial.org/arduino/?page_id=119
template<class T>
inline Print &operator <<(Print &obj, T arg)
{ 
  obj.print(arg); 
  return obj; 
}


void setup()
{
  Serial.begin(9600);	  // Debugging only
  Serial.println("setup");

  // Initialise the IO and ISR
  vw_set_ptt_inverted(true); // Required for DR3100
  vw_set_tx_pin(VIRTUAL_WIRE);
  vw_setup(2000);	 // Bits per sec
}


unsigned long watt = 0;
unsigned long counter=0;

unsigned long last_pulse=0;
unsigned long time=0;

unsigned long last_transmit = 0;
unsigned long tx_counter=0;


int insend=0;
uint8_t txbuf[100];

void loop()
{

  int a;
  int b;

  a = analogRead(0);
  b = map(a,0,1024,0,256);

  if(b >= SCHWELLWERT_IN && insend==0) { 
    Serial.print("In: ");
    Serial.println(b);

#if REFLEX_DEBUG > 0
    digitalWrite(13, true); // Flash a light to show transmitting
#endif

    time = millis();
    if (last_pulse > 0 && last_pulse + 10 < time) {
      // 1000 / 75 * 3600 * 1000

      watt = int(48000000/(time - last_pulse));
      Serial << "Calc watt: "<< watt << "last" << last_pulse << " now " << time << " diff " << time - last_pulse  << " millis\n";

      last_pulse = time;
      insend = 1;
      counter = counter + 1;

    }
    if (last_pulse == 0 || last_pulse > time) {
      last_pulse = time;
      insend = 1;
    }
  }

#if REFLEX_DEBUG > 0
  if (insend == 1) {
    Serial.print("Wert: ");
    Serial.println(b);
  }
#endif 

  if(b < SCHWELLWERT_OUT && insend==1) {
    Serial.print("Out: ");
    Serial.println(b);
#if REFLEX_DEBUG > 0
    digitalWrite(13, false);
#endif 
    insend = 0;
  }

  // Send the "Watt" to the receiver
  if((watt > 0) && (millis() - last_transmit >= TRANSMIT_RATE) ) {
    tx_counter++;
    sprintf((char *)txbuf,"%lu;%lu;%lu;%lu",watt,counter,time,tx_counter);
    Serial.print("Transmit: ");
    Serial.println((char*)txbuf);
    vw_send((uint8_t *)txbuf, strlen((char *)txbuf)+1);
    vw_wait_tx(); // Wait until the whole message is gone
    last_transmit = millis();
  }

 delay(10);
}














