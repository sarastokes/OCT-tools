function [newIm2, Theta, Scale] = alignImages(im1, im2, plotFlag, savePath)
    % ALIGNIMAGES
    % 
    % Description:
    %   Align OCT images of the same eye
    %
    % Syntax:
    %   [newImg, Theta, Scale] = alignImages(im1, im2, plotFlag, savePath)
    %
    % Inputs:
    %   im1         First image
    %   im2         Second image, this one will be rotated/translated
    % Optional inputs:
    %   plotFlag    0 = none, 1 = final images (default), 2 = all images
    %   savePath    If provided, saves rotation to image 2 as .json
    % Outputs:
    %   newIm2      Aligned image
    %   Theta       Angle of rotation (imrotate)
    %   Scale       Scale factor applied (imresize)
    %
    % References
    % https://www.mathworks.com/help/vision/examples/
    % find-image-rotation-and-scale-using-automated-feature-matching.html
    %
    % History:
    %   6Aug2018 - SSP
    %   2Jan2019 - SSP - added more input image checking
    %   3Jan2019 - SSP - changed output to include angle and scale
    % ---------------------------------------------------------------------
    if nargin < 4
        savePath = [];
    elseif islogical(savePath) && isa(im2, 'OCT')
        savePath = [im2.imagePath, im2.imageName];
    end
    
    if nargin < 3
        plotFlag = 1;
    else
        assert(ismember(plotFlag, 0:2), 'Set plotFlag to 0, 1 or 2');
    end

    im1 = checkImage(im1);
    im2 = checkImage(im2);

    if plotFlag > 0
        figure();
        imshowpair(im1, im2);
        title('Original images');
    end
    
    % Identify matching features between the images
    pts1 = detectSURFFeatures(im1);
    pts2 = detectSURFFeatures(im2);
    
    [features1, validPts1] = extractFeatures(im1, pts1);
    [features2, validPts2] = extractFeatures(im2, pts2);
    
    % Match features by their descriptors
    indexPairs = matchFeatures(features1, features2);
    
    % Retrieve locations of corresponding points for each image
    matched1 = validPts1(indexPairs(:, 1));
    matched2 = validPts2(indexPairs(:, 2));
    
    % Show putative point matches
    if plotFlag == 2
        figure();
        showMatchedFeatures(im1, im2, matched1, matched2);
        title('Putatively matched points (including outliers)');
    end
    
    % Estimate transformation
    [tform, inlier2, inlier1] = estimateGeometricTransform(...
        matched2, matched1, 'similarity');
    
    % Display the matching points used in the computation
    if plotFlag == 2
        figure();
        showMatchedFeatures(im1, im2, inlier1, inlier2);
        title('Matching points (inliers only)');
        legend('pts image 1', 'pts image 2');
    end
    
    [Theta, Scale] = solveTransform(tform);
    
    % Transform image
    outputView = imref2d(size(im1));
    newIm2 = imwarp(im2, tform, 'OutputView', outputView);
    if plotFlag > 0
        figure();
        imshowpair(im1, newIm2);
        title('Aligned images');
    end
    
    if plotFlag > 0
        figure(); imshowpair(im1, newIm2, 'diff');
        title('Difference in aligned images');
        colorbar(); colormap(bone);

        figure(); hold on;
        plot(1:size(im1, 2), sum((newIm2 - im1), 1)/256);
        xlim([1, size(im1, 2)]);
        xlabel('pixels'); ylabel('error');
        title('Alignment errors');
        figPos(gcf, 1, 0.75);
    end
    
    % Save the output
    if ~isempty(savePath)
        jsonPath = [savePath, '.json'];
        if exist(jsonPath, 'file')
            S = loadjson(jsonPath);
            S.Scale = Scale; S.Theta = Theta;
        else
            im2.Theta = Theta; im2.Scale = Scale;
            im2.saveJSON();
            dlmwrite([savePath, '_theta.txt'], Theta);
            dlmwrite([savePath, '_scale.txt'], Scale);
            fprintf('Saved to %s\n\t and %s\n',... 
                [savePath, '_theta.txt'], [savePath, '_scale.txt']);
        end
        savejson('', S, jsonPath);
    end
end

function im = checkImage(im)
    % CHECKIMAGE  Parse input image
    if isa(im, 'OCT')
        im = im.rawImage;
    end

    if ndims(im) == 3
        im = rgb2gray(im);
    end
end