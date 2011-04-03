// transmitter_v2.pde
//
// Überwacht die Drehscheibe im Stromzähler mit einer Reflex-Lichtschranke
// und berechnet die Wattzahl
// Der Wert wird dann per Funk an einen Empfänger übermittelt
//
// (c) Dirk Melchers
// www.dirk-melchers.de
#include <Ports.h>
#include <RF12.h>
#include <util/crc16.h>
#include <util/parity.h>
#include <avr/eeprom.h>
#include <avr/pgmspace.h>

#define SCHWELLWERT_IN 80
#define SCHWELLWERT_OUT 65
#define TRANSMIT_RATE 1000

#define REFLEX_DEBUG 1
#define COLLECT 0x20 // collect mode, i.e. pass incoming without sending acks

Port strom (1);
// Utility class to fill a buffer with string data

class PacketBuffer : 
public Print {
public:
  PacketBuffer () : 
  fill (0) {
  }

  const byte* buffer() { 
    return buf; 
  }
  byte length() { 
    return fill; 
  }
  void reset() { 
    fill = 0; 
  }
  const char* print() { 
    buf[fill]=0; 
    return (char *)buf;
  }

  virtual void write(uint8_t ch)
  { 
    if (fill < sizeof buf) buf[fill++] = ch; 
  }

private:
  byte fill, buf[RF12_MAXDATA];
};


byte myId;



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
  Serial.begin(57600);	  // Debugging only
  Serial.println("setup");

  Serial.print("\n[rfStrings]");
  myId = rf12_config();
  strom.mode(OUTPUT);
}


unsigned long watt = 0;
unsigned long counter=0;

unsigned long last_pulse=0;
unsigned long time=0;

unsigned long last_transmit = 0;
unsigned long tx_counter=0;


PacketBuffer payload;   // temp buffer to send out

int insend=0;


void loop()
{

  int a;
  int b;
  unsigned long timediff;

  a = strom.anaRead();
  b = map(a,0,1024,0,256);
  //   Serial.println(b);

  if(b >= SCHWELLWERT_IN && insend==0) { 
    Serial.print("In: ");
    Serial.println(b);

#if REFLEX_DEBUG > 0
    strom.digiWrite(true); // Flash a light to show transmitting
#endif

    time = millis();
    timediff = time - last_pulse;
    Serial << "Timediff: " << timediff << "\n";
    if (last_pulse > 0 && timediff > 1000) {

      // 48000... = 1000 / 75 * 3600 * 1000
      watt = int(48000000/timediff);
      if (watt < 15000) { 
        Serial << "Calc watt: "<< watt << "last" << last_pulse << " now " << time << " diff " << timediff  << " millis\n";

        last_pulse = time;
        insend = 1;
        counter = counter + 1;
      } 
      else {
        Serial << "Unsinniger Watt-Wert: " << watt << " wurde verworfen\n";
        watt = 0;
      }
    }

    // beim ersten Lauf die aktuelle Zeit nehmen, aber keinen Wert ausgeben
    if (last_pulse == 0 || last_pulse > time) {
      last_pulse = time;
      insend = 1;
    }
  }

#if REFLEX_DEBUG > 2
  if (insend == 1) {
    Serial.print("Wert: ");
    Serial.println(b);
  }
#endif 

  if(b < SCHWELLWERT_OUT) {
    if (insend) {
      Serial.print("Out: ");
      Serial.println(b);
    }
#if REFLEX_DEBUG > 0
    strom.digiWrite(false);
#endif 
    insend = 0;
  }

  rf12_recvDone();
  // Send the "Watt" to the receiver
  if((watt > 0) && (millis() - last_transmit >= TRANSMIT_RATE) && rf12_canSend()) {
    strom.digiWrite(1);
    tx_counter++;

    payload.reset();
    payload << "Strom" << ";"<< 1 << ";" << watt << ";" << counter << ";" << time << ";" << tx_counter;
    Serial << "Transmit: " << payload.print() << "\n";

    byte header = RF12_HDR_ACK;

    header |= RF12_HDR_DST | 1;
    rf12_sendStart(header, payload.buffer() , payload.length());
    rf12_sendWait(0);

    last_transmit = millis();
    delay(10);
    strom.digiWrite(0);
  }

  delay(10);
}



















