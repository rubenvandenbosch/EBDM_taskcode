function ex = displayInstruction(ex, slideNumber)

% ex: experiment parameters
% slides: which slide(s) to display

% Instructions in folders:
% Instructions_MVC, File: Dia01.jpg
% Instructions_HandgripExercise, Files: Dia01.jpg - Dia10.jpg
% Instructions_AppleTask, Files: Dia01.jpg - Dia10.jpg
%------------------
% EDIT BL (18-feb-21)
% Made separate instructions for instructions in cubicles (familiarise and perform) and in scanner (choice task)
% 

[pictsPath, ~, ~] = fileparts(mfilename('fullpath'));

% i.e., 'MVC', 'Hexercise' or 'ChoiceTask'
pictsPath = fullfile(pictsPath, sprintf('Instructions_%s',ex.stage));
   
if ~isfield(ex, 'scr')
   ex.scr=prepareScreen(ex); 
end

filename = fullfile(pictsPath,sprintf('Dia%02d.jpg',slideNumber));
if ~exist(filename,'file')
  return
end
image = imread(filename);
Screen('PutImage', ex.scr.w, image);
Screen('Flip', ex.scr.w);


