#!/usr/bin/env python3
"""Simulierter Panasonic VIERA (2012er NRC/DMR-Protokoll) für den Protokolltest."""
import re, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

NRC = "urn:panasonic-com:service:p00NetworkControl:1"
RC = "urn:schemas-upnp-org:service:RenderingControl:1"
state = {"volume": 10, "mute": 0, "keys": []}

DDD = """<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0"><device>
<deviceType>urn:panasonic-com:device:p00RemoteController:1</deviceType>
<friendlyName>VIERA_WT50</friendlyName><manufacturer>Panasonic</manufacturer>
<modelName>VIERA</modelName><modelNumber>TX-L55WT50E</modelNumber>
<UDN>uuid:4D454930-0200-1000-8001-A81374ABCDEF</UDN>
</device></root>"""

def envelope(action, urn, inner=""):
    return (f'<?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">'
            f'<s:Body><u:{action}Response xmlns:u="{urn}">{inner}</u:{action}Response></s:Body></s:Envelope>')

FAULT = ('<?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><s:Fault>'
         '<faultcode>s:Client</faultcode><faultstring>UPnPError</faultstring><detail>'
         '<UPnPError xmlns="urn:schemas-upnp-org:control-1-0"><errorCode>401</errorCode>'
         '<errorDescription>Invalid Action</errorDescription></UPnPError></detail></s:Fault></s:Body></s:Envelope>')

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def reply(self, code, body):
        b = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", 'text/xml; charset="utf-8"')
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path == "/nrc/ddd.xml": return self.reply(200, DDD)
        if self.path == "/log": return self.reply(200, ",".join(state["keys"]))
        self.reply(404, "")

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0))).decode()
        action = self.headers.get("SOAPACTION", "")
        if not (action.startswith('"') and action.endswith('"')): return self.reply(500, FAULT)
        urn, _, name = action.strip('"').partition("#")
        if f"<u:{name} xmlns:u=\"{urn}\">" not in body or "<s:Envelope" not in body: return self.reply(500, FAULT)
        if self.path == "/nrc/control_0" and urn == NRC and name == "X_SendKey":
            key = re.search(r"<X_KeyEvent>(.*?)</X_KeyEvent>", body).group(1)
            if "FORBIDDEN" in key: return self.reply(403, "")
            if not re.fullmatch(r"NRC_[A-Z0-9_]+-ONOFF", key): return self.reply(500, FAULT)
            state["keys"].append(key)
            return self.reply(200, envelope(name, urn))
        if self.path == "/dmr/control_0" and urn == RC:
            if "<InstanceID>0</InstanceID><Channel>Master</Channel>" not in body: return self.reply(500, FAULT)
            if name == "GetVolume": return self.reply(200, envelope(name, urn, f"<CurrentVolume>{state['volume']}</CurrentVolume>"))
            if name == "SetVolume":
                state["volume"] = int(re.search(r"<DesiredVolume>(\d+)</DesiredVolume>", body).group(1))
                return self.reply(200, envelope(name, urn))
            if name == "GetMute": return self.reply(200, envelope(name, urn, f"<CurrentMute>{state['mute']}</CurrentMute>"))
            if name == "SetMute":
                state["mute"] = int(re.search(r"<DesiredMute>(\d)</DesiredMute>", body).group(1))
                return self.reply(200, envelope(name, urn))
        self.reply(500, FAULT)

ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
