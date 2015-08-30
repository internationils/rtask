#!/usr/bin/env perl

#
# usage: prove test-rtask.t
#

use strict;
use warnings;
use autodie;

use FindBin;                 # locate this script
use lib "$FindBin::Bin/../lib";
use taskparse;

use Data::Printer;
use Capture::Tiny ':all';
use Text::Diff;
use Test::More;

#---------------------------------------------------------------------------
#--- TEST routines
#---------------------------------------------------------------------------
# BASIC tests
sub test_basic {
    my $g = shift;
    my $input;
    my $output;
    plan tests => 5;

    $input = qq(\n);
    $output = "";
    parse_and_compare($g, $input, $output, "Blank line");

    $input = qq(line);
    $output = qq(1: text
            text: line);
    parse_and_compare($g, $input, $output, "Single word");

    $input = qq(next line);
    $output = qq(1: text
            text: next line);
    parse_and_compare($g, $input, $output, "Multiple words");

    $input = qq(firstline\nsecond);
    $output = qq(1: text
            text: firstline
            2: text
            text: second);
    parse_and_compare($g, $input, $output, "Two lines");

    $input = qq(firstline\n\nthird);
    $output = qq(1: text
            text: firstline
            3: text
            text: third);
    parse_and_compare($g, $input, $output, "Three lines, second one blank");
};

# COMMENT tests
sub test_comments {
    my $g = shift;
    my $input;
    my $output;
    plan tests => 5;

    $input = qq(// mycomment full line);
    $output = qq(1: comment
            comment: // mycomment full line);
    parse_and_compare($g, $input, $output, "Full line comment");

    $input = qq(//);
    $output = qq(1: comment
            comment: //);
    parse_and_compare($g, $input, $output, "Blank comment");

    $input = qq(line // mycomment at the end of the line);
    $output = qq(1: comment text
            text: line
            comment: // mycomment at the end of the line);
    parse_and_compare($g, $input, $output, "Comment at the end of the line");

    $input = qq(line endcomment //);
    $output = qq(1: comment text
            text: line endcomment
            comment: //);
    parse_and_compare($g, $input, $output, "Blank comment at the end of the line");

    $input = qq(// a "comment containing quotes in lineNNN" and a #tag and a continuation to be ignored ... \\);
    $output = qq(1: comment
            comment: // a "comment containing quotes in lineNNN" and a #tag and a continuation to be ignored ... \\);
    parse_and_compare($g, $input, $output, "Comment with quotes, tag and continuation to be ignored");
};

# TAG tests
sub test_tags {
    my $g = shift;
    my $input;
    my $output;
    plan tests => 1;

    $input = qq(+testprojectA \@testlocationB #testtagC.line !testprioD &testtypeE +proj2 \@location2 #tag2 !prio2 &type2 tasktext);
    $output = qq(1: text tags \(with 10 tags\)
            text: tasktext
            PROJ: +testprojectA +proj2
            TAGS: #testtagC.line #tag2
            SCOP: \@testlocationB \@location2
            PRIO: !testprioD !prio2
            TYPE: &testtypeE &type2);
    parse_and_compare($g, $input, $output, "10 tags, 2 each");
}

# SPECIAL CHARACTER tests
sub test_characters {
    my $g = shift;
    my $input;
    my $output;
    plan tests => 3;

    $input = qq(a line with a forward slash / in the middle);
    $output = qq(1: text
            text: a line with a forward slash / in the middle);
    parse_and_compare($g, $input, $output, "Slash in the middle");

    $input = qq(a line with an exclamation ! and two more !! in the middle);
    $output = qq(1: text
            text: a line with an exclamation ! and two more !! in the middle);
    parse_and_compare($g, $input, $output, "Non-tags with ! and !!");

    $input = qq(a line a !!nontag !/notag2);
    $output = qq(1: text
            text: a line a !!nontag !/notag2);
    parse_and_compare($g, $input, $output, "Non-tags !!nontag and !/nontag");
}

# QUOTING tests
sub test_quotes {
    my $g = shift;
    my $input;
    my $output;
    plan tests => 3;

    $input = qq("line with quoted text");
    $output = qq(1: qtext
            qtext: "line with quoted text");
    parse_and_compare($g, $input, $output, "Full line quoted");

    $input = qq(#a_tag "line with more quoted text" #another_tag // and a comment);
    $output = qq(1: qtext comment tags (with 2 tags)
            qtext: "line with more quoted text"
            comment: // and a comment
TAGS: #a_tag #another_tag);
    parse_and_compare($g, $input, $output, "Tag, quoted text, tag and a comment");

    $input = qq("this is a quoted
            multiline across line2
            up to line3");
    $output = qq(1: qtext
            qtext: "this is a quoted multiline across line2 up to line3");
    parse_and_compare($g, $input, $output, "Quoted three line multiline");
}

# CONTINUATION tests
sub test_continuation {
    my $g = shift;
    my $input;
    my $output;
    plan tests => 2;

    $input = qq(and here we have line with \\
            a continued line);
    $output = qq(1: text
            text: and here we have line with a continued line);
    parse_and_compare($g, $input, $output, "Simple continued text across 2 lines");

    $input = qq(#tags #more_tags.line \\\n#and_even_more.line with a blank line next);
    $output = qq(1: text tags (with 3 tags)
            text: with a blank line next
            TAGS: #tags #more_tags.line #and_even_more.line);
    parse_and_compare($g, $input, $output, "Continued text across 2 lines with tags");
}

# GRAMMAR tests
sub test_grammar {
    my $g = shift;
    my $input;
    my $output;
    plan tests => 1;

    $input = qq(TODO: failline with a #tag_in_the_middle and more task text that shouldn't be in line);
    $output = qq(1: text tags \(with 1 tags\)
            text: failline with a and more task text that shouldn't be in line
            TAGS: #tag_in_the_middle);
    parse_and_compare_false($g, $input, $output, "TODO: A line with a #tag in the middle that should fail");
}

sub runtests {
    my $g = shift;
    my $input;
    my $output;

    plan tests => 7;
    subtest 'The basics' => \&test_basic, $g;
    subtest 'Comments' => \&test_comments, $g;
    subtest 'Quotes' => \&test_quotes, $g;
    subtest 'Tags' => \&test_tags, $g;
    subtest 'Characters' => \&test_characters, $g;
    subtest 'Continuation' => \&test_continuation, $g;
    subtest 'Grammar' => \&test_grammar, $g;

    done_testing();
    return 0;
}

#---------------------------------------------------------------------------
#--- test utility subs
#---------------------------------------------------------------------------

# take an array and print it out on one line, space separated
sub printarray {
    my $array = shift ;
    foreach my $matchtag ( @{$array} ) { print " $matchtag"; }
    print "\n";
}

# take the parsed tasklist and print it to stdout
# this gets captured and used in the self tests
sub print_tasklist {
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

sub parse_and_compare { do_parse_and_compare(@_, 1); }
sub parse_and_compare_false { do_parse_and_compare(@_, 0); }
sub do_parse_and_compare {
    my $g = shift;
    my $input = shift;
    my $expect = shift;
    my $testdesc = shift;
    my $truefalse = shift;

    my $result;

# clear all the internal variables in preparation for the test
    rtinit_all();
# need to reinitialize the parser every time; grmmar can be reused
    my $r = rtinit_parser($g);

# need to read the input and get the tree, else the parsing doesn't happen
    $r->read(\$input);
    my $tree = ${$r->value};
# need to flush in case the last line doesn't end with \r\n which is needed to
# trigger the saving of the temporary variables to the task array
    rtflush_parser();
# capture the outpt of the task list from stdout
    $result = capture { print_tasklist() };

#my $boolean = (($result =~ s/\s//gr) eq ($expect =~ s/\s//gr));
#print "bool: $boolean ?= $truefalse\n";

# Test::More testing...
    ok ( (($result =~ s/\s//gr) eq ($expect =~ s/\s//gr)) == $truefalse , $testdesc);

# TODO: set with debug level...
# debug output via Text::Diff::Table
    if(0) {
        if ( (($result =~ s/\s//gr) ne ($expect =~ s/\s//gr)) == $truefalse ) {
            $result =~ s/\s+$//gm;
        chomp $result;
        chomp $expect;
        $expect =~ s/^/...EXPECT:\n/;
        $result =~ s/^/...RESULT:\n/;
        my $diff = diff \$expect, \$result, { STYLE => "Table" };

        my $printinput = $input;
        $printinput =~ s/^/INPUT: /gm;
        print "$printinput\n";
        print $diff;
    }
    }
}


#---------------------------------------------------------------------------
#--- main
#---------------------------------------------------------------------------

# initialize the grammar and run the test suite
my $g = rtinit_grammar();
runtests($g);
