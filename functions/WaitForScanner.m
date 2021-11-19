function [ex, tr] = WaitForScanner(ex, tr, varargin)
% [ex, tr] = WaitForScanner(ex, tr, nTriggers, bitsi)
% 
% DESCRIPTION
% Function to wait for a number of (scanner) triggers before continuing. A
% countdown is shown on screen during the wait.
% The time info of the triggers is stored.
%
% INPUTS
% ex           : struct; experiment info struct
%   must contain fields:
%     ex.scr            : struct with PTB screen info
%     ex.triggerKeyCode : trigger code sent by MRI scanner
% tr           : struct; current trial info
% 
% Optional inputs:
%  If unspecified these are retrieved from the ex struct, hence in that
%  case they must be defined there (as ex.waitNumScans and ex.BitsiMRI)
%   nTriggers  : num; the number of triggers to wait for
%   bitsi      : a bitsi object used to obtain the trigger from the scanner
%
% OUTPUT
% ex :  The experiment configuration struct with the scanner triggers &
%       timings added
% -------------------------------------------------------------------------
% 

% Process input arguments
% -------------------------------------------------------------------------
assert(nargin <= 4, 'Too many input arguments')
assert(isstruct(ex), 'Input ex should be type struct')
assert(isstruct(tr), 'Input tr should be type struct')
if nargin > 2
    for in = 1:numel(varargin)
        if isa(varargin{in},'double')
            nTriggers = varargin{in};
        elseif isa(varargin{in},'Bitsi_2016')
            bitsi = varargin{in};
        end
    end
end
if ~exist('nTriggers','var'); nTriggers = ex.waitNumScans; end
if ~exist('bitsi','var'); bitsi = ex.BitsiMRI; end
assert(isnumeric(nTriggers), 'Input nTriggers should be of type struct')
assert(isa(bitsi, 'Bitsi_2016'), 'Input bitsi should be of type Bitsi_2016')

% Countdown nTriggers
% -------------------------------------------------------------------------
% Preallocate variables
triggers = nan(nTriggers,3);

count = 0;
bitsi.clearResponses(); % Clear response buffer
while count < nTriggers
    
    % Countdown text depending on language setting
    switch ex.language
        case 'EN'
            basetxt = 'Waiting for scanner... ';
        case 'NL'
            basetxt = 'Wachten op scanner...';
    end
    txt = sprintf('%s %d', basetxt, nTriggers-count);
    
    % Display on screen
    drawTextCentred(ex.scr, txt, ex.fgColour);
    Screen('Flip', ex.scr.w);
    
    % Log trigger number, trigger code, and trigger time
    triggers(count+1,1) = count+1;
    [triggers(count+1,2), triggers(count+1,3)] = bitsi.getResponse(inf,true);
    
    % If scanner trigger matches specified, report and increment count
    if triggers(count+1,2) == ex.triggerKeyCode
        fprintf('%s Warm-up trigger %d\n', datestr(now),count+1);
        count = count + 1;
        bitsi.clearResponses();
        WaitSecs(0.1);
    end
end

% Display count zero
drawTextCentred(ex.scr, sprintf('%s %d', basetxt,nTriggers-count), ex.fgColour);
Screen('Flip', ex.scr.w);

% Save trigger time info
% -------------------------------------------------------------------------
% Set the time of the final trigger as T0 of the current fMRI run of the
% experiment
if ~isfield(ex,'MRIrunsT0'), ex.MRIrunsT0 = {}; end
ex.MRIrunsT0 = [ex.MRIrunsT0, triggers(end,3)];

% Also add this time to the current trial info struct
tr.timings.firstMRItriggerT0 = triggers(end,3);
end