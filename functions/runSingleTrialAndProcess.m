
function tr=runSingleTrialAndProcess(scr,el,ex,tr,doTrial,b,t)
% this prepares a trial structure for the experiment,
% calls "doTrial" of your experiment,
% checks if it needs repeating, and checks for things like calibration
% requests or if the Eyelink computer 'abort' or 'end' was pressed.
tr.block=b; tr.trialIndex=t;              % initialise trial position
tr.allTrialIndex = t + (b-1)*ex.blockLen; % index relative to whole experiment
tr.key=[];  tr.R=ex.R_INCOMPLETE;         % initialise trial exit status
%  Iterate this trial as many times as needed to get a non-Incomplete result
while  tr.R==ex.R_INCOMPLETE              % repeat trial immediately?
  kcode = 1; while any(kcode) [z z kcode]=KbCheck; end;
  FlushEvents;             % ensure no keys pressed at start of trial
  if ex.useEyelink         %%%% begin eye tracker recording
    Eyelink('startrecording');
    el.eye=Eyelink('eyeavailable')+1;
    if ~el.eye
      error('No eye available');
      el.eye=1;
    end;
    
    Eyelink('message', 'B %d T %d', b,t); % signal to eyelink - start of trial
  end;
  if ex.useSqueezy         %%%% begin MP150 squeezy recording
    retval=calllib(ex.mplib, 'startMPAcqDaemon');
    if ~strcmp(retval,'MPSUCCESS')
      error('Could not start squeezy acquisition daemon');
    end
    fprintf('starting acqisition\n');
    retval = calllib(ex.mplib, 'startAcquisition');
    if ~strcmp(retval,'MPSUCCESS')
      fprintf(1,'Failed to Start Acquisition.\n');
      calllib(ex.mplib, 'disconnectMPDev');
      error('Failed to start squeezy acquisition');
    end
    tr=LogEvent(ex,el,tr,'startSqueezyAcquisition');
  end
  if ex.useGripforce         %%%% Gripforce (TSG/RU device) recording
    % AGT_CoreProtocol function requires this for the call to
    % waitForForceData. The Squeezy debivice requires time to determine
    % data collection starting point. Fir the gripforce device this
    % information is not used.
    tr=LogEvent(ex,el,tr,'startSqueezyAcquisition');
  end
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Call External doTrial routine
  tr = doTrial(scr, el, ex, tr);
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Returns the results of that trial
  % ensure trial result structure is OK
  if ~isfield(tr,'key'), tr.key=[]; end              % well, it's just possible that you return a completely
  if ~isfield(tr,'R'),   tr.R=ex.R_UNSPECIFIED; end; % different structure to the one we provided!
  
  % recheck keyboard, and execute special end-of-trial commands if needed
  [z z kcode] = KbCheck;                             % is a key pressed at the end of the trial?
  if kcode(ex.exitkey),  tr.key=ex.exitkey;  end;    % override repeat trial if escape pressed.
  if kcode(112),         allowinput(scr,ex); end;    % f1: allow modification of expt params
  if length(tr.key)>1,   tr.key=tr.key(1);   end;
  if isempty(tr.key) || tr.key==0,  tr.key=find(kcode); % expt provided no keypress data --> check our own
  else
    if tr.key=='R',   tr.R=ex.R_NEEDS_REPEATING; end;
    if tr.key=='D' && ex.useEyelink, dodriftcorrection(el ); tr.R=ex.R_NEEDS_REPEATING;end;
    if tr.key=='C' && ex.useEyelink, EyelinkDotrackersetup(el); tr.R=ex.R_NEEDS_REPEATING; end;
    if tr.key==ex.exitkey,  tr.R=ex.R_ESCAPE;  end;
  end
  if ex.useEyelink            %%%% stop recording
    if tr.R == ex.R_NEEDS_REPEATING,  Eyelink('message', 'VOID_TRIAL'); end;
    Eyelink('stoprecording');
    eyeStatus=Eyelink('checkrecording');
    switch(eyeStatus)       % check Eyelink status - was the trial aborted?
      case el.ABORT_EXPT,   tr.R=ex.R_ESCAPE; Eyelink('stoprecording'); break;
      case el.REPEAT_TRIAL, tr.R=ex.R_NEEDS_REPEATING; tr.key='R';Eyelink('stoprecording');
      case el.SKIP_TRIAL,   tr.R=ex.R_NEEDS_REPEATING; tr.key='R';Eyelink('stoprecording');
    end
  end
  if ex.useSqueezy
    calllib(ex.mplib, 'stopAcquisition')
  end
  if tr.R == ex.R_INCOMPLETE
    fprintf('repeating block %g trial %g\n',b,t);
  end
end; % while trial needs repeating




function allowinput(scr,ex)
% this allows the user to type at the keyboard and invoke commands.
Screen closeall
%Screen('OpenWindow', scr.w, ex.bgColour, [0 0 100,100]);
disp('type "return" to return to experiment, or "dbquit" to end expt');
keyboard();
%Screen('OpenWindow', scr.w, ex.bgColour, [0 0 scr.ssz]);


