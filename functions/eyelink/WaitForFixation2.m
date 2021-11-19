function result=WaitForFixation2(el, location, accuracy, duration)
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

#not complete yet

global DCO;
if(~exist('DCO','var') || length(DCO)~=2) DCO=[0 0]; end;

% drain queue
flushEyelinkQueue();

s=Eyelink('newestfloatsample');
p0=[s.time s.gx(el.eye)+DCO(1) s.gy(el.eye)+DCO(2)];
p = repmat(p0,5,1);
cont=1;
fixtime=0;
result=0;
debugfixation=0;
count=0;
totaltime=0;
while cont    
  drained=0;
  while(~drained) % get queued samples and events
    [samples, events,drained]=Eyelink('GetQueuedData');
    if(isempty(events))continue;end;
    endfixs  =find(events(2,:) == el.ENDFIX);
    startfixs=find(events(2,:) == el.STARTFIX);
    if(length(startfixs)>0)
      
    end
    if(length(endfixs)>0)
      fixtime=0;
      isfixating=0;
      for(i=1:length(endsaccs))
        results= [events([1 14 15],endsaccs(i))]';
        dist=norm(events([14,15],endsaccs(i)) - events([9,10], endsaccs(i)));
        if(dist>minsize)
          return; 
        end;
      end
    end;
  end;
  
  if(Eyelink('NewFloatSampleAvailable'))
    s=Eyelink('NewestFloatSample');
    if(isstruct(s))
      dt=s.time-p(end,1);
      if(dt>0) % if it's a later timepoint, add to p-list
        p = [p(2:end,:); s.time s.gx(el.eye)+DCO(1), s.gy(el.eye)+DCO(2)];
        count=count+1;
        if(debugfixation)
          screen('fillrect', el.window, [128 0 0],[p(end,2) p(end,3) p(end,2)+5 p(end,3)+5]);
          screen('fillrect', el.window, [128 128 0],[location location+[5 5]]);
          screen('flip', el.window);
          %if(norm(p(2:3))<10000)p(end,2:3), end;%%%%%%%%% DEBUG
        end;
        if(count<=5) continue; end;
        if(isFixated(p,100))%position is stable
          if((location==-1 & all(p(end,2:3)>0 & p(end,2:3)<3000) )...
              | norm(p(end,2:3)-location)<accuracy) %within accuracy
            fixtime=fixtime + p(end,1)-p(end-1,1);
          end;
        else
          fixtime=0;
        end;
        if(fixtime>duration)
          cont=0; result=p(end,:)-[p0(1), 0 0]; %return time till fix and location
        end;
        totaltime=totaltime+p(end,1)-p(end-1,1);
        if(totaltime>6000)
          debugfixation=1;
        end;         % if no fixation within 4 seconds, start drawing the debug screen
        if(totaltime>9000)
          %correction(el); % if still no fixation after 8 seconds, run drift correction
          simpleDCO(el,location);
          %driftcorrect(location,el);
          totaltime=0;
        end
      end;
    end;
  end;
  [z z keys]=KbCheck;
  if(any(keys))
    if(keys('C'))
      driftcorrect(location)
    else
      cont=0; result=0;
    end;
  end;
end;
if(result(1)>0 && debugfixation)
    disp(['fix success loc=' num2str(location(1)) ',' num2str(location(2)) ';eye='...
        num2str(p(end,2)) ',' num2str(p(end,3))]);
end


%% invoke built in drift correction
function driftcorrect(location,el)
     Eyelink('stoprecording');
     e=27; 
     screen('fillrect', el.window, [255 128 0],[location-[10 10] location+[10 10]]);
     screen('fillrect', el.window, [0   0   0],[location-[2 2] location+[2 2]]);     
     screen('flip', el.window);
     while e==27 & Eyelink('isconnected'),
        e=Eyelink('DriftCorrStart',floor(location(1)),floor(location(2)),1,1,1);
     end;
     e=Eyelink('CalResult'); 
     if(e==0) Eyelink('ApplyDriftCorr');
     else warning('poor calibration.');Eyelink('ApplyDriftCorr');
     end;
     Eyelink('startrecording');

%% correction if bad fixations
function correction(el)
     Eyelink('stoprecording');
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
     Eyelink('startrecording');

%% wait for 2 sec and take average position for calibration purposes
% and return the actual coordinates given by eyelink
function a=wfix(el)
    n=0; pcum=[0 0]; a=0;
    time=0;ended=0; DURATION=2000;
    while ~ended
      if(Eyelink('NewFloatSampleAvailable'))
        s=Eyelink('NewestFloatSample');
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
     
     
