function varargout = MicrophoneCal(varargin)
% MICROPHONECAL M-file for MicrophoneCal.fig
%      MICROPHONECAL, by itself, creates a new MICROPHONECAL or raises the existing
%      singleton*.
%
%      H = MICROPHONECAL returns the handle to a new
%      MICROPHONECAL or the handle to
%      the existing singleton*.
%
%      MICROPHONECAL('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MICROPHONECAL.M with the given input arguments.
%
%      MICROPHONECAL('Property','Value',...) creates a new MICROPHONECAL or raises the
%      existing singleton*.  
%

% Last Modified by GUIDE v2.5 04-Nov-2010 17:49:26

% Begin initialization code - DO NOT EDIT
	gui_Singleton = 1;
	gui_State = struct('gui_Name',       mfilename, ...
					   'gui_Singleton',  gui_Singleton, ...
					   'gui_OpeningFcn', @MicrophoneCal_OpeningFcn, ...
					   'gui_OutputFcn',  @MicrophoneCal_OutputFcn, ...
					   'gui_LayoutFcn',  [] , ...
					   'gui_Callback',   []);
	if nargin && ischar(varargin{1})
		gui_State.gui_Callback = str2func(varargin{1});
	end

	if nargout
		[varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
	else
		gui_mainfcn(gui_State, varargin{:});
	end
% End initialization code - DO NOT EDIT
%--------------------------------------------------------------------------


%--------------------------------------------------------------------------
% --- Executes just before MicrophoneCal is made visible.
function MicrophoneCal_OpeningFcn(hObject, eventdata, handles, varargin)
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% Initial setup
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		% load the configuration information, store in config structure
		config = MicrophoneCal_Configuration;

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% Update handles structure
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		handles.output = hObject;
		handles.ABORT = 0;
		
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% Setup Paths
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		disp([mfilename ': checking paths'])
		if isempty(which('RPload'))
			cdir = pwd;
			pdir = ['C:\TytoLogy\TytoSettings\' getenv('USERNAME')];
			disp([mfilename ': loading paths using ' pdir])
			cd(pdir);
			tytopaths
			cd(cdir);
		else
			disp([mfilename ': paths ok, launching programn'])
		end		
		
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% set defaults
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		% first check to see if defaults file exists
		% need to get the path for the mfile for MicrophoneCal
		mpath = mfilename('fullpath')
		defaultsfile = [mpath '_Defaults.mat']
		
		if exist(defaultsfile, 'file')
			disp('Loading cal data from defaults file...')
			load(defaultsfile, 'cal');
		else
			disp('using internal defaults for cal...')
			% Set the starting attenuation value
			cal.Atten = 40;
			% Frequency range and Step Size
			cal.Fmin = 200;
			cal.Fstep = 50;
			cal.Fmax = 15000;
			% # repetitions at each frequency
			cal.Nreps = 5;
			% output analog voltage max
			cal.DAscale = 5;
			% gain on the mic preamp [headphoneL headphoneR reference]
			cal.Gain_dB = [40 40 0];
			% sensitivity of the calibration mic in V / Pa
			cal.CalMic_sense = 10;
			% Field Type = FreeField
			cal.FieldType = 1;
			% SpeakerChannel = Left
			cal.SpeakerChannel = 1;
			% channels to Calibrate (L, R, B(oth) or R(eference))
			cal.CalChannel ='B';
			% HiPass Filter Fc (Hz)
			cal.HiPassFc = 60;
			% LoPass Filter Fc (Hz)
			cal.LoPassFc = 16000;
		end
		
		% save defaults file name
		handles.defaultsfile = defaultsfile;
		% store calibration struct
		handles.cal = cal;
		% calibration is incomplete
		handles.CalComplete = 0;
		guidata(hObject, handles);
		
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% load the BK mic pressure field data
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		BKPressureFile = 'W2495529.BKW';
		handles.cal.bkdata = readBKW(BKPressureFile);
		guidata(hObject, handles);
		
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% wherever the circuits are stored
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		
	  	iodev.Circuit_Path = config.CIRCUIT_PATH;
		iodev.Circuit_Name = config.CIRCUIT_NAME;
		iodev.status = 0;	
		% Dnum = device number
		iodev.Dnum = config.IODEVNUM;
		iodev.Fs = 48000;
		% store in handles struct
		handles.iodev = iodev;
		
		% input/output function handle (this is hardware dependent,
		% so it is stored in MicrophoneCal_Configuration() )
		handles.iofunction = config.IOFUNCTION;
		
		guidata(hObject, handles);
		
		

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% update the UI values
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		update_ui_str(handles.AttenuatorCtrl, handles.cal.Atten);
		update_ui_str(handles.FrequencyMinCtrl, handles.cal.Fmin);
		update_ui_str(handles.FrequencyMaxCtrl, handles.cal.Fmax);
		update_ui_str(handles.FrequencyStepCtrl, handles.cal.Fstep);
		update_ui_str(handles.RepetitionsCtrl, handles.cal.Nreps);
		calChanNum = calchannelstr2val(handles.cal.CalChannel);
		update_ui_val(handles.CalChannelCtrl, calChanNum);
		
		update_ui_str(handles.DAscaleCtrl, handles.cal.DAscale);
		update_ui_str(handles.CalibrationMicSensivityCtrl, handles.cal.CalMic_sense);
		update_ui_str(handles.LMicGainCtrl, handles.cal.Gain_dB(1));
		update_ui_str(handles.RMicGainCtrl, handles.cal.Gain_dB(2));
		update_ui_str(handles.RefMicGainCtrl, handles.cal.Gain_dB(3));
		update_ui_val(handles.FieldTypeCtrl, handles.cal.FieldType);
		update_ui_val(handles.SpeakerChannelCtrl, handles.cal.SpeakerChannel);

		set(handles.RunCalibration_ctrl, 'Enable', 'on');
		set(handles.AbortCtrl, 'Enable', 'off');
		set(handles.AbortCtrl, 'Visible', 'off');
		set(handles.AbortCtrl, 'HitTest', 'off');
		set(handles.AbortCtrl, 'Value', 0);
		update_ui_val(handles.FieldTypeCtrl, handles.cal.FieldType);
		update_ui_str(handles.HiPassFcCtrl, handles.cal.HiPassFc);
		update_ui_str(handles.LoPassFcCtrl, handles.cal.LoPassFc);
	
		guidata(hObject, handles);

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% UIWAIT makes MicrophoneCal wait for user response (see UIRESUME)
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		% uiwait(handles.figure1);
%--------------------------------------------------------------------------

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Action Control Callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function RunCalibration_ctrl_Callback(hObject, eventdata, handles)
	set(handles.RunCalibration_ctrl, 'Enable', 'off');
	set(handles.AbortCtrl, 'Enable', 'on');
	set(handles.AbortCtrl, 'Visible', 'on');
	set(handles.AbortCtrl, 'HitTest', 'on');
	set(handles.AbortCtrl, 'Value', 0);
	handles.CalComplete = 0;
	guidata(hObject, handles);
	
	MicrophoneCal_RunCalibration;

	set(handles.RunCalibration_ctrl, 'Enable', 'on');
	set(handles.AbortCtrl, 'Enable', 'off');
	set(handles.AbortCtrl, 'Visible', 'off');
	set(handles.AbortCtrl, 'HitTest', 'off');
	set(handles.AbortCtrl, 'Value', 0);
	
	if COMPLETE
		handles.CalComplete = 1;
		save(handles.defaultsfile, 'cal');
	end
	guidata(hObject, handles);
%--------------------------------------------------------------------------


%--------------------------------------------------------------------------
% --- Outputs from this function are returned to the command line.
function varargout = MicrophoneCal_OutputFcn(hObject, eventdata, handles) 
	% Get default command line output from handles structure
	varargout{1} = handles.output;
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function CloseRequestFcn(hObject, eventdata, handles)
	pause(0.1);
	delete(hObject);
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function AbortCtrl_Callback(hObject, eventdata, handles)
	disp('ABORTING Calibration!')
	handles.ABORT = 1;
	guidata(hObject, handles);	
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function PlotFRCtrl_Callback(hObject, eventdata, handles)
%--------------------------------------------------------------------------


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Menu Control Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
% Save the FR Calibration data 
%--------------------------------------------------------------------------
function SaveCalibration_ctrl_Callback(hObject, eventdata, handles)
	[calfile, calpath] = uiputfile('*_fr.mat','Save earphone calibration data in file');

	if calfile
		datafile = fullfile(calpath, calfile);
		frdata = handles.frdata;
		save(datafile, '-MAT', 'frdata');
	end
%--------------------------------------------------------------------------


%--------------------------------------------------------------------------
% Save the Raw Calibration data 
%--------------------------------------------------------------------------
function SaveRawData_ctrl_Callback(hObject, eventdata, handles)
	[rawfile, rawpath] = uiputfile('*.mat','Save raw earphone calibration data:');

	if rawfile
		datafile = fullfile(rawpath, rawfile);
		
		rawdata = handles.rawdata;
		frdata = handles.frdata;
		cal = handles.cal;
		save(datafile, '-MAT', 'rawdata', 'cal', 'frdata');
	end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
% Plot the Calibration data 
%--------------------------------------------------------------------------
function PlotFRData_Ctrl_Callback(hObject, eventdata, handles)
	if ~isfield(handles, 'frdata') 
		return
	end
	
	if isstruct(handles.frdata)
		frdata = handles.frdata;
	else
		return
	end
	
	if ~isfield(frdata, 'freq')
		return
	end
	
	if isempty(frdata.freq)
		return
	end
	
	L = 1;
	R = 2;
	REF = 3;	
	
	% plot curves
	figure
	subplot(211)
	hold on
		errorbar(frdata.freq, 1000*frdata.mag(L, :), 1000*frdata.mag_stderr(L, :), 'g');
		errorbar(frdata.freq, 1000*frdata.mag(R, :), 1000*frdata.mag_stderr(R, :), 'r');
		errorbar(frdata.freq, frdata.mag(REF, :), frdata.mag_stderr(REF, :), 'k-.');
	hold off
	ylabel('Magnitude')
	legend('Left (X1000)', 'Right (X1000)', 'Ref');
	title('Calibration Results')
	set(gca, 'XGrid', 'on');
	set(gca, 'YGrid', 'on');
	
	subplot(212)
	hold on
		errorbar(frdata.freq, frdata.phase(L, :), frdata.phase_stderr(L, :), 'g');
		errorbar(frdata.freq, frdata.phase(R, :), frdata.phase_stderr(R, :), 'r');
		errorbar(frdata.freq, frdata.phase(REF, :), frdata.phase_stderr(REF, :), 'k-.');
	hold off
	ylabel('Phase')
	xlabel('Frequency (Hz)')
	legend('Left', 'Right', 'Ref');
	set(gca, 'XGrid', 'on');
	set(gca, 'YGrid', 'on');

	figure
	subplot(211)
	plot(frdata.freq, normalize(frdata.mag(1, :)), 'g.-')
	hold on
		plot(frdata.freq, normalize(frdata.mag(2, :)), 'r.-')
		plot(frdata.freq, normalize(frdata.mag(3, :)), 'k.-')
	hold off
	ylabel('Normalized Magnitude')
	legend('Left', 'Right', 'Ref');
	title('Normalized Frequency Response')
	set(gca, 'XGrid', 'on');
	set(gca, 'YGrid', 'on');
	set(gca, 'Color', .5*[1 1 1]);

	subplot(212)
	plot(frdata.freq, unwrap(frdata.phase(1, :)), 'g.-');
	hold on
		plot(frdata.freq, unwrap(frdata.phase(2, :)), 'r.-');
		plot(frdata.freq, unwrap(frdata.phase(3, :)), 'k.-');
	hold off
	ylabel('Unwrapped Phase')
	xlabel('Frequency (Hz)')
	set(gca, 'XGrid', 'on');
	set(gca, 'YGrid', 'on');
	set(gca, 'Color', .5*[1 1 1]);
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function SettingsSave_Ctrl_Callback(hObject, eventdata, handles)
	% get the settings file name and path
	[settingsfile, settingspath] = uiputfile('*_MCsettings.mat', ...
															'Save settings file...');
														
	% return if user hits CANCEL button (settingsfile == 0)
	if settingsfile == 0
		disp('aborting...');
		return
	end
	
	disp(['Saving data to settings file ' settingsfile])
	% make local copy of cal structure
	cal = handles.cal;
	save(fullfile(settingspath, settingsfile), 'cal', '-MAT');
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function SettingsLoad_Ctrl_Callback(hObject, eventdata, handles)
	% get the settings file name and path
	[settingsfile, settingspath] = uigetfile('*_MCsettings.mat', ...
															'Select settings file...');
	% return if user hits CANCEL button (settingsfile == 0)
	if settingsfile == 0
		return
	end
	
	disp(['Loading data from settings file ' settingsfile])
	load(fullfile(settingspath, settingsfile), '-MAT');
	
	% store calibration struct
	handles.cal = cal;

	% calibration with these settings is incomplete
	handles.CalComplete = 0;
	
	guidata(hObject, handles);

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% update the UI values
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	update_ui_str(handles.AttenuatorCtrl, handles.cal.Atten);
	update_ui_str(handles.FrequencyMinCtrl, handles.cal.Fmin);
	update_ui_str(handles.FrequencyMaxCtrl, handles.cal.Fmax);
	update_ui_str(handles.FrequencyStepCtrl, handles.cal.Fstep);
	update_ui_str(handles.RepetitionsCtrl, handles.cal.Nreps);
	calChanNum = calchannelstr2val(handles.cal.CalChannel);
	update_ui_val(handles.CalChannelCtrl, calChanNum);

	update_ui_str(handles.DAscaleCtrl, handles.cal.DAscale);
	update_ui_str(handles.CalibrationMicSensivityCtrl, handles.cal.CalMic_sense);
	update_ui_str(handles.LMicGainCtrl, handles.cal.Gain_dB(1));
	update_ui_str(handles.RMicGainCtrl, handles.cal.Gain_dB(2));
	update_ui_str(handles.RefMicGainCtrl, handles.cal.Gain_dB(3));
	update_ui_val(handles.FieldTypeCtrl, handles.cal.FieldType);
	update_ui_val(handles.SpeakerChannelCtrl, handles.cal.SpeakerChannel);

	update_ui_val(handles.FieldTypeCtrl, handles.cal.FieldType);
%--------------------------------------------------------------------------

%-------------------------------------------------------------------------
function TDTSettingsMenuCtrl_Callback(hObject, eventdata, handles)
	iodev = handles.iodev;
	fullcircuit = fullfile(iodev.Circuit_Path, [iodev.Circuit_Name '.rcx'])
	if ~exist(fullcircuit, 'file')
		warning('%s: circuit %s not found...', mfilename, fullcircuit)
		[fname, pname] = uigetfile('*.rcx', 'Select TDT RPvD circuit file');
		if fname == 0
			% user cancelled request
			return
		end
		% need to strip off .rcx from filename
		[tmp1, fname, fext, tmp2] = fileparts(fname)
		iodev.Circuit_Name = fname;
		iodev.Circuit_Path = pname;
		handles.iodev = iodev;
		guidata(hObject, handles);
		iodev
		
	else
		[fname, pname] = uigetfile('*.rcx', ...
								'Select TDT RPvD circuit file', ...
								fullcircuit);
		if fname == 0
			% user cancelled request
			return
		end
		% need to strip off .rcx from filename
		[tmp1, fname, fext, tmp2] = fileparts(fname);
		iodev.Circuit_Name = fname;
		iodev.Circuit_Path = pname;
		handles.iodev = iodev;
		guidata(hObject, handles);
		iodev
	end
%-------------------------------------------------------------------------

%-------------------------------------------------------------------------
function SaveDefaults_Ctrl_Callback(hObject, eventdata, handles)
% save defaults
	% first check to see if defaults file exists
	% need to get the path for the mfile for MicrophoneCal
	mpath = mfilename('fullpath')
	defaultsfile = [mpath '_Defaults.mat']

	cal = handles.cal;
	disp(['Saving defaults cal data in file: ' defaultsfile])
	save(defaultsfile, 'cal');
%-------------------------------------------------------------------------


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Calibration Control Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function AttenuatorCtrl_Callback(hObject, eventdata, handles)
	attenuator_value = read_ui_str(hObject, 'n');
	
	if ~between(attenuator_value, 0, 120)
		warndlg('Attenuator value out of range (0-120 dB)', 'MicrophoneCal');
		update_ui_str(hObject, handles.cal.Atten);
	else
		handles.cal.Atten = attenuator_value;
		guidata(hObject, handles);
	end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function FrequencyMinCtrl_Callback(hObject, eventdata, handles)
	freq = read_ui_str(hObject, 'n');
	
	if ~between(freq, 0, handles.cal.Fmax)
		warnstr = sprintf('Min Freq value out of range (0-%d Hz)', handles.cal.Fmax);
		warndlg(warnstr, mfilename);
		update_ui_str(hObject, handles.cal.Fmin);
	else
		handles.cal.Fmin = freq;
		guidata(hObject, handles);
	end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function FrequencyMaxCtrl_Callback(hObject, eventdata, handles)
	freq = read_ui_str(hObject, 'n');
	if ~between(freq, handles.cal.Fmin, 15000)
		warnstr = sprintf('Max Freq value out of range (%d - 15000 Hz)', handles.cal.Fmin);
		warndlg(warnstr, mfilename);
		update_ui_str(hObject, handles.cal.Fmax);
	else
		handles.cal.Fmax = freq;
		guidata(hObject, handles);
	end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function FrequencyStepCtrl_Callback(hObject, eventdata, handles)
	freq = read_ui_str(hObject, 'n');
	if ~between(freq, 1, handles.cal.Fmax)
		warnstr = sprintf('Freq Step value out of range (1 - %d Hz)', handles.cal.Fmax);
		warndlg(warnstr, mfilename);
		update_ui_str(hObject, handles.cal.Fstep);
	else
		handles.cal.Fstep = freq;
		guidata(hObject, handles);
	end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function RepetitionsCtrl_Callback(hObject, eventdata, handles)
	reps = read_ui_str(hObject, 'n');
	if ~between(reps, 1, 100)
		warnstr = sprintf('Reps value out of range (1 - 100)');
		warndlg(warnstr, mfilename);
		update_ui_str(hObject, handles.cal.Nreps);
	else
		handles.cal.Nreps = reps;
		guidata(hObject, handles);
	end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function CalChannelCtrl_Callback(hObject, eventdata, handles)
	CalChannelStr = 'LRBT';
	handles.cal.CalChannel = CalChannelStr(read_ui_val(handles.CalChannelCtrl));
	guidata(hObject, handles);
%--------------------------------------------------------------------------

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Microphone Control Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function DAscaleCtrl_Callback(hObject, eventdata, handles)
	aValue = read_ui_str(hObject, 'n');
	if ~between(aValue, 1, 100)
		warnstr = sprintf('DAscale value out of range (0 - 10)');
		warndlg(warnstr, mfilename);
		update_ui_str(hObject, handles.cal.DAscale);
	else
		handles.cal.DAscale = aValue;
		guidata(hObject, handles);
	end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function CalibrationMicSensivityCtrl_Callback(hObject, eventdata, handles)
	aValue = read_ui_str(hObject, 'n');
	if ~between(aValue, 0, 20)
		warnstr = sprintf('Calibration Mic Sensitivity value out of range (0 - 20)');
		warndlg(warnstr, mfilename);
		update_ui_str(hObject, handles.cal.CalMic_sense);
	else
		handles.cal.CalMic_sense = aValue;
		guidata(hObject, handles);
	end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function LMicGainCtrl_Callback(hObject, eventdata, handles)
	aValue = read_ui_str(hObject, 'n');
	if ~between(aValue, 0, 100)
		warnstr = sprintf('L Mic Gain value out of range (0 - 100)');
		warndlg(warnstr, mfilename);
		update_ui_str(hObject, handles.cal.Gain_dB(1));
	else
		handles.cal.Gain_dB(1) = aValue;
		guidata(hObject, handles);
	end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function RMicGainCtrl_Callback(hObject, eventdata, handles)
	aValue = read_ui_str(hObject, 'n');
	if ~between(aValue, 0, 100)
		warnstr = sprintf('R Mic Gain value out of range (0 - 100)');
		warndlg(warnstr, mfilename);
		update_ui_str(hObject, handles.cal.Gain_dB(2));
	else
		handles.cal.Gain_dB(2) = aValue;
		guidata(hObject, handles);
	end
%--------------------------------------------------------------------------
	
%--------------------------------------------------------------------------
function RefMicGainCtrl_Callback(hObject, eventdata, handles)
	aValue = read_ui_str(hObject, 'n');
	if ~between(aValue, 0, 100)
		warnstr = sprintf('Ref Mic Gain value out of range (0 - 100)');
		warndlg(warnstr, mfilename);
		update_ui_str(hObject, handles.cal.Gain_dB(3));
	else
		handles.cal.Gain_dB(3) = aValue;
		guidata(hObject, handles);
	end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function FieldTypeCtrl_Callback(hObject, eventdata, handles)
	handles.cal.FieldType = read_ui_val(handles.FieldTypeCtrl);
	guidata(hObject, handles);
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function SpeakerChannelCtrl_Callback(hObject, eventdata, handles)
	handles.cal.SpeakerChannel = read_ui_val(handles.SpeakerChannelCtrl);
	guidata(hObject, handles);
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function FreqVal_Callback(hObject, eventdata, handles)
function RefVal_Callback(hObject, eventdata, handles)
function RefSPL_Callback(hObject, eventdata, handles)
function LVal_Callback(hObject, eventdata, handles)
function LSPL_Callback(hObject, eventdata, handles)
function RVal_Callback(hObject, eventdata, handles)
function RSPL_Callback(hObject, eventdata, handles)
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function HiPassFcCtrl_Callback(hObject, eventdata, handles)
	% limits for HiPass Fc are [1 LowPass]
	lim = [1 handles.cal.LoPassFc];
	% check values and update
	handles.cal.HiPassFc = editbox_update(handles.HiPassFcCtrl, ...
											lim, ...
											handles.cal.HiPassFc);
	guidata(hObject, handles);
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function LoPassFcCtrl_Callback(hObject, eventdata, handles)
	% limits for LoPassFc are [HiPassFc Fs/2]
	lim = [handles.cal.HiPassFc handles.iodev.Fs/2];
	% check values and update
	handles.cal.LoPassFc = editbox_update(handles.LoPassFcCtrl, ...
											lim, ...
											handles.cal.LoPassFc);
	guidata(hObject, handles);
%
%--------------------------------------------------------------------------


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% --- Executes during object creation, after setting all properties.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%--------------------------------------------------------------------------
function RefVal_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		set(hObject,'BackgroundColor','white');
	end
function RefSPL_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		set(hObject,'BackgroundColor','white');
	end
function FreqVal_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		set(hObject,'BackgroundColor','white');
	end
function LVal_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		set(hObject,'BackgroundColor','white');
	end
function LSPL_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		set(hObject,'BackgroundColor','white');
	end
function RVal_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		set(hObject,'BackgroundColor','white');
	end
function RSPL_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		set(hObject,'BackgroundColor','white');
	end
function AttenuatorCtrl_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		 set(hObject,'BackgroundColor','white');
	end
function FrequencyMinCtrl_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		 set(hObject,'BackgroundColor','white');
	end
function FrequencyMaxCtrl_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		 set(hObject,'BackgroundColor','white');
	end
function FrequencyStepCtrl_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		 set(hObject,'BackgroundColor','white');
	end
function RepetitionsCtrl_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		 set(hObject,'BackgroundColor','white');
	end
function DAscaleCtrl_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		 set(hObject,'BackgroundColor','white');
	end
function CalibrationMicSensivityCtrl_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		 set(hObject,'BackgroundColor','white');
	end
function LMicGainCtrl_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		 set(hObject,'BackgroundColor','white');
	end
function RMicGainCtrl_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		 set(hObject,'BackgroundColor','white');
	end
function RefMicGainCtrl_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		 set(hObject,'BackgroundColor','white');
	end
function FieldTypeCtrl_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		 set(hObject,'BackgroundColor','white');
	end
function SpeakerChannelCtrl_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		 set(hObject,'BackgroundColor','white');
	end
function CalChannelCtrl_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
		 set(hObject,'BackgroundColor','white');
	end
function HiPassFcCtrl_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
	    set(hObject,'BackgroundColor','white');
	end
function LoPassFcCtrl_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
	    set(hObject,'BackgroundColor','white');
	end
%--------------------------------------------------------------------------
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Utilities
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%--------------------------------------------------------------------------
function aNum = calchannelstr2val(aStr)
	% load constants
	Tytoconstants;

	% return number to correspond to channel string
	[tmp, aNum] = find(aStr == CALCHANNELSTR);
%--------------------------------------------------------------------------
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

	





