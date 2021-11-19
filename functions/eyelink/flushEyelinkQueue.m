% function flushEyelinkQueue(el)
% calls eyelink GetQueuedData until the buffer is empty
% sanjay manohar

function flushEyelinkQueue(el)
drained=0;while(~drained)
    [samples, events,drained]=Eyelink('GetQueuedData');
end
