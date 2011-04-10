#!/opt/bin/perl
use strict;
use warnings;

use Device::SerialPort;

$| = 1;

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
        print "READ: $zeile\n";

        # Stromwert gefunden?
        if ( $zeile =~ m/\A STROM ; WATT ; (\d+) ; (\d+) \z/smx ) {
            my $id    = $1;
            my $value = $2;

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

            my $fh;
            open $fh, ">", "/tmp/temp_${id}.txt";
            printf $fh "%d\n", $value;
            close $fh;
        }
    }
}
