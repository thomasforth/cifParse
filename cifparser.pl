use strict;
#use warnings;

# Written by thomas.forth@gmail.com see more at www.tomforth.co.uk
# This script is absolutely completely open-source, you can do whatever you want with it.
# Saying that, it would be nice if you acknowledged me and even nicer if you let me know what you're doing in case I can help!
# Ps. The coding style is inefficient and long but it should be easy to follow what's happening. I output files at each step so you can step what's going on.

&shortenCIF;
&parseCIF;
	
sub shortenCIF{
	print "shortening CIF file...\n";
	open (CIFIN, "ATCO_450_BUS.CIF");
	open (CIFOUT, ">temp_shortened.CIF");

	# get rid of lines starting QE or QI followed by a letter, I don't need them
	while (<CIFIN>) {
		if (($_ =~ m/^QE/) | ($_ =~ m/^QI\d*[A-Z]+\d*\s/)) { # but maybe I do need them outside W. Yorkshire?
			#print $_;
		}
		else {
			print CIFOUT $_;
		}
	}
	close (CIFIN);
	close (CIFOUT);

	open(CIF, "temp_shortened.CIF");

	#writes extracts routes, directions, start and end lines in CIF file
	open(ROUTES, ">routes.txt");
	my $firstentry  = 1;
	while(<CIF>) {	
		if ($_ =~ m/(^QSN.*)/) { #could this also be W. Yorks specific?
			if ($firstentry == 1) {$firstentry = 0;}
			else {
				my $endpos = $.-1;
				print ROUTES "$endpos\n";
			}
			chomp $_;
			my $routeline = $1;
			my @route = split(/\s+/, $routeline);
			my $routecode = $route[2];
			my $directioncode = $route[4];
			
			my $startpos = $. + 1;
			print ROUTES "$routecode\t$directioncode\t$startpos\t";
			
		}
		if ($.%100000 == 0) {
			my $percentdone = 100 * $. / 2308540;
			$percentdone =~ s/\.\d*//;
			print "$percentdone % done \n";
		}
	}
	close(ROUTES);
	close(CIF);

	#de-duplicates routes by selecting the longest one and returns start and end lines for that
	open (ROUTES, "routes.txt");
	open (LONGESTUNIQUE, ">uniqueroutes.txt");

	my %routelength;
	my %routestart;
	my %routeend;
	while(<ROUTES>) {
		chomp $_;
		my @line = split(/\t/, $_);
		if ($line[3] - $line[2] > $routelength{$line[0]."\t".$line[1]}) {
			$routelength{$line[0]."\t".$line[1]} = $line[3] - $line[2];
			$routestart{$line[0]."\t".$line[1]} = $line[2];
			$routeend{$line[0]."\t".$line[1]} = $line[3];
		}
	}

	foreach (sort keys  %routelength)	{
		print LONGESTUNIQUE "$_\t$routestart{$_}\t$routeend{$_}\n";
	}
	close(ROUTES);
	close(LONGESTUNIQUE);
	print "Done!\n";
}

sub parseCIF{
	print "parsing shortened CIF file...\n";
	#returns an ordered list of NaPTaN codes for each busroute
	open (LONGESTUNIQUE, "uniqueroutes.txt");
	open (CIF, "temp_shortened.CIF");
	open (NAPTAN, "NaPTAN_complete.txt");
	open (ROUTES, ">routetable.txt");

	#load NaPTAN details into hashes keyed by bus-stop code
	my %naptancommonname;
	my %naptanlon;
	my %naptanlat;
	my %naptanarea;
	while (<NAPTAN>) {
		chomp $_;
		my @naptanline = split(/\t/, $_);
		$naptancommonname{$naptanline[0]} = $naptanline[1];
		$naptanlon{$naptanline[0]} = $naptanline[2];
		$naptanlat{$naptanline[0]} = $naptanline[3];
		$naptanarea{$naptanline[0]} = $naptanline[4];
	}	

	#print out a database-style table
	my @cif = (<CIF>); #loading the whole file into an array is inefficient but it works
	my @routes = (<LONGESTUNIQUE>);
	foreach (@routes)  {
		my @routedetails = split(/\t/,$_);
		my $route = $routedetails[0].$routedetails[1];
		my $stopcounter = 0;
		for (my $i = $routedetails[2] - 1; $i <= $routedetails[3]; $i++) {
			$cif[$i] =~ m/Q[OIT](\d+)/;
			my $stopcode = $1;
			#$stopcode =~ s/^4500/450/; #I don't think I need this any more
			if (exists($naptancommonname{$stopcode})) {			
				print ROUTES "$route\t$stopcounter\t$stopcode\t$naptancommonname{$stopcode}\t$naptanarea{$stopcode}\t$naptanlon{$stopcode}\t$naptanlat{$stopcode}\n";
				$stopcounter++;
			}
		}
	}

	#print out a javascript file with the information in arrays
	#I know this repeats some stuff from the previous code block but I prefer longer code to complicated code :)
	open(JAVASCRIPT, ">rawdata3.js");
	
	my $minlong = 1000;
	my $maxlong = -1000;
	my $minlat = 1000;
	my $maxlat = -1000;
	
	my %routecodeshash;
	foreach (@routes)  {
		my @routedetails = split(/\t/,$_);
		my $route = $routedetails[0].$routedetails[1];
		$routecodeshash{$route} = 1;
		my $stopcounter = 0;
		my @stopcodes = [];
		my @stopnames = [];
		my @stoplons = [];
		my @stoplats = [];
		my @stopareas = [];
		for (my $i = $routedetails[2] - 1; $i <= $routedetails[3]; $i++) {
			$cif[$i] =~ m/Q[OIT](\d+)/; # this works for W. Yorkshire but probably not elsewhere!
			my $stopcode = $1;
			#$stopcode =~ s/^4500/450/;
			if (exists($naptancommonname{$stopcode})) { #stopcodes are all eight long
				$stopcodes[$stopcounter] = $stopcode;
				$stopnames[$stopcounter] = '"'.$naptancommonname{$stopcode}.'"';
				$stoplons[$stopcounter]  = ($naptanlon{$stopcode});
				$stoplats[$stopcounter]  = ($naptanlat{$stopcode});
				$stopareas[$stopcounter] = '"'.$naptanarea{$stopcode}.'"';
				$stopcounter++;
				#find range of longs and lats
				if ($naptanlon{$stopcode} < $minlong){ $minlong = $naptanlon{$stopcode}};
				if ($naptanlon{$stopcode} > $maxlong){ $maxlong = $naptanlon{$stopcode}};
				if ($naptanlat{$stopcode} < $minlat){ $minlat = $naptanlat{$stopcode}};
				if ($naptanlat{$stopcode} > $maxlat){ $maxlat = $naptanlat{$stopcode}};
			}
		}
		#print out accumulated arrays only if they exist (longer than 1>		
		jsprint("codes", \@stopcodes, $route, $stopcounter);
		jsprint("labels", \@stopnames, $route, $stopcounter);
		jsprint("xcoords", \@stoplons, $route, $stopcounter);
		jsprint("ycoords", \@stoplats, $route, $stopcounter);
		jsprint("areas", \@stopareas, $route, $stopcounter);
	}
	
	#create list of routes
	my %stringsroutecodeshash;
	my %codeslist;
	my %labelslist;
	my %areaslist;
	my %xcoordslist;
	my %ycoordslist;
	my %colourslist;

	foreach (keys %routecodeshash) {
		$stringsroutecodeshash{'"'.$_.'"'} = 1;
		$codeslist{"codes".$_} = 1;
		$labelslist{"labels".$_} = 1;
		$areaslist{"areas".$_} = 1;
		$xcoordslist{"xcoords".$_} = 1;
		$ycoordslist{"ycoords".$_} = 1;
		$colourslist{$_} = '"blue"';
	}
	my @routecodes = sort keys %stringsroutecodeshash;
	my @codeslist = sort keys %codeslist;
	my @labelslist = sort keys %labelslist;
	my @areaslist = sort keys %areaslist;
	my @xcoordslist = sort keys %xcoordslist;
	my @ycoordslist = sort keys %ycoordslist;
	my @colourslist = values %colourslist;
		
	jsprint("routes", \@routecodes, "", scalar(@routecodes));
	jsprint("codeslist", \@codeslist, "", scalar(@codeslist));
	jsprint("labelslist", \@labelslist, "", scalar(@labelslist));
	jsprint("areaslist", \@areaslist, "", scalar(@areaslist));
	jsprint("xcoordslist", \@xcoordslist, "", scalar(@xcoordslist));
	jsprint("ycoordslist", \@ycoordslist, "", scalar(@ycoordslist));
	jsprint("colourlist", \@colourslist, "", scalar(@colourslist));
	print JAVASCRIPT "var minlong = $minlong;\n"; #min long
	print JAVASCRIPT "var maxlong = $maxlong;\n";  #max long
	print JAVASCRIPT "var minlat = $minlat;\n"; # print JAVASCRIPT #min lat
	print JAVASCRIPT "var maxlat = $maxlat;\n"; # print JAVASCRIPT #max lat		
	
	close (CIF);
	close (LONGESTUNIQUE);
	close (NAPTAN);
	close (ROUTES);

	sub jsprint {
		if (scalar($_[3])>1) {
			print JAVASCRIPT "var " .$_[0] . $_[2] . " = [";
			for (my $i = 0 ; $i < $_[3] - 1; $i++) {
				print JAVASCRIPT $_[1][$i] . ",";	
			}
			print JAVASCRIPT $_[1][$_[3] - 1]; #GET RID OF THE LAST COMMA
			print JAVASCRIPT "];\n"; 
		}
		else {
			print JAVASCRIPT "var " .$_[0] . $_[2] . " = [";
			print JAVASCRIPT "];\n"; 
		}
	}
}

print "The script will now try to load index.html to visualise the parsed data.\n";
print "If index.html does not load, open it manually.";
exec("index.html");