function [ratio, choroid_size, retina_size] = choroidThickness(octName, octPath)
    % CHOROIDTHICKNESS
    %
    % Syntax:
    %   [ratio,choroid_size,retina_size]=choroidThickness(octName,octPath)
    %
    % History:
    %   5Aug2018 - SSP
    % ---------------------------------------------------------------------
    
    % Parse inputs
    if nargin < 2
        octPath = uigetdir('Choose directory where segmentation is saved');
    end
    assert(ischar(octName), 'OCT name must be type char');
    
    % Template for reading segmentation files
    getPath = @(x) [octPath, filesep, x, '_', octName, '.txt'];
    
    % Load segmentation data
    rpe0 = dlmread(getPath('rpe'));
    if size(rpe0, 1) == 2
        rpe0 = flipud(rpe0);
        rpe0 = rpe0';
    end
    ilm0 = dlmread(getPath('ilm'));
    if size(ilm0, 1) == 2
        ilm0 = flipud(ilm0);
        ilm0 = ilm0';
    end
    CHOROID_PARAMS = dlmread(getPath('parabola'));
    
    % Determine the full x-axis
    x_min = min([rpe0(:, 1); ilm0(:, 1)]);
    x_max = max([rpe0(:, 1); ilm0(:, 1)]);
    xpts = x_min:x_max;
    
    % Evaluate choroid parabola at the x-axis points
    CHOROID = parabola(xpts, CHOROID_PARAMS);
    
    % Interpolate the RPE and ILM boundaries to the new x-axis
    RPE = interp1(rpe0(:, 1), rpe0(:, 2), xpts);
    ILM = interp1(ilm0(:, 1), ilm0(:, 2), xpts);
    
    choroid_size = abs(CHOROID - RPE);
    retina_size = abs(RPE - ILM);
    ratio = choroid_size./retina_size;
    
    figure(); hold on;
    plot([0, max(xpts)], [1, 1], '--', 'Color', [0.5 0.5 0.5]);
    plot(xpts, ratio, '.k', 'MarkerSize', 2);
    plot(xpts, smooth(ratio, 8), 'b');
    xlim([0, max(xpts)]); ylim([0, 2]);
    title([octName ' - size ratio']);
    set(gca, 'Box', 'off'); grid on;
    ylabel('choroid to retina thickness ratio');
    xlabel('x-axis (pixels)');
end