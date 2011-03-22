%--------------------------------------------------------------------------
% MicrophoneCal_settings.m
%--------------------------------------------------------------------------
%
%	Edit this file to set frequency range, amplitude, etc
%	for calibrating the earphone microphones with a reference
%	(e.g., Bruel & Kjaer / B&K) microphone
%
%--------------------------------------------------------------------------
% cal fields:
% 
%              Atten: (dbl)		attenuator setting (dB)
%               Fmin: (dbl)		min frequency (Hz)
%              Fstep: (dbl)		frequency step (Hz)
% 				    Fmax: (dbl)		max frequency (Hz)
%              Nreps: (dbl)		# reps per freq.
%            DAscale: (dbl)		output voltage scale factor (V)
%            Gain_dB: (1X3 dbl)	input microphone gain (db), (Left, Right, Ref)
%       CalMic_sense: (dbl)		Reference Microphone Sensitivity (Pascal/Volts)
%           Interval: (dbl)		stimulue interval (seconds)
%               Gain: (1X3 dbl)	input microphone gain mult. factor (L, R, Ref)
%              VtoPa: (dbl)		Reference Microphone Volts to Pascal conv. factor
%       StimInterval: (dbl)		Stimulus interval (msec)
%       StimDuration: (dbl)		Stimulus duration (msec)
%      SweepDuration: (dbl)		Stimulus sweep duration (msec)
%          StimDelay: (dbl)		Stimulus delay (msec)
%        AcqDuration: (dbl)		Acquisition time (msec)
%        SweepPeriod: (dbl)		total sweep period (msec)
%           StimRamp: (dbl)		calibration stimulus ramp on/off time (msec)
%           TestRamp: (dbl)		test stimulus ramp on/off time (msec)
%            SPLRamp: (dbl)		SPL test stimulus ramp on/off time (msec)
%        InputFilter: (dbl)		Input hi-pass filter (TDT) on (1) off (0)
%            InputFc: (dbl)		Input hi-pass filter freq. (Hz)
%        TTLPulseDur: (dbl)		TTL sync pulse duration (msec)
%     SpeakerChannel: (dbl)		output speaker channel
%          FieldType: (dbl)		calibration condition, 1 = free field, 2 = pressure field
%             bkdata: [struct]	B&K microphone information
%              timer: (dbl)		time duration (seconds) for calibration
%         CalChannel: (str)		channel being calibrated (L, R, BOTH)
%          Nchannels: (dbl)		# of input channels
%       Ncalchannels: (dbl)		# of channels for calibration
%       CalChannelID: (dbl)		channels that are being calibrated [1 3]
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
% Sharad Shanbhag
% sshanbha@aecom.yu.edu
%--------------------------------------------------------------------------
% Revisions:
%
%	5 Feb 2008:	Created from FFCal_settings.m
%
%	26 January, 2009 (SJS)
% 		-	revised GUI to allow user to change parameters
% 		-	modified MicrophoneCal_settings and
%			MicrophoneCal_frdata_init to account for changes
%	19 June, 2009 (SJS):
% 		-	added documentation
%	3 September, 2009 (SJS): 
%		-	updated code to use newer matlab call to
%			ActiveX (no more invoke())
%	3 Nov, 2010 (SJS):
% 		-	moved iodev struct into handles, values initially
% 			set in MicrophoneCal_OpeningFcn()
%		-	added comments
%--------------------------------------------------------------------------

disp('...general setup starting...');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% general constants
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% channel mnemonics
	L = 1;
	R = 2;
	REF = 3;
	% maximum possible attenuator value (dB)
	MAX_ATTEN = 120;
	% clipping value (Volts)
	CLIPVAL = 10;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% make local copy of iodev TDT structure
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	iodev = handles.iodev;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Calibration Settings
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 	% # repetitions at each frequency
 	Nreps = cal.Nreps;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% set global calibration settings
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% deciFactor only used for plotting
	deciFactor = 5;
	% InterStimInterval (seconds)
	cal.Interval = 0.1;
	% convert gain on the mic preamp in dB to gain factor
	Gain = 10.^(cal.Gain_dB./20);
	cal.Gain = 10.^(cal.Gain_dB./20);
	% pre-compute the V -> Pa conversion factor using the 
	% microphone sensitivity settings
	VtoPa = (cal.CalMic_sense^-1);
	cal.VtoPa = VtoPa;
	% pre-compute the sinusoid RMS factor
	RMSsin = 1/sqrt(2);
	% set the attenuator values	
	if cal.SpeakerChannel == L
		Latten = cal.Atten;
		Ratten = MAX_ATTEN;
	else
		Latten = MAX_ATTEN;
		Ratten = cal.Atten;
	end
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% set the stimulus/acquisition settings
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%	
	% set up the calibration frequency range
	Freqs = cal.Fmin:cal.Fstep:cal.Fmax;
	F = [cal.Fmin cal.Fstep cal.Fmax];
	Nfreqs = length(Freqs);

	% set the # of calibration channels and channel ID string
	switch cal.CalChannel
		% calibrate both channels (L and R)
		case 'B'
			Ncalchannels = 3;
			CalChannelID = [L R REF];
		% calibrate L channel only
		case 'L'
			Ncalchannels = 2;
			CalChannelID = [L REF];
		% calibrate R channel only
		case 'R'
			Ncalchannels = 2;
			CalChannelID = [R REF];
		% measure transfer function of speaker, using ref mic
		case 'T'
			Ncalchannels = 1;
			CalChannelID = REF;
	end
	Nchannels = 3;
	cal.Nchannels = Nchannels;
	cal.Ncalchannels = Ncalchannels;
	cal.CalChannelID = CalChannelID;

	% Stimulus Interval (ms)
	cal.StimInterval = 0;
	% Stimulus Duration (ms)
	cal.StimDuration = 150;
	% Duration of epoch (ms)
	cal.SweepDuration = 200;
	% Delay of stimulus (ms)
	cal.StimDelay = 10;
	% Total time to acquire data (ms)
	cal.AcqDuration = cal.SweepDuration;
	% Total sweep time = sweep duration + inter stimulus interval (ms)
	cal.SweepPeriod = cal.SweepDuration + cal.StimInterval;
	% Stimulus ramp on/off time
	cal.StimRamp = 5;
	cal.TestRamp = 5;
	cal.SPLRamp = 1;

	
	%Input Filter Fc
	cal.InputFilter = 1;
% 	cal.HiPassFc = 60;
% 	cal.LoPassFc = 16000;
	%TTL pulse duration (msec)
	cal.TTLPulseDur = 1;

% Added front panel control for this for more flexibility
% 4/16/09, SJS
% 	cal.SpeakerChannel = L;

	
