#include <OneWire.h>
#include <DallasTemperature.h>

#include <Ports.h>
#include <RF12.h>

#include "hausmessung.h"

// Data wire is plugged into port 3 on the Arduino
#define ONE_WIRE_BUS 4
#define TEMPERATURE_PRECISION 12

#define TRANSMIT_RATE   1000


// Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to Dallas Temperature.
DallasTemperature sensors(&oneWire);

int number_of_devices; // Number of temperature devices found

#define MAX_DEVICES 10
DeviceAddress device_ids[MAX_DEVICES];

byte myId;
unsigned long last_transmit = 0;
unsigned long tx_counter=0;
char tmp_device_name[17];

struct payload_data payload;


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
    Serial.print("Found device ");
    Serial.print(i, DEC);
    Serial.print(" with address: ");
    printAddress(device_ids[i]);
    Serial.println();

    // set the resolution to 9 bit (Each Dallas/Maxim device is capable of several different resolutions)
    sensors.setResolution(device_ids[i], TEMPERATURE_PRECISION);

    i++;
  }
}


void setup(void)
{
  // start serial port
  Serial.begin(57600);

  // Init temperature sensors
  init_temp();

  last_transmit = millis();
  myId = rf12_config();
  Serial.println("Setup done");
}




void loop(void)
{

  rf12_recvDone();

  if ( ( millis() - last_transmit >= TRANSMIT_RATE )) {

    // Send the command to get temperatures
    sensors.requestTemperatures();

    // Loop through each device, print out temperature data for ( int i = 0; i < NUM_DEVICES; i++ ) {
    // server << i << device_connected [i] <<"<br>";

    for(int i=0;i<number_of_devices; i++) {
      if (device_ids[i]) {
        rf12_recvDone();
        if (rf12_canSend()) {
          payload.id = i;
          payload.typ = 1;
          device_address_to_string(device_ids[i]);
          strncpy((char*)payload.data.temperatur.name, tmp_device_name, 17);
          payload.data.temperatur.temp = sensors.getTempC(device_ids[i]);
          Serial  << "Temp" << ";"<< i << ";" << payload.data.temperatur.temp  << ";" << payload.data.temperatur.name << "\n";

          byte header = RF12_HDR_DST | 1;
          rf12_sendStart(header, &payload , sizeof(payload));
          rf12_sendWait(0);
        }
      }
    }



    last_transmit = millis();
  }


  // don't like busy waits - just sleep a while
  delay(10);
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

