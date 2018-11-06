# spxBurstDetection

is a graphical user interface for the detection of 'bursts' in time stamp lists representing neuronal events, e.g. trains of action potentials. Bursts are defined as groups of events occurring in rapid succession, separated by phases of long inter-spike intervals. More precisely, the algorithm is a variant of the MaxInterval algorithm (Nex Technologies, NeuroExplorer Manual (2018), http://www.neuroexplorer.com; Cotterill et al., J.Neurophysiol. 116, 306–321 (2016))

The burst detection algorihm is implemented in function etslburstf.m; see there for details.
The code makes use of in-house formats for time information, namely 'time stamp lists' (tsl) and 'extended time stamp lists' (etsl). 

![screenshot](/doc/screenshot_spxBurstDetection.png)

### Features: 
* reads time stamp lists in *.mat files as produced by threshdetgui (see threshDet repository)
* user-defined specification of all critical parameters defining bursts
* display of raster plots and detected bursts
* display of inter-spike-interval histogram
* display of peri-burst time interval histogram
* saving to disk of detected bursts as etsl

Please note that the code in this repository is not self-sufficient, you'll additionally need the following repositories:
* fileIO
* etslfunc
* graphics
* sampledSeries
* utilities

Matlab toolboxes required:
* Statistics and Machine Learning

## General note on repositories in the ExpAnesth organization
The code in these repositories provides basic tools for the analysis of electrophysiological time series to members of the Section of Experimental Anesthesiology, Department of Anesthesiology, University Hospital of Tuebingen. Except where noted, code was written by Harald Hentschke. It has been designed primarily for in-house use by individuals who were instructed on its scope and limitations. Also, a substantial proportion of the code has been developed and extended over a time span of >10 years. In detail,

* the implementation of algorithms reflects the evolution of Matlab itself, that is, code that had been initially developed on older versions of Matlab does not necessarily feature newer techniques such as the new automatic array expansion as introduced in Matlab Release 2016b
* nonetheless, all code has been tested to run on Matlab R2018b
* while most m-files contain ample comments, documentation exists only for a few repositories
* checks of user input are implemented to varying degrees
* the code will be improved, updated and documented when and where the need arises