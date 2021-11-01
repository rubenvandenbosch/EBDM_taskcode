function ex = displayInstructions(ex, slides)

% ex: experiment parameters
% slides: which slide(s) to display

% Instructions in folders:
% Instructions_MVC, File: Dia01.jpg
% Instructions_HandgripExercise, Files: Dia01.jpg - Dia10.jpg
% Instructions_AppleTask, Files: Dia01.jpg - Dia10.jpg

[pictsPath, ~, ~] = fileparts(mfilename('fullpath'));

% i.e., 'MVC', 'Hexercise' or 'ChoiceTask'
pictsPath = fullfile(pictsPath, sprintf('Instructions_%s',ex.stage));
   
if ~isfield(ex, 'scr')
   ex.scr=prepareScreen(ex); 
end

for n=1:numel(slides)   
   filename = fullfile(pictsPath,sprintf('Dia%02d_%s.jpg',slides(n),ex.language));
   if ~exist(filename,'file')
      break
   end
   image = imread(filename);
   Screen('PutImage', ex.scr.w, image);
   Screen('Flip', ex.scr.w);
   WaitSecs(2);
   myKbWait(ex);
   WaitSecs(0.5);
end


