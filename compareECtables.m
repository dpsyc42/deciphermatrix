% % This script expects that the CSV files all have a consistent format with the necessary columns ('From', 'To', 'PosteriorExpectation'). Any deviations might cause the script to fail.

clear;
clc;

% User configuration for number of CSV files
numFiles = input('Enter the number of CSV files to compare: ');
csvFiles = cell(numFiles, 1);
labels = cell(numFiles, 1); % To store user-provided labels for each file

% Load datasets
for i = 1:numFiles
    [file, path] = uigetfile('*.csv', sprintf('Select CSV file %d containing dataset', i));
    if isequal(file, 0)
        disp('User cancelled the file selection.');
        return;
    else
        csvFiles{i} = fullfile(path, file);
        disp(['File ', num2str(i), ': ', csvFiles{i}, ' has been selected.']);
        labels{i} = input('Enter a label for this condition (e.g., ''placebo rest''): ', 's');
    end
end

% Reading data from each CSV, focusing only on 'From', 'To', 'PosteriorExpectation'
data = cell(numFiles, 1);
for i = 1:numFiles
    opts = detectImportOptions(csvFiles{i}, 'NumHeaderLines', 0);
    opts.SelectedVariableNames = {'From', 'To', 'PosteriorExpectation'};
    data{i} = readtable(csvFiles{i}, opts);
end

% User choices for analyses
doOverlaps = input('Do you want to analyze overlapping connections? Enter 1 for Yes, 0 for No: ');
doSignChanges = input('Do you want to analyze sign changes across conditions? Enter 1 for Yes, 0 for No: ');

% Define save directory - using the same directory as the first selected file
saveDir = path;

% Analyzing Overlapping Connections
if doOverlaps
    overlaps = table();
    for i = 1:height(data{1})
        for j = 2:numFiles
            for k = 1:height(data{j})
                if strcmp(data{1}.From(i), data{j}.From(k)) && strcmp(data{1}.To(i), data{j}.To(k)) && ...
                   sign(data{1}.PosteriorExpectation(i)) == sign(data{j}.PosteriorExpectation(k))
                    overlaps = [overlaps; table(data{1}.From(i), data{1}.To(i), ...
                        data{1}.PosteriorExpectation(i), data{j}.PosteriorExpectation(k), ...
                        'VariableNames', {'From', 'To', labels{1}, labels{j}})];
                end
            end
        end
    end
    if height(overlaps) > 0
        disp('Preview of Overlapping Connections:');
        disp(overlaps);
        savePath = fullfile(saveDir, 'Overlapping_Connections.csv');
        writetable(overlaps, savePath);
        disp(['Overlapping connections saved to: ', savePath]);
    else
        disp('No overlapping connections found.');
    end
end

% Detecting Sign Changes Across Conditions
if doSignChanges
    signChanges = table();
    for i = 1:height(data{1})
        for j = 2:numFiles
            for k = 1:height(data{j})
                if strcmp(data{1}.From(i), data{j}.From(k)) && strcmp(data{1}.To(i), data{j}.To(k)) && ...
                   sign(data{1}.PosteriorExpectation(i)) ~= sign(data{j}.PosteriorExpectation(k))
                    signChanges = [signChanges; table(data{1}.From(i), data{1}.To(i), ...
                        data{1}.PosteriorExpectation(i), data{j}.PosteriorExpectation(k), ...
                        'VariableNames', {'From', 'To', labels{1}, labels{j}})];
                end
            end
        end
    end
    if height(signChanges) > 0
        disp('Preview of Sign Changes Across Conditions:');
        disp(signChanges);
        savePath = fullfile(saveDir, 'Sign_Changes.csv');
        writetable(signChanges, savePath);
        disp(['Sign changes saved to: ', savePath]);
    else
        disp('No sign changes across conditions found.');
    end
end

