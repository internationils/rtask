package taskparse;

use strict;
use warnings;

BEGIN {
    require Exporter;
# set the version for version checking
    our $VERSION     = 1.00;
# Inherit from Exporter to export functions and variables
    our @ISA         = qw(Exporter);
# Functions and variables which are exported by default
    our @EXPORT      = qw( new rtget_tasklist
            rtinit_all rtinit_grammar rtinit_parser rtflush_parser
            rtdo_nothing rtdo_dump_line rtdo_newline rtdo_continuation rtdo_comment
            rtdo_taglist rtdo_nqstring rtdo_qstring rtdo_process
            rtdo_list_line);
# Functions and variables which can be optionally exported
    our @EXPORT_OK   = qw();
}

use Marpa::R2;
use Data::Printer;
#use Log::Log4perl;

my @tasklist=(); # final storage of all parsed data
my $inputline=1; # count the iput lines, useful for debugging and error mesages
my $containedlines=0; # to tarack the line increment for multilines (quoted, continuations)
my %record=(); # temporary record storage during parsing of one input like
my @tagarray = (); # temporary storage of all tags
my $taskstring=""; # temporary storage of all non quoted text

=begin comment
   BRIEF INFORMAL GRAMMAR DESCRIPTION
>>>How can an input line look?
blank
comment # only goes to end of line, continuation with '\' not possible
tags* text [tags|text]* comment*

>>>How can text look?
plain text # anything that is not a tag
"quoted text" # swallows text up to the next quote, even on subsequent lines with or without '\' continuation

>>>how can a tag look?
[!$+&#]\w+
=end comment
=cut

my $grammar = << 'END_OF_GRAMMAR2';
        :default ::= action => [ name, start, length, value ]
#lexeme default = action => [ name, value ] latm => 1 # to add token names to ast
        :start          ::= tasktokens
        tasktokens      ::= tasktoken +
        tasktoken       ::=
        comment            action => rtdo_comment
        | qstring          action => rtdo_qstring
        | uqstring         action => rtdo_nqstring
        | tag              action => rtdo_taglist
        || nontag          action => rtdo_nqstring
        | continuation     action => rtdo_continuation 
        | newline          action => rtdo_newline

        qstring ~ quote in_string quote
        quote ~ ["]
        in_string ~ in_string_char*
        in_string_char ~ [^"] | '\"'

        comment ~ '//' comment_body
        comment_body ~ comment_body_char*
        comment_body_char ~ [^\n\r]

        nontag ~ tagstartchar no_space_nl

        tag ~ tagstartchar tag_body
        tag_body ~ [\w] no_space_nl
        tagstartchar ~ [+#@&!]

        uqstring ~ wordstart no_space_nl
        wordstart ~ [^\s+#@&!]
        no_space_nl ~ [^\h\n\r]*

        :discard ~ hspaces
        hspaces ~ [\h]+

        continuation ::= cont_char newline
        cont_char ~ '\'

        newline ::= cr nl || cr | nl
        cr ~ [\r]
        nl ~ [\n]
END_OF_GRAMMAR2

#The programmer must decide when to use the "~" operator and when to use the "::=" operator, but the choice will usually be easy: If you want Marpa to "do what I mean" with whitespace, you use the "::=" operator. If you want Marpa to do exactly what you say on a character-by-character basis, then you use the "~" operator.

# http://search.cpan.org/dist/Marpa-R2/pod/Scanless.pod
#Tokens at the boundary between L0 and G1 have special significance. The top-level undiscarded symbols in L0, which will be called "L0 lexemes", go on to become the terminals in G1. G1's terminals are called "G1 lexemes". To find the "L0 lexemes", Marpa looks for symbols which are on the LHS of a L0 rule, but not on the RHS of any L0 rule. To find the "G1 lexemes", Marpa looks for symbols on the RHS of at least one G1 rule, but not on the LHS of any G1 rule.

#lwa sequence rules (those with "+" or "*" quantifiers) must be rules of their own. Try this: tag_body ~ tag_body_start tag_body_rest; tag_body_start~ ...; tag_body_rest ~ [\w]*;
#lwa Marpa's SLIF will never autogenerate a rule ID for you, in order to make debugging easier. And sequences must be a grammar rule of their own

#rns | means 'same precedence as above', || means 'lower precedence than above'
#rns for continuation you possibly can use a sequence rule with separator => [\]
#rns on continuations, my last take is
#rns cont_line ::= line+ separator => cont
#rns line ~ [^\\]+
#rns cont ~ '\' [\n]
#rns but if you are not going to allow \ for escaping the last version would do.
#rns Also, trace_terminals => 1 or even 99 and show_progress() can help you see what's going on.  BTW, you can put this trace_terminals/show_progress stuff into a sub, e.g. parse_debug() to be called when a parse fails.

#rns re data structures — you can define semantic actions for rules which will, e.g. insert the needed data into the DB once parsed, as in https://metacpan.org/pod/distribution/Marpa-R2/pod/Scanless/DSL.pod
#rns and avoid the need for intermediary storage.

# error correction
# http://stackoverflow.com/questions/25698167/does-the-marpa-parser-library-support-error-recovery

# initialize everything
sub rtinit_all { rtinit_tasklist(); rtinit_taskvars(); }

# reset the global tasklist
sub rtinit_tasklist {
    @tasklist=(); # final storage of all parsed data
    $inputline=1; # count the input lines, useful for debugging and error mesages
}

# reset all temporary collection variables
sub rtinit_taskvars {
    $containedlines=0; # to track the line increment for multilines (quoted, continuations)
    %record=(); # temporary record storage during parsing of one input like
    @tagarray = (); # temporary storage of all tags
    $taskstring=""; # temporary storage of all non quoted text
}

sub rtget_tasklist { return @tasklist; }

sub rtinit_grammar {
    print "---Setting up grammar...\n";
    my $g = Marpa::R2::Scanless::G->new({
            action_object => 'main',
            source         => \( $grammar )
    });
    return $g;
}

sub rtinit_parser {
    my $g = shift;
#   print "---Setting up parser...\n";
    my $r  = Marpa::R2::Scanless::R->new({
            grammar => $g,
#   trace_terminals => 1,
#   trace_values => 1
            });
    return $r;
}

# called when a new ..... is set up
sub new { if(0) { print "NEW\n";} } 
# blank action if needed
sub rtdo_nothing { return; }

sub rtflush_parser {
rtdo_newline();
}

#
# if a newline is encountered, save all of the items collected as we've
# reached the end of the input line
#
sub rtdo_newline {
    $record{'inputline'} = $inputline++;
# add the contained lines, since the next line will start at a later line
    $inputline += $containedlines;

#  print "Line: $inputline\n";

# my $listsize=@tasklist;
# print " [EOL$listsize-$inputline]\n";

# make a copy of the tag array to put into the tags has in the record, else its gone...
    if ( scalar @tagarray > 0 ) {
        my @copyarray = @tagarray;
        $record{'tags'} = \@copyarray;
    }
# make a copy of the hash to push into the array, else its gone...
    my %saverecord=%record;

# ... and save the current record to the main task array
# ... if there is anything in the record
#   print scalar keys %saverecord;
    if(scalar keys %saverecord > 1) { push @tasklist, \%saverecord; }

# reset the temporary task variables
    rtinit_taskvars();
}

# a line continuation just needs to increment the linecount... newline is only called
# when the entire input line has been consumed
sub rtdo_continuation { $containedlines++; }

# just pass the contents on to the handler
sub rtdo_comment { rtdo_process("comment", $_[1]); }
sub rtdo_taglist { rtdo_process("tags", $_[1]); }
sub rtdo_nqstring { rtdo_process("text", $_[1]); }

# quoted strings are special because they can span multiple lines
# so we need to count them
sub rtdo_qstring {
    if ($_[1] =~ /\n/) {
        my $newlines = () = $_[1] =~ /\n/g;
        $containedlines += $newlines;
#print "NEWLINE found... $newlines newlines in line $inputline\n";
        $_[1] =~ s/\n/ /g;
    }
    rtdo_process("qtext", $_[1]);
}


sub rtdo_process {
    my $type  = $_[0];
    my @chash  = $_[1];

    my $datatype = ref $chash[0];

#   print "$inputline: $type\n";
#   print STDERR "type: $type $datatype\n";
#  p @chash;

    if ( ref $chash[0] eq "ARRAY" ) {
        my $ttype = shift @{ $chash[0] };
        my $start = shift @{ $chash[0] };
        my $length = shift @{ $chash[0] };
        if($type eq "tags") {
            foreach ( @{ $chash[0] } ) { push @tagarray,$_; }
        }
        else {
#TODO old code... review and probably delete
            foreach ( @{ $chash[0] } ) { $taskstring .= $_." "; }
            p $taskstring;
            $record{$type} = $taskstring;
        }
#print "ARRDUMP::".Dumper(\%record);
    } else {
        chomp $chash[0];
        if($type eq "tags") {
            push @tagarray,$chash[0]; 
        }
        else {
            if ( not exists $record{$type} ) {
                $record{$type} = $chash[0];
            }
            else {
                $record{$type} = $record{$type}." ".$chash[0];
            }
        }
#print "SCADUMP::".Dumper(\%record);
    }
}

sub rtdo_list_line {
    my $type  = $_[0];
    my @chash  = $_[1];

# values passed in here can be single values (passed in a scalar) or
# an array (passed as a reference). Deal with it appropriately.
# BUGME: change to the following to see the crash:
#   if ( ref $chash[0] ||1 ) {
    if ( ref $chash[0] eq "ARRAY" ) {
#		print "REF LISTLINE items: ".scalar @{$chash[0]}."\n";
#print "DUMP: ".Dumper(@chash,$chash[0]);
        print "ARR$type: ";
        my $type = shift @{ $chash[0] };
        my $start = shift @{ $chash[0] };
        my $length = shift @{ $chash[0] };
        foreach ( @{ $chash[0] } ) { print ".".$_." "; }
    } else {
        print "SCA$type: ";
        chomp $chash[0];
        print $chash[0]." ";
    }
}
