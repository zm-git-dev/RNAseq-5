#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

# perl pipeline.pl -i <INPUT> -o <OUTPUT> -g <GENOME> -p <PART> -r <RUNID>
## ARGUMENTS:
	### -i : input ... Directory containing all fastq files to be run through pipeline
	### -o : output ... Directory where all output files will be organized and saved
	### -g : genome build ... Genome build to be used. "u" for UCSC, "e" for Ensembl, "n" for NCBI
	### -p : part ... part of the pipeline to be completed. 1 => Tophat and Cufflinks, 2 => Cuffmerge and Cuffquant, 3 => Cuffnorm
	### -r : runID ... unique runID used to identify and organize outputs from a given run

# Three commands for entire pipeline:
## Part 1:
	### perl pipeline.pl -i /home/kanagarajm/fq_batch/ -o /mnt/speed/kanagarajM/pipeline_batch/ -g u -p 1 -r 72414
## Part 2:
	### perl pipeline.pl -i /home/kanagarajm/fq_batch/ -o /mnt/speed/kanagarajM/pipeline_batch/ -g u -p 2 -r 72414
## Part 3: 
	### perl pipeline.pl -i /home/kanagarajm/fq_batch/ -o /mnt/speed/kanagarajM/pipeline_batch/ -g u -p 3 -r 72414

## If you are interested in using cuffdiff for differential expression analysis, use this command after completing Part 2:
	### perl pipeline.pl -i /mnt/speed/kanagarajM/pipeline_batch/cq-out/ -o /mnt/speed/kanagarajM/pipeline_batch/ -g u --cd -r 72414


my ( $input, $output, $genomeType, $part, $cd, $runID, $t, $tc );
$part = 0;

GetOptions(	
	'o=s' => \$output,
	'i=s' => \$input,
	'g=s' => \$genomeType,
	'p=i' => \$part,
	'cd' => \$cd,
	'r=i' => \$runID
) or die "Incorrect input and/or output path!\n";

# String checks and manipulation
die "Invalid part number\n" unless ($part =~ /^[0123]$/);
die "Invalid genome type\n" unless ($genomeType =~ /^[uen]$/i);

$input =~ s/.$// if (substr($input, -1, 1) eq "/");
$output = $output . "/" if (substr($output, -1, 1) ne "/"); 

### MAIN ###
if ($part == 1) {

	# Glob all fq.gz files to be run in parallel and processed through the Sun Grid Engine (IHG-Cluster) using the qsub command to execute tophat and cufflinks
	my $suffix = "*.fq.gz";
	my @size = glob("$input/$suffix");
	$tc = scalar(@size);
	$t = "1-".$tc;
	if ($tc > 100) { $tc = 75; }

	`qsub -t $t -tc $tc -v ARG1=$input,ARG2=$output,ARG3=$genomeType,ARG4=$part,ARG5=$runID,ARG6=$suffix submit_pipeline.sh`;
}
elsif ($part == 2){

	# After all samples have been processed in part 1, merge their transcripts using Cuffmerge before proceeding to cuffquant step
	`perl run_pipeline.pl -i $input -o $output -g $genomeType -p $part -r $runID --cm`;

	# Glob all relevant tophat output directories and run in parallel through Sun Grid Engine using qsub command to execute cuffquant
	my $suffix = "th-out/th-out_*_$runID";
	my @size = glob("$output/$suffix");
	$tc = scalar(@size);
	$t = "1-".$tc;
	if ($tc > 100) { $tc = 75; }

	`qsub -t $t -tc $tc -v ARG1=$output,ARG2=$output,ARG3=$genomeType,ARG4=$part,ARG5=$runID,ARG6=$suffix submit_pipeline.sh`;
}
elsif ($part == 3){

	# After all samples have been run through cuffquant in Step 2, submit cuffnorm job to Sun Grid Engine
	`qsub -pe parallel 8 -V -S /usr/bin/perl run_pipeline.pl -i $input -o $output -g $genomeType -p $part -r $runID`;
}

# Should differential expression analysis be of interest, submit cuffdiff job to Sun Grid Engine after completing Step 2
# Specify input as a directory containing cq-out folders for samples of interest
if ($cd){
	`qsub -pe parallel 8 -V -S /usr/bin/perl run_pipeline.pl -i $input -o $output -g $genomeType -r $runID --cd`;
}



