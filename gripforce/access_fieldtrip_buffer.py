# !/usr/bin/env python
import sys
#sys.path.append("../../dataAcq/buffer/python")
import numpy
import time
import json

major_version = sys.version_info.major
if major_version == 2:
    import FieldTrip2 as FieldTrip
elif major_version == 3:
    import FieldTrip3 as FieldTrip


# Define header, prepare for sending data to buffer
def defineHeader(hostname, port, samplerate, timeout=5000):
    ftc = FieldTrip.Client()
    print('Trying to connect to buffer on %s:%i ...' % (hostname, port))
    try:
        ftc.connect(hostname, port)
        print('\nConnected - trying to define header...')
        ftc.putHeader(2, samplerate, 10)
    except IOError:
        raise NameError('Failed connecting to or defining FieldTrip buffer')


# Establish connection with FieldTrip buffer
def connect_fieldtrip_buffer(hostname,port,samplerate,timeout=5000):
    defineHeader(hostname,port,samplerate)
    ftc = FieldTrip.Client()
    # Wait until the buffer connects correctly and returns a valid header
    hdr = None
    while hdr is None :
        print('Trying to connect to buffer on %s:%i ...'%(hostname,port))
        try:
            ftc.connect(hostname, port)
            print('\nConnected - trying to read header...')
            hdr = ftc.getHeader()
        except IOError:
            raise NameError('Failed connecting to FieldTrip buffer')
            
        if hdr is None:
            print('Invalid Header... waiting')
            time.sleep(1)
        else:
            print(hdr)
            #print hdr.labels
            
    return(ftc)

def wait_event(ftc, nEvents, type, value=None, timeout=1000):
    # wait for event that equals type (and value if != None)
    Tstart = time.time()
    err = None
    hdr = ftc.getHeader()
    if nEvents is None: 
        nEvents = hdr.nEvents
    didFound=None
    #print 'waiting for event type: ' + str(type)
    while didFound is None:
        evt = None
        to = max(0,min(100,timeout-1000*(time.time()-Tstart)))
        if to==0:
            break # timeout
        (curSamp,curEvents)=ftc.wait(-1,nEvents,to) # Block until there are new events to process
        if curEvents < nEvents: 
            # buffer events were flushed, reset counter
            nEvents = max(0,curEvents-1)
            continue
        if curEvents-nEvents >= 100 :
            print('Ignoring ' + str(curEvents-nEvents-100) + ' events, not accessible anymore')
            nEvents = curEvents-100
        if curEvents>nEvents :
            evts=ftc.getEvents([nEvents,curEvents-1]) 
            for e in evts:
                nEvents = nEvents + 1 # keep updating actually processed events
                # check possible error sent from other module
                if len(e.type)>6:
                    # if str(e.type[0:7],'utf-8') == '_MD_ERR':
                    if e.type[0:7] == '_MD_ERR':
                        err = str(json.loads(e.value))
                        didFound = 1
                        break
                # if str(e.type,'utf-8') != type:
                if e.type != type:
                    continue
                try:
                    val = json.loads(e.value)
                except:
                    # not a JSON converted, don't need to convert
                    val = e.value
                #print e.type
                #print val
                if value is not None and (val != value):
                    continue
                e.value = val
                evt = e
                didFound = 1
                break
            else:
               # event not yet found
               pass
        else:
            # timeout
            pass
            
    return (evt,nEvents,err)
