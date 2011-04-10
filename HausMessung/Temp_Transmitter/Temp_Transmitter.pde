#include <OneWire.h>
#include <DallasTemperature.h>

#include <Ports.h>
#include <RF12.h>


// Data wire is plugged into port 3 on the Arduino
#define ONE_WIRE_BUS 3
#define TEMPERATURE_PRECISION 12

#define TRANSMIT_RATE   1000


struct {
    byte typ;
    byte id;    // temp sensor: 0..255
    union {
      struct {
        int temp;   // temperature * 100
        char name[20];
      } temperatur;
      struct {
        int watt;
        unsigned long count;
        unsigned long transmittcount;
      } strom;
    } data;
} payload;


// no-cost stream operator as described at
// http://sundial.org/arduino/?page_id=119
template<class T>
inline Print &operator <<(Print &obj, T arg)
{
  obj.print(arg);
  return obj;
}


// Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to Dallas Temperature.
DallasTemperature sensors(&oneWire);

#define NUM_DEVICES 8
int numberOfDevices; // Number of temperature devices found


DeviceAddress device_ids[NUM_DEVICES] = {
  {
    0x28,0x32,0xC4,0xFA,0x01,0x00,0x00,0x61        }
  , // Wozi
  {
    0x28,0xfe,0xef,0xca,0x01,0x00,0x00,0x43        }
  , // Erdgeschoss
  {
    0x28,0x65,0x02,0xFB,0x01,0x00,0x00,0xFB        }
  , // Keller
  {
    0x28,0x1d,0x1f,0xcb,0x01,0x00,0x00,0x1a        }
  , // Heizung
  {
    0x28,0x4E,0xE6,0xFA,0x01,0x00,0x00,0xFF        }
  , // Onboard

  {
    0x28,0x4a,0x27,0xcb,0x01,0x00,0x00,0x0b        }
  , // Temp1

  {
    0x28,0x22,0x0c,0x72,0x02,0x00,0x00,0x07      }
  , // Temp 6
  {
    0x28,0x31,0xd1,0xfa,0x01,0x00,0x00,0x96      }
  , // Dach

};

bool device_connected[NUM_DEVICES];

// Definition of CharArray for Sensor-Names
char* device_names[NUM_DEVICES] = {
  "Wohnzimmer",
  "Erdgeschoss",
  "Keller",
  "Heizung",
  "OnBoard",

  "Temp1",
  "Temp6",
  "Dach",
};


byte myId;
unsigned long last_transmit = 0;
unsigned long tx_counter=0;


void init_temp(void) {
  // Start up the library
  sensors.begin();

  // Grab a count of devices on the wire
  numberOfDevices = sensors.getDeviceCount();

  // locate devices on the bus
  Serial.print("Locating devices...");

  Serial.print("Found ");
  Serial.print(numberOfDevices, DEC);
  Serial.println(" devices.");


  // Loop through each device, print out address
  for(int i=0;i<NUM_DEVICES; i++)
  {
    // Search the wire for address
    if(sensors.isConnected(device_ids[i]))
    {
      device_connected[i]=1;
      Serial.print("Found device ");
      Serial.print(i, DEC);
      Serial.print(" with address: ");
      printAddress(device_ids[i]);
      Serial.println();

      // set the resolution to 9 bit (Each Dallas/Maxim device is capable of several different resolutions)
      sensors.setResolution(device_ids[i], TEMPERATURE_PRECISION);
    }
    else{
      device_connected[i]=0;
      Serial << "Device ";
      printAddress(device_ids[i]);
      Serial  << " nicht gefunden!\n";
    }
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

        for(int i=0;i<NUM_DEVICES; i++) {
            if (device_connected[i]==1) {
                rf12_recvDone();
                if (rf12_canSend()) {
                payload.id = i;
                payload.typ = 1;
                strncpy((char*)payload.data.temperatur.name, device_names[i], 19);
                float tempC = sensors.getTempC(device_ids[i]);
                payload.data.temperatur.temp = (int)(tempC*100);
                Serial  << "Temp" << ";"<< i << ";" << payload.data.temperatur.temp  << ";" << payload.data.temperatur.name << "\n";

                byte header = RF12_HDR_ACK | RF12_HDR_DST | 1;
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
