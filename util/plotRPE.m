function plotRPE(OCT, varargin)

    ip = inputParser();
    ip.CaseSensitive = false;
    ip.KeepUnmatched = true;
    addParameter(ip, 'Axes', [], @ishandle);
    addParameter(ip, 'Normalize', true, @islogical);
    % addParameter(ip, 'LineWidth', 1, @isnumeric);
    % addParameter(ip, 'Color', 'k', @(x) isvector(x) || ischar(x));
    parse(ip, varargin{:});

    
    if isempty(ip.Results.Axes)
        ax = axes('Parent', figure());
        hold(ax, 'on');
    else
        ax = ip.Results.Axes;
    end

    if ip.Results.Normalize
        rpe = OCT.RPE(:, 2)/max(abs(OCT.RPE(:, 2)));
        axis(ax, 'tight');
    else
        rpe = OCT.RPE(:, 2);
    end

    plot(ax, OCT.RPE(:, 1), rpe, varargin{:});
