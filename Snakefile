"""
Juno pipeline
Authors: Ernst Hamer, Alejandra Hernandez-Segura, Dennis Schmitz, Robert Verhagen, Diogo Borst, Tom van Wijk, Maaike van der Beld
Organization: Rijksinstituut voor Volksgezondheid en Milieu (RIVM)
Department: Infektieziekteonderzoek, Diagnostiek en Laboratorium Surveillance (IDS), Bacteriologie (BPD)
Date: 09-10-2020

Documentation: https://github.com/DennisSchmitz/BAC_gastro


Snakemake rules (in order of execution):
    1 fastQC        # Asses quality of raw reads.
    2 trimmomatic   # Trim low quality reads and adapter sequences.
    3 fastQC        # Asses quality of trimmed reads.
    4 spades        # Perform assembly with SPAdes.
    5 quast         # Run quality control tool QUAST on contigs/scaffolds.
    6 checkM        # Gives scores for completeness, contamination and strain heterogeneity (optional).
    7 picard        # Determines library fragment lengths.
    8 bbmap         # Generate scaffold alignment metrics.
    9 multiQC       # Summarize analysis results and quality assessments in a single report 

"""

#################################################################################
##### Import config file, sample_sheet and set output folder names          #####
#################################################################################

configfile: "profile/pipeline_parameters.yaml"
configfile: "profile/variables.yaml"

from pandas import *
import pathlib
import pprint
import os
import yaml
import json


yaml.warnings({'YAMLLoadWarning': False}) # Suppress yaml "unsafe" warnings

#################################################################################
##### Load samplesheet, load genus dict and define output directory         #####
#################################################################################

# SAMPLES is a dict with sample in the form sample > read number > file. E.g.: SAMPLES["sample_1"]["R1"] = "x_R1.gz"
SAMPLES = {}
with open(config["sample_sheet"]) as sample_sheet_file:
    SAMPLES = yaml.safe_load(sample_sheet_file) 

# OUT defines output directory for most rules.
OUT = pathlib.Path(config["out"])

# Decision whether to run checkm or not
checkm_decision = config["checkm"]
genus_all=config["genus"]
genus_file_1 = str(config["genus_file"])

if checkm_decision == 'TRUE':
    # make a list of all genera supported by the current version of CheckM
    genuslist = []
    with open(config["genuslist"]) as file_in:
        for line in file_in:
            if "genus" in line:
                genuslist.append((line.split()[1].lower().strip()))
    
    # If genus for all samples was provided, use it. Otherwise read it from the In-house_NGS_selectie_2020.xlsx file
    if genus_all != 'NotProvided':
        if genus_all.lower() in genuslist: 
            for sample, value in SAMPLES.items():
                SAMPLES[sample] = [value, genus_all]
        else:
            print(f""" \n\nERROR: The genus supplied is not recognized by CheckM\n
            If you are unsure what genera are accepted by the current version of the pipeline, 
            please run the pipeline using the --help-genera command to see available genera.\n\n""")
            sys.exit(1)
    else:
        # Check genus file is available
        try:
            print("Checking if genus file exists...")
            if not os.path.exists( genus_file_1 ):
                raise FileNotFoundError(genus_file_1)
        except FileNotFoundError as err:
            print("The genus file ({0}) does not exist. Please provide an existing file or provide the --genus while calling the Juno pipeline.".format(err) )
            sys.exit(1)
        else:
            print("Genus file present.")
        
        #GENUS added to samplesheet dict (for CheckM)
        xls = ExcelFile(pathlib.Path(genus_file_1))
        df1 = xls.parse(xls.sheet_names[0])[['Monsternummer','genus']]
        genus_dict = dict(zip(df1['Monsternummer'].values.tolist(), df1['genus'].values.tolist()))
        genus_dict = json.loads(json.dumps(genus_dict), parse_int=str) # Convert all dict values and keys to strings
    
    
        #################################################################################
        ##### Catch sample and genus errors, when not specified by the user         #####
        #################################################################################
    
        error_samples_genus = []
        error_samples_sample = []
    
        #search samples in genus dict and add genus to the SAMPLES dict
        for sample, value in SAMPLES.items():
            if str(sample) in genus_dict:
                if str(genus_dict[sample]).lower() in genuslist:
                    SAMPLES[sample] = [value,genus_dict[sample]]
    
                # Genus not recognized by checkM
                else: 
                    error_samples_genus.append(sample)
    
            # Sample not found in Excel file
            else: 
                error_samples_sample.append(sample)
    

    
        if error_samples_sample:
            print(f""" \n\nERROR: The sample(s):\n\n{chr(10).join(error_samples_sample)} \n
            Not found in the Excel file: {pathlib.Path(genus_file_1)}. 
            Please insert the samples with its corresponding genus in the Excel file before starting the pipeline.
            When the samples are in the Excel file, checkM can asses the quality of the microbial genomes. \n
            It is also possible to remove the sample that causes the error from the samplesheet, and run the analysis without this sample.\n\n""")
            sys.exit(1)
            
        if error_samples_genus:
            print(f""" \n\nERROR:  The genus supplied with the sample(s):\n\n{chr(10).join(error_samples_genus)}\n\nWhere not recognized by CheckM\n
            Please supply the sample row in the Excel file {pathlib.Path(genus_file_1)}
            with a correct genus. If you are unsure what genera are accepted by the current
            version of the pipeline, please run the pipeline using the --help-genera command to see available genera.\n\n""")
            sys.exit(1)
else:
    for sample, value in SAMPLES.items():
        SAMPLES[sample] = [value, 'checkm_deactivated']


#@################################################################################
#@#### 				Processes                                    #####
#@################################################################################

    #############################################################################
    ##### Data quality control and cleaning                                 #####
    #############################################################################
include: "bin/rules/qc_raw_data.smk"
include: "bin/rules/clean_data.smk"
include: "bin/rules/qc_clean_data.smk"
include: "bin/rules/cat_unpaired.smk"
    #############################################################################
    ##### De novo assembly                                                  #####
    #############################################################################
include: "bin/rules/run_spades.smk"

    #############################################################################
    ##### Scaffold analyses: QUAST, CheckM, picard, bbmap and QC-metrics    #####
    #############################################################################
include: "bin/rules/run_quast.smk"
if checkm_decision == 'TRUE':
    include: "bin/rules/run_checkm.smk"
    include: "bin/rules/parse_checkm.smk"
include: "bin/rules/fragment_length_analysis.smk"
include: "bin/rules/generate_contig_metrics.smk"
include: "bin/rules/parse_bbtools.smk"
include: "bin/rules/parse_bbtools_summary.smk"
if checkm_decision == 'TRUE':
    include: "bin/rules/multiqc_report.smk"
else:
    include: "bin/rules/multiqc_report_nocheckm.smk"


#@################################################################################
#@#### The `onstart` checker codeblock                                       #####
#@################################################################################

onstart:
    try:
        print("Checking if all specified files are accessible...")
        if checkm_decision == 'TRUE':
            important_files = [ config["sample_sheet"],
                         config["genuslist"],
                         'files/trimmomatic_0.36_adapters_lists/NexteraPE-PE.fa' ]
        else:
            important_files = [ config["sample_sheet"],
                         'files/trimmomatic_0.36_adapters_lists/NexteraPE-PE.fa' ]
        for filename in important_files:
            if not os.path.exists(filename):
                raise FileNotFoundError(filename)
    except FileNotFoundError as e:
        print("This file is not available or accessible: %s" % e)
        sys.exit(1)
    else:
        print("\tAll specified files are present!")
    shell("""
        mkdir -p {OUT}
        mkdir -p {OUT}/results
        echo -e "\nLogging pipeline settings..."
        echo -e "\tGenerating methodological hash (fingerprint)..."
        echo -e "This is the link to the code used for this analysis:\thttps://github.com/AleSR13/Juno_pipeline/tree/$(git log -n 1 --pretty=format:"%H")" > '{OUT}/results/log_git.txt'
        echo -e "This code with unique fingerprint $(git log -n1 --pretty=format:"%H") was committed by $(git log -n1 --pretty=format:"%an <%ae>") at $(git log -n1 --pretty=format:"%ad")" >> '{OUT}/results/log_git.txt'
        echo -e "\tGenerating full software list of current Conda environment (\"juno_master\")..."
        conda list > '{OUT}/results/log_conda.txt'
        echo -e "\tGenerating config file log..."
        rm -f '{OUT}/results/log_config.txt'
        for file in profile/*.yaml
        do
            echo -e "\n==> Contents of file \"${{file}}\": <==" >> '{OUT}/results/log_config.txt'
            cat ${{file}} >> '{OUT}/results/log_config.txt'
            echo -e "\n\n" >> '{OUT}/results/log_config.txt'
        done
    """)

#@################################################################################
#@#### These are the conditional cleanup rules                               #####
#@################################################################################

#onerror:
 #   shell("""""")


onsuccess:
    shell("""
        echo -e "\tGenerating Snakemake report..."
        snakemake --config checkm="{checkm_decision}" out="{OUT}" genus="{genus_all}" --profile profile --unlock
        snakemake --config checkm="{checkm_decision}" out="{OUT}" genus="{genus_all}" genus_file="{genus_file_1}" --profile profile --report '{OUT}/results/snakemake_report.html'
        echo -e "Finished"
    """)


#################################################################################
##### Specify final output:                                                 #####
#################################################################################

localrules:
    all,
    cat_unpaired


rule all:
    input:
        expand(str(OUT / "FastQC_pretrim/{sample}_{read}_fastqc.zip"), sample = SAMPLES, read = ['R1', 'R2']),   
        expand(str(OUT / "trimmomatic/{sample}_{read}.fastq.gz"), sample = SAMPLES, read = ['pR1', 'pR2', 'uR1', 'uR2']),
        expand(str(OUT / "FastQC_posttrim/{sample}_{read}_fastqc.zip"), sample = SAMPLES, read = ['pR1', 'pR2', 'uR1', 'uR2']),
        expand(str(OUT / "SPAdes/{sample}/scaffolds.fasta"), sample = SAMPLES),   
        str(OUT / "QUAST/report.tsv"),
        expand(str(OUT / "bbtools_scaffolds/per_sample/{sample}_MinLenFiltSummary.tsv"), sample = SAMPLES),
        str(OUT / "bbtools_scaffolds/bbtools_combined/bbtools_scaffolds.tsv"),
        str(OUT / "bbtools_scaffolds/bbtools_combined/bbtools_summary_report.tsv"),
        str(OUT / "MultiQC/multiqc.html")
