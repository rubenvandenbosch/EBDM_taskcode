function EXIT = displayInstructions(ex, instructionsDir, slides, varargin)
% displayInstructions(ex, instructionsDir, slides, stage)
% 
% INPUTS
% ex              : struct; experiment parameters
% instructionsDir : char; directory containing image files of instruction
%                   slides
% slides          : num array; which slide(s) to display
% stage           : char; which experiment stage to display experiment
%                   slides from. 
%                   Possible values: 
%                       'practice', 'choice', 'perform', 
%                       'welcome' (show welcome slide),
%                       'restore' (show restored session slide),
%                       'end' (show end of experiment slide)
%                   If not specified, it is based on the value of ex.stage
% 
% OUTPUT
% EXIT  : return exit code if escape/exit key was pressed. Tells program to
%         quit experiment
% -------------------------------------------------------------------------

% Process input arguments
assert(nargin <= 4, 'Too many input arguments')
if nargin == 4; stage = varargin{1}; assert(ischar(stage), 'Input stage should be class char'); end
assert(isstruct(ex), 'Input ex should be class struct')
assert(ischar(instructionsDir), 'Input instructionsDir should be class char')
assert(isnumeric(slides), 'Input slides should be numeric')

if ~exist('stage','var'), stage = ex.stage; end
assert(ismember(stage,{'practice', 'choice', 'perform','welcome','restore','end'}), 'Input stage should be one of: practice, choice, perform, welcome, restore, end')

% Prepare screen if necessary
if ~isfield(ex, 'scr')
    ex.scr = prepareScreen(ex);
end

% Display selected instruction slides
slideNr = 1;
EXIT = 0;
while slideNr <= numel(slides)
    % Get file name
    filename = fullfile(instructionsDir,sprintf('instructions_%s_%s_%d.jpg',ex.language,stage,slides(slideNr)));
    
    % If requested file does not exist, warn and continue
    if ~(exist(filename,'file') == 2)
        warning('Instructions file does not exist: %s', filename)
        slideNr = slideNr + 1;
        continue
    end
    
    % Read and display image
    image = imread(filename);
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
