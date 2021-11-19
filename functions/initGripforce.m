function ex = initGripforce(ex)
    if ex.useSqueezy
       error('Either use Squeezy or Gripforce device, not both!');
    end
    [p, ~, ~] = fileparts(mfilename('fullpath'));
    % add fieldtrip online folder
    addpath(fullfile(p,'gripforce','fieldtrip','fileio'));
    ex.gripforce.url = 'buffer://localhost:1972';
    ex.gripforce.fthdr = ft_read_header(ex.gripforce.url);
    ex.MP_SAMPLE_RATE = ex.gripforce.fthdr.Fs; 
   return
end