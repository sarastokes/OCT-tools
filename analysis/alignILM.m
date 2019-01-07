function xShift = alignILM(refOCT, OCT, varargin)
    % ALIGNILM
    %
    % Description:
    %   Use cross correlation to align ILM for 2 OCTs
    %
    % Syntax:
    %   xShift = alignILM(refOCT, OCT, varargin)
    %
    % Input:
    %   refOCT          Reference OCT
    %   OCT             OCT to shift and align
    % Optional key/value input:
    %   Plot            Plot the output (default = true)
    %   Save            File path to save xshift of 2nd OCT (default = [])
    %   Clip            Points to clip from start + end of each signal
    %                   (default = [0, 0])
    %
    % Examples:
    %   % Remove the first 100 data points and last 200 data points from
    %   % each signal. This is helpful when you only care most about 
    %   % aligning the peak (fovea) and don't want the flat edges 
    %   % influencing the result
    %   alignILM(refOCT, OCT, 'Clip', [100, 200]);
    %
    % History:
    %   6Jan2018 - SSP
    % ---------------------------------------------------------------------

    assert(isa(refOCT, 'OCT'), 'Reference must be an OCT');
    assert(isa(OCT, 'OCT'), 'Input must be an OCT instance');
    
    ip = inputParser();
    ip.CaseSensitive = false;
    addParameter(ip, 'Plot', true, @islogical);
    addParameter(ip, 'Save', false, @islogical);
    addParameter(ip, 'Clip', [0, 0], @isnumeric);
    parse(ip, varargin{:});
    
    clipValues = round(ip.Results.Clip);

    % Get ILMs and smooth pixellation.
    refILM = smooth(refOCT.ILM(1+clipValues:end-clipValues, 2), 10);
    ILM = smooth(OCT.ILM(1+clipValues:end-clipValues, 2), 10);

    % Compute lag of longer signal
    [corrILM, lag] = xcorr(ILM, refILM);
    [~, ind] = max(abs(corrILM));
    lagDiff = lag(ind);

    if numel(ILM) >= numel(refILM)
        xShift = -1 * lagDiff;
    else
        xShift = lagDiff;
    end
    
    if abs(xShift) < 1
        disp('Using min alignment instead');
        [~, indILM] = min(ILM);
        [~, indREF] = min(refILM);
        xShift = round(indREF - indILM);
    end
    
    fprintf('Computed x-shift of %.3g\n', xShift);

    if ip.Results.Plot
        refILM = (refILM - min(refILM)) / max(abs(refILM - min(refILM)));
        ILM = (ILM - min(ILM)) / max(abs(ILM - min(ILM)));
        
        figure();
        ax1 = subplot(121); hold(ax1, 'on');
        axis(ax1, 'tight'); grid(ax1, 'on');
        plot(ax1, 1:numel(ILM), ILM, 'r');
        plot(ax1, 1:numel(refILM), refILM, 'k');
        set(ax1, 'XTickLabels', {}, 'YTickLabels', {}); 
        
        ax2 = subplot(122); hold(ax2, 'on');
        axis(ax2, 'tight'); grid(ax2, 'on');
        plot(ax2, (1:numel(ILM))+xShift, ILM, 'r');
        plot(ax2, 1:numel(refILM), refILM, 'k');
        set(ax2, 'XTickLabels', [], 'YTickLabels', []);
        
        legend('Target', 'Reference');
        set(legend, 'Location', 'NorthWest', 'EdgeColor', 'none');

        figPos(gcf, 1.5, 0.5); tightfig(gcf);
    end

    if ip.Results.Save
        jsonPath = [OCT.imagePath, OCT.imageName, '.json'];
        if exist(jsonPath, 'file')
            S = loadjson(jsonPath);
            S.Shift = xShift;
            savejson('', S, jsonPath);
        else
            S = struct('Shift', xShift);
            savejson('', S, jsonPath);
            fprintf('Created json file:\n%s\n', jsonPath);
            dlmwrite([OCT.imagePath, OCT.imageName, '_shift.txt'], xShift);
        end
    end

