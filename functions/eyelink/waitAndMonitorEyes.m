function [fixations keys]=waitAndMonitorEyes(el,waitmsec)
t=time;
fixations=[];
keys=[];
[z z kcode]=kbcheck;
oldkcode=kcode; p1=[];
while t+waitmsec>time
    st=eyelink('getnextdatatype');
    if(st==el.STARTFIX)
        s=eyelink('getfloatdata',st);
        p1 = [s.sttime s.gstx s.gsty nan nan nan];
    elseif(st==el.ENDFIX)
        s=eyelink('getfloatdata',st);
        p1=[];
        fixations = [fixations; s.sttime s.gstx s.gsty s.entime s.genx, s.geny];
    end;
    %check for keydown
    [z,z,kcode]=kbcheck;
    keysdown=find(kcode&~oldkcode);
    if(length(keysdown)>0) keys=[keys;time keysdown(1)]; end
    oldkcode=kcode;
    wait 10;
end
if(length(p1)>0)fixations=[fixations;p1];end;

