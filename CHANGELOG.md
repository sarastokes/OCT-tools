# CHANGELOG

### 22Jan2019
- Switched image padding code in `analysis\simpleSegmentation.m`
- Fixed select peaks tooltip string typo for `HistogramPeakSlider.m`
- Added `SegmentationPreprocessingTutorial.mlx`
- Images are default converted to doubles now within `analysis\simpleSegmentation.m`
- Colormap in `ChoroidApp.m` is now pink, added colormap button to `HistogramPeakSlider.m`
- Closing out of `OCT\crop` without specifying a crop value resets JSON crop value
- Image alignment with `analysis\alignImages.m` now uses cropped raw images

### 7Jan2019
- Added image reload to `ChoroidApp.m` and `OCT\update()`

### 6Jan2019
- Added option to `OCT` class save as a `.json` file. This will replace the many `.txt` files previously used for each parameter.
- New function `alignILM.m` to calculate the x-axis shift of one OCT image to match the reference image.
- Two new plotting functions: `util\plotRPE.m` and `util\plotILM.m`

### 5Jan2019
- User interface changes for `HistogramPeakSlider`: removed physical slider bc arrow keys were easier
- If segmentation exists, instatiating an `OCT` object automatically runs `OCT.doAnalysis`.
- Relative choroid ratio option for `OCT.plotRatio()` to compare choroid ratio to a reference OCT, if exists.
- Fixed application of `Shift` property for non-relative `OCT.plotRatio()`

### 4Jan2019
- Added `refID` property to `OCT` class for the image number of the reference OCT.

### 3Jan2019
- Added `scale` property to `OCT` class and modified `analysis\alignImages.m` accordingly
- Wrote `ChoroidRatioView` to interactively display choroid ratio while fitting boundary control points with `ChoroidApp`.

### 2Jan2019
- Wrote `HistogramSlider.m` to compare 1D histograms with segmented RPE, ILM and choroid.
- Wrote `HistogramPeakSlider.m` to cooperate with `ChoroidApp.m` for interactive identification of choroid boundary control points using the 1D histograms.
- Reformatted `ChoroidApp.m` with UI layout on right side
- Reorganized folders, adding `deprecated\` and `analysis\'

### 1Jan2019
- Prepped `ChoroidApp.m` for new experiments.

### 20Dec2018
- Added `ChoroidApp.m`, an improved version of `ChoroidIdentification.m` that relies on control points, not edge detection.
- Moved `ChoroidIdentification.m`

### 16Aug2018
- Reload and crop functions for OCT class.

### 8Aug2018
- Extra visualization options for the `OCT` class.
- QOD export option for getting choroid ratios into Igor Pro.
- Added instructions to README

### 7Aug2018
- Working class encompassing existing functions for individual OCT images (`OCT.m`).
- General improvements to workflow while analyzing images.

### 6Aug2018
- New function `alignImages.m` to determine rotation degree necessary to align images of the same eye from different days. 
- New function `compareChoroids.m` plots a comparison of two choroid thickness ratios and optionally aligns by shifting the 2nd ratio along the x-axis.
- Updates to `choroidThickness.m`.
- Utility function `exportFigure.m` for saving images of segmentation from `ChoroidIdentification.m`.

### 5Aug2018
- Array format of RPE and ILM segmentation now matches Edges and Choroid. Previous code needs to account for `[y;x]` to `[x, y]` conversion.
- Added initial analysis function `choroidThickness.m`. Next step is to align the signals.

### 4Aug2018
- Changed `ExcludeEdges` function from imrect to imfreehand
- Added fast MEX function for finding edges within polygon `lib\inPolygon.c` which must be compiled. For now `ChoroidIdentification.m` tries to compile the function if `InPolygon.mexw64` isn't available, but in the future, an option to use Matlab's builtin `inpolygon` would be good.

### 3Aug2018
- First working version of RPE, ILM segmentation and choroid fits to a parabola.