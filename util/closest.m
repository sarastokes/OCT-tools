function [val, ind] = closest(n, vec)
	% CLOSEST  
    %
    % Description:
    %   Finds vector member closest to N
    %
    % Syntax:
    %   [val, ind] = closest(n, vec)
    % 
    % Inputs:
    %   n       Number to match
    %   vec     Vector to search
    % Outputs:
    %   val     Value of closest number to n in vec
    %   ind     Index of closest number to n in vec
    % 
	% History:
	%   29Aug2017 - SSP
    %   2Jan2018 - SSP - changed val to vector value, not difference value
    % ---------------------------------------------------------------------

	[~, ind] = min(abs(vec - n));
    val = vec(ind);
	