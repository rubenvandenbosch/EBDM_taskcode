function EXIT = displayInstructions(ex, instructionsDir, stage)
% displayInstructions(ex, instructionsDir, stage)
% 
% INPUTS
% ex              : struct; experiment parameters
% instructionsDir : char; directory containing image files of instruction
%                   slides
% stage           : char; which experiment stage to display experiment
%                   slides for.
%                   Possible values: 
%                  - 'general'     : general task explanation
%                  - 'calibration' : calibration instructions
%                  - 'familiarize' : familiarize instructions
%                  - 'practice'    : practice choices instructions
%                  - 'choice'      : choice task instructions
%                  - 'choiceStart' : final slide(s) before start choices
%                  - 'perform'     : perform stage instructions
%                  - 'performStart': final slide(s) before start perform
%                  - 'welcome'     : show welcome slide
%                  - 'restore'     : show restored session slide
%                  - 'end'         : show end of experiment slide
% 
% OUTPUT
% EXIT  : return exit code if escape/exit key was pressed. Tells program to
%         quit experiment
% -------------------------------------------------------------------------
% 

% Process input arguments
% -------------------------------------------------------------------------
assert(isstruct(ex), 'Input ex should be class struct')
assert(ischar(instructionsDir), 'Input instructionsDir should be class char')
assert(ischar(stage), 'Input stage should be class char')
assert(ismember(stage,{'general','calibration','familiarize','practice', 'choice','choiceStart', 'perform','performStart','welcome','restore','end'}), ...
    'Input stage should be one of: general, calibration, familiarize, practice, choice, choiceStart, perform, performStart, welcome, restore, end')

% Prepare screen if necessary
% -------------------------------------------------------------------------
if ~isfield(ex, 'scr')
    ex.scr = prepareScreen(ex);
end

% Get all instruction slide images for the requested task stage
% -------------------------------------------------------------------------
list = dir(fullfile(instructionsDir,sprintf('instructions_%s_%s_*.*', ex.language,stage)));
imgfiles = cell(numel(list),1);
for ifile = 1:numel(list)
    imgfiles{ifile} = fullfile(list(ifile).folder,list(ifile).name);
end
imgfiles = sort(imgfiles);

% Display instruction slide images
% -------------------------------------------------------------------------
slideNr = 1;
EXIT = 0;
while slideNr <= numel(imgfiles)
    
    % Read and display image
    image = imread(imgfiles{slideNr});
    Screen('PutImage', ex.scr.w, image);
    Screen('Flip', ex.scr.w);
    
    % Wait before allowing key press
    WaitSecs(1);
    
    % Wait for a button press
    resp = 0;
    if ex.useBitsiBB
        while resp == 0
            ex.BitsiBB.clearResponses(); % empty input buffer
            [resp, ~] = ex.BitsiBB.getResponse(0.2, true); % wait for any button press
            if resp == 0
                % Check whether exit key on keyboard was pressed
                [~, ~, resp, ~] = KbCheck();
                if resp(ex.exitkey), break; end
            end
        end
    else
        [~,resp,~] = KbWait();
    end
    
    % If the exit key was pressed, return with exit code.
    % If left key was pressed, go back one slide (if possible), except when
    % in the choice stage in MRI.
    % Otherwise continue to next slide or continue the experiment.
    if ex.useBitsiBB
        if any(resp==ex.exitkey)
            EXIT = 1;
            return
        elseif slideNr > 1 && any(resp==ex.leftKey) && ~strcmp(ex.stage,'choice')
            slideNr = slideNr - 1;
            WaitSecs(0.1);
        else
            slideNr = slideNr + 1;
            WaitSecs(0.1);
        end
    else
        if resp(ex.exitkey)
            EXIT = 1;
            return
        elseif slideNr > 1 && resp(ex.leftKey) && ~strcmp(ex.stage,'choice')
            slideNr = slideNr - 1;
            WaitSecs(0.1);
        else
            slideNr = slideNr + 1;
            WaitSecs(0.1);
        end
    end
end
end
