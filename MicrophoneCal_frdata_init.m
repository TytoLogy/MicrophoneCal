%--------------------------------------------------------------------------
% MicrophoneCal_frdata_init.m
%--------------------------------------------------------------------------
%	Script to initialize/allocate frdata structure that holds the microphone
%	frequency response calibration data for the earphone microphones
%--------------------------------------------------------------------------
% Data Format:
% 
% 	frdata fields: 
% 	
% 			FIELD       FMT		   DESCRIPTION	
%          time_str: (str)			date and time of data collection
%         timestamp: (dbl)			matlab timestamp at start of data acq.
%              adFc: (dbl)			analog-digital conversion rate for data
%              daFc: (dbl)			digital-analog conversion rate for signals
%          nrasters: (dbl)			# of frequencies tested
%             range: [1X3 dbl]		array of Fmin Fstep Fmax freqs
%              reps: (dbl)			# of reps at each frequency
%       calsettings: (struct)		calibration settings structure (see MicrophoneCal_settings.m)
%             atten: (dbl)			attenuator setting, dB
%           max_spl: (dbl)			maximum dB SPL level
%           min_spl: (dbl)			minimum dB SPL signal level
% 			 DAscale: (dbl)			scaling factor for output signal in Volts
%              freq: [1x473 dbl]	frequencies
%               mag: [3x473 dbl]	magnitude data, (Left Vrms, Right Vrms, Ref VRMS)
%             phase: [3x473 dbl]	phase data (degrees)
%              dist: [3x473 dbl]	mag. distortion data (2nd harmonic)
%        mag_stderr: [3x473 dbl]	magnitude std. error.
%      phase_stderr: [3x473 dbl]	phase std. error
%        background: [3x2 dbl]	Background RMS level, Volts, (L, R, Ref channels)
%     bkpressureadj: [1x473 dbl]	ref. mic correction factor for pressure field measurements
%           ladjmag: [1x473 dbl]	L channel microphone magnitude correction factor (Vrms/Pascal_rms)
%           radjmag: [1x473 dbl]	R channel microphone magnitude correction factor (Vrms/Pascal_rms)
%           ladjphi: [1x473 dbl]	L channel microphone phase correction factor (deg)
%           radjphi: [1x473 dbl]	R channel microphone phase correction factor (deg)
% 
% 		microphone adjust factors are:
% 			magnitude adj = knowles mic Vrms / Ref mic Vrms
% 			phase adj = Knowls mic deg - ref mic degrees
% 
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
% Sharad Shanbhag
% sshanbha@aecom.yu.edu
%--------------------------------------------------------------------------
% Revisions:
%
% 5 Feb 2008:	Created from FFCal_settings.m
% 
% 23 January, 2009 (SJS):	
% 		-	changed caldata to frdata to avoid confusion with caldata from 
% 			HeadphoneCal
%		-	renamed file from MicrophoneCal_caldata.m to 
%			MicrophoneCal_frdata_init.m to more
%			clearly indicate function of script.
%	26 January, 2009 (SJS)
% 		-	revised GUI to allow user to change parameters
% 		-	modified MicrophoneCal_settings and
%			MicrophoneCal_frdata_init to account for changes
%	19 June, 2009 (SJS):
% 		-	added documentation
%--------------------------------------------------------------------------

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Setup data storage variables and paths
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	frdata.time_str = datestr(now, 31);		% date and time
	frdata.timestamp = now;						% timestamp
	frdata.adFc = iodev.Fs;						% analog input rate
	frdata.daFc = iodev.Fs;						% analog output rate
	frdata.nrasters = Nfreqs;					% number of freqs to collect
	frdata.range = F;								% freq range (matlab string)
	frdata.reps = Nreps;							% reps per frequency
	frdata.calsettings = cal;					% parameters for calibration session
	frdata.atten = cal.Atten;					% initial attenuator setting
	frdata.max_spl = 0;							% maximum spl (will be determined in program)
	frdata.min_spl = 0;							% minimum spl (will be determined in program)
	frdata.DAscale = cal.DAscale;				% output peak voltage level

	% set up the arrays to hold the data
	tmp = zeros(Nfreqs, Nreps);
	tmpcell = cell(Nchannels, 1);
	background = tmpcell;
	for i=1:Nchannels
		tmpcell{i} = tmp;
		background{i} = zeros(1, Nreps);
	end
	mags = tmpcell;
	phis = tmpcell;
	dists = tmpcell;
	
	%initialize the frdata structure arrays for the calibration data
	tmpcell = cell(Nchannels, Nfreqs);
	tmparr = zeros(Nchannels, Nfreqs);
	frdata.freq = Freqs;
	frdata.mag = tmparr;
	frdata.phase = tmparr;
	frdata.dist = tmparr;
	frdata.mag_stderr = tmparr;
	frdata.phase_stderr = tmparr;
	frdata.background = zeros(Nchannels, 2);
	if cal.FieldType == 2
		frdata.rawmags = tmp;
	end

	% setup cell for raw data 
	rawdata.background = cell(Nreps, 1);
	rawdata.resp = cell(Nfreqs, Nreps);
	rawdata.Freqs = Freqs;
