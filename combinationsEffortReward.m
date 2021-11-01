function selection = combinationsEffortReward(effort,reward,num)
E = 5; % number of effort levels
R = 5; % number of reward levels (should be equal to E)
combinations = cell(E,R); 
for e=1:E
   for r=1:R
      for n=1:length(effort)
         if effort(n) == e && reward(n) == r
            %fprintf('effort: %d\treward: %d\tindex: %d\n', e,r,n);
            % store indices into effort vector of all effort/reward combinations
            combinations{e,r}(end+1)=n; % index n will be used in AGT_CoreProtocol... in defining performTrial via last_trial
            continue
         end
      end
   end
end

% take random 2 times each combination
rng('shuffle'); % Reinitialize the random number generator
selection = [];
for e=1:E
   for r=1:R
      % define a random couple of indexes taken from range 1:5
      range = randperm(numel(combinations{e,r}));
      %if isempty(range), continue, end % happens if not all combinations exist with len < E*R (25)
      idxs = range(1:num); % num x 25 ( num x E x R)
      selection = cat(2, selection, combinations{e,r}(idxs));
   end
end
% shuffle chosen selection 
% (ends up in E * R * 2 = 50 selections with 2 times each possible combination)
selection = selection(randperm(length(selection)));
   