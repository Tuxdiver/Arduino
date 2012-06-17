#!/opt/bin/perl
use strict;
use Data::Dumper;

my @temp;


%mapping = (


);

foreach my $file (glob("/tmp/temp_*.txt")) {
    print "Reading file $file\n";

    open my $in, "<", $file;
    while(<$in>){
        chomp();
        my ($num,$ort,$temperatur) = split(/;/);
        push @temp, [$ort,$temperatur];
    }
    close $in;
    unlink $file;
}

if (scalar(@temp)) {
    $temp_rrd->update(map { $_->[0]=>$_->[1] } @temp );
	print Dumper(\@temp);
}


# Watt lesen
my @data=();
foreach my $file (glob("/tmp/watt.txt*")) {
	print "Reading file $file\n";
	open my $in, "<", $file;     
	my $ds = "Strom";
	while(<$in>){
	       	chomp();
        	push @data, [$ds,$_];
	}
	close $in;
	unlink $file;         
}                                                                                                 

if(scalar(@data)) {
        $strom_rrd->update(map { $_->[0]=>$_->[1] } @data );
	print Dumper(\@data);
}

