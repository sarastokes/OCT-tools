function ilm = plotILM(OCT, varargin)

    ip = inputParser();
    ip.CaseSensitive = false;
    ip.KeepUnmatched = true;
    addParameter(ip, 'Axes', [], @ishandle);
    addParameter(ip, 'Normalize', true, @islogical);
    addParameter(ip, 'Smooth', 10, @isnumeric);
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
        ilm = OCT.ILM(:, 2) - min(OCT.ILM(:, 2));
        ilm = ilm/max(abs(ilm));
        axis(ax, 'tight');
    else
        ilm = OCT.ILM(:, 2);
    end

    if ip.Results.Smooth > 0
        ilm = smooth(ilm, ip.Results.Smooth);
    end

    plot(ax, OCT.ILM(:, 1), ilm, ip.Unmatched);
