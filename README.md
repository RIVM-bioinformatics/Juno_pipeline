## BAC Gastro pipeline

The goal of this pipeline is to generate assemblies from raw fastq files. The input of the pipeline is raw Illumina paired-end data in the form of two fastq files (with extension .fastq, .fastq.gz, .fq or .fq.gz), containing the forward and the reversed reads ('R1' and 'R2' must be part of the file name, respectively). On the basis of the generated genome assemblies, low quality and contaminated samples can be excluded for downstream analysis. __Note:__ The pipeline has been tested only in gastroenteric bacteria (_Salmonella_, _Shigella_, _Listeria_ and STEC).

The pipeline uses the following tools:
1. [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) (Andrews, 2010) is used to assess the quality of the raw Illumina reads
2. [Trimmomatic](http://www.usadellab.org/cms/?page=trimmomatic) (Bolger, Lohse, & Usadel, 2014) is used to remove poor quality data and adapter sequences. The sliding window option of Trimmomatic starts scanning at the 5’ end and clips the read once the average quality within the window falls below a threshold. The sliding window is the number of nucleotides over which Trimmomatic calculates an average phred quality score, a measure of the quality of the identification of the nucleobases generated by automated DNA sequencing. The Trimmomatic minlen config parameter is set to 50, this parameter is used to drop the read if the read is below a specific length.
3. FastQC is used once more to assess the quality of the trimmed reads
4. [Picard](https://broadinstitute.github.io/picard/) determines the library fragment lengths
5. The reads are assembled into scaffolds by [SPAdes](https://cab.spbu.ru/software/spades/) (Bankevich et al., 2012) by means of _de novo_ assembly of the genome. SPAdes uses k-mers for building an initial de Bruijn graph and on following stages it performs graph-theoretical operations to assemble the genome. Kmer sizes of 21, 33, 55, 77 and 99 were used. For _de novo_ assembly, SPAdes isolate mode is used. 
6. [QUAST](http://quast.sourceforge.net/) (Gurevich, Saveliev, Vyahhi, & Tesler, 2013) is used to assess the quality of the filtered scaffolds. 
7. To assess the quality of the microbial genomes, [CheckM](https://ecogenomics.github.io/CheckM/) (Parks, Imelfort, Skennerton, Hugenholtz, & Tyson, 2015) is used. CheckM calculates scores for completeness, contamination and strain heterogeneity. 
8. [Bbtools](https://jgi.doe.gov/data-and-tools/bbtools/) (Bushnell, 2014) is used to generate scaffold alignment metrics. 
9. [MultiQC](https://multiqc.info/) (Ewels, Magnusson, Lundin, & Käller, 2016) is used to summarize analysis results and quality assessments in a single report for dynamic visualization.

### Basic Usage

All input fastq files can be put in the raw_data folder, or an input folder can be otherwise specified. The most simple way to use the pipeline is:

```
bash start_here.sh -i <INPUT_DIR>
```

The pipeline guides you through the installation steps (if necessary). It first makes a sample sheet enlisting the samples and their corresponsing fastq files. Note that the pipeline expects that fastq files containing forward and reverse reads are recognized from each other by the name ('R1' and 'R2'. For instance: sampleX_R1.fastq.gz and sampleX_R2.fastq.gz). Make sure that your files follow that pattern!

The pipeline will run the different steps of the pipeline and store the results of each of them in the output folder (out/). The output folder also contains logging information for every step of the pipeline (out/log/), for the jobs submitted to the cluster in which it was run (out/log/drmaa) and for the pipeline in general (out/results/). 

### Getting help

For getting more information about the usage and see all the options accepted by this pipeline you can type:

```
bash start_here.sh --help
```
An important thing to know is that __the pipeline only accepts genera that are supported by the CheckM database__. To get a full list of the genera that are accepted by CheckM, run this:

```
bash start_here.sh --help_genera
```
The pipeline relies on the [`snakemake`](https://snakemake.readthedocs.io/en/stable/) workflows. This tool has a lot of options that can be used. The BAC gastro pipeline is able to send commands to snakemake. Thereore, any argument that is not enlisted in the `--help` is sent to snakemake. If you want to see all the available options/arguments that snakemake accepts, type:

```
bash start_here.sh --snakemake-help
```

### Advanced Usage

The pipeline also accepts different parameters that have different actions. For instance, you can do a dry-run in which every step the pipeline takes is enlisted, but without actually performing them.

```
bash start_here.sh -i <INPUT_DIR> -n
```
You can also clean all the files produced in previous runs (deleting the out/, out/log/, sample_sheet.yaml, etc) by typing

```
bash start_here.sh --clean
```

For other parameters, see the folloing table of options or call the `--help` option of this pipeline.

| __PARAMETER__ | __DESCRIPTION__ |
| :---: | :--- |
| __Input:__ | |
| -i, --input [DIR] | This is the folder containing your input fastq files. Default is raw_data/' and only relative paths are accepted |
| __Output (automatically generated):__ | |                                                                                   
| out/ | Contains dir contains the results of every step of the pipeline |
| out/log/ | Contains the log files for every step of the pipeline |
| out/log/drmaa | Contains the .out and .err files of every job sent to the grid/cluster |
| out/log/results | Contains the log files and parameters that the pipeline used for the current run |
| __Parameters:__ | |
| -h, --help | Print the help document |
| --help-genera | Prints list of accepted genera for this pipeline (based on CheckM list) |
| -sh, --snakemake-help | Print the snakemake help document |
| --clean (-y) | Removes output (-y forces "Yes" on all prompts) |
| --no-checkm	|	Not run CheckM or update the genus database from CheckM |
| --no-genus-update	|	Not update the genus database from CheckM |
| -n, --dry-run | Useful snakemake command that displays the steps to be performed without actually executing them. Useful to spot any potential issues while running the pipeline |
| -u, --unlock | Unlocks the working directory. A directory is locked when a run ends abruptly and it prevents you from doing subsequent analyses on that directory until it gets unlocked |
| Other snakemake parameters | Any other parameters will be passed to snakemake. Read snakemake help (-sh) to see the options |

