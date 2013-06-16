#!/usr/bin/perl
use strict;
use RRD::Simple;
use Data::Dumper;

my $temp_rrd_file="/home/pi/Arduino/HausMessung/rrd/temperatur.rrd";
my $luefter_rrd_file="/home/pi/Arduino/HausMessung/rrd/luefter.rrd";
my $strom_rrd_file="/home/pi/Arduino/HausMessung/rrd/strom.rrd";

# Create an interface object
my $temp_rrd = RRD::Simple->new(
        file => $temp_rrd_file,
        cf => [qw(LAST AVERAGE MIN MAX)],
        default_dstype => "GAUGE",
        on_missing_ds => "add",
         );

# Create an interface object
my $luefter_rrd = RRD::Simple->new(
        file => $luefter_rrd_file,
        cf => [qw(LAST AVERAGE MIN MAX)],
        default_dstype => "GAUGE",
        on_missing_ds => "add",
         );


# Create an interface object
my $strom_rrd = RRD::Simple->new(
        file => $strom_rrd_file,
        cf => [qw(LAST AVERAGE MIN MAX)],
        default_dstype => "COUNTER",
        on_missing_ds => "add",
         );
 
if (!-f $strom_rrd_file) {
        $strom_rrd->create( $strom_rrd_file, "3years", "Strom"=>"GAUGE", "Strom_data"=>"COUNTER");
}

if (!-f $luefter_rrd_file) {
        $luefter_rrd->create( $luefter_rrd_file, "3years", "Luefter"=>"GAUGE" );
}


my @temp;
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
    if (!-f $temp_rrd_file) {
            $temp_rrd->create( $temp_rrd_file, "3years", map { $_->[0] => "GAUGE" } @temp);
    }

    $temp_rrd->update(map { $_->[0]=>$_->[1] } @temp );
	print Dumper(\@temp);
}

my @luefter;
foreach my $file (glob("/tmp/luefter.txt*")) {
    print "Reading file $file\n";
    open my $in, "<", $file;
    while(<$in>){
        chomp();
        push @luefter, ["Luefter",$_];
    }
    close $in;
    unlink $file;
}

if (scalar(@temp)) {
    $luefter_rrd->update(map { $_->[0]=>$_->[1] } @luefter );
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

