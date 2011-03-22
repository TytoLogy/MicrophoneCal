%--------------------------------------------------------------------------
% MicrophoneCal_RunCalibration.m
%--------------------------------------------------------------------------
%  Script that runs the calibration protocol
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
% Sharad Shanbhag
% sshanbha@aecom.yu.edu
%--------------------------------------------------------------------------
% Created:	23 January, 2009	SJS
% 				Moving all RunCalibration_ctrl_Callback() operations
% 				to here so that it's easier to track and catalog 
% 				changes to the code.
%
% Revisions:
%
%	26 January, 2009 (SJS)
% 		-	revised GUI to allow user to change parameters
% 		-	modified MicrophoneCal_settings and
%			MicrophoneCal_frdata_init to account for changes
%		-	made changes so that ABORT button actually does something (works?)
%	19 June, 2009 (SJS): 
%		-	updated documentation
%		-	ran Mlint profiler, corrections made
%--------------------------------------------------------------------------

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set some things...
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% make a local copy of the cal settings structure
	cal = handles.cal;
	
	% set the COMPLETE flag to 0
	COMPLETE = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initialization Scripts
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Load the settings and constants for FFcal 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	MicrophoneCal_settings;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Start the TDT circuits
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	MicrophoneCal_tdtinit;
	handles.iodev = iodev;
	guidata(hObject, handles);		
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% setup storage variables
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	MicrophoneCal_frdata_init;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Read in the BK mic xfer function for pressure field 
% and get correction values for use with the free field mic
% If free-field, set correction factor to 1
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%	
	if cal.FieldType == 2
		% interpolate to get values at desired freqs (data in dB)
		frdata.bkpressureadj = interp1(cal.bkdata.Response(:, 1), cal.bkdata.Response(:, 2), Freqs);
		% convert to factor
		frdata.bkpressureadj = 1./invdb(frdata.bkpressureadj);
	else
		frdata.bkpressureadj = ones(size(Freqs));
	end
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% set the start and end bins for the calibration
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	start_bin = ms2bin(cal.StimDelay + 2*cal.StimRamp, iodev.Fs);
	if ~start_bin
		start_bin = 1;
	end
	end_bin = start_bin + ms2bin(cal.StimDuration-cal.StimRamp, iodev.Fs);
	zerostim = syn_null(cal.StimDuration, iodev.Fs, 1);
	acqpts = ms2bin(cal.AcqDuration, iodev.Fs);
	outpts = length(zerostim);
	% time vector for plots
	dt = 1/iodev.Fs;
	tvec = 1000*dt*(0:(acqpts-1));
	stim_start = ms2bin(cal.StimDelay, iodev.Fs);
	stim_end = stim_start + outpts - 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Store the plot handles as an array that corresponds
% to the L, R and REF channels
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	respPlotHandles = [handles.Lmicplot handles.Rmicplot handles.REFmicplot];
	respPlotLineSpecs = {'g-', 'r-', 'k-'};
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% First, get the background noise level
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% plot the array
	axes(handles.stim_plot);
	plot(zerostim(cal.SpeakerChannel, :), 'b');

	PA5setatten(PA5L, MAX_ATTEN);
	PA5setatten(PA5R, MAX_ATTEN);

	% pre-allocate the background data cell array
	background = cell(1, Nchannels);
	for c = 1:Nchannels
		background{c} = zeros(1, Nreps);
	end
	
	% pause to let things settle down
	disp([mfilename ': collecting background data']);
	pause(1);
	
	for rep = 1:Nreps
		update_ui_str(handles.FreqVal, 'Backgnd');
		% play the "sound"
		[resp, rate] = headphonecal_io(iodev, zerostim, acqpts);
		% plot responses
		for p = 1:Ncalchannels
			ChannelID = CalChannelID(p);

			axes(respPlotHandles(ChannelID));
			
			plot(resp{ChannelID}, respPlotLineSpecs{ChannelID});
		end
		
		% determine the magnitude and phase of the response
		for n = 1:Ncalchannels
			c = CalChannelID(n);
			background{c}(rep) = rms(resp{c}) / Gain(c);
		end
		
		update_ui_str(handles.RefVal, sprintf('%.2f', background{REF}(rep)));
		
		% compute dB SPL
		background{REF}(rep) = dbspl(VtoPa*background{REF}(rep));
		update_ui_str(handles.RefSPL, sprintf('%.2f', background{REF}(rep)));

		% store the response data
		rawdata.background{rep} = cell2mat(resp');
		
		pause(cal.Interval);
	end
	
	for n = 1:Ncalchannels
		c = CalChannelID(n);
		frdata.background(c, 1) = mean( background{c} );
		frdata.background(c, 2) = std( background{c} );
	end
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Now initiate sweeps
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	PA5setatten(PA5L, Latten);		% this is the speaker channel
	PA5setatten(PA5R, Ratten);		% this is unused so max the atten

	if cal.SpeakerChannel == L
		toneChannel = 'L';
	else
		toneChannel = 'R';
	end
	
	% PAUSE	
	disp([mfilename ': now running calibration...']);
	pause(1)
	
	% pre-allocate some data cell arrays
	
	mags = cell(1, Nchannels);
	for c = 1:Nchannels
		mags{c} = zeros(Nfreqs, Nreps);
	end
	phis = mags; 
	dists = mags;
	
	tic
	handles.STOP_FLG = 0;	
	rep = 1;
	freq_index = 1;
	%*******************************LOOP through the frequencies
	while ~handles.STOP_FLG && freq_index <= Nfreqs
		% get the current frequency
		freq = Freqs(freq_index);

		% tell user what frequency is being played
		set(handles.FreqVal, 'String', sprintf('%d', freq));
		
		% synthesize and scale the sine wave;
		[S, stimspec.RMS, stimspec.phi] = syn_calibrationtone(cal.StimDuration, iodev.Fs, freq, 0, toneChannel);
		S = cal.DAscale*S;

		% apply the sin^2 amplitude envelope eliminate
		% transients in the stimulus
		S = sin2array(S, cal.StimRamp, iodev.Fs);

		% plot the array
		axes(handles.stim_plot);
		plot(S(cal.SpeakerChannel, :), 'b');

		% now, collect the data for frequency FREQ
		for rep = 1:Nreps
			% play the sound;
% 			[resp, rate] = headphonecal_io(iodev, S, acqpts);
			[resp, rate] = handles.iofunction(iodev, S, acqpts);
			% determine the magnitude and phase of the response
			[lmag, lphi] = fitsinvec(resp{L}(start_bin:end_bin), 1, iodev.Fs, freq);
			[rmag, rphi] = fitsinvec(resp{R}(start_bin:end_bin), 1, iodev.Fs, freq);
			[refmag, refphi] = fitsinvec(resp{REF}(start_bin:end_bin), 1, iodev.Fs, freq);
			[ldistmag, ldistphi] = fitsinvec(resp{L}(start_bin:end_bin), 1, iodev.Fs, 2*freq);				
			[rdistmag, rdistphi] = fitsinvec(resp{R}(start_bin:end_bin), 1, iodev.Fs, 2*freq);				
			[refdistmag, refdistphi] = fitsinvec(resp{REF}(start_bin:end_bin), 1, iodev.Fs, 2*freq);			

			% compute 2nd harmonic distortion ratio
			dists{L}(freq_index, rep) = ldistmag / lmag;
			dists{R}(freq_index, rep) = rdistmag / rmag;
			dists{REF}(freq_index, rep) = refdistmag / refmag;

			% adjust for the gain of the preamp and convert to RMS
			lmag = RMSsin * lmag / Gain(L);
			rmag = RMSsin * rmag / Gain(R);
			
			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			% DEBUGGING
			% frdata.refmag(freq_index, rep) = refmag;
			% frdata.RMSsin(freq_index, rep) = RMSsin;
			% frdata.GainRef(freq_index, rep) = Gain(REF);
			% frdata.adjfactor(freq_index, rep) =  frdata.bkpressureadj(freq_index);
			% frdata.rawmags(freq_index, rep) =  RMSsin * refmag / Gain(REF);
			% frdata.adjmags(freq_index, rep) = RMSsin * frdata.bkpressureadj(freq_index) * refmag  ./ Gain(REF);
			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			
			% adjust REFerence mic for gain, adjust for free-field or 
			% pressure-field, and convert to RMS
			refmag = RMSsin * refmag * frdata.bkpressureadj(freq_index) ./ Gain(REF);

			% store the data in arrays
			mags{L}(freq_index, rep) = lmag;
			mags{R}(freq_index, rep) = rmag;
			mags{REF}(freq_index, rep) = refmag;
			phis{L}(freq_index, rep) = lphi;
			phis{R}(freq_index, rep) = rphi;
			phis{REF}(freq_index, rep) = refphi;

			% plot the response
			axes(handles.REFmicplot);	plot(resp{REF}, 'k');
			axes(handles.Lmicplot);		plot(tvec, resp{L}, 'g');
			axes(handles.Rmicplot);		plot(tvec, resp{R}, 'r');

			set(handles.RefVal, 'String', sprintf('%.2f', 1000*refmag));
			set(handles.RefSPL, 'String', sprintf('%.2f', dbspl(VtoPa*refmag)));
			set(handles.LVal, 'String', sprintf('%.2f', 1000*lmag));
			set(handles.RVal, 'String', sprintf('%.2f', 1000*rmag));
			
			% Check for possible clipping (values > 10V for TDT SysIII)
			for channel = 1:Nchannels
				if max(resp{channel}) >= CLIPVAL
					handles.STOP_FLG = channel;
				end
			end
			
			% store the raw response data
			rawdata.resp{freq_index, rep} = cell2mat(resp');

			pause(cal.Interval);
		end

		% compute the averages for this frequency
		for channel = 1:Nchannels
			frdata.mag(channel, freq_index) = mean( mags{channel}(freq_index, :) );
			frdata.mag_stderr(channel, freq_index) = std( mags{channel}(freq_index, :) );
			frdata.phase(channel, freq_index) = mean( unwrap(phis{channel}(freq_index, :)) );
			frdata.phase_stderr(channel, freq_index) = std( unwrap(phis{channel}(freq_index, :)) );
			frdata.dist(channel, freq_index) = mean( dists{channel}(freq_index, :) );
		end
		
		% increment frequency index counter
		freq_index = freq_index + 1;

		% check if user pressed ABORT button or if STOP_FLG is set
		if handles.STOP_FLG
			disp('STOP_FLG detected')
			cal.timer = toc;
			break;
		end
		if read_ui_val(handles.AbortCtrl) == 1
			disp('abortion detected')
			cal.timer = toc;
			break
		end
	end %********************End of Cal loop

	% get the time
	cal.timer = toc;

	if handles.STOP_FLG
		errstr = sprintf('Possible clip on channel %d', handles.STOP_FLG);
		errordlg(errstr, 'Clip alert!');
	end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Exit gracefully (close TDT objects, etc)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	MicrophoneCal_tdtexit;
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% check if we made it to the end of the frequencies
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	if freq == F(3)
		% if yes, complete
		COMPLETE = 1;
	else
		% if not, incomplete, skip the calculations and
		% return
		COMPLETE = 0;
		handles.frdata = frdata;
		handles.rawdata = rawdata;
		return
	end
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% data are complete, do some computations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% microphone adjust factors are:
	% 	magnitude adj = knowles mic Vrms / Ref mic Vrms
	% 	phase adj = Knowls mic deg - ref mic radians

	% compute L and R magnitude correction
	frdata.ladjmag = frdata.mag(L, :) ./ frdata.mag(REF, :);
	frdata.radjmag = frdata.mag(R, :) ./ frdata.mag(REF, :);
	
	% compute L and R phase correction
	frdata.ladjphi = frdata.phase(L, :) - frdata.phase(REF, :);
	frdata.radjphi = frdata.phase(R, :) - frdata.phase(REF, :);
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save handles and data and temp file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	handles.frdata = frdata;
	handles.rawdata = rawdata;
	handles.cal = cal;
	guidata(hObject, handles);
	
	[filename, pathname] = uiputfile('*_fr.mat', 'Save FR Data');
	if filename
		frfilename = fullfile(pathname, filename);
		save(frfilename, 'frdata', 'cal', '-mat');
		save([date '_fr.mat'], 'frdata', 'cal', '-mat');
	else
		save([date '_fr.mat'], 'frdata', 'cal', '-mat');
	end
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% plot curves
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% average data (non-normalized)
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
	subplot(212)
	hold on
		errorbar(frdata.freq, frdata.phase(L, :), frdata.phase_stderr(L, :), 'g');
		errorbar(frdata.freq, frdata.phase(R, :), frdata.phase_stderr(R, :), 'r');
		errorbar(frdata.freq, frdata.phase(REF, :), frdata.phase_stderr(REF, :), 'k-.');
	hold off
	ylabel('Phase')
	xlabel('Frequency (Hz)')
	legend('Left', 'Right', 'Ref');

	% Normalized data plot	
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
	
	
	% plotfr
	PlotFR(frdata)
	
	