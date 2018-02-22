%% Viscosity Analysis in Bulk
% Completed February 2018 
% Written by Melissa C. Kenny and Matthew N. Giarra
% Contact: mck66@vt.edu
%
% This script loads all viscosity data files in a folder and calculates the
% moving-window standard deviation of the data, and segments the raw
% data into "steady" and "unsteady" portions by comparing the moving window
% standard deviation at each point to the standard deviation threshold
% specified by the user. The steady and unsteady viscosities are plotted
% along with the standard deviation of viscosity, and the mean, standard
% deviation, and bounds of the 95% confidence interval of viscosity 
% are saved within a .mat file.
%
% This code can only be used if the spindle speed was kept constant
% throughout the trial. The spindle type output only applies if 60 RPM was
% used with the 40 spindle and 120 RPM was used with the 51 spindle.
%
% This code also only works with filenames similar to 
% '25C_07-11-16_hum_la###_trial###' OR '10C_02-10-17_dry_water_trial###'
%
clear
clc
close all

%% Below are the inputs that you should change if needed.

% Size of the window used to calculate the moving-window standard 
% deviation of the data. 
windowSize = 150; % data points (not seconds)

% Standard deviation threshold for accepting a 'steady' vs an 'unsteady' 
% value
stDevThreshold = 0.05;

% Font size for making plots
fontSize = 14;

% Maximum y axis value for plots
ma = 25;

% Sample Rate
sampleRate = 2; % Hz

% End time for all trials - crops the data to this time
setEndTime = 25; % Minutes
setEndTime = setEndTime*60*sampleRate; % Data Points

%% You shouldn't need to change anything below this line.

% Choose the folder where all the files are that will be analyzed
fprintf('\n Choose the folder that contains all of the files to be analyzed from the pop up window.\n\n');
fileDirectory = uigetdir();

% Determine the path to the directory that will contain the plots. Make
% this if it doesn't already exist.
plotDirectory = [fileDirectory,'\plots\'];
if ~exist(plotDirectory, 'dir')
    mkdir(plotDirectory);
end

% Find all text files in this folder
txtFiles = dir([fileDirectory '\*.txt']);

% Create the structure fields and values variables to use to save as a .mat
% file later
field1 = 'Filename'; field2 = 'Temperature'; field3 = 'Date';
field4 = 'Humidity'; field5 = 'FluidTested'; field6 = 'Identifier';
field7 = 'TrialNumber'; field8 = 'Spindle'; field9 = 'RPM';
field10 = 'MeanViscosity'; field11 = 'ViscosityStandardDeviation';
field12 = 'LowerBoundConfidenceInterval'; field13 = 'UpperBoundConfidenceInterval';
field14 = 'WindowSize'; field15 = 'Threshold';
fileNameSt = {}; temperature = {}; date = {}; humidity = {}; trialType = {}; IDnum = {};
trialNumber = {}; spindle = {}; spinSpeed = {}; meanVisc = {}; stDevValidViscosity = {}; 
viscosityLowerBound = {}; viscosityUpperBound = {}; winsize = {}; thresh = {};

% A loop to go through each file and make the necessary calculations
for f = 1:length(txtFiles)
    
    % Save window size and threshold for each file
    winsize{f,1} = windowSize;
    thresh{f,1} = stDevThreshold;
    
    % Read each info file
    fileName = txtFiles(f).name;
    fileNameSt{f,1} = fileName;
    
    % Complete path to the data file.
    filePath = fullfile(fileDirectory, fileName);
    
    % Name of the trial, extracted from the file name
    trialName = fileName(1:end-4);
    
    % These are the trial stats, extracted from the trial name, including
    % temperature, date, humidity, trial number, larvae number, etc. If
    % these are not in the filename in the order indicated in line 19 then
    % it will not output correctly.
    if trialName(1:2) == '17' % Trials saying 17 were 17.5
        temperature{f,1} = '17.5';
    else temperature{f,1} = trialName(1:2);
    end
    date{f,1} = trialName(5:12);
    hum = trialName(14:16);
    if hum(2) == 'r'
        humidity{f,1} = 'No';
    elseif hum(2) == 'u'
        humidity{f,1} = 'Yes';
    end
    if trialName(18) == 'l' || trialName(18) == 'L'
        IDnum{f,1} = trialName(20:22);
        trialType{f,1} = 'hemolymph';
    else trialType{f,1} = trialName(18:22);
        IDnum{f,1} = 0;
    end
    trialNumber{f,1} = trialName(29:length(trialName));
    
    % Load the raw data file into a structure
    rawDataFile = importdata(filePath);
    
    % Extract the measured data from the raw data file
    try
        viscosityData = rawDataFile.textdata;
    catch
        warning('There is an anomolous text line in the file, open the file and delete any odd lines (usually the first line).')
        disp(['The filename is: ' fileName])
    end
    
    % Removes the '?' in front of some of the lines of data - the '?'
    % indicates the viscosity measured was outside the range of the
    % spindle. DO NOT ANALYZE data with these lines, the values are not
    % usable. However, as the motor starts up and turns off, these will
    % occur so that is why the '?' is removed here.
    viscosityData = regexprep(viscosityData(:,1),'?','');
    
    % Shorten the text file to the endSetTime set above
    if setEndTime < length(viscosityData)
        viscosityData = viscosityData(1:setEndTime);
    end
    
    % Obtain number of data points taken during the entire experiment
    nDataPoints = length(viscosityData);
    
    % Initialize a vector to hold the spindle speed (RPM), viscosity
    % (mPas), and torque (%) data
    spindleSpeed            = zeros(nDataPoints, 1);
    viscosityMeasurement    = zeros(nDataPoints, 1);
    torque                  = zeros(nDataPoints, 1);

    % Determine the position of the spindle speed, torque,
    % and viscosity data within the raw data vector
    spindleSpeedLocation = regexpi(viscosityData{1}, 'rpm');
    viscosityLocation    = regexpi(viscosityData{1}, 'mPas');
    torqueLocation       = regexpi(viscosityData{1}, '%');
    
    % Determine the spindle speed that was set on the viscometer
    % This assumes the speed is held constant after the motor gets to
    % speed and thus, the speed in the middle of testing would be the 
    % correct speed
    spindleSpeedToPlot = str2double(viscosityData{ceil(nDataPoints/2)}(spindleSpeedLocation + 4 : spindleSpeedLocation + 6));
    spinSpeed{f,1} = spindleSpeedToPlot;
    if spindleSpeedToPlot == 60
        spindle{f,1} = '40'; spNum = 40;
    else spindle{f,1} = '51'; spNum = 51;
    end
    
    % This loop extracts the spindle speed (RPM), torque, and the measured 
    % viscosity (mPas) from each line of the raw data file.
    for k = 1 : nDataPoints
        spindleSpeed(k)         = str2double(viscosityData{k}(spindleSpeedLocation + 4 : spindleSpeedLocation + 6));
        viscosityMeasurement(k) = str2double(viscosityData{k}(viscosityLocation + 5 : viscosityLocation + 8));
        torque(k)               = str2double(viscosityData{k}(torqueLocation + 2 : torqueLocation + 5));
    end
    
    % Determine which viscosity measurements were taken
    % at the spindle speed specified at the beginning of this file
    validPoints = spindleSpeed == spindleSpeedToPlot;

    % This is the viscosity measurements taken when the spindle speed was 
    % equal to the value specified at the beginning of this file
    validViscosityMeasurements2 = viscosityMeasurement(validPoints); %change
    
    % Take the torque measurements taken when the spindle speed was equal
    % to the value specified at the beginning of this file.
    validTorque = torque(validPoints);
    
    % Determine the maximum viscosity that can be measured for each
    % combination of spindle and speed.
    if spNum == 40
        maxVisc = 307/spindleSpeedToPlot;
        maxVisc = roundn(maxVisc, -2);
    elseif spNum == 51
        maxVisc = 4854/spindleSpeedToPlot;
        maxVisc = roundn(maxVisc, -2);
    end
    
    % Knowing the viscosity is equal to the maximum viscosity multiplied by
    % the torque, we can calculate the viscosity measured.
    validViscosityMeasurements = roundn((validTorque./100).*maxVisc, -2);

    % Time-vector in seconds
    timeVectorSeconds = 0.5 * (0 : (length(validViscosityMeasurements) - 1) )';

    % Time vector in minutes
    timeVectorMinutes = timeVectorSeconds / 60;

    % Calculates the moving-window standard deviation 
    % of the valid data, and the locations of the
    % centers of the moving window within the input data array.
    [stDev, stDev_Indices] = movingWindowStDev(validViscosityMeasurements, windowSize);

    % Determine the locations in the standard deviation
    % vector where the standard deviation is less than or equal to the
    % threshold specified at the beginning of this file.
    indicesBelowThreshold = stDev_Indices (stDev < stDevThreshold);
    viscosityDataBelowThreshold = validViscosityMeasurements(indicesBelowThreshold);
    minutesBelowThreshold = indicesBelowThreshold * 0.5 / 60;

    % Calculate the average valid viscosity
    meanVisc{f,1} = mean(viscosityDataBelowThreshold);

    % Calcuate the standard deviation of the valid viscosity
    stDevValidViscosity{f,1} = std(viscosityDataBelowThreshold);

    % Calculate the upper and lower bounds of the 95% confidence interval
    viscosityUpperBound{f,1} = meanVisc{f,1} + 1.96 * stDevValidViscosity{f,1};
    viscosityLowerBound{f,1} = meanVisc{f,1} - 1.96 * stDevValidViscosity{f,1};
    
    % Create a figure handle for plotting.
    fi = figure;

    % Plot the raw data and the standard deviation on separate axes.
    [AXES, rawTrace, stdTrace] = plotyy(timeVectorMinutes, validViscosityMeasurements,  0.5 * stDev_Indices / 60, stDev, 'plot');
    
    % Format the raw trace.
    set(rawTrace, 'LineStyle', '-', 'Color', 'k', 'LineWidth', 2);

    % Format the stDev trace
    set(stdTrace, 'LineStyle', '-', 'Color', 'r', 'LineWidth', 2);

    % Label the two vertical axes and horizontal axis.
    set(get(AXES(1),'Ylabel'), 'String','Viscosity (cP)', 'FontSize', fontSize, 'Color', 'black')
    set(get(AXES(2),'Ylabel'), 'String','Standard Deviation (mPas)', 'FontSize', fontSize, 'Color', 'red')
    set(get(AXES(1),'Xlabel'), 'String','Time (min)','FontSize',fontSize, 'Color', 'black')

    % % Set the axis limits.
    mi = 0;
    set(AXES(1), 'ylim', [mi ma], 'YMinorTick', 'on', 'YTick', mi:1:ma, 'YColor', 'black');
    set(AXES(2), 'ylim', [0 0.5], 'YMinorTick', 'on', 'YTick', 0:0.1:0.5, 'YColor', 'red');

    % Plot the viscosity data below the threshold.
    hold on;
    plot(minutesBelowThreshold, viscosityDataBelowThreshold, '.g', 'MarkerSize', 7);
    hold off
    
    % Turn on the grid.
    grid on;

    % Make a plot legend
    h = legend('Data Not Included', 'Acceptable Data', 'Viscosity St. Dev.');

    % Plot a dashed line indicating the std dev threshold
    axes(AXES(2));
    hold on;
    plot(xlim, stDevThreshold * [1, 1], '--k');

    % Label the plot.
    title([lower(strrep(trialName, '_', '-'))], 'FontSize', 0.8 * fontSize);

    % Format the plot.
    set(h, 'FontSize', fontSize);
    set(gcf, 'color', 'white');
    set(AXES, 'FontSize', fontSize);
    axis(AXES, 'square');

    % Determine the path to the .eps (vector) plot to be saved.
    figureSavePathEPS = fullfile(plotDirectory, [fileName '.eps']);

    % Determine the path to the Matlab .fig file to be saved.
    figureSavePathMAT = fullfile(plotDirectory, [fileName '.fig']);
    
    % Save the EPS (vector) figure.
    print(fi, '-depsc', figureSavePathEPS);

    % Save the Matlab .fig file.
    saveas(fi, figureSavePathMAT, 'fig');

    hold off

end

% Put all the data together in a structure
finalStats = struct(field1, fileNameSt, field2, temperature, field3, date, field4, humidity, field5, trialType, field6, IDnum, field7, trialNumber, field8, spindle, field9, spinSpeed, field10, meanVisc, field11, stDevValidViscosity, field12, viscosityLowerBound, field13, viscosityUpperBound, field14, winsize, field15, thresh);

% Prompt the user if they want to save the data. If yes, then will continue
% through saving the .mat and excel file, if not, code will end.
wantToSave = input('Do you want to save this data? Type 1 for yes, 2 for no: ');
if wantToSave == 1

    % Save all data as a .mat file
    saveName = input('What do you want to save the file? Input as string. ');
    save(saveName, 'finalStats')

end

% END OF SCRIPT



