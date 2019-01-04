classdef ChoroidRatioView < handle
	
	properties (SetAccess = private)
		appHandle
		axHandle
		choroidRatio
	end

	properties (Hidden, Dependent = true)
		RPE
		ILM
		Choroid
        ChoroidParams
	end


	methods
		function obj = ChoroidRatioView(appHandle)
			assert(isa(appHandle, 'ChoroidApp'),...
				'Input ChoroidApp handle');
			obj.appHandle = appHandle;

			obj.createUI();

			addlistener(obj.appHandle, 'FitChoroid',... 
				@(src, evt)obj.onAppFitChoroid);
			addlistener(obj.appHandle, 'ClosedApp',...
				@(src, evt)obj.onAppClosed);
		end

		function update(obj)
			if ~isempty(obj.RPE) && ~isempty(obj.Choroid)
				obj.doAnalysis();
			end
		end
    end

    % Dependent set/get methods
	methods 
		function RPE = get.RPE(obj)
			RPE = obj.appHandle.RPE;
		end

		function ILM = get.ILM(obj)
			ILM = obj.appHandle.ILM;
		end

		function Choroid = get.Choroid(obj)
			Choroid = obj.appHandle.Choroid;
        end
        
        function ChoroidParams = get.ChoroidParams(obj)
            ChoroidParams = obj.appHandle.ChoroidParams;
        end
	end

	methods (Access = private)

		function doAnalysis(obj)
			xpts = obj.getXPts();

			% Evaluate choroid at x-axis points
			CHOROID = parabola(xpts, obj.ChoroidParams);

			% Interpolate the RPE and ILM boundaries
			iRPE = interp1(obj.RPE(:, 1), obj.RPE(:, 2), xpts);
			iILM = interp1(obj.ILM(:, 1), obj.ILM(:, 2), xpts);

			% Choroid to RPE boundary
			choroidSize = abs(CHOROID - iRPE);
			% RPE-Choroid boundary to ILM
			retinaSize = abs(iRPE - iILM);
			% Ratio of choroid size to retina size
			obj.choroidRatio = choroidSize ./ retinaSize;

			obj.plotAnalysis(xpts, obj.choroidRatio);
        end

		function xpts = getXPts(obj)
			if ~isempty(obj.RPE) && ~isempty(obj.ILM)
				xMin = min([obj.RPE(:, 1); obj.ILM(:, 1)]);
				xMax = max([obj.RPE(:, 1); obj.ILM(:, 1)]);
				xpts = xMin:xMax;
			else
				xpts = [];
			end
		end
	end

	% Callback functions
	methods (Access = private)
		function onKeyPress(obj, ~, evt)
			if strcmp(evt.Character, 'x')
				obj.update();
			end
		end

		function onAppFitChoroid(obj, ~, ~)
			obj.update();
		end

		function onAppClosed(obj, ~, ~)
            try
    			delete(obj.axHandle.Parent);
            catch
                return;
            end
		end
	end

	% User interface functions
	methods (Access = private)
		function plotAnalysis(obj, xpts, ypts)
			% PLOTANALYSIS  Plot the choroid ratio
			h = findobj(obj.axHandle, 'Tag', 'ChoroidRatio');

			if isempty(h)
				line(xpts, ypts,...
					'Parent', obj.axHandle,...
					'Color', hex2rgb('334de6'),...
					'LineWidth', 1,...
					'Tag', 'ChoroidRatio');
			else
				set(h, 'XData', xpts, 'YData', ypts);
			end

			xlim(obj.axHandle, [0, max(xpts)]);
			ylim(obj.axHandle, [floor(min(ypts)), ceil(max(ypts))]);
		end

		function createUI(obj)
			fh = figure('Name', 'ChoroidRatioView',...
				'Menubar', 'none', 'Toolbar', 'none',...
				'NumberTitle', 'off',...
				'Color', 'w',...
				'DefaultUicontrolBackgroundColor', 'w',...
				'KeyPressFcn', @obj.onKeyPress);
			figPos(fh, 0.5, 0.5);

			obj.axHandle = axes('Parent', fh,...
				'Tag', 'RatioAxes');
			hold(obj.axHandle, 'on');
			axis(obj.axHandle, 'square');
			xlabel(obj.axHandle, 'x-axis (pixels)');
			ylabel(obj.axHandle, 'choroid:retina ratio');
			line([1, size(obj.appHandle.originalImage, 2)], [1, 1],...
				'Parent', obj.axHandle,...
				'Color', [0.7, 0.7, 0.7], 'LineWidth', 0.5);
			xlim(obj.axHandle, [1, size(obj.appHandle.originalImage, 2)]);
			ylim(obj.axHandle, [0, 2]);
		end
	end

	methods (Static)
		function octList = getBaseOCT()
			vars = evalin('base', 'whos');
			octList = cell(0, 1);
			for i = 1:numel(vars)
				if isa(vars(i), 'OCT')
					octList = cat(1, octList, vars(i).name); 
				end
			end
		end
	end
end