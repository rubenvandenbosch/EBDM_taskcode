function result = run_ebdm_fmri(varargin)
% run_ebdm_fmri([subject, session, stage])
%   OR 
% run_ebdm_fmri('restore')
%
% SUMMARY
% Script to run the effort-based decision-making (EBDM) task.
% 
% Place and run this file from the root directory of the task code.
%
% INPUT
% Supply 3 required inputs OR run without input argument to supply info
% interactively. 
% If supplying one input 'restore', it will restore the last run experiment
% session.
% 
% Required info:
%   subject : num; subject number
%   session : num; session number (e.g. 1=baseline / 2=postintervention)
%   stage   : Experiment stage
%           - practice : calibration (MVC), familiarize effort levels, 
%                        practice choices
%           - choice   : choice task decisions (optionally in MRI scanner)
%           - perform  : performance of selected effort levels for reward
%                        from the choice stage
% 
% NB: adjust experiment settings in commonSettings.m
% 
% -------------------------------------------------------------------------
% Ruben van den Bosch, November 2021
% Donders Institute, Radboud University Nijmegen
% The Netherlands
% 

% Process input arguments
assert(nargin == 0 || nargin == 1 || nargin == 3, 'Incorrect number of input arguments');

% Directories and files needed to specify here
%   (others in commonSettings)
% -------------------------------------------------------------------------
% Root directory of task code
ex.dirs.rootDir = fileparts(mfilename('fullpath'));

% Output directory for result files
%   For now, use the same as it was (i.e. "output" one level up from root 
%   task code dir)
ex.dirs.output = fullfile(ex.dirs.rootDir,'..','EBDM_output');

% Create output directory if it does not exist
if ~exist(ex.dirs.output,'dir')
    mkdir(ex.dirs.output); 
end

% Recovery file
%   Full path to the experiment recovery file that is saved after every
%   trial and can be used to restore a session, e.g. after a crash.
%   This file is overwritten on each new experiment session.
ex.files.recovery = fullfile(ex.dirs.rootDir,'LastExperiment_recovery.mat');

% Add required task directories to Matlab path
% .........................................................................
addpath(genpath(fullfile(ex.dirs.rootDir,'functions')));
addpath(genpath(fullfile(ex.dirs.rootDir,'instructions')));
addpath(genpath(fullfile(ex.dirs.rootDir,'stimuli')));
try ex.PsychtoolboxVersion = PsychtoolboxVersion;
catch, error('Psychtoolbox is not added to the Matlab path.'); end

% Get subject, visit, and experiment stage, or get restore info
% -------------------------------------------------------------------------
% If applicable, use provided input arguments
restore = false;
if nargin == 3
    ex.subject   = varargin{1};
    ex.session   = varargin{2};
    ex.stage     = varargin{3};
elseif nargin == 0
    ex.subject   = input('Subject number: ');
    ex.session   = input('Session number: ');
    ex.stage     = lower(input('Experiment stage: ','s'));
elseif nargin == 1
    if strcmpi(varargin{1},'restore')
        restore = true;
    else
        error('If providing 1 input argument, it must be: restore.  Check spelling?');
    end
end

% Restore session OR define session info
% -------------------------------------------------------------------------
if restore
    % Load recovery file
    %   Store recovered experiment data in params
    %   Store recovered experiment parameters in ex. The struct ex is
    %   overwritten with settings from commonSettings, but the restored
    %   settings will be used by later code.
    params = load(ex.files.recovery,'result');
    params = params.result;
    ex     = params.params;

else    % Define session info for new session
    
    % Use empty params when starting new session
    params = [];
    
    % Constrain session number? Comment out if not. We have max 2 visits
    assert(ex.session == 1 || ex.session == 2, 'Session number can only be 1 or 2.')

    % Constrain possible strings for experiment stage (to prevent 
    % irregularities in output file names)
    stages = {'practice', 'choice', 'perform'};
    while ~ismember(lower(ex.stage),stages)
        try
            assert(ismember(lower(ex.stage),stages), '\nUnknown experiment stage. Check spelling?\n Possible stages: practice, choice, perform.\n', false)
        catch ME
            disp(ME.message)
            ex.stage = input('Experiment stage: ','s');
        end
    end

    % Text output files
    %   BIDS-like naming scheme
    %   By default the files are tab-delimited for all file extensions, 
    %   except when the file name has .csv extension, resulting in 
    %   comma-delimited.
    %   For each subject-session-stage task run a separate .mat file is 
    %   also saved automatically, containing the experiment data.
    % .....................................................................
    % Output file with all sessions (visits) and experiment stages 
    % concatenated
    ex.files.output_all = fullfile(ex.dirs.output,sprintf('subject-%.3d_task-EBDM.tsv', ex.subject));

    % Output file of the current session (visit) with all experiment stages
    % ex.files.output_session = fullfile(ex.dirs.output,sprintf('subject-%.3d_ses-%d_task-EBDM.tsv', ex.subject,ex.session));

    % Output file of the current session (visit) and experiment stage
    % ex.files.output_session_stage = fullfile(ex.dirs.output,sprintf('subject-%.3d_ses-%d_task-EBDM_stage-%s.tsv', ex.subject,ex.session,ex.stage));

    % Display session information and ask for confirmation
    % .....................................................................
    % Check for existing output .mat file for this subject-session-stage, 
    % and ask whether to abort in case of existing output file
    matfile = fullfile(ex.dirs.output,sprintf('subject-%.3d_ses-%d_task-EBDM_stage-%s.mat', ex.subject,ex.session,ex.stage));
    if exist(matfile,'file') == 2
        warning('An output file for this participant and experiment stage already exists! Check whether your session info input is correct.\n  %s',  ...
            matfile)
    end

    % Display session information and ask for confirmation or abort
    fprintf('\nSubject: %.3d \nSession: %d \nExperiment stage: %s\n',ex.subject,ex.session,ex.stage);
    if ~(exist(matfile,'file') == 2)      % if new session
        accept = input('Is this correct (yes/no)? ', 's');
        accept = strtrim(accept);
        if ~ismember(lower(accept),{'y', 'yes', 'ja', 'j'})
            error('\nExperiment settings not accepted. Run %s again to specify different settings.', mfilename);
        end
    else                                % if existing output file
        cont = input('\nContinue anyway?\n    The results of this run will be appended to existing output files.\n(yes/no) ', 's');
        cont = strtrim(cont);
        if ~ismember(lower(cont),{'y', 'yes', 'ja', 'j'})
            error('\nExperiment settings not accepted. Run %s again to specify different settings.', mfilename);
        end
    end
end

% Load common settings
%   Also initializes bitsi for MRI and buttonbox, if applicable
% ---------------------------------------------------------------------
ex = commonSettings(ex);

% Start grip force recording, if applicable
% -------------------------------------------------------------------------
if ex.useGripforce
    ex = start_gripforce(ex, 'start');
end

% Start task
% -------------------------------------------------------------------------
result = AGT_CoreProtocol_RU_BSI(params,ex);

% Cleanup
% -------------------------------------------------------------------------
% Close bitsi objects for button box and MRI triggers
if ex.useBitsiBB
    ex.BitsiBB.close;
end
if ex.inMRIscanner
    ex.BitsiMRI.close;
end

% Stop gripforce buffer after task is complete
if ex.useGripforce
    start_gripforce(ex, 'stop');
end
end