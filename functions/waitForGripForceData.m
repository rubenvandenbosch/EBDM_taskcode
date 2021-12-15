   function [squeezeData, keys, timeOfLastAcquisition] = waitForGripForceData(ex,...
   timeOfLastAcquisition, ...
   maxTimeToWait, stopRecordingAtThreshold , ISI, ...
   continuousFeedbackFunction )
% Function to stream data from Gripforce device (TSG/RU manufactured device).
% Requires a Fieldtrip recording buffer daemon in combination with a (Matlab)
% client responsible for streaming data from Gripforce to this buffer.
% 'timeOfLastAcquisition':
%  Kept for backwards compatibility reasons, by getting the current
%  state of the header, the actual number of samples acquired thusfar is 
% returned. Just start acquiring samples from that point in time.
% 
%     (Needs to know the time of the last acquisition in order to calculate
%     how many samples to dequeue before starting this acquisition.
%     The first time you call this in a trial, you should send the time that
%     the acquisition started - i.e. tr.startSqueezyAcquisition.
%     Subsequent calls in the same trial must pass the value returned from
%     this function 'timeOfLastAcquisition'.)
%
% The function blocks execution until either
% 1) the force exceeds 'stopRecordingAtThreshold'
% 2) the time elapsed exceeds 'maxTimeToWait'.
%
% The function returns a matrix 'sqeezeData(TIME,CHANNEL)'
% which is the force data for the left and right channels
% and also if any keys were pressed, they are in the vector 'keys',
% otherwise this vector is empty.
%
% Not necessary using the Fieldtrip buffer (handled by ft_read_header)
%     (Finally, we also return "timeOfLastAcquisition" which is the time that we
%     last checked the MP150 stream. This is needed for further calls, to know
%     how much data to de-queue)
%
% continuousFeedbackFunction( currentForce )
%  should be a function that can be called repeatedly each time new samples
%  are acquired. You can do the drawing in here.

url = 'buffer://localhost:1972';
% get current acquisition status (no dequeueing required, just start reading from this point in time)
oldhdr = ft_read_header(url); % oldhdr.nSamples marks the start of current data record
startRecordingTime = GetSecs;
lastread = startRecordingTime;
nTotalRead = 0;
EXIT = 0;

record = zeros(0,2);
while(GetSecs < startRecordingTime + maxTimeToWait && ~EXIT)
   %%%% CHECK KEYPRESSES
   [keyisdown,secs,keycode] = KbCheck;      % check for real key
   keys=find(keycode);
   if(any(keys==27)), EXIT=1; end           % check for ESCAPE
   
   % get current acquisition status (where are we, how many samples have
   % been acquired up to now)
   newhdr = ft_read_header(url);
   
   if (newhdr.nSamples > oldhdr.nSamples)   % any data in queue?
      data = ft_read_data(url,'begsample',oldhdr.nSamples+1,'endsample',newhdr.nSamples);
      lastread=GetSecs;
      nTotalRead=nTotalRead+(newhdr.nSamples-oldhdr.nSamples);

      record = cat(1,record,data'); % todo: check channel dimension for concatenating!!
      twentyMilliSecSamples = max(1, ex.MP_SAMPLE_RATE * (20/1000));
      if nTotalRead > twentyMilliSecSamples
         mu  = mean( record((nTotalRead-twentyMilliSecSamples):nTotalRead, :) );       % 20ms mean force
         mud = mean( diff(record((nTotalRead-twentyMilliSecSamples):nTotalRead, :)) ); % 20ms mean differential
         if any(mu > stopRecordingAtThreshold)
            EXIT=1;
            fprintf('Exit wait gripforce: mu=%.2f\tthreshold=%.2f\n',mu,stopRecordingAtThreshold);
         end
      end
   end
   oldhdr = newhdr;
   if exist('continuousFeedbackFunction','var') && ~isempty(continuousFeedbackFunction) && exist('mu','var')
      continuousFeedbackFunction( mu ); % if the user supplied a feedback
      % function, call it now with the mean force over last 20ms (this is
      % a vector with two elements, one for each channel)
   end
end
timeOfLastAcquisition = lastread; % send back the time we last read the device
squeezeData = record; % send back the actual data recorded
%fprintf('size returned record: %d\n',size(record,1));

