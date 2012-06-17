#!/usr/bin/perl
use strict;
use warnings;

use Device::SerialPort;
use LWP::UserAgent;
use HTTP::Request;
use Data::Dumper;

my $api_key = $ENV{COSM_API_KEY} // die "ENV-Variable COSM_API_KEY not set!";
my $feed_id = '62684';

$| = 1;

my %mapping = (
        '284ee6fa010000ff' => { 
		name => "KG: On Board",
                stream_id => '1',
        },
        '2832c4fa01000061' => { 
		name => "EG: Treppe",
                stream_id => '2',
        },
        '28220c7202000007' => { 
		name => "DG: 1",
                stream_id => '3',
        },
        '2831d1fa01000096' => { 
		name => "DG: 2",
                stream_id => '4',
        },
        '286502fb010000fb' => { 
		name => "KG",
                stream_id => '5',
        },
        '281d1fcb0100001a' => { 
		name => "KG: Heizung",
                stream_id => '6',
        },

);


my $quiet = 0;
my $lockfile;

# Serial-Device oeffnen
my $PortObj = new Device::SerialPort( "/dev/ttyUSB0", $quiet, $lockfile );
if ( !$PortObj ) {
    print "Try ttyUSB1\n";
    $PortObj = new Device::SerialPort( "/dev/ttyUSB1", $quiet, $lockfile );
}
if ( !$PortObj ) {
    die "Kann Serial-Device nich oeffnen";
}
my %last_data;

# Port konfigurieren
$PortObj->baudrate(57600);
$PortObj->read_const_time(10);

my $count_in;
my $string_in;
my $InBytes = 64;
my $string;

# Endlos-Loop
while (1) {

    # Zeichen lesen
    ( $count_in, $string_in ) = $PortObj->read($InBytes);
    $string .= $string_in;

    # Wenn schon ein "\n" enthalten ist, die gelesene Zeile verarbeiten

    if ( $string =~ /\n/smx ) {
        $string =~ s/\A (.*?) \n (.*) \z/$2/smx;
        my $zeile = $1;
        # print STDERR "READ: $zeile\n";

        # Stromwert gefunden?
        if ( $zeile =~ m/\A Strom ; WATT ; (\d+) ; (\d+) \z/smx ) {
            my $id    = $1;
            my $value = $2;
            print STDERR "Found Strom: Watt=$value\n";

            # Wert in eine Datei schreiben
            my $fh;
            open $fh, ">", "/tmp/watt.txt";
            printf $fh "%d\n", $value;
            close $fh;
        }

        if ( $zeile =~ m/\A Temp ; (\d+) ; (\d+\.\d+) ; (.*) \z/smx ) {
            my $id    = $1;
            my $value = $2;
            my $name  = $3;

		if (exists $mapping{$name}) {
			if (!exists $last_data{$name} || $last_data{$name}->{time} + 60 < time()) {
				print STDERR "Send $value for $name to cosm\n";
				my $result = send_to_cosm({data=>[$mapping{$name}->{stream_id} => $value], 
					api_key=>$mapping{$name}->{api_key} // $api_key, 
					method=>'PUT', 
					feed_id => $mapping{$name}->{feed_id} // $feed_id,
				});
				if (!$result) {
					print "Update of cosm failed!\n";
				} else {
					$last_data{$name}={value=>$value, time=>time()};
				}
			}
		}
		else {
			print "$name not in mapping!\n";
		}
        }
    }
}

sub send_to_cosm {
	my $options = shift;

	my $api_key = $options->{api_key};
	my $method = $options->{method};
	my $feed_id = $options->{feed_id};
	my $url = 'http://api.cosm.com/v2/feeds/'.$feed_id.'.csv';
	my @data = @{$options->{data}};

	my $ua = LWP::UserAgent->new();
	$ua->default_header('X-ApiKey' => $api_key);
	my $request = HTTP::Request->new($method => $url);
	$request->content(join(",", @data));
	#print Dumper $ua;
	#print Dumper $request;
	my $resp =  $ua->request($request);
	#print Dumper $resp;

	return $resp->is_success;
}

