// Receiver.pde



#include <Ports.h>
#include <RF12.h>

#include "hausmessung.h"

byte myId;
Port led (1);


void setup()
{
    Serial.begin(57600);
    Serial.println("setup");

    Serial.print("\n[rfStrings]");
    myId = rf12_config();

    led.mode(OUTPUT);
}


void loop()
{

    if ( rf12_recvDone() && rf12_crc == 0 ) {
        // LED an
        led.digiWrite(1);

        struct payload_data  *data;
        data = (struct payload_data *)rf12_data;

        if (data->typ == 1) {
          float temp = (float)(data->data.temperatur.temp) / 100.00;
          Serial << "Temp;" << (int)data->id << ";" << temp  << ";" << data->data.temperatur.name << "\n";
        }

        if (data->typ == 2) {
          Serial << "Strom;WATT;" << (int)data->id << ";" << data->data.strom.watt << "\n";
        }


        if ( RF12_WANTS_ACK ) {
            rf12_sendStart(RF12_ACK_REPLY, 0, 0);
        }

        // LED wieder aus
        led.digiWrite(0);
    }
}
