function tr = LogEvent(ex, el, tr, event, varargin)
% tr = LogEvent(ex, el, tr, eventName, eventTime)
% 
% DESCRIPTION
% Log the time of an event and store in tr struct.
% 
% The time is relative to the start of the experiment (ex.exptStartT0) OR
% if the current trial is performed during fMRI scanning, the time is
% relative to the time of the first trigger on task in this MRI run (stored
% in ex.MRIrunsT0).
% 
% The function gets the current system time (GetSecs) to determine the time
% of the event.
% Alternatively, a previously recorded system time can be provided to be
% used here to log that time relative to the reference time (use input
% eventTime).
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
% Optional input:
% eventTime : double; previously recorded system time to use here for
%             logging relative to reference time.
% 
% OUTPUT
% tr    : struct; trial data structure with the added event time (secs) in
%         tr.timings.(event)
% -------------------------------------------------------------------------
% 

% Process input arguments
% -------------------------------------------------------------------------
assert(nargin <= 5, 'Too many input arguments');
assert(ischar(event), 'Input event should be class char');
if nargin == 5
    eventTime = varargin{1};
    assert(isnumeric(eventTime), 'Input eventTime should be numeric');
end

% Determine reference time to use
% -------------------------------------------------------------------------
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
% -------------------------------------------------------------------------
if exist('eventTime','var')
    tr.timings.(event) = eventTime - refTime;
else
    tr.timings.(event) = GetSecs() - refTime;
end

% Send Eyelink message if applicable
% -------------------------------------------------------------------------
if ex.useEyelink && ~(isstruct(el))
    Eyelink('message', 'B %d T %d : %s', tr.block, tr.trialIndex, event);
    Eyelink('command', ['record_status_message ' event]);
end
end