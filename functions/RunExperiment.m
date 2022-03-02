function result = RunExperiment ( doTrial, ex, params, blockStart )
% result = RunExperiment ( @doTrial, ex, params [, @blockStart] )
% The body of the experiment.
% Sanjay Manohar 2008
%
% What It Does:
% ------------
% 1) Create screen (type 'help prepareScreen' for details)
%
% 2) Initialise eyelink (if ex.useEyelink==1), recording default eye
%    position information to a date-numbered file. (if useEyelink==2 then
%    use a dummy eyelink setup)
%
% 3) Combine information from 'ex' and 'params' structures. Params is
%    either interpreted as values that override those of ex, or alternatively
%    if params is the result from a previous experiment, then simply continue
%    the previous experiment.
%    If not continuing a previous experiment, create trial structure
%    (type help createTrials) using parameters in ex.
%
% 4) Iteratively call the given trial function: doTrial(scr, el, ex, trial)
%    Parameters sent: screen structure, eyelink structure,
%      experiment parameters structure, and trial parameters structure
%
% 5) Handles eyelink trial, calibration, drift correction, and abort logic.
%
% 6) Handles keypresses
%      'R'    repeat trial now
%      'D'    drift correct
%      'C'    tracker setup screen
%      'F1'   allow keyboard input to modify experiment
%      escape exit block and exit experiment.
%    The key result should be passed
%    back from doTrial in the return structure as trial.key, and trial.R
%    should return a status (R_ERROR terminates block).
%
% 7) Handles errors: saves all data in 'errordump.mat', cleans screen and
%    shuts down eyelink; also attempts to upload EDF file to current
%    directory. Also, data is saved at every block-end, in LastExperiment.dat
%
% NOTE:
%  1) ex.R_ERROR (any number) and ex.useEyelink (true/false) must be defined.
%  2) doTrial must be a function handle (passed using @) with the
%     parameters as described in 4 above
%
% Input arguments:
%
% doTrial:          user-supplied function of the form
%                   trialResult = doTrial(scr, el, ex, trial)
%                   Called with parameters of each trial.
%
%
% ex:               Experimental parameters, containing fields:
%  blocks           = number of blocks, or alternatively an array of
%                     integers specifying the block types for each block to
%                     run. Default = 1
%
%  blockLen         = number of trials per block.
%
%  blockVariables.varName1  = [value1, value2, value3]
%  trialVariables.varName2  = [value4, value5]
%                     Specify trial types.
%                     These create variables that are shuffled across
%                     trials and blocks. Each variable 'varName_i' will take
%                     one of the specified value_i from the corresponding
%                     array.
%                     You can use a cell array instead.
%
%  useEyelink       = whether to use eyelink
%  useScreen        = whether to use the PsychToolbox Screen command
%  useSqueezy       = initialise squeezy device. default initialises to
%                     500Hz, 2 channels
%
%  exptStartEnd     = @function exptStartEnd(ex, timepoint) is called at
%                     the start/end of the experiment. Can be used for
%                     one-off instructions.
%
%  blockStart:      = user supplied function of the form
%                     @function blockStart (scr, el, ex, trial), where the trial
%                     supplied is the first trial of the block. use this to
%                     write a display needed at the start of a block.
%
%  randomSeed       = integer > 0: set the trial randomisation seed
%                     if omitted or 'nan', then randomise from the timer.
%
%  rethrowErrors    = if true, then the errors will be shown as proper
%                     errors, after the cleanup
%
%  practiceTrials   = number of practice trials. If this is a multiple of
%                     the number of trial types, there will be one of each
%                     type.
%
%  shuffleTrials    = true if you want the trials in a random order in each
%                     block. Otherwise they will run in the order that the
%                     fields of 'trialVariables' were created.
%
%  shufflePracticeTrials = (same but for practice trials)
%
%  repetitionsPerBlock: You can specify this instead of blockLen. If this
%                     is 1, then the block length will be the same as the
%                     number of trial types.
%
%  MP_SAMPLE_RATE   = sample rate for the squeezy - Hz. Default 500 Hz
%
%
%
% params:           Either - additional experimental parameters which
%                   override those in 'ex', or 'result' returned from
%                   a previous RunExperiment.
%                   set a field 'overrideParameters' if you want to
%                   automatically override any parameters set in the
%                   experiment program, otherwise you will be asked.
%
% blockStart:       can also be specified as a separate parameter, as an
%                   @function.
%
% in doTrial, you have access to
%
%  ex.R_NEEDS_REPEATING  }
%  ex.R_ERROR            }  = constants you can return as results in tr.R
%  ex.R_ESCAPE           }
%  ex.exitkey       the platform-specific Escape key number, for KbCheck
%
% result:
%  file             = EDF file name for eyelink data (hopefully transferred
%                     into local working directory at end of experiment)
%  trials(block,trial) = trial parameters structure - the specific
%                     parameters created by createTrials, and sent
%                     sequentially to each doTrial.
%  params           = The experimental parameters, combined
%  data(block,trial)= The results of each trial, as returned by doTrial.
%                     Once you have discarded unwanted trials/reordered the
%                     trials for analysis, you can use
%                     transpIndex(result.data) to access the values as
%                     matrices.
%  practiceResult(i)= results returned from doTrial for the practice
%                     trials.
%  last (1x2 double)= last block and trial that was successfully completed;
%                     this is the point to continue from if 'result' is
%                     used as the 'params' input to RunTrials.
%  date             = date/time string of start of experiment.
%
% Sanjay Manohar 2008


% Setup parameters
% =========================================================================
% values of responseType, supplied by doTrial.
% send these values in tr.R to indicate the outcome of each trial
ex.R_ERROR        = -99;            % trial was an error; leave it and do nothing
ex.R_NEEDS_REPEATING = -97;         % error: rerun trial immediately after
ex.R_NEEDS_REPEATING_LATER = -95;   % error: rerun trial at end of block
ex.R_ESCAPE       = -98;            % escape was pressed - exit immediately
ex.R_INCOMPLETE   = -96;            % trial didn't complete as expected
ex.R_UNSPECIFIED  = -94;            % experiment didn't provide a return value

% Store the stack trace - so we know which .m experiment file was run
% to execute the experiment
ex.experimentStack= dbstack;
fatal_error       = 0;              % true if the task must end suddenly

% Store the file record for top-level function (i.e. experiment)
%  - includes the modification date and size! (2018)
ex.experimentFile = dir(which(ex.experimentStack(end).file));

% If params is given, restore previous experiment settings
% -------------------------------------------------------------------------
% block and trial to start at
last = [1 1];

% If restoring, overwrite the settings in struct ex with those specified in
% params
if exist('params','var') && ~isempty(params)
    
    % Combine ex and params in struct ex, overwriting existing fields in ex
    ex = combineStruct(ex, params);
    
    % go straight to the last-executed trial
    % keep old trial structure and randomisation
    % keep results of old trials
    % also keep results of old practice trials
    if isfield(params,'last'),           last = params.last; end
    if isfield(params,'trials'),         trials = params.trials; end
    if isfield(params,'data'),           result.data = params.data; end
    if isfield(params,'practiceResult'), result.practiceResult = params.practiceResult; end
    
    % keep a list of EDF files used in previous runs
    if isfield(params,'edfFiles')
        result.edfFiles=params.edfFiles;
    else
        result.edfFiles={};
    end
    
    % keep a list of times that each run begins
    if isfield(params,'startTimes')
        result.startTimes=params.startTimes;
    else
        result.startTimes={};
    end
    
    % Indicate that we're using a restored session
    ex.restoredSession = true;
    
    % Log which trial we restored from
    ex.restoredFrom = last;
else
    ex.restoredSession = false;
end

% Set default values for unspecified parameters
% -------------------------------------------------------------------------
if ~isfield(ex,'useEyelink'), ex.useEyelink=0; end  % default No Eyelink
if ~isfield(ex,'useScreen'),  ex.useScreen=1;  end  % default Yes Screen
if ~isfield(ex,'useSqueezy'), ex.useSqueezy=0; end  % default No Squeezy
if ~isfield(ex,'useGripforce'), ex.useGripforce=0; end  % default No Gripforce
if ex.useEyelink, ex.useScreen=1; end               % can't have eyelink without screen
if ~ex.useScreen,  scr=0; end                       % not using screen?
if ~ex.useEyelink,  el=0; end                       % not using eyelink?

if ~exist('blockStart','var') && isfield(ex,'blockStart'), blockStart = ex.blockStart; end
if ~exist('exptStartEnd','var') && isfield(ex,'exptStartEnd'), exptStartEnd = ex.exptStartEnd; end
if ~isfield(ex,'blocks'), disp('Assuming 1 block only'); ex.blocks = 1; end

% store time of experiment start
if ~exist('result','var'), result.startTimes = {}; end
result.startTimes = [result.startTimes, datestr(now,31)];

% Set random seed
% -------------------------------------------------------------------------
% added 2016 to cater for different random number generator in new Matlab
% (rand seed has been deprecated now)
if isfield(ex,'randomSeed') && numel(ex.randomSeed)==1 && ~isnan(ex.randomSeed)
    try   % if random seed present, set the fixed seed
        rng(ex.randomSeed);
    catch mx   % older versions of matlab:
        rand('seed',ex.randomSeed);
    end
else    % no seed present: randomise the generator from the clock
    try
        rng('shuffle');
    catch mx  % older versions of matlab:
        rand('seed',sum(100*clock));
    end
end

% Create trials
% =========================================================================
if ~exist('trials','var')
    if ~strcmp(ex.stage,'perform')  % Create trials on choice and practice stages
        trials = createTrials(ex);
    else                            % Select trials from previous choices for the perform stage
        trials = getPerformTrials(ex);
    end
end

% Run experiment
% =========================================================================
% Everything in try block to catch and report errors
e=[]; % this carries any errors
try
    % Initialise devices
    % ---------------------------------------------------------------------
    % Enable unified mode of KbName,
    % so KbName accepts identical key names on all operating systems:
    KbName('UnifyKeyNames');
    if ~isfield(ex,'exitkey')
        ex.exitkey = KbName('Escape');
    end
    
    % Initialise screen (scr struct)
    if ex.useScreen
        if ~isfield(ex,'scr') || ex.restoredSession
            scr = prepareScreen(ex);
            ex.scr = scr;
            ex.screenSize = scr.ssz;
        else
            scr = ex.scr;
        end
    end
    
    % Initialise squeezy device
    if ex.useSqueezy
        ex.mplib = 'mpdev'; mpdir='.';
        if ~isfield(ex, 'MP_SAMPLE_RATE') ex.MP_SAMPLE_RATE=500;end
        x=loadlibrary([mpdir '/mpdev.dll'],[mpdir '/mpdev.h']);
        [retval, sn] = calllib(ex.mplib,'connectMPDev',101,11,'auto');
        if ~strcmp(retval,'MPSUCCESS')
            fprintf('for eyelink use IP 100.1.1.2; for MP150 use IP 169.254.111.111\n');
            error('could not initialise MP150: %s', retval);
        end
        calllib(ex.mplib, 'setSampleRate', 1000/ex.MP_SAMPLE_RATE); % ms between samples
        calllib(ex.mplib, 'setAcqChannels', int32([1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 ]));  % which of 16 channels?
    end
    
    % Initialise eye tracker
    datestring=datestr(now,30);
    namebase=datestring([5:8, 10:13]); % base filename = date
    if(ex.useEyelink)                  % initialise eyelink (el struct)
        if Eyelink('IsConnected'), Eyelink('Shutdown');end;
        if(ex.useEyelink==1)
            success=Eyelink('Initialize');
            if success<0, fprintf('ensure eyelink software is on, cable is connected, and that\nthe IP address is set to 100.1.1.2\n'); return; end
        else
            Eyelink('InitializeDummy');
        end                            % set up calibration, record & receive gaze + pupil
        Eyelink('command', 'calibration_type = HV9');
        Eyelink('command', 'saccade_velocity_threshold = 35');
        Eyelink('command', 'saccade_acceleration_threshold = 9500');
        Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
        Eyelink('command', 'file_sample_data = GAZE,AREA,STATUS');
        Eyelink('command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,BUTTON');
        Eyelink('command', 'link_sample_data  = LEFT,RIGHT,GAZE,AREA');
        Eyelink('command', 'screen_pixel_coords = 0,0,%d,%d', scr.ssz(1), scr.ssz(2));
        Eyelink('Command', 'pupil_size_diameter = YES');
        el=EyelinkInitDefaults(scr.w);
        el.file=[namebase '.edf'];
        Eyelink('openfile', el.file ); % create the EDF file
        result.file   = el.file;
        el.disallowEarlySaccades=1;    % store the filename in output
        el.backgroundcolour=ex.bgColour;
        el.foregroundcolour=ex.fgColour;
        el.callback = []; % disable the flashy calibration screen
        if(~isfield(result,'edfFiles')) result.edfFiles={};end;
        result.edfFiles={result.edfFiles{:}, result.file};
        EyelinkDoTrackerSetup(el);     % run the calibration routine
        FlushEvents;
    end
    
    % ---------------------------------------------------------------------
    % Start of experiment code
    % ---------------------------------------------------------------------
    % Init output structure
    result.trials = trials;     % save trial structure in output
    result.params = ex;         % save experimental parameters in output
    
    % Call experiment start code
    %   Logs experiment start system time
    %   Shows welcome/restore screen
    assert(exist('exptStartEnd','var')==1, 'No experiment start function provided. Required for setting start time reference point, and showing instructions.')
    ex = exptStartEnd(ex,'start');
    
    % Practice trials
    % ---------------------------------------------------------------------
    % If there are practice trials, and we're not continuing from before:
    if isfield(ex,'practiceTrials') && ex.practiceTrials>0 && prod(last)==1
        
        % Create a new set of random trials for the practice
        % .................................................................
        %   Use a random sample from the created trial list. Prevents
        %   having the same N practice trials as the first N real trials
        prac = trials(:);
        prac = prac(randsample(numel(prac),ex.practiceTrials));
                
        if strcmpi(ex.stage,'perform')
           % Set all practice trials to a yes-trial to perfrom, except for 
           % one (if more than one practice trials)
           for ix = 1:numel(prac)
               prac(ix).Yestrial = 1;
           end
           if numel(prac) > 1, prac(randi(numel(prac),1)).Yestrial = 0; end
        end
        
        % Run practice trials, preceded by calibration and familiarization,
        % if applicable
        % .................................................................
        prePracticeTrials = ex.numCalibration + ex.numFamiliarise;
        for ix = 1:prePracticeTrials + ex.practiceTrials
            
            % Get practice trial number (negative for prePracticeTrials)
            if ix <= prePracticeTrials
                practiceTrialIx = -prePracticeTrials + ix;
            else
                practiceTrialIx = ix - prePracticeTrials;
            end
            
            % Work out what kind of trial this is
            %   Start with calibration, then familiarize, then practice
            %   For calibration and familiarize, load trial info of first
            %   practice trial (not used)
            if ix <= prePracticeTrials
                tr = prac(1,1);
                if ix <= ex.numCalibration
                    tr.sub_stage = 'calibration';
                    % For calibration stage also set effort info to NaN
                    tr.effortIx    = nan;
                    tr.effortLevel = nan;
                else
                    tr.sub_stage = 'familiarize';
                end
            else
                % Get practice trial parameters for current trial
                tr = prac(practiceTrialIx);
                tr.sub_stage = 'practice';
            end
            
            % Log practice trial number (negative for prePracticeTrials)
            % mark the trial as a practice
            % set first trial of MRI run to false
            tr.practiceTrialIx  = practiceTrialIx;
            tr.isPractice       = true;
            tr.firstTrialMRIrun = false;
            
            % Display instructions by calling blockstart method
            %   using block index 0 for practice block
            %   call blockstart method to display instructions on the first
            %   practice trial and the first of each new part
            blockstart_trials = unique([1, ...
                                        1 + ex.numCalibration, ...
                                        1 + ex.numCalibration + ex.numFamiliarise]);
            if exist('blockStart','var') && ismember(ix,blockstart_trials)
                kcode = 1; while any(kcode); [~, ~, kcode] = KbCheck; end
                FlushEvents ''; % Empty strings are ignored... Remove these 2 lines?
                
                % Run block start method
                tr.block = 0;
                [ex, tr] = blockStart(scr,el,ex,tr);
                
                % If there was an error or escape key, exit practice trials
                if tr.R == ex.R_ERROR || tr.R == ex.R_ESCAPE
                    fatal_error=1; break;
                end
            elseif ~exist('blockStart','var') && ex.inMRIscanner
                error('No blockStart function provided. This code is needed when in the MRI scanner to sync the task to the scanner')
            end
            
            % Run the practice trial
            %   set the block index to 0
            tr = runSingleTrialAndProcess(scr, el, ex, tr,doTrial,0,ix);
            
            % Overwrite tr fields with forced values for practice stage
            % 	trialIndex with practiceTrialIndex to have negative trial
            %   index within block for calibration and familiarize and
            %   positive trial numbers for practice choices.
            %   Set reward info to NaN for calibration and familiarize
            tr.trialIndex = practiceTrialIx;
            if ix <= prePracticeTrials
                tr.rewardIx    = nan;
                tr.rewardLevel = nan;
            end
            
            % Do not allow repeating practice trials
            if(isfield(ex,'R_NEEDS_REPEATING_LATER') && tr.R==ex.R_NEEDS_REPEATING_LATER)
                tr.R = 1;
            end
            
            % Write practice data to results output structure and the txt 
            % output files
            assert(isfield(tr,'isPractice') && tr.isPractice, 'Make sure to mark the trial as practice for correct assignment in the result struct')
            [result, ex] = writeResults(ex, result, tr);
            
            % If there was an error, exit practice trials
            if tr.R == ex.R_ERROR || tr.R == ex.R_ESCAPE
                fatal_error=1; break;
            end
        end
    end
    
    % Main blocks and trials
    % ---------------------------------------------------------------------
    % If only MVC calibration or stage is 'practice', we skip all this
    if ~ex.calibOnly && ~strcmp(ex.stage,'practice')
        
        % Display "Start of experiment" and wait for key press to start
        if ~(isfield(ex,'practiceTrials') && ex.practiceTrials>0 && prod(last)==1) && ~ex.restoredSession && ~fatal_error
            if ex.useScreen
                Screen(scr.w, 'FillRect',ex.bgColour, scr.sszrect);
                if strcmp(ex.language,'NL'), txt='De taak begint nu'; else, txt='The task starts now'; end
                drawTextCentred(scr, txt, ex.fgColour);
                Screen('Flip', scr.w);
            else
                disp('Start of experiment - press a key');
            end
            myKbWait(ex); % press a key to start the experiment
            WaitSecs(1);
        end
        
        % Loop over blocks
        %   Continue from last block
        for b = last(1):ex.blocks
            
            % If exit key was pressed during practice, break out of this
            % loop
            if fatal_error, break; end
            
            % Call the blockStart method if supplied
            %   Waiting for fMRI scanner triggers is implemented in
            %   blockstart method. If using mri, assert we have a
            %   blockstart method.
            if exist('blockStart','var')
                kcode = 1; while any(kcode); [~, ~, kcode] = KbCheck; end
                FlushEvents ''; % Empty strings are ignored... Remove these 2 lines?
                
                % Get which block we are in to inform the blockStart code 
                trial1.block = b;
                
                % If this is the first block of a new fMRI run, log this in
                % the tr struct; in the blockstart method the task will
                % wait for the MRI triggers to come in before continuing
                if b == last(1) && ex.inMRIscanner
                    % Assert that this is a restored session if this is not
                    % block 1 trial 1
                    if ~(prod(last)==1)
                        assert(ex.restoredSession, 'ex.restoredSession is false, but not starting with block 1 trial 1...?')
                    end
                    
                    trial1.firstTrialMRIrun = true;
                else
                    trial1.firstTrialMRIrun = false;
                end
                
                % Run block start method
                [ex, trial1] = blockStart(scr,el,ex,trial1);
                
                % If there was an error or escape key, exit
                if trial1.R == ex.R_ERROR || trial1.R == ex.R_ESCAPE
                    fatal_error=1; break;
                end
            elseif ~exist('blockStart','var') && ex.inMRIscanner
                error('No blockStart function provided. This code is needed when in the MRI scanner to sync the task to the scanner')
            end
            
            % Initialise record of trials to repeat at end of block
            repeatLater = [];
            
            % Set settings used for fatiguing experiment only
            %   start effort on level specified below * MVC
            fatEffort    = ex.fatiguingExerciseSTartEffortLevel;
            prevReward   = 0;   % remember previous result, init to non-used value
            handLocation = 1;   % hand target for fatiguing experiment using two gripforces
            
            % Run each trial in this block
            % .............................................................
            firstMRItrial = 1;
            for t = 1:ex.blockLen
                % skip through trials already done
                if b==last(1) && t<last(2)
                    firstMRItrial = t+1;
                    continue
                end
                
                % Get trial parameters
                %   Set current trial's sub_stage to the overall ex.stage
                %   Set tr.isPractice to false
                tr = trials(b,t);
                tr.sub_stage  = ex.stage;
                tr.isPractice = false;
                
                % Add MRI info to trial struct
                if b==last(1) && ex.inMRIscanner && t == firstMRItrial
                    tr.firstTrialMRIrun = true;
                    tr.timings.firstMRItriggerT0 = trial1.timings.firstMRItriggerT0;
                else
                    tr.firstTrialMRIrun = false;
                end
                
                % Run trial
                if strcmp(ex.stage,'choice') % Choice trials
                    % Run current trial
                    tr = runSingleTrialAndProcess(scr,el,ex,tr,doTrial,b,t);

                elseif ~ex.fatiguingExercise % Regular perform stage trials
                    % Run current trial
                    tr = runSingleTrialAndProcess(scr,el,ex,tr,doTrial,b,t);
                
                else                         % Fatiguing experiment
                    
                    % Set trial effort level
                    tr.effort = {fatEffort};
                    
                    if ex.twoHands
                        handLocation = handLocation * -1; % toggle tree left (-1) or right (1)
                        tr.location = handLocation;
                    else
                        tr.location = 0; % show tree in the middle
                    end
                    
                    % Run current trial
                    tr = runSingleTrialAndProcess(scr,el,ex,tr,doTrial,b,t);
                    
                    % Process trial data
                    %   convert reward 0/1 to -1/+1 for easy calculation
                    %   and report
                    if tr.reward
                        reward = 1;
                    else
                        reward = -1;
                    end
                    fprintf('succes=%d\tprevious=%d',reward,prevReward);
                    
                    % Adjust effort level to make more or less fatiguing
                    if reward == prevReward
                        if reward > 0
                            fatEffort = fatEffort + 0.1; % add 10% to required force level
                        else
                            fatEffort = fatEffort - 0.1; % subtract 10% from required force level
                            if fatEffort < 0.1, fatEffort = 0.1; end
                        end
                        prevReward = 0; % init
                    else
                        prevReward = reward;
                    end
                    % Report effort level
                    fprintf('\teffort level=%f\n',fatEffort);
                end
                
                % Keep track of what the last complete trial is
                result.last = [b,t];
                
                % Write results to result struct, output txt files, and
                % save a recovery file after each trial
                [result, ex] = writeResults(ex, result, tr);
                
                % Mark trial for repeating, if applicable
                if(isfield(ex,'R_NEEDS_REPEATING_LATER') && tr.R==ex.R_NEEDS_REPEATING_LATER)
                    repeatLater = [repeatLater, t];
                    fprintf('Block %d Trial %d will be repeated at end\n',b,t);
                end
                
                % Save the newly added trial info and flags to trial struct
                [trials, tr] = ensureStructsAssignable(trials,tr);
                trials(b,t)  = tr;
                
                % If there was an error, exit
                if tr.R==ex.R_ERROR || tr.R==ex.R_ESCAPE
                    fatal_error=1; break;
                end
            end  % end of regular trials in block
            
            % Repeat-later trials
            % .............................................................
            % keep going until they don't need repeating.
            % add them to the end of the data, but put in the appropriate 
            % trial index for where it would have been in the sequence.
            t=1;
            while (~fatal_error) && (t<=length(repeatLater))
                repTrial = trials(b,repeatLater(t));
                
                % Track repeat trials and the number of repeats
                if isfield(repTrial,'numRepeated') && ~isnan(repTrial.numRepeated)
                    repTrial.numRepeated = repTrial.numRepeated + 1;
                else
                    repTrial.numRepeated = 1;
                end
                
                % If the number of repeats exceeds the max, continue to
                % next the trial to redo
                if repTrial.numRepeated > ex.maxNumRepeatedTrials
                    % too many retries, go on to the next trial to repeat
                    t = t + 1;
                    continue
                end
                
                % Add repeat trial info and flags to trial struct
                repTrial.isRepeated = 1;
                [trials, repTrial] = ensureStructsAssignable(trials,repTrial);
                trials(b,repeatLater(t)) = repTrial;
                
                % Run current repeat trial
                tr=runSingleTrialAndProcess(scr,el,ex,repTrial,doTrial,b,repeatLater(t));
                
                % make the trial index the same as it should have been
                tr.trialIndex = repeatLater(t);
                
                % Write results to result struct, output txt files, and
                % save a recovery file after each trial
                % .........................................................
                [result, ex] = writeResults(ex, result, tr);
                
                % Allow the trial to be repeated more than once
                if tr.R==ex.R_NEEDS_REPEATING_LATER
                    repeatLater = [repeatLater, repeatLater(t)]; 
                end
                
                % If there was an error, exit
                if tr.R==ex.R_ERROR || tr.R==ex.R_ESCAPE
                    fatal_error=1; break;
                end
                
                % Increment trial index
                t = t + 1;
            end
            
            % End of block actions
            % .............................................................
            % Display end of block
            if ex.useScreen && ~exist('blockStart','var')
                drawTextCentred(scr, 'End of block', ex.fgColour);
                Screen('Flip', scr.w);
                myKbWait(ex);  % wait for keypress after each block
            end
            
            % Exit experiment if exit key is pressed
            [~,~,kcode] = KbCheck;
            if kcode(ex.exitkey) || fatal_error,  break;  end
            
            % Fatiguing experiment break: rest phase
            startTime = GetSecs();
            if ex.fatiguingExercise && b ~= ex.blocks
                waitDuration = 4.5 * 60; % 4,5 minutes waiting time
                % resting phase, wait ...
                waitTime = waitDuration - (GetSecs()-startTime);
                while waitTime > 0
                    waitTime = waitDuration - (GetSecs()-startTime);
                    msg = sprintf('You have a break now. Remaining break time: %d seconds',max(0,ceil(waitTime)));
                    drawTextCentred(scr, msg, ex.fgColour);
                    Screen('Flip', scr.w);
                    java.lang.Thread.sleep(1000);
                end
            end
        end
        
        % END OF EXPERIMENT
        %   Call experiment end function, if provided
        if exist('exptStartEnd','var') && ~fatal_error
            exptStartEnd(ex,'end');
        end
    else
        % If only running calibration, remove non-used variables
        result = rmfield(result,'trials');
    end
    
catch e                                  % in case of an error
    fprintf('Error : %s\n', e.message);  % display error message
    for ix=1:length(e.stack)
        disp(e.stack(ix));
        save 'errordump';
        if exist('result','var')
            result.data=result; % and still give back the data so far
        end
    end
end

% Cleanup
% -------------------------------------------------------------------------
% restore screen
if(ex.useScreen)
    Screen closeall;
end
% close eye data file then transfer
if ex.useEyelink
    if(Eyelink('isConnected'))
        Eyelink('closefile');
        fprintf('Downloading edf...');
        if Eyelink('receivefile',el.file,el.file) < 0
            fprintf('Error in receiveing file!\n');
        end
        fprintf('Done\n');
        Eyelink('shutdown');
    end
end
% close squeezy device
if ex.useSqueezy
    calllib(ex.mplib, 'disconnectMPDev');
    unloadlibrary('mpdev');
    fprintf('disconnecting MP150\n');
end

% Clear PTB and show the mouse cursor again
FlushEvents '';
ShowCursor;

% If ending abruptly, explain why
if fatal_error && exist('tr','var') 
    if tr.R == ex.R_ESCAPE            % was escape pressed?
        fprintf('Exiting -- Escape key pressed\n');
        fprintf('If this was unintentional, you might be able to resume the experiment by re-running it\n');
        fprintf('and using the result (e.g. ans or result from LastExperiment.mat) as the input parameter.\n');
    end
end

% rethrow errors? if enabled, this will require any user code after the
% experiment to catch the error if finalisation is required. this allows
% debugging directly into the location of the problem.
if isfield(ex,'rethrowErrors') && ex.rethrowErrors
    if ~isempty(e), rethrow(e); end
end
