Nagios Checks
=============

This is just a dumping ground of handy Nagios checks I've written, or modified.
If you find it useful, consider forking this project, adding any of your own, 
and submitting a pull request to add to the list.

Existing Checks
---------------

* check\_redis\_save - Checks to ensure that redis has saved to disk recently. Configurable warning and critical thresholds.
* check\_redis\_slave.sh - Checks to make sure that this redis server either slaves off a connected master, or is a master with connected slaves.