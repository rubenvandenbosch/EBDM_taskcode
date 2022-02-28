function ex = commonSettings(ex)
% 
% DESCRIPTION
% Define experiment settings.
% 
% -------------------------------------------------------------------------
% 

% Switch between task versions
%   'apple' : original apple gathering task scenario
%   'food'  : food-related effort-based decision making task scenario with
%             vending machine stimulus.
ex.TaskVersion = 'food';

% If doing the food-related EBDM scenario, choose whether to use sweet or
% savory food rewards
if strcmpi(ex.TaskVersion,'food')
    ex.FoodVersion = 'sweet';
end

% Description of protocol to save in results struct
ex.description = 'Food-related effort-based decision making task';

% Language of instructions ('NL' OR 'EN')
ex.language = 'NL';

% Run in debug mode?  debug mode: 1 block of 2 trials, for testing
ex.DEBUG = false;

% Directories and files
% =========================================================================
% Required directories for recording gripforce input
%   - Full path to directory with functions .m files
%   - Full path to directory with gripforce recording code
ex.dirs.functions = fullfile(ex.dirs.rootDir,'functions');
ex.dirs.gripforce = fullfile(ex.dirs.functions,'gripforce');

% Full path to virtual environment to activate 
%   required packages: pyserial, numpy.
%   Default path is "venv_EBDM" one level up from root code dir.
%   If it is an Anaconda virtual environment, set dirs.venv.conda to true.
ex.dirs.venv.path  = fullfile(ex.dirs.rootDir,'..','venv_EBDM');
ex.dirs.venv.conda = false;

% Directory containing image files with instructions
ex.dirs.instructions = fullfile(ex.dirs.rootDir,'instructions',lower(ex.TaskVersion));

% Stimulus image files
%   first one must be the no-reward image of an empty tree/vending machine!
%   last one must be fixationcross!
% 
%   Only file names (files are looked for in the stimuli directory)
%   file name pattern: '<number><itemName>.jpg', e.g. '3apple.jpg'
switch ex.TaskVersion
    case 'apple'
        ex.imageFiles = {'tree.jpg','1apple.jpg','3apple.jpg', '6apple.jpg', '9apple.jpg', '12apple.jpg','fixationcross.jpg'};
    case 'food'
        % Image files and names of food stimuli
        if strcmpi(ex.FoodVersion,'sweet')
            ex.imageFiles = {'vending_machine.jpg','1blueberry.jpg','1m&m.jpg','4blueberry.jpg','4m&m.jpg','fixationcross.jpg'};
            
            % Store food stimuli names (list in increasing calories)
            %   English name must match name in image file name
            ex.foodStimNames.EN = {'blueberry','m&m'};
            ex.foodStimNames.NL = {'blauwe bes','m&m'};
            
        elseif strcmpi(ex.FoodVersion,'savory')
            ex.imageFiles = {'vending_machine.jpg','1cucumber.jpg','1pringle.jpg','4cucumber.jpg','4pringle.jpg','fixationcross.jpg'};
            
            % Store food stimuli names (list in increasing calories)
            %   English name must match name in image file name
            ex.foodStimNames.EN = {'cucumber','pringle'};
            ex.foodStimNames.NL = {'komkommer','pringle'};
        end
end

% Trial structure settings
% =========================================================================
% Effort and reward levels specification
% -------------------------------------------------------------------------
% 2 x 2 x 4 design
% reward_magnitude x calories x effort
% low(1 piece)/high(4 pieces) x low cal(1)/high cal(2) x 4 effort levels

% Levels of reward magnitude
%   Make sure the numbers in the names of jpgs of stimuli match this.
ex.rewardLevel = [1 4];

% Levels of food reward calories variable
ex.caloriesLevel = {'low','high'};

% Effort levels: proportions of maximum voluntary contraction (MVC)
ex.effortLevel = [0.1 0.33 0.56 0.8];

% Order of familiarizing with force levels.
% true = use force levels 1 1 2 2 3 3 etc, false = 1...6,1...6
ex.practiceAscending = false; 

% Elements to vary over trials or blocks
% -------------------------------------------------------------------------
%   ex.blockVariables.<var> = <list or vector with possible values>
%   ex.trialVariables.<var> = <list or vector with possible values>

% Variables to vary over blocks
%   Set one variable of length 1 to force all blocks same
ex.blockVariables.blocktype = 1;

% Allow unequal number of trials per trial type within one block
ex.allowUnequalTrials = true;

% Variables to vary over trials
%   Reward and effort index (based on reward/effort levels specified above)
ex.trialVariables.rewardIx   = 1:numel(ex.rewardLevel);
ex.trialVariables.caloriesIx = 1:numel(ex.caloriesLevel);
ex.trialVariables.effortIx   = 1:numel(ex.effortLevel);

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
        
        % Number of MVC calibration trials
        ex.numCalibration       = 3;
        ex.calibOnly            = false;  % If true, only MVC calibration is run
        
        % Number of trials to familiarize with effort levels. Ideally an
        % multiple of the number of effort levels (e.g. 3x4=12 to practice
        % each of 4 effort levels 3 times).
        ex.numFamiliarise       = 12;
        
        % Ask participants to indicate subjective effort experience on a
        % VAS scale for each effort level? Appears after the final
        % familiarize trial of each effort level
        ex.effortVAS            = false;
        
        % Number of practice decisions about X effort for X reward
        ex.practiceTrials       = 6;
        
        % Random order of practice trials?
        ex.shufflePracticeTrials = true;
        
        % Set total number of trials based on the above
        ex.blockLen   = ex.numCalibration + ex.numFamiliarise + ex.practiceTrials;
        ex.last_trial = [];
        
        % Set the block number on which people are asked to actually 
        % perform selected effort for reward options during the choice task
        % to number that will never be reached
        ex.choiceBlockNumber    = 99;
        
        % Stage performed inside MRI scanner?
        ex.inMRIscanner         = false;
    
    case 'choice'
        % Choice stage:
        %   - decision trials about expending effort for reward, performed
        %     in the MRI scanner.
        ex.inMRIscanner         = true;
        
        % Number of blocks and trials per block
        %   NB: with a 4x4 design, a block length of 16 or 32 allows for 
        %       equal number of occurance per trial type within a block
        ex.blocks               = 6;   % Number of blocks
        ex.blockLen             = 16;  % number of  trials within each block
        ex.blockBreakTime       = 10;  % Rest time betwen blocks (seconds)

        % Include this number of practice choice trials at the beginning?
        ex.practiceTrials       = 4;
        
        % Random order of practice trials?
        ex.shufflePracticeTrials = true;
        
        % How many retries are allowed (>=0 or Inf for endless retries)
        ex.maxNumRepeatedTrials = Inf;
        
        % Set the block number on which people are asked to actually 
        % perform selected effort for reward options during the choice task
        % to number that will never be reached
        ex.choiceBlockNumber    = 99;
        
        % Turn off the calibration and effort familiarization
        ex.numCalibration       = 0;
        ex.numFamiliarise       = 0;
        
    case 'perform'
        % Perform stage:
        %   - Performance of the effort for reward decisions made. A number
        %     of decisions from the choice stage are selected and whenever
        %     an offer of a certain effort level for a reward magnitude was
        %     accepted, perform the gripforce effort to try and obtain the
        %     reward
        
        % Number of blocks and trials per block
        ex.blocks               = 2;  % Number of blocks
        ex.blockLen             = 16; % number of  trials within each block
        ex.blockBreakTime       = 8;  % Rest time betwen blocks (seconds)
        
        % Practice a number of trials with different effort levels without
        % reward?
        ex.practiceTrials       = 3;
        
        % Random order of practice trials?
        ex.shufflePracticeTrials = true;
        
        % Block number from which people are to actually perform gripforce 
        % effort. Set to 1, as that's all we do at this stage
        ex.choiceBlockNumber    = 1;
        
        % How many retries are allowed (>=0 or Inf for endless retries)
        ex.maxNumRepeatedTrials = Inf;
                
        % Turn off the calibration and effort familiarization
        ex.numCalibration       = 0;
        ex.numFamiliarise       = 0;
        
        % Set total number of practice trials based on the above
        ex.practiceTrials = ex.numCalibration + ex.numFamiliarise + ex.practiceTrials; 
        assert(ex.practiceTrials <= ex.blockLen,'Set parameter "blockLen >= "practiceTrials"');
        
        % Stage performed inside MRI scanner?
        ex.inMRIscanner = false;
end

% Set calibration needed flag depending on whether any calibration trials
% are requested. If no calibration needed, automatically unset calibOnly.
if ex.numCalibration > 0, ex.calibNeeded = true;
else, ex.calibNeeded = false; ex.calibOnly = false; end

% Other block settings
% No sure whether we can leave this out, just set to false for now
% -------------------------------------------------------------------------
% Do fatiguing experiment? Seems to be like perform trials, but effort 
%   level is dynamically adjusted based on success rate
ex.fatiguingExercise = false;
ex.fatiguingExerciseSTartEffortLevel = 0.3;

% Timings (seconds)
% =========================================================================
% Calibration phase
% .........................................................................
ex.calibrationDuration  = 5;   % Time for calibration squeeze

% Choice phase
% .........................................................................
% Intertrial interval (ITI)
%   set ex.methodITI to a number to have fixed ITIs (in secs)
%   set ex.methodITI to 'randUniform' to have random ITIs between
%       ex.minITI and ex.maxITI
%   set ex.methodITI to 'randNormal' to have random delays drawn
%       from a normal distribution with mean of ex.meanITI (must be
%       between min and max delay) that is truncated to produce draws
%       between ex.minITI and ex.maxITI. The variance is set to
%       (1/mean)*range, unless specified in ex.sigmaITI.
switch ex.stage
    case {'practice','choice'}
        ex.methodITI    = 'randNormal';
        ex.minITI       = 3;
        ex.maxITI       = 8;
        ex.meanITI      = 5;
    case 'perform'
        ex.methodITI    = 'randUniform';
        ex.minITI       = 1;
        ex.maxITI       = 4;
end

% Time between offer onset (tree with effort+stake) and "Yes/No" response
% options onset.
%   set ex.methodChoiceDelay to a number to have fixed delays (in secs)
%   set ex.methodChoiceDelay to 'randUniform' to have random delays between
%       ex.minChoiceDelay and ex.maxChoiceDelay
%   set ex.methodChoiceDelay to 'randNormal' to have random delays drawn
%       from a normal distribution with mean of ex.meanChoiceDelay (must be
%       between min and max delay) that is truncated to produce draws
%       between ex.minChoiceDelay and ex.maxChoiceDelay. The variance is
%       set to (1/mean)*range, unless specified in ex.sigmaChoiceDelay.
ex.methodChoiceDelay    = 'randNormal';
ex.minChoiceDelay       = 3;
ex.maxChoiceDelay       = 6;
ex.meanChoiceDelay      = 4;

% Time that a participant has to accept/reject offer. 
%   Starts from onset "Yes/No" response options
ex.maxRT                = 4;

% Performance phase
% .........................................................................
ex.responseDuration     = 5;   % Time allowed to reach required force+duration on practice and work-phase Yes trials
ex.minSqueezeTime       = 2;   % Minimum required squeeze time at force level of trial to mark it success (converted to number of gripforce samples below).
ex.delayAfterResponse   = 1;   % Time after squeeze period ends, and before reward appears (practice and perform stage)
ex.rewardDuration       = 3;   % Time from when reward appears, until screen blanks (practice and perform stage)

% Technical setup
% =========================================================================
% Set random number generator seed based on subject and session number
ex.randomSeed = str2double(sprintf('%d%d', ex.subject,ex.session));

% Remove potentially connected COM devices
delete(instrfindall);

% Response key settings
% -------------------------------------------------------------------------
% Keyboard
KbName('UnifyKeyNames');   % Use OS-independent key naming scheme
ex.leftKey     = KbName('LeftArrow');
ex.rightKey    = KbName('RightArrow');
ex.exitkey     = KbName('Escape');

% Bitsi buttonbox
ex.COMportBitsiBB = 'COM2';  % set to '' to simulate bitsi buttonbox
ex.leftButton  = ['a', 'f'];
ex.rightButton = ['b', 'e'];

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
ex.COMportMRI     = ''; %'COM3';   % set to '' to simulate bitsi
ex.triggerKeyCode = 65; %97;       % 97 = key 'a' (set to 65 if simulated bitsi)

% Initialize bitsi serial object for incoming MRI triggers
%  Only if inMRIscanner = true
%  Do it here to catch errors early
if ex.inMRIscanner
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
ex.darkgrey          = [40 40 40];      % dark grey color
ex.silver            = [176 196 172];   % used for rungs of ladder
ex.brown             = [160  82  45];   % brown tree trunk
ex.yellow            = [255 255   0];   % wider (current) rung
ex.size_text         = 24;              % size of text
ex.forceBarPos       = [100 150];       % location/length of force bar (pixels); [<x-offset> <half of length>]; was [300 150]
ex.forceBarWidth     = 50;              % width of force bars, in px
ex.forceColour       = [255 0 0];       % bar colour for force, red
ex.forceScale        = 200;             % scale of size of force bars (pixels); Original ws 200
ex.extraWidth        = 20;              % How much wider is the force-level indicator than the bar (px)
if strcmpi(ex.TaskVersion,'food')
    ex.VMdim         = [325 455];       % Dimensions of vending machine stimulus image (pixels)
end

% Gripforce options
% -------------------------------------------------------------------------
% Only for the practice and perform stages
ex.COMportGripforce = 'COM5';
switch ex.stage
    case {'practice','perform'}
        ex.useGripforce      = true;   % Change to 1 to use GripForce device (manufactured by TSG department, Radboud University)
        ex.useSqueezy        = false;  % Change to 1 to use handles! whether or not to use the squeezy devices
        ex.simulateGripforce = false;  % For testing without a gripforce
        ex.channel           = 1;      % Which data channel are you using for the handle?
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

% Use just 2 trials when debugging
if ex.DEBUG
    ex.blocks   = 1;
    ex.blockLen = 2;
end
end