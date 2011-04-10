// Strom_Transmitter.pde
//
// Überwacht die Drehscheibe im Stromzähler mit einer Reflex-Lichtschranke
// und berechnet die Wattzahl
// Der Wert wird dann per Funk an einen Empfänger übermittelt
//
// (c) Dirk Melchers
// www.dirk-melchers.de

#include <Ports.h>
#include <RF12.h>

#include "hausmessung.h"

#define SCHWELLWERT_IN   300
#define SCHWELLWERT_OUT  250
#define TRANSMIT_RATE   1000

#define REFLEX_DEBUG 1


unsigned long watt = 0;
unsigned long counter=0;

unsigned long last_pulse=0;
unsigned long time=0;

unsigned long last_transmit = 0;
unsigned long tx_counter=0;


Port strom (1);
byte myId;
int insend=0;


void setup()
{
    Serial.begin(57600);	  // Debugging output

    Serial.print("\n[rfStrings]");
    myId = rf12_config();

    strom.mode(OUTPUT);
}

struct payload_data payload;

void loop()
{

    int a;
    unsigned long timediff;

    // Read analog input and calculate average
    a=0;
    for (int i=0; i<5; i++) {
      a += strom.anaRead();
    }
    a = a/5;
    // Serial.println(a);

    if(a >= SCHWELLWERT_IN && insend==0) {

        #if REFLEX_DEBUG > 0
            Serial.print("In: ");
            Serial.println(a);
            strom.digiWrite(true); // Flash a light to show transmitting
        #endif

        time = millis();
        timediff = time - last_pulse;
        Serial << "Timediff: " << timediff << "\n";
        if (last_pulse > 0 && timediff > 1000) {

            // 48000... = 1000 W h / 75 turns per KW h * 3600 (1 h) * 1000 (millis)
            watt = int(48000000/timediff);

            // only accept values below 15kw
            if (watt < 15000) {
                #if REFLEX_DEBUG > 0
                    Serial << "Calc watt: "<< watt << "last" << last_pulse << " now " << time << " diff " << timediff  << " millis\n";
                #endif

                // remember "now"
                last_pulse = time;
                insend = 1;
                counter = counter + 1;
            }
            else {
              Serial << "Unsinniger Watt-Wert: " << watt << " wurde verworfen\n";
              watt = 0;
            }
      }

      // on the first run: only store "now", but don't send any data
      if (last_pulse == 0 || last_pulse > time) {
        last_pulse = time;
        insend = 1;
      }

    }

    #if REFLEX_DEBUG > 2
        if (insend == 1) {
            Serial.print("Wert: ");
            Serial.println(a);
        }
    #endif

    // red part of the turning wheel is gone
    if(a < SCHWELLWERT_OUT) {
        #if REFLEX_DEBUG > 0
            if (insend) {
                Serial.print("Out: ");
                Serial.println(a);
            }
            strom.digiWrite(false);
        #endif
        insend = 0;
    }


    // Send the "Watt" to the receiver
    rf12_recvDone();
    if((watt > 0) && (millis() - last_transmit >= TRANSMIT_RATE) && rf12_canSend()) {

        // Blink the LED
        strom.digiWrite(1);

        tx_counter++;

        payload.typ = 2;
        payload.id = 1;
        payload.data.strom.watt = watt;
        payload.data.strom.count = counter;
        payload.data.strom.tx_count = tx_counter;

        Serial  << "Strom: " << payload.data.strom.watt  << ";" << payload.data.strom.count << ";"<< payload.data.strom.tx_count << "\n";

        byte header = RF12_HDR_ACK | RF12_HDR_DST | 1;
        rf12_sendStart(header, &payload, sizeof payload);
        rf12_sendWait(0);

        last_transmit = millis();

        // sleep a little and switch of LED
        delay(10);
        strom.digiWrite(0);
    }

    // a little delay
    delay(10);
}
