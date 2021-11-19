function [ss,zz]=readAllEDF(list, path)
% readAllEDF ( list [, path] ): preprocessing to load EDF saccade data from
% experiments.
%
% list is either a list of .mat files each containing a variable starting with 
% 'z' or 'result', that was produced by the RunExperiment routine; or
% alternatively you can directly pass a structure previously returned by
% RunExperiment.
% It runs readEDFASC to convert each of the 'edfFiles' files to a saccade
% structure. Once converted you can modify the saccade list 'sl' to remove
% unwanted trials, so that the size exactly matches that of the data in
% z.data. When you finish, type 'dbcont' and the saccades will be analysed
% and stored in the output z, using putSaccadesIntoData.
% optional parameter: path - prepended to filenames before reading edf or
% asc files. (please put a trailing slash!)

if(isstruct(list)) list={list};end;
ss=[];
for i=1:length(list)
    zn=list{i};
    if(~isstruct(zn))
        zs=load(zn);
        fn=fieldnames(zs);
        c=0;
        for j=1:length(fn);
            if(fn{j}(1)=='z' | strcmp(fn{j}(1:6),'result') )
                z=zs.(fn{j});
                c=c+1;
            end;
        end;
        if(c~=1)
            warning(['file ' zn ' contains ' num2str(c) ' z variables.']);
            zs, keyboard;
        end;
    else
        z=zn
    end;

    ns=0;
    sl={};
    for j=1:length(z.edfFiles)
        if ~exist('path','var'), path=''; end
        s=readEDFASC([path z.edfFiles{j}],1,1);
        if isfield(s(1),'B_m')
          disp(['file ' z.edfFiles{j} ' from ' s(1).B_m ' to ' s(end).B_m]);
        elseif isfield(s(1),'BT_m')
          [s.B_m]=s.BT_m;
        else
          [s.B_m]=deal('');
        end
        sl{j}=s;
        ns=ns+length(s);
    end;
    sl_All = sl; % preserve undeleted items in case needed
    if(ns~=prod(size(z.data))) %incorrect number of trials
        nexcess=ns-prod(size(z.data));
        warning(['saccades "sl" do not match data "z"']);
        cblk=1;ctri=1;
        for j=1:length(sl)% go through each set of saccades
            disp(['sl{' num2str(j) '} from ' sl{j}(1).B_m(1:end-1) ...
                ' to ' sl{j}(end).B_m(1:end-1)]);
            k=1; 
            while(k<=length(sl{j})) 
                btstr=sl{j}(k).B_m;
                deleted=0;
                if(length(btstr)==0)
                    if(nexcess>0)
                        sl{j}(k)=[];
                        k=k-1;
                        nexcess=nexcess-1;
                        deleted=1;
                    end
                else
                    bt=sscanf(btstr,'%d T %d');
                    if(cblk>bt(1) || (cblk==bt(1) && ctri>bt(2))) % is it a earlier trial?
                        if(k==1)
                            sl{j}(k)=[]; % at the beginning of a saccade file, delete this one
                        else
                            sl{j}(k-1)=[]; % otherwise delete the previous one
                        end
                        k=k-1;
                        nexcess=nexcess-1;
                        deleted=1;
                    end;
                end;
                if(~deleted)
                    ctri=ctri+1; %increment block and trial
                    if(ctri>z.params.blockLen)ctri=1;cblk=cblk+1;end
                else
                    fprintf('deleted s %d, %d\n',j,k);
                end;
                k=k+1;
            end
            % now all saccades correspond to their corresponding position
            % in the experiment. But what if there are extras at the end?
            nDataTrials = prod(size(z.data));
            if length(sl{j})>nDataTrials % more saccades than trials
              sl{j}((nDataTrials+1):end) = []; % delete any excess
              fprintf('deleting %d trailing saccades\n', length(sl{j})-nDataTrials);
            end
        end;
        z.data, sl
        fprintf('edit structure, and when you have the correct \n number of trials, type dbcont to continue');
        keyboard;
    end
    for j=1:length(sl)
        if ~isfield(sl{j},'VOID_TRIAL_t')
            [sl{j}.VOID_TRIAL_t]=deal([]);
            [sl{j}.VOID_TRIAL_m]=deal([]);
        end;
        ss=[ss sl{j}];
    end;
    if exist('zz')~=1
        zz=z;
    else
        zz=combineData(zz,z);
    end;
end;
    
    
    