function [results, points]=WaitUntilSaccadeNear(el, maxtime, location, threshold)
% [end_txy, points] =WaitUntilSaccadeNear(el, maxtime, location, threshold)
% this uses the eyelink parser to determine when the next saccade occurs
% returns array [end-saccade-time, end-saccade-x, end-saccade-y]
% but also records points in between, as [time1, x1, y1, pupil1 ; time2... ] .
%
% waits until saccade end AND eye lands within 'threshold' distance from 
% 'location', or time elapsed, or if saccade is late then
% until saccade has completed. If saccade has already started, and
% el.disallowEarlySaccades is set, then waits for the next saccade that 
% lands within the given area.
%
% uses global DCO - drift correct offset
global DCO;
if(~exist('DCO','var') || length(DCO)~=2)DCO=[0 0];end;

started=0;ended=0;
s=eyelink('NewestFloatSample');
p0=[s.time s.gx(el.eye) s.gy(el.eye), s.pa(el.eye)] + [0 DCO 0];
points=p0;
debug=isfield(el, 'debugSaccades');
disallowEarlySaccades = isfield(el, 'disallowEarlySaccades');

eye=el.eye;if eye==2; eye=1;end;
while ~ended
  drained=0;
  while(~drained)
    [s e drained]=Eyelink('GetQueuedData');
    if(started && prod(size(s))>0)
      pr=[s(1,:)',s(14+eye,:)'+DCO(1),s(16+eye,:)'+DCO(2),s(12+eye,:)'];
      okpoints = (s(2,:)==el.SAMPLE_TYPE)' & (abs(pr(:,2))<2000) & (abs(pr(:,3))<2000);
      pr=pr(okpoints,:);
      if(prod(size(pr))) points=[points;pr];end;
    end;
    if(prod(size(e))>0)
      starts=(e(2,:)==el.STARTSACC);
      ends=(e(2,:)==el.ENDSACC);
    else starts=[];ends=[];
    end
    if(sum(starts)>sum(ends)) started=1; end;
    if(~isempty(ends) && any(ends))
      for iends=1:length(ends)
        p1=[e([5,9,10],iends)]' + [0 DCO];
        p2=[e([6,14,15],iends)]' + [0 DCO];
        %[p1,p2] %%% DEBUG
        if (norm(location-p2(2:3))>threshold)
          %started=0; ended=0;
          %'unsatisfactory saccade' %%%%%%DEBUG
        elseif ((p1(1) < p0(1)) & disallowEarlySaccades)
          %'early saccade' %% DEBUG
        else % OK saccade
           %'ok saccade' %%%%%%DEBUG
           ended=1;
           results = p2;
        end
      end
    end
  end;

  if debug
    p=[points(end,2:3)];
    screen('fillrect', el.window, [255,255,255],[p p+[3 3]]);
    screen('fillrect', el.window, [255,0,0],[location location+[3 3]]);
    screen('flip', el.window);
  end;

%     st=eyelink('getnextdatatype');
%     if(st)
%         'extradata!'
%         if(st==el.LOSTDATAEVENT)
%            continue;
%         else
%             s=eyelink('getfloatdata',st);
%         end
%         if st==el.STARTSACC
%             started=1;
%         end;
%         if debug
%             screen('fillrect', el.window, 0,[location location+[10 10]]);
%         end
%         if st==el.ENDSACC
%             disp('endsacc');
%             p1 = [s.sttime s.gstx s.gsty];
%             p2 = [s.entime s.genx s.geny];
%             points = [points; p2 s2.pa(el.eye)];
%             if ((s.sttime<p0(1)) || ~started) & disallowEarlySaccades 
%                 'early saccade' %%%%%%%DEBUG
%                 continue;end;
%             if (norm(location-p2(2:3))>threshold)
%                 started=0; ended=0;
%                 'unsatisfactory saccade', p1,p2 %%%%%%DEBUG
%             else
%                 ended=1;
%                 results = p2;
%             end;
%         end;
%     end;
%     if eyelink('NewFloatSampleAvailable')
%         s2=eyelink('NewestFloatSample');
%         time = s2.time - p0(1);
%         if time>maxtime & ~started % if saccade already begun, allow it to complete
%             ended=1;
%             results = 0;
%         end;
%         points=[points; s2.time, s2.gx(el.eye), s2.gy(el.eye), s2.pa(el.eye)];
%         if debug
%             p=[s2.gx(el.eye) s2.gy(el.eye)];
%             %if(norm(p)<10000)  disp(p);end;
%             screen('fillrect', el.window, [255,255,255],[p p+[3 3]]);
%             screen('fillrect', el.window, [255,0,0],[location location+[3 3]]);
%             screen('flip', el.window);
%         end;
%     end;
    [z z keys]=KbCheck;
    if keys(27)
      ended=1; results=0; 
    end;
end;
