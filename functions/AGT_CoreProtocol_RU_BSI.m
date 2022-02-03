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

% These need to be global.
global MVC totalReward

% Open output files for writing
% -------------------------------------------------------------------------
% .mat output file to save result struct of current session and stage
outfile_mat = fullfile(ex.dirs.output,sprintf('subject-%.3d_ses-%d_task-EBDM_stage-%s.mat', ex.subject,ex.session,ex.stage));

% Open output files and write header lines if necessary
[~, ex] = writeResults(ex, [], [], true);

% If this is not a restored session, prepare required info before starting
% -------------------------------------------------------------------------
if ~exist('params','var') || isempty(params)
    % params should be empty struct
    params = struct([]);
    
    % Get subject's MVC from previous calibration, or set to arbitrary 
    % number before calibration
    % ---------------------------------------------------------------------
    if ~ex.calibNeeded
        % Get MVC from output mat file of the practice stage
        filename = strrep(outfile_mat,sprintf('stage-%s',ex.stage),'stage-practice');
        assert(exist(filename,'file')==2, 'Practice stage file that includes MVC is missing');

        % Load the 'result' variable from the file.
        tmp = load(filename,'result');
        % Grab MVC
        MVC = tmp.result.MVC;
        % Clear tmp variable
        clear tmp
    else
        % Arbitrary MVC value that is overwritten after first calibration
        MVC = 3;
    end

    % For the perform stage, load subject's choices from the choice stage
    % to check that there are enough choices to start the perform stage
    % ---------------------------------------------------------------------
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
    
    % Add function handle for experiment start/end function to ex struct
    % ---------------------------------------------------------------------
    ex.exptStartEnd = @exptStartEnd;
    
else    % Restored session
    % Restore globals from previous experiment
    if isfield(params, 'MVC'), MVC = params.MVC; end
    if isfield(params, 'data') && isfield(params.data(end),'totalReward')
        totalReward = params.data(end).totalReward;
    end
end

% RUN EXPERIMENT
% -------------------------------------------------------------------------
% start experiment
result = RunExperiment(@doTrial, ex, params, @blockfn);

% Save the final result struct in mat file
save(outfile_mat, 'result');

% Close all open (output) files
fclose('all');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% STIMULI
function drawTree(scr, ex, location, rewardIx, effortIx, height, doAppleText, otherText, doFlip)
% 
% Generic merged function to draw tree, apples, rungs and force level
% 
% INPUTS
% location = -1 for left, 0 for centre, 1 for right
% rewardIx = 0 for no reward
% effortIx = 0 for no force
%       provide effortIx as type cell to specify any possible value
% height   = current squeeze, relative to MVC.
% 
% if doAppleText, write reward & effort level below the centre of screen
%   if not, then write the string in otherText below the centre if screen.
% if doFlip, then the screen is flipped at the end of the function.
% -------------------------------------------------------------------------
% 

% Prepare location and reward/effort variables
% -------------------------------------------------------------------------
% Stimuli positions on screen
BP  = ex.forceBarPos;        % bar position
x0  = scr.centre(1);
y0  = scr.centre(2);         % where to place the tree?
x0  = x0 + location * BP(1); % translate whole tree
W   = ex.forceBarWidth;      % bar width
S   = ex.forceScale;         % vertical distance between rungs
lW  = 5;                     % line width for rungs of effort level ladder
tlW = 7;                     % width of target line for current effort lvl

% Get reward level from index
rewardLevel = ex.rewardLevel(rewardIx);

% Get effort level from index in variable force
if iscell(effortIx)
    % ugly trick to treat effort as direct force value instead of an index 
    % of a pre-defined array with default values.
    effortIx = effortIx{1};
    force = effortIx;
else
    force = ex.effortLevel(effortIx); % the proportion of MVC
end

% Set force bar level at 0 or based on current squeeze force
if ex.fatiguingExercise
    % no maximum limit during fatiguing experiment
    height = max(0,height);
else
    height = max(0,min(1.5,height));
end

% Draw stimuli
% -------------------------------------------------------------------------
% Draw trunk brown
Screen('FillRect', scr.w, ex.brown,  [x0-W/2 y0-BP(2) x0+W/2 y0+BP(2)]);

% Draw rungs of ladder at each effortLevel
if ~ex.fatiguingExercise
    for ix = 1:length(ex.effortLevel) % width of lines is 5 (i.e. this is not a hardcoded level of something)
        Screen('Drawlines',scr.w, [ -W/2  W/2 ; BP(2)-ex.effortLevel(ix)*S BP(2)-ex.effortLevel(ix)*S ], lW, ex.silver, [x0 y0], 0);
    end
end

% Show current trial's force level as a wider rung at the relevant height
if ex.fatiguingExercise
    % NB: Fixed force level set to 0.7 (always plot the target yellow bar 
    %     at this location)
    Screen('Drawlines',scr.w,[ -W/2-ex.extraWidth W/2+ex.extraWidth ; BP(2)-0.7*S BP(2)-0.7*S ], tlW, ex.yellow, [x0 y0], 0);
else
    Screen('Drawlines',scr.w,[ -W/2-ex.extraWidth W/2+ex.extraWidth ; BP(2)-force*S BP(2)-force*S ], tlW, ex.yellow, [x0 y0], 0);
end

% Draw apples in tree image according to reward level
if ~ex.fatiguingExercise
    Screen('DrawTexture', scr.w, scr.imageTexture(rewardIx+1),[], ...
        [ (x0-3*W) (y0 + BP(2) - ex.effortLevel(end)*S - numel(ex.effortLevel)*W) (x0 + 3*W) (y0 + BP(2) - ex.effortLevel(end)*S) ]);
end

% Display reward and effort level in text
%   (note previous versions only displayed effort visually as a forcebar)
if rewardIx > 0
    if doAppleText
        % Reward level in number of apples
        formatstring = 'Appels: %d ';
        drawTextCentred(scr, sprintf(formatstring, rewardLevel), ex.fgColour, scr.centre + [0 300]);
        % Effort level
        if strcmpi(ex.language,'NL'), formatstring = 'Inspanningsniveau: %d ';
        else, formatstring = 'Effort level: %d '; end
        drawTextCentred(scr, sprintf(formatstring, effortIx), ex.fgColour, scr.centre + [0 350]);
    end
end

% Draw the momentary force height
% -------------------------------------------------------------------------
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

% Wrapping up
% -------------------------------------------------------------------------
% Display text in input otherText, if applicable
if ~doAppleText && ~isempty(otherText)
    drawTextCentred( scr, otherText, ex.forceColour, scr.centre + [0 200]);
end

% Flip screen
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
global totalReward

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
            displayInstructions(ex, ex.dirs.instructions, slideNrs, 'restore');
            
            % Display total reward before continuing a restored session in
            % the perform stage
            if strcmp(ex.stage,'perform')
                if strcmp(ex.language,'NL'), txt='Totaal verzamelde appels'; else, txt='Total apples gathered'; end
                drawTextCentred(scr, sprintf('%s: %d',txt, totalReward), pa.fgColour, scr.centre + [0,-100])
                WaitSecs(1);
            end
        else
            % Reset totalReward
            totalReward = 0;
            
            % Display welcome screen
            displayInstructions(ex, ex.dirs.instructions, slideNrs, 'welcome');
        end
    case 'end'
        slideNrs = 1;
        displayInstructions(ex, ex.dirs.instructions, slideNrs, 'end');
end

%% Start of block:
% this also controls calibration and practice at the start of the experiment
function [ex, tr] = blockfn(scr, el, ex, tr)
global totalReward
EXIT = 0;

% Display instructions
% -------------------------------------------------------------------------
if tr.block == 0  % Practice blocks
    
    % A practice block can be part of the practice stage, or it can be a 
    % short practice block before starting the main experiment blocks
    switch ex.stage
        case 'practice'
            % Display instructions according to which sub_stage of the
            % practice stage we are in
            switch tr.sub_stage
                case 'calibration'
                    % Only calibration instruction (rest of task 
                    % instructions come after calibration)
                    EXIT = displayInstructions(ex, ex.dirs.instructions, 1, 'practice');

                case {'familiarize','practice'}
                    if ex.numFamiliarise > 0 && tr.practiceTrialIx < 1
                        % If there are familiarize trials, start with 
                        % general task instructions, then specific 
                        % familiarize instruction
                        EXIT = displayInstructions(ex, ex.dirs.instructions, 2:6, 'practice');

                    elseif ex.numFamiliarise < 1
                        % If there are no familiarize trials, start with 
                        % general task instructions, then specific choice 
                        % practice instruction
                        EXIT = displayInstructions(ex, ex.dirs.instructions, [2:5,7:9], 'practice');

                    elseif ex.numFamiliarise > 0 && tr.practiceTrialIx > 0
                        % If there were familiarize trials, but we are now 
                        % ready for the choice practice, only present the 
                        % specific choice practice instruction
                        EXIT = displayInstructions(ex, ex.dirs.instructions, 7:9, 'practice');
                    end
            end
            
        case 'choice'
            % Display instructions of choice task that come before the
            % short practice block
            EXIT = displayInstructions(ex, ex.dirs.instructions, 1:3, 'choice');
        case 'perform'
            % Display instructions of perform task that come before the
            % short practice block
            EXIT = displayInstructions(ex, ex.dirs.instructions, 1, 'perform');
    end
    
elseif tr.block == 1 % start of experiment
    switch ex.stage
        case 'choice'
            % Display final instruction slide before starting the first
            % block of the choice stage
            EXIT = displayInstructions(ex, ex.dirs.instructions, 4);
        case 'perform'
            % Display final instruction slide before starting the first
            % block of the perform stage
            EXIT = displayInstructions(ex, ex.dirs.instructions, 2);
    end
    
else  % starting a new block of the main experiment
    
    % End of block text
    if strcmp(ex.language,'NL'), txt='Einde van dit blok.'; else, txt='End of block.'; end
    drawTextCentred(scr, txt, ex.fgColour, scr.centre +[0, -150]);
    
    % Inform how long before continuing
    if strcmp(ex.language,'NL'), txt = sprintf('De taak gaat over %d seconden verder',ex.blockBreakTime);
    else, txt = sprintf('The task will continue in %d seconds',ex.blockBreakTime); end
    drawTextCentred(scr, txt, ex.fgColour);
    
    % If perform stage, display total reward collected
    if strcmp(ex.stage,'perform')
        if strcmp(ex.language,'NL'), txt = sprintf('Totaal verzamelde appels: %d',totalReward);
        else, txt = sprintf('Total apples gathered: %d',totalReward); end
        drawTextCentred(scr, txt, ex.fgColour, scr.centre +[0, 150]);
    end
    
    % Show text and wait
    Screen('Flip',scr.w);
    tr = waitOrBreak(ex, tr, ex.blockBreakTime);
end

% If escape key was pressed, return with exit code
if ~EXIT
    tr.R = 1; % trial OK
else
    tr.R = ex.R_ESCAPE; % tells RunExperiment to exit.
    return
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
global  MVC totalReward

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
        % Number of trials per effort level
        numTrLvl = floor(ex.numFamiliarise/numel(ex.trialVariables.effortIx));
        
        % Get effort level
        if pa.practiceAscending
            % Gives 1,1,1,..,2,2,2,..,3,3,3,.. etc
            tr.effortIx = 1 + floor((famTrIndex-1)/numTrLvl);
            
            % Determine whether this was the last practice trial for this
            % effort level and we should ask for a VAS score after this
            % trial (if ex.effortVAS is true)
            if ex.effortVAS && ~mod(famTrIndex,numTrLvl)
                getVAS = true;
            else 
                getVAS = false;
            end
        else
            % Gives 1,2,3,4,5,  1,2,3,4,5  effort levels.
            tr.effortIx = 1 + mod(famTrIndex - 1, numel(ex.trialVariables.effortIx));
            
            % Determine whether this was the last practice trial for this
            % effort level and we should ask for a VAS score after this
            % trial (if ex.effortVAS is true)
            if numTrLvl > 1
                lastEffortPrac = famTrIndex > numel(ex.trialVariables.effortIx) && floor(famTrIndex/numel(ex.trialVariables.effortIx)) >= numTrLvl-1;
            else
                lastEffortPrac = floor(famTrIndex/numel(ex.trialVariables.effortIx)) >= numTrLvl-1;
            end
            if ex.effortVAS && lastEffortPrac
                getVAS = true;
            else
                getVAS = false;
            end
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
        
        % Wait with blank screen during time delay after response
        Screen('Flip',scr.w);
        tr = waitOrBreak(pa,tr,ex.delayAfterResponse);
        
        % Run the VAS function to ask for subjective effort experience, if
        % applicable
        if ex.effortVAS && getVAS
            [tr,EXIT] = doVAS(ex,scr,tr);
        else
            tr.VAS = nan;
        end
        
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
        Tdelay = pa.methodITI;
        if ischar(pa.methodITI)
            switch pa.methodITI
                case 'randUniform'
                    % Uniform random sample
                    Tdelay = (ex.minITI + rand*(ex.maxITI-ex.minITI));
                case 'randNormal'
                    assert(ex.minITI < ex.meanITI && ex.meanITI < ex.maxITI, 'Mean choice delay falls outside min to max range. Check settings');
                    
                    % Get sigma
                    if isfield(ex,'sigmaITI'), sigma = ex.sigmaITI;
                    else, sigma = (1/ex.meanITI)*(ex.maxITI-ex.minITI); end
                    
                    % Create truncated normal distribution
                    d = makedist('normal',ex.meanITI,sigma);
                    d = truncate(d,ex.minITI,ex.maxITI);
                    
                    % Random draw
                    Tdelay = random(d,1);
            end
        end
        tr = waitOrBreak(ex, tr, Tdelay);
        
        % Present tree with effort and stake in centre of screen
        drawTree(scr,ex,0,tr.rewardIx, tr.effortIx, 0, true, [], true);
        tr = LogEvent(ex,el,tr,'stimOnset');
        
        % Wait before presenting yes/no response options
        Tdelay = pa.methodChoiceDelay;
        if ischar(pa.methodChoiceDelay)
            switch pa.methodChoiceDelay
                case 'randUniform'
                    % Uniform random sample
                    Tdelay = (ex.minChoiceDelay + rand*(ex.maxChoiceDelay-ex.minChoiceDelay));
                case 'randNormal'
                    assert(ex.minChoiceDelay < ex.meanChoiceDelay && ex.meanChoiceDelay < ex.maxChoiceDelay, 'Mean choice delay falls outside min to max range. Check settings');
                    
                    % Get sigma
                    if isfield(ex,'sigmaChoiceDelay'), sigma = ex.sigmaChoiceDelay;
                    else, sigma = (1/ex.meanChoiceDelay)*(ex.maxChoiceDelay-ex.minChoiceDelay); end
                    
                    % Create truncated normal distribution
                    d = makedist('normal',ex.meanChoiceDelay,sigma);
                    d = truncate(d,ex.minChoiceDelay,ex.maxChoiceDelay);
                    
                    % Random draw
                    Tdelay = random(d,1);
            end
        end
        tr = waitOrBreak(ex, tr, Tdelay);
        
        % Draw tree and add 'yes/no' response options, then flip to present
        drawTree(scr,ex,0, tr.rewardIx , tr.effortIx, 0, true, [], false);
        drawTextCentred(scr, yestxt, ex.fgColour, scr.centre + [ tr.yeslocation 200]);
        drawTextCentred(scr, notxt, ex.fgColour, scr.centre + [-tr.yeslocation 200]);
        Screen('Flip',scr.w);
        tr = LogEvent(ex,el,tr,'choiceOnset');
        
        % Wait for a valid response or until deadline
        % -----------------------------------------------------------------
        % Deadline is the maximum response time, ex.maxRT
        deadline = GetSecs + ex.maxRT;
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
        WaitSecs(0.5);
        Screen('Flip', scr.w);
        tr = LogEvent(ex,el,tr,'trialEnd');
        
        % Copy Yestrial field to accept field in tr struct for consistent
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
            tr = waitOrBreak(ex, tr, ex.delayAfterResponse);
            
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
            
            % Check for key press
            [~,~,keyCode] = KbCheck;        % check for real key
            if keyCode(pa.exitkey), EXIT = true; end   % check for ESCAPE
        
            % Wait as long as a perform trial would take
            waitTime = ex.minSqueezeTime + ex.delayAfterResponse + pa.rewardDuration;
            tr = waitOrBreak(ex, tr, waitTime);
        end
        % Log end of trial
        tr = LogEvent(ex,el,tr,'trialEnd');
        
        % Store total reward in tr struct
        tr.totalReward = totalReward;
        
        % Present total reward feedback after the last perform trial
        if pa.allTrialIndex >= ex.blocks*ex.blockLen && ~ex.fatiguingExercise
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

function [tr,EXIT] = doVAS(ex,scr,tr)
% Function to run an interactive VAS scale to ask for the subjective effort
% experience.
% The VAS score is a continuous measure representing the percentage of the
% scale bar covered from left to right. 
% 
% OUTPUT
% The VAS score and response time are saved per question in the tr struct
% as: tr.VAS.Q1_score and tr.VAS.Q1_RT (Q1 until Qn for n questions).
%
% EXIT; returned when when escape key is pressed

EXIT = false;

% VAS questions to ask
switch ex.language
    case 'NL'
        % Questions
        Qs = {'Hoe zwaar was de taak fysiek gezien?'; ...
              'Hoe zwaar was de taak mentaal gezien?'};
        % Corresponding response options to display on the VAS scale
        Rs = {'Helemaal niet zwaar', 'Neutraal', 'Heel erg zwaar'; ...
              'Helemaal niet zwaar', 'Neutraal', 'Heel erg zwaar'};
    case 'EN'
        % Questions
        Qs = {'How effortful was the task physically?'; ...
              'How effortful was the task mentally?'};
        % Corresponding response options to display on the VAS scale
        Rs = {'Not effortful', 'Neutral', 'Extremely effortful'; ...
              'Not effortful', 'Neutral', 'Extremely effortful'};
end

% Window width and height
wdw = ex.screenSize(1);
wdh = ex.screenSize(2);

% VAS scale color settings
scalecol    = [160 160 160];
barcol      = [255 200 0];
slider      = [0 0 10 50];

% VAS scale position settings
xaxis       = [0.1*wdw 0.9*wdw; 0.7*wdh 0.7*wdh];
yleft       = [0.1*wdw 0.1*wdw; 0.65*wdh 0.75*wdh];
ymid        = [0.5*wdw 0.5*wdw; 0.65*wdh 0.75*wdh];
yright      = [0.9*wdw 0.9*wdw; 0.65*wdh 0.75*wdh];

% Text position settings
xyInstr     = scr.centre + [0,-100]; % instruction text position
xyQ         = scr.centre + [0,-300]; % question text position
yR          = 0.8*wdh;               % ylocation only of response options

% present black screen for sec before starting
Screen('FillRect',scr.w,ex.bgColour);
Screen('Flip', scr.w);
WaitSecs(0.2);

% Instruction text
switch ex.language
    case 'NL'
        instructionTxt = 'Klik met de muis op de lijn op de plek die het best overeenkomt met uw gevoel.';
    case 'EN'
        instructionTxt = 'Use the mouse to click on the bar at the spot that best matches your feeling.';
end

% Loop over questions to ask
for iQ = 1:numel(Qs)
    
    % Starting position slider
    xpos         = ymid(1,1);
    bottomslider = CenterRectOnPoint(slider,xpos,xaxis(2,1));
    
    % Draw instruction text, question and slider
    drawTextCentred(scr, Qs{iQ}, ex.fgColour, xyInstr)
    drawTextCentred(scr, instructionTxt, ex.fgColour, xyQ)
    Screen('FillRect', scr.w, barcol, bottomslider);
    
    % Draw response options
    drawTextCentred(scr, Rs{iQ,1}, barcol, [xaxis(1,1),yR])
    drawTextCentred(scr, Rs{iQ,2}, barcol, [ymid(1,1),yR])
    drawTextCentred(scr, Rs{iQ,3}, barcol, [xaxis(1,2),yR])
    
    % Draw scale
    Screen('DrawLines',scr.w,xaxis,2,scalecol);
    Screen('Drawlines',scr.w,yleft,2,scalecol);
    Screen('Drawlines',scr.w,ymid,2,scalecol);
    Screen('Drawlines',scr.w,yright,2,scalecol);
    
    % Present screen
    Screen('Flip', scr.w);
    
    % Check for mouse button click (10 sec window)
    ShowCursor(scr.w);
    validResponse = false; tic;
    while ~validResponse
        clear x y buttons
        [x,y,buttons] = GetMouse(scr.w);
        
        % Check that mouse click was within the bounds of the slider
        if buttons(1) && (xaxis(1,1) < x && x < xaxis(1,2) && yleft(2,1) < y && y < yleft(2,2))
            RT = toc;
            validResponse = true;
            
            % Save RT and clicked position as the VAS output
            tr.VAS.(sprintf('Q%d_score',iQ)) = (x - xaxis(1,1))/(xaxis(1,2)-xaxis(1,1));
            tr.VAS.(sprintf('Q%d_RT',iQ))    = RT;
        end
        
        % Check for escape key press
        [~,~,keyCode] = KbCheck;        % check for real key
        if keyCode(ex.exitkey), EXIT = true; return; end   % check for ESCAPE
    end
    
    % Calculate new position slider
    xpos = x;
    bottomslider = CenterRectOnPoint(slider,xpos,xaxis(2,1));
    
    % Draw instruction text, question and slider
    drawTextCentred(scr, Qs{iQ}, ex.fgColour, xyInstr)
    drawTextCentred(scr, instructionTxt, ex.fgColour, xyQ)
    Screen('FillRect', scr.w, barcol, bottomslider);
    
    % Draw response options
    drawTextCentred(scr, Rs{iQ,1}, barcol, [xaxis(1,1),yR])
    drawTextCentred(scr, Rs{iQ,2}, barcol, [ymid(1,1),yR])
    drawTextCentred(scr, Rs{iQ,3}, barcol, [xaxis(1,2),yR])
    
    % Draw scale
    Screen('DrawLines',scr.w,xaxis,2,scalecol);
    Screen('Drawlines',scr.w,yleft,2,scalecol);
    Screen('Drawlines',scr.w,ymid,2,scalecol);
    Screen('Drawlines',scr.w,yright,2,scalecol);
    
    % Present screen and wait 1 sec
    Screen('Flip', scr.w);
    WaitSecs(1);
end

% When finished, say thanks and wait for buttonpress to continue
if strcmp(ex.language,'NL'), txt = 'Bedankt!'; else, txt = 'Thank you!'; end
drawTextCentred(scr, txt, ex.fgColour)
if strcmp(ex.language,'NL'), txt = 'Druk op een knop om verder te gaan.'; 
else, txt = 'Press a button to continue'; end
drawTextCentred(scr, txt, ex.fgColour, scr.centre + [0 200])
Screen('Flip', scr.w);
waitForKeypress(ex);



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
        [resp, ~] = ex.BitsiBB.getResponse(0.1, true); % don't wait longer than 30 s.
        if resp > 0, spacepressed = true; end
    else
        WaitSecs(0.1);
    end
end % wait for a key to be pressed before starting
if escapepressed, EXIT = true; return; else, EXIT=false; end

while KbCheck, WaitSecs(0.1); end  % (and wait for key release)
return