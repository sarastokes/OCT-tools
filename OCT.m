classdef OCT < handle
    % OCT
    
    properties (SetAccess = private)
        RPE
        ILM
        Choroid
        ChoroidParams
        Edges
        CropValues
    end
    
    properties
        imagePath char
        imageName char
        imageID
    end
    
    properties (Dependent = true, Hidden = true)
        octImage
    end
    
    properties (Transient = true, Hidden = true)
        originalImage
    end
    
    properties (Constant, Hidden)
        FEATURES = {'rpe', 'ilm', 'choroid', 'parabola', 'edges', 'crop'};
    end
    
    methods
        function obj = OCT(imageName)
            if nargin == 0
                % New image, may not have been segmented yet
                [obj.imageName, obj.imagePath] = uigetfile();
                obj.octImage = obj.fetchImage();
            else
                % Image with existing segmentation
                obj.imageName = imageName;
                obj.imagePath = uigetdir();
                obj.load();
                obj.octImage = obj.fetchImage();
            end
        end
        
        function octImage = get.octImage(obj)
            if isempty(obj.originalImage)
                octImage = obj.fetchImage();
            else
                octImage = obj.originalImage;
            end
        end
        
        function str = getPath(obj, x)
            % GETPATH
            str = [obj.imagePath, filesep, x, '_', obj.imageName, '.txt'];
        end
        
        function set.RPE(obj, RPE)
            obj.RPE = RPE;
        end
        
        function set.ILM(obj, ILM)
            obj.ILM = ILM;
        end
        
        function set.Choroid(obj, choroid)
            obj.Choroid = choroid;
        end
        
        function set.ChoroidParams(obj, choroidParams)
            % assert(numel(choroidParams) == 3,...
            %     'Provide 3 parabola fit parameters');
            obj.ChoroidParams = choroidParams;
        end
        
        function set.Edges(obj, edges)
            obj.Edges = edges;
        end
        
    end
    
    methods (Access = private)
        function im = fetchImage(obj)
            % FETCHIMAGE  Read image from file
            if ~exist(obj.imagePath, 'file')
                obj.imagePath = uigetfile();
            end
            
            im = imread(obj.imagePath);
            
            % Convert to grayscale if necessary
            if numel(size(im)) == 3
                im = rgb2gray(im);
            end
        end
        
        function load(obj)
            % LOAD  Load parameters from file
            obj.Choroid = dlmread(getPath('choroid'));
            obj.ChoroidParams = dlmread(getPath('parabola'));
            obj.RPE = dlmread(getPath('rpe'));
            obj.ILM = dlmread(getPath('ilm'));
            obj.Edges = dlmread(getPath('edges'));
            obj.CropValues = dlmread(getPath('crop'));
        end
    end
end