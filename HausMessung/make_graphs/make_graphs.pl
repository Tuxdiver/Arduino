#!/opt/bin/perl
use RRD::Simple;
use strict;

$RRD::Simple::DEBUG=0;
$|=1;

system("/volume1/opt/rrd/stromgraph.sh");

my $dest = "/volume1/web";
my @periods = qw( hour 6hour 12hour day week month year 3years);
my %trends = ("hour"=>600, "6hour"=>1800, "12hour"=>2400, "day"=>3600, "week"=>3600*12, "month"=>3600*24*2, "year"=>3600*24*10, "3years"=>3600*24*30);


my $rrd_file_temp="/volume1/opt/rrd/temperatur.rrd";
my $rrd_file_strom="/volume1/opt/rrd/strom.rrd";

# Create an interface object
my $rrd_temp = RRD::Simple->new(
        file => $rrd_file_temp,
         );
my $rrd_strom = RRD::Simple->new(
        file => $rrd_file_strom,
         );





my @wanted_temp = reverse qw (Heizung OnBoard Keller Erdgeschoss Wohnzimmer Dach);
my @wanted_strom = reverse qw (Strom);

my @dsnames_temp = $rrd_temp->sources;
my @dsnames_strom = $rrd_strom->sources;

my %dsnames_temp = map { $_ => 1 } @dsnames_temp;
my %dsnames_strom = map { $_ => 1 } @dsnames_strom;

@wanted_temp = grep { $dsnames_temp{$_} } @wanted_temp;
@wanted_strom = grep { $dsnames_strom{$_} } @wanted_strom;



foreach my $period (@periods) {
        my $trend=$trends{$period};
        
	print "Generate temps $period\n";
	$rrd_temp->graph(
	        destination => $dest,
       	 	extended_legend => 1,
		periods => [ $period ],
		sources => [ grep { $_ ne "Heizung" } @wanted_temp ],
		width=>500,
		height=>150,
	);

	print "Generate heating $period\n";
	$rrd_temp->graph(
        	destination => $dest, 
        	extended_legend => 1,
		periods => [ $period ],
		sources => [ qw(Heizung) ],
		basename => "heizung", 
		width=>500,
		height=>200,
		);

        print "Generate strom $period\n";
        $rrd_strom->graph(
                destination => $dest,
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
                # 'CDEF:predict=8640,-2,1800,Strom,PREDICT'=>1,
                # 'LINE:predict#0000ff;Vorher'=>1,
                #  end=>"now+${trend}sec",
        ); 
}
