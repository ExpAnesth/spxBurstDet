function burstpick(src,edat,etsl,head,varargin)
% ** function burstpick(src,edat,etsl,head,varargin)

% is part of the spike detection gui (threshdetgui.m).
% It is the callback of ButtonDownFcn of a 'dummy' patch (a rectangle) in
% subplot sp.tslOv.axH. Extracts an excerpt of data d centered on the x
% coordinate of a mouse click in the subplot and plots it in subplot
% sp.tslExc.axH. If input argument 'co' is explicitly specified the
% coordinate of the mouse click is ignored

global wp ap sp ds 
persistent rawD si fi

pvpmod(varargin);
etslconst;

% --- delete outdated info
if any(ishandle(wp.infoChar2H))
  delete(wp.infoChar2H);
  wp.infoChar2H=nan;
end
subplot(sp.rawExc.axH)
cla
% --- load fresh raw data
if wp.freshRawDataFlag
  % try original file location first...
  fExist=false;
  ffn=[head.ds.dataPath  '\' head.ds.dataFn];
  if exist(ffn,'file')
    fExist=true;
  else
    % look in current directory
    if exist(head.ds.dataFn,'file')
      ffn=head.ds.dataFn;
      fExist=true;
    end
  end
  if fExist
    % little info..
    subplot(sp.rawExc.axH)
    th=ultext('just a sec please, loading raw data...',0.02,'fontsize',12,'color','b');
    drawnow
    % try to make sense of the channel
    [nix,nix2,fi]=abfload(ffn,'info');
    chIx=[];
    for g=1:fi.nADCNumChannels
      % channel name without blanks
      if strfind(ds.dataFn,fi.recChNames{g}(fi.recChNames{g}~=32))
        chIx=[chIx g];
      end
    end
    if numel(chIx)~=1
      warndlg('raw data channel name could not be identified - displaying first channel');
      chIx=1;
      subplot(sp.rawExc.axH)
    end
    % load complete data for one channel
    [rawD,si]=abfload(ffn,'channels',fi.recChNames(chIx));
    % hipass filter mildly, just in case..
    rawD=hifi(rawD,si,100);
  else
    th=ultext([head.ds.dataFn ' not found'],0.02,'fontsize',10,'color','k');
    drawnow
  end
  % whatever the outcome of the above, don't go a-lookin' for them again!
  wp.freshRawDataFlag=false;
end

% --- plot excerpt
if ~isempty(rawD)
  % always try to display burst +- 25 % of data at each end
  intv=cumsum(etsl(get(src,'userdata'),[etslc.tsCol etslc.durCol]));
  % to pts
  intv=cont2discrete(intv,si/1000,'intv',1);
  intvLen=diff(intv);
  intv(1)=max(round(intv(1)-.25*intvLen),1);
  intv(2)=min(round(intv(2)+.25*intvLen),fi.dataPtsPerChan);
  % do it
  subplot(sp.rawExc.axH)
  pllplot(rawD(intv(1):intv(2),:),'si',si,'noscb',1);
  set(sp.rawExc.axH,'color',wp.stdAxCol);
  axis on
end
  
% --- put out info
txt=['burst start: ' num2str(etsl(get(src,'userdata'),etslc.tsCol)/1000,'%5.1f') ' s'];
wp.infoChar2H=ultext(txt,0.01,'color','b','fontweight','bold');
    
