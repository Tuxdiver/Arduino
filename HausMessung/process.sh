#/bin/sh

while true; do 
	./update_rrd/update_rrd.pl 
	sleep 50
	./update_rrd/update_rrd.pl 
	sleep 50
	./update_rrd/update_rrd.pl 
	sleep 50
	./update_rrd/update_rrd.pl 
	sleep 50
	./update_rrd/update_rrd.pl 
	sleep 50
	./update_rrd/update_rrd.pl 
	sleep 50
	./update_rrd/update_rrd.pl 
	sleep 50
	./update_rrd/update_rrd.pl 
	sleep 50
	./update_rrd/update_rrd.pl 
	sleep 50
	./update_rrd/update_rrd.pl 
	sleep 20
	./make_graphs/make_graphs.pl
done

