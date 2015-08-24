If you're looking to connect an on-premise VOIP phone system to Office 365 you'll find several documents stating that you must purchase a session border controller, and a list of supported vendors. But if you're the kind of person who would rather take an unsupported approach than install yet another black box on your network, it can be done. In this guide I'll share what I've learned over the last two weeks in building my own session boarder controller with open source software.

This guide assumes you have some familiarity with SIP and that you can do some of the basic configuration of software like Kamailio and rtpengine. The point of this post is primarily to document the specific configuration needed by Office 365.

To start, you'll need a server with the [Kamailio](http://www.kamailio.org) SIP server and the Sipwise [rtpengine](https://github.com/sipwise/rtpengine) RTP proxy installed. I'll be referring this server as `sbc` throughout this guide. The internal address for `sbc` is 10.0.0.5, the external address is 25.25.25.5.

You will also need a public IP that is natted to your `sbc` server, and a public DNS record. And you will need an SSL certificate signed by one of [Office 365's supported CA's](https://support.microsoft.com/en-us/kb/929395). The Subject of the certificate must match the DNS record EXACTLY, wildcard certificates will not work. If you attempt to connect with a wildcard certificate you will get 403 forbidden back from Microsoft's SIP server.

Make sure you have a UM Dial plan configured in Office 365, then configure your UM IP Gateway. Use your public DNS entry which matches the subject of your SSL certificate for the address. Once configured, open back up the UM IP Gateway configuration to find your Fowarding address, it will be in the format <guid>.um.outlook.com.

You will need to configure your firewall to allow SIPS and SRTP from Office 365. You can either open your firewall to all [Office 365 IPs](https://support.office.com/en-us/article/Office-365-URLs-and-IP-address-ranges-8548a211-3fe7-47cb-abb1-355ea5aa88a2?ui=en-US&rs=en-US&ad=US) or use the IP that your forwarding address currently resolves to and hope it doesn't change. To allow SIPS, make sure that TCP port 5061 is open to your `sbc` server. To allow SRTP you will need to allow the UDP port range 1024-65535.

In my case the phone system I'm proxying to 365 is Cisco Unified Call Manager 8. To connect Call Manager to your `sbc` server, create a SIP Trunk, be sure that `Media Termination Point Required` is checked and make sure it is associated with a SIP security profile that uses TCP. For the Destination use the internal IP of your `sbc` server. Then create a route pattern for Office 365 voicemail that uses this trunk, in my case I'm using the numer 87000.

All the steps so far are prerequisites that would be basically the same for any session boarder controller. The next steps are whare you start building your own SBS.

First configure rtpengine. If using the debian packages, edit `/etc/defaults/ngcp-rtpengine-daemon` otherwise edit your startup script with the same options.

```
#/etc/defaults/ngcp-rtpengine-daemon

RUN_RTPENGINE=yes
LISTEN_TCP=25060
LISTEN_UDP=12222
LISTEN_NG=22222
LISTEN_CLI=9900
INTERFACES="10.0.0.5 internal/10.0.0.5 external/10.0.0.5!25.25.25.5"
TIMEOUT=60
SILENT_TIMEOUT=3600
PIDFILE=/var/run/ngcp-rtpengine-daemon.pid
FORK=yes
TABLE=0
```

The important part here is `LISTEN_NG` which is how kamailio will communicate with rtpengine, and `INTERFACES` which specifies which interface rtpengine will listen on as well as how rtpengine will re-write the SDP body in the SIP packets.

For your kamailio configuration, make sure you have the modules for tls, rtpengine and textops enabled. Consult the kamailio [tls](http://kamailio.org/docs/modules/3.4.x/modules/tls.html) documentation for how to configure your SSL certificate.

Since I'm using kamailio for routing to other SIP trunks as well, I created an SRV record specifically for routing to 365 which I point Call Manager to. I then use the SIP uri to determine which SIP packets to rewrite for 365. The kamailio routing config may look something like this.

```
#/etc/kamailio/kamailio.cfg
request_route {
    if(uri=~'^.*@pstn[0-9]?-o365\.in\.trilliumstaffing\.com.*$') {
        set_rtpengine_set("0");
        tpengine_manage("SRTP DTLS=off replace-session-connection ICE=remove direction=internal direction=external");#
    }
    if(!loose_route()) {
        if(uri=~'^.*@sbc-o365\.example\.com.*$') {
            record_route_advertised_address("25.25.25.5");
            rewritehostporttrans("<guid>.um.outlook.com:5061;transport=tls");
            remove_hf("To");
            insert_hf("To: <sip:87000@<guid>.um.outlook.com>\r\n");
            t_on_reply(1);
        }
    }
}
onreply_route[1] {
    set_rtpengine_set("0");
    rtpengine_manage("RTP DTLS=off ICE=remove replace-session-connection direction=external direction=internal");#
    sdp_remove_line_by_prefix("c=IN IP4 25");
    subst("/^(Record-Route.*)25[.]25[.]25[.]5(.*)$/\\10.0.0.5\\2/g");
}
```

Don't expect to be able to copy and paste the config above and have it work. As noted earlier, this guide is for people who can manage a kamailio configuration. But this should include the minimum SIP maipulations necessary to make it work.

Part of what makes integrating SIP with Office 365 so difficult is that Microsoft does not public specific guidence on what SIP options they require, this seems to be special information reserved to their SBC partners. Here are some of the specific requirements I've learned through trial and error.

1. As noted above, the certificate subject must exactly match your DNS and the address in your UM IP gateway. Without this you get a 403 from 365.

2. The host portion of the To: header in your SIP packet must be your destination <guid>.um.outlook.com. If this does not match you will get 488 not acceptable here from Microsoft.

3. You will also get 488 from Microsoft if you are not offering SRTP

4. If you are offering RTCP mutexing in your invite you will get 488.

5. If your Invite contains any ICE options you will get 488.

There may be other requirements or restrictions that I did not discover, so in the interests of helping others figure out what Office 365 requires I'm including the dump of a SIP exchange between my working Kamailio/rtpengine server and Office 365.


Invite with Offer

```
INVITE sip:87000@df6b236d-056d-416a-8f5f-f2e8e1a0238d.um.outlook.com:5061;transport=tls SIP/2.0
Record-Route: <sip:25.25.25.5;transport=tls;r2=on;lr>
Record-Route: <sip:25.25.25.5;transport=tcp;r2=on;lr>
To: <sip:87000@<guid>.um.outlook.com>
Via: SIP/2.0/TLS sbc.example.com:5061;branch=z9hG4bKf5ce.075c1223046356d5878a36157c2736d5.0;i=c
Via: SIP/2.0/TCP 10.0.0.6:5060;branch=z9hG4bK1fd3fd816943
From: "10048 - Armstrong, Clint" <sip:10048@10.0.0.6>;tag=94213~3cc43a48-48ec-41b9-848c-fcefa428f2e7-21861219
Date: Mon, 24 Aug 2015 12:22:29 GMT
Call-ID: c81d7600-5db10c85-9501-3402000a@10.0.2.52
Supported: timer,resource-priority,replaces
Min-SE:  1800
User-Agent: Cisco-CUCM9.1
Allow: INVITE, OPTIONS, INFO, BYE, CANCEL, ACK, PRACK, UPDATE, REFER, SUBSCRIBE, NOTIFY
CSeq: 101 INVITE
Expires: 180
Allow-Events: presence, kpml
Supported: X-cisco-srtp-fallback,X-cisco-original-called
Call-Info: <urn:x-cisco-remotecc:callinfo>; security= NotAuthenticated; gci= 1-4270982, <sip:10.0.2.52:5060>;method="NOTIFY;Event=telephone-event;Duration=500"
Cisco-Guid: 3357373952-0000065536-0000032693-0872546314
Session-Expires:  1800
P-Asserted-Identity: "10048 - Armstrong, Clint" <sip:10048@10.0.2.52>
Remote-Party-ID: "10048 - Armstrong, Clint" <sip:10048@10.0.2.52>;party=calling;screen=yes;privacy=off
Contact: <sip:10048@10.0.0.6:5060;transport=tcp>
Max-Forwards: 70
Content-Type: application/sdp
Content-Length: 322

v=0
o=CiscoSystemsCCM-SIP 94213 1 IN IP4 10.0.2.52
s=SIP Call
c=IN IP4 25.25.25.5
t=0 0
m=audio 31182 RTP/SAVP 0 101
a=rtpmap:0 PCMU/8000
a=ptime:20
a=rtpmap:101 telephone-event/8000
a=fmtp:101 0-15
a=sendrecv
a=rtcp:31183
a=crypto:1 AES_CM_128_HMAC_SHA1_80 inline:Rt5s9b1WdrBKIoygx4q3Tx8Zog/+Qt1/UTEmxr9x
```

OK with Answer

```
SIP/2.0 200 OK
To: <sip:87000@<guid>.um.outlook.com>;tag=ee195713eb
Via: SIP/2.0/TLS sbc.example.com:5061;received=25.25.25.5;branch=z9hG4bKf5ce.075c1223046356d5878a36157c2736d5.0;i=c
Via: SIP/2.0/TCP 10.0.0.6:5060;branch=z9hG4bK1fd3fd816943
From: "10048 - Armstrong, Clint" <sip:10048@10.0.0.6>;tag=94213~3cc43a48-48ec-41b9-848c-fcefa428f2e7-21861219
Call-ID: c81d7600-5db10c85-9501-3402000a@10.0.0.6
CSeq: 101 INVITE
Record-Route: <sip:25.25.25.5;transport=tls;r2=on;lr>
Record-Route: <sip:25.25.25.5;transport=tcp;r2=on;lr>
Contact: <sip:207.46.198.124:5061;transport=tls>;automata;text;audio;video;image
CONTENT-LENGTH: 355
PRIORITY: Normal
SUPPORTED: Replaces
SUPPORTED: timer
SUPPORTED: 100rel
CONTENT-TYPE: application/sdp
ALLOW: ACK
Allow: CANCEL,BYE,INVITE,MESSAGE,INFO,SERVICE,OPTIONS,BENOTIFY,NOTIFY,PRACK,UPDATE
P-ASSERTED-IDENTITY: <sip:87000@<guid>.um.outlook.com>
SERVER: RTCC/5.0.0.0 MSExchangeUM/15.01.0231.021
Content-ID: c0284ce7-716b-4ff2-8ec3-c23379fe1184
Session-Expires: 1800;refresher=uac
Min-SE: 1800

v=0
o=- 85 0 IN IP4 207.46.198.124
s=session
c=IN IP4 207.46.198.124
b=CT:10000000
t=0 0
m=audio 54532 RTP/SAVP 0 101
c=IN IP4 207.46.198.124
a=label:main-audio
a=sendrecv
a=rtpmap:0 PCMU/8000
a=rtpmap:101 telephone-event/8000
a=fmtp:101 0-16,36
a=ptime:20
a=crypto:1 AES_CM_128_HMAC_SHA1_80 inline:FHoHEZk7wM6b/frTeX+fzQ/K0PtuAvfIzRqjol9K
```
