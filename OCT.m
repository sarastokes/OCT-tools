classdef OCT < handle
    % OCT
    %
    % Description:
    %   Represents features and analyses of a single OCT b-scan
    %
    % Constructor:
    %   x = OCT(imageID, imagePath)
    %
    % Inputs:
    %   imageID         Image number (also image title)
    %   imagePath       Folder where image and data is stored, optional
    %                   If not provided, opens up UI to choose a folder
    %
    % Methods:
    %   obj.reload()
    %   obj.crop()
    %   obj.doAnalysis()
    % Visualization methods:
    %   obj.show()
    %   obj.plotRatio()
    %   obj.plotSizes()
    %   obj.showSegmentation()
    %
    % History:
    %   7Aug2018 - SSP - working version compiled from previous functions
    %   11Aug2018 - SSP - added crop function
    %   14Aug2018 - SSP - added reload option
    %   2Jan2019 - SSP - changed edges to control points
    %   3Jan2019 - SSP - added scale property
    % ---------------------------------------------------------------------

    % Identifiers
    properties (SetAccess = private)
        imagePath
        imageID
    end

    % Segmentation
    properties (SetAccess = private)
        RPE = [];
        ILM = [];
        Choroid = [];
        ChoroidParams = [];
        ControlPoints = [];
        CropValues = [];
        Shift = [];
        Theta = [];
        Scale = [];
    end

    % Analysis
    properties (SetAccess = private)
        choroidSize
        retinaSize
        choroidRatio
        shiftedRatios = false;
    end

    % Lazy loading of images and analysis
    properties (Dependent = true, Hidden = true)
        octImage
        imageName
    end
    
    % Transient copy of the full original image to support lazy loading
    properties (Transient = true, Hidden = true)
        originalImage
    end

    % Features which may have been extracted from the image
    properties (Constant = true, Hidden = true)
        FEATURES = {'rpe', 'ilm', 'choroid', 'parabola', 'controlpoints',...
            'crop', 'shift', 'theta', 'scale'};
    end

    methods
        function obj = OCT(imageID, imagePath)
            % OCT  Constructor
            assert(isnumeric(imageID), 'Image ID must be numeric');

            obj.imageID = imageID;
            if nargin < 2 || ~isfolder(imagePath)
                obj.imagePath = uigetdir();
            else
                obj.imagePath = imagePath;
            end
            fprintf('image path: %s\n', obj.imagePath);

            obj.originalImage = obj.fetchImage();
            obj.load();
            
            obj.shiftedRatios = false;
        end
        
        function reload(obj)
            % RELOAD  Reload from .txt files
            obj.load();
        end

        function str = getPath(obj, x)
            % GETPATH  Returns path of saved feature .txt file
            x = lower(x);
            assert(ismember(x, obj.FEATURES),...
                'Path value not in features list!');
            str = [obj.imagePath, filesep, obj.imageName, '_', x, '.txt'];
        end
        
        function cropValues = crop(obj, saveValues)
            if nargin < 2
                saveValues = false;
            else
                assert(islogical(saveValues), 'Save values should be t/f');
            end
            
            fh = figure(); 
            [~, cropValues] = imcrop(obj.octImage);
            
            % Return if no crop specified.
            if isempty(cropValues)
                return;
            end          
            cropValues = [ceil(cropValues(1:2)), floor(cropValues(3:4))];
            
            if saveValues
                str = [obj.imagePath, filesep, obj.imageName, '_crop.txt'];
                dlmwrite(str, cropValues);
                fprintf('Wrote crop values to: %s\n', str);
            end
            delete(fh);
        end

        function doAnalysis(obj)
            % Determine the full x-axis
            xpts = obj.getXPts();

            % Evaluate choroid parabola at the x-axis points
            CHOROID = parabola(xpts, obj.ChoroidParams);

            % Interpolate the RPE and ILM boundaries to the new x-axis
            iRPE = interp1(obj.RPE(:, 1), obj.RPE(:, 2), xpts);
            iILM = interp1(obj.ILM(:, 1), obj.ILM(:, 2), xpts);

            % Choroid to RPE-Choroid boundary
            obj.choroidSize = abs(CHOROID - iRPE);
            % RPE-Choroid boundary to ILM
            obj.retinaSize = abs(iRPE - iILM);
            % Ratio of choroid size to retina size
            obj.choroidRatio = obj.choroidSize./obj.retinaSize;
        end

        function xpts = getXPts(obj)
            % GETXPTS
            if ~isempty(obj.RPE) && ~isempty(obj.ILM)
                x_min = min([obj.RPE(:, 1); obj.ILM(:, 1)]);
                x_max = max([obj.RPE(:, 1); obj.ILM(:, 1)]);
                xpts = x_min:x_max;
                
                if ~isempty(obj.Shift)
                    xpts = xpts + obj.Shift;
                    fprintf('Applying shift of %u pixels\n', obj.Shift);
                end
            else
                xpts = [];
            end
        end
        
        function igor = igor(obj, smoothFac)
            if nargin < 2
                smoothFac = 12;
            end
            if isempty(obj.choroidRatio)
                obj.doAnalysis();
            end
            igor = [obj.getXPts', smooth(obj.choroidRatio, smoothFac)];
            openvar('igor');
        end
    end

    % Visualization methods
    methods
        function show(obj, ax)
            % SHOW  Plot the OCT image (with rotation and crop)
            if isempty(ax)
                ax = axes('Parent', figure());
            end
            imagesc(ax, obj.octImage); colormap(gray);
            title(ax, sprintf('Image #%u', obj.imageID));
            axis image off
            tightfig(gcf);
        end
        
        function plotRatio(obj, smoothFac)
            % PLOTRATIO
            if nargin < 2
                smoothFac = 10;
            end
            if isempty(obj.choroidRatio)
                obj.doAnalysis();
            end

            xpts = obj.getXPts();
            figure(); hold on;
            plot([0, max(xpts)], [1, 1], '--', 'Color', [0.3, 0.3, 0.3]);
            % Raw data
            plot(xpts, obj.choroidRatio, '.k', 'MarkerSize', 4);
            % Smoothed data
            plot(xpts, smooth(obj.choroidRatio, smoothFac),...
                'b', 'LineWidth', 1.5);
            xlim([0, max(xpts)]); ylim([0, 2]);
            title([obj.imageName ' - Choroid Thickness']);
            set(gca, 'Box', 'off'); grid on;
            ylabel('choroid to retina thickness ratio');
            xlabel('x-axis (pixels)');
        end

        function plotSizes(obj)
            % PLOTRATIO  Plot raw sizes of choroid and retina
            if isempty(obj.choroidRatio)
                obj.doAnalysis();
            end

            xpts = obj.getXPts();
            figure(); hold on;
            plot(xpts, obj.choroidSize, '.k', 'MarkerSize', 3);
            p1 = plot(xpts, smooth(obj.choroidSize, 8), 'b', 'LineWidth', 1);
            plot(xpts, obj.retinaSize, '.k', 'MarkerSize', 3);
            p2 = plot(xpts, smooth(obj.retinaSize, 8), 'r', 'LineWidth', 1);
            xlim([0, max(xpts)]);
            legend([p1, p2], {'Choroid', 'Retina'});
            title([obj.imageName ' - Choroid and Retina Sizes']);
            set(gca, 'Box', 'off'); grid on;
            ylabel('Width (pixels)');
            xlabel('x-axis (pixels)');
        end
        
        function showSegmentation(obj)
            if isempty(obj.RPE)
                return
            end
            obj.show(); hold on;
            plot(obj.RPE(:, 1), obj.RPE(:, 2), 'b');
            plot(obj.ILM(:, 1), obj.ILM(:, 2), 'b');
            plot(obj.Choroid(:, 1), obj.Choroid(:, 2), 'r');
        end
    end

    % Dependent set/get methods
    methods
        function imageName = get.imageName(obj)
            imageName = ['im', num2str(obj.imageID)];
        end

        function octImage = get.octImage(obj)
            if isempty(obj.originalImage)
                octImage = obj.fetchImage();
            else
                octImage = obj.originalImage;
            end
            
            % Transform or rotate the image, if necessary
            if ~isempty(obj.Scale)
                octImage = imresize(octImage, obj.Scale);
            end

            if ~isempty(obj.Theta)
                octImage = imrotate(octImage, obj.Theta);
                fprintf('Applied rotation of %.2f degrees\n', obj.Theta);
            end
            
            % Crop the image, if necessary
            if ~isempty(obj.CropValues)
                fprintf('Cropped by %u, %u\n',...
                    abs(round([size(octImage, 1) - obj.CropValues(3),...
                           size(octImage, 2) - obj.CropValues(4)])));
                octImage = imcrop(octImage, obj.CropValues);
            end
        end
    end

    methods (Access = private)
        function im = fetchImage(obj)
            % FETCHIMAGE  Read image from file
            str = [obj.imagePath, filesep, num2str(obj.imageID), '.png'];
            im = imread(str);

            % Convert to grayscale if necessary
            if numel(size(im)) == 3
                im = rgb2gray(im);
            end
        end

        function load(obj)
            % LOAD  Load parameters from file, if they exist
            obj.Choroid = obj.fetch(obj.getPath('choroid'));
            obj.ChoroidParams = obj.fetch(obj.getPath('parabola'));
            obj.RPE = obj.fetch(obj.getPath('rpe'));
            obj.ILM = obj.fetch(obj.getPath('ilm'));
            obj.ControlPoints = obj.fetch(obj.getPath('controlpoints'));
            obj.CropValues = obj.fetch(obj.getPath('crop'));
            obj.Shift = obj.fetch(obj.getPath('shift'));
            obj.Theta = obj.fetch(obj.getPath('theta'));
            obj.Scale = obj.fetch(obj.getPath('scale'));
        end
    end

    methods (Static)
        function x = fetch(filePath)
            % FETCH  Reads a .txt file if existing, returns message if not
            if ~exist(filePath, 'file')
                str = strsplit(filePath, filesep);
                fprintf('Did not find file %s\n', str{end});
                x = [];
            else
                x = dlmread(filePath);
            end
        end
    end
end
