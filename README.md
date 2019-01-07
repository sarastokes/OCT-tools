# OCT-tools
Segmentation and analysis of retinal layers from individual OCT b-scans, with an emphasis on computing choroid thickness. Developed by Sara Patterson (sarap44_at_uw.edu) in the [Neitz lab][neitzlab] at University of Washington. 

### Usage
The code works best when all the images are in a single folder with numbers as filenames (e.g., `1.png`, `2.png`, etc). The analysis and data will be saved with the prefix `im1_`, `im2_`, etc.

1. If you intend to compare images of the same eye, the first step is to align them. The `alignImages.m` function will calculate the rotation necessary to align two images and save the rotation value. Translations along the X-axis can be computed after segmentation.
2. Crop the images. Note: when the version of the image returned by the `octImage` property of the `OCT` class is rotated, then cropped so it's best to crop the image after rotating. MATLAB's built-in `imcrop` function is useful here.
3. Type `ChoroidApp` into the command line and select your image (or pass the image file path or `OCT` class as the first argument).
4. Segment the RPE-Choroid and ILM boundaries.
5. Use the Add Point button to add control points marking the choroid-sclera boundary. If these boundaries are not clear, open the `HistogramPeakSlider` UI to use 1D histograms and peak/trough detection to help with control point placement.
6. Fit the control points marking the choroid-sclera boundary with a parabola.
7. Steps 5 and 6 are usually an iterative process completed when enough control points are added to correctly fit the choroid-sclera boundary. 
10. Provide a name for the exported data (works best if this includes the image ID number like `im1`, `im2`, etc). This saves .txt files of the extracted boundaries, control points and fit parameters. The `OCT` class properties are populated by searching for these files.
11. To compare two images, use `compareChoroids.m`. This function plots the two choroids and optionally computes an x-axis shift value to align the two foveal pits. The alignment is just a simple registration of maximum values. Alternatively, you can use the `OCT.plotRatio()` to add multiple choroid ratios to a single plot.



### Dependencies
This code was written in Matlab 2018 and requires the Bioinformatics, Computer Vision, Curve Fitting, Image Processing and Signal Processing toolboxes.

### References
The initial ILM and RPE segmentation uses a simplified implementation of an algorithm introduced in:

Chiu, S.J., Li, X.T., Nicholas, P., Toth, C.A., Izatt, J.A., Farsiu, S. (2010) Automatic segmentation of seven retinal layers in SDOCT images congruent with expert manual segmentation. *Optics Express*, 18(18), 19413-19428


[neitzlab]: <http://www.neitzvision.com/>