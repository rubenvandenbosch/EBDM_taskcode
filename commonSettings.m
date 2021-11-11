function ex = commonSettings(ex)
% 
% DESCRIPTION
% Define experiment settings.
% 
% -------------------------------------------------------------------------
% 

% Description of protocol to save in results struct
ex.type = 'Food-related effort-based decision making task';

% Language of instructions ('NL' OR 'EN')
ex.language = 'NL';

% Run in debug mode?  debug mode: 1 block of 2 trials, for testing
ex.DEBUG = false;

% Directories and files
% =========================================================================
% Required directories for recording gripforce input
%   - Full path to conda environment to activate
%   - Full path to directory with gripforce recording code
ex.dirs.condaEnv  = 'C:\Users\rubvdbos\AppData\Local\Continuum\anaconda3\envs\flair';
ex.dirs.gripforce = fullfile(ex.dirs.rootDir,'gripforce');

% Directory containing image files with instructions
ex.dirs.instructions = fullfile(ex.dirs.rootDir,'instructions');

% Stimulus image files
%   last one must be fixationcross!
%   Not placed in .files field because it's referenced like this in the
%   original code (in prepareScreen)
ex.imageFiles = {'tree.jpg','1apple.jpg','3apple.jpg', '6apple.jpg', '9apple.jpg', '12apple.jpg','fixationcross.png'};

% Recovery file
%   Full path to the experiment recovery file that is saved after every
%   trial and can be used to restore a session, e.g. after a crash.
%   This file is overwritten on each new experiment session.
ex.files.recovery = fullfile(ex.dirs.rootDir,'LastExperiment_recovery.mat');

% Trial structure settings
% =========================================================================
% Effort and reward levels specification
% -------------------------------------------------------------------------
% 4 x 4 effort x reward

% What are the different levels of rewards that will be used. Make sure jpgs of apple tree match this.
% Change to something that makes sense for our stimuli
ex.applesInStake = [1 3 6 9];  % [1 3 6 9 12]; 

% Effort levels corresponding to the variable 'force' in 'drawTree'.
ex.effortIndex   = 1:4; % [1 2 3 4 5];

% Define effort level as proportion of MVC
ex.effortLevel   = [0.2 0.4 0.6 0.8]; % [0.16 0.32 0.48 0.64 0.80];

% Order of familiarizing with force levels.
% true = use force levels 1 1 2 2 3 3 etc, false = 1...6,1...6
ex.practiceAscending    = false; 

% Elements to vary over trials or blocks
% -------------------------------------------------------------------------
%   ex.blockVariables.<var> = <list or vector with possible values>
%   ex.trialVariables.<var> = <list or vector with possible values>

% Vary block types?
ex.blockVariables.blocktype = 1;   % Force all blocks same = 1

% Allow unequal number of trials per trial type within one block
ex.allowUnequalTrials  = true;

% We probably want to use this option to specify reward type, reward
% magnitude and effort level.
% ....................................
%   ex.trialVariables.reward_type = {'lowCal','highCal'};
%   ex.trialVariables.reward_magn = {'low','high'};
%   ex.trialVariables.effort = 1:4;
% Having two varying reward variables might make things complicated.
% Instead use a 4-level reward coding? 
%   1=lowCal_lowMag, 2=lowCal_highMag, 3=highCal_lowMag, 4=highCal_highMag
ex.trialVariables.reward = 1:numel(ex.effortIndex);
ex.trialVariables.effort = 1:numel(ex.applesInStake);

% Vary whether Yes/No response option is on the left
% ex.trialVariables.yesIsLeft = [true false];

% Force Yes response option on the left. Not sure if this works without
% fixed trial orders; to be tested I suppose
% ex.yesIsLeft = false;

% There are HARDCODED 5x5 effort x reward levels later on!!
% -------------------------------------------------------------------------
% Use 5x5 for now to test, then change hardcoded elements to implement 4x4
% or other designs
        ex.yesIsLeft            = false;
        ex.applesInStake        = [1 3 6 9 12];% What are the different levels of rewards that will be used. Make sure jpgs of apple tree match this.
        ex.effortIndex          = [1 2 3 4 5];  % Effort levels corresponding to the variable 'force' in 'drawTree'.
        %16/7/18     ...
        ex.effortLevel          = [0.16 0.32 0.48 0.64 0.80]; % Effort - Proportion of MVC
        %effort required on each trial (column vector of 100 trials)
        ex.order_effort= [
            4 5 5 5 3 3 2 4 1 3 4 4 5 3 5 1 2 2 4 1 1 2 3 1 2 ... % each row is one block
            4 5 3 2 1 5 5 5 2 3 2 2 5 1 4 4 3 4 1 3 4 3 1 2 1 ...
            2 3 3 5 4 4 5 1 2 4 2 3 5 5 4 2 1 1 1 5 3 4 2 1 3 ...
            5 3 4 5 1 1 2 1 4 2 5 5 4 3 4 4 3 1 5 2 1 3 3 2 2 
            ]';
        %    3 2 4 4 1 2 5 5 3 4 2 2 3 4 5 4 5 1 1 1 3 1 5 3 2
        % Offered reward on each trial
        % one fifth of each of the levels 1 to 5
        % 25 x 4 trials
        ex.order_reward =[
            4 2 1 5 4 2 2 5 5 3 1 3 4 5 3 2 5 1 2 3 1 3 1 4 4 ...
            4 2 3 2 1 5 1 3 1 2 5 3 4 3 5 1 4 3 2 5 2 1 4 4 5 ...
            5 3 5 2 2 4 1 4 3 3 1 2 3 4 5 2 5 3 1 5 1 1 4 2 4 ...
            3 1 4 4 5 1 3 3 2 4 1 2 1 4 3 5 5 2 5 2 4 2 3 5 1 
            ]';
        %    2 4 1 2 4 3 2 3 1 5 5 1 4 3 4 4 1 2 5 3 5 1 5 3 2
        % trial set to use for practice (i.e. drawn form the above list)
        ex.practiceTrialIndex   = [ 1;2;3;4;5 ]; 
        ex.last_trial           = [];
% -------------------------------------------------------------------------

% Block settings depending on experiment stage
% =========================================================================
switch ex.stage
    case 'practice'
        % Practice stage: 
        %   - calibration of maximum voluntary contraction (MVC)
        %       Use ex.calibOnly=true to only run the MVC calibration
        %   - familiarization with the different effort levels (based on
        %     MVC)
        %   - Practice choice task
        ex.calibNeeded          = true;
        ex.calibOnly            = false;  % If true, only MVC calibration is run
        
        % Number of MVC calibration trials
        ex.numCalibration       = 3;
        
        % Number of trials to familiarize with effort levels. Ideally an
        % multiple of the number of effort levels (e.g. 3x4=12 to practice
        % each of 4 effort levels 3 times).
        ex.numFamiliarise       = 5; %12;
        
        % Number of practice decisions about X effort for X reward
        ex.numPracticeChoices   = 5;
        
        % Set total number of trials based on the above
        ex.practiceTrials       = ex.numCalibration + ex.numFamiliarise + ex.numPracticeChoices;
        ex.blockLen             = ex.practiceTrials;
        ex.last_trial           = [];
        
        % Set the block number on which people are asked to actually 
        % perform selected effort for reward options during the choice task
        % to number that will never be reached
        ex.choiceBlockNumber    = 99;
        
        % Stage performed inside MRI scanner?
        ex.inMRIscanner = false;
    
    case 'choice'
        % Choice stage:
        %   - decision trials about expending effort for reward, performed
        %     in the MRI scanner.
        ex.inMRIscanner = true;
        
        % Number of blocks and trials per block
        %   NB: with a 4x4 design, a block length of 16 or 32 allows for 
        %       equal number of occurance per trial type within a block
        ex.blocks   = 1;   % Number of blocks
        ex.blockLen = 16;  % number of  trials within each block

        % Include this number of practice choice trials at the beginning?
        ex.numPracticeChoices   = 0;
        
        % How many retries are allowed (>=0 or Inf for endless retries)
        ex.maxNumRepeatedTrials = Inf;
        
        % Set the block number on which people are asked to actually 
        % perform selected effort for reward options during the choice task
        % to number that will never be reached
        ex.choiceBlockNumber    = 99;
        
        % Turn off the calibration and effort familiarization
        ex.calibNeeded          = false;
        ex.calibOnly            = false;
        ex.numCalibration       = 0;   
        ex.numFamiliarise       = 0;   
        
        % Set total number of practice trials based on the above
        ex.practiceTrials       = ex.numCalibration + ex.numFamiliarise + ex.numPracticeChoices; 
        assert(~(ex.practiceTrials > ex.blockLen),'Set parameter "blockLen >= "practiceTrials"');
        
    case 'perform'
        % Perform stage:
        %   - Performance of the effort for reward decisions made. A number
        %     of decisions from the choice stage are selected and whenever
        %     an offer of a certain effort level for a reward magnitude was
        %     accepted, perform the gripforce effort to try and obtain the
        %     reward
        
        % Number of blocks and trials per block
        ex.blocks   = 1;   % Number of blocks
        ex.blockLen = 16;  % number of  trials within each block
        
        % Practice a number of trials with different effort levels without
        % reward?
        ex.numPracticeChoices   = 0;
        
        % Block number from which people are to actually perform gripforce 
        % effort. Set to 1, as that's all we do at this stage
        ex.choiceBlockNumber    = 1;
        
        % How many retries are allowed (>=0 or Inf for endless retries)
        ex.maxNumRepeatedTrials = Inf;
        
        % Load subject's results from output file to load their decisisions
        % in the choice stage
        % .................................................................
        % Get choices output mat file and assert it exists
        choices_file = fullfile(ex.dirs.output, sprintf('subject-%.3d_visit-%d_stage-choice_ses-%d.mat', ex.subject,ex.visit,ex.session));
        assert(exist(choices_file,'file') == 2, 'The choices output file does not exist: %s',choices_file);
        
        % Load choices data
        ex.resultsChoiceTask = load(choices_file);
        YesResp = [ex.resultsChoiceTask.result.data.Yestrial];

        % Assert that the number of perform trials is not greater than the
        % number of decisions made in the choice stage
        assert(ex.resultsChoiceTask.result.params.blockLen * ex.resultsChoiceTask.result.params.blocks >= ex.blockLen || ex.DEBUG, ...
            'There are more trials to perform effort for (%d) than the number of decisions made in the choice stage (%d)', ...
            ex.blocks * ex.blockLen, ex.resultsChoiceTask.result.params.blockLen * ex.resultsChoiceTask.result.params.blocks);
        
        % Pseudorandomly select trials where force to be performed after 
        % all choices
        %       This function uses HARDCODED 5x5 effort x reward levels!! CHANGE!
        allCombinationsOnce = combinationsEffortReward(ex.order_effort,ex.order_reward,1);
        ex.last_trial = allCombinationsOnce;
                
        % Turn off the calibration and effort familiarization
        ex.calibNeeded          = false;
        ex.calibOnly            = false;
        ex.numCalibration       = 0;
        ex.numFamiliarise       = 0;
        
        % Set total number of practice trials based on the above
        ex.practiceTrials       = ex.numCalibration + ex.numFamiliarise + ex.numPracticeChoices; 
        assert(ex.practiceTrials <= ex.blockLen,'Set parameter "blockLen >= "practiceTrials"');
        
        % Stage performed inside MRI scanner?
        ex.inMRIscanner = false;
end

% Other block settings
% No sure whether we can leave this out, just set to false for now
% -------------------------------------------------------------------------
% Do fatiguing experiment? Seems to be like perform trials, but effort 
%   level is dynamically adjusted based on success rate
ex.fatiguingExercise    = false;
ex.fatiguingExerciseSTartEffortLevel = 0.3;

% Timings (seconds)
% =========================================================================
% Intertrial interval
% Time will be randomly chosen in the interval minITI - maxITI    %% CHANGE TO E.G. A POISSON DRAW?
ex.minITI               = 0.5;
ex.maxITI               = 4;

% Calibration phase
% .........................................................................
ex.calibrationDuration  = 5;   % Time for calibration squeeze

% Decision phase
% .........................................................................
ex.maxTimeToWait        = 10;  % Time that a participant has to accept/reject offer. Starts from onset "Yes/No" response options

% Time between offer onset (tree with effort+stake) and "Yes/No" response
% options onset.
%   set to a number to have fixed delays
%   set to 'RandPoisson' to have 2-4 seconds random delays (poisson distribution)
%   set to 'RandNormal' to have 2-4 seconds random delays (normal distribution)
ex.timeBeforeChoice     = 'RandNormal';

% Performance phase
% .........................................................................
ex.responseDuration     = 5;   % Time allowed to reach required force+duration on practice and work-phase Yes trials
ex.minSqueezeTime       = 2;   % Minimum required squeeze time at force level of trial to mark it success (converted to number of gripforce samples below).
ex.delayAfterResponse   = 1;   % Time after squeeze period ends, and before reward appears (practice and work)
ex.rewardDuration       = 3;   % Time from when reward appears, until screen blanks (practice and work-yes)

% Technical setup
% =========================================================================
% Response key settings
% -------------------------------------------------------------------------
% Keyboard
KbName('UnifyKeyNames');   % Use OS-independent key naming scheme
ex.leftKey     = KbName('LeftArrow');
ex.rightKey    = KbName('RightArrow');

% Bitsi buttonbox
ex.COMportBitsiBB = 'COM2';  % set to '' to simulate bitsi buttonbox
ex.leftButton  = 'a';
ex.rightButton = 'b';

% Response keys: use buttonbox or keyboard?
%   Current experimental setup: choice stage is in the scanner using the 
%   bitsi buttonbox, the calibration/practice stage and performance stage
%   outside the scanner using a keyboard.
switch ex.stage
    case {'practice','perform'}
        ex.useBitsiBB = false;
    case 'choice'
        % For testing with keyboard, set to false
        ex.useBitsiBB = false; 
        
        % Initialize bitsi buttonbox object for response pads used in MRI
        %   Do it here to catch errors early
        if ex.useBitsiBB
            delete(instrfindall);
            ex.BitsiBB = Bitsi_2016(ex.COMportBitsiBB); % create a serial object
            ex.BitsiBB.setTriggerMode();
            ex.leftKey   = ex.leftButton;
            ex.rightKey  = ex.rightButton;
        end
end

% MRI scanner options
% -------------------------------------------------------------------------
% Number of scans triggers to wait for at the start of an fMRI run
ex.waitNumScans = 5;

% Trigger info
%   COMport receiving scanner triggers, and
%   character code sent by scanner as trigger
ex.COMportMRI     = 'COM3';   % set to '' to simulate bitsi
ex.triggerKeyCode = 97;       % 97 = key 'a' (set to 4 if simulated bitsi)

% Initialize bitsi serial object for incoming MRI triggers
%  Only if inMRIscanner = true
%  Do it here to catch errors early
if ex.inMRIscanner
    delete(instrfindall);
    ex.BitsiMRI = Bitsi_2016(ex.COMportMRI); % create a serial object
    ex.BitsiMRI.setTriggerMode();
end

% Display options
% -------------------------------------------------------------------------
ex.skipScreenCheck   = 1;               % should be 0, but set to 1 if you get monitor warnings (use 0/1 double, not logical)
ex.displayNumber     = 0;               % 1 for multiple monitors

ex.bgColour          = [0 0 0];         % background
ex.fgColour          = [255 255 255];   % text colour, white
ex.fgColour2         = [  0 255   0];   % lime green to highlight Yes/No choice
ex.fgColour3         = [  0   0 255];   % text colour, blue
ex.silver            = [176 196 172];   % used for rungs of ladder
ex.brown             = [160  82  45];   % brown tree trunk
ex.yellow            = [255 255   0];   % wider (current) rung
ex.size_text         = 24;              % size of text
ex.forceBarPos       = [300 150];       % location of force bars on Screen, in pixels; Original was [300 150]
ex.forceBarWidth     = 50;              % width of force bars, in px
ex.forceColour       = [255 0 0];       % bar colour for force, red
ex.forceScale        = 200;             % scale of size of force bars (pixels); Original ws 200
ex.extraWidth        = 20;              % How much wider is the force-level indicator than the bar (px).

% Gripforce options
% -------------------------------------------------------------------------
% Only for the practice and perform stages
switch ex.stage
    case {'practice','perform'}
        ex.useGripforce      = true;   % Change to 1 to use GripForce device (manufactured by TSG department, Radboud University)
        ex.useSqueezy        = false;  % Change to 1 to use handles! whether or not to use the squeezy devices
        ex.simulateGripforce = false;  % For testing without a gripforce
        ex.channel           = 1;      % Which data channel are you using for the handle?
        
        % Start recording gripforce input
        % .................................................................
        % First determine whether the gripforce buffer is already on
        if ispc
            [~,pinfo] = system('netstat -ano | findstr :1972');
        elseif isunix
            [~,pinfo] = system('netstat -anp | grep :1972');
        end
        % Figure out whether a new process for the gripforce should be
        % started
        if ~isempty(pinfo)
            pinfo = textscan(strtrim(pinfo),'%[^\n\r]');
            pinfo = pinfo{1};
            if size(pinfo,1) > 1 
                newP = false;
            elseif pinfo(end) == '0'
                newP = true;
            end
        else
            newP = true;
        end
        % If not running yet, call system command to start gripforce with 
        % '&' to start a separate process instead of running the command 
        % within matlab
        if newP
            if ispc
                system([fullfile('gripforce','start_gripforce.bat') ' ' ex.dirs.condaEnv ' ' ex.dirs.gripforce ' &']);
            elseif isunix
                system([fullfile('gripforce','start_gripforce.sh') ' ' ex.dirs.condaEnv ' ' ex.dirs.gripforce ' &']);
            end
            WaitSecs(6); % Give process enough time to start
        else
            disp('Gripforce fieldtrip buffer is running. Not starting anew')
        end
        
        % Initialize gripforce and store sampling rate of gripforce
        if ex.useGripforce && ~ex.simulateGripforce
            ex = initGripforce(ex);
        elseif ex.useGripforce && ex.simulateGripforce
            % If simulated gripforce, set sampling rate to 500 Hz
            ex.MP_SAMPLE_RATE=500;
        elseif ex.useSqueezy
            % NB: also configured in RunExperiment!!
            if ~isfield(ex, 'MP_SAMPLE_RATE'), ex.MP_SAMPLE_RATE=500; end
        end
        
        % Set the required number of gripforce samples above threshold for 
        % success, based on setting specified above.
        ex.minimumAcceptableSqueezeTime = ex.MP_SAMPLE_RATE * ex.minSqueezeTime;

    case 'choice'
        % Don't use gripforce during choice stage
        ex.useGripforce      = false;
        ex.useSqueezy        = false;
        ex.simulateGripforce = false;
        ex.channel           = 1;
end

% Eye tracker options
% -------------------------------------------------------------------------
ex.useEyelink = false;

% Debugging options
% =========================================================================
ex.rethrowErrors     = true;  % Rethrow actual error instead of printing message only

% Trial and block structure to use when debugging
if ex.DEBUG
    ex.order_effort = [ 5;5; 3;2; 4;4; 3;5; 2;4 ];
    ex.order_reward = [ 5;3; 2;4; 5;3; 3;5; 3;4 ];
    ex.blocks       = 1;
    ex.blockLen     = 2;
    ex.last_trial   = [ 1;2; 3;4; 5;6 ];
end
end