// receiver.pde
//
// Simple example of how to use VirtualWire to receive messages
// Implements a simplex (one-way) receiver with an Rx-B1 module
//
// See VirtualWire.h for detailed API docs
// Author: Mike McCauley (mikem@open.com.au)
// Copyright (C) 2008 Mike McCauley
// $Id: receiver.pde,v 1.3 2009/03/30 00:07:24 mikem Exp $

#include <Ports.h>
#include <RF12.h>

byte myId;
Port led (1);

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
    Serial.begin(57600);
    Serial.println("setup");

    Serial.print("\n[rfStrings]");
    myId = rf12_config();

    led.mode(OUTPUT);
}

unsigned long watt;
unsigned long count;
unsigned long time;
unsigned long txcounter;
int id;

float temp;
char name[100];

void loop()
{

    if ( rf12_recvDone() && rf12_crc == 0 ) {
        // LED an
        led.digiWrite(1);

        char *buf;
        buf = (char *)rf12_data;
        buf[rf12_len] = 0;

        Serial << "# INPUT:" << buf << "\n";
        id = -1;

        // Strom?
        sscanf((char *)buf, "Strom;%d;%lu;%lu;%lu;%lu", &id, &watt, &count, &time, &txcounter);
        if ( id != -1) {
            //Serial << "# Strom :" << (char *)buf << ":\n";
            Serial << "STROM;WATT;" << id << ";" << watt  << "\n";
            Serial << "STROM;COUNT;" << id << ";" << count << "\n";
            Serial << "STROM;TIME;" << id << ";" << time  << "\n";
            Serial << "STROM;TXCOUNT;" << id << ";" << txcounter  << "\n";
        } 

     
        id=-1;
        // Strom?
        sscanf((char *)buf, "Temp;%d;%.2f;%s", &id, &temp, &name) ;
        if (id != -1) {
            //Serial << "# Temp :" << (char *)buf << ":\n";
            Serial << "Temp;" << id << ";" << temp  << ";" << name << "\n";
        }
        
        if ( RF12_WANTS_ACK ) {
            rf12_sendStart(RF12_ACK_REPLY, 0, 0);
        }

        // LED wieder aus
        led.digiWrite(0);
    }
}
