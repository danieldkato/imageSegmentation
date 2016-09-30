% Last updated DDK 2016-09-27

% OVERVIEW
% Use this script to identify the frame numbers during which trials begin
% over the course of a grab, along with the types of those trials. 

% REQUIREMENTS
% 1) The MATLAB function readContinuousDAT, available at https://github.com/gpierce5/BehaviorAnalysis/blob/master/readContinuousDAT.m (commit 71b3a3c)
% 2) The MATLAB function LocalMinima, available at \\hsbruno05\Users\dan\Documents\MATLAB\clay\LocalMinima.m
% 3) The MATLAB function read_ardulines, available at


%%
function [trialStartFrames, trialTypes, trialMatrix] = trial_registration(galvoPath, timerPath, ardulines, showInflectionPoints)
    
    if nargin<4
        showInflectionPoints = 0;
    end
    
    galvoTrace = readContinuousDAT(galvoPath); % Load the galvanometer data from the raw .dat file into an s x 1 vector, where s is number of samples taken during grab 
    timerTrace = readContinuousDAT(timerPath); % Load the trial timer data from the raw .dat file into an s x 1 vector, where s is the number of samples taken during a grab

    %% Find when every frame starts (in terms of sample index)
    
    % Get every sample index in galvoTrace corresponding to the onset of a
    % new frame; these can be found by finding local minima in the
    % galvanometer trace (the bottom of the sawtooth pattern of
    % galvanometer trace corresponds to the beginnig of a new frame):
    
    frameRate = 3.37; % Frames per second; this is a constant for now, but I should think about how to make this get the frame rate at runtime
    framePeriod = 1/frameRate;
    sampleRate = 16000; % Samples per second; Also a constant for now, but I should think about how to make this get the sample rate at runtime
    minDistanceGalvo = framePeriod * sampleRate; % The function LocalMinima will include only the lowest of any local minima found within this many samples of each other
    galvoThreshold = -1.8; % Whatever units gavloTrace is expressed in (Volts, I think); the function LocalMinima will exclude any local minima higher than this value; for the time being, I just got this from eyeballing a sample galvo trace, but I may ultimately need more sophisticated ways of getting this if there's any variability
    
    frameOnsetSamples = LocalMinima(galvoTrace, minDistanceGalvo, galvoThreshold); %returns a vector of indices into the input trace
    
    % Plot the local minima on top the galvo trace if desired; this can be
    % handy just to double check that reasonable parameters for LocalMinima
    % have been chosen, but may be cumbersome if processing large batches
    % of data
    
    if showInflectionPoints == 1
        figure;
        plot(galvoTrace);
        hold on;
        t = (1:1:length(galvoTrace));
        plot(t(frameOnsetSamples), galvoTrace(frameOnsetSamples), 'r.');
    end 
    
    
    %% Find when every trial starts (in terms of sample index)
    
    % Get every sample index in timerTrace corresponding to the onset of a
    % new trial; trial onsets are indicated by local maxima, so run
    % LocalMinima on -trialTrace:
    
    minITI = 3; % Seconds; again, it would be better if there were a way to do this dynamically
    minDistanceTimer = minITI * sampleRate;
    timerThreshold = -4; % timerTrace units (Volts, I think); again, should think of a way to get this dynamically
    trialOnsetSamples = LocalMinima(-timerTrace, minDistanceTimer, timerThreshold);
    
    if showInflectionPoints == 1
        plot(timerTrace);
        plot(t(trialOnsetSamples), timerTrace(trialOnsetSamples), 'r.'); 
    end
    
    
    %% Omit any trials delivered before the first frame or after the last frame
    trialOnsetSamples = trialOnsetSamples( trialOnsetSamples>=min(frameOnsetSamples) & trialOnsetSamples<=max(frameOnsetSamples) );
    
    
    
    %% Match every trial to the frame within which it started
    trialStartFrames = cell(length(trialOnsetSamples), 1);
    
    % For each trial onset sample number, find the highest frame onset
    % sample number below it
    for i = 1:length(trialStartFrames)
        [M, I] = max(frameOnsetSamples( frameOnsetSamples <= trialOnsetSamples(i) ));
        trialStartFrames{i} = I;
    end
    
    %% Get an ordered list of trial types from arudlines
    trialTypes = read_ardulines(ardulines);

    %% Merge trialStartFrames with trialTypes
    trialMatrix = cell(length(trialOnsetSamples), 2);
    trialMatrix(:, 1) = trialStartFrames;
    trialMatrix(:, 2) = trialTypes; 
    
    %csvwrite('trialMatrix.csv', trialMatrix);
    dlmwrite('test.csv', trialMatrix(:,:));
    
    % Write trialMatrix to a .csv 
end