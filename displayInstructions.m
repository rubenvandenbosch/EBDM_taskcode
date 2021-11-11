function ex = displayInstructions(ex, instructionsDir, slides, varargin)
% ex = displayInstructions(ex, instructionsDir, slides, stage)
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
%                       'restore' (show restored session slide)
%                   If not specified, it is based on the value of ex.stage
% -------------------------------------------------------------------------

% Process input arguments
assert(nargin <= 4, 'Too many input arguments')
if nargin == 4; stage = varargin{1}; assert(ischar(stage), 'Input stage should be class char'); end
assert(isstruct(ex), 'Input ex should be class struct')
assert(ischar(instructionsDir), 'Input instructionsDir should be class char')
assert(isnumeric(slides), 'Input slides should be numeric')

if ~exist('stage','var'), stage = ex.stage; end
assert(ismember(stage,{'practice', 'choice', 'perform','welcome','restore'}), 'Input stage should be one of: practice, choice, perform, welcome, restore')

% Prepare screen if necessary
if ~isfield(ex, 'scr')
    ex.scr=prepareScreen(ex);
end

% Display selected instruction slides
for n = 1:numel(slides)
    % Get file name
    filename = fullfile(instructionsDir,sprintf('instructions_%s_%s_%d.jpg',ex.language,stage,slides(n)));
    
    % If requested file does not exist, warn and continue
    if ~(exist(filename,'file') == 2)
        warning('Instructions file does not exist: %s', filename)
        continue
    end
    
    % Read and display image
    image = imread(filename);
    Screen('PutImage', ex.scr.w, image);
    Screen('Flip', ex.scr.w);
    
    % Wait and wait for key press
    WaitSecs(2);
    myKbWait(ex);
    WaitSecs(0.5);
end