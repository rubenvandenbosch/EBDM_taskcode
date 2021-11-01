# !/usr/bin/env python
"""
A simple Python script to stream analogue input data from Gripforce device (or buttonbox) to fieldtrip buffer
"""
from access_fieldtrip_buffer import *
import serial
import numpy
import time


class Gripforce2ft(object):
    # simple helper class to send module fieldtrip event to BrainStream
    # url: fieldtrip url, i.e.: 'buffer://localhost:1972'
    # mdl_name: name of targeted BrainStream module

    def __init__(self, url):

        self.urlbuffer = url
        self.ftc = None

    def __del__(self):
        if self.ftc:
            self.ftc.disconnect()

    def connect(self, samplerate):
        try:
            # connect to fieldtrip buffer
            (host, port) = parse_fieldtrip_url(self.urlbuffer)
            self.ftc = connect_fieldtrip_buffer(host, port, samplerate)
        except:
            print("Failed connecting to buffer")

    def send_event(self, evt_type, evt_value):
        # send FieldTrip event to buffer
        evt = FieldTrip.Event()
        evt.type = evt_type #'_MD_EVT.' + str(destination_module)
        evt.value = json.dumps(evt_value)
        if self.ftc:
            self.ftc.putEvents(evt)

    def send_data(self, data):
        # send data to buffer
        if self.ftc:
            # putData(D) -- writes samples that must be given as a NUMPY array, samples x channels.
            self.ftc.putData(data)


##################################################################################
def parse_fieldtrip_url(url):
    url = url[url.find('//') + 2:]  # remove 'buffer://' prefix
    host = url[: url.find(':')]
    port = int(url[url.find(':') + 1:])
    return host, port


def get_sample(ser,channel,buttonboxdevice=False):
    btndown = ["A", "B", "C", "D", "E", "F", "G", "H"]
    btnup = ["a", "b", "c", "d", "e", "f", "g", "h"]

    ser.write(str.encode(channel))
    #ser.flush()
    value = round(float(ser.readline().strip()),3)
    if buttonboxdevice and (any(b in value for b in btndown) or any(b in value for b in btnup)):
        # buttonbox key was pressed, remove extra character
        for b in btnup:
            value = value.replace(b, "")
        for b in btndown:
           value = value.replace(b, "")

    return value

def get_simulated_sample(ser, channel):
    global simvalue1
    global simvalue2
    btndown = ["A", "B", "C", "D", "E", "F", "G", "H"]
    btnup = ["a", "b", "c", "d", "e", "f", "g", "h"]

    ser.write(str.encode(channel))
    #ser.flush()
    value = round(float(ser.readline().strip()), 3)
    if (any(b in value for b in btndown) or any(b in value for b in btnup)):
        # buttonbox key was pressed to simulate force
        if "A" in value and simvalue2 >= 50:
            simvalue2 = simvalue2 - 50
            value = value.replace("E","")

        if "B" in value and simvalue2 < 800:
            simvalue2 = simvalue2 + 50
            value = value.replace("A", "")

        if "E" in value and simvalue1 >= 50:
            simvalue1 = simvalue1 - 50
            value = value.replace("E","")

        if "F" in value and simvalue1 < 800:
            simvalue1 = simvalue1 + 50
            value = value.replace("A", "")

        for b in btnup:
            value = value.replace(b, "")
        for b in btndown:
            value = value.replace(b, "")

    if channel == "A1" or channel == "A":
        value = str(simvalue1)
    else:
        value = str(simvalue2)

    return value


# for simulating buttonbox analogue channel 1 and channel 2 values
simvalue1 = 0
simvalue2 = 0


# Connect to fieldtrip buffer
def main(url='buffer://localhost:1972', serialdevice='COM5', samplerate=50, simulation=False):

    channel1 = 'A' # 'A1' for buttonbox
    channel2 = 'A2'
    twochan = False # for dedicated gripforce device

    if len(sys.argv) > 1:
        url = sys.argv[1]
    if len(sys.argv) > 2:
        serialdevice = sys.argv[2]
    if len(sys.argv) > 3:
        samplerate = float(sys.argv[3])
    if len(sys.argv) > 4:
        simulation = sys.argv[4] == 'True'

    print('url = '+url)
    print('serial devic e= ' + serialdevice)
    print('sample rate = ' + str(samplerate))
    print('simulation = ' + str(simulation))
    try:
        # connect to fieldtrip buffer
        fte = Gripforce2ft(url)
        fte.connect(samplerate)
    except:
        print("Failed connecting to fieldtrip buffer")
        return(-1)

    try:
        # make a buttonbox
        ser = serial.Serial(serialdevice, 115200, timeout=0.10)
        #ser = serial.Serial("/dev/cu.usbserial-A900XEZ8", 115200, timeout=0.10)
        #ser = serial.Serial("/dev/cu.usbserial-A9O7FXD1", 115200, timeout=1.10)
        #ser = serial.Serial("COM2", 115200, timeout=0.10)
        time.sleep(5)
        print(ser.readline()) # read welcome message
        ser.flush()
    except:
        print("Failed connecting to serial device: " + serialdevice)
        return(-1)

    sample = numpy.zeros((1, 2))
    startTime = time.time()
    counter = 0
    while True:
        counter = counter + 1
        if not simulation:
            value = get_sample(ser, channel1)
        else:
            value = get_simulated_sample(ser, channel1)
        #print value
        sample[0, 0] = float(value)

        if twochan:
            if not simulation:
                value = get_sample(ser, channel2)
            else:
                value = get_simulated_sample(ser, channel2)
            #print value
        else:
            value = 0

        sample[0, 1] = float(value)
        fte.send_data(sample)
        print(sample)

        #time.sleep(1.0/samplerate)
        #print("extra time left: ", float(counter)/float(samplerate) - (time.time()-startTime))
        while (time.time()-startTime) < float(counter)/float(samplerate):
            waittime = float(counter)/float(samplerate) - (time.time()-startTime)
            if waittime > 0.001:
                #print "waiting: "+ str(waittime/2)
                time.sleep(waittime / 2)
            #pass


if __name__ == '__main__':
    main()

