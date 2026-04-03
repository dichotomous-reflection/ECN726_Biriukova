Replication/code run instructions:

This is replication code for the following paper:
Federle, Jonathan and Meier, André and Müller, Gernot J. and Mutschler, Willi and Schularick, Moritz, The Price of War (September 17, 2024). Available at SSRN: https://ssrn.com/abstract=4559293 or http://dx.doi.org/10.2139/ssrn.4559293

The code is written for Stata (originally 19, but I used Stata 16) combined with R. The file that needs to run is main_extended.do, and it includes both the R-Stata setup and the result generation. 
Line 10 needs to be modified with the directory in which the project is stored (currently it has my path).
Line 465 contains long-running code that generates panel figures not included in the main paper, so it is commented out (but it runs for about 1 hour+ if uncommented).
The replications were successful. The results will be stored in data/03_exports.
