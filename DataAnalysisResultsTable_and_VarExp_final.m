clear;
addpath('/scratch/fc37/leo/Toolboxes/spm12'); % Add SPM12 to the MATLAB path

%% File Loading
[file, path] = uigetfile('*.mat', 'Select the MAT file containing BMA data');
if isequal(file, 0)
    disp('User selected Cancel');
    return;
else
    disp(['User selected ', fullfile(path, file)]);
    load(fullfile(path, file)); % Load the selected file
end

%% Extract the filename without extension to use in output CSV names
[~, name, ~] = fileparts(file);

%% Check for required data
if ~exist('BMA', 'var') || ~exist('GCM', 'var')
    error('BMA or GCM data not found in the file. Please check the MAT file content.');
end

%% User Configuration
desired_covariates = [2]; % Default is the second covariate, change as needed
roi_names_input = 'AMG, PCC, mPFC, INS, rPPC, lPPC'; % Modify names and length as needed
roi_names = strsplit(roi_names_input, ', ');
Pp_threshold = 0.99; % Threshold for posterior probability
Ep_thr = 0.0001; % Threshold for posterior expectation

%% Calculate Average Variance Explained First
nSubjects = numel(GCM);
varExplained = zeros(nSubjects, 1);
for i = 1:nSubjects
    result = spm_dcm_fmri_check(GCM{i});
    varExplained(i) = result.diagnostics(1);  % Assuming diagnostics(1) is the variance explained
end
averageVariance = mean(varExplained);

%% Prepare Enhanced Filenames Incorporating Average Variance
significantFilename = sprintf('%s_avg-%.2f_Pp%.3f.csv', name, averageVariance, Pp_threshold);
varianceFilename = sprintf('%s_variance_explained_avg-%.2f_results.csv', name, averageVariance);

%% Calculate BMA Data Matrices for Significant Values
covariates_n = length(BMA.Xnames); % Number of covariates
VOI_n = sqrt(length(BMA.Pnames)); % Calculate number of ROIs based on Pnames length
if length(roi_names) ~= VOI_n
    error('Number of ROI names does not match number of ROIs. Please enter %d ROI names.', VOI_n);
end

Ep = reshape(full(BMA.Ep), VOI_n, VOI_n, covariates_n); % Posterior expectations
Pp = reshape(BMA.Pp, VOI_n, VOI_n, covariates_n); % Posterior probabilities
ci = spm_invNcdf(0.95); % 5th and 95th percentiles for confidence intervals
c = ci * sqrt(diag(BMA.Cp));
interval_low = BMA.Ep - c;
interval_high = BMA.Ep + c;

low = NaN(VOI_n, VOI_n, covariates_n);
high = NaN(VOI_n, VOI_n, covariates_n);
for i = 1:covariates_n
    ids = 1 + (i - 1) * VOI_n^2 : i * VOI_n^2;
    low(:,:,i) = full(reshape(interval_low(ids), VOI_n, VOI_n));
    high(:,:,i) = full(reshape(interval_high(ids), VOI_n, VOI_n));
end

significant = (Pp >= Pp_threshold) & (abs(Ep) >= Ep_thr);
Ep_significant = zeros(size(Ep));
Ep_significant(significant) = Ep(significant);

rows = [];
for i = desired_covariates
    for r = 1:VOI_n
        for c = 1:VOI_n
            if significant(r, c, i)
                row = {roi_names{r}, roi_names{c}, BMA.Xnames{i}, sprintf('%.3f', Ep_significant(r, c, i)), sprintf('%.3f', low(r, c, i)), sprintf('%.3f', high(r, c, i))};
                rows = [rows; row];
            end
        end
    end
end

%% Create and display the table of significant values
T = cell2table(rows, 'VariableNames', {'From', 'To', 'Covariate', 'PosteriorExpectation', 'CI_Lower', 'CI_Upper'});
if height(T) > 0
    disp('Preview of Significant Connections:');
    disp(T);
    writetable(T, fullfile(path, significantFilename));
    disp(['CSV file saved to: ', fullfile(path, significantFilename)]);
else
    disp('No significant connections found.');
end

%% Display and save the Variance Explained CSV including the average variance
resultsTable = table(cellstr(num2str((1:nSubjects)')), varExplained, 'VariableNames', {'Subject', 'VarianceExplained'});
% Append the average variance as the last row
averageRow = table({'ave'}, averageVariance, 'VariableNames', {'Subject', 'VarianceExplained'});
resultsTable = [resultsTable; averageRow];

if height(resultsTable) > 0
    disp('Preview of Variance Explained:');
    disp(resultsTable);
    writetable(resultsTable, fullfile(path, varianceFilename));
    disp(['CSV file saved to: ', fullfile(path, varianceFilename)]);
else
    disp('No variance explained data to display.');
end
