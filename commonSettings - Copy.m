function ex = commonSettings()
% Apple gathering task
%  * The main bulk of the exeriment is making yes/no decsions 
%    (by pressing the arrow keys) about whether the
%    stake offered is "worth it" for the effort required.
%  * This script is for the transdiagnostic patient studies.
%  * The order of trials and blocks is FIXED in advance
%  * Hold escape to exit.
%  * If you already have performed calbriaton and practice 
%    you can select the previous result file and start from the 
%    experimental blocks, by setting "calibNeeded".
%
% You need to have:
%  * Add latest "matlib" to the path - requires RunExperiment.m,
%    createTrials.m, prepareScreen
%  * All the apple.jpg images in the folder you are working from
%  * Hand dynamometer eg. SS25LA connected to MP150 via DA100C 
%    and UIM100C, set up already, configured to Channel 1
%  * or alternatively, TSG RU manufactured gripforce device in combination
%    with a fieldtrip saving buffer to stream the gripforce data.
%
%%% STRUCTURE
%
% There are 4 phases to the experiment
% 1  calibration - calculate their max grip strength (MVC) initial squeeze
%    and then 2 attempts at the yellow line (=110% then 105% MVC)
% 2. Practice/Familiarisation - 2 practices of each force level
% 3. Decisions - Self-paced (10s time out) choices of effort for reward, 
%    no squeezing, 5 effort x 5 reward levels, 25 trials x 4 blocks.
% 4. Execute 25 trials selected randomly from the choices in part 3, but 
%    such that all effort/reward combinations are selected once. This
%    combination is randomly selected from the 4 repetitions. Forced
%    squeezing required for trials that were accepted.
% 

start_apple_task(); % script to set Matlab path
KbName('UnifyKeyNames')%YS change as KbName seems to recognise left and ...

%% Things to adjust (START) %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% OUTPUT
fld = fileparts(mfilename('fullpath'));
ex.outputFolder = fullfile(fld,'..','output'); % folder to store all genrated output

% FMRI Scanner
ex.waitNumScans         = 5;   % number of scans to wait for before starting the actual experiment
ex.fmriComport          = 'COM2';  % set to '' to simulate bitsi buttonbox

% KEYS 
% (bitsi buttonbox, fmri)
%ex.leftButton           = 'a'; %80 for simulated bitsi (i.e., keyboard)  %%BLjuli2021: aangepast voor twee buttonboxen
%ex.rightButton          = 'b'; %79 for simulated bitsi (i.e., keyboard)  %%BLjuli2021: aangepast voor twee buttonboxen
ex.leftButton           = ['a', 'f']; %80 en ? for simulated bitsi (i.e., keyboard)  %%BLjuli2021: aangepast voor twee buttonboxen
ex.rightButton          = ['b', 'e']; %79 en ? for simulated bitsi (i.e., keyboard)  %%BLjuli2021: aangepast voor twee buttonboxen
% (keyboard)
ex.leftKey              = KbName('LeftArrow');
ex.rightKey             = KbName('RightArrow');

% TIMINGS (all in seconds)
ex.calibrationDuration  = 5;   % Time for calibration squeeze
ex.maxTimeToWait        = 10;  % Time that a participant has to accept/reject (answering yes/no)

% timeBeforeChoice: Time after options (tree with effort+stake) appear, before "Yes/No" appears and maxTimeToWait starts
% set ex.timeBeforeChoice to a number to have fixed delays between tree and yes/no appearance 
% set ex.timeBeforeChoice to a 'RandPoisson' to have 2-4 seconds random delays (poisson distribution) between tree and yes/no appearance 
% set ex.timeBeforeChoice to a 'RandNormal' to have 2-4 seconds random delays (normal distribution) between tree and yes/no appearance 
ex.timeBeforeChoice     = 'RandNormal';

ex.responseDuration     = 5;   % Time allowed to reach required force+duration on practice and Work-phase Yes trials
ex.delayAfterResponse   = 1;   % Time after squeeze period ends, and before reward appears (practice and work)
ex.rewardDuration       = 3;   % Time from when reward appears, until screen blanks (practice and work-yes)
% time will be randomly chosen in the interval minITI - maxITI
ex.minITI               = 0.5; % minimal fixation cross time duration, only shown before decision trials
ex.maxITI               = 4;   % maximum fixation cross time duration, only shown before decision trials

ex.maxNumRepeatedTrials = Inf; % How many retries are allowed (>=0 or Inf for endless retries)

% LANGUAGE
ex.language = 'NL'; % set to 'EN' for english

%% Things to adjust (END) %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Nothing should be changed in the settings below
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ex.useBitsiBB           = 0;   % in cubicles (non-fmri) a keyboard will be used, not a buttonbox

%right arrows differently on different trials. UnifyingKeyNames ensures...
%all key names are used interchangeably.  
ex.yesIsLeft           = false;% currently yes is always shown on the left.
ex.allowUnequalTrials  = true;% allows randomisation for uneven trial...
%numbers. Explanation can be found in createTrials script.
ex.trialVariables.yesIsLeft = [true false];


%% Calibration
ex.calibNeeded          = false;
ex.calibOnly            = false; 

%% Fatiguing added exercise
ex.fatiguingExercise    = false;
ex.fatiguingExerciseSTartEffortLevel = 0.3;

ex.type                 = 'AGT for core protocol 2018';

%% SETUP
ex.DEBUG                = false;         % debug mode - 2 trials per block, for testing.
ex.rethrowErrors        = true;      % RB 2021

ex.skipScreenCheck      = 1;             % should be 0, but set to 1 if you get monitor warnings.
ex.displayNumber        = 0;             % 1 for multiple monitors

ex.channel              = 1;             % Which data channel are you using for the handle?
ex.useSqueezy           = false;          % Change to 1 to use handles! whether or not to use the squeezy devices
ex.useGripforce         = true;          % Change to 1 to use GripForce device (manufactured by TSG department, Radboud University)


ex.simulateGripforce    = false;         % actual experiment, use gripforce
%ex.simulateGripforce    = true;         % for testing without a gripforce

ex.useEyelink           = false;         % load eye tracker?

%% STRUCTURE
ex.trialVariables.trialtype = 0;

% the block number on which people are asked to actually perform selected
% squeezes (at the end of the experiment).
ex.choiceBlockNumber    = 99; % set to number that will never be reached 

ex.blocktype            = 1;   % all blocks same =1
ex.practiceAscending    = false; % true = use force levels 1 1 2 2 3 3 etc, false = 1...6,1,...6

% 5 x 5 effort x reward
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% below for debugging only! %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ex.fmriComport          = '';%'COM2';  % set to '' to simulate bitsi buttonbox
% ex.leftButton           = 80;%'a'; %80 for simulated bitsi (i.e., keyboard)
% ex.rightButton          = 79;%'b'; %79 for simulated bitsi (i.e., keyboard)
% ex.skipScreenCheck      = 1;             % should be 0, but set to 1 if you get monitor warnings.
% ex.displayNumber        = 1;             % 1 for multiple monitors
% ex.simulateGripforce    = true;         % for testing without a gripforce
% ex.minITI               = 0; % minimal fixation cross time duration, only shown before decision trials
% ex.maxITI               = 0.5;   % maximum fixation cross time duration, only shown before decision trials
% ex.timeBeforeChoice     = 0;

if ex.useGripforce || ex.useSqueezy
    if ex.useGripforce
        if ex.simulateGripforce
            ex.MP_SAMPLE_RATE=500;
        else
            ex = initGripforce(ex);
        end
    else
       % NB: also configured in RunExperiment!!
       if ~isfield(ex, 'MP_SAMPLE_RATE'), ex.MP_SAMPLE_RATE=500; end
    end

    % this has units of SAMPLES. How many samples Need to be above the yellow line?
    % currently sampling at 500 Hz, so this is 2 seconds.
    % TRICKY! gripforce runs at 100Hz sampling rate, so set it using this
    % information (instead to a hardcoded 1000)
    ex.minimumAcceptableSqueezeTime = ex.MP_SAMPLE_RATE * 2;
end

%% DISPLAY
ex.bgColour      = [0 0 0];         % background
ex.fgColour      = [255 255 255];   % text colour, white
ex.fgColour2     = [  0 255   0];   % lime green to highlight Yes/No choice
ex.fgColour3     = [0 0 255];       % text colour, blue
ex.silver        = [176 196 172];   % used for rungs of ladder
ex.brown         = [160  82  45];   % brown tree trunk
ex.yellow        = [255 255   0];   % wider (current) rung
ex.size_text     = 24;              % size of text
ex.forceBarPos   = [300 150];       % location of force bars on Screen, in pixels; Original was [300 150]
ex.forceBarWidth = 50;              % width of force bars, in px
ex.forceColour   = [255 0 0];       % bar colour for force, red
ex.forceScale    = 200;             % scale of size of force bars (pixels); Original ws 200
ex.extraWidth    = 20;              % How much wider is the force-level indicator than the bar (px).

% last one must be fixationcross!
ex.imageFiles = {'tree.jpg','1apple.jpg','3apple.jpg', '6apple.jpg', '9apple.jpg', '12apple.jpg','fixationcross.png'};
