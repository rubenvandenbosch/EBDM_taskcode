function result = run_ebdm_fmri(varargin)
% run_ebdm_fmri([subject, session, stage])
%
% SUMMARY
% Script to run the effort-based decision-making (EBDM) task.
% 
% Place and run this file from the root directory of the task code.
%
% INPUT
% Required info, either supplied directly or asked for interactively:
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

assert(nargin <= 3, 'Too many input arguments');

% Directories
% -------------------------------------------------------------------------
% Root directory of task code
ex.dirs.rootDir = fileparts(mfilename('fullpath'));

% Output directory for result files
%       For now, use the same as it was (i.e. "output" one level up from 
%       root task code dir)
ex.dirs.output = fullfile(ex.dirs.rootDir,'..','output');

% Create output directory if it does not exist
if ~exist(ex.dirs.output,'dir')
    mkdir(ex.dirs.output); 
end

% Add required task directories to Matlab path
% .........................................................................
addpath(genpath(fullfile(ex.dirs.rootDir,'functions')));
addpath(genpath(fullfile(ex.dirs.rootDir,'instructions')));
addpath(genpath(fullfile(ex.dirs.rootDir,'stimuli')));
try ex.PsychtoolboxVersion = PsychtoolboxVersion;
catch, error('Psychtoolbox is not added to the Matlab path.'); end

% Get subject, visit, and experiment stage info
% -------------------------------------------------------------------------
% If applicable, use provided input arguments
if nargin == 3
    ex.subject   = varargin{1};
    ex.session   = varargin{2};
    ex.stage     = varargin{3};
elseif nargin == 2
    ex.subject   = varargin{1};
    ex.session   = varargin{2};
    ex.stage     = lower(input('Experiment stage: ','s'));
elseif nargin == 1
    ex.subject   = varargin{1};
    ex.session   = input('Session number: ');
    ex.stage     = lower(input('Experiment stage: ','s'));
else
    ex.subject   = input('Subject number: ');
    ex.session   = input('Session number: ');
    ex.stage     = lower(input('Experiment stage: ','s'));
end

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
        ex.stage     = input('Experiment stage: ','s');
    end
end

% Output files
%   BIDS-like naming scheme
%   By default the files are tab-delimited for all file extensions, except
%   for the .csv file extension, which results in comma-delimited.
% -------------------------------------------------------------------------
% Output file of the current session (visit) and experiment stage
ex.files.output_session_stage = fullfile(ex.dirs.output,sprintf('subject-%.3d_ses-%d_task-EBDM_stage-%s.tsv', ex.subject,ex.session,ex.stage));

% Output file of the current session (visit) with all experiment stages
ex.files.output_session = fullfile(ex.dirs.output,sprintf('subject-%.3d_ses-%d_task-EBDM.tsv', ex.subject,ex.session));

% Output file with all sessions (visits) and experiment stages concatenated
ex.files.output_all = fullfile(ex.dirs.output,sprintf('subject-%.3d_task-EBDM.tsv', ex.subject));

% Check for existing output files
% .........................................................................
% Ask whether to abort in case of existing output file
if exist(ex.files.output_session_stage,'file') == 2
    warning('An output file for this participant and experiment stage already exists! Check whether yout session info input is correct.\n  %s',  ...
        ex.files.output_session_stage)
    cont = input('Continue anyway?\n    The results of this run will be appended to existing output files.\n(yes/no) ', 's');
    cont = strtrim(cont);
    if ~ismember(lower(cont),{'y', 'yes', 'ja', 'j'})
        error('\nExperiment settings not accepted. Run %s again to specify different settings.', mfilename);
    end
end

% Display session information and ask for confirmation
% -------------------------------------------------------------------------
fprintf('\nSubject: %.3d \nSession: %d \nExperiment stage: %s\n',ex.subject,ex.session,ex.stage);
accept = input('Is this correct (yes/no)? ', 's');
accept = strtrim(accept);
if ~ismember(lower(accept),{'y', 'yes', 'ja', 'j'})
    error('\nExperiment settings not accepted. Run %s again to specify different settings.', mfilename);
end

% Load common settings
%   Also initializes bitsi for MRI and buttonbox, if applicable
% -------------------------------------------------------------------------
ex = commonSettings(ex);

% Start grip force recording, if applicable
% -------------------------------------------------------------------------
if ex.useGripforce
    ex = start_gripforce(ex, 'start');
end

% Start task
% -------------------------------------------------------------------------
params = []; % Empty now. Possible to implement such that it can be used to restore options from earlier sessions
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