#include <Streaming.h>

#include <OneWire.h>
#include <DallasTemperature.h>

#include <Ports.h>
#include <RF12.h>
#define TRANSMIT_RATE   1000

// Data wire is plugged into port 3 on the Arduino
#define ONE_WIRE_BUS 7
#define TEMPERATURE_PRECISION 12


struct payload_data {
  byte typ; // typ = 1: temp, 2: strom, 3: luefter
  byte id; // sensor id: 0..255
  union {
    struct {
      float temp;
      char name[20];
    } 
    temperatur;
    struct {
      int watt;
      unsigned long count;
      unsigned long tx_count;
    } 
    strom;
    struct {
      int drehzahl;
      int duty;
    } 
    luefter;
  } 
  data;
};


int last_read=0;
int rpm1=0;
volatile unsigned int rpm1_counter = 0;
volatile int blink=0;
byte myId;
struct payload_data payload;

// Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to Dallas Temperature.
DallasTemperature sensors(&oneWire);
int number_of_devices; // Number of temperature devices found

#define MAX_DEVICES 10
DeviceAddress device_ids[MAX_DEVICES];
char tmp_device_name[17];


void inc_rpm1() {
  rpm1_counter++;
  blink=!blink;
  digitalWrite(13,blink);
}

int h2o_sensor_id=-1;

void init_temp(void) {
  // Start up the library
  sensors.begin();

  // Grab a count of devices on the wire
  number_of_devices = sensors.getDeviceCount();

  // locate devices on the bus
  Serial.print("Locating devices...");

  Serial.print("Found ");
  Serial.print(number_of_devices, DEC);
  Serial.println(" devices.");

  oneWire.reset_search();
  int i=0;
  while (i < MAX_DEVICES && oneWire.search(device_ids[i])) {
    device_address_to_string(device_ids[i]);

    Serial << "Found device " <<  i << " with address: " << tmp_device_name << endl;

    // set the resolution to 9 bit (Each Dallas/Maxim device is capable of several different resolutions)
    sensors.setResolution(device_ids[i], TEMPERATURE_PRECISION);

    if (!strncmp(tmp_device_name,"28c5c2fa0100000a",16)) {
      h2o_sensor_id = i;
      Serial << "Aquarium-Sensor id = " << i << endl;
    }
    i++;
  }
  number_of_devices = i;
}


void setup() {
  // initialize serial communication at 57600 bits per second:
  Serial.begin(57600);
  pinMode(13,OUTPUT);

  // Init temperature sensors
  init_temp();

  pinMode(4,OUTPUT);
  digitalWrite(4,0);

  pinMode(3,INPUT);
  digitalWrite(3, HIGH);
  attachInterrupt(1,inc_rpm1,RISING);
  last_read=millis();

  /*
  pinMode(3, OUTPUT);
   TCCR2A = _BV(COM2B1) | _BV(WGM21) | _BV(WGM20); // COM2B1: clear OC2B on Compare Match; WGM21/20/22 (latter in TCCR2B below): count from 0 to OCR2A
   TCCR2B = _BV(WGM22) | _BV(CS21); // CS20: prescaler 8
   OCR2A = 80;
   OCR2B = 40; // for 50% duty cycle
   */
  pinMode(9, OUTPUT);
  TCCR1A = _BV(COM1A1); // COM2B1: clear OC2B on Compare Match; WGM21/20/22 (latter in TCCR2B below): count from 0 to OCR2A
  TCCR1B = _BV(WGM13) | _BV(CS11); // CS20: prescaler 8
  ICR1=80;
  OCR1B = 80;
  OCR1A = 40; // for 50% duty cycle

  myId = rf12_config();

}

float h2o_temp=0.0;
int luefter_an = 0;

void loop() {
  int sensorValue;

  rf12_recvDone();

  int time_now = millis();

  if (time_now - last_read > 5000) {
    float time_faktor = (time_now-last_read) / 1000.0;
    rpm1 = rpm1_counter * 30 / time_faktor;
    last_read = time_now;
    rpm1_counter = 0;


    // Send the command to get temperatures
    sensors.requestTemperatures();
    delay(50);
    for(int i = 0; i < number_of_devices; i++) {
      if (device_ids[i]) {
        rf12_recvDone();
        if (rf12_canSend()) {
          payload.id = 31;
          payload.typ = 1;
          device_address_to_string(device_ids[i]);
          strncpy((char*)payload.data.temperatur.name, tmp_device_name, 17);
          payload.data.temperatur.temp = sensors.getTempC(device_ids[i]);
          if (i == h2o_sensor_id) {
            h2o_temp = payload.data.temperatur.temp;
          }
          Serial  << "Temp" << ";"<< i << ";" << payload.data.temperatur.temp  << ";" << payload.data.temperatur.name << endl;

          byte header = RF12_HDR_DST | 1;
          rf12_sendStart(header, &payload , sizeof(payload));
          rf12_sendWait(0);
          delay(100);
        }
      }
    }



    // read the input on analog pin 0:
    /*    if (h2o_sensor_id == -1 || h2o_temp <= 0) {
     sensorValue = analogRead(A0);
     sensorValue = map(sensorValue,0,1023,29,80); 
     } 
     */

    sensorValue = map(h2o_temp*100,1950,2100,29,80);
    if (h2o_temp > 21) {
      sensorValue = 80;
    }
    if (sensorValue < 29) {
      sensorValue = 29;
    }    
    Serial << "Mapping: " << sensorValue << endl;

    // Hysterese Logik
    if (luefter_an == 0 && sensorValue >= 36) {
      digitalWrite(4,HIGH);
      luefter_an = 1;
    } 
    if (luefter_an == 1 && sensorValue <= 31) {
      digitalWrite(4,LOW);
      luefter_an = 0;
    }

    // Wenn luefter aus sein soll, PWM auf 0
    if (luefter_an == 0) {
      sensorValue = 0;
    }
    OCR1A = sensorValue;



    rf12_recvDone();
    if (rf12_canSend()) {
      payload.id = 31;
      payload.typ = 3;
      payload.data.luefter.drehzahl = rpm1;
      payload.data.luefter.duty = sensorValue;

      byte header = RF12_HDR_DST | 1;      
      rf12_sendStart(header, &payload , sizeof(payload));
      rf12_sendWait(0);
    }

    Serial << "Luefter: " << sensorValue << " RPM: " << rpm1_counter << " " << rpm1 << endl; 
  }

  delay(100);
}


// function to print a device address
void printAddress(DeviceAddress deviceAddress)
{
  for (uint8_t i = 0; i < 8; i++)
  {
    if (deviceAddress[i] < 16) Serial.print("0");
    Serial.print(deviceAddress[i], HEX);
  }
}


void device_address_to_string(DeviceAddress deviceAddress)
{
  sprintf(tmp_device_name, "%02x%02x%02x%02x%02x%02x%02x%02x", 
  deviceAddress[0],deviceAddress[1],deviceAddress[2],deviceAddress[3],
  deviceAddress[4],deviceAddress[5],deviceAddress[6],deviceAddress[7]);
  tmp_device_name[16]=0;
}









