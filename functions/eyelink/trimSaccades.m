function ss=trimSaccades(ss, event1, event2)
% removes parts of saccades that are not between 
% events event1 and event2.
% event1 and event2 are strings representing events that were logged using
% LogEvent.
% ss is a struct array of saccades created by readEDFASC from an EDF file.
% if no events are specified, 'saccadetarget' and 'saccadeaccepted' are used
% by default.
% If the events were not logged for a trial, the trial is not truncated.

if(exist('event1')~=1) event1='saccadetarget';end;
if(exist('event2')~=1) event2='saccadeaccepted';end;
event1=[event1 '_t'];
event2=[event2 '_t'];


for i=1:length(ss)
    st=ss(i).pos(1,1);
    et=ss(i).pos(end,1);
    if isfield(ss(i), event1)
        p=ss(i).saccadetarget_t;
        if(length(p)>0)
            if(~isnan(p))
                st=p;
            end;
        end;
    end;
    if isfield(ss(i), event2)
        p=ss(i).saccadeaccepted_t;
        if(length(p)>0)
            if(~isnan(p))
                et=p;
            end;
        end;
    end;
    ss(i).pos=ss(i).pos(ss(i).pos(:,1)>st & ss(i).pos(:,1)<et,:);
    ss(i).saccade=ss(i).saccade(ss.saccade(:,1)>st & ss.saccade(:,1)<et,:);
    ss(i).fixation=ss(i).fixation(ss.fixation(:,1)>st & ss.fixation(:,1)<et,:);
end;
