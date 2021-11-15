function result = AGT_CoreProtocol_RU_BSI(params,ex)
% result = AGT_CoreProtocol(params)
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
%  * Add latest "matlib" to the path -ppe requires RunExperiment.m,
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
% 2. Practice - 2 practices of each force level
% 3. Decisions - Self-paced (10s time out) choices of effort for reward,
%    no squeezing, 5 effort x 5 reward levels, 25 trials x 5 blocks.
% 4. Execute 25 trials selected randomly (but with all effort/reward combinations
%    once) from the choices in part 3. Forced squeezing required for trials
%    that were accepted.
%


%%% Notes
% 2018-06-29 : Adapted script from AGT_Simplified.
% Squeezy implementation: interfaces with MP150 and transducers, records  from channels 1.
% Authors: Sanjay Manohar, Annika Kienast, Matthew Apps, Valerie Bonnelle,
%          Michele Veldsman, Campbell Le Heron, Trevor Chong 2012-2018
%%

% these Need to be global.
global MVC totalReward

% Open output files for writing
% -------------------------------------------------------------------------
% .mat output file name to save result struct of current session and stage
[p, f, ~] = fileparts(ex.files.output_session_stage);
outfile_mat = fullfile(p,[f '.mat']);

% Open output files and write header lines
[~, ex] = writeResults(ex, [], [], true);

% Get subject's MVC from previous calibration, or set to arbitrary number
% before calibration
% -------------------------------------------------------------------------
if ~ex.calibNeeded
    % Get MVC from output mat file of the practice stage
    filename = strrep(outfile_mat,sprintf('stage-%s',ex.stage),'stage-practice');
    assert(exist(filename,'file')==2, 'Practice stage file that includes MVC is missing');
    
    % load the 'result' variable from the file.
    load(filename,'result');
    % an error will occur here if the selected file isn't a valid result file.
    MVC = result.MVC;         % grab MVC
    clear result % Clear result file to make way for new one.
else
    % Arbitrary MVC value that is overwritten after first calibration
    MVC = 3;
end

% RUN EXPERIMENT
% -------------------------------------------------------------------------
% Add function handle for start experiment function to ex struct
ex.exptStart = @exptStart;

% restore globals from previous experiment?
if ~exist('params','var') || isempty(params)
    params=struct();
else
    if isfield(params, 'MVC'), MVC = params.MVC; end
    if isfield(params, 'data') && isfield(params.data(end),'totalReward')
        totalReward = params.data(end).totalReward;
    end
end

% start experiment
result = RunExperiment( @doTrial, ex, params, @blockfn);

% Save the final result struct in mat file
save(outfile_mat, 'result');

% Close all open (output) files
fclose('all');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% STIMULI
function drawTree( scr, ex, location, stake,effort, height, doAppleText, otherText, doFlip )
% Generic merged function to draw tree, apples, rungs and force level
% location = -1 for left, 0 for centre, 1 for right
% stake    = 0 for no apples, or 1-5 for stake levels
% effort   = 0 for no force,  or 1-5 for force levels
%            corresponding to 0.16/0.32/0.48/0.64/0.80.
% provide effort number as type cell to specify any possible value
% height   = current squeeze, relative to MVC.
% if doAppleText, then write the stake & effort below the centre of screen
% if not, then write the string in otherText below the centre if screen.
% if doFlip, then the screen is flipped at the end of the function.

BP = ex.forceBarPos;        % bar position
x0 = scr.centre(1);
y0 = scr.centre(2);         % where to place the tree?
x0 = x0 + location * BP(1); % translate whole tree
W  = ex.forceBarWidth;      % bar width
S  = ex.forceScale;         % vertical distance between rungs
if iscell(effort)
    % ugly trick to treat effort as direct force value instead of an index into a
    % pre-defined array with default values.
    effort = effort{1};
    force = effort;
else
    force = ex.effortLevel(effort); % the proportion of MVC
end
if ex.fatiguingExercise
    % no maximum limit during fatiguing experiment
    height = max(0,height);
else
    height = max(0,min(1.5,height));
end

% Draw trunk brown
Screen('FillRect', scr.w, ex.brown,  [x0-W/2 y0-BP(2) x0+W/2 y0+BP(2)]); 

if ~ex.fatiguingExercise
    Screen('DrawTexture', scr.w, scr.imageTexture(stake+1),[], ...
        [ (x0-3*W) (y0 + BP(2) - ex.effortLevel(end)*S - numel(ex.effortLevel)*W) (x0 + 3*W) (y0 + BP(2) - ex.effortLevel(end)*S) ]);
end

% Draw apples according to stake level
if stake > 0
    apples = ex.rewardLevel(stake);
    if doAppleText   % text for how many apples
        formatstring = 'Appels: %d ';
        drawTextCentred(scr, sprintf(formatstring ,apples), ex.fgColour, scr.centre + [0 300]);
    end
end

% Draw rungs of ladder at each effortLevel
if ~ex.fatiguingExercise
    for ix = 1:length(ex.effortLevel) % width of lines is 5 (i.e. this is not a hardcoded level of something)
        Screen('Drawlines',scr.w, [ -W/2  W/2 ; BP(2)-ex.effortLevel(ix)*S BP(2)-ex.effortLevel(ix)*S ], 5, ex.silver, [x0 y0], 0);
    end
end

% Display the effort level as on-screen text.
%   (note previous versions only displayed effort visually as a forcebar)
if force > 0
    if doAppleText   % text for how many apples
        if strcmpi(ex.language,'NL'), formatstring = 'Inspanningsniveau: %d '; 
        else, formatstring = 'Effort level: %d '; end
        drawTextCentred(scr, sprintf(formatstring,floor(effort)), ex.fgColour, scr.centre + [0 350]);
    end
end

% Show current trial's force level as a wider rung at the relevant height
if ex.fatiguingExercise
    % NB: Fixed force level set to 0.7 (always plot the target yellow bar at this location)
    % draw wider line for fixed force=0.7 level
    Screen('Drawlines',scr.w,[ -W/2-ex.extraWidth W/2+ex.extraWidth ; BP(2)-0.7*S BP(2)-0.7*S ], 7, ex.yellow, [x0 y0], 0);
else
    % draw wider line for current force level
    Screen('Drawlines',scr.w,[ -W/2-ex.extraWidth W/2+ex.extraWidth ; BP(2)-force*S BP(2)-force*S ], 7, ex.yellow, [x0 y0], 0);
end

% Draw the momentary force height
if height < force
    clr = ex.forceColour;
elseif height >= force
    clr = ex.yellow;
end

if ex.fatiguingExercise
    % adapt plot height level to match 0.7 for actually requested force during fatiguing experiment
    height = height * (0.7/force);
    % but we don't want to exceed the trunk, so limit height
    height = min(1.0,height);
end
Screen('FillRect', scr.w, clr, [x0-W/2 y0+BP(2)-height*S x0+W/2 y0+BP(2)]);

if ~doAppleText && ~isempty(otherText)
    drawTextCentred( scr, otherText, ex.forceColour, scr.centre + [0 200]);
end
if doFlip
    Screen('Flip',scr.w);
end


function drawCalibAndFlip(scr, ex, colour, colourlevel, height, effortLevel)
height = max(0,min(1.5,height));
x0     = scr.centre(1);
y0     = scr.centre(2);
FC     = ex.forceColour;
% These are the coordinates for the target line:
% Y = 150 - effortLevel*S for AGT, where S is 200
Screen('Drawlines',scr.w,[ -25-50/8 +25+50/8 ; 150-effortLevel*200 150-effortLevel*200 ], 7, colourlevel, [x0 y0], 0);
% These are the coordinates for the Bar Outline
Screen('FrameRect', scr.w, colour, [x0-25 y0-150 x0+25 y0+150], 4);
% These are the coordinates for the Force Feedback Bar; Original height*S
Screen('FillRect', scr.w, FC, [x0-25 y0+150-height*200 x0+25 y0+150]);
Screen('Flip',scr.w);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Start of experiment
function exptStart(ex)
% Display start of experiment instruction slide:
%   either a welcome screen OR a session restore info screen
slideNrs = 1;
if ex.restoredSession
%     displayInstructions(ex, ex.dirs.instructions, slideNrs, 'restore')
else
%     displayInstructions(ex, ex.dirs.instructions, slideNrs, 'welcome')
end

%% Start of block:
% this also controls calibration and practice at the start of the experiment
function blockfn(scr, el, ex, tr)
global  totalReward
totalReward = 0; % start each block with zero total reward

% Display instructions
%   Kept displayInstructions method of calling img files, at least for now
% -------------------------------------------------------------------------
if tr.block == 0  % Practice block
    
    % Display general practice instructions on first trial
    if tr.practiceTrialIx == 1
        slideNrs = 1:5;
%         displayInstructions(ex, ex.dirs.instructions, slideNrs)
    end

    % Determine which part of practice stage we're in 
    CALIBRATING   = ex.numCalibration > 0 && tr.practiceTrialIx <= ex.numCalibration;
    FAMILIARISE   = ~CALIBRATING && tr.practiceTrialIx <= ex.numFamiliarise + ex.numCalibration;
    PRACTICE      = ~CALIBRATING && ~FAMILIARISE;
    
    % Display instructions according to which part
    if CALIBRATING
        displayInstructions(ex, ex.dirs.instructions, 6)
    elseif FAMILIARISE
        displayInstructions(ex, ex.dirs.instructions, 5)
    elseif PRACTICE
        displayInstructions(ex, ex.dirs.instructions, 7)
    end
    
elseif tr.block == 1 % start of experiment
    slideNrs = 1:5;
    displayInstructions(ex, ex.dirs.instructions, slideNrs)
    
elseif tr.block >= ex.choiceBlockNumber % the single trials to perform at the end
    if ~ex.fatiguingExercise
        slideNrs = 1;
        displayInstructions(ex, ex.dirs.instructions, slideNrs)
    else
        warning('No instructions implemented for fatiguingExercise experiment')
    end
    
else  % starting a new block of the main experiment
    
    if strcmp(ex.language,'NL'), txt='Einde van dit blok.'; else, txt='End of block.'; end
    drawTextCentred(scr, txt, ex.fgColour, scr.centre +[0, -300]);
    
    if ex.fatiguingExercise
        if strcmp(ex.language,'NL'), txt='Let op, we starten weer over 3 seconden'; else, txt='Get ready, we will start again in 3 seconds'; end
        drawTextCentred(scr, txt, ex.fgColour);
        Screen('Flip',scr.w);
        WaitSecs(3);
    else
        if strcmp(ex.language,'NL'), txt='Wanneer u er klaar voor bent, druk op een toets/knop om door te gaan'; else, txt='When you are ready, press the spacebar/button to continue'; end
        drawTextCentred(scr, txt, ex.fgColour);
        Screen('Flip',scr.w);
        waitForKeypress(ex);
        WaitSecs(0.5);
    end
end

% Wait for MRI scanner triggers and set T0 of this MRI run, if applicable
if tr.firstTrialMRIrun
    [ex, tr] = WaitForScanner(ex, tr);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% For each trial:

function tr=doTrial(scr, el, ex, tr)
% scr = screen information
% el  = eyelink information
% ex  = general experiment parameters
% tr  = trial-specific parameters
global  MVC totalReward YesResp

tr.sub_stage = ex.stage; % init
pa = combineStruct(ex, tr);   % get parameters for this trial

% Work out what kind of trial this is:
% calibration is done as the first 3 trial of the practice.
% the calibration and practice trials themselves are run with block==0
% for the final block, execution trials are picked from previous choices at random
CALIBRATING   = pa.block == 0 && ex.numCalibration>0 && pa.trialIndex < (ex.numCalibration+1) ;
FAMILIARISE   = pa.block == 0 && ~CALIBRATING && pa.trialIndex < pa.numFamiliarise +ex.numCalibration+1;
PRACTICE      = pa.block == 0 && ~CALIBRATING && ~FAMILIARISE;
PERFORM_TRIAL = tr.block >= ex.choiceBlockNumber || ex.fatiguingExercise;

tr=LogEvent(ex,el,tr,'starttrial');  % Log events

EXIT = false; % this gets set to true if escape is pressed.

%%%%%%%%%%%%%%%%%%%%%%%%

% init to global MVC
tr.MVC = MVC;
if CALIBRATING 
    % The experiment starts with CALIBRATION if calibNeeded.
    % if no calibration needed, just exit the trial.
    if ~ex.calibNeeded; tr.R=1; return; end
    
    % Log practice substage
    if strcmp(ex.stage,'practice'), tr.sub_stage = 'calibration'; end
    
    % trial 1: draw red bar - height = voltage divided by 3, no target line
    % trial 2: target line at 1.1  * MVC from first trial
    % trial 3: target line at 1.05 * MVC
    % the number is the proportion of MVC to use as the top of the bar.
    
    % Prepare final instruction and target force setting
    if strcmp(ex.language,'NL')
        calibrationInstructions = {
            'Knijp zo hard mogelijk!'  , 1.0,[0 0 0]
            'Probeer boven de gele lijn te komen!'    , 1.1,[255 255 0]
            'Probeer boven de gele lijn te komen!'    , 1.05,[255 255 0]
            };
    else
        calibrationInstructions = {
            'Squeeze as hard are you can!'  , 1.0,[0 0 0]
            'Get above the yellow line!'    , 1.1,[255 255 0]
            'Get above the yellow line!'    , 1.05,[255 255 0]
            };
    end
    % Use the trial index to select one of the above three
    % instructions+settings. If trial index > 3, keep using the third
    % option, i.e. every time use 1.05 * MVC as the target line
    if pa.trialIndex <= 3, ix = pa.trialIndex; else, ix = 3; end
    
    % Display instruction
    drawTextCentred(scr, calibrationInstructions{ix,1} , ex.fgColour);
    Screen('Flip',scr.w);
    WaitSecs(1);
    
    % Prepare gripforce feedback function
    %   parameters:(scr, ex, colour, colourlevel, height, effortLevel)
    fbfunc = @(f) drawCalibAndFlip(scr, ex, ex.fgColour, calibrationInstructions{ix,3}, f(pa.channel)/MVC, calibrationInstructions{ix,2} );
    
    % read data from force transducer:
    %   parameters: ( timeOfLastAcquisition, maxTimeToWait, stopRecordingThreshold, ISI, feedbackFunction )
    tr = LogEvent(ex,el,tr,'startresponse');
    [data] = waitForForceData(ex,tr.startSqueezyAcquisition, ex.calibrationDuration, inf, 6, fbfunc);
    tr.maximumForce = max(data(:,pa.channel));
    tr=LogEvent(ex,el,tr,'endresponse');
    
    % Process during blank screen
    Screen('Flip', scr.w);
    WaitSecs(0.5);           % Blank screen for 0.5 seconds
    tr.data1 = data(:,1);    % store all force data for channel 1
    tr.R=1;                  % report success
    
    % which is larger, the current trial's force, or the current MVC?
    %   update the MVC on calibration trials.
    MVC = max(tr.maximumForce, MVC);
    
    % Display 'end of calibration' instruction
    if pa.trialIndex == ex.numCalibration
        if strcmp(ex.language,'NL'), txt='Goed gedaan!'; else, txt='Well done!'; end
        drawTextCentred(scr, txt, ex.fgColour, scr.centre +[0 -200]);
        if ~ex.calibOnly
            if strcmp(ex.language,'NL'), txt='De onderzoeker zal nu het spel aan u gaan uitleggen'; else, txt='The researcher will now explain the game to you.'; end
            drawTextCentred(scr, txt, ex.fgColour, scr.centre +[0 -100]);
        else
            if strcmp(ex.language,'NL'), txt='Einde calibratie deel'; else, txt='End of MVC calibration part'; end
            drawTextCentred(scr, txt, ex.fgColour, scr.centre +[0 0]);
        end
        Screen('Flip', scr.w);
        EXIT = EXIT || waitForKeypress(ex);
        tr.MVC = MVC; % Save MVC to trial only on last calibration
    else
        % If not last calibration, the MVC is not yet calibrated well, so
        % do not save a value to the trial data
        tr.MVC = NaN;
    end

elseif FAMILIARISE
    % Log practice substage
    if strcmp(ex.stage,'practice'), tr.sub_stage = 'familiarization'; end
    
    % Get trial number of familiarization stage
    if ex.calibNeeded
        famTrIndex = tr.trialIndex - ex.numCalibration;
    else
        famTrIndex = tr.trialIndex;
    end
    
    % Get effort level
    if pa.practiceAscending 
        % Gives 1,1,1,..,2,2,2,..,3,3,3,.. etc
        numTrLvl = floor(ex.numFamiliarise/numel(ex.effortIndex));  % number of trials per level
        tr.effortIx = 1 + floor((famTrIndex-1)/numTrLvl);
    else
        % Gives 1,2,3,4,5,  1,2,3,4,5  effort levels.
        tr.effortIx = 1 + mod(famTrIndex,numel(ex.effortIndex));
    end
    tr.effort   = ex.effortLevel( tr.effortIx );
    
    % On first practice trial, display instructions
    if famTrIndex == 0     
        if strcmp(ex.language,'NL')
            txt='Knijp boven de lijn totdat de balk geel wordt, houd dit 2 seconden vol!'; 
        else
            txt='Squeeze above the line until the bar turns yellow. Hold for 2 seconds';
        end
        drawTextCentred(scr, txt, ex.fgColour, scr.centre +[0, -100])
        Screen('Flip',scr.w);
        EXIT = EXIT || waitForKeypress(ex); % wait for a key to be pressed before starting
        WaitSecs(1);
    end
    
    % Function to draw tree without apples and the correct effort rung,
    %   with "RESPOND NOW". Location 0 means centre of screen.
    if strcmp(ex.language,'NL'), txt = 'Knijp nu!'; else, txt = 'Squeeze now!'; end
    fbfunc = @(f) drawTree(scr, ex, 0, 0, tr.effortIx, f(pa.channel)/MVC, false, txt, true );
    
    % Get squeeze response data
    tr = LogEvent(ex,el,tr,'startresponse');
    [data,z,TLA]  = waitForForceData(ex,tr.startSqueezyAcquisition, ex.responseDuration, inf, ...
        (pa.responseDuration+pa.rewardDuration) , fbfunc);
    tr = LogEvent(ex,el,tr,'endresponse');
    activeHandData  = data(:,pa.channel);                       % units are samples
    tr.maximumForce = max(activeHandData);                      % Find maximum force
    tr.maximumTime  = find(activeHandData==tr.maximumForce,1);  % find all samples with max force
    tr.data         = data(:,pa.channel);                       % store all force data
    
    % Was the squeeze equal or greater than required for long enough?
    squeezeTime     = sum(activeHandData >= tr.effort*MVC);
    tr.success      = squeezeTime >= pa.minimumAcceptableSqueezeTime;
    
    % Give participant feedback on performance
    if tr.success
        if strcmp(ex.language,'NL'), txt='Goed gedaan!'; else, txt='Well done!'; end
        drawTextCentred(scr, txt, [0 255 0]);
    elseif squeezeTime > 0
        if strcmp(ex.language,'NL'), txt='Houd langer vol'; else, txt='Hold for longer'; end
        drawTextCentred(scr, txt, [255 0 0]);
    else
        if strcmp(ex.language,'NL'), txt='Knijp harder'; else, txt='Squeeze harder'; end
        drawTextCentred(scr, txt, [255 0 0]);
    end
    Screen('Flip',scr.w);
    tr = waitOrBreak(pa,tr,2);                  % wait 2 seconds
    
    % CHECK KEYPRESSES
    [~,~,keyCode] = KbCheck;                    % check for real key
    if keyCode(pa.exitkey), EXIT=true; end      % check for ESCAPE
    
    % Wait with blank screen during time delay after response
    Screen('Flip',scr.w);
    tr = waitOrBreak(pa,tr,ex.delayAfterResponse);
    
elseif ~CALIBRATING && ~FAMILIARISE && ~PERFORM_TRIAL
    
    % Choice trials (practice and main experiment)
    % ---------------------------------------------------------------------
    % Randomly assign left/right key to yes/no option
    tr.yesIsLeft = rand > 0.5;
    
    % Work out which keys are 'yes' and 'no', and set location on screen to
    % present yes/no text
    if tr.yesIsLeft
        tr.yeslocation  = -300;
        tr.yesKey       = pa.leftKey;
        tr.noKey        = pa.rightKey;
    else
        tr.yeslocation  = 300;
        tr.yesKey       = pa.rightKey;
        tr.noKey        = pa.leftKey;
    end
    if strcmp(ex.language,'NL')
        yestxt='Ja';
        notxt='Nee';
    else
        yestxt='Yes';
        notxt='No';
    end
    
%     % Change instructions according to randomisation
%     if tr.yesIsLeft
%         if strcmp(ex.language,'NL'), txt='Druk de linker pijl toets/knop voor JA'; else, txt='Press the left arrow key for YES'; end
%         YesText = txt;
%         if strcmp(ex.language,'NL'), txt='Druk de rechter pijl toets/knop voor NEE'; else, txt='Press the right arrow key for NO'; end
%         NoText  = txt;
%     else
%         if strcmp(ex.language,'NL'), txt='Gebruik de linker en rechter pijl toets/knop voor Ja of NEE'; else, txt='Use the left and right arrow keys to choose YES or NO'; end
%         YesText = txt;
%         if strcmp(ex.language,'NL'), txt='afhankelijk van de getoonde zijde'; else, txt='depending on the side they are presented'; end
%         NoText  = txt;
%     end
%     
    % If practice trials
    if tr.block==0
        % Get practice trial number
        if ex.calibNeeded
            pracTrIndex = tr.trialIndex - ex.numFamiliarise - ex.numCalibration;
        else
            pracTrIndex = tr.trialIndex - ex.numFamiliarise;
        end
        
%         % decide which of the main trials to show, for the 5 practice trials.
%         trialNumber = pa.practiceTrialIndex( pracTrIndex  );
    else % 'real' trials
        trialNumber = pa.allTrialIndex; % which of the list of trials to show
    end
    
    % draw fixation cross
    Screen('DrawTexture', ex.scr.w, scr.imageTexture(end),[]);
    Screen('Flip', ex.scr.w);
    WaitSecs(ex.minITI+rand(1)*(ex.maxITI-ex.minITI));    %RB: Currently random, change to e.g. poisson??
    
%     % get the effort/stake combination from the predetermined list
%     %    RB: THIS IS WHERE TRIAL ORDER FROM createTrials IS IGNORED, AND INSTEAD PRESPECIFIED ORDER IS USED
%     tr.effortIx = ex.order_effort( trialNumber );
%     tr.effort   = ex.effortLevel( tr.effortIx );  % proportion of MVC to display
%     tr.stakeIx  = ex.order_reward( trialNumber ); % n is stake index (1-5)
%     tr.stake    = ex.applesInStake( tr.stakeIx ); % look up stake value (in apples), based on stake 'level' (1-5)
%     


    % Log this trial's reward and effort levels based on the index
    tr.rewardLevel = ex.rewardLevel(tr.rewardIx);
    tr.effortLevel = ex.effortLevel(tr.effortIx);

    % Present tree with effort and stake in centre of screen, for choice
    drawTree(scr,ex,0,tr.rewardIx, tr.effortIx, 0, true, [], true);
    tr = LogEvent(ex,el,tr,'startStim');
    
    % Wait before presenting yes/no response options
    Tdelay = pa.timeBeforeChoice;
    if ischar(pa.timeBeforeChoice)
        if strcmpi(pa.timeBeforeChoice,'RandPoisson')
            % Get Poisson distributed random number
            lambda=10;
            Tdelay = 2+poissrnd(lambda)/(lambda+1);
        elseif strcmpi(pa.timeBeforeChoice,'RandNormal')
            Tdelay = 2 + rand*2;
        else
            error('Unsupported value (%s) for ''timeBeforeChoice'' setting',pa.timeBeforeChoice);
        end
    end
    WaitSecs(Tdelay);
    
    % Draw tree and add 'yes/no' response options, then flip to present
    drawTree(scr,ex,0,tr.stakeIx , tr.effortIx, 0, true, [], false);
    drawTextCentred(scr, yestxt, ex.fgColour, scr.centre + [ tr.yeslocation 200]);
    drawTextCentred(scr, notxt, ex.fgColour, scr.centre + [-tr.yeslocation 200]);
    
    Screen('Flip',scr.w);
    tr = LogEvent(ex,el,tr,'startChoice');
    
    % Wait for L/R choice
    % This sets the total trial length, which is the same for every trial.
    % To change it, alter ex.maxTimeToWait at the start of the script.
    deadline = GetSecs + ex.maxTimeToWait;
    
    % Wait for a valid response or until deadline
    % ---------------------------------------------------------------------
    if ex.useBitsiBB,  ex.BitsiBB.clearResponses(); end % empty input buffer
    while GetSecs < deadline
        if ex.useBitsiBB
            tr.key = [];
            while 1
                [resp, time_resp] = ex.BitsiBB.getResponse(0.1, true);
                if resp > 0
                    tr.key = resp;
                    break;
                end
                if GetSecs >= deadline, break; end
                
                % also check escape key
                [keyisdown,~,keyCode] = KbCheck;
                if keyisdown && keyCode(ex.exitkey)
                    tr.key = ex.exitkey;
                    break;
                end
            end
        else
            while ~KbCheck && GetSecs < deadline, WaitSecs(0.1); end
            [~,~,keyCode] = KbCheck;   % get key code
            tr.key = find(keyCode,1);
        end
        if isempty(tr.key), continue, end
        
        % If a response key was pressed, break out of the while loop
        if any(tr.yesKey==tr.key) || any(tr.noKey==tr.key) || tr.key==ex.exitkey
            break
        else % Draw feedback about which button to use
            drawTree(scr,ex,0,tr.stakeIx , tr.effortIx, 0, true, [], false);
            if strcmp(ex.language,'NL'), txt='Gebruik de linker en rechter pijl toets/knop'; else, txt='Use the Left and Right arrow keys'; end
            drawTextCentred(scr, txt, ex.forceColour, scr.centre + [0, -300])
            drawTextCentred(scr, yestxt, ex.fgColour, scr.centre +[ tr.yeslocation 200]);
            drawTextCentred(scr, notxt, ex.fgColour, scr.centre + [-tr.yeslocation 200]);
            Screen('Flip',scr.w);
        end
        tr.key = [];
    end
    
    % Process response
    % ---------------------------------------------------------------------
    doTree       = true;
    
    % No key pressed in allotted time?
    if isempty(tr.key)
        tr.Yestrial  = NaN;        % Too slow.
        if strcmp(ex.language,'NL'), message='Reageer sneller alstublieft'; else, message='Please respond faster'; end
        msgloc       = scr.centre + [0, -300];
        msgcolour    = ex.forceColour;
        
        % If this was not a practice trial, mark it to repeat at the end of
        % this block
        if tr.block~=0
            tr.R=ex.R_NEEDS_REPEATING_LATER;
        end
        
    else % Process response
        switch tr.key
            case num2cell(tr.yesKey)    % responded "yes"
                tr.Yestrial  = 1;
                message      = yestxt;
                msgloc       = scr.centre + [tr.yeslocation, 200];
                msgcolour    = ex.fgColour3;
            case num2cell(tr.noKey)     % responded "no"
                tr.Yestrial  = 0;
                message      = notxt;
                msgloc       = scr.centre + [-tr.yeslocation, 200];
                msgcolour    = ex.fgColour3;
            case ex.exitkey             % EXIT key was pressed
                tr.Yestrial  = NaN;
                EXIT         = true;
                message      = 'User exit via Esc key';
                doTree       = false;
                msgloc       = scr.centre + [0, -300];
                msgcolour    = ex.forceColour;
            otherwise
                tr.Yestrial  = 2;   % invalid response key pressed (can happen at timeout)
                if strcmp(ex.language,'NL'), txt='Gebruik de linker en rechter pijl toets/knop'; else, txt='Use the Left and Right arrow keys'; end
                message      = txt;
                msgloc       = scr.centre + [0, -300];
                msgcolour    = ex.forceColour;
                if tr.block~=0 % If not a practice trial, repeat it
                    tr.R=ex.R_NEEDS_REPEATING_LATER;
                end
        end
    end
    
    % Draw feedback
    drawTextCentred(scr, message, msgcolour, msgloc)
    if doTree
        drawTree(scr,ex,0,tr.stakeIx , tr.effortIx, 0, true, [], true);
    end
    tr = LogEvent(ex,el,tr,'endChoice');
    
    % Wait until the total trial length is up, so all trials are the same length (ex.maxTimeToWait)
    WaitSecs(0.5);      %% RB: Always wait .5?? Should be while GetSecs() < deadline ?
    Screen('Flip', scr.w);
    tr=LogEvent(ex,el,tr,'endTrial');
    
    % Store whether the decision was accepted on each trial, for the purposes
    % of the final perfomance block.
    if ~PRACTICE
        YesResp( tr.allTrialIndex ) = tr.Yestrial;
    end
    
    %%%%%%%%%%%%% end of trial %%%%%%%%%%%%%%%%
    
elseif PERFORM_TRIAL
    if strcmp(ex.stage,'ChoiceTask')
        tr.sub_stage = 'Perform';
    end
    
    %%%%%%%%%%%%%%%%%
    % there are 10 performance trials, at the end of the experiment. They
    % constitute the final block.  (Block 6 in this case).
    % They are drawn with predetermined indices from the choices.
    % select the corresponding choice trial
    if ~ex.fatiguingExercise
        location = 0; % tree in the middle
        performTrial = ex.last_trial(tr.trialIndex);
        tr.effortIx = ex.order_effort( performTrial );
        tr.effort  = ex.effortLevel( tr.effortIx );
        tr.stakeIx = ex.order_reward(  performTrial ); % n is stake index (1-5)
        tr.stake   = ex.applesInStake(tr.stakeIx); % look up stake value (in apples), based on stake 'level' (1-5)
    else
        location = tr.location; % tree middle (0) or left(-1)/right(1) for two hands case
        if location > 0, pa.channel = 2; else pa.channel = 1; end % which hand/channel, left (location/channel) = (-1/1) or right (1,2)
        performTrial = NaN; % only the tree, no apples, but with effort level
        tr.effortIx = tr.effort; % should be a number delivered as type cell
        tr.effort = tr.effort{1}; % convert from cell to number
        tr.stakeIx = 0;
        tr.stake = 1;
    end
    % draw tree with effort and stake in centre of screen, indicating
    % previous choice.
    drawTree(scr,ex,location,tr.stakeIx , tr.effortIx, 0, false, [], true);
    tr = LogEvent(ex,el,tr,'startStim');
    WaitSecs(0.5);
    
    tr = LogEvent(ex,el,tr,'startChoice');
    if ~ex.fatiguingExercise
        Yestrial = YesResp(performTrial); %find out if trial 18 was a Yes response
    else
        Yestrial = 1;
    end
    
    if Yestrial == 1   %% Accepted Performance trials (MV)
        
        tr = LogEvent(ex,el,tr,'startresponse');
        % Record force data over the response duration.
        
        fbfunc = @(f) drawTree(scr,ex,location ,tr.stakeIx,tr.effortIx,  f(pa.channel)/MVC, false, 'Knijp nu!', true);
        
        [data,k,TLA]    = waitForForceData(ex, tr.startSqueezyAcquisition, ex.responseDuration, inf, 4 , fbfunc);
        tr.data         = data(:,pa.channel); % store all force data from the given channel
        tr.maximumForce = max(tr.data);
        tr.maximumTime  = find(tr.data == tr.maximumForce,1); % units are SAMPLES
        tr.MVC          = MVC;
        % Check for key press
        [keyisdown,secs,keyCode] = KbCheck;              % check for real key
        if keyCode(pa.exitkey), EXIT = true; end   % check for ESCAPE
        
        Screen('Flip',scr.w);
        tr=LogEvent(ex,el,tr,'endresponse');
        WaitSecs(ex.delayAfterResponse);
        
        %%%% Display Reward
        % Stay above for 2s
        tr.timeAboveTarget = sum(tr.data >= tr.effort*MVC );
        % Recorded trial length is 5s squeeze, and need to stay above for 2s
        if tr.timeAboveTarget >= pa.minimumAcceptableSqueezeTime
            tr.reward = tr.stake;     % success!
        else                        % failure!
            tr.reward = 0;
        end
        totalReward = totalReward + tr.reward;   % add winnings to total apples in basket
        if ~ex.fatiguingExercise
            if strcmp(ex.language,'NL'), txt='Verzamelde appels'; else, txt='Apples gathered'; end
            drawTextCentred( scr, sprintf( '%s: %d',txt, tr.reward), pa.fgColour, scr.centre + [0,-100] )
            Screen('Flip',scr.w);
        end
        tr=LogEvent(ex,el,tr,'startreward');
        WaitSecs(pa.rewardDuration);
        %%%% End of trial
        
        
    else %% Declined performance trials
        
        drawTree(scr,ex,0,tr.stakeIx, tr.effortIx, 0, false, [], true);
        %tr = LogEvent(ex,el,tr,'startStim'); % Ph: overwrite earlier value, seems wrong to me???
        tr = LogEvent(ex,el,tr,'startdeclined');
        WaitSecs(0.5);
        drawTextCentred(scr, 'offer afgewezen', ex.fgColour, scr.centre +[0 -300]);
        drawTree(scr,ex,0,tr.stakeIx , tr.effortIx, 0, false, [], true);
        WaitSecs(pa.delayAfterResponse);
        
        tr=LogEvent(ex,el,tr,'startreward');
        WaitSecs(pa.rewardDuration);
        tr.reward = NaN;
    end
    
    % is this the end of the final performance trial?
    if pa.trialIndex >= length(ex.last_trial) && ~ex.fatiguingExercise %== 10
        if strcmp(ex.language,'NL'), txt='Einde van de taak, dank voor uw deelname!'; else, txt='End of Task. Thank you for taking part!'; end
        drawTextCentred(scr, txt, ex.fgColour, scr.centre +[0 0]);
        if strcmp(ex.language,'NL'), txt='Totaal verzamelde appels'; else, txt='Total Apples gathered'; end
        drawTextCentred( scr, sprintf( '%s: %d',txt, totalReward), pa.fgColour, scr.centre + [0,-100] )
        if strcmp(ex.language,'NL'), txt='Druk een toets/knop om door te gaan'; else, txt='Press space bar to continue'; end
        drawTextCentred( scr, sprintf(txt), pa.fgColour, scr.centre + [0,-200] )
        Screen('Flip', scr.w);
        waitForKeypress(ex); % wait for a key to be pressed (defined at end of this script)
    end
    
    tr.totalReward = totalReward; % store in results
    
end

if ~EXIT
    if tr.R~=ex.R_NEEDS_REPEATING_LATER
        tr.R = 1; % trial OK
    end
else
    tr.R = pa.R_ESCAPE; % tells RunExperiment to exit.
end


return %%%%%%%%%%%%% end of experiment %%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function tr = waitOrBreak(ex, tr, waitsecs)
% wait for time "waitsecs"
% or exit if esape is pressed.
t    = GetSecs;
EXIT = 0;
prevkey = false;
while GetSecs<t+waitsecs && ~EXIT
    WaitSecs(0.010); % check keyboard every 10 ms
    [~,~,k]=KbCheck;
    if ~prevkey && k(ex.exitkey)  % if escape goes down,
        EXIT = 1;
    end
    prevkey = any(k); % store last keyboard state
end
if EXIT, tr.R = ex.R_ESCAPE; end
return

function EXIT = waitForKeypress(ex)
% wait for a key to be pressed and released.
spacepressed  = false;
escapepressed = false;
exitkey  = KbName('ESCAPE');
spacekey = KbName('SPACE');

while ~spacepressed && ~escapepressed
    [~,~,k]=KbCheck;  % get set of keys pressed
    spacepressed  = k(spacekey);
    escapepressed = k(exitkey); % is space or escape presesed?
    % check bitsi buttonbox (fmri only)
    if ex.useBitsiBB
        ex.BitsiBB.clearResponses(); % empty input buffer
        [resp, time_resp] = ex.BitsiBB.getResponse(0.1, true); % don't wait longer than 30 s.
        if resp > 0, spacepressed = true; end
    else
        WaitSecs(0.1);
    end
end % wait for a key to be pressed before starting
if escapepressed, EXIT = true; return; else, EXIT=false; end

while KbCheck, WaitSecs(0.1); end  % (and wait for key release)
return

%if exist(subjname)
%error('Subject name already in use,please rename current or saved file')
%end