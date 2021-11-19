function tr = LogEvent(ex, el, tr, event)
% tr = LogEvent(ex, el, tr, eventName)
% 
% DESCRIPTION
% Log the time of an event and store in tr struct.
% The time is relative to the start of the experiment (ex.exptStartT0) OR
% if the current trial is performed during fMRI scanning, the time is
% relative to the time of the first trigger on task in this MRI run (stored
% in ex.MRIrunsT0).
% 
% If eye tracking is used, a message with the event time is sent to the
% eyelink screen and EDF file.
% 
% INPUT
% ex    : struct; experiment parameters. Must contain fields:
%   ex.exptStartT0 : cell array with doubles; system time at start of each
%                    run of the experiment (can be multiple if restored).
%   ex.MRIrunsT0   : cell array with doubles; only required when in MRI. 
%                    System times of first triggers of each MRI run.
% el    : struct; eye-link info
% tr    : struct; current trial data structure
% event : char; event name to log time for in tr.timings.(event).
% 
% OUTPUT
% tr    : struct; trial data structure with the added event time (secs) in
%         tr.timings.(event)
% -------------------------------------------------------------------------
% 

% Determine reference time to use
if ex.inMRIscanner && ~tr.isPractice
    % If a main experiment trial in the MRI scanner, the refTime is the
    % first trigger time of the last started MRI run
    refTime = ex.MRIrunsT0{end};
else
    % If not in the MRI, the refTime is the start of the current experiment
    % run
    refTime = ex.exptStartT0{end};
end

% Log event time in tr.timings field
tr.timings.(event) = GetSecs() - refTime;

% Send Eyelink message if applicable
if ex.useEyelink && ~(isstruct(el))
    Eyelink('message', 'B %d T %d : %s', tr.block, tr.trialIndex, event);
    Eyelink('command', ['record_status_message ' event]);
end
end