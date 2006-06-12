#!/usr/bin/perl
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
# $Id$
# arp-fingerprint.pl -- Perl script to fingerprint system with arp-scan
#
# Author: Roy Hills
# Date: 30th May 2006
#
# This script uses arp-scan to fingerprint the operating system on the
# specified target.
#
# It sends various different ARP packets to the target, and records which
# ones it responds to.  From this, it constructs a fingerprint string
# which is used to match against a hash containing known fingerprints.
#
use warnings;
use strict;
use Getopt::Std;
#
# You might need to change this to suit your configuration
# You can change the interface by defining RMIF, e.g.
# RMIF=eth1 arp-fingerprint.pl 192.168.0.1
my $arpscan="arp-scan -N -q -r 1";
#
# Hash of known fingerprints
#
# These fingerprints were observed on:
#
# FreeBSD 4.3	FreeBSD 4.3 on VMware
# Win98		Windows 98 SE on VMware
# NT4		Windows NT Workstation 4.0 SP6a on Pentium
# 2000		Windows 2000
# XP		Windows XP Professional SP2 on Intel P4
# 2003		Windows 2003 Server SP1 on Intel P4
# Linux 2.0	Linux 2.0.29 on VMware (debian 1.3.1)
# Linux 2.2	Linux 2.2.19 on VMware (debian potato)
# Linux 2.4	Linux 2.4.29 on Intel P3 (debian sarge)
# Linux 2.6	Linux 2.6.15.7 on Intel P3 (debian sarge)
# Cisco IOS	IOS 12.1(27b) on Cisco 2621, IOS 12.3(15) on Cisco 2503
# Solaris 7	Solaris 7 (x86) on VMware
# Solaris 9	Solaris 9 (SPARC) on Sun Ultra 5
# ScreenOS 5.0	ScreenOS 5.0.0r9 on NetScreen 5XP
# MacOS 10.4	MacOS 10.4.6 on powerbook G4
# MacOS 10.3	MacOS 10.3.9 on imac G3
# IRIX 6.5	IRIX64 IRIS 6.5 05190004 IP30 on SGI Octane
# SCO OS	SCO OpenServer 5.0.7 on VMware
# Win 3.11	Windows for Workgroups 3.11/DOS 6.22 on VMware
# 95		Windows 95 OSR2 on VMware
# NT 3.51	Windows NT Server 3.51 SP0 on VMware
# OpenBSD	OpenBSD 3.1 on VMware
# NetBSD	NetBSD
# IPSO		IPSO 3.2.1-fcs1 on Nokia VPN 210
#
my %fp_hash = (
   '11110100000' => 'FreeBSD, Win98, NT4, 2000, XP, 2003',
   '01000100000' => 'Linux 2.2, 2.4, 2.6',
   '01010100000' => 'Linux 2.2, 2.4, 2.6',	# If non-local IP is routed
   '00000100000' => 'Cisco IOS',
   '11110110000' => 'Solaris 7, 9',
   '01000111111' => 'ScreenOS 5.0',
   '11110000000' => 'Linux 2.0, MacOS 10.4, IPSO',
   '11110100011' => 'MacOS 10.3, FreeBSD 4.3, IRIX 6.5',
   '10010100011' => 'SCO OS',
   '10110100000' => 'Win 3.11, 95, NT 3.51',
   '11110000011' => 'OpenBSD',
   '10110110000' => 'NetBSD',
   '00010110011' => 'Unknown 1', # dwk at 7663 in June 2006, Entrada Networks
   '01010110011' => 'Unknown 2', # dwk at 7663 in June 2006, Cisco
   );
#
my $usage =
qq/Usage: arp-fingerprint.pl [options] <target>
Fingerprint the target system using arp-scan.

'options' is one or more of:
        -h Display this usage message.
        -v Give verbose progress messages.
/;
my %opts;
my $verbose;
my $fingerprint="";
my $fp_name;
#
# Process options
#
die "$usage\n" unless getopts('hv',\%opts);
if ($opts{h}) {
   print "$usage\n";
   exit(0);
}
$verbose=$opts{v} ? 1 : 0;
#
if ($#ARGV != 0) {
   die "$usage\n";
}
my $target=shift;
#
# Check that the system responds to an arp-scan with no options.
# If it does, then fingerprint the target.
#
if (&fp("","$target") eq "1") {
   $fingerprint .= &fp("--arpspa=127.0.0.1","$target");
   $fingerprint .= &fp("--arpspa=0.0.0.0","$target");
   $fingerprint .= &fp("--arpspa=255.255.255.255","$target");
   $fingerprint .= &fp("--arpspa=1.0.0.1","$target");	# Non-local source IP
   $fingerprint .= &fp("--arpop=255","$target");
   $fingerprint .= &fp("--arphrd=6","$target");
   $fingerprint .= &fp("--arphrd=255","$target");
   $fingerprint .= &fp("--arppro=0xffff","$target");
   $fingerprint .= &fp("--arppro=0x8137","$target");
   $fingerprint .= &fp("--arppln=6","$target");
   $fingerprint .= &fp("--arphln=8","$target");
#
   if (defined $fp_hash{$fingerprint}) {
      $fp_name = "$fp_hash{$fingerprint}";
   } else {
      $fp_name = "UNKNOWN";
   }
   print "$target\t$fingerprint\t$fp_name\n";
} else {
   print "$target\tNo Response\n";
}
#
# Scan the specified IP address with arp-scan using the given options.
# Return "1" if the target responds, or "0" if it does not respond.
#
sub fp ($$) {
   my $ip;
   my $options;
   my $response = "0";
   ($options, $ip) = @_;

   open(ARPSCAN, "$arpscan $options $ip |") || die "arp-scan failed";
   while (<ARPSCAN>) {
      if (/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\t/) {
         $response = "1";
         last;
      }
   }
   close(ARPSCAN);

   if ($verbose) {
      if ($response) {
         print "$options\tYes\n";
      } else {
         print "$options\tNo\n";
      }
   }

   return $response;
}
