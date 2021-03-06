 function [r, sse] = check_zdrift(path)

% DOCUMENTATION TOC:
% I. OVERVIEW
% II. REQUIREMENTS
% III. USAGE
% IV. INPUTS
% V. OUTPUTS

% Last updated DDK 2018-01-29


%% I. OVERVIEW
% This function provides a metric of how much focal plane drift has
% occurred over the course of a movie. 

% It does this by taking the 2-D correlation coefficient between the
% average of the first 1000 frames and the average of the last 1000
% frames. In order to control for any differences that might arise from X-Y
% translations, it first registers the images with the optimal 2D affine
% transformation before computing the correlation coefficient.


%% II. REQUIREMENTS
% 1) write_metadata.m, available at https://github.com/danieldkato/utilities/blob/master/metadata/MATLAB/write_metadata.m.
% 2) get_sha1.m
% 3) getLastCommit.m
% 4) reg_and_warp.m
% 5) extract_frames.m


%% III. USAGE
% This function can be called form within another MATLAB script or from the
% MATLAB command window. Alternatively, it can be invoked directly from the
% command line as follows:

% matlab -nodisplay -nosplash -r "check_zdrift <path\to\movie>"

% where <path\to\movie> stands for the path to the movie to be analyzed.


%% IV. INPUTS
% 1) path - path to a movie saved as a multi-page TIFF.


%% V. OUTPUTS
% 1) r - 2D correlation coefficient between the average of the first 1000
% frames and the average of the last 1000 frames of the input movie. Note
% that the average of the last 1000 frames has been registered to the
% average of the first 1000 frames using the optimal 2D affine
% transformation to eliminate any differences due to X-Y translation.

% In addition to formally returning r, this function saves the following to
% secondary storage:

% 1) D - a MATLAB struct with the following fields:
%   a) r - 2D correlation coefficient between the average of the first
%   1000 frames and the registered average of the last 1000 frames.

%   b) beginning - m x n matrix containing the mean image of the first 1000
%   frames of the input movie, where m and n are the movie height and
%   width, respectively. The gray values have been adjusted to maximize the
%   dynamic range.

%   c) end - m x n matrix containing the mean image of the last 1000
%   frames of the input movie, where m and n are the movie height and
%   width, respectively. The gray values have been adjusted to maximize the
%   dynamic range.

%   d) diff_map - m x n matrix containing the difference between the mean
%   image of the first 1000 frames and the mean of the last 1000 frames.
%   The gray values have been adjusted to maximize the dynamic range.

% 2) A TIFF of the mean of the first 1000 frames of the input movie. The
% gray values have been adjusted to maximize the dynamic range.

% 3) A TIFF of the mean of the last 1000 frames of the input movie. The
% gray values have been adjusted to maximize the dynamic range.

% 4) A TIFF of the difference between the mean of the first 1000 frames and
% the last 1000 frames of the input movie. The gray values have been
% adjusted to maximize the dynamic range.


%% TOODO:


%% CD to directory of movie:
[directory, name, ext] = fileparts(path);
cd(directory);


%% Find number of frames in movie:
tic;
disp('Getting file info...');
info = imfinfo(path);
disp('... done'); toc;
num_frames = numel(info);

% Throw error if movie is fewer than 1000 frames long:
if num_frames < 1000
    error('Input video is fewer than 1000 frames long; cannot compare first vs last 1000-frame averages.');
elseif num_frames < 2000
    warning('Input video is fewer than 2000 frames long; first 1000 frames will overlap with last 1000 frames.');
end


%% Get average images of beginning and end of movie:

% Load first thousand frames and get average:
disp('Computing mean of first 1000 frames...'); tic;
%F = extract_frames(path, 201, 1200);
F = extract_frames(path, 1, 10);
avg_first = mean(F, 3); 
disp('... done.'); toc;

% Load last thousand frames and get average:
disp('Computing mean of last 1000 frames...'); tic;
%L = extract_frames(path, num_frames-999, num_frames);
L = extract_frames(path, 1, 10);
avg_last = mean(L, 3);
disp('... done'); toc;


%% Do 2D transform of average of last 1000 frames to compensate for any XY drift:

[avg_first_cropped, avg_last_reg_cropped, mask_reg] = reg_and_warp(avg_first, avg_last); % Do transform
avg_first_cropped = int16(avg_first_cropped); % necessary to save to TIFF later on
avg_last_reg_cropped = int16(avg_last_reg_cropped); % necessary to save to TIFF later on


%% Quantify similarity of mean images:

% Compute diff map:
diff_map = avg_last_reg_cropped - avg_first_cropped;

% Find 2D correlation coefficient:
r = corr2(avg_first_cropped, avg_last_reg_cropped);
disp(['r = ' num2str(r)]);

% Sum of squared errors:
sse = sum(sum((avg_last_reg_cropped - avg_first_cropped).^2));
disp(['sse = ' num2str(sse)]);


%% Compute correlaton map:
%{
Fbar = mean(mean(avg_first));
Lbar = mean(mean(avg_last_reg));

F_error = avg_first - Fbar;
L_error = avg_last_reg - Lbar;

F_sq_error = F_error.^2;
L_sq_error = L_error.^2;

F_sse = sum(reshape(F_sq_error, [1, width*height]));
L_sse = sum(reshape(L_sq_error, [1, width*height]));

d = sqrt(F_sse * L_sse);

corr_map = F_error.*L_error;
%}

%% Visualize images:

% Visualize averages and difference map:
f1 = figure();
subplot(1,3,1);
imshow(imadjust(avg_first_cropped));
title('First 1000 frame avg');
subplot(1,3,2);
imshow(imadjust(avg_last_reg_cropped));
title('Last 1000 frame avg');
subplot(1,3,3);
imshow(imadjust(diff_map));
title('Difference map');

%{
% Visualize difference map:
diff_map = avg_last_adjusted - avg_first_adjusted;
diff_map = diff_map - min(min(diff_map));
diff_map = diff_map/max(max(diff_map));

%  Display images:
f1 = figure();
imshow(avg_first_adjusted);
f2 = figure();
imshow(avg_last_adjusted);
f3 = figure();
imshow(diff_map);
%}


%% Try to register the mean images to the z-stack:

disp('Attempting to register average images to z-stack...');

% Find if there's a z-stack directory associated with the imaging site:

% CD to the site directory ad get contents:
movie_dir = cd('../..'); % assuming a directory structure of /mouse/session/site/grab/2P/movie.tif, this should cd to the site directory
ls = dir();

% Check if directory contents include zstack directory:
names = arrayfun(@(x) x.name, ls, 'UniformOutput', false);
is_zdir = cellfun(@(c) regexp(c, 'zstack'), names, 'UniformOutput', false);
zstack_exists = ~isempty(cell2mat(is_zdir));

% If zstack exists, try to register beginning and end average images to plane of z-stack:
if exist('zstack', 'dir')
    
    % CD to the z-stack directory:
    site_dir = cd('zstack');
    
    % Load z-stack metadata:
    z_metadata = loadjson('metadata.json');
    step_size = z_metadata.stepSize;
    
    % Get the name of the actual z-stack file:
    % TODO: deal with situations where there's more than one regexp match?
    % TODO: deal with situations where there's no regexp match?
    ls = dir();
    names = arrayfun(@(x) x.name, ls, 'UniformOutput', false);
    is_zstack = cellfun(@(c) ~isempty(regexp(c, 'file_[0-9]*.tif', 'ONCE')), names, 'UniformOutput', false);
    z_idx = find(cell2mat(is_zstack)); 
    zstack_name = ls(z_idx).name;
    
    % Load and process Z-stack:
    Z_processed = process_zstack(zstack_name);
    num_slices = size(Z_processed, 3);
    
    % Bank out non-overlapping pixels in Z_processed:
    for z = 1:num_slices
        curr_slice = Z_processed(:,:,z);
        curr_slice(~mask_reg) = mean(mean(curr_slice));
        Z_processed(:,:,z) = curr_slice;
    end
    
    % Correlate the average first image and average last image with each
    % slice and find the most correlated slice for each:
    z_first = reg_slice_2_stack(avg_first_cropped, Z_processed);
    z_last = reg_slice_2_stack(avg_last_reg_cropped, Z_processed);
    
    % Estimate the z-distance between the average first and average last image
    z_distance = (z_first - z_last) * step_size;
    
    z_drift.beginning_slice = z_first;
    z_drift.end_slice = z_last;
    z_drift.z_distance = z_distance;
end
('... done.');

% CD back to the movie directory:
cd(movie_dir);


%% Save outputs:

('Saving outputs...');

% Check if output directory exists, and if not, create it and cd into it:
ls = dir();
names = arrayfun(@(x) x.name, ls, 'UniformOutput', false);
is_cz = cellfun(@(c) regexp(c, 'check_zdrift'), names, 'UniformOutput', false);
cz_exists = ~isempty(cell2mat(is_cz));
if ~cz_exists
    mkdir('check_zdrift');
end
old = cd('check_zdrift');

% Create an output structure including the R value, mean beginning image,
% mean end image, and difference
z_drift.r = r;
z_drift.sse = sse;
z_drift.beginning = avg_first_cropped;
z_drift.end = avg_last_reg_cropped;
z_drift.diff_map = diff_map;
save('zdrift.mat', 'z_drift');

% Save average images:
f_name = 'AVG_frames_201-1200_adjusted.tif';
l_name = ['AVG_frames_' num2str(num_frames - 999) '-' num2str(num_frames) '_adjusted.tif'];
saveastiff(avg_first_cropped, f_name);
saveastiff(avg_last_reg_cropped, l_name);
saveastiff(diff_map, 'diff_map.tif');

('... done.');


%% Save metadata:

%{
Metadata.inputs(1).path = which(path);
Metadata.outputs(1).path = which(f_name);
Metadata.outputs(2).path = which(l_name);
Metadata.outputs(3).path = which('Zdrift.mat');

write_metadata(Metadata,'check_zdrift_metadata.json');
%}


%% close figures:
close(f1);

cd('..');
