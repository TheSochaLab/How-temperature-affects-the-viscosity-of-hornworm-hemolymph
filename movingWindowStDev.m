% Completed February 2018
% Written by Matthew N. Giarra and Melissa C. Kenny
% Contact: mck66@vt.edu
function [STDEV, STDEV_INDICES] = movingWindowStDev(INPUTDATA, WINDOWSIZE)
% This function with calculate the moving window standard deviation of
% input data with a specificed window size. It will output a vector of the
% standard deviation for each index tested as the window moves through the
% data.

% Number of data points
nPoints = length(INPUTDATA);

% Number of points to the left and right of the window center
windowRadius = floor(WINDOWSIZE / 2);

% Number of data points on which a full-sized window can be centered
% (i.e. the "interior points" of the data)
nPointsValid = nPoints - 2 * windowRadius;

% Initialize the standard deviation vector
STDEV = zeros(nPointsValid, 1);

% Initialize the vector to hold the center point locations 
centerPoints = zeros(nPointsValid, 1);

% Loop over the data and calculate the Standard Deviation for each window location.
for k = 1 : nPointsValid;
   
   % Left and right index of the data that will 
   % contribute to the standard deviation calculation
   leftIndex  = k;
   rightIndex = WINDOWSIZE + k;
   
   % Location of the data point on which the window is centered
   centerPoints(k) = leftIndex + windowRadius;
   
   % Data within the window
   validInputData = INPUTDATA(leftIndex : rightIndex);
   
   % Standard deviation of the data within the window
   STDEV(k) = std(validInputData);
end

% Remove NaN values
validSD = ~isnan(STDEV);
STDEV = STDEV(validSD);
centerPoints = centerPoints(validSD);

% Save the center points locations to the output variable.
STDEV_INDICES = centerPoints;

end