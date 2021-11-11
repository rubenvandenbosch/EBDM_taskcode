function result = writeResults(ex, result, tr, varargin)
% result = writeResults(ex, result, tr, init)
% 
% Function to save the results of the current trial.
% 
% DESCRIPTION
% The results of the current trial (contained in tr) are appended to the
% result.data field of the result struct. 
% The relevant trial results are appended to the output text
% files. 
% The whole result structure, including the current trial results
% is saved in a recovery file that can be used to restore the session, e.g.
% after a crash.
% 
% If init is true (default false), only the outputfiles are initialized and
% no data is written. During initialization the output text files are
% openend and the header line is written if necessary. If init is true, the
% code section to save resuls is not executed.
% Use empty [] for result and tr inputs if initializing.
% 
% INPUTS
% ex      : struct; main experiment info struct. Should contain at least
%           the fields: dirs, files. A field with file IDs (fids) is
%           added when initializing.
% result  : struct with all results of current experiment run. Not used
%           (supply []) when init=true.
% tr      : struct with results for the current trial. Not used (supply [])
%           when init=true.
% init    : true/false; defaults to false. Toggle initialize only mode. If
%           set to true, the relevant text output files are opened and, if
%           necessary, the header line is written. 
% 
% OUTPUT
% result  : struct with all results of the currently running experiment.
%           The current trial data is appended to the field result.data
% Output files:
% - Recovery .mat file (ex.recoveryFile) of current session to which the
%   updated result struct is saved.
% - tab-delimited txt files specified in ex struct
% 
% -------------------------------------------------------------------------
% 

% Process input arguments
% -------------------------------------------------------------------------
assert(nargin <= 4, 'Too many input arguments')
if nargin == 4, init = varargin{1}; else, init = false; end
if ~init
    assert(isstruct(result), 'Input result should be class struct');
    assert(isstruct(tr), 'Input tr should be class struct');
end

% Field names in ex.files (and ex.fids) that contain the file names (file 
% ids)to use for this session
fields = {'output_session_stage','output_session','output_all'};
if strcmp(ex.stage,'perform'), fields = [fields 'output_payout']; end

% Initialize output files
% =========================================================================
% Only open files and write header if necessary, then return
if init
    % Open output files, write header line if new file
    for ifile = 1:numel(fields)
        if exist(ex.files.(fields{ifile}),'file') == 2
            % Open
            ex.fids.(fields{ifile}) = fopen(ex.files.(fields{ifile}), 'a');
        else
            % Open
            ex.fids.(fields{ifile}) = fopen(ex.files.(fields{ifile}), 'a');
            
            % Write header
            %   Required columns in BIDS specification for events files: 
            %       onset, duration
            %   subject session stage MVC block trialNr trialNr_block onset duration reward effortIx effortLvl accept didAccept success totalReward yesLocation   
            fprintf(ex.fids.(fields{ifile}), ...
                'subject\tsession\tstage\tMVC\tblock\ttrialNr\ttrialNr_block\tonset\tduration\treward\teffortIx\teffortLvl\taccept\tdidAccept\tsuccess\ttotalReward\tyesLocation\n');
        end
    end
    
    % Return without executing the writing data section below
    return
end

% Save trial results
% =========================================================================
assert(~init, 'Trying to write results when initialize only option is set to true')

% Write to result struct
% -------------------------------------------------------------------------
% Initialise data field in result struct if necessary (first trial)
if ~isfield(result.data,'data')
    result.data = []; 
else
    assert(isstruct(result.data), 'result.data should be class struct');
end

% Append trial data to result.data struct
[result.data, tr] = ensureStructsAssignable(result.data,tr);
result.data = [result.data tr];

% Save experiment recovery file
% -------------------------------------------------------------------------
save(ex.files.recovery,'result');

% Write data to output files
% -------------------------------------------------------------------------
% Get output variables and set unavailable vars to NaN
if isfield(tr,'Yestrial'), Yestrial = tr.Yestrial; else, Yestrial = NaN; end
if isfield(tr,'stake'), stake = tr.stake; else, stake = NaN; end
if isfield(tr,'reward'), reward = tr.reward; else, reward = NaN; end
if isfield(tr,'effort'), effort = tr.reward; else, effort = NaN; end
if isfield(tr,'sub_stage'), stage = tr.sub_stage; else, stage = ex.stage; end

% Write data
for ifile = 1:numel(fields)
    % subject session stage MVC block trialNr trialNr_block onset duration reward effortIx effortLvl accept didAccept success totalReward yesLocation
    fprintf(ex.fids.(fields{ifile}), '%d\t%d\t%s\t%d\t%d\t%d\t%d\t%f\t%f\t%d\t%d\t%f\t%s\t%d\t%d\t%d\t%s', ...
        ex.subject, ex.session, ex.stage, tr.MVC, tr.block, tr.trialIndex, tr.allTrialIndex, ...
        tr.onset, tr.duration, tr.reward, tr.effortIx, tr.effortLvl, tr.accept, tr.didAccept, tr.success, tr.totalReward, tr.yesLocation);
end
end

% old:
% 'starttime\ttime\tstage\tsubject_id\tsession\tMVC\tblocknr\ttrialnr\teffort\tstake\treward\ttotalReward\tchoice\n'

%     fprintf(ex.fids.(fields{ifile}),'%f\t%s\t%s\t%s\t%d\t%.2f\t%d\t%d\t%f\t%d\t%d\t%d\t%d\n', ...
%         tr.starttrial,datestr(now),stage,ex.subject,ex.session,tr.MVC,b,t,effort,stake,reward,totalReward,Yestrial);
% fprintf(ex.fpSession, '%f\t%s\t%s\t%d\t%.2f\t%d\t%d\t%f\t%d\t%d\t%d\t%d\n',tr.starttrial,datestr(now),ex.subject,ex.session,tr.MVC,b,t,tr.effort,stake,reward,totalReward,Yestrial);