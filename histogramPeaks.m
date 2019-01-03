function [peakInd, troughInd] = histogramPeaks(x0, varargin)

    ip = inputParser();
    ip.CaseSensitive = false;
    addParameter(ip, 'Plot', false, @islogical);
    addParameter(ip, 'Thresh', 25, @isnumeric);
    parse(ip, varargin{:});


    x0 = double(x0);
    
    [peakInd, peakMag] = peakfinder(x0, ip.Results.Thresh);
    [troughInd, troughMag] = peakfinder(x0, ip.Results.Thresh, [], -1);
    
    if ip.Results.Plot
        ax = axes('Parent', figure()); hold(ax, 'on');
        plot(ax, 1:numel(x0), x0, 'Color', 'k', 'LineWidth', 1.5);
        plot(peakInd, peakMag, 'o',...
            'Color', hex2rgb('00cc4d'), 'LineWidth', 1.5);
        plot(troughInd, troughMag, 'o',...
            'Color', hex2rgb('ff4040'), 'LineWidth', 1.5);
        xlim(ax, [1, numel(x0)]); ylim(ax, [0, 255]);
    end
    
    peakInd = [peakInd, peakMag];
    troughInd = [troughInd, troughMag];
end