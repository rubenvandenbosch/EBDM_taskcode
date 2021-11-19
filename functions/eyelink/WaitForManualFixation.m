function result=waitForManualFixation(el, location, accuracy, duration)
% result=waitForManualFixation(el, location. accuracy, duration)
% for use with touchscreen.
% 
% use at the start of the experiment, to wait for a steady hand position
% near a specified location.
% times are in seconds. positions in screen pixels.
% 
% result: if it is scalar, then it is a key code
% if it is a 2-vector, it is the last cursor position.

timeFixated = 0;
fixating=0;
key=0;
lastchecktime = GetSecs;
pos = [];

while(timeFixated<duration && key==0) 
  [p(1) p(2) b]=GetMouse;
  t = GetSecs; 
  dt= t-lastchecktime;
  lastchecktime = t;
  pos = [pos; t,p(1),p(2)];

  if(length(location)==2) % is the location important?
    correctLocation  = (norm(p-location)<accuracy);
  else
    correctLocation = 1;
  end
  
  if(size(pos,1)>5)
    v = pyth( diff(pos([end-5:end],[2 3]),1), 2 )./diff(pos([end-5:end],1));
    fixating = mean( v ) < 2;
  end
  if(fixating && correctLocation)
    timeFixated = timeFixated + dt;
  else
    timeFixated = 0;
  end
  
  [z z kcode]=KbCheck; % check for escape key
  if(any(kcode)) key=find(kcode,1); end
end

if(key~=0) result = key;
else result=p;
end