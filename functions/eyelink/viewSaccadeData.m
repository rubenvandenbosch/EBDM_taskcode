function [sel, d] = viewSaccadeData(s,z, sel, plotfields, extraCommand )
% [sel, d] = viewSaccadeData(saccades, experimentResult, selectedTrials, plotfields )
%
% allow browsing the saccades, drawing spatial and time-graphs for each
% trial. Press H for help during interactive function.
%
% saccades: a structure of eyelink data, as read by readEDFASC()
% experimentResult: an experiment result structure, as created by
%                   RunExperiment
% plotfields: a structure containing field names to plot (these are the event names
%             crated by eyelink messages
%
%        plotfields.tStart = 'fieldname1'
%        plotfields.tEnd = 'fieldname2'
%        plotfields.times = {'fieldname3', 'fieldname4' }
%
%    if plotfields is absent or [], then use z.params.dataFields, 
% 
% sel: send a selection list, or return a selection list from the command.
%      This is a vector of trial indices. ( [] means no selection )
%
% extraCommand: a command to run after drawing each trial - e.g. to display
%      extra trial information / statistics.. The expression can include 
%            'z' for the experiment result structure, 
%            'i' for the current trial index, 
%            'd(i)' for the current experiment data (z.data), 
%            's(i)' for the saccade data.
% d: returns the trial data (z.data) - use when you want to delete trials.

r=s;
if exist('z','var') e=z; end;
help=['H: help, P: previous, N: next, shift+P/N: within selection, '...
      'E: toggle early, L: toggle late, S: toggle selected, '...
      'D: delete; ctrl+D: delete selected, sh+D: delete saccades only, '...
      'M: mark time in dstruct, G goto'] ;

if exist('e')
    if isstruct(e)
        if isfield(e, 'data')
            d=e.data;
        else
            d=e;
        end
        if (~exist('plotfields') || isempty(plotfields)) && isfield(e, 'params')
            if isfield(e.params, 'dataFields')
                plotfields=e.params.dataFields;
            elseif isfield(e.params, 'dataFields')
                plotfields=e.params.dataFields;
            end
        end;
    else
        d=0;
    end;
else d=0;
end

i=1; n=length(r);
key=NaN;
% close all;
f1=figure(1); clf
f2=figure(2); clf
if exist('sel')~=1 sel=[]; end;
showEarlyPoints=0; showLatePoints=0;
while key~=27 && key~='Q'
    if length(r(i).pos)
        times=[];times_=[]; points=[];
        t0=r(i).pos(1,1);
        tstart=t0; tend=r(i).pos(end,1);
        if isstruct(d) & exist('plotfields')
            szd=size(d);
            if(szd>1)
              b=1+floor((i-1)/szd(2)); t=1+mod((i-1), szd(2));
              if i > prod(szd) b=szd(1); t=szd(2); disp('cant show all saccades as they outnumber the trials'); end;
              disp(d(b,t));
            else b=1;t=1;
            end
            if isfield(plotfields, 'tStart')
                tstart_=d(b,t).(plotfields.tStart);
                tstart =  r(i).([plotfields.tStart '_t']);
            end
            if isfield(plotfields, 'tEnd')
                tend_=d(b,t).(plotfields.tEnd);
                tend =  r(i).([plotfields.tEnd '_t']);
            end
            if isfield(plotfields, 'times')
                times=[];
                for j=1:length(plotfields.times)
                    if isfield(r(i), [plotfields.times{j} '_t'])
                        times=[times,   r(i).([plotfields.times{j} '_t'])];
                    else
                        times=[times, d(b,t).(plotfields.times{j})];
                    end;
                end;
            else plotfields.times={};
            end;
            if isfield(plotfields, 'points')
                if iscell(plotfields.points)
                    points=[];
                    for j=1:length(plotfields.points)
                        if isnumeric(plotfields.points{j})
                            points=[points; plotfields.points{j}];
                            pointnames{j}=['(' num2str(j) ')'];
                        elseif isfield(d(b,t), plotfields.points{j})
                            points=[points; d(b,t).(plotfields.points{j})];
                            pointnames{j}=plotfields.points{j};
                        end
                    end;
                end
            end;
        end;
        idx=find(r(i).pos(:,1) > tstart & r(i).pos(:,1) < tend);
        idxe=find(r(i).pos(:,1) < tstart);
        idxl=find(r(i).pos(:,1) > tend);
        figure(f2);
        plot(r(i).pos(idx,1), r(i).pos(idx,2), 'r', r(i).pos(idx,1), r(i).pos(idx,3), 'b');
        hold on;
        plot(r(i).pos(idx,1), r(i).pos(idx,4)*0.10, 'y');
        if showEarlyPoints
            plot(r(i).pos(idxe,1), r(i).pos(idxe,2), 'g', r(i).pos(idxe,1), r(i).pos(idxe,3), 'g');
            plot(r(i).pos(idxe,1), r(i).pos(idxe,4)*0.10, 'y');
        end
        if showLatePoints
            plot(r(i).pos(idxl,1), r(i).pos(idxl,2), 'g', r(i).pos(idxl,1), r(i).pos(idxl,3), 'g');
            plot(r(i).pos(idxl,1), r(i).pos(idxl,4)*0.10, 'y');
        end;
        hold off
        for j=1:length(times)
            if j>length(plotfields.times) timename=['Marker ' num2str(j-length(plotfields.times)+1)];
            else timename = plotfields.times{j};
            end;
            text(times(j), 600-j*30, ['\uparrow ' timename]);
        end;
        figure(f1);
        plot(r(i).pos(idx,2), r(i).pos(idx,3), '. b');
        hold on;
        if showEarlyPoints
            plot(r(i).pos(idxe,2), r(i).pos(idxe,3), '. g');
        end
        if showLatePoints
            plot(r(i).pos(idxl,2), r(i).pos(idxl,3), '. g');
        end;
        hold off;        axis([200 1000 0 1000]);

        for j=1:size(points,1)
            text( points(j,1), points(j,2), ['\leftarrow ' pointnames{j}]);
        end;
    end;
    title(['Trial ' num2str(i) ', Sel :' num2str(find(sel==i))]);
    if exist('extraCommand','var')
      eval(extraCommand);
    end
    
    
    %% interact
    if(exist('FlushEvents'))
        FlushEvents;
        pause;
        [z z kcode]=KbCheck;
        key=find(kcode);
        ctrl=kcode(17); shift=kcode(16);
    else % no psychtoolbox...
        [key,key,key]=ginput(1);
        ctrl=(key<32); % can't do ctrl+A/B/C as this is mouse 1/2/3
        if ctrl; key=key+64; end;
        shift=(key>33 & key<91); % not sure of effect of these
        if (~shift) & (key>96); key=key-32; end;
    end;
    if length(key)>0
        if length(key>1) akey = key(find(key>64 & key<91)); else akey=key; end;
        if length(akey)==0 akey='`';end;
        switch akey
         case 'N',
             if shift
                 q=min(sel(sel>i));
                 if length(q) i=q; else disp('no later selections');end;
             else
                 i=i+1, if i>n disp('last trial'); i=n; end;
             end;
         case 'P', 
             if shift
                 q=max(sel(sel<i));
                 if length(q) i=q; else disp('no earlier selections'); end;
             else
                 i=i-1, if i<1 disp('first trial'); i=1; end;
             end;
         case 'S', di=find(sel==i); 
            if di   sel(di)=[]; 
            else    sel = [sel i];
            end;
         case  'E', showEarlyPoints = ~showEarlyPoints;
            case 'L', showLatePoints= ~showLatePoints;
            case 'H', disp(help);
            case 'D', 
                if shift
                    if input(sprintf('Delete just eye movements for trial %d? (1/0)',i))
                        r(i)=[];
                    end
                elseif ctrl
                    if input(sprintf('Delete all %d selected trials? (1/0)',length(sel)))
                        r(sel)=[];
                        d(sel)=[];
                        sel=[];
                    end;
                else
                    if input(sprintf('Delete trial %d? (1/0)',i))
                        r(i)=[];
                        d(b,t)=[];
                        sel(sel==i)=[];
                        sel(sel>i)=sel(sel>i)-1;
                    end;
                end;
            case 'M'
                [mx my]=ginput(1);
                %plotfields.times={plotfields.times{:} mx};
                if isfield(d(b,t),'marker')
                    d(b,t).marker=[d(b,t).marker mx];
                else
                    d(b,t).marker=mx;
                end;
            case 'G'
                i2=input('Go to trial :');
                if i2<1 | i2>length(r) disp('invalid trial number');
                else i=i2;
                end;
        end;
    end;
    if length(key)~=1, key=nan; end
end;
% close(f1);
% close(f2);
