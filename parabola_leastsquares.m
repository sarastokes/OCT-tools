function [fit, beta] = parabola_leastsquares(x, y, interpFit)
    % FITPARABOLA
    %
    % Description:
    %   Fit data to a parabola using least squares. Interpolate to a
    %   regularly spaced grid, if necessary.
    %
    % Syntax:
    %   [fit, beta] = parabola_leastsquares(x, y, interpFit)
    %
    % Inputs:
    %   x                   x-axis points
    %   y                   y-axis points
    % Optional inputs:
    %   interpOutput        interpolate to regular spacing along x
    %                       default = false
    %
    % Outputs:
    %   fit                 y-axis fit to parabola
    %   beta                fit parameters
    % 
    % History:
    %   3Aug2018 - SSP
    % ---------------------------------------------------------------------
    
    if nargin < 3
        interpFit = false;
    else
        assert(islogical(interpFit), 'interpFit should be t/f');
    end
    
    assert(numel(x) == numel(y), 'x and y need the same number of points');
    
    % Set up the linear equations:
    A = @(x) [ones(numel(x),1), x, x.^2];
    
    % Least squares:
    beta = A(x)\y;
    
    % Parabola using fit parameters
    fit = parabola(x, beta);
    
    % Interpolate to regularly spaced grid (like pixels of image)
    if interpFit
        fit = interp1(x, fit, min(x):max(x));
    end
end