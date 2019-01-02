function newAxes = exportFigure(ax)
	% EXPORTFIGURE  
    %
    % Description:
    %   Open a UI axes into new figure window
    %
    % Syntax:
    %   newAxes = EXPORTFIGURE(ax);
	%
	% Inputs:
    %   ax          Axes handle
    % Output:
    %   newAxes     New axes handle
    %
    % History:
    %   6Jan2017 - SSP - moved from NeuronApp/RenderApp
	% ---------------------------------------------------------------------

	newAxes = copyobj(ax, figure());
	set(newAxes,...
		'ActivePositionProperty', 'outerposition',...
		'Units', 'normalized',...
		'Position', [0, 0, 1, 1],...
		'OuterPosition', [0, 0, 1, 1]);
    
    % Keep only the visible components
    delete(findall(newAxes, 'Visible', 'off'));
    