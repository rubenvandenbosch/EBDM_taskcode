function a1 = combineData(a1,a2, dimension)
% combineData( a1, a1 [,dimension] )
%
% Combine data from two sets, created by RunTrials.
% Checks whether the two experiments had different parameters.
% if so, copy the differing parameter data into each individual trial's
% parameters first, and remove from the main experiment parameter set.
% Then, merge all trials into one set containing a1.blocks + a2.blocks
% number of blocks.
% (c) Sanjay Manohar 2008


if(iscell(a1))
    q=a1{1};
    for i=2:length(a1)
        q=combineData(q,a1{i});
    end;
    a1=q;
    return;
end;

if ~exist('dimension') HORZ=1;
else HORZ=dimension==2;
end

% compare params
paramsDifferent = 0;
f1=fieldnames(a1.params); f2=fieldnames(a2.params);
for i=1:length(f1)
    ok=0;
    if ~isfield( a2.params, f1{i} ) ...
          | ~isequal( getfield(a1.params, f1{i}), getfield(a2.params, f1{i}))
        paramsDifferent = paramsDifferent + 1;
        diffParams{paramsDifferent} = f1{i};
    end;
end;
for i=1:length(f2)
    if ~isfield( a1.params, f2{i} ) | ~isequal(getfield(a1.params,f2{i}), getfield(a2.params, f2{i}))
        ok=0;
        for j=1:paramsDifferent
            if isequal(diffParams{j}, f2{i}) ok=1;end;
        end;
        if ~ok
            paramsDifferent=paramsDifferent + 1;
            diffParams{paramsDifferent} = f2{i};
        end
    end
end;
df1=fieldnames(a1.data); df2=fieldnames(a2.data);
for i=1:length(df1)
    if ~isfield(a2, df1{i})
        ok=0;
        for j=1:paramsDifferent
            if isequal(diffParams{j}, df1{i}) ok=1;end;
        end;
        if ~ok
            paramsDifferent=paramsDifferent + 1;
            diffParams{paramsDifferent} = df1{i};
        end
    end;
end;
for i=1:length(df2)
    if ~isfield(a1, df2{i})
        ok=0;
        for j=1:paramsDifferent
            if isequal(diffParams{j}, df2{i}) ok=1;end;
        end;
        if ~ok
            paramsDifferent=paramsDifferent + 1;
            diffParams{paramsDifferent} = df2{i};
        end
    end;
end;
    


% different parameters into each trial and the trial's data
nt1 = size(a1.data);
nt2 = size(a2.data);
for i=1:paramsDifferent
    disp(['merging fields "', diffParams{i} '"']);
    for j=1:nt1(1)
        for k=1:nt1(2)
            if isfield(a1.params, diffParams{i})
                a1.trials(j,k).(diffParams{i}) = getfield(a1.params, diffParams{i});
                a1.data(j,k).(diffParams{i})   = getfield(a1.params, diffParams{i});
            elseif ~isfield(a1.data(j,k), diffParams{i})
                disp(['*first structure does not contain "' diffParams{i} '", using NaN']);
                a1.data(j,k).(diffParams{i})   = NaN;
                a1.trials(j,k).(diffParams{i}) = NaN;
            end;
        end;
    end;
    for j=1:nt2(1)
        for k=1:nt2(2)
            if isfield(a2.params, diffParams{i})
                a2.trials(j,k).(diffParams{i}) = getfield(a2.params, diffParams{i});
                a2.data(j,k).(diffParams{i})   = getfield(a2.params, diffParams{i});
            elseif ~isfield(a2.data(j,k), diffParams{i})
                disp(['*second structure does not contain "' diffParams{i} '", using NaN.']);
                a2.data(j,k).(diffParams{i})   = NaN;
                a2.trials(j,k).(diffParams{i}) = NaN;
            end;
        end;
    end;
    if isfield(a1.params, diffParams{i}) a1.params=rmfield(a1.params, diffParams{i});end
end;

% DATA
a2.data=orderfields(a2.data, fieldnames(a1.data));
trialsok=1;
try
    a2.trials=orderfields(a2.trials, fieldnames(a1.trials));
catch
    trialsok=0;
    warning('trials structures contain different fields; ignoring "trials".');
end;
trialsok=0; % added because of change in block structure

% merge trial and trial data into a1
for i=1:nt2(1)
  for j=1:nt2(2)
    if HORZ
      a1.data(nt1(1)+i, j)   = a2.data(i,j);
      if trialsok
        a1.trials(nt1(1)+i, j) = a2.trials(i,j);
      end;
    else
      a1.data(i,nt1(2)+j) = a2.data(i,j);
      if trialsok
        a1.trials(i,nt1(2)+j) = a2.trials(i,j);
      end
    end
  end;
end;
%a1.params.blocks = a1.params.blocks + a2.params.blocks;






