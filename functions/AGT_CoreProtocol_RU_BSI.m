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

% For the perform stage, load subject's choices from the choice stage
% -------------------------------------------------------------------------
if strcmp(ex.stage,'perform')
    % Get choices output mat file and assert it exists
    ex.choices_file = strrep(outfile_mat,'stage-perform','stage-choice');
    assert(exist(ex.choices_file,'file') == 2, 'The choices output file does not exist: %s',ex.choices_file);
    
    % Assert that the number of perform trials is not greater than the
    % number of decisions made in the choice stage
    choices  = load(ex.choices_file,'result');
    nChoices = numel(choices.result.data);
    assert(ex.blocks * ex.blockLen <= nChoices || ex.DEBUG, ...
        'There are more trials to perform effort for (%d) than the number of decisions made in the choice stage (%d)', ex.blocks * ex.blockLen, nChoices);
    clear choices;  % Clear previous results from memory hear
end

% RUN EXPERIMENT
% -------------------------------------------------------------------------
% Add function handle for experiment start/end function to ex struct
ex.exptStartEnd = @exptStartEnd;

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
result = RunExperiment(@doTrial, ex, params, @blockfn);

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
function ex = exptStartEnd(ex, timepoint)
% Display start/end of experiment instruction slides
% INPUTS
% ex        : struct with experiment parameters
% timepoint : char; 'start' OR 'end'
%
assert(isstruct(ex), 'Input ex should be of class struct')
assert(ischar(timepoint), 'Input timepoint should be a character string')

switch lower(timepoint)
    case 'start'
        % Log the system time at the start of the experiment
        if ~isfield(ex,'exptStartT0'), ex.exptStartT0 = {GetSecs()};
        else, ex.exptStartT0 = [ex.exptStartT0 {GetSecs()}]; end
        
        % Show either a welcome screen OR a session restore info screen
        slideNrs = 1;
        if ex.restoredSession
            %             displayInstructions(ex, ex.dirs.instructions, slideNrs, 'restore')
        else
            %             displayInstructions(ex, ex.dirs.instructions, slideNrs, 'welcome')
        end
    case 'end'
        slideNrs = 1;
        %         displayInstructions(ex, ex.dirs.instructions, slideNrs, 'end')
end

%% Start of block:
% this also controls calibration and practice at the start of the experiment
function [ex, tr] = blockfn(scr, el, ex, tr)
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
    
    % Display instructions according to which stage we're in
    switch tr.sub_stage
        case 'calibration'
            displayInstructions(ex, ex.dirs.instructions, 6)
        case 'familiarize'
            displayInstructions(ex, ex.dirs.instructions, 5)
        case 'practice'
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
%         waitForKeypress(ex);
        WaitSecs(0.5);
    end
end

% Wait for MRI scanner triggers and set T0 of this MRI run, if applicable
if tr.firstTrialMRIrun
    [ex, tr] = WaitForScanner(ex, tr);
end

%% For each trial:
function tr = doTrial(scr, el, ex, tr)
% scr = screen information
% el  = eyelink information
% ex  = general experiment parameters
% tr  = trial-specific parameters
global  MVC totalReward YesResp

% Get parameters for this trial
pa = combineStruct(ex, tr);

% Work out what kind of trial this is:
if ismember(tr.sub_stage,{'calibration','familiarize','choice','perform'})
    stage = tr.sub_stage;
elseif strcmp(tr.sub_stage,'practice') && ismember(ex.stage,{'practice','choice'})
    stage = 'choice';
elseif strcmp(tr.sub_stage,'practice') && strcmp(ex.stage,'perform')
    stage = 'perform';
end

% Prepare EXIT value; gets set to true if escape is pressed.
EXIT = false;

% Set trial MVC to global MVC value
tr.MVC = MVC;

% =========================================================================
switch stage
    case 'calibration'
        % The experiment starts with CALIBRATION if calibNeeded.
        % if no calibration needed, just exit the trial.
        if ~ex.calibNeeded; tr.R=1; return; end
        
        % trial 1: draw red bar - height = voltage divided by 3, no target
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
        tr = LogEvent(ex,el,tr,'trialOnset');
        WaitSecs(1);
        
        % Prepare gripforce feedback function
        %   parameters:(scr, ex, colour, colourlevel, height, effortLevel)
        fbfunc = @(f) drawCalibAndFlip(scr, ex, ex.fgColour, calibrationInstructions{ix,3}, f(pa.channel)/MVC, calibrationInstructions{ix,2} );
        tr = LogEvent(ex,el,tr,'stimOnset');
        
        % read data from force transducer:
        %   parameters: ( timeOfLastAcquisition, maxTimeToWait, stopRecordingThreshold, ISI, feedbackFunction )
        tr = LogEvent(ex,el,tr,'squeezeStart');
        [data] = waitForForceData(ex,tr.startSqueezyAcquisition, ex.calibrationDuration, inf, 6, fbfunc);
        tr = LogEvent(ex,el,tr,'squeezeEnd');
        tr.maximumForce = max(data(:,pa.channel));
        
        % Process during blank screen
        Screen('Flip', scr.w);
        WaitSecs(0.5);           % Blank screen for 0.5 seconds
        tr.data1 = data(:,1);    % store all force data for channel 1
        tr.R = 1;                % report success
        
        % Which is larger, the current trial's force, or the current MVC?
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
            % If not last calibration, the MVC is not yet calibrated well, 
            % so do not save a value to the trial data
            tr.MVC = NaN;
        end
        tr = LogEvent(ex,el,tr,'trialEnd');
        
    case 'familiarize'
        
        % Get trial number of familiarization stage
        if ex.calibNeeded
            famTrIndex = tr.trialIndex - ex.numCalibration;
        else
            famTrIndex = tr.trialIndex;
        end
        
        % Get effort level
        if pa.practiceAscending
            % Gives 1,1,1,..,2,2,2,..,3,3,3,.. etc
            numTrLvl = floor(ex.numFamiliarise/numel(ex.trialVariables.effortIx));  % number of trials per level
            tr.effortIx = 1 + floor((famTrIndex-1)/numTrLvl);
        else
            % Gives 1,2,3,4,5,  1,2,3,4,5  effort levels.
            tr.effortIx = 1 + mod(famTrIndex - 1, numel(ex.trialVariables.effortIx));
        end
        % Log this trial's reward and effort levels based on the index
        tr.rewardLevel = ex.rewardLevel(tr.rewardIx);
        tr.effortLevel = ex.effortLevel(tr.effortIx);
        tr.effort = tr.effortLevel; % Seems needed because of leftover code somewhere
        
        % Log trial onset time
        tr = LogEvent(ex,el,tr,'trialOnset');
        
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
        tr = LogEvent(ex,el,tr,'stimOnset');
        
        % Get squeeze response data
        tr = LogEvent(ex,el,tr,'squeezeStart');
        [data,~,~] = waitForForceData(ex,tr.startSqueezyAcquisition, ex.responseDuration, inf, ...
            (pa.responseDuration + pa.rewardDuration), fbfunc);
        tr = LogEvent(ex,el,tr,'squeezeEnd');
        
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
        tr = LogEvent(ex,el,tr,'feedbackOnset');
        tr = waitOrBreak(pa,tr,2);                  % wait 2 seconds
        tr = LogEvent(ex,el,tr,'trialEnd');
        
        % CHECK KEYPRESSES
        [~,~,keyCode] = KbCheck;                    % check for real key
        if keyCode(pa.exitkey), EXIT=true; end      % check for ESCAPE
        
        % Wait with blank screen during time delay after response
        Screen('Flip',scr.w);
        tr = waitOrBreak(pa,tr,ex.delayAfterResponse);
        
    case 'choice'
        
        % Choice trials (practice and main experiment)
        % -----------------------------------------------------------------
        % Randomly assign left/right key to yes/no option
        tr.yesIsLeft = rand > 0.5;
        
        % Work out which keys are 'yes' and 'no', and set location on 
        % screen to present yes/no text
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
        
        % Log this trial's reward and effort levels based on the index
        tr.rewardLevel = ex.rewardLevel(tr.rewardIx);
        tr.effortLevel = ex.effortLevel(tr.effortIx);
        
        % Draw fixation cross, and log trial onset time
        Screen('DrawTexture', ex.scr.w, scr.imageTexture(end),[]);
        Screen('Flip', ex.scr.w);
        tr = LogEvent(ex,el,tr,'trialOnset');
        
        % Inter Trial Interval (ITI) at beginning of each trial
        %   RB: Currently random, change to e.g. poisson??
        WaitSecs(ex.minITI + rand*(ex.maxITI-ex.minITI));
        
        % Present tree with effort and stake in centre of screen
        drawTree(scr,ex,0,tr.rewardIx, tr.effortIx, 0, true, [], true);
        tr = LogEvent(ex,el,tr,'stimOnset');
        
        % Wait before presenting yes/no response options
        Tdelay = pa.timeBeforeChoice;
        if ischar(pa.timeBeforeChoice)
            if strcmpi(pa.timeBeforeChoice,'RandPoisson')
                % Get Poisson distributed random number
                lambda = 10;
                Tdelay = ex.minTimeBeforeChoice + poissrnd(lambda)/(lambda+1);
            elseif strcmpi(pa.timeBeforeChoice,'RandNormal')
                Tdelay = (ex.minTimeBeforeChoice + rand*(ex.maxTimeBeforeChoice-ex.minTimeBeforeChoice));
%                 Tdelay = 2 + rand*2;
            else
                error('Unsupported value (%s) for ''timeBeforeChoice'' setting',pa.timeBeforeChoice);
            end
        end
        WaitSecs(Tdelay);
        
        % Draw tree and add 'yes/no' response options, then flip to present
        drawTree(scr,ex,0, tr.rewardIx , tr.effortIx, 0, true, [], false);
        drawTextCentred(scr, yestxt, ex.fgColour, scr.centre + [ tr.yeslocation 200]);
        drawTextCentred(scr, notxt, ex.fgColour, scr.centre + [-tr.yeslocation 200]);
        Screen('Flip',scr.w);
        tr = LogEvent(ex,el,tr,'choiceOnset');
        
        % Wait for a valid response or until deadline
        % -----------------------------------------------------------------
        % This sets the total trial length, which is the same for every 
        % trial(?) To change it, alter ex.maxTimeToWait
        deadline = GetSecs + ex.maxTimeToWait;
        if ex.useBitsiBB,  ex.BitsiBB.clearResponses(); end % empty input buffer
        while GetSecs < deadline
            if ex.useBitsiBB
                tr.key = [];
                while 1
                    [resp, respTime] = ex.BitsiBB.getResponse(0.1, true);
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
                [~,respTime,keyCode] = KbCheck;   % get key code
                tr.key = find(keyCode,1);
            end
            if isempty(tr.key), continue, end
            
            % If a response key was pressed, break out of the while loop
            if any(tr.yesKey==tr.key) || any(tr.noKey==tr.key) || tr.key==ex.exitkey
                break
            else % Draw feedback about which button to use
                drawTree(scr,ex,0,tr.rewardIx , tr.effortIx, 0, true, [], false);
                if strcmp(ex.language,'NL'), txt='Gebruik de linker en rechter pijl toets/knop'; else, txt='Use the Left and Right arrow keys'; end
                drawTextCentred(scr, txt, ex.forceColour, scr.centre + [0, -300])
                drawTextCentred(scr, yestxt, ex.fgColour, scr.centre + [tr.yeslocation 200]);
                drawTextCentred(scr, notxt, ex.fgColour, scr.centre + [-tr.yeslocation 200]);
                Screen('Flip',scr.w);
            end
            tr.key = [];
        end
        
        % Process response
        % -----------------------------------------------------------------
        doTree = true;
        % No key pressed in allotted time?
        if isempty(tr.key)
            tr.Yestrial  = NaN;        % Too slow.
            if strcmp(ex.language,'NL'), message='Reageer sneller alstublieft'; else, message='Please respond faster'; end
            msgloc       = scr.centre + [0, -300];
            msgcolour    = ex.forceColour;
            
            % If this was not a practice trial, mark it to repeat at the 
            % end of this block
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
        
        % Log response onset and calculate response time
        %   If no response, set to NaN
        if isempty(tr.key)
            tr = LogEvent(ex,el,tr,'responseOnset', nan);
        else
            tr = LogEvent(ex,el,tr,'responseOnset', respTime);
        end
        tr.timings.responseTime = tr.timings.responseOnset - tr.timings.choiceOnset;
        
        % Draw feedback
        drawTextCentred(scr, message, msgcolour, msgloc)
        if doTree
            drawTree(scr,ex,0, tr.rewardIx, tr.effortIx, 0, true, [], true);
        end
        tr = LogEvent(ex,el,tr,'feedbackOnset');
        
        % Wait until the total trial length is up, so all trials are the same length (ex.maxTimeToWait)
        WaitSecs(0.5);      %% RB: Always wait .5?? Should be while GetSecs() < deadline if the goal is indeed to get equal trial durations?
        Screen('Flip', scr.w);
        tr = LogEvent(ex,el,tr,'trialEnd');
        
        % Copy Yestrial field to accept fiels in tr struct for consistent
        % naming in output file
        tr.accept = tr.Yestrial;
        
    case 'perform'
        
        % Set tree location and log/set reward and effort levels
        if ~ex.fatiguingExercise
            location = 0; % tree in the middle
            
            % Log this trial's reward and effort levels based on the index
            tr.rewardLevel = ex.rewardLevel(tr.rewardIx);
            tr.effortLevel = ex.effortLevel(tr.effortIx);
        else
            location = tr.location; % tree middle (0) or left(-1)/right(1) for two hands case
            if location > 0, pa.channel = 2; else pa.channel = 1; end % which hand/channel, left (location/channel) = (-1/1) or right (1,2)
            performTrial = NaN; % only the tree, no apples, but with effort level
            tr.effortIx = tr.effort; % should be a number delivered as type cell
            tr.effort = tr.effort{1}; % convert from cell to number
            tr.stakeIx = 0;
            tr.stake = 1;
        end
        
        % Draw tree with reward/effort indication of previous choice.
        drawTree(scr,ex, location, tr.rewardIx ,tr.effortIx, 0, false, [], true);
        tr = LogEvent(ex,el,tr,'stimOnset');
        WaitSecs(0.5);
        
        % Find out if trial was a Yes response
        if ~ex.fatiguingExercise
            Yestrial = tr.Yestrial;
        else
            Yestrial = 1;
        end
        
        % Run trial
        if Yestrial == 1   % Accepted Performance trials
            tr.didAccept = 1;
            
            % Function to draw tree without apples and the correct effort 
            % rung, with "RESPOND NOW" text
            if strcmp(ex.language,'NL'), txt = 'Knijp nu!'; else, txt = 'Squeeze now!'; end
            fbfunc = @(f) drawTree(scr,ex,location ,tr.rewardIx, tr.effortIx, f(pa.channel)/MVC, false, txt, true);
            
            % Get squeeze response data
            tr = LogEvent(ex,el,tr,'squeezeStart');
            [data,~,~] = waitForForceData(ex, tr.startSqueezyAcquisition, ex.responseDuration, inf, 4 , fbfunc);
            tr = LogEvent(ex,el,tr,'squeezeEnd');
            
            tr.data         = data(:,pa.channel); % store all force data from the given channel
            tr.maximumForce = max(tr.data);
            tr.maximumTime  = find(tr.data == tr.maximumForce,1); % units are SAMPLES
            tr.MVC          = MVC;
            
            % Check for key press
            [~,~,keyCode] = KbCheck;        % check for real key
            if keyCode(pa.exitkey), EXIT = true; end   % check for ESCAPE
            
            % Wait with blank screen
            Screen('Flip',scr.w);
            WaitSecs(ex.delayAfterResponse);
            
            % Determine whether successful
            %   Trial successful if force stayed above effort level for
            %   pa.minimumAcceptableSqueezeTime
            %   Add winnings to total apples in basket
            tr.timeAboveTarget = sum(tr.data >= tr.effortLevel*MVC );
            if tr.timeAboveTarget >= pa.minimumAcceptableSqueezeTime
                tr.success = true;   % success!
            else
                tr.success = false;  % failure!
            end
            totalReward = totalReward + tr.success * tr.rewardLevel;
            
            % Display reward feedback
            if ~ex.fatiguingExercise
                if strcmp(ex.language,'NL'), txt='Verzamelde appels'; else, txt='Apples gathered'; end
                drawTextCentred(scr, sprintf('%s: %d', txt,tr.rewardLevel), pa.fgColour, scr.centre + [0,-100])
                Screen('Flip',scr.w);
                
                % Log reward feedback onset time and wait reward duration
                tr = LogEvent(ex,el,tr,'feedbackOnset');
                WaitSecs(pa.rewardDuration);
            else
                % If no feedback displayed, set onset to NaN
                tr = LogEvent(ex,el,tr,'feedbackOnset', nan);
            end
            
        else    % Declined performance trials
            tr.didAccept = 0;
            
            % No reward on this trial
            tr.success = NaN;
            
            % Display "offer declined" text
            if strcmp(ex.language,'NL'), txt='Aanbod afgewezen'; else, txt='Offer declined'; end
            drawTextCentred(scr, txt, ex.fgColour, scr.centre + [0 -300]);
            drawTree(scr,ex,0,tr.rewardIx , tr.effortIx, 0, false, [], true);
            
            % Log decline feedback onset time
            tr = LogEvent(ex,el,tr,'feedbackOnset');
            
            % Wait equally long as after performed trials? Or only as long 
            % as rewardDuration?
            %         WaitSecs(pa.delayAfterResponse);
            WaitSecs(pa.rewardDuration);
        end
        % Log end of trial
        tr = LogEvent(ex,el,tr,'trialEnd');
        
        % Store total reward in tr struct
        tr.totalReward = totalReward;
        
        % Present total reward feedback after the last perform trial
        if pa.trialIndex >= ex.blocks*ex.blockLen && ~ex.fatiguingExercise
            if strcmp(ex.language,'NL'), txt='Einde van dit taakgedeelte'; else, txt='End of this task stage'; end
            drawTextCentred(scr, txt, ex.fgColour, scr.centre +[0 0]);
            if strcmp(ex.language,'NL'), txt='Totaal verzamelde appels'; else, txt='Total apples gathered'; end
            drawTextCentred( scr, sprintf( '%s: %d',txt, totalReward), pa.fgColour, scr.centre + [0,-100] )
            if strcmp(ex.language,'NL'), txt='Druk op een knop om door te gaan'; else, txt='Press a button to continue'; end
            drawTextCentred( scr, sprintf(txt), pa.fgColour, scr.centre + [0,-200] )
            Screen('Flip', scr.w);
            tr = LogEvent(ex,el,tr,'totalRewardOnset');  % Log onset of total reward feedback
            waitForKeypress(ex); % wait for a key to be pressed (defined at end of this script)
        end
end

if ~EXIT
    if tr.R~=ex.R_NEEDS_REPEATING_LATER
        tr.R = 1; % trial OK
    end
else
    tr.R = pa.R_ESCAPE; % tells RunExperiment to exit.
end
return


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