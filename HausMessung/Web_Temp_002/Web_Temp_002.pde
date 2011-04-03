#include <OneWire.h>
#include <DallasTemperature.h>
#define WEBDUINO_SERIAL_DEBUGGING 0
#include <SPI.h>
#include "Ethernet.h"
#include "WebServer.h"

// Data wire is plugged into port 2 on the Arduino
#define ONE_WIRE_BUS 3
#define TEMPERATURE_PRECISION 12


// no-cost stream operator as described at 
// http://sundial.org/arduino/?page_id=119
template<class T>
inline Print &operator <<(Print &obj, T arg)
{ 
  obj.print(arg); 
  return obj; 
}

// CHANGE THIS TO YOUR OWN UNIQUE VALUE
static uint8_t mac[] = { 
  0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };

// CHANGE THIS TO MATCH YOUR HOST NETWORK
static uint8_t ip[] = { 
  192, 168, 178, 222 };

#define PREFIX ""

WebServer webserver(PREFIX, 80);


// Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to Dallas Temperature. 
DallasTemperature sensors(&oneWire);

#define NUM_DEVICES 8
int numberOfDevices; // Number of temperature devices found


DeviceAddress device_ids[NUM_DEVICES] = { 
  { 
    0x28,0x32,0xC4,0xFA,0x01,0x00,0x00,0x61  }
  , // Wozi
  { 
    0x28,0xfe,0xef,0xca,0x01,0x00,0x00,0x43  }
  , // Erdgeschoss
  { 
    0x28,0x65,0x02,0xFB,0x01,0x00,0x00,0xFB  }
  , // Keller
  { 
    0x28,0x1d,0x1f,0xcb,0x01,0x00,0x00,0x1a  }
  , // Heizung
  { 
    0x28,0x4E,0xE6,0xFA,0x01,0x00,0x00,0xFF  }
  , // Onboard

  { 
    0x28,0x4a,0x27,0xcb,0x01,0x00,0x00,0x0b  }
  , // Temp1

  { 0x28,0x22,0x0c,0x72,0x02,0x00,0x00,0x07}, // Temp 6
  { 0x28,0x31,0xd1,0xfa,0x01,0x00,0x00,0x96}, // Dach

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


void resetCmd(WebServer &server, WebServer::ConnectionType type, char *, bool)
{
  /* this line sends the standard "we're all OK" headers back to the
   browser */
  server.httpSuccess();

  /* if we're handling a GET or POST, we can output our data here.
   For a HEAD request, we just stop after outputting headers. */
  if (type != WebServer::HEAD)
  {
    Serial.print("Resetting Temp\n");
    init_temp();
    Serial.print("Reset done\n");
    server << "Reset done<br><a href=\"/\">back</a>";
  }

}




void tempCmd(WebServer &server, WebServer::ConnectionType type, char *, bool)
{
  /* this line sends the standard "we're all OK" headers back to the
   browser */
  server.httpSuccess();

  /* if we're handling a GET or POST, we can output our data here.
   For a HEAD request, we just stop after outputting headers. */
  if (type != WebServer::HEAD)
  {
    
    
    server << "<a href=\"reset.html\">reset</a> | <a href=\"csv.html\">csv</a><br>\n";
    sensors.requestTemperatures(); // Send the command to get temperatures

      int min=-10;
    int max=60;

    // Loop through each device, print out temperature data
    for(int i=0;i<NUM_DEVICES; i++)
    {
      // server << i << device_connected[i]<<"<br>";
      if (device_connected[i]==1) {
        float tempC = sensors.getTempC(device_ids[i]);
        server << device_names[i] << " ( Sensor " << i << " ): " << tempC << " Grad Celsius<br>\n";	
        server << "<img src=\"http://chart.apis.google.com/chart?cht=gom&chs=250x150&chxt=x,y&chds=" << min << "," << max << "&chxr=0,"<<min<<","<<max<<",10|1,"<<min<<","<<max<<",10";
        server << "&chco=0000ff,00ff00,ffff00,ff0000";
        server << "&chtt="<< device_names[i];	
        server << "&chd=t:" << tempC << "&chl=" << tempC;
        server << "\"><br>\n<hr>\n";
      }
    } 
  }
}

void csvCmd(WebServer &server, WebServer::ConnectionType type, char *, bool)
{
  /* this line sends the standard "we're all OK" headers back to the
   browser */
  server.httpSuccess("text/plain");

  /* if we're handling a GET or POST, we can output our data here.
   For a HEAD request, we just stop after outputting headers. */
  if (type != WebServer::HEAD)
  {
    sensors.requestTemperatures(); // Send the command to get temperatures

    // Loop through each device, print out temperature data
    for(int i=0;i<NUM_DEVICES; i++)
    {
      // server << i << device_connected[i]<<"<br>";
      if (device_connected[i]==1) {
        float tempC = sensors.getTempC(device_ids[i]);
        server << i << ";" << device_names[i] << ";" << tempC << "\n"; 
      }
    } 
  }
}


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
  Serial.begin(9600);

  // Init temperature sensors
  init_temp();

  /* initialize the Ethernet adapter */
  Ethernet.begin(mac, ip);

  /* setup our default command that will be run when the user accesses
   * the root page on the server */
  webserver.setDefaultCommand(&tempCmd);
  webserver.addCommand("index.html", &tempCmd);

  // setup the other URLs
  webserver.addCommand("csv.html", &csvCmd);
  webserver.addCommand("reset.html", &resetCmd);

  /* start the webserver */
  webserver.begin();

}

void loop(void)
{ 


  char buff[64];
  int len = 64;

  /* process incoming connections one at a time forever */
  webserver.processConnection(buff, &len);
  
  // don't like busy waits - just sleep a while
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



