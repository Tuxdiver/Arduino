#!/usr/bin/perl
use RRD::Simple;
use strict;
use CGI;

$RRD::Simple::DEBUG=0;
$|=1;
if (!-d "/run/shm/HausMessung/img/") {
	system("mkdir -p /run/shm/HausMessung/img/");
}

my $q = new CGI;

#my $dest = "/home/pi/Arduino/HausMessung/img";
my $dest = "/run/shm/HausMessung/img";
#my @periods = qw( hour 6hour 12hour day week month year 3years);
my @periods = qw( hour day week );
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





my @wanted_temp = ("KGHeizung","KGOnBoard","KG", "EGTreppe", "DG1", "DG2", "Aquarium","AquariumAussen");
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

my $mtime=(stat "$dest/aquarium-hourly.png")[9];

if (time() - $mtime > 120) {
foreach my $period (@periods) {
        my $trend=$trends{$period};

#	print "Generate temps $period\n";
	$rrd_temp->graph(
	        destination => "$dest",
       	 	extended_legend => 1,
		periods => [ $period ],
		sources => [ grep { $_ ne "KGHeizung" } @wanted_temp ],
		width=>500,
		height=>200,
		#upper_limit => 35,
         	#lower_limit => 15,
	);

#	print "Generate heating $period\n";
	$rrd_temp->graph(
        	destination => "$dest",
        	extended_legend => 1,
		periods => [ $period ],
		sources => [ "KGHeizung" ],
		basename => "heizung",
		width=>500,
		height=>200,
		);

#        print "Generate aquarium $period\n";
        $rrd_temp->graph(
                destination => "$dest",
                extended_legend => 1,
                periods => [ $period ],
                sources => [ "Aquarium" , "AquariumAussen"],
                basename => "aquarium",
                width=>500,
                height=>200,
		#upper_limit => 35,
         	#lower_limit => 15,
                );

#	print "Generate luefter $period\n";
	$rrd_luefter->graph(
        	destination => "$dest",
        	extended_legend => 1,
		periods => [ $period ],
		sources => [ qw(Luefter) ],
		basename => "luefter",
		width=>500,
		height=>200,
		);

#    print "Generate strom $period\n";
#    $rrd_strom->graph(
#                destination => "$dest",
#                extended_legend => 1,
#                periods => [ $period ],
#                sources => [ @wanted_strom ],
#                source_drawtypes => { Strom => "LINE",
#                                   },
#                 width=>500,
#                 height=>200,
#                 lower_limit=>0,
#                 "CDEF:smoothed=Strom,$trend,TREND" => 1,
#                 'AREA:smoothed#99ff99:Mittel' => 1,
#        );
}
}

print $q->header('Hausmessung'), $q->start_html('Hausmessung');
print << "_EOF_";
<h1>Hausmessung</H1>
<h3>Aquarium</h3>
<img src="/hausmessung/img/aquarium-hourly.png">
<img src="/hausmessung/img/aquarium-daily.png">
<img src="/hausmessung/img/aquarium-weekly.png"><br>
<H3>Temperaturen</H3>
<img src="/hausmessung/img/temperatur-hourly.png">
<img src="/hausmessung/img/temperatur-daily.png">
<img src="/hausmessung/img/temperatur-weekly.png"><br>
<h3>L&uuml;fter</h3>
<img src="/hausmessung/img/luefter-hourly.png">
<img src="/hausmessung/img/luefter-daily.png">
<img src="/hausmessung/img/luefter-weekly.png"><br>
<h3>Heizung</h3>
<img src="/hausmessung/img/heizung-hourly.png">
<img src="/hausmessung/img/heizung-daily.png">
<img src="/hausmessung/img/heizung-weekly.png"><br>
_EOF_
print $q->end_html();

