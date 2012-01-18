/*

Modified for OSC by Brian Richardson (skinny@knowhere.net)

*/

/******************************************************************************

  Filename:		udpapp.h
  Description:	UDP app for the WiShield 1.0

 ******************************************************************************

  TCP/IP stack and driver for the WiShield 1.0 wireless devices

  Copyright(c) 2009 Async Labs Inc. All rights reserved.

  This program is free software; you can redistribute it and/or modify it
  under the terms of version 2 of the GNU General Public License as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
  more details.

  You should have received a copy of the GNU General Public License along with
  this program; if not, write to the Free Software Foundation, Inc., 59
  Temple Place - Suite 330, Boston, MA  02111-1307, USA.

  Contact Information:
  <asynclabs@asynclabs.com>

   Author               Date        Comment
  ---------------------------------------------------------------
   AsyncLabs			07/11/2009	Initial version

 *****************************************************************************/
extern "C" {
#include "uip.h"
}
#include <string.h>
#include "udpapp.h"
#include "config.h"
#include "HardwareSerial.h"
#include "OSCMessage.h"
#include "OSCDecoder.h"

static struct udpapp_state s;
static OSCDecoder decoder;

// This exists within the sketch for the user to modify.
extern void handleOSCMessage(OSCMessage& oscMess);

void dummy_app_appcall(void)
{
}

void udpapp_init(void)
{
   struct uip_udp_conn *c;

   c = uip_udp_new(NULL, HTONS(0));
   if(c != NULL) {
      uip_udp_bind(c, HTONS(12344));
   }
   PT_INIT(&s.pt);
}

#ifndef HTONL
#   if UIP_BYTE_ORDER == UIP_BIG_ENDIAN
#      define HTONL(n) (n)
#   else /* UIP_BYTE_ORDER == UIP_BIG_ENDIAN */
#      define HTONL(n) ((((uint32_t)(n) & 0xff000000) >> 24) | (((uint32_t)(n) & 0x00ff0000) >> 8) | (((uint32_t)(n) & 0x0000ff00) << 8) | (((uint32_t)(n) & 0x000000ff) << 24))
#   endif /* UIP_BYTE_ORDER == UIP_BIG_ENDIAN */
#else
#error "HTONL already defined!"
#endif /* HTONS */

#ifndef NTOHL
#define NTOHL HTONL
#endif

static unsigned char parse_msg(void)
{
#if 0
    for (int i = 0; i < uip_datalen(); i++)
      Serial.print(((char*)(uip_appdata))[i]);
    Serial.println("");
#endif

    if (strncmp((char *)(uip_appdata), "#bundle", 7) == 0) {
      // oh hey, this one is a bundle..
      /*
      Serial.print("Got a bundle.. total size is ");
      Serial.print(uip_datalen());
      Serial.println("");
      */
      uint8_t* walk = (uint8_t*)(uip_appdata);
      uint8_t* end = walk + uip_datalen();
      walk += 16; // skip #bundle tag and timestamp ..
      while (end - walk >= 4) {
        int len = NTOHL(*(uint32_t *)walk);
        /*
        Serial.print("Size of this portion: ");
        Serial.print(len);
        Serial.println("");
        */
        walk += 4;
        if (walk + len <= end) {
          OSCMessage m;
          decoder.decode(&m, walk);    
          handleOSCMessage(m);
        }
        walk += len;
      }
      return 1;
    }

    OSCMessage m;
    decoder.decode(&m, (uint8_t*)(uip_appdata));    
    handleOSCMessage(m);
    
    return 1;
}

static PT_THREAD(handle_connection(void))
{
   PT_BEGIN(&s.pt);

   // No state machine here now, we just stay in "Parse OSC Message" state.
   while (true) {
      PT_WAIT_UNTIL(&s.pt, uip_newdata());
      if(uip_newdata() && parse_msg()) {
         uip_flags &= (~UIP_NEWDATA);
      }
   } 

   PT_END(&s.pt);
}

void udpapp_appcall(void)
{
   handle_connection();
}
