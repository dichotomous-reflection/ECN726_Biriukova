Replication/code run instructions:

This is replication code for the following paper:
Federle, Jonathan and Meier, André and Müller, Gernot J. and Mutschler, Willi and Schularick, Moritz, The Price of War (September 17, 2024). Available at SSRN: https://ssrn.com/abstract=4559293 or http://dx.doi.org/10.2139/ssrn.4559293

The code is written for Stata (originally 19, but I used Stata 16) combined with R. The file that needs to run is main_extended.do, and it includes both the R-Stata setup and the result generation. 
Line 10 needs to be modified with the directory in which the project is stored (currently it has my path).
Line 465 contains long-running code that generates panel figures not included in the main paper, so it is commented out (but it runs for about 1 hour+ if uncommented).
The replications were successful. The results will be stored in data/03_exports.


Extension instructions:
Path: 238484-V1/src/02_export/figures/my_modifications

In the specified folder, there are two files: predictability_with_initiators_final.R (reproducing my results for the first part) and attacker_defender_final.do (Stata code reproducing the results for the second part).

In the R file, change the path on line 5 to the local path where the project directory is stored (up to /238484-V1). After that, run the entire file. The results will be stored in the "results" subfolder.
In the Stata file, change the path on line 36 to the local path where the project directory is stored (up to /238484-V1). After that, run the entire file. The results will be stored in the "results" subfolder.

The code relies on the datasets obtained in the preprocessing stage of the main paper (stores in \238484-V1\data\02_processed). If the original replication code was run, these files should be available (or they can be downloaded with the project as they are included in the repository).
