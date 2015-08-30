#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use FindBin;                 # locate this script
use lib "$FindBin::Bin/lib";
#use lib './lib/';
use taskparse;

use File::Slurp 'read_file';
use Data::Printer;
use Capture::Tiny ':all';
use Text::Diff;
use Getopt::Long;
use Test::More;

#use Data::Dumper;
#$Data::Dumper::Deepcopy = 1; # for better dumps

#---------------------------------------------------------------------------
#--- utility subs
#---------------------------------------------------------------------------
sub printarray {
    my $array = shift ;
    foreach my $matchtag ( @{$array} ) { print " $matchtag"; }
    print "\n";
}

sub selftest {
    my @tasklist=rtget_tasklist();
#print "TASKLIST::\n".Dumper(@tasklist);
    foreach my $titem (@tasklist)
    {
#my $line = sprintf ("%3d",$titem->{'inputline'});
        my $line = sprintf ("%d",$titem->{'inputline'});
        my $spaces = "";
        my $tags =  join(" ", keys $titem);
        $tags =~ s/inputline\s?//;
        printf "$line: $tags";
        if ( exists $titem->{'tags'} ) { print " (with ".@{$titem->{'tags'}}." tags)"; }
        print "\n";

        if ( exists $titem->{'text'} )    { print "$spaces    text: $titem->{'text'}\n"; }
#else { print "$spaces    text: <no task text found!>\n"; }
        if ( exists $titem->{'qtext'} )   { print "$spaces   qtext: $titem->{'qtext'}\n"; }
        if ( exists $titem->{'comment'} ) { print "$spaces comment: $titem->{'comment'}\n"; }

        if ( exists $titem->{'tags'} ) {
            if (my @matched = grep( /\+/, @{$titem->{'tags'}}))
            { print "$spaces    PROJ:"; printarray(\@matched); }
            if (my @matched = grep( /\#/, @{$titem->{'tags'}}))
            { print "$spaces    TAGS:"; printarray(\@matched); }
            if (my @matched = grep( /\@/, @{$titem->{'tags'}}))
            { print "$spaces    SCOP:"; printarray(\@matched); }
            if (my @matched = grep( /\!/, @{$titem->{'tags'}}))
            { print "$spaces    PRIO:"; printarray(\@matched); }
            if (my @matched = grep( /\&/, @{$titem->{'tags'}}))
            { print "$spaces    TYPE:"; printarray(\@matched); }
        }
    }
}

#---------------------------------------------------------------------------
#--- main
#---------------------------------------------------------------------------
#
# todo: CONFIG FILE
# http://search.cpan.org/~shlomif/Config-IniFiles-2.88/lib/Config/IniFiles.pm
# https://www.roaringpenguin.com/products/remind
# http://todotxt.com/
#
my $test=0;
my $infile="todo.txt";
GetOptions ('test' => \$test, 'infile=s' => \$infile);
if (@ARGV > 0) { $infile = shift @ARGV; }
if (@ARGV > 0) { die "ERROR: ".@ARGV." extra arguments on command line: @ARGV\n"; }

#print @INC;

my $g = rtinit_grammar();
my $r = rtinit_parser($g);
#p $g;
#p $r;

my $string;
if ( $test ) {
    print "Use prove task-test.t ...\n";
}
else {
    print "---Reading input from $infile...\n";
    $string = read_file($infile);
}

print "---Parsing Input file with parser...\n";
$r->read(\$string);

print "---Retrieving the tree...\n";
my $tree = ${$r->value};
#print "Tree:\n".Dumper($tree);
#p $tree;
print "---DONE processing input\n";

