# OCT-tools
Segmentation and analysis of retinal layers from individual OCT b-scans, with an emphasis on computing choroid thickness. Developed by Sara Patterson in the [Neitz lab][neitzlab] at University of Washington.

### Usage
The code works best when all the images are in a single folder with numbers as filenames (e.g., `1.png`, `2.png`, etc). 

1. If you intend to compare images of the same eye, the first step is to align them. The `alignImages.m` function will calculate the rotation necessary to align two images. Translations along the X-axis can be computed after segmentation.
2. Crop the images. Note: when the version of the image returned by the `octImage` property of the `OCT` class is rotated, then cropped so it's best to crop the image after rotating. MATLAB's built-in `imcrop` function is useful here.
3. Input the image to `ChoroidIdentification` to segment the layers.

Will finish this later...


### Dependencies
This code was written in Matlab 2018 and requires the Bioinformatics, Computer Vision and Signal Processing toolboxes. All external dependencies are provided, except the free [GUI Layout Toolbox][guilayout], which can be installed from Matlab's Add-Ons window.

### References
The initial ILM and RPE segmentation uses a simplified implementation of an algorithm introduced in:
Chiu, S.J., Li, X.T., Nicholas, P., Toth, C.A., Izatt, J.A., Farsiu, S. (2010) Automatic segmentation of seven retinal layers in SDOCT images congruent with expert manual segmentation. *Optics Express*, 18(18), 19413-19428

[guilayout]: <https://www.mathworks.com/matlabcentral/fileexchange/47982-gui-layout-toolbox>
[neitzlab]: <https://www.neitzvision.com>