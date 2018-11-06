function burstdetguifunc(src,~,job,varargin)
% ** function burstdetguifunc(src,eventdata,job,varargin)
% Collection of callback routines for burstdetgui.m
%                         >>> INPUT VARIABLES >>>
%
% NAME              TYPE/DEFAULT          DESCRIPTION
% sp               struct                handles to subplots of main
%                                         figure


% to do (new):
% - ap and ds in head vs. 'local' ap and ds not very satisfactory
% - the whole concept of addressing separate units per channel (=cells of
% bu.etsl) is error-prone as it is implemented now, e.g. if the number of
% units per channel changes from file to file (of a given experiment). The
% code dealing with separate units is for now left in place because there
% may be times ahead in which we need to be able to do this. In this case,
% threshdetgui will have to change, too
% - also, different units of a channel might as well be elements of a
% struct bu, so bu(2).etsl instead of bu.etsl{2}
% - different mode of determining burst start: convolution + threshold? 

% We need some global data:
%   evt.tsl=cell array of time stamp lists of single 'events' 
%   bu.etsl=extended time stamp list of phases of activity ('bursts')
% Strucures:
%   ds='data set' listing properties of current file
%   ap='analysis parameters' describing details of current analysis
%   wp='working parameters' (like colors)
%   sp=subplot handles
global evt bu ds ap wp sp 
persistent head

pvpmod(varargin);
etslconst;

done=0;
while ~done
  partJob=job{1};
  switch partJob
    case 'init'
      % *******************************************************************
      % in this ini job, all fields of wp, ap and ds are set up. This is a
      % necessity because the callbacks set here are handles to functions
      % expecting fully defined variables. Besides, it is helpful to have
      % an overview of all fields of above-mentioned key variables. Last,
      % but not least, default values for some parameters are set.
      % *******************************************************************
      % ----- set up major variables 
      head=[];
      evt.tsl=[];
      bu.etsl=[];
      bu.silentEtsl=[];
      bu.atsl=[];
      % --------------------------
      % ----- set up ds (data set)
      % --------------------------
      % uigetfile returns 0 as output arguments if the cancel button is
      % hit, so use these as initializing values
      ds.dataFn=0;
      ds.dataPath=0;
      % will contain a number of file-specific parameters after upload
      ds.fileInfo=[];
      
      % -------------------------------------
      % ----- set up ap (analysis parameters)
      % -------------------------------------      
      % name of results file
      ap.resFn='lastFile_res';
      % name of ascii file holding time stamp list of events 
      ap.asciiEvtFn='lastFile_evtTsl';

      % ~~~~~~~ burst detection section
      % inter-event interval threshold (ms) for burst start
      ap.maxIEI_init=100;
      % inter-event interval threshold (ms) for bursts 
      ap.maxIEI_tail=500;
      % minimum number of events a burst must consist of
      ap.minNEvPerBurst=3;
      % minimum length of silent period before burst (ms)
      ap.minPreBurstSilentPerLen=2000;
      % maximum number of events allowed in silent period
      ap.maxPreBurstSilentPerNEv=1;

      % *** the following parameters are currently inactivated in
      % burstdet_optgui and must not be criteria in burst detection *** 

      % length (ms) beyond which a burst will be regarded a 'freak' event
      % (but will still enter all statistics)
      ap.maxNormalBurstLength=inf;
      % minimally acceptable duration of bursts
      ap.minBurstLen=inf;
      % --------------------------------------
      % ----- set up wp ('working' parameters)
      % --------------------------------------      
      % index to & name of unit (of possibly multi-'channel' tsl)
      wp.tslUnitInd=1;
      wp.tslUnitName=['U' int2str(wp.tslUnitInd)];

      % ~~~~~~~ display options & matlab version section
      % which version of Matlab?
      wp.mver=ver;
      % note that in standalone deployed code function ver may produce
      % several entries with .Name equal to 'Matlab', so we have to opt for
      % one
      tmpIx=find(strcmpi('matlab',{wp.mver.Name}),1);
      wp.mver=str2double(wp.mver(tmpIx).Version);
      % standard background color of subplots in main figure window
      wp.stdAxCol=[.8 .8 1];
      % time interval covered per line in raster plot, s
      wp.OvPlotTAx=10;
      % numerical code and color for specific types of burst/event:
      wp.isFreakBurst=3;
      wp.freakBurstCol=[.95 .7 .1];
      % peri-event-time histogram (peth): limits
      wp.pethInterval=[-500 2000];
      % peri-event-time histogram (peth): bin width
      wp.pethBinWid=5;
      % bins for peth will be computed later
      wp.pethBin=[];
      % handle to text for display of information
      wp.infoCharH=nan;
      % handle to text for display of currently selected burst information
      wp.infoChar2H=nan;
      % flag informing burstpick whether fresh raw data have to be read
      wp.freshRawDataFlag=false;
      % flag informing us whether loaded event time stamp list is empty
      wp.evtTslEmptyFlag=false;

      % ~~~~~~~ saving options section
      wp.resFnString='';
      % the following working pars are not accessible in the options
      % dialog
      % number of events in current tsl
      wp.nTs=0;
      % time stamp list of events in excerpt plot
      wp.evtTsl=[];
      % time stamp list of bursts in excerpt plot
      wp.buEtsl=[];
      % current ccordinate of mouse click in overview plot
      wp.curCo=[0 0];
      
      % ----- initialize subplots
      % -- tsl, overview 
      subplot(sp.tslOv.axH), cla, hold on
      axis off
      set(sp.tslOv.axH,'color',wp.stdAxCol);
      tmpyl=get(gca,'ylim');
      tmpxl=get(gca,'xlim');
      % handle to patch object whose ButtonDownFcn callback generates an
      % excerpt plot (burstpick)
      sp.tslOv.patchH=patch(tmpxl([1 1 2 2])',tmpyl([1 2 2 1])',wp.stdAxCol);
      % lines indicating bursts
      sp.tslOv.burstLh=nan;
      % relative height of these lines in the plot
      sp.tslOv.BurstLineRelHeight=.02;
      % markers indicating start of bursts
      sp.tslOv.evMarkH=nan;
      % relative height of these markers in the plot 
      sp.tslOv.EvMarkRelHeight=.85;

      % -- tsl, aligned to burst start 
      subplot(sp.tslExc.axH), hold on,
      set(sp.tslExc.axH,'color',wp.stdAxCol);
      % initialize handle to excerpt plot
      sp.tslExc.excH=plot(nan,'k');
      % plot the dummy patch
      tmpyl=get(gca,'ylim');
      tmpxl=get(gca,'xlim');
      sp.tslExc.patchH=patch(tmpxl([1 1 2 2])',tmpyl([1 2 2 1])',wp.stdAxCol);
      % -- info
      set(sp.info.axH,'color',[.9 .9 .9],'box','on','xtick',[],'ytick',[]);
      % -- iei
      set(sp.iei.axH,'color',wp.stdAxCol);
      % vertical line representing maxIEI_tail
      wp.maxIEI_tailLH=nan;
      % -- raw excerpt
      set(sp.rawExc.axH,'color',wp.stdAxCol,'xtick',[],'ytick',[]);

      % -- peth
      set(sp.peth.axH,'color',wp.stdAxCol);
      job(1)=[];
      
    case 'optionsDialogAlert'
      handles=guihandles(findobj('tag','options'));
      set(handles.OKParBttn,'BackgroundColor','r')
      job(1)=[];

    case 'openOptionsDialog'
      burstdet_optgui(src);
      job(1)={'writeOptions2Gui'};
      
    case 'writeOptions2Gui'
      % set the various uicontrols' strings and values to those of
      % corresponding fields of ap and wp, all along checking for errors
      % get handles to all uicontrols via uihandles.m ...
      handles=guihandles(findobj('tag','options'));
      uicFn=fieldnames(handles);
      apFn=fieldnames(ap);
      wpFn=fieldnames(wp);
      structName={'ap','wp'};
      % ..and set their 'string' properties to the values of the
      % matching fields of ap or wp
      for g=1:length(uicFn)
        structIx=[any(strcmp(uicFn{g},apFn)),...
          any(strcmp(uicFn{g},wpFn))];
        if length(find(structIx))==1
          eval(['cType=get(handles.' uicFn{g} ',''style'');']);
          switch cType
            case 'edit'
              % depending on the type of the field...
              switch uicFn{g}
                case {'resFnString'}
                  eval(['set(handles.' uicFn{g} ',''string'',' structName{structIx} '.' uicFn{g} ');']);
                otherwise
                  eval(['set(handles.' uicFn{g} ',''string'',num2str(' structName{structIx}  '.' uicFn{g} ',''% 6.2f''));']);
              end
            case 'checkbox'
              eval(['set(handles.' uicFn{g} ',''value'',' structName{structIx}  '.' uicFn{g} ');']);
            case 'text'
              % do nothing because text uicontrols do not hold any
              % information
            otherwise
              errordlg('internal: encountered uicontrol other than edit, checkbox or text');
          end
        elseif length(find(structIx))>1
          errordlg(['internal: uicontrol tagged ''' uicFn{g} ''' has more than one matching fields in ap and wp']);
        end
      end
      job(1)=[];

    case 'readOptionsFromGui'
      % the inverse of job 'writeOptions2Gui': retrieve the various 
      % uicontrols' strings and values and set corresponding fields of ap 
      % and wp. All checks for major pitfalls are done in 'writeOptions2Gui' 
      % so they are omitted here.
      handles=guihandles(findobj('tag','options'));
      uicFn=fieldnames(handles);
      apFn=fieldnames(ap);
      wpFn=fieldnames(wp);
      structName={'ap','wp'};
      for g=1:length(uicFn)
        structIx=[any(strcmp(uicFn{g},apFn)),...
          any(strcmp(uicFn{g},wpFn))];
        if length(find(structIx))==1
          eval(['cType=get(handles.' uicFn{g} ',''style'');']);
          switch cType
            case 'edit'
              % depending on the type of the field...
              switch uicFn{g}
                case {'resFnString'}
                  eval([structName{structIx} '.' uicFn{g} '=get(handles.' uicFn{g} ',''string'');']);
                otherwise
                  eval(['[tmpNum,conversionOK]=str2num(get(handles.' uicFn{g} ',''string''));']);
                  if conversionOK
                    eval([structName{structIx} '.' uicFn{g} '=tmpNum;']);
                  else
                    warndlg(['could not read value for ' structName{structIx} '.' uicFn{g} ' - only numeric values are allowed (typographic error?)'])
                  end
              end
            case 'checkbox'
              eval([structName{structIx}  '.' uicFn{g} '=get(handles.' uicFn{g} ',''value'');']);
            otherwise
          end
        end
      end
      set(handles.OKParBttn,'BackgroundColor',get(handles.saveParBttn,'BackgroundColor'));
      job(1)={'digestOptions'};

    case 'writeOptions2File'
      % *** it is extremely important not to dump wp/ap to file because
      % each of these has fields which cannot be set in the options dialog
      % but are determined e.g. after upload of fresh raw data. Instead,
      % the whole figure including the uicontrols will be saved (and loaded
      % by 'readOptionsFromFile'). This is certainly less than elegant, but 
      % it is relatively fail-safe
      [tmpDataFn,tmpDataPath] = uiputfile('*.fig');
      if ischar(tmpDataFn) && ischar(tmpDataPath) 
        saveas(findobj('tag','options'),[tmpDataPath tmpDataFn ],'fig');
      end
      job(1)=[];
      
    case 'readOptionsFromFile'
      [tmpOptFn,tmpOptPath] = uigetfile('*.fig','pick options file');
      if ischar(tmpOptFn) && ischar(tmpOptPath)
        close(findobj('tag','options'));
        open([tmpOptPath tmpOptFn]);
      end
      job(1)={'optionsDialogAlert'};

    case 'digestOptions'
      % this part job must be run when options were read from gui
      disp('** processing & checking options..');
      % ----- checks of parameters:
      if isfinite(ap.minBurstLen)
        if ap.minBurstLen<=0
          warndlg('minimal burst length not OK - setting to inf');
          ap.minBurstLen=inf;
        end
      end
      % --- display options:
      % - bin borders for peth with one bin with zero as left border
      if length(wp.pethInterval)~=2
        warndlg('peri-burst time interval must contain two values')
      else
        if diff(wp.pethInterval)<=0
          warndlg('peri-burst time interval must contain two values, the left one being lower than the right one');
        end
        if wp.pethInterval(1)>0
          warndlg('left border of peri-burst time interval must be smaller than zero - setting it to 0');
          wp.pethInterval(1)=0;
        end
      end
      if isempty(wp.pethBinWid) 
        warndlg('peri-burst time histogram bin width is empty - setting to 1');
        wp.pethBinWid=1;
      end
      % not necessary - tslpeth will do that
      % wp.pethBin=[fliplr(0:-wp.pethBinWid:wp.pethInterval(1)) wp.pethBinWid:wp.pethBinWid:wp.pethInterval(2)];
      if ~isempty(wp.resFnString)
        wp.resFnString=deblank(wp.resFnString);
      end
      job(1)=[];      

    case 'closeOptionsDialog'
      tmph=findobj('name', 'options', 'type', 'figure');
      if ~isempty(tmph)
        close(tmph);
      end
      job(1)=[];      
      
    case 'readData'
      % delete/reset results/plots/variables from last file/channel
      % empty tsl
      evt.tsl=[];
      bu.etsl=[];
      bu.silentEtsl=[];
      bu.atsl=[];
      wp.evtTsl=[];
      wp.buEtsl=[];
      % delete all lines & markers & set handles to nan
      if any(ishandle(sp.tslOv.burstLh))
        delete(sp.tslOv.burstLh);
        sp.tslOv.burstLh=nan;
      end
      if any(ishandle(sp.tslOv.evMarkH))
        delete(sp.tslOv.evMarkH);
        sp.tslOv.evMarkH=nan;
      end
      if any(ishandle(wp.infoCharH))
        delete(wp.infoCharH);
        wp.infoCharH=nan;
      end
      if any(ishandle(wp.infoChar2H))
        delete(wp.infoChar2H);
        wp.infoChar2H=nan;
      end
      % wipe plots
      cla(sp.tslOv.axH);
      cla(sp.iei.axH);
      cla(sp.rawExc.axH);
      cla(sp.info.axH);
      cla(sp.tslExc.axH);
      cla(sp.peth.axH);
      drawnow;
      % by default, set to false
      wp.evtTslEmptyFlag=false;
      % unit name & index is deliberately left at old value
      if ds.dataPath
        [tmpDataFn,tmpDataPath] = uigetfile('*.mat','pick data file',ds.dataPath);
      else
        [tmpDataFn,tmpDataPath] = uigetfile('*.mat','pick data file');
      end
      if ischar(tmpDataFn) && ischar(tmpDataPath)
        ds.dataFn=tmpDataFn;
        ds.dataPath=tmpDataPath;
        % load data
        load([ds.dataPath ds.dataFn],'evt','head');
        % retrieve information about the raw file from which tsl was
        % determined
        ds.fileInfo=head.ds.fileInfo;
        % don't forget to set flag 
        wp.freshRawDataFlag=true;
        % check how many units are in evt.tsl and offer option to choose one
        % (evt.tsl may be an array or a cell array)
        if iscell(evt.tsl)
          wp.tslNUnit=numel(evt.tsl);
          unitNames=[repmat('U',wp.tslNUnit,1)  int2str((1:wp.tslNUnit)')];
        else
          wp.tslNUnit=1;
          unitNames='U1';
        end
        % if more than one unit found, open dialog for unit, keeping chosen
        % one as default selection
        if wp.tslNUnit>1
          if ~isempty(wp.tslUnitName)
            wp.tslUnitInd=picklistitem(unitNames,'defaultVal',find(strcmp(wp.tslUnitName,unitNames)));
          else
            wp.tslUnitInd=picklistitem(unitNames);            
          end
          wp.tslUnitName=['U' int2str(wp.tslUnitInd)];
        else
          wp.tslUnitInd=1;
          wp.tslUnitName='U1';
        end
        if iscell(evt.tsl)
          evt.tsl=evt.tsl{wp.tslUnitInd};
        else
          % nothing to be done because there is only one unit
        end
        % ** now check whether tsl is empty
        if isempty(evt.tsl)
          wp.evtTslEmptyFlag=true;
        end
        % *** once complete info is available set some wp vars
        tmpix=strfind(ds.dataFn,'.');
        % name of .mat file - same as the one uploaded
        ap.resFn=[ds.dataPath ds.dataFn];
        % name of ascii file(s)
        % § redundant
        ap.asciiEvtFn=[ds.dataPath ds.dataFn(1:tmpix(end)-1) '_'  wp.tslUnitName '_' wp.resFnString];
        % next two jobs: plotting data & detecting bursts
        job(2:end+1)=job;
        job(1:2)={'plotOv','detBurst'};
        clear tmp*
      else
        job(1)=[];
      end

    case  'plotOv'
      if ~isempty(evt.tsl)
        subplot(sp.tslOv.axH), cla, hold on
        rasterplot(evt.tsl,'xIntv',wp.OvPlotTAx);
        axis on; set(gca,'ytick',[]);
        title([ds.dataFn ', ' wp.tslUnitName],'color','b','fontsize',10,'fontweight','bold','interpreter','none');
        % re-create dummy patch
        tmpyl=get(gca,'ylim');
        tmpxl=get(gca,'xlim');
        sp.tslOv.patchH=patch(tmpxl([1 1 2 2])',tmpyl([1 2 2 1])',[.9 .9 1]);
        % put to background
        set(sp.tslOv.axH,'children',circshift(get(sp.tslOv.axH,'children'),-1));
      end
      job(1)=[];
      
    case 'detBurst'
      cla(sp.rawExc.axH)
      % etsl must be emptied because it may exist from former session
      bu.etsl=[];
      bu.silentEtsl=[];
      bu.atsl=[];
      bu.stats=[];
      wp.buEtsl=[];
      if any(ishandle(sp.tslOv.burstLh))
        delete(sp.tslOv.burstLh);
        sp.tslOv.burstLh=nan;
      end
      if any(ishandle(sp.tslOv.evMarkH))
        delete(sp.tslOv.evMarkH);
        sp.tslOv.evMarkH=nan;
      end
      if any(ishandle(wp.infoCharH))
        delete(wp.infoCharH);
        wp.infoCharH=nan;
      end
      if any(ishandle(wp.infoChar2H))
        delete(wp.infoChar2H);
        wp.infoChar2H=nan;
      end
      if ishandle(wp.maxIEI_tailLH)
        set(wp.maxIEI_tailLH,'xdata',ap.maxIEI_tail*[1 1]);
      end
      % etslburstf can handle empty tsl, so no need for differentiation
      % here
      [bu.etsl,bu.atsl,bu.silentEtsl,bu.stats]=etslburstf(evt.tsl,ap.maxIEI_tail,...
        'recLen', diff(ds.fileInfo.recTime)*1000,...
        'maxIEI_init',ap.maxIEI_init,...
        'minNEvPerBurst',ap.minNEvPerBurst,...
        'minSilentPerDur',ap.minPreBurstSilentPerLen,...
        'maxSilentPerNEv',ap.maxPreBurstSilentPerNEv,...
        'startTs','iei');
      % tag 'freak bursts'
      bu.etsl(bu.etsl(:,etslc.durCol)>ap.maxNormalBurstLength,etslc.tagCol)=wp.isFreakBurst;
      if ~isempty(evt.tsl)
        job(4:end+3)=job;
        job(1:4)={'plotBurst','plotIEI','plotPETH','plotBurstAligned'};
      else
        if wp.evtTslEmptyFlag
          subplot(sp.tslOv.axH),
          text(mean(get(gca,'xlim')),mean(get(gca,'ylim')),'no events in data file','fontsize',16,'color','r','fontweight','bold','horizontalalignment','center');
        else
          % this can only be the case when detect button was inadvertently
          % hit
          warndlg('no data loaded')
        end
        job(1)=[];
      end
      
    case 'plotBurst'
      % plot line markers for bursts, set callbacks & put out some
      % information
      nTs=size(bu.etsl,1);
      if nTs>0
        % draw lines marking detected bursts in overview plot:
        % - compute coordinates of burst start and stop times as if we
        % wanted to plot them
        tmpStopTs=sum(bu.etsl(:,[etslc.tsCol etslc.durCol]),2);
        [~,buStartXY]=rasterplot(bu.etsl(:,etslc.tsCol),'xIntv',wp.OvPlotTAx,'plotType','none');        
        [~,buStopXY]=rasterplot(tmpStopTs,'xIntv',wp.OvPlotTAx,'plotType','none');
        % add negative offset to y coordinates
        buStartXY(:,2) = buStartXY(:,2) - 0.5;
        buStopXY(:,2) = buStopXY(:,2) - 0.5;
        % plot the burst start times by single markers so very short burst
        % can readily be identified (this must be done before the
        % corrections below)
        subplot(sp.tslOv.axH),
        sp.tslOv.evMarkH=plot(buStartXY(:,1),buStartXY(:,2),'m.');
        set(sp.tslOv.evMarkH,'markersize',12);
        % - bursts suffering from one or more line breaks can be identified
        % by unequal y values as produced by rasterplot with the current
        % axis setting
        % the elementary y offset from line to line is by definition 1
        eYOffs=1;
        % these are the y offset differences in the burst start and stop
        % times
        buYDiff=abs(buStartXY(:,2)-buStopXY(:,2));
        % lbbIx points to broken bursts
        lbbIx=find(buYDiff);
        % lbbIx2 points to bursts broken over more than 2 lines
        lbbIx2=find(buYDiff>eYOffs+2*eps);
        % 1. intermediate portions of bursts with 2+ line breaks, if any:
        % APPEND lines for intermediate portions of bursts
        for g=1:numel(lbbIx2)
          tmpY=buStartXY(lbbIx2(g),2)-eYOffs:-eYOffs:buStopXY(lbbIx2(g),2)+eYOffs-eps;
          buStartXY=cat(1,buStartXY,[zeros(size(tmpY'))  tmpY']);
          buStopXY=cat(1,buStopXY,[1000*wp.OvPlotTAx*ones(size(tmpY'))  tmpY']);
        end          
        % 2. APPEND the broken END of bursts to lists by taking 
        % -- 0 as fresh x start values 
        % -- y value of stop ts as fresh y start value
        buStartXY=cat(1,buStartXY,[zeros(numel(lbbIx),1)  buStopXY(lbbIx,2)]);
        % -- x value of stop ts as fresh x stop values 
        % -- y value of stop ts as fresh y stop value
        buStopXY=cat(1,buStopXY,[buStopXY(lbbIx,1) buStopXY(lbbIx,2)]);
        % 3. fix BEGINNING of broken bursts by 
        % -- setting x values of stop ts to wp.OvPlotTAx IN MILLISECONDS
        % -- setting y values of stop ts to same value as corresponding
        % start ts
        buStopXY(lbbIx,1)=wp.OvPlotTAx*1000;
        buStopXY(lbbIx,2)=buStartXY(lbbIx,2);
        % ** sort!
        tmp=sortrows([buStartXY buStopXY],[-2 1]);
        buStartXY=tmp(:,[1 2]);
        buStopXY=tmp(:,[3 4]);
        % plot lines
        subplot(sp.tslOv.axH),
        sp.tslOv.burstLh=line([buStartXY(:,1)'; buStopXY(:,1)'],[buStartXY(:,2)'; buStopXY(:,2)'],'color','r','linewidth',3);
        % use the 'userdata' field of the lines to store the index into
        % etsl so the callback boils down to indexing etsl (essentially)
        tmp=cumsum(buYDiff+1);
        for lix=1:length(sp.tslOv.burstLh)
          tmpIx=find(tmp>=lix, 1);
          set(sp.tslOv.burstLh(lix),'userdata',tmpIx,'ButtonDownFcn',{@burstpick,bu.etsl,head});
          % change color of freak bursts
          if bu.etsl(tmpIx,etslc.tagCol)==wp.isFreakBurst
            set(sp.tslOv.burstLh(lix),'color',wp.freakBurstCol);
          end
        end
        
        % ----- display a few basic parameters:
        subplot(sp.info.axH),
        txt={...
            ['eff. rec time: ' num2str(bu.stats.recTime/1000,'%1.2f')],...
            ['fract ev: ' num2str(bu.stats.fractionEvInBurst,'%1.2f')],...
            ['rate: ' num2str(bu.stats.burstRate,'%1.4f') ' Hz'],...
            ['length: ' num2str(bu.stats.mnBurstLen,'%5.2f') '+/-' num2str(bu.stats.stdBurstLen,'%5.2f') ' ms'],...
            ['rel. time: ' num2str(bu.stats.relTimeInBurst,'%1.4f')],...
            ['sil per len: ' num2str(bu.stats.mnSilentPerLen,'%5.2f') '+/-' num2str(bu.stats.stdSilentPerLen,'%5.2f') ' ms'],...
          };
        wp.infoCharH=text(.05,0,txt,'VerticalAlignment','bottom','fontsize',9);
      else
        warndlg('no burst detected');
      end
      job(1)=[];
      
    case  'plotIEI'
      if ~isempty(evt.tsl)
        % --- iei of events
        subplot(sp.iei.axH), cla, hold on
        % this should be the most interesting range for task at hand
        bin=10:10:wp.pethInterval(2)*2;
        n=histc(diff(evt.tsl),bin);
        bar(bin+wp.pethBinWid/2,sqrt(n),1.0,'k');
        niceyuax;
        % line for iei thresh
        wp.maxIEI_tailLH=line(ap.maxIEI_tail*[1 1],get(gca,'ylim'),'color','r','linewidth',2,'linestyle','--');
        ylabel('sqrt(N)')
        xlabel('inter-event-interval (ms)');
      end
      job(1)=[];
      
    case  'plotPETH'
      % --- peth
      nTs=size(bu.etsl,1);
      if nTs>0
        [peth,wp.pethBin]=tslpeth(bu.etsl(:,etslc.tsCol),evt.tsl,'interval',wp.pethInterval,...
          'intvDistance',1,'binw',wp.pethBinWid);
        peth(:,any(~isfinite(peth),1))=[];
        % set axis limits and plot peth
        subplot(sp.peth.axH), cla, hold on
        set(gca,'xlim',wp.pethBin([1 end]));
        bar(wp.pethBin,mean(peth,2),1.0,'k');
        xlabel('peri-burst time (ms)');
      end
      job(1)=[];

    case  'plotBurstAligned'
      % --- bursts, aligned & peth
      nTs=size(bu.etsl,1);
      if nTs
        subplot(sp.tslExc.axH), cla, hold on
        rasterplot(evt.tsl,'xIntv',wp.pethInterval/1000,'etsl',bu.etsl);
        axis tight
        set(gca,'xlim',wp.pethBin([1 end]), 'ytick',[]);
      end
      job(1)=[];
      
    case 'saveResults'
      % write as atsl
      try
        write_atsl(bu.atsl,[ap.resFn '.txt'],...
          'rectime',diff(ds.fileInfo.recTime),...
          'ephys_filename',head.ds.dataFn,...
          'ephys_chan',head.wp.dataChanName{1},...
          'ev_threshold',head.ap.thresh,...
          'burst_interval1',ap.maxIEI_init,...
          'burst_interval2',ap.maxIEI_tail,...
          'burst_minev',ap.minNEvPerBurst,...
          'silentper_dur',ap.minPreBurstSilentPerLen,...
          'silentper_maxev',ap.maxPreBurstSilentPerNEv,...
          'comment',['generated by ' mfilename]);
      catch ME
        warndlg({'Writing of atsl failed, possibly because the *.mat file loaded for burst analysis does not contain sufficient information about the recording (old version of threshdetgui).',...
          'Here is the explicit error message: ',...
          ME.message});
      end
      % save result by default as cell array because there may be several
      % units per channel
      bubu=bu;
      clear bu;
      load(ap.resFn,'bu','ap_bu');
      % if bu is an array, overwrite it; if it is a cell array, 
      % place the current tsl in it
      % §§ Jan 09: this is of course nonsense but leave in place until
      % maybe one day the option to deal with several separate units will
      % be used
      if wp.tslNUnit>1
        if exist('bu','var') && ~iscell(bu)
          % delete old ones
          bu=[];
          ap_bu=[];
        end
        bu.etsl{wp.tslUnitInd}=bubu.etsl;
        bu.silentEtsl{wp.tslUnitInd}=bubu.silentEtsl;
        bu.stats{wp.tslUnitInd}=bubu.stats;
        % save local ap as ap_bu
        ap_bu(wp.tslUnitInd)=ap;
      else
        bu.etsl=bubu.etsl;
        bu.silentEtsl=bubu.silentEtsl;
        bu.stats=bubu.stats;
        % save local ap as ap_bu
        ap_bu=ap;
      end
      save([ap.resFn],'bu','ap_bu','-mat','-append');
      bu=bubu;
      clear bubu ap_bu;
      
      job(1)=[];

    case 'done'
      tmph=findobj('name', 'Burst Determination', 'type', 'figure');
      if ~isempty(tmph)
        delete(tmph);
      end
      tmph=findobj('name', 'options', 'type', 'figure');
      if ~isempty(tmph)
        delete(tmph);
      end
      job(1)=[];
      clear global

    otherwise
      errordlg(['illegal job: ' partJob]);
      error(['illegal job: ' partJob]);      
  end
  done=isempty(job);
end




