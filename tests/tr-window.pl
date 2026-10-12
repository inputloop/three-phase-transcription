#!/usr/bin/env perl
# tr-window.pl -- a third reader for phase one (tr1qt): names, windows, clocks and kept hashes, read in Perl.
#   Copyright 2026 Corwin Brust <corwin@bru.st> and Contributors.  Authored by Mentat (for Corwin).
#   SPDX-License-Identifier: GPL-3.0-or-later OR LGPL-3.0-or-later
#
# WHY: 2026-10-11.  An OBS file name ("2026-10-11 18-33-17.mp4") carried a space into every citation and got past
#   both earlier readers (tr1qt's own --prove-red in Python, tests/tr-spec.sh in sh + awk), which only ever saw
#   names without one.  His rule: what gets past the tests gets a NEW spec in a language apart from the work's and
#   the prior tests'.  This spec is written from the tool's header (NAMES, WINDOW, CLOCK, WORK), not its code.
#
# usage: perl tests/tr-window.pl QDIR...      every check on every tr1qt output folder; exit 1 on any fault
#        perl tests/tr-window.pl --prove-red  planted folders, one fault each, and a clean control
#   W1  the folder name is a stem a citation can carry: letters, digits and . _ + - only
#   W2  with a window in PROVENANCE (window_s A-B), every quote starts at or after A and ends by B (1 s slack)
#   W3  quotes come in time order
#   W4  the hh:mm:ss column is the start, in whole seconds, in the recording's own clock
#   W5  a source named like a date and time has clock_start equal to it; any other has none
#   W6  sha256 is 64 hex; a kept .sha256 beside it names the same digest
use strict; use warnings;
use File::Temp qw(tempdir);

sub hms { my $s = int(shift); sprintf "%02d:%02d:%02d", int($s / 3600), int(($s % 3600) / 60), $s % 60 }

sub check {
    my ($q) = @_; my @f; (my $name = $q) =~ s{/+$}{}; $name =~ s{.*/}{};
    push @f, "W1 $name: the name holds a character a citation cannot carry" unless $name =~ /^[A-Za-z0-9._+-]+$/;
    my %p;
    if (open my $ph, '<', "$q/PROVENANCE") { while (<$ph>) { chomp; my ($k, $v) = split /\t/, $_, 2; $p{$k} = $v if defined $v } }
    else { push @f, "W0 $name: no PROVENANCE"; return @f }
    my ($a, $b) = ($p{window_s} // '') =~ /^([\d.]+)-([\d.]+)$/;
    open my $qh, '<', "$q/QUOTES.tsv" or return (@f, "W0 $name: no QUOTES.tsv");
    my ($last, $n) = (-1, 0);
    while (<$qh>) {
        chomp; $n++; my ($s, $e, $t) = split /\t/;
        if (defined $a) {
            push @f, "W2 $name:$n starts at $s, before the window opens at $a" if $s < $a - 1;
            push @f, "W2 $name:$n ends at $e, after the window closes at $b" if $e > $b + 1;
        }
        push @f, "W3 $name:$n starts at $s, before the line above it ($last)" if $s < $last;
        push @f, "W4 $name:$n says $t, its start $s is " . hms($s) if $t ne hms($s);
        $last = $s;
    }
    my $src = $p{source} // '';
    my $want = $src =~ /(\d{4})[-_](\d\d)[-_](\d\d)[ _T-](\d\d)[-_:](\d\d)[-_:](\d\d)/ ? "$1-$2-$3T$4:$5:$6" : undef;
    if (defined $p{clock_start}) {
        if (!defined $want) { push @f, "W5 $name: clock_start $p{clock_start} with no date in the name" }
        elsif ($p{clock_start} ne $want) { push @f, "W5 $name: clock_start is $p{clock_start}, the name says $want" }
    } elsif (defined $want) { print "NOTE W5 $name: the name says $want and PROVENANCE keeps no clock (made before CLOCK, 2026-10-11)\n" }
    my $h = $p{sha256} // '';
    push @f, "W6 $name: sha256 '$h' is not 64 hex" unless $h =~ /^[0-9a-f]{64}$/;
    if (open my $kh, '<', "$q/.sha256") { my $l = <$kh> // ''; chomp $l; my @k = split /\t/, $l;
        push @f, "W6 $name: the kept hash names " . ($k[2] // 'nothing') . ", PROVENANCE names $h" unless ($k[2] // '') eq $h }
    return @f;
}

sub plant {
    my ($dir, $name, %o) = @_; my $q = "$dir/$name"; mkdir $q;
    open my $p, '>', "$q/PROVENANCE"; print $p "source\t$o{source}\nsha256\t" . ("a" x 64) . "\n";
    print $p "window_s\t$o{window}\n" if $o{window}; print $p "clock_start\t$o{clock}\n" if $o{clock}; close $p;
    open my $t, '>', "$q/QUOTES.tsv"; print $t "$_\n" for @{ $o{rows} }; close $t;
    if ($o{kept}) { open my $k, '>', "$q/.sha256"; print $k "1\t2\t$o{kept}\n"; close $k }
    return $q;
}

sub prove_red {
    my $d = tempdir(CLEANUP => 1); my ($fired, $n) = (0, 0);
    my @good = ("100.00\t101.00\t00:01:40\ta", "102.50\t103.00\t00:01:42\tb");
    my %base = (source => "2026-10-11 18-33-17.mp4", clock => "2026-10-11T18:33:17", window => "99.00-104.00", rows => \@good);
    my @cases = (
        ["control", 0, %base],
        ["has space", "W1", %base],
        ["early", "W2", %base, rows => ["90.00\t91.00\t00:01:30\ta"]],
        ["late", "W2", %base, rows => ["103.00\t109.00\t00:01:43\ta"]],
        ["order", "W3", %base, rows => [$good[1], $good[0]]],
        ["hms", "W4", %base, rows => ["100.00\t101.00\t00:01:41\ta"]],
        ["clock", "W5", %base, clock => "2026-10-11T18:33:18"],
        ["noclock", "W5", %base, source => "remodel.mp3"],
        ["kept", "W6", %base, kept => ("b" x 64)],
        ["oldset", 0, %base, clock => undef, window => undef],   # made before CLOCK: a note, not a fault
    );
    for my $c (@cases) {
        my ($name, $want, %o) = @$c; my @f = check(plant($d, $name, %o)); $n++;
        if (!$want) { $fired++ if !@f; print "  control: ", (@f ? "FAULTS @f" : "clean"), "\n" }
        else { $fired++ if grep { /^$want / } @f }
    }
    print "tr-window --prove-red: $fired/$n planted cases read as planted\n";
    return $fired == $n ? 0 : 1;
}

if (@ARGV && $ARGV[0] eq '--prove-red') { exit prove_red() }
die "usage: perl tests/tr-window.pl QDIR... | --prove-red\n" unless @ARGV;
my $faults = 0;
for my $q (@ARGV) { my @f = check($q); print "FAULT $_\n" for @f; $faults += @f }
printf "tr-window: %d folder(s), %d fault(s)\n", scalar @ARGV, $faults;
exit($faults ? 1 : 0);
