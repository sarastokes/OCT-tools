# OCT-tools
Segmentation and analysis of retinal layers from individual OCT b-scans, with an emphasis on computing choroid thickness. Developed by Sara Patterson in the [Neitz lab][neitzlab] at University of Washington.


This code was written in Matlab 2018 and requires the Bioinformatics, Computer Vision and Signal Processing toolboxes. All external dependencies are provided, except the free [GUI Layout Toolbox][guilayout], which can be installed from Matlab's Add-Ons window.


The initial ILM and RPE segmentation uses a simplified implementation of an algorithm introduced in:
Chiu, S.J., Li, X.T., Nicholas, P., Toth, C.A., Izatt, J.A., Farsiu, S. (2010) Automatic segmentation of seven retinal layers in SDOCT images congruent with expert manual segmentation. *Optics Express*, 18(18), 19413-19428

[guilayout]: <https://www.mathworks.com/matlabcentral/fileexchange/47982-gui-layout-toolbox>
[neitzlab]: <https://www.neitzvision.com>