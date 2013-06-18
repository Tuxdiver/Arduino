#!/usr/bin/perl
use strict;
use warnings;

use Device::SerialPort;
use LWP::UserAgent;
use HTTP::Request;
use Data::Dumper;

$| = 1;

my %mapping = (
        '284ee6fa010000ff' => {
		name => "KG On Board",
                stream_id => '1',
        },
        '2832c4fa01000061' => {
		name => "EG Treppe",
                stream_id => '2',
        },
        '28220c7202000007' => {
		name => "DG 1",
                stream_id => '3',
        },
        '2831d1fa01000096' => {
		name => "DG 2",
                stream_id => '4',
        },
        '286502fb010000fb' => {
		name => "KG",
                stream_id => '5',
        },
        '281d1fcb0100001a' => {
		name => "KG Heizung",
                stream_id => '6',
        },
	'28c5c2fa0100000a' => {
		name => "Aquarium",
		stream_id => '7',
	},
	'28bbf27202000024' => {
		name => "Aquarium Aussen",
		stream_id => '8',
	},
);


my $quiet = 0;
my $lockfile;

# Serial-Device oeffnen
my $PortObj = new Device::SerialPort( "/dev/ttyAMA0", $quiet, $lockfile );
if ( !$PortObj ) {
    print "Try ttyUSB0\n";
    $PortObj = new Device::SerialPort( "/dev/ttyUSB0", $quiet, $lockfile );
}
if ( !$PortObj ) {
    print "Try ttyUSB1\n";
    $PortObj = new Device::SerialPort( "/dev/ttyUSB1", $quiet, $lockfile );
}
if ( !$PortObj ) {
    die "Kann Serial-Device nich oeffnen";
}
print "Serial device openend\n";

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
        #print STDERR "READ: $zeile\n";

        # Luefter gefunden?
        if ( $zeile =~ m/\A Luefter ; DREHZAHL ; (\d+) ; (\d+) \z/smx ) {
            my $id    = $1;
            my $value = $2;
            print STDERR "Found Luefter: Drehzahl=$value\n";

            # Wert in eine Datei schreiben
            my $fh;
            open $fh, ">", "/tmp/luefter.txt";
            printf $fh "%d\n", $value;
            close $fh;
        }

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
    			print STDERR "Found $value for sensor $name ($mapping{$name}->{name})\n";
                # Store:
                # Key: $mapping{$name}->{stream_id}
                # Value: $value
                my $fh;
                open $fh, ">", "/tmp/temp_${name}.txt";
                printf $fh "%d;%s;%f\n", $id, $mapping{$name}->{name}, $value;
                close $fh;
    		}
    		else {
    			print "$name not in mapping!\n";
    		}
        }
    }
}

