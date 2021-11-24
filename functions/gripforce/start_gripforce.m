function ex = start_gripforce(ex, mode)
% ex = start_gripforce(ex, mode)
% 
% DESCRIPTION
% Start or stop the grip force recording buffer process.
% 
% INPUT
% ex    : struct with experiment settings
% mode  : char; 'start' OR 'stop'. Start the process or stop the process
% 
% OUTPUT
% If mode is 'start': returns ex with added fields pertaining to
% initialized grip force (fieldtrip header and sample rate).
% -------------------------------------------------------------------------
% 

% Process input arguments
% -------------------------------------------------------------------------
assert(isstruct(ex), 'Input ex should be class struct');
assert(ismember(lower(mode), {'start','stop'}), "Input mode should be either 'start' or 'stop'");

% If simulate grip force is true, initialize simulation settings and return
% -------------------------------------------------------------------------
if ex.simulateGripforce
    % Simulated sampling rate of 500 Hz
    ex.MP_SAMPLE_RATE = 500;
    
    % Set the required squeeze time for success in number of samples based
    % on the time defined in seconds in ex.minSqueezeTime
    ex.minimumAcceptableSqueezeTime = ex.MP_SAMPLE_RATE * ex.minSqueezeTime;
    return
end

% Start/stop grip force recording
% -------------------------------------------------------------------------
% First determine whether the gripforce buffer is running
[running, pid] = checkGripforceProcess();

% If not running yet, call system command to start gripforce with '&' to 
% start a separate process instead of running the command within matlab
if strcmpi(mode,'start')
    if ~running
        % Start gripforce process
        if ispc
            system([fullfile(ex.dirs.gripforce,'start_gripforce.bat') ' ' ex.dirs.condaEnv ' ' ex.dirs.gripforce ' &']);
        elseif isunix
            system([fullfile(ex.dirs.gripforce,'start_gripforce.sh') ' ' ex.dirs.condaEnv ' ' ex.dirs.gripforce ' &']);
        end
        % Wait until process started
        while ~running
            running = checkGripforceProcess();
            WaitSecs(0.5);
        end
    else
        disp('Gripforce fieldtrip buffer is running. Not starting anew');
    end
    
    % Initialize gripforce and store sampling rate of gripforce
    ex = initGripforce(ex);

    % Set the required squeeze time for success in number of samples based
    % on the time defined in seconds in ex.minSqueezeTime
    ex.minimumAcceptableSqueezeTime = ex.MP_SAMPLE_RATE * ex.minSqueezeTime;

elseif strcmp(mode,'stop') && running
    % Kill process
    if ispc
        system(sprintf('taskkill /PID %d /F', pid));
    elseif isunix
        system(sprintf('kill -9 %d', pid));
    end
elseif strcmp(mode,'stop') && ~running
    disp('No running gripforce process to stop');
end
end

function [running, pid] = checkGripforceProcess()
% Check whether the grip force buffer process is running.
% Returns:
%   running : true/false
%   pid     : double; process ID of running process (otherwise empty)

if ispc
    [~,pinfo] = system('netstat -ano | findstr :1972');
elseif isunix
    [~,pinfo] = system('netstat -anp | grep :1972');
end

% Figure out whether a new process for the gripforce should be
% started
if isempty(pinfo)
    running = false;
    pid = [];
else
    % Get process ID
    pinfo = textscan(strtrim(pinfo),'%[^\n\r]');
    pinfo = pinfo{1};
    pid = strsplit(pinfo{1}, ' ');
    if isunix, pid = strsplit(pid, '/'); pid = pid{1}; end
    pid = str2double(pid{end});
    
    % Running if multiple lines in pinfo or if the pID is not zero
    if size(pinfo,1) > 1
        running = true;
    elseif pid(end) == 0
        running = false; 
    else
        running = true;
    end
end
end