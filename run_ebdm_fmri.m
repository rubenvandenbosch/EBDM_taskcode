function result = run_ebdm_fmri(varargin)
% run_ebdm_fmri([subject, visit, stage])
%
% SUMMARY
% Script to run the effort-based decision-making (EBDM) task.
% 
% The output file naming convention is/will be adjusted, and is now also
% separated by visit number to the lab.
% 
% Place and run this file from the root directory of the task code.
%
% INPUT
% Required info, either supplied directly or asked for interactively:
%   subject
%   visit (1 baseline / 2 postintervention)
%   stage (Experiment stage:  
%           - practice : calibration (MVC), familiarize effort levels, 
%                        practice choices
%           - choice   : choice task decisions (in MRI scanner)
%           - perform  : performance of selected effort levels for reward
%                        from the choice stage
% 
% NB: adjust experiment settings in commonSettings.m
% 
% -------------------------------------------------------------------------
%

assert(nargin < 4, 'Too many input arguments');

% Script to add all required folders to Matlab path and make sure that 
% Psychtoolbox is added to path (start_apple_task.m must be in the root 
% directory of task code, same as run_ebdm_fmri.m)
start_apple_task();

% Main directories
% -------------------------------------------------------------------------
% Root directory of task code
ex.rootDir = fileparts(mfilename('fullpath'));

% Output directory for result files
%       For now, use the same as it was (i.e. "output" one level up from 
%       root task code dir)
ex.outputFolder = fullfile(ex.rootDir,'..','output');

% Create output directory if it does not exist
if ~exist(ex.outputFolder,'dir')
    mkdir(ex.outputFolder); 
end

% Get subject, visit, and experiment stage info
% -------------------------------------------------------------------------
% If applicable, use provided input arguments
if nargin == 3
    ex.subjectId = varargin{1};
    ex.visit     = varargin{2};
    ex.stage     = varargin{3};
elseif nargin == 2
    ex.subjectId = varargin{1};
    ex.visit     = varargin{2};
    ex.stage     = lower(input('Experiment stage: ','s'));
elseif nargin == 1
    ex.subjectId = varargin{1};
    ex.visit     = input('Visit number: ');
    ex.stage     = lower(input('Experiment stage: ','s'));
else
    ex.subjectId = input('Subject number: ');
    ex.visit     = input('Visit number: ');
    ex.stage     = lower(input('Experiment stage: ','s'));
end

% Constrain visit number? e.g. comment if not. We have max 2 visits
assert(ex.visit == 1 || ex.visit == 2, 'Visit number can only be 1 or 2.')

% Constrain possible strings for experiment stage (to prevent irregularities in
% output file names)
stages = {'practice', 'choice', 'perform'};
try
    assert(ismember(lower(ex.stage),stages), '\nUnknown experiment stage. Check spelling?\n Possible stages: practice, choice, perform.\n', false)
catch ME
    disp(ME.message)
    ex.stage     = input('Experiment stage: ','s');
end

% Output file name
% Using different naming format
% -------------------------------------------------------------------------
% Apparently different output files are used, one collecting all sessions
% and appending each in one file, another using separate files per session,
% and a third for the payout.
% Keeping this setup for now, but will look into reducing to one outputfile

% Output file concatenating sessions (make .tsv as output is saved tab
% separated)
% .........................................................................
ex.outputFilenameSessions = fullfile(ex.outputFolder,sprintf('subject-%.3d_visit-%d_stage-%s.tsv', ex.subjectId,ex.visit,ex.stage));

% Output file for current session. Keeping this because the code currently
% works with a session number to track instances that the task was started.
%
% Will likely remove unnecessary session numbers, and replace with a
% warning that the subject-visit-stage combination already exists.
% .........................................................................
% First get new session number, based on existing output files in the
% output folder

% Get existing output files
outfiles = dir(fullfile(ex.outputFolder, strrep(ex.outputFilenameSessions,'.tsv','_ses-*.tsv')));
outfiles = {outfiles(:).name}';

% Isolate session numbers from file names, and convert from str to numbers
sesnrs = cellfun(@(x) regexp(x, 'ses-\d+', 'match'), outfiles);
if ~isempty(sesnrs)
    sesnrs = cellfun(@(x) str2num(strrep(x, 'ses-', '')), sesnrs);
else
    sesnrs = 0;
end

% New session number is max of existing sesnrs + 1
ex.session = max(sesnrs) + 1;

% Session specific output file name for this session
ex.outputFilenameSession = fullfile(ex.outputFolder,sprintf('subject-%.3d_visit-%d_stage-%s_ses-%d.tsv', ex.subjectId,ex.visit,ex.stage,ex.session));

% Another separate file seems to track the payout of obtained rewards in
% the performance stage
% .........................................................................
ex.payoutFilenameSessions = fullfile(ex.outputFolder, sprintf('subject-%.3d_visit-%d_payout.tsv',ex.subjectId,ex.visit));

% Display session information and ask for confirmation
% -------------------------------------------------------------------------
fprintf('\nSubject: %.3d \nVisit: %d \nExperiment stage: %s\nSession: %d\n',ex.subjectId,ex.visit,ex.stage,ex.session);
accept = input('Is this correct (yes/no)? ', 's');
accept = strtrim(accept);
if ~ismember(accept,{'y', 'yes', 'ja', 'j'})
    error('\nExperiment settings not accepted. Run %s again to specify different settings.', mfilename);
end

% Load common settings and initialize gripforce (if applicable)
% -------------------------------------------------------------------------
ex = commonSettings(ex);

% Start task
% -------------------------------------------------------------------------
% Display instructions?

% Start task
params = []; % Empty now. Possible to implement such that it can be used to restore options from earlier sessions
result = AGT_CoreProtocol_RU_BSI(params,ex);

% Stop gripforce buffer after task is complete
% .........................................................................
% Only for the practice and perform stages
if ismember(ex.stage, {'practice','perform'})
    % Get process ID
    if ispc
        [~,pinfo] = system('netstat -ano | findstr :1972');
    elseif isunix
        [~,pinfo] = system('netstat -anp | grep :1972');
    end
    pid = textscan(pinfo, '%[^\n\r]');
    pid = strsplit(pid{1}{1}, ' ');
    if isunix
        pid = strsplit(pid, '/');
        pid = pid{1};
    end
    pid = str2double(pid{end});

    % Kill process
    if ispc
        system(sprintf('taskkill /PID %d /F', pid));
    elseif isunix
        system(sprintf('kill -9 %d', pid));
    end
end
end