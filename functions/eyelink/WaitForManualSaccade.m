function [endpoint startedMoving finishedMoving pos startedMovingIx ]...
            = waitForManualSaccade(el, maxtime, minsize)
% [endpoint, startTime, finishTime, pos, startIndex] 
%    =waitForManualSaccade(el, maxtime. minsize)
% for use with touchscreen.
% 
% wait for a movement, and then for hand position to become steady 
% again.
% times are in seconds. positions in screen pixels.
% 
% endpoint: if it is scalar, then it is a key code
% if it is a 2-vector, it is the end-movement position.
% returned times are in seconds from GetSecs.
% pos is the list of recorded mouse positions [t x y]
% startedMovingIx is the index in 'pos' that corresponds
% to the startTime of the movement.

startTime      = GetSecs;
startedMoving  = 0; % time movt started
finishedMoving = 0; % time movt finished
isMoving       = 0; % true if moving
key=0;
lastchecktime = GetSecs;
pos=[];

while( ~finishedMoving && key==0 && ... % key press or
       (lastchecktime<(startTime+maxtime)) ) % timeout?
  dt=0;
  while(dt < 0.001) % wait for millisecond to update
    t = GetSecs;
    dt= t-lastchecktime;
  end
  lastchecktime = t;
  [p(1) p(2) b]=GetMouse;
  pos=[pos; t p(1) p(2)]; % columns [time, xpos, ypos]
  
  if(size(pos,1)>60)
    v = pyth( diff(pos([end-60:end],[2 3]),1), 2 )./diff(pos([end-60:end],1));
    isMoving = mean( v ) > 0.2;
  end
  
  if((isMoving>0) && ~(startedMoving>0))
    startedMoving=GetSecs;
    startedMovingIx=size(p,1);
  end
  
  distanceMoved = norm(p - pos(1,[2:3]));
  
  if(~(isMoving>0) && (startedMoving>0) && (distanceMoved>minsize))
    finishedMoving=GetSecs;
  end
  
  [z z kcode]=KbCheck; % check for escape key
  if(any(kcode)) key=find(kcode,1); end
end

if(key~=0) endpoint = key;
else endpoint = pos(end,:);
end