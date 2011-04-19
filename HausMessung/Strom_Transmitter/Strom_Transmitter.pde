// Strom_Transmitter.pde
//
// Überwacht die Drehscheibe im Stromzähler mit einer Reflex-Lichtschranke
// und berechnet die Wattzahl
// Der Wert wird dann per Funk an einen Empfänger übermittelt
//
// (c) Dirk Melchers
// www.dirk-melchers.de

#define SERIAL_DEBUG 0
#define DO_SEND 1


#include <Ports.h>
#if DO_SEND > 0
#include <RF12.h>
#endif

#include "hausmessung.h"

#define SCHWELLWERT_IN   300
#define SCHWELLWERT_OUT  250

#define TRANSMIT_RATE   5000




Port strom (1);
Port heartbeat (2);
Port transmitter (3);

byte myId;

int heartbeat_status;            // hearbeat-LED status
int heartbeat_count;             // hearbeat-LED counter
unsigned long counter;           // number of pulse
unsigned long tx_counter;        // how much packets where sent
unsigned long last_transmit;     // time of last transmit

unsigned long watt;              // calculated Watt value
int in_pulse;                    // in "red" part now
unsigned long last_pulse;        // time of last pulse


void setup()
{
  Serial.begin(57600);	  // Debugging output

#if DO_SEND > 0
  Serial.print("\n[rfStrings]");
  myId = rf12_config();
#endif

  strom.mode(OUTPUT);
  transmitter.mode(OUTPUT);
  heartbeat.mode(OUTPUT);
}


void loop()
{
  // declare variables
  int analog_in;                   // reading of the analog input
  unsigned long time;              // now
  unsigned long timediff;          // diff between two impulses
  int send_now=0;                  // force send of data
  int can_send;                    // is RF12 ready for sending
  byte header;                     // RF12 header
  struct payload_data payload;     // RF12 payload

    // initialize
  send_now = 0;

  // Read analog input and calculate average
  analog_in=0;
  for (int i=0; i<5; i++) {
    analog_in += strom.anaRead();
  }
  analog_in = analog_in / 5;

#if SERIAL_DEBUG > 2
  Serial.print("Analog in: ");
  Serial.println(analog_in);
#endif


  if(analog_in >= SCHWELLWERT_IN && in_pulse==0) {
    strom.digiWrite(true); // Flash a light to show transmitting

    time = millis();
    timediff = time - last_pulse;

#if SERIAL_DEBUG > 0
    Serial.print("Trigger in: ");
    Serial.println(analog_in);
    Serial << "Timediff: " << timediff << "\n";
#endif


    if (last_pulse > 0 && timediff > 1000) {

      // 48000... = 1000 W h / 75 turns per KW h * 3600 (1 h) * 1000 (millis)
      watt = int( 48000000 / timediff );

      // only accept values below 20 kW
      if ( watt < 20000 ) {
#if SERIAL_DEBUG > 0
        Serial << "Calc watt: "<< watt << "last" << last_pulse << " now " << time << " diff " << timediff  << " millis\n";
#endif

        // remember "now"
        last_pulse = time;
        in_pulse = 1;
        counter = counter + 1;
        send_now = 1;
      }
      else {
        Serial << "Unsinniger Watt-Wert: " << watt << " wurde verworfen\n";
        watt = 0;
      }
    }

    // on the first run or on time overflow: only store "now", but don't send any data
    if ( last_pulse == 0 || last_pulse > time ) {
      last_pulse = time;
      in_pulse = 1;
      watt = 0;
    }

  }

#if SERIAL_DEBUG > 2
  if (in_pulse == 1) {
    Serial.print("Wert: ");
    Serial.println(analog_in);
  }
#endif

  // red part of the turning wheel is gone
  if(analog_in < SCHWELLWERT_OUT) {
    if (in_pulse) {
#if SERIAL_DEBUG > 0
      Serial.print("Trigger out: ");
      Serial.println(analog_in);
#endif
      strom.digiWrite(false);
      in_pulse = 0;
    }
  }


  // Send the "Watt" to the receiver
  transmitter.digiWrite(1);
#if DO_SEND > 0
  rf12_recvDone();
#endif
  transmitter.digiWrite(0);

#if DO_SEND > 0
  can_send = rf12_canSend();
#else
  can_send = 1;
#endif

  time = millis();
  timediff = time - last_transmit;  
  if((watt > 0) && (send_now == 1 || (timediff >= TRANSMIT_RATE)) && can_send) {
    Serial << watt << "--" << send_now << "--" << can_send << "--" << timediff << "\n";
    // Blink the Transmitter-LED
    transmitter.digiWrite(1);

    tx_counter++;

    payload.typ = 2;
    payload.id = 1;
    payload.data.strom.watt = watt;
    payload.data.strom.count = counter;
    payload.data.strom.tx_count = tx_counter;

#if SERIAL_DEBUG > 0
    Serial  << "Strom: " << payload.data.strom.watt  << ";" << payload.data.strom.count << ";"<< payload.data.strom.tx_count << "\n";
#endif

#if DO_SEND > 0
    // byte header = RF12_HDR_ACK | RF12_HDR_DST | 1;
    header = RF12_HDR_DST | 1;
    rf12_sendStart(header, &payload, sizeof payload);
#endif

    last_transmit = millis();
    send_now = 0;

    // switch of Transmitter-LED
    transmitter.digiWrite(0);
  }

  // toggle heartbeat-LED every second
  heartbeat_count++;
  if (heartbeat_count > 1000) {
    heartbeat.digiWrite(heartbeat_status);
    heartbeat_count = 0;
    heartbeat_status = not heartbeat_status;
  }
}


























