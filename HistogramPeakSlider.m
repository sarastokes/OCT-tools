classdef HistogramPeakSlider < handle
   
    properties (Access = private)
        octImage
        appHandle
    end

    properties (SetAccess = private)
        chosenPeak
        chosenTrough
        calculatedMidpoint
        storedPoints
    end

    properties (SetAccess = private)
        figHandle
        axHandle
        imHandle
        histHandle
        histLine
        sliderHandle
    end
    
    properties (Dependent = true)
        sliderValue
        
        RPE
        ILM
        Choroid
    end

    properties (Constant = true, Hidden = true)
        ICON_DIR = [fileparts(mfilename('fullpath')),...
                filesep, 'util', filesep, 'icons', filesep];
    end
    
    methods
        function obj = HistogramPeakSlider(im)
            if nargin == 0
                im = uigetfile({'*.png'; '*.tiff'; '*.jpeg'});
                if ~ischar(im)
                    disp('No image selected!');
                    return
                end
            end
            
            % Parse input file, get image
            if isa(im, 'OCT')
                im = im.octImage;
            elseif ischar(im)
                im = imread(im);
            end

            % Convert to grayscale if necessary
            if numel(size(im)) == 3
                im = rgb2gray(im);
            end
            obj.octImage = im;
            
            obj.createUI();
        end
        
        function sliderValue = get.sliderValue(obj)
            sliderValue = round(get(obj.sliderHandle, 'Value'));
        end
        
        function RPE = get.RPE(obj)
            RPE = obj.appHandle.RPE;
        end
        
        function ILM = get.ILM(obj)
            ILM = obj.appHandle.ILM;
        end
        
        function Choroid = get.Choroid(obj)
            Choroid = obj.appHandle.Choroid;
        end
        
        function addParent(obj, appHandle)
            if ~isa(appHandle, 'ChoroidApp')
                warning('Input must be ChoroidApp class');
                return;
            end
            obj.appHandle = appHandle;
            obj.addRPE(obj.appHandle.RPE);
            obj.addILM(obj.appHandle.ILM);
            obj.addChoroid(obj.appHandle.Choroid);
            obj.storedPoints = [obj.appHandle.ControlPoints(:, 1),...
                nan(size(obj.appHandle.ControlPoints, 1), 1),...
                obj.appHandle.ControlPoints(:, 2)];
            obj.plotStoredPoints();
        end

        
        function addRPE(obj, RPE)
            if isempty(RPE)
                return;
            end

            delete(findall(obj.figHandle, 'Tag', 'RPE'));

            line('Parent', obj.histHandle,...
                'XData', [1, 255],...
                'YData', repmat(obj.RPE(obj.sliderValue, 2), [1, 2]),...
                'Color', rgb('sky blue'),...
                'LineWidth', 1,...
                'Tag', 'RPE');
        end
        
        function addILM(obj, ILM)
            if isempty(ILM)
                return;
            end
            
            delete(findall(obj.histHandle, 'Tag', 'ILM'));
            
            line('Parent', obj.histHandle,...
                'XData', [1, 255],...
                'YData', repmat(obj.ILM(obj.sliderValue, 2), [1, 2]),...
                'Color', rgb('sky blue'),...
                'LineWidth', 1,...
                'Tag', 'ILM');
        end
        
        function addChoroid(obj, Choroid)
            if isempty(Choroid)
                return;
            end

            delete(findall(obj.histHandle, 'Tag', 'Choroid'));
            
            line('Parent', obj.histHandle,...
                'XData', [1, 255],...
                'YData', repmat(obj.Choroid(obj.sliderValue, 2), [1, 2]),...
                'Color', rgb('light red'),...
                'LineWidth', 1,...
                'Tag', 'Choroid');
        end
    end
    
    % Callback methods
    methods (Access = private)
        
        function onSlide(obj, ~, ~)
            obj.plotHistogram(obj.sliderValue);
            obj.plotRPE(obj.sliderValue);
            obj.plotILM(obj.sliderValue);
            obj.plotChoroid(obj.sliderValue);
            
            delete(findall(obj.histHandle, 'Tag', 'Peak'));
            delete(findall(obj.histHandle, 'Tag', 'Trough'));
            delete(findall(obj.histHandle, 'Tag', 'Midpoint'));
            
            set(obj.getByTag('SliderText'), 'String',...
                sprintf('Index = %u', obj.sliderValue));
            obj.plotSliderPoint();
        end
        
        function onSlideFinished(obj, ~, ~)
            set(obj.getByTag('PeakText'), 'String', 'Peak: ');
            set(obj.getByTag('TroughText'), 'String', 'Trough: ');
            set(obj.getByTag('MidpointText'), 'String', 'Midpoint: ');
        end

        function onFindPeaks(obj, ~, ~)
            [pkInd, trInd] = histogramPeaks(obj.octImage(:, round(obj.sliderValue)));
            if ~isempty(obj.RPE)
                pkInd(pkInd(:, 1) > obj.RPE(obj.sliderValue, 2), :) = [];
                trInd(trInd(:, 1) > obj.RPE(obj.sliderValue, 2), :) = [];
            end
            pkInd(pkInd(:, 2) == 0, :) = [];
            trInd(trInd(:, 2) == 0, :) = [];
            obj.plotPeaks(pkInd, trInd);
        end

        function onSelectPeak(obj, ~, ~)
            [~, xSelect, ySelect] = selectdata2(...
                'Axes', obj.histHandle,...
                'Figure', obj.figHandle,...
                'SelectionMode', 'closest',...
                'Ignore', obj.histLine);
            ind = cellfun(@isempty, xSelect);
            obj.chosenPeak = [xSelect{~ind}, ySelect{~ind}];
            set(obj.getByTag('PeakText'), 'String',...
                sprintf('Peak: %u, %u', obj.chosenPeak));
        end

        function onSelectTrough(obj, ~, ~)
            [~, xSelect, ySelect] = selectdata2(...
                'Axes', obj.histHandle,...
                'Figure', obj.figHandle,...
                'SelectionMode', 'closest',...
                'Ignore', obj.histLine);
            ind = cellfun(@isempty, xSelect);
            obj.chosenTrough = [xSelect{~ind}, ySelect{~ind}];
            set(obj.getByTag('TroughText'), 'String',...
                sprintf('Trough: %u, %u', obj.chosenTrough));
        end

        function onFindMidpoint(obj, ~, ~)
            if isempty(obj.chosenPeak) || isempty(obj.chosenTrough)
                return;
            end
            
            histRange = sort([obj.chosenPeak(2), obj.chosenTrough(2)]);
            histRange = histRange(1):histRange(2);
            meanPt = mean(obj.histLine.XData(histRange));
            [~, ind] = closest(meanPt, double(obj.histLine.XData(histRange)));
            xRange = double(obj.histLine.YData(histRange));
            ind = xRange(ind);
            obj.calculatedMidpoint = double([...
                obj.histLine.XData(ind), obj.histLine.YData(ind)]);
            set(obj.getByTag('MidpointText'), 'String',...
                sprintf('Midpoint: %u, %u', obj.calculatedMidpoint));
            obj.plotMidpoint(obj.calculatedMidpoint);
        end
        
        function onStoreMidpoints(obj, ~, ~)
            obj.storedPoints = cat(1, obj.storedPoints,...
                [obj.sliderValue, obj.calculatedMidpoint]);
            obj.plotStoredPoints();
        end
        
        function onDeleteLastPoint(obj, ~, ~)
            obj.storedPoints(end, :) = [];
            obj.plotStoredPoints();
        end
        
        function onSendMidpoints(obj, ~, ~)
            if isempty(obj.appHandle)
                warning('Need to set appHandle first!');
                return;
            end
            obj.appHandle.addControlPoints(obj.storedPoints(:, [1, 3]));
        end
    end
    
    % User interface functions
    methods (Access = private)
        function h = getByTag(obj, tag)
            h = findall(obj.figHandle, 'Tag', tag);
        end

        function plotHistogram(obj, xInd)
            set(obj.histLine, 'XData', obj.octImage(:, round(xInd)));
        end
        
        function plotRPE(obj, xInd)
            h = findobj(obj.histHandle, 'Tag', 'RPE');
            if ~isempty(h)
                set(h, 'YData', [obj.RPE(xInd, 2), obj.RPE(xInd, 2)]);
            end
        end
        
        function plotILM(obj, xInd)
            h = findobj(obj.histHandle, 'Tag', 'ILM');
            if ~isempty(h)
                set(h, 'YData', [obj.ILM(xInd, 2), obj.ILM(xInd, 2)]);
            end
        end
        
        function plotChoroid(obj, xInd)
            h = findobj(obj.histHandle, 'Tag', 'Choroid');
            if ~isempty(h)
                set(h, 'YData', [obj.Choroid(xInd, 2), obj.Choroid(xInd, 2)]);
            end
        end
        
        function plotStoredPoints(obj)
            delete(obj.getByTag('ControlPoints'));
            line(obj.storedPoints(:, 1), obj.storedPoints(:, 3),...
                'Parent', obj.axHandle,...
                'Color', 'c', 'Marker', 'x',...
                'LineStyle', 'none',...
                'Tag', 'ControlPoints');
        end
        
        function plotSliderPoint(obj)
            set(obj.getByTag('SliderPoint'), 'XData', obj.sliderValue);
        end
        
        function plotPeaks(obj, pkInd, trInd)
            % PLOTPEAKS  Plot detected peaks and troughs
            delete(findall(obj.histHandle, 'Tag', 'Peak'));
            delete(findall(obj.histHandle, 'Tag', 'Trough'));
            
            line(pkInd(:, 2), pkInd(:, 1),...
                'Parent', obj.histHandle,...
                'Color', hex2rgb('00cc4d'),...
                'Marker', 'o', 'LineWidth', 1,...
                'LineStyle', 'none',...
                'Tag', 'Peak');

            line(trInd(:, 2), trInd(:, 1),...
                'Parent', obj.histHandle,...
                'Color', hex2rgb('ff4040'),...
                'Marker', 'o', 'LineWidth', 1,...
                'LineStyle', 'none',...
                'Tag', 'Trough');
        end
        
        function plotMidpoint(obj, midPt)
            delete(obj.getByTag('Midpoint'));
            line(midPt(1), midPt(2),...
                'Parent', obj.histHandle,...
                'Color', hex2rgb('334de6'),...
                'Marker', 'o', 'LineWidth', 1,...
                'LineStyle', 'none',...
                'Tag', 'Midpoint');
        end
    end
    
    % User interface setup functions
    methods (Access = private)
        
        function createUI(obj)
            obj.figHandle = figure('Name', 'HistogramSlider',...
                'Color', 'w',...
                'NumberTitle', 'off',...
                'Menubar', 'none', 'Toolbar', 'none',...
                'DefaultUicontrolBackgroundColor', 'w');
            figPos(obj.figHandle, 1.4, 0.5);
            
            mainLayout = uix.HBox('Parent', obj.figHandle,...
                'Spacing', 1, 'Padding', 2,...
                'BackgroundColor', 'w');
            
            octLayout = uix.VBox('Parent', mainLayout,...
                'BackgroundColor', 'w');
            
            obj.axHandle = axes('Parent', octLayout);
            obj.imHandle = imagesc(obj.axHandle, obj.octImage);
            colormap(obj.figHandle, gray);
            axis(obj.axHandle, 'equal', 'tight', 'off');
            hold(obj.axHandle, 'on');
            
            obj.sliderHandle = uicontrol(octLayout,...
                'Style', 'slider',...
                'Min', 1, 'Max', size(obj.octImage, 2),...
                'Value', 1,...
                'Callback', @obj.onSlideFinished);
            jSlider = findjobj(obj.sliderHandle);
            set(jSlider, 'AdjustmentValueChangedCallback', @obj.onSlide);
            line(1, size(obj.imHandle.CData, 1),...
                'Parent', obj.axHandle,...
                'Color', rgb('peach'), 'Marker', '^',...
                'LineStyle', 'none',...
                'Tag', 'SliderPoint');
            
            set(octLayout, 'Heights', [-1, -0.1]);
            
            axPanel = uipanel('Parent', mainLayout,...
                'BackgroundColor', 'w');
            obj.histHandle = axes('Parent', axPanel,...
                'YLim', [1, size(obj.octImage, 1)],...
                'XLim', [0, 255],...
                'YDir', 'reverse',...
                'Tag', 'HistogramAxes');
            obj.histLine = line(obj.histHandle,...
                    'YData', 1:size(obj.octImage, 1),...
                    'XData', obj.octImage(:, 1),...
                    'LineWidth', 1, 'Color', 'k');
            
            uiLayout = uix.VBox('Parent', mainLayout,...
                'BackgroundColor', 'w');
            uicontrol(uiLayout,...
                'Style', 'text',...
                'String', 'Index = 1',...
                'Tag', 'SliderText');
            uicontrol(uiLayout,...
                'Style', 'push',...
                'String', 'Find Extrema',...
                'TooltipString', 'Find peaks of current histogram',...
                'Callback', @obj.onFindPeaks);
            uicontrol(uiLayout,...
                'Style', 'push',...
                'String', 'Select Peak',...
                'Callback', @obj.onSelectPeak);
            uicontrol(uiLayout,...
                'Style', 'push',...
                'String', 'Select Trough',...
                'Callback', @obj.onSelectTrough);
            uicontrol(uiLayout,...
                'Style', 'text',...
                'String', 'Last Selected:',...
                'FontWeight', 'bold');
            uicontrol(uiLayout,...
                'Style', 'text',...
                'String', 'Peak: ',...
                'Tag', 'PeakText');
            uicontrol(uiLayout,...
                'Style', 'text',...
                'String', 'Trough: ',...
                'Tag', 'TroughText');
            uicontrol(uiLayout,...
                'Style', 'push',...
                'String', 'Find midpoint',...
                'Tag', 'FindMidpoint',...
                'Callback', @obj.onFindMidpoint);
            uicontrol(uiLayout,...
                'Style', 'text',...
                'String', 'Midpoint: ',...
                'Tag', 'MidpointText');
            exportLayout = uix.HBox('Parent', uiLayout,...
                'BackgroundColor', 'w');
            plotLayout = uix.VBox('Parent', exportLayout,...
                'BackgroundColor', 'w');
            
            uicontrol(plotLayout,...
                'Style', 'push',...
                'String', 'Store',...
                'Callback', @obj.onStoreMidpoints);
            uicontrol(plotLayout,...
                'Style', 'push',...
                'String', 'Delete',...
                'Callback', @obj.onDeleteLastPoint);
            uicontrol(exportLayout,...
                'Style', 'push',...
                'String', 'Send',...
                'Callback', @obj.onSendMidpoints);
            
            set(uiLayout, 'Heights', [-0.5, -1, -1, -1, -0.5, -0.5, -0.5, -1, -0.5, -1])
            set(mainLayout, 'Widths', [-2.5, -1, -0.5]);
        end
    end
end