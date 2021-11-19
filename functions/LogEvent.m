function tr=LogEvent(ex, el, tr, event)
% tr = LogEvent ( ex, el, tr, eventName )
% sets tr.(eventName) to the current time
% and sends the message to the eyelink screen and EDF file.

tr.(event)=GetSecs();
if(ex.useEyelink)
    Eyelink('message', 'B %d T %d : %s', tr.block, tr.trialIndex, event);
    Eyelink('command', ['record_status_message ' event]);
end;
