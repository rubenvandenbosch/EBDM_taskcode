function y=removeBlinks(x)
% x = vector of reals
% find nans, and remove fast bits before and after.
d       = diff(isnan(x));
starts  = find(d==1);
vel     = diff(x);
smvel   = smooth(diff(smooth(x,3,'boxcar')),3,'boxcar'); % smoothed
meanspd = nanmean(abs(smvel));
stdspd  = nanstd( abs(smvel));
% work backwards from blink-starts
for i = 1:length(starts) % from start of each blink
  j = starts(i)-1; % relative position
  go = 4; % wait until this many consecutive nonblink values
  while j>0 & go>0
    if abs(vel(j))>(meanspd+1*stdspd)
      x(j)=nan;
      go=2; 
    else
      x(j)=nan;
      go=go-1;
    end
    j=j-1; 
  end
end
% work forwards from blink-ends
d     = diff(isnan(x));
ends  = find(d==-1);
for i = 1:length(ends)
  j = ends(i)+1;
  go = 4;
  while j<=length(x) & go>0
    if abs(vel(j))>(meanspd+1*stdspd)
      x(j)=nan;
      go=2;
    else
      x(j)=nan; % nan if not surrounded by normal vel points
      go=go-1;
    end
    j=j+1;
  end
end

y=x;  