#!/usr/bin/perl
use RRD::Simple;
use strict;

$RRD::Simple::DEBUG=0;
$|=1;


my $dest = "/home/pi/Arduino/HausMessung/img";
my @periods = qw( hour 6hour 12hour day week month year 3years);
my %trends = ("hour"=>600, "6hour"=>1800, "12hour"=>2400, "day"=>3600, "week"=>3600*12, "month"=>3600*24*2, "year"=>3600*24*10, "3years"=>3600*24*30);


my $rrd_file_temp="/home/pi/Arduino/HausMessung/rrd/temperatur.rrd";
my $rrd_file_strom="/home/pi/Arduino/HausMessung/rrd/strom.rrd";
my $rrd_file_luefter="/home/pi/Arduino/HausMessung/rrd/luefter.rrd";

# Create an interface object
my $rrd_temp = RRD::Simple->new(
        file => $rrd_file_temp,
         );
my $rrd_strom = RRD::Simple->new(
        file => $rrd_file_strom,
         );
my $rrd_luefter = RRD::Simple->new(
        file => $rrd_file_luefter,
         );





my @wanted_temp = ("KGHeizung","KGOnBoard","KG", "EGTreppe", "DG1", "DG2", "Aquarium");
my @wanted_strom = reverse qw (Strom);
my @wanted_luefter = reverse qw (Luefter);

my @dsnames_temp = $rrd_temp->sources;
my @dsnames_strom = $rrd_strom->sources;
my @dsnames_luefter = $rrd_luefter->sources;

my %dsnames_temp = map { $_ => 1 } @dsnames_temp;
my %dsnames_strom = map { $_ => 1 } @dsnames_strom;
my %dsnames_luefter = map { $_ => 1 } @dsnames_luefter;

@wanted_temp = grep { $dsnames_temp{$_} } @wanted_temp;
@wanted_strom = grep { $dsnames_strom{$_} } @wanted_strom;
@wanted_luefter = grep { $dsnames_luefter{$_} } @wanted_luefter;



foreach my $period (@periods) {
        my $trend=$trends{$period};

	print "Generate temps $period\n";
	$rrd_temp->graph(
	        destination => "$dest/temp",
       	 	extended_legend => 1,
		periods => [ $period ],
		sources => [ grep { $_ ne "KGHeizung" } @wanted_temp ],
		width=>500,
		height=>200,
	);

	print "Generate heating $period\n";
	$rrd_temp->graph(
        	destination => "$dest/temp",
        	extended_legend => 1,
		periods => [ $period ],
		sources => [ "KGHeizung" ],
		basename => "heizung",
		width=>500,
		height=>200,
		);

	print "Generate luefter $period\n";
	$rrd_luefter->graph(
        	destination => "$dest/luefter",
        	extended_legend => 1,
		periods => [ $period ],
		sources => [ qw(Luefter) ],
		basename => "luefter",
		width=>500,
		height=>200,
		);

    print "Generate strom $period\n";
    $rrd_strom->graph(
                destination => "$dest/strom",
                extended_legend => 1,
                periods => [ $period ],
                sources => [ @wanted_strom ],
                source_drawtypes => { Strom => "LINE",
                                   },
                 width=>500,
                 height=>200,
                 lower_limit=>0,
                 "CDEF:smoothed=Strom,$trend,TREND" => 1,
                 'AREA:smoothed#99ff99:Mittel' => 1,
        );
}
