#
#
use diagnostics;
use Getopt::Long;
use Data::Dumper;
my $infile = "";
GetOptions(
	"file=s" => \$infile)
or die("Error!");
unless (-e $infile)
# e: existance
{
	print STDERR  "Use --file InputFile, where InputList is a file with an ID\n";
	exit 1;
}

open(IN, $infile);
while(<IN>){
	chomp;
	$uniprotid = $_;
	my $outfile = $uniprotid."_mobi.json";
	my $outfile2 = $uniprotid."_mobi.hash";
	print $uniprotid." ";
	open(OUT, ">", $outfile);
	open(OUT2, ">", $outfile2);
	my $outdata = '$ROOT={"MOBIDB" => '.qx(python mobidb-get.py -i $uniprotid -m -c).",\n";
	$outdata .= '"DISORDER" => '.qx(python mobidb-get.py -i $uniprotid -d -c).",};\n";

	print OUT $outdata;

	$outdata =~ s/:/=>/g;
	print OUT2 $outdata;

	my $ROOT = eval $outdata;
	if ($ROOT -> {MOBIDB} -> {length}){
		parserProc($ROOT);
	}else{
		print " ID not found!\n";
	}
	close OUT;
	close OUT2;
}
close IN;


sub parserProc{
	my $ROOT=shift;

	my $protlength = $ROOT -> {MOBIDB} -> {length};
	print "(Length=".$protlength.")\n";
	my @score = map {0} 1..$protlength;
	my @iupred = map {0} 1..$protlength;
	my @iupredRes = ();
	foreach my $predIndex ( @{ $ROOT -> {DISORDER} -> {predictors} }){
		#print Dumper($predIndex)."\n";
		my $iup=0;
		if ($predIndex -> {pred} eq "iupl"){
			$iup=1;
		}
		foreach my $rangeHash ( @{ $predIndex -> {anns}}){
			if ($rangeHash -> {ann} eq "d"){
				my $start = $rangeHash -> {start} -1;
				my $end = $rangeHash -> {end} -1;
				for($start..$end){
					$score[$_]++;
					if($iup == 1){
						$iupred[$_]++;
					}
				}
			}
		}
	}
	
	my $lengthS=0;
	my $lengthC=0;
	my $lengthD=0;
	my @PdbRes = ();
	foreach my $pdbs ( @{ $ROOT -> {DISORDER} -> {consensus} -> {pdb}})
	{
		my $start = $pdbs -> {start};
		my $end = $pdbs -> {end};
		my $ann = $pdbs -> {ann};
		if($ann eq "S"){
			$lengthS += ($end-$start)+1;
		}
		elsif($ann eq "C"){
			$lengthC += ($end-$start)+1;
		}
		elsif($ann eq "S"){
			$lengthD += ($end-$start)+1;
		}
	}
	printf "%.2f%% PDB coverage, ", (($lengthS+$lengthC+$lengthD)/$protlength*100);
	printf "(%.2f%% ordered PDB region)\n", (($lengthS)/$protlength*100);
	push(@PdbRes, (($lengthS+$lengthC+$lengthD)/$protlength*100));
	
	#print Dumper(\@score);
	my $diff=0;
	for(my $i=0; $i<$protlength; $i++){
		if($iupred[$i] == 1){
			if($score[$i] <= 5){
				$diff++;
			}
		}else{
			if($score[$i] > 5){
				$diff++;
			}
		}
	}
	printf  "%.2f%% IUPred disagreement\n", ($diff/$protlength*100);
	push(@iupredRes, ($diff/$protlength*100));
	
	open (OUTP, ">>", "PDBcoverage_raw.txt");
	open (OUTI, ">>", "IUPredDisagr_raw.txt");
	foreach my $i (@PdbRes){
		printf OUTP "%.2f%%, ", $i;
	}
	foreach my $i (@iupredRes){
		printf OUTI "%.2f%%, ", $i;
	}
	close OUTP;
	close OUTI;
}

