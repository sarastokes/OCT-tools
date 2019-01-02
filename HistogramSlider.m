classdef HistogramSlider < handle
   

    properties (Access = private)
        octImage
        RPE
        ILM
        Choroid
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
    end
    
    methods
        function obj = HistogramSlider(im)
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
        
        function addRPE(obj, RPE)
            obj.RPE = RPE;
            delete(findall(obj.figHandle, 'Tag', 'RPE'));

            line('Parent', obj.histHandle,...
                'XData', [1, 255],...
                'YData', repmat(obj.RPE(obj.sliderValue, 2), [1, 2]),...
                'Color', rgb('sky blue'),...
                'LineWidth', 1,...
                'Tag', 'RPE');
        end
        
        function addILM(obj, ILM)
            obj.ILM = ILM;
            delete(findall(obj.histHandle, 'Tag', 'ILM'));
            
            line('Parent', obj.histHandle,...
                'XData', [1, 255],...
                'YData', repmat(obj.ILM(obj.sliderValue, 2), [1, 2]),...
                'Color', rgb('sky blue'),...
                'LineWidth', 1,...
                'Tag', 'ILM');
        end
        
        function addChoroid(obj, Choroid)
            obj.Choroid = Choroid;
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
        end
    end
    
    % User interface functions
    methods (Access = private)
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
        
        function createUI(obj)
            obj.figHandle = figure('Name', 'HistogramSlider',...
                'Color', 'w',...
                'DefaultUicontrolBackgroundColor', 'w');
            figPos(obj.figHandle, 1.5, 0.5);
            
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
                'Value', 1);
            jSlider = findjobj(obj.sliderHandle);
            set(jSlider, 'AdjustmentValueChangedCallback', @obj.onSlide);
            
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

            set(mainLayout, 'Widths', [-3, -1]);
        end
    end
end