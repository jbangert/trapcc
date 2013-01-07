#!/usr/bin/env python
# GoodFET Client Library for Maxim USB Chips.
#  This version depends on the usb_max.py file to provide Scapy classes for
#  protocol interaction and packet creation.
#
# (C) 2012 Travis Goodspeed <travis at radiantmachines.com>
# Modifications for using Scapy usb_max layer:
#    (C) 2012 Ryan Speers <ryan at rmspeers.com>
#
# This code is being rewritten and refactored.  You've been warned!


import sys, time, string, cStringIO, struct, glob, os;

from GoodFET import GoodFET;
from usb_max import *

#Handy registers.
rEP0FIFO=0
rEP1OUTFIFO=1
rEP2INFIFO=2
rEP3INFIFO=3
rSUDFIFO=4
rEP0BC=5
rEP1OUTBC=6
rEP2INBC=7
rEP3INBC=8
rEPSTALLS=9
rCLRTOGS=10
rEPIRQ=11
rEPIEN=12
rUSBIRQ=13
rUSBIEN=14
rUSBCTL=15
rCPUCTL=16
rPINCTL=17
rREVISION=18
rFNADDR=19
rIOPINS=20
rIOPINS1=20  #Same as rIOPINS
rIOPINS2=21
rHIRQ=25
rHIEN=26
rMODE=27
rPERADDR=28
rHCTL=29
rHXFR=30
rHRSL=31

#Host mode registers.
rRCVFIFO =1
rSNDFIFO =2
rRCVBC   =6
rSNDBC   =7
rHIRQ    =25


# R11 EPIRQ register bits
bmSUDAVIRQ =0x20
bmIN3BAVIRQ =0x10
bmIN2BAVIRQ =0x08
bmOUT1DAVIRQ= 0x04
bmOUT0DAVIRQ= 0x02
bmIN0BAVIRQ =0x01

# R12 EPIEN register bits
bmSUDAVIE   =0x20
bmIN3BAVIE  =0x10
bmIN2BAVIE  =0x08
bmOUT1DAVIE =0x04
bmOUT0DAVIE =0x02
bmIN0BAVIE  =0x01




# ************************
# Standard USB Requests
SR_GET_STATUS		=0x00	# Get Status
SR_CLEAR_FEATURE	=0x01	# Clear Feature
SR_RESERVED		=0x02	# Reserved
SR_SET_FEATURE		=0x03	# Set Feature
SR_SET_ADDRESS		=0x05	# Set Address
SR_GET_DESCRIPTOR	=0x06	# Get Descriptor
SR_SET_DESCRIPTOR	=0x07	# Set Descriptor
SR_GET_CONFIGURATION	=0x08	# Get Configuration
SR_SET_CONFIGURATION	=0x09	# Set Configuration
SR_GET_INTERFACE	=0x0a	# Get Interface
SR_SET_INTERFACE	=0x0b	# Set Interface

# Get Descriptor codes
GD_DEVICE		=0x01	# Get device descriptor: Device
GD_CONFIGURATION	=0x02	# Get device descriptor: Configuration
GD_STRING		=0x03	# Get device descriptor: String
GD_HID	            	=0x21	# Get descriptor: HID
GD_REPORT	        =0x22	# Get descriptor: Report

# SETUP packet header offsets
bmRequestType           =0
bRequest       	        =1
wValueL			=2
wValueH			=3
wIndexL			=4
wIndexH			=5
wLengthL		=6
wLengthH		=7

# HID bRequest values
GET_REPORT		=1
GET_IDLE		=2
GET_PROTOCOL            =3
SET_REPORT		=9
SET_IDLE		=0x0A
SET_PROTOCOL            =0x0B
INPUT_REPORT            =1

# PINCTL bits
bmEP3INAK   =0x80
bmEP2INAK   =0x40
bmEP1INAK   =0x20
bmFDUPSPI   =0x10
bmINTLEVEL  =0x08
bmPOSINT    =0x04
bmGPXB      =0x02
bmGPXA      =0x01

# rUSBCTL bits
bmHOSCSTEN  =0x80
bmVBGATE    =0x40
bmCHIPRES   =0x20
bmPWRDOWN   =0x10
bmCONNECT   =0x08
bmSIGRWU    =0x04

# USBIRQ bits
bmURESDNIRQ =0x80
bmVBUSIRQ   =0x40
bmNOVBUSIRQ =0x20
bmSUSPIRQ   =0x10
bmURESIRQ   =0x08
bmBUSACTIRQ =0x04
bmRWUDNIRQ  =0x02
bmOSCOKIRQ  =0x01

# MODE bits
bmHOST          =0x01
bmLOWSPEED      =0x02
bmHUBPRE        =0x04
bmSOFKAENAB     =0x08
bmSEPIRQ        =0x10
bmDELAYISO      =0x20
bmDMPULLDN      =0x40
bmDPPULLDN      =0x80

# PERADDR/HCTL bits
bmBUSRST        =0x01
bmFRMRST        =0x02
bmSAMPLEBUS     =0x04
bmSIGRSM        =0x08
bmRCVTOG0       =0x10
bmRCVTOG1       =0x20
bmSNDTOG0       =0x40
bmSNDTOG1       =0x80

# rHXFR bits
# Host XFR token values for writing the HXFR register (R30).
# OR this bit field with the endpoint number in bits 3:0
tokSETUP  =0x10  # HS=0, ISO=0, OUTNIN=0, SETUP=1
tokIN     =0x00  # HS=0, ISO=0, OUTNIN=0, SETUP=0
tokOUT    =0x20  # HS=0, ISO=0, OUTNIN=1, SETUP=0
tokINHS   =0x80  # HS=1, ISO=0, OUTNIN=0, SETUP=0
tokOUTHS  =0xA0  # HS=1, ISO=0, OUTNIN=1, SETUP=0
tokISOIN  =0x40  # HS=0, ISO=1, OUTNIN=0, SETUP=0
tokISOOUT =0x60  # HS=0, ISO=1, OUTNIN=1, SETUP=0

# rRSL bits
bmRCVTOGRD   =0x10
bmSNDTOGRD   =0x20
bmKSTATUS    =0x40
bmJSTATUS    =0x80
# Host error result codes, the 4 LSB's in the HRSL register.
hrSUCCESS   =0x00
hrBUSY      =0x01
hrBADREQ    =0x02
hrUNDEF     =0x03
hrNAK       =0x04
hrSTALL     =0x05
hrTOGERR    =0x06
hrWRONGPID  =0x07
hrBADBC     =0x08
hrPIDERR    =0x09
hrPKTERR    =0x0A
hrCRCERR    =0x0B
hrKERR      =0x0C
hrJERR      =0x0D
hrTIMEOUT   =0x0E
hrBABBLE    =0x0F

# HIRQ bits
bmBUSEVENTIRQ   =0x01   # indicates BUS Reset Done or BUS Resume
bmRWUIRQ        =0x02
bmRCVDAVIRQ     =0x04
bmSNDBAVIRQ     =0x08
bmSUSDNIRQ      =0x10
bmCONDETIRQ     =0x20
bmFRAMEIRQ      =0x40
bmHXFRDNIRQ     =0x80

class GoodFETMAXUSB(GoodFET):
    MAXUSBAPP=0x40;

    def setup2str(self,SUD):
        """Converts the header of a setup packet to a string."""
        if not isinstance(SUD, USBSetup):
            SUD = USBSetup(''.join(SUD))
        return SUD.summary()

    def MAXUSBsetup(self):
        """Move the FET into the MAXUSB application."""
        self.writecmd(self.MAXUSBAPP,0x10,0,self.data); #MAXUSB/SETUP
        print "Connected to MAX342x Rev. %x" % (self.rreg(rREVISION));
        self.wreg(rPINCTL,0x18); #Set duplex and negative INT level.

    def MAXUSBtrans8(self,byte):
        """Read and write 8 bits by MAXUSB."""
        data=self.MAXUSBtrans([byte]);
        return ord(data[0]);

    def MAXUSBtrans(self,data):
        """Exchange data by MAXUSB."""
        self.data=data;
        self.writecmd(self.MAXUSBAPP,0x00,len(data),data);
        return self.data;

    def rreg(self,reg):
        """Peek 8 bits from a register."""
        data=[reg<<3,0];
        self.writecmd(self.MAXUSBAPP,0x00,len(data),data);
        return ord(self.data[1]);
    def rregAS(self,reg):
        """Peek 8 bits from a register, setting AS."""
        data=[(reg<<3)|1,0];
        self.writecmd(self.MAXUSBAPP,0x00,len(data),data);
        return ord(self.data[1]);
    def wreg(self,reg,value):
        """Poke 8 bits into a register."""
        data=[(reg<<3)|2,value];
        self.writecmd(self.MAXUSBAPP,0x00,len(data),data);
        return value;
    def wregAS(self,reg,value):
        """Poke 8 bits into a register, setting AS."""
        data=[(reg<<3)|3,value];
        self.writecmd(self.MAXUSBAPP,0x00,len(data),data);
        return value;
    def readbytes(self,reg,length):
        """Peek some bytes from a register."""
        data=[(reg<<3)]+range(0,length);
        self.writecmd(self.MAXUSBAPP,0x00,len(data),data);
        toret=self.data[1:len(self.data)];
        ashex="";
        for foo in toret:
            ashex=ashex+(" %02x"%ord(foo));
        print "GET %02x==%s" % (reg,ashex);
        return toret;
    def readbytesAS(self,reg,length):
        """Peek some bytes from a register, acking prior transfer."""
        data=[(reg<<3)|1]+range(0,length);
        self.writecmd(self.MAXUSBAPP,0x00,len(data),data);
        toret=self.data[1:len(self.data)];
        ashex="";
        for foo in toret:
            ashex=ashex+(" %02x"%ord(foo));
        print "GET %02x==%s" % (reg,ashex);
        return toret;
    def ctl_write_nd(self,request):
        """Control Write with no data stage.  Assumes PERADDR is set
        and the SUDFIFO contains the 8 setup bytes.  Returns with
        result code = HRSLT[3:0] (HRSL register).  If there is an
        error, the 4MSBits of the returned value indicate the stage 1
        or 2."""

        # 1. Send the SETUP token and 8 setup bytes.
        # Should ACK immediately.
        self.writebytes(rSUDFIFO,request);
        resultcode=self.send_packet(tokSETUP,0); #SETUP packet to EP0.
        if resultcode: return resultcode;

        # 2. No data stage, so the last operation is to send an IN
        # token to the peripheral as the STATUS (handhsake) stage of
        # this control transfer.  We should get NAK or the DATA1 PID.
        # When we get back to the DATA1 PID the 3421 automatically
        # sends the closing NAK.
        resultcode=self.send_packet(tokINHS,0); #Function takes care of retries.
        if resultcode: return resultcode;

        return 0;


    def ctl_read(self,request):
        """Control read transfer, used in Host mode."""
        resultcode=0;
        bytes_to_read=request[6]+256*request[7];

        ##SETUP packet
        self.writebytes(rSUDFIFO,request);     #Load the FIFO
        resultcode=self.send_packet(tokSETUP,0); #SETUP packet to EP0
        if resultcode:
            print "Failed to get ACK on SETUP request in ctl_read()."
            return resultcode;

        self.wreg(rHCTL,bmRCVTOG1);              #FIRST data packet in CTL transfer uses DATA1 toggle.
        resultcode=self.IN_Transfer(0,bytes_to_read);
        if resultcode:
            print "Failed on IN Transfer in ctl_read()";
            return resultcode;

        self.IN_nak_count=self.nak_count;

        #The OUT status stage.
        resultcode=self.send_packet(tokOUTHS,0);
        if resultcode:
            print "Failed on OUT Status stage in ctl_read()";
            return resultcode;

        return 0; #Success

    xfrdata=[]; #Ugly variable used only by a few functions.  FIXME
    def IN_Transfer(self,endpoint,INbytes):
        """Does an IN transfer to an endpoint, used for Host mode."""
        xfrsize=INbytes;
        xfrlen=0;
        self.xfrdata=[];

        while 1:
            resultcode=self.send_packet(tokIN,endpoint); #IN packet to EP. NAKS taken care of.
            if resultcode: return resultcode;

            pktsize=self.rreg(rRCVBC); #Numer of RXed bytes.

            #Very innefficient, move this to C if performance is needed.
            for j in range(0,pktsize):
                self.xfrdata=self.xfrdata+[self.rreg(rRCVFIFO)];
            xfrsize=self.xfrdata[0];
            self.wreg(rHIRQ,bmRCVDAVIRQ); #Clear IRQ
            xfrlen=xfrlen+pktsize; #Add byte count to total transfer length.

            print "%i / %i" % (xfrlen,xfrsize)

            #Packet is complete if:
            # 1. The device sent a short packet, <maxPacketSize
            # 2. INbytes have been transfered.
            if (pktsize<self.maxPacketSize) or (xfrlen>=xfrsize):
                self.last_transfer_size=xfrlen;
                ashex="";
                for foo in self.xfrdata:
                    ashex=ashex+(" %02x"%foo);
                print "INPACKET EP%i==%s (0x%02x bytes remain)" % (endpoint,ashex,xfrsize);
                return resultcode;

    RETRY_LIMIT=3;
    NAK_LIMIT=300;
    def send_packet(self,token,endpoint):
        """Send a packet to an endpoint as the Host, taking care of NAKs.
        Don't use this for device code."""
        self.retry_count=0;
        self.nak_count=0;

        #Repeat until NAK_LIMIT or RETRY_LIMIT is reached.
        while self.nak_count<self.NAK_LIMIT and self.retry_count<self.RETRY_LIMIT:
            self.wreg(rHXFR,(token|endpoint)); #launch the transfer
            while not (self.rreg(rHIRQ) & bmHXFRDNIRQ):
                # wait for the completion IRQ
                pass;
            self.wreg(rHIRQ,bmHXFRDNIRQ);           #Clear IRQ
            resultcode = (self.rreg(rHRSL) & 0x0F); # get the result
            if (resultcode==hrNAK):
                self.nak_count=self.nak_count+1;
            elif (resultcode==hrTIMEOUT):
                self.retry_count=self.retry_count+1;
            else:
                #Success!
                return resultcode;
        return resultcode;

    def writebytes(self,reg,tosend):
        """Poke some bytes into a register."""
        data="";
        if type(tosend)==str:
            data=chr((reg<<3)|3)+tosend;
            print "PUT %02x:=%s (0x%02x bytes)" % (reg,tosend,len(data))
        else:
            data=[(reg<<3)|3]+tosend;
            ashex="";
            for foo in tosend:
                ashex=ashex+(" %02x"%foo);
            print "PUT %02x:=%s (0x%02x bytes)" % (reg,ashex,len(data))
        self.writecmd(self.MAXUSBAPP,0x00,len(data),data);
    def usb_connect(self):
        """Connect the USB port."""

        #disconnect D+ pullup if host turns off VBUS
        self.wreg(rUSBCTL,bmVBGATE|bmCONNECT);
    def usb_disconnect(self):
        """Disconnect the USB port."""
        self.wreg(rUSBCTL,bmVBGATE);
    def STALL_EP0(self,SUD=None):
        """Stall for an unknown SETUP event."""
        if SUD==None:
            print "Stalling EP0.";
        else:
            print "Stalling EPO for %s" % self.setup2str(SUD);
        self.wreg(rEPSTALLS,0x23); #All three stall bits.
    def SETBIT(self,reg,val):
        """Set a bit in a register."""
        self.wreg(reg,self.rreg(reg)|val);
    def vbus_on(self):
        """Turn on the target device."""
        self.wreg(rIOPINS2,(self.rreg(rIOPINS2)|0x08));
    def vbus_off(self):
        """Turn off the target device's power."""
        self.wreg(rIOPINS2,0x00);
    def reset_host(self):
        """Resets the chip into host mode."""
        self.wreg(rUSBCTL,bmCHIPRES); #Stop the oscillator.
        self.wreg(rUSBCTL,0x00);      #restart it.
        while self.rreg(rUSBIRQ)&bmOSCOKIRQ:
            #Hang until the PLL stabilizes.
            pass;

class GoodFETMAXUSBHost(GoodFETMAXUSB):
    """This is a class for implemented a minimal USB host.
    It's intended for fuzzing, rather than for daily use."""
    def hostinit(self):
        """Initialize the MAX3421 as a USB Host."""
        self.usb_connect();
        self.wreg(rPINCTL,(bmFDUPSPI|bmPOSINT));
        self.reset_host();
        self.vbus_off();
        time.sleep(0.2);
        self.vbus_on();

        #self.hostrun();
    def hostrun(self):
        """Run as a minimal host and dump the config tables."""
        while 1:
            self.detect_device();
            time.sleep(0.2);
            self.enumerate_device();
            self.wait_for_disconnect();
    def detect_device(self):
        """Waits for a device to be inserted and then returns."""
        busstate=0;

        #Activate host mode and turn on 15K pulldown resistors on D+ and D-.
        self.wreg(rMODE,(bmDPPULLDN|bmDMPULLDN|bmHOST));
        #Clear connection detect IRQ.
        self.wreg(rHIRQ,bmCONDETIRQ);

        print "Waiting for a device connection.";
        while busstate==0:
            self.wreg(rHCTL,bmSAMPLEBUS); #Update JSTATUS and KSTATUS bits.
            busstate=self.rreg(rHRSL) & (bmJSTATUS|bmKSTATUS);

        if busstate==bmJSTATUS:
            print "Detected Full-Speed Device.";
            self.wreg(rMODE,(bmDPPULLDN|bmDMPULLDN|bmHOST|bmSOFKAENAB));
        elif busstate==bmKSTATUS:
            print "Detected Low-Speed Device.";
            self.wreg(rMODE,(bmDPPULLDN|bmDMPULLDN|bmHOST|bmLOWSPEED|bmSOFKAENAB));
        else:
            print "Not sure whether this is Full-Speed or Low-Speed.  Please investigate.";
    def wait_for_disconnect(self):
        """Wait for a device to be disconnected."""
        print "Waiting for a device disconnect.";

        self.wreg(rHIRQ,bmCONDETIRQ); #Clear disconnect IRQ
        while not (self.rreg(rHIRQ) & bmCONDETIRQ):
            #Wait for IRQ to change.
            pass;

        #Turn off markers.
        self.wreg(rMODE,bmDPPULLDN|bmDMPULLDN|bmHOST);
        print "Device disconnected.";
        self.wreg(rIOPINS2,(self.rreg(rIOPINS2) & ~0x04)); #HL1_OFF
        self.wreg(rIOPINS1,(self.rreg(rIOPINS1) & ~0x02)); #HL4_OFF

    def enumerate_device(self):
        """Enumerates a device on the present port."""

        Set_Address_to_7 = [0x00,0x05,0x07,0x00,0x00,0x00,0x00,0x00];
        Get_Descriptor_Device = [0x80,0x06,0x00,0x01,0x00,0x00,0x00,0x00]; #len filled in
        Get_Descriptor_Config = [0x80,0x06,0x00,0x02,0x00,0x00,0x00,0x00];


        print "Issuing USB bus reset.";
        self.wreg(rHCTL,bmBUSRST);
        while self.rreg(rHCTL) & bmBUSRST:
            #Wait for reset to complete.
            pass;

        time.sleep(0.2);

        #Get the device descriptor.
        self.wreg(rPERADDR,0); #First request to address 0.
        self.maxPacketSize=8; #Only safe value for first check.
        Get_Descriptor_Device[6]=8; # wLengthL
        Get_Descriptor_Device[7]=0; # wLengthH

        print "Fetching 8 bytes of Device Descriptor.";
        self.ctl_read(Get_Descriptor_Device); # Get device descriptor into self.xfrdata;
        self.maxPacketSize=self.xfrdata[7];
        print "EP0 maxPacketSize is %02i bytes." % self.maxPacketSize;

        # Issue another USB bus reset
        print "Resetting the bus again."
        self.wreg(rHCTL,bmBUSRST);
        while self.rreg(rHCTL) & bmBUSRST:
            #Wait for reset to complete.
            pass;
        time.sleep(0.2);

        # Set_Address to 7 (Note: this request goes to address 0, already set in PERADDR register).
        print "Setting address to 0x07";
        HR = self.ctl_write_nd(Set_Address_to_7);   # CTL-Write, no data stage
        #if(print_error(HR)) return;

        time.sleep(0.002);           # Device gets 2 msec recovery time
        self.wreg(rPERADDR,7);       # now all transfers go to addr 7


        #Get the device descriptor at the assigned address.
        Get_Descriptor_Device[6]=0x12; #Fill in real descriptor length.
        print "Fetching Device Descriptor."
        self.ctl_read(Get_Descriptor_Device); #Result in self.xfrdata;

        self.descriptor=self.xfrdata;
        self.VID 	= self.xfrdata[8] + 256*self.xfrdata[9];
        self.PID 	= self.xfrdata[10]+ 256*self.xfrdata[11];
        iMFG 	= self.xfrdata[14];
        iPROD 	= self.xfrdata[15];
        iSERIAL	= self.xfrdata[16];

        self.manufacturer=self.getDescriptorString(iMFG);
        self.product=self.getDescriptorString(iPROD);
        self.serial=self.getDescriptorString(iSERIAL);

        self.printstrings();

    def printstrings(self):
        print "Vendor  ID is %04x." % self.VID;
        print "Product ID is %04x." % self.PID;
        print "Manufacturer: %s" % self.manufacturer;
        print "Product:      %s" % self.product;
        print "Serial:       %s" % self.serial;

    def getDescriptorString(self, index):
        """Grabs a string from the descriptor string table."""
        # Get_Descriptor-String template. Code fills in idx at str[2].
        Get_Descriptor_String = [0x80,0x06,index,0x03,0x00,0x00,0x40,0x00];

        if index==0: return "MISSING STRING";

        status=self.ctl_read(Get_Descriptor_String);
        if status: return None;

        #Since we've got a string
        toret="";
        for c in self.xfrdata[2:len(self.xfrdata)]:
            if c>0: toret=toret+chr(c);
        return toret;

class GoodFETMAXUSBHID(GoodFETMAXUSB):
    """This is an example HID keyboard driver, loosely based on the
    MAX3420 examples."""
    def hidinit(self):
        """Initialize a USB HID device."""
        self.usb_disconnect();
        self.usb_connect();

        self.hidrun();

    def hidrun(self):
        """Main loop of the USB HID emulator."""
        print "Starting a HID device.  This won't return.";
        while 1:
            self.service_irqs();
    def do_SETUP(self):
        """Handle USB Enumeration"""

        #Grab the SETUP packet from the buffer.
        SUD=self.readbytes(rSUDFIFO,8);

        #Parse the SETUP packet
        print "Handling a setup packet of %s" % self.setup2str(SUD);

        setuptype=(ord(SUD[bmRequestType])&0x60);
        if setuptype==0x00:
            self.std_request(SUD);
        elif setuptype==0x20:
            self.class_request(SUD);
        elif setuptype==0x40:
            self.vendor_request(SUD);
        else:
            print "Unknown request type 0x%02x." % ord(SUD[bmRequestType])
            self.STALL_EP0(SUD);
    def class_request(self,SUD):
        """Handle a class request."""
        print "Stalling a class request.";
        self.STALL_EP0(SUD);
    def vendor_request(self,SUD):
        print "Stalling a vendor request.";
        self.STALL_EP0(SUD);
    def std_request(self,SUD):
        """Handles a standard setup request."""
        scapySUD = USBSetup(''.join(SUD));
        setuptype= scapySUD.bRequest;
        if setuptype==SR_GET_DESCRIPTOR: self.send_descriptor(scapySUD);
        #elif setuptype==SR_SET_FEATURE: self.feature(1);
        elif setuptype==SR_SET_CONFIGURATION: self.set_configuration(SUD);
        elif setuptype==SR_GET_STATUS: self.get_status(scapySUD);
        elif setuptype==SR_SET_ADDRESS: self.rregAS(rFNADDR);
        elif setuptype==SR_GET_INTERFACE: self.get_interface(SUD);
        else:
            print "Stalling Unknown standard setup request type %02x" % setuptype;

            self.STALL_EP0(SUD);

    def get_interface(self,SUD):
        """Handles a setup request for SR_GET_INTERFACE."""
        if ord(SUD[wIndexL]==0):
            self.wreg(rEP0FIFO,0);
            self.wregAS(rEP0BC,1);
        else:
            self.STALL_EP0(SUD);

    RepD=[
    0x05,0x01,		# Usage Page (generic desktop)
	0x09,0x06,		# Usage (keyboard)
	0xA1,0x01,		# Collection
	0x05,0x07,		#   Usage Page 7 (keyboard/keypad)
	0x19,0xE0,		#   Usage Minimum = 224
	0x29,0xE7,		#   Usage Maximum = 231
	0x15,0x00,		#   Logical Minimum = 0
	0x25,0x01,		#   Logical Maximum = 1
	0x75,0x01,		#   Report Size = 1
	0x95,0x08,		#   Report Count = 8
	0x81,0x02,		#  Input(Data,Variable,Absolute)
	0x95,0x01,		#   Report Count = 1
	0x75,0x08,		#   Report Size = 8
	0x81,0x01,		#  Input(Constant)
	0x19,0x00,		#   Usage Minimum = 0
	0x29,0x65,		#   Usage Maximum = 101
	0x15,0x00,		#   Logical Minimum = 0,
	0x25,0x65,		#   Logical Maximum = 101
	0x75,0x08,		#   Report Size = 8
	0x95,0x01,		#   Report Count = 1
	0x81,0x00,		#  Input(Data,Variable,Array)
	0xC0]
    def send_descriptor(self,SUD):
        """Send the USB descriptors based upon the setup data."""
        desclen=0;
        reqlen=SUD.getRequestLength(); #16-bit length

        desctype=SUD.wValueH;
        if desctype==GD_DEVICE:
            pkt = USBDeviceDescriptor()
            #print "Correct Response DD?:", pkt.answers(SUD)
            desclen=pkt.getDescLen(); #Returns bLength #self.DD[0]
            ddata=pkt.getBuiltArray(); #self.DD
        elif desctype==GD_CONFIGURATION:
            pkt = USBConfigurationDescriptor()
            desclen=pkt.getDescLen(); #Returns wTotalLength
            ddata=pkt.getBuiltArray(); #self.CD
        elif desctype==GD_STRING:
            if SUD.wValueL == 0:
                pkt = USBStringDescriptorLanguage()
                pkt.addLanguage(0x0409)
            else:
                pkt = USBStringDescriptor()
                if SUD.wValueL == 1: #Manufacturer ID
                    pkt.string = "Maxim"
                elif SUD.wValueL == 2: #Product ID
                    pkt.string = "MAX3420E Enum Code"
                elif SUD.wValueL == 2: #Serial Number ID
                    pkt.string = "S/N 3420E"
            desclen=pkt.getDescLen(); #self.strDesc[ord(SUD[wValueL])][0]
            ddata=str(pkt) #self.strDesc[ord(SUD[wValueL])]
        elif desctype==GD_REPORT:
            desclen=43; #self.CD[25] (wDescriptorLength)
            ddata=self.RepD;

        #TODO Configuration, String, Hid, and Report

        if desclen>0:
            sendlen=min(reqlen,desclen);
            self.writebytes(rEP0FIFO,ddata);
            self.wregAS(rEP0BC,sendlen);
        else:
            print "Stalling in send_descriptor() for lack of handler for %02x." % desctype;
            self.STALL_EP0(SUD);

    def set_configuration(self,SUD):
        """Set the configuration."""
        bmSUSPIE=0x10;
        configval=ord(SUD[wValueL]);
        if(configval>0):
            self.SETBIT(rUSBIEN,bmSUSPIE);
        self.rregAS(rFNADDR);

    def get_status(self,SUD):
        """Get the USB Setup Status."""
        testbyte=SUD.bmRequestType
        #Toward Device
        if testbyte==0x80:
            self.wreg(rEP0FIFO,0x03); #Enable RWU and self-powered
            self.wreg(rEP0FIFO,0x00); #Second byte is always zero.
            self.wregAS(rEP0BC,2);    #Load byte count, arm transfer, and ack CTL.
        #Toward Interface
        elif testbyte==0x81:
            self.wreg(rEP0FIFO,0x00);
            self.wreg(rEP0FIFO,0x00); #Second byte is always zero.
            self.wregAS(rEP0BC,2);
        #Toward Endpoint
        elif testbyte==0x82:
            if(SUD.wIndexL==0x83):
                self.wreg(rEP0FIFO,0x01); #Stall EP3
                self.wreg(rEP0FIFO,0x00); #Second byte is always zero.
                self.wregAS(rEP0BC,2);
            else:
                self.STALL_EP0(SUD);
        else:
            self.STALL_EP0(SUD);
    def service_irqs(self):
        """Handle USB interrupt events."""

        epirq=self.rreg(rEPIRQ);
        usbirq=self.rreg(rUSBIRQ);

        #Are we being asked for setup data?
        if(epirq&bmSUDAVIRQ): #Setup Data Requested
            self.wreg(rEPIRQ,bmSUDAVIRQ); #Clear the bit
            self.do_SETUP();
        if(epirq&bmIN3BAVIRQ): #EN3-IN packet
            self.do_IN3();


    typephase=0;
    typestring="                      Python does USB HID!";
    typepos=0;

    def asc2hid(self,ascii):
        """Translate ASCII to an USB keycode."""
        a=ascii;
        if a>='a' and a<='z':
            return ord(a)-ord('a')+4;
        elif a>='A' and a<='Z':
            return ord(a)-ord('A')+4;
        elif a==' ':
            return 0x2C; #space
        else:
            return 0; #key-up
    def type_IN3(self):
        """Type next letter in buffer."""
        if self.typepos>=len(self.typestring):
            self.typeletter(0);
        elif self.typephase==0:
            self.typephase=1;
            self.typeletter(0);
        else:
            typephase=0;
            self.typeletter(self.typestring[self.typepos]);
            self.typepos=self.typepos+1;
        return;
    def typeletter(self,key):
        """Type a letter on IN3.  Zero for keyup."""
        #if type(key)==str: key=ord(key);
        #Send a key-up.
        self.wreg(rEP3INFIFO,0);
        self.wreg(rEP3INFIFO,0);
        self.wreg(rEP3INFIFO,self.asc2hid(key));
        self.wreg(rEP3INBC,3);
    def do_IN3(self):
        """Handle IN3 event."""
        #Don't bother clearing interrupt flag, that's done by sending the reply.
        self.type_IN3();
