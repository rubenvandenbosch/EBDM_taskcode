function result=WaitForFixation2(el, location, accuracy)
% Eyelink wait for fixation. 
% result = WaitForFixation(el, location, accuracy, duration)
% Used at the beginning of experiment to wait for eye to fixate
% on a spot. 
% location (if not [0]) specifies required target, 
% accuracy specifies radius permitted around location, 
% duration is minimum time needed to fixate.
%
% uses global DCO - drift correct offset
% this version dequeues data from eyelink buffer.


global DCO;
if(~exist('DCO','var') || length(DCO)~=2) DCO=[0 0]; end;

% drain queue
flushEyelinkQueue();

  [z z keys]=KbCheck;
  if(any(keys))
    if(keys('C'))
      driftcorrect(location)
    else
      cont=0; result=0;
    end;
  end;

while(1)
  if(eyelink('NewFloatSampleAvailable'))
    s=eyelink('NewestFloatSample');
    if(isstruct(s))
      p=[s.gx(el.eye)+DCO(1) s.gy(el.eye)+DCO(2)];
      result = norm(p-location)<accuracy;
      return
    end;
  end
  [z z keys]=KbCheck;
  if(any(keys)) result = 0;   return;  end
end;


%% invoke built in drift correction
function driftcorrect(location,el)
     eyelink('stoprecording');
     e=27; 
     screen('fillrect', el.window, [255 128 0],[location-[10 10] location+[10 10]]);
     screen('fillrect', el.window, [0   0   0],[location-[2 2] location+[2 2]]);     
     screen('flip', el.window);
     while e==27 & eyelink('isconnected'),
        e=eyelink('DriftCorrStart',floor(location(1)),floor(location(2)),1,1,1);
     end;
     e=eyelink('CalResult'); 
     if(e==0) eyelink('ApplyDriftCorr');
     else warning('poor calibration.');eyelink('ApplyDriftCorr');
     end;
     eyelink('startrecording');

%% correction if bad fixations
function correction(el)
     eyelink('stoprecording');
     ssz=Screen('WindowSize', el.window);
     s1=[50,50]; s2=ssz-s1;
     EyelinkDrawCalTarget(el,s1(1), s1(2));
     WaitSecs(0.3); e1=wfix(el);
     EyelinkDrawCalTarget(el,s2(1), s2(2));
     WaitSecs(0.3); e2=wfix(el);
     % conversion given by
     % e3 = e1 + (e2-e1) .* ( (s3-s1) ./ (s2-s1) )
     eAtScrCentre = e1 + (e2-e1).*( ([0,0]-s1)./(s2-s1) );
     eScale = (e2-e1)./(s2-s1) ;
     eyelink('startrecording');

%% wait for 2 sec and take average position for calibration purposes
% and return the actual coordinates given by eyelink
function a=wfix(el)
    n=0; pcum=[0 0]; a=0;
    time=0;ended=0; DURATION=2000;
    while ~ended
      if(eyelink('NewFloatSampleAvailable'))
        s=eyelink('NewestFloatSample');
        a=[s.gx(el.eye) s.gy(el.eye)];
        if(~time) time=s.time+DURATION;
        else      ended=s.time>time;
        end;
        if (norm(a)<3000) 
          pcum=pcum+a;
          n=n+1;
        end;
      end;
      WaitSecs(0.001);
    end;
    a=pcum/n;
    
%% simple drift correct (single point - offset only)
function simpleDCO(el,location)
     global DCO;
     screen('fillrect', el.window, [255 128 0],[location-[10 10] location+[10 10]]);
     screen('fillrect', el.window, [0   0   0],[location-[2 2] location+[2 2]]);     
     screen('flip', el.window);
     WaitSecs(0.3); a=wfix(el);
     dco=location-a;
     if(norm(dco)>200) warning(['calibration is ' num2str(norm(dco)) 'px out']); end;
     DCO=dco
     
     