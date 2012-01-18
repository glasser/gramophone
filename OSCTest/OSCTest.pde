/*
 * UDP endpoint
 *
 * A simple UDP endpoint example using the WiShield 1.0
 */

#include <WiShield.h>
#include <OSCMessage.h>
#include <Wire.h>

#define WIRELESS_MODE_INFRA	1
#define WIRELESS_MODE_ADHOC	2

// Wireless configuration parameters ----------------------------------------
unsigned char local_ip[] = {192,168,1,1};	// IP address of WiShield
unsigned char gateway_ip[] = {0,0,0,0};	// router or gateway IP address
unsigned char subnet_mask[] = {255,255,255,0};	// subnet mask for the local network
const prog_char ssid[] PROGMEM = {"Hive Queen"};		// max 32 bytes

unsigned char security_type = 0;	// 0 - open; 1 - WEP; 2 - WPA; 3 - WPA2

// WPA/WPA2 passphrase
const prog_char security_passphrase[] PROGMEM = {"DEADBEEF23"};	// max 64 characters

// WEP 128-bit keys
// sample HEX keys
prog_uchar wep_keys[] PROGMEM = {	0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d,	// Key 0
									0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,	0x00,	// Key 1
									0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,	0x00,	// Key 2
									0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,	0x00	// Key 3
								};

// setup the wireless mode
// infrastructure - connect to AP
// adhoc - connect to another WiFi device
unsigned char wireless_mode = WIRELESS_MODE_INFRA;

unsigned char ssid_len;
unsigned char security_passphrase_len;
//---------------------------------------------------------------------------

int breakoutAddress = 56;
//int ledPin =  13;    // LED connected to digital pin 13

#define SKIP_WIFI // if defined WIFI is skipped.
#define SERIAL_LOGGING


#define CHANNELS 6
#define OSC_BUTTON_TIMEOUT_MS 1000
#define ATTRACT_INTERVAL_MS 5000

int solenoidOutPins[] = {0, 1, 3, 4, 5, 6};
int buttonInPins[] = {14+0, 14+1, 14+2, 14+3, 8, 9}; // active low

// int electricFenceInPin = 10; // pp  -- using 9 for now

// nonzero means that an OSC user has depressed the button. the value will be the time
// in millis when we will release it automatically if they have not.
unsigned long oscButtonTimers[] = {0, 0, 0, 0, 0, 0};

void setup()   {                
//  pinMode(ledPin, OUTPUT);

#ifdef SERIAL_LOGGING
  Serial.begin(9600);
  Serial.println("Good morning. It is time for the juice of oranges?");
#endif

  for (int i = 0; i < CHANNELS; i++) {
    pinMode(buttonInPins[i], INPUT);
    digitalWrite(buttonInPins[i], HIGH); // pullups
  }

  for (int i = 0; i < CHANNELS; i++) {
    digitalWrite(solenoidOutPins[i], LOW); // paranoia
    pinMode(solenoidOutPins[i], OUTPUT);
  }
  
  

  Wire.begin();
  writeLamps(0);

  for(int i = 0; i < CHANNELS; i++) {
    writeLamps(1 << i);
    delay(250);
  }

#ifndef SKIP_WIFI
  // wifi init can take a while.. let them know when it completes
  writeLamps(1 + 4 + 8); // this means "initializing wifi" :)
#ifdef SERIAL_LOGGING
  Serial.println("Initializing wifi");
#endif
  WiFi.init();
#ifdef SERIAL_LOGGING
  Serial.println("Done. That's a relief");
#endif
#endif
  for (int i = 0; i < 3; i++) {
    writeLamps(255);
    delay(250);
    writeLamps(0);
    delay(500);
  }

  // redo this in case WiFi.init() stomps pin 8 (eg, turns off pullup..)
  for (int i = 0; i < CHANNELS; i++) {
    pinMode(buttonInPins[i], INPUT);
    digitalWrite(buttonInPins[i], HIGH); // pullups
  }

#ifdef SERIAL_LOGGING
  Serial.println("Hello??!");
#endif
}

byte lastLamps = 0;
void writeLamps(byte state) {
  if (state == lastLamps)
    return;
  lastLamps = state;
  Wire.beginTransmission(breakoutAddress);
  Wire.send(state);
  Wire.endTransmission();
}

void clearSolenoids() {
  for (int i = 0; i < CHANNELS; i++) {
    digitalWrite(solenoidOutPins[i], LOW);
  }
}

// add:
// - max firing time
// - min lamp illumination time

void delayPoll(unsigned long term) {
  unsigned long target = millis() + term;
  do {
#ifndef SKIP_WIFI
    WiFi.run();
#endif
  } while (millis() < target);
}


unsigned long lastActivityTime = 0;
unsigned long lastMainLoop = 0;

long mainBrightness[CHANNELS] = {0, 0, 0, 0, 0, 0};
long mainCounters[CHANNELS] = {0, 0, 0, 0, 0, 0};
long minLampOff[CHANNELS] = {0, 0, 0, 0, 0, 0};

void loop()                     
{
  if (lastMainLoop == 0)
    lastMainLoop = millis() - 1;
  
#ifndef SKIP_WIFI
  WiFi.run();
#endif
  /*
  writeLamps(1);
  clearSolenoids(); digitalWrite(solenoidOutPins[0], HIGH);
  delay(200);
  writeLamps(2);
  clearSolenoids(); digitalWrite(solenoidOutPins[1], HIGH);
  delay(200);
  writeLamps(4);
  clearSolenoids(); digitalWrite(solenoidOutPins[2], HIGH);
  delay(200);
  writeLamps(8);
  clearSolenoids(); digitalWrite(solenoidOutPins[3], HIGH);
  delay(200);
  writeLamps(16);
  clearSolenoids(); digitalWrite(solenoidOutPins[4], HIGH);
  delay(200);
  writeLamps(32);
  clearSolenoids(); digitalWrite(solenoidOutPins[5], HIGH);
  delay(200);
  clearSolenoids();
  writeLamps(127);
  delay(1000);
  writeLamps(255);
  delay(1000);
  */

/*  
  for(int i = 0; i < CHANNELS; i++) {
    writeLamps(1 << i);
    clearSolenoids();
    digitalWrite(solenoidOutPins[i], HIGH);
    delayPoll(250);
  }
  */

 
  /*
  for (int i = 0; i < CHANNELS; i++) {
    clearSolenoids();
    digitalWrite(solenoidOutPins[i], HIGH);
    writeLamps(1 << i);
#ifdef lame
    for (int j = 0; j < i + 1; j++) {
      digitalWrite(ledPin, HIGH);
      delay(100);
      digitalWrite(ledPin, LOW);
      delay(100);
    }
#endif
  
    delay(1000);
  }

  clearSolenoids();
  writeLamps(255);
//  digitalWrite(ledPin, HIGH);
  delay(1000);
  */

  byte lamps = 0;
  unsigned long now = millis();
  for (int i = 0; i < CHANNELS; i++) {
    if (oscButtonTimers[i] < now)
      oscButtonTimers[i] = 0;
    if (!digitalRead(buttonInPins[i]) || oscButtonTimers[i] != 0) {
      minLampOff[i] = now + 100; // they always stay on at least this long, even on a tap
      mainBrightness[i] += (now - lastMainLoop)*250;
      if (mainBrightness[i] > 15000)
        mainBrightness[i] = 15000;
      digitalWrite(solenoidOutPins[i], HIGH);
      
      if (i != 5) {
        #ifdef SERIAL_LOGGING
          Serial.print("Pin pressed:");
          Serial.println(i);
        #endif
      }
      
      lastActivityTime = now;
    } else if (digitalRead(buttonInPins[5])) {
   
      /* IF 6th pin is pressed fire them all! */
        makeFireball(200); // passed "stagger" which give pace to the effect
   
    } else {
      digitalWrite(solenoidOutPins[i], LOW);
    }
    if (minLampOff[i] > now)
      lamps = lamps | (1 << i);
    mainCounters[i] += mainBrightness[i];
    if (mainCounters[i] >= 100000) {
      mainCounters[i] -= 100000;
      lamps = lamps | (1 << i);
    }
    mainBrightness[i] -= (now - lastMainLoop)*20;
    if (mainBrightness[i] < 0) {
      mainBrightness[i] = 0;
      mainCounters[i] = 0;
    }
  }
  writeLamps(lamps);
  lastMainLoop = now;
  
  if (now - lastActivityTime > ATTRACT_INTERVAL_MS) {
    switch (random(5)) {
      case 0:
      {
        switch (random(4)) {
         case 0:
          attractRotate(1+2+16, 20*1000);
          break;
         case 1:
          attractRotate(1, 20*1000);
          break;
         case 2:
          attractRotate(1+4+8, 20*1000);
          break;
         case 3:
          attractRotate(1+4, 20*1000);
          break;
        }
      }
      break;
      case 1:
      attractBreathe(20*1000);
      break;
      case 2:
      attractRain(20*1000);
      break;
      case 3:
      attractFade(20*1000);
      break;
      case 4:
      attractPwm(20*1000);
      break;
    }
  }
}
  
  /*
  digitalWrite(ledPin, HIGH);   // set the LED on
//  digitalWrite(lampPin, HIGH);
  lampsOn();
  digitalWrite(firePin, HIGH);
  delay(digitalRead(buttonPin) ? 1000 : 250);
  digitalWrite(ledPin, LOW);    // set the LED off
//  digitalWrite(lampPin, LOW);
  lampsOff();
  digitalWrite(firePin, LOW);
  delay(digitalRead(buttonPin) ? 1000 : 250);
  */

bool startsWith(const char* str, const char* prefix) {
  return strncmp(str, prefix, strlen(prefix)) == 0;
}

void handleOSCMessage(OSCMessage& oscMess)
{

  /*
  Serial.println("Got a message!!!");



    uint16_t i;
    unsigned char *ip=oscMess.getIpAddress();
    
    long int intValue;
    float floatValue;
    char *stringValue;
    
    Serial.print(ip[0],DEC);
    Serial.print(".");
    Serial.print(ip[1],DEC);
    Serial.print(".");
    Serial.print(ip[2],DEC);
    Serial.print(".");
    Serial.print(ip[3],DEC);
    Serial.print(":");
    
    Serial.print(oscMess.getPortNumber());
    Serial.print(" ");
    Serial.print(oscMess.getOSCAddress());
    Serial.print(" ");
    Serial.print(oscMess.getTypeTags());
    Serial.print("--");
    
    for(i=0 ; i<oscMess.getArgsNum(); i++){
      
     switch( oscMess.getTypeTag(i) ){
      
        case 'i':       
          intValue = oscMess.getInteger32(i);
          
          Serial.print(intValue);
          Serial.print(" ");
         break; 
         
         
        case 'f':        
          floatValue = oscMess.getFloat(i);
        
          Serial.print(floatValue);
          Serial.print(" ");
         break; 
        
        
         case 's':         
          stringValue = oscMess.getString(i);
         
          Serial.print(stringValue);
          Serial.print(" ");
         break;       
     }         
    }
    Serial.println("");  
*/

  char* addr = oscMess.getOSCAddress();
  
  if (startsWith(addr, "/hello")) {
    return;
  }

  if (startsWith(addr, "/button")) {
      // oscemote -- /button/[A-E][1-3], sends on/off events as int values 0 and 1
      if (strlen(addr) != strlen("/button/A1")) {
        writeLamps(2+8);
        delay(250);
        return;
      }
      int row = addr[8] - 'A';
      if (row < 0 || row >= CHANNELS) {
        writeLamps(2+16);
        delay(250);
        return;
      }

      bool isOn = true;      
      for (int i=0 ; i < oscMess.getArgsNum(); i++) {
        if (oscMess.getTypeTag(i) == 'i') {
            isOn = oscMess.getInteger32(i) != 0 ? true : false;
        }
      }
        
      oscButtonTimers[row] = isOn ? (millis() + OSC_BUTTON_TIMEOUT_MS) : 0;
      return;
  }

  // unrecognized -- say hi
  for (int i = 0; i < 1; i++) {
    writeLamps(255);
    delay(500);
    writeLamps(0);
    delay(250);
  }
  
    
  return;
  
  
}

// if this returns true, caller should immediately return ...
bool attractDelay(unsigned long term) {
  unsigned long target = millis() + term;
  do {
#ifndef SKIP_WIFI
    WiFi.run();
#endif
    for (int i = 0; i < CHANNELS; i++) {
      if (!digitalRead(buttonInPins[i]) || oscButtonTimers[i] != 0)
        return true;
    }
  } while (millis() < target);

  return false;
}

byte rotate5(byte in) {
  return (in >> 1) | ((in & 1) << 4);
}
byte rotate5rev(byte in) {
  return ((in & (1+2+4+8)) << 1) | (in >> 4);
}

void attractRotate(byte pattern, unsigned long durationMs) {
  unsigned long endTime = millis() + durationMs;
  
  while (true) {
    unsigned long now = millis();
    if (now >= endTime)
      break;
  
    writeLamps(pattern);
   
    float time = 2.0*3.14*now/30000.0;
    if (cos(time) > 0.0) {
      pattern = rotate5rev(pattern);
    }
    else {
      pattern = rotate5(pattern);
    }
   
    if (attractDelay(abs(sin(time))*500.0))
      break;
  }
}

void attractBreathe(unsigned long duration) {
  unsigned long endTime = millis() + duration;
  
  while (!attractDelay(1)) {
    unsigned long now = millis();
    if (now >= endTime)
      break;
    float duty = (sin(2.0*3.14*now/20000.0)+1.0)/2.0;
    if (random(1000) < duty*1000.0)
      writeLamps(255);
    else
      writeLamps(0); 
  }
}


void attractRain(unsigned long duration) {
  unsigned long endTime = millis() + duration;
  
  while (true) {
    unsigned long now = millis();
    if (now >= endTime)
      break;
    writeLamps(1 << random(CHANNELS));
    if (attractDelay(50))
      return;
    writeLamps(0);
    if (attractDelay(75))
      return;
  }
}

void attractFade(unsigned long duration) {
  unsigned long endTime = millis() + duration;

  int intervals[5] = {10000, 10000, 10000, 10000, 10000};
  int counters[5] = {0, 0, 0, 0, 0};
  
  while (!attractDelay(10)) {
    unsigned long now = millis();
    if (now >= endTime)
      break;
 
    if (random(100) == 0)
      intervals[random(5)] = 2;

    byte lamps = 0;
    byte cost = random(3) == 0 ? 1 : 0;
    for (int i = 0; i < 5; i++) {
      counters[i]++;
      if (counters[i] >= intervals[i]) {
        lamps = lamps | (1 << i);
        counters[i] = 0;
        intervals[i] += cost;
      }
    }
    
    writeLamps(lamps);
  }
}

void attractPwm(unsigned long duration) {
  unsigned long endTime = millis() + duration;
  unsigned long nextGift = 0;
  unsigned long lastTick = millis();

  long brightness[5] = {0, 0, 0, 0, 0};
  long counters[5] = {0, 0, 0, 0, 0};
  
  while (!attractDelay(1)) {
    unsigned long now = millis();
    if (now >= endTime)
      break;
 
    if (now >= nextGift) {
      brightness[random(5)] = 20000;
      nextGift = now + random(5000);
    }

    byte free = random(2) == 0;
    byte lamps = 0;
    int cost = (now - lastTick)*2;
    for (int i = 0; i < 5; i++) {
      counters[i] += brightness[i];
      if (counters[i] >= 20000) {
        counters[i] -= 20000;
        lamps = lamps | (1 << i);
      }
      if (brightness[i] > 10000)
        brightness[i] -= cost;
      if (brightness[i] > 2500 || !free)
        brightness[i] -= cost;
      if (brightness[i] < 0) {
        brightness[i] = 0;
        counters[i] = 0;
      }
    }
    
    writeLamps(lamps);
    lastTick = now;
  }
}

void makeFireball(unsigned long stagger) {

  #ifdef SERIAL_LOGGING
  Serial.println("Fireball!");
  #endif
    
  
      // turn all off
      for (int j = 0; j < CHANNELS; j++) {
        digitalWrite(solenoidOutPins[j], LOW);
      }
      
      delay(stagger);

      // circle around -- using channels - 1 so that the % (modulo) works out
      for (int j = 0; j < (CHANNELS - 1); j++) {
        digitalWrite(solenoidOutPins[j], HIGH);
        delay(stagger);
        digitalWrite(solenoidOutPins[(j-1) % (CHANNELS - 1) ], LOW);  
      }
      
      // just in case
      for (int j = 0; j < CHANNELS; j++) {
        digitalWrite(solenoidOutPins[j], LOW);
      }
      
      
      // fire them all 
      for (int j = 0; j < CHANNELS; j++) {
        digitalWrite(solenoidOutPins[j], HIGH);
      }
      
      delay(stagger*5);
      
      // turn them all off
      for (int j = 0; j < CHANNELS; j++) {
        digitalWrite(solenoidOutPins[j], LOW);
      }
      
      delay(stagger*5);
      
}
