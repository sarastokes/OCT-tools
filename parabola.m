function y = parabola(x, a)
    % PARABOLA
    %
    % Inputs:
    %   x   x-axis points
    %   a   fit parameters
    %
    % 3Aug2018 - SSP
    % ---------------------------------------------------------------------
    
    y = a(1)+a(2)*x + a(3)*x.^2;